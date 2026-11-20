import path from "node:path"

type Todo = { id?: string; content: string; status: string }
type Unit = {
  id: string
  label: string
  content: string
  position: number
  file?: string
  open: boolean
  writes: number
  feedbackRevision: boolean
}
type SessionGate = {
  agent?: string
  approvalAvailable: boolean
  verificationRequested: boolean
  feedbackRevisionAvailable: boolean
  todoLoadFailed: boolean
  todos: Todo[]
  unit?: Unit
}

const sessions = new Map<string, SessionGate>()

function gate(sessionID: string): SessionGate {
  let state = sessions.get(sessionID)
  if (!state) {
    state = {
      approvalAvailable: false,
      verificationRequested: false,
      feedbackRevisionAvailable: false,
      todoLoadFailed: false,
      todos: [],
    }
    sessions.set(sessionID, state)
  }
  return state
}

function repositoryPath(file: unknown, directory: string, worktree: string): string | undefined {
  if (typeof file !== "string" || !file) return undefined
  const resolved = path.resolve(directory, file)
  const relative = path.relative(worktree, resolved).split(path.sep).join("/")
  if (!relative || relative === ".." || relative.startsWith("../") || path.isAbsolute(relative)) return undefined
  return relative
}

function makeUnit(todo: Todo, position: number, worktree: string): Unit {
  const label = todo.content.match(/\bUnit \d+\/\d+\b/)?.[0] ?? todo.content
  const file = todo.content.match(/\bUnit \d+\/\d+\s+—\s+(.+?):\s+/)?.[1]
  return {
    id: todo.id ?? todo.content,
    label,
    content: todo.content,
    position,
    file: file ? repositoryPath(file.trim(), worktree, worktree) : undefined,
    open: true,
    writes: 0,
    feedbackRevision: false,
  }
}

function nextTodoUnit(state: SessionGate, worktree: string): Unit | undefined {
  const position = state.todos.findIndex((item) => item.status !== "completed" && item.status !== "cancelled")
  const todo = state.todos[position]
  if (!todo) return undefined
  return makeUnit(todo, position, worktree)
}

function feedbackTodoUnit(state: SessionGate, worktree: string): Unit | undefined {
  let position = state.todos.findIndex((item) => item.status === "in_progress")
  if (position < 0) {
    for (let index = 0; index < state.todos.length; index += 1) {
      if (state.todos[index]?.status === "completed") position = index
    }
  }
  const todo = state.todos[position]
  return todo ? makeUnit(todo, position, worktree) : undefined
}

function isUnitComplete(todos: unknown, unit: Unit): boolean {
  if (!Array.isArray(todos)) return false
  const rows = todos as Todo[]
  const byID = unit.id && rows.findIndex((todo) => todo.id === unit.id)
  const byContent = rows.findIndex((todo) => todo.content === unit.content)
  const index = typeof byID === "number" && byID >= 0
    ? byID
    : byContent >= 0
      ? byContent
      : unit.position
  const todo = rows[index]
  return todo?.status === "completed" &&
    ((todo.id && todo.id === unit.id) || todo.content === unit.content || index === unit.position)
}

function todoPosition(todos: Todo[], unit: Unit): number {
  if (unit.id) {
    const index = todos.findIndex((todo) => todo.id === unit.id)
    if (index >= 0) return index
  }
  const byContent = todos.findIndex((todo) => todo.content === unit.content)
  return byContent >= 0 ? byContent : unit.position
}

async function refreshTodos(state: SessionGate, client: any, sessionID: string, force = false): Promise<void> {
  if (!force && state.todos.length > 0) return
  const response = await client.session.todo({ path: { id: sessionID } })
  if (response.error) throw new Error("could not reload the session todo list")
  if (!Array.isArray(response.data)) throw new Error("session todo response was not a list")
  state.todos = response.data.map((todo: Todo) => ({ id: todo.id, content: todo.content, status: todo.status }))
}

function patchPaths(patchText: unknown): string[] {
  if (typeof patchText !== "string") return []
  const paths: string[] = []
  for (const line of patchText.split(/\r?\n/)) {
    const file = line.match(/^\*\*\* (?:Update|Add|Delete) File: (.+)$/)?.[1]
    const move = line.match(/^\*\*\* Move to: (.+)$/)?.[1]
    if (file) paths.push(file.trim())
    if (move) paths.push(move.trim())
  }
  return paths
}

function safeShellCommand(command: unknown, verificationRequested: boolean): boolean {
  if (typeof command !== "string" || /[;|<>`\n\r]|&&|\|\||\$\(|\$\{|\(\s*\)/.test(command)) return false
  const value = command.trim()
  if (/^(pwd|ls|file|stat|wc)(\s|$)/.test(value)) return true
  if (/^rg\s/.test(value) && !/--pre(?:=|\s|$)/.test(value)) return true
  if (/^git\s+(status|diff|log|show|branch --show-current|rev-parse --show-toplevel|rev-parse --verify -q HEAD)(\s|$)/.test(value)) {
    return !/--(?:output|ext-diff|textconv)(?:=|\s|$)/.test(value)
  }
  return verificationRequested && /^(mvn test|mvn -Dtest=[^\s]+ test|npm test)(\s|$)/.test(value)
}

function mutatingPaths(tool: string, args: any, directory: string, worktree: string): string[] | undefined {
  if (tool === "edit" || tool === "write") {
    const file = repositoryPath(args?.filePath, directory, worktree)
    return file ? [file] : undefined
  }
  if (tool === "apply_patch") {
    const files = patchPaths(args?.patchText).map((file) => repositoryPath(file, directory, worktree))
    if (files.some((file) => !file)) return undefined
    return files as string[]
  }
}

const plugin = async ({ directory, worktree, client }: { directory: string; worktree: string; client: any }) => ({
  "chat.message": async (input: any, output: any) => {
    const state = gate(input.sessionID)
    state.agent = input.agent
    if (input.agent !== "cobuild") {
      state.approvalAvailable = false
      state.feedbackRevisionAvailable = false
      return
    }

    // The first non-synthetic text part is the user's prompt. Ignore editor
    // context attached after it when determining exact approval.
    const prompt = output.parts.find((part: any) => part.type === "text" && part.synthetic !== true)
    const userText = prompt?.type === "text" ? prompt.text.trim() : ""
    if (userText === "approve") {
      state.approvalAvailable = false
      state.feedbackRevisionAvailable = false
      state.verificationRequested = false
      state.unit = undefined
      state.todoLoadFailed = false
      try {
        await refreshTodos(state, client, input.sessionID, true)
        state.unit = nextTodoUnit(state, worktree)
        state.approvalAvailable = true
      } catch {
        state.todoLoadFailed = true
      }
      return
    }

    state.approvalAvailable = false
    state.todoLoadFailed = false
    try {
      await refreshTodos(state, client, input.sessionID, true)
    } catch {
      state.todoLoadFailed = true
    }
    state.verificationRequested = /\b(test|tests|testing|verify|verification|validate|validation)\b/i.test(userText)
    if (!state.unit || !state.unit.open) {
      state.unit = feedbackTodoUnit(state, worktree)
    }
    state.feedbackRevisionAvailable = Boolean(state.unit)
    if (state.feedbackRevisionAvailable && state.unit) {
      state.unit.open = true
      state.unit.writes = 0
      state.unit.feedbackRevision = true
    }
  },

  event: async ({ event }: { event: any }) => {
    if (event.type !== "todo.updated") return
    const state = sessions.get(event.properties.sessionID)
    if (!state || state.agent !== "cobuild") return
    state.todos = event.properties.todos.map((todo: Todo) => ({ id: todo.id, content: todo.content, status: todo.status }))
  },

  "tool.execute.before": async (input: any, output: any) => {
    const state = gate(input.sessionID)
    if (state.agent !== "cobuild") return

    const readOnly = new Set(["read", "glob", "grep", "list", "webfetch", "websearch", "skill"])
    if (readOnly.has(input.tool)) return

    if (input.tool === "todowrite") {
      if (state.unit && Array.isArray(output.args?.todos)) {
        const currentIndex = todoPosition(output.args.todos, state.unit)
        if (currentIndex >= 0) {
          for (let index = currentIndex + 1; index < output.args.todos.length; index += 1) {
            const todo = output.args.todos[index]
            if (todo.status !== "cancelled") todo.status = "pending"
          }
        }
      }
      if (Array.isArray(output.args?.todos)) {
        state.todos = output.args.todos.map((todo: Todo) => ({ id: todo.id, content: todo.content, status: todo.status }))
      }
      return
    }

    try {
      if (input.tool === "bash") {
        if (safeShellCommand(output.args?.command, state.verificationRequested)) return
        throw new Error("shell command is outside the read-only/verification allowlist")
      }

      const approvedThisTurn = state.approvalAvailable
      state.approvalAvailable = false
      if (state.todoLoadFailed) throw new Error("could not reload the session todo list; send a fresh exact approve or feedback message to retry")

      const paths = mutatingPaths(input.tool, output.args, directory, worktree)
      if (!paths) throw new Error("could not resolve all write paths inside the repository")
      if (paths.length !== 1) throw new Error("one review unit may change exactly one file")

      if (!state.unit) {
        if (!approvedThisTurn) throw new Error('no unused exact "approve" authorizes a write')
        await refreshTodos(state, client, input.sessionID)
        const next = nextTodoUnit(state, worktree)
        if (!next) throw new Error("there is no pending todo unit to authorize")
        if (next.file && paths[0] !== next.file) throw new Error(`the next pending unit is ${next.label} in ${next.file}`)
        state.unit = next
        state.approvalAvailable = false
      } else if (!state.unit.open) {
        throw new Error("the current unit is complete; wait for a fresh exact user approval")
      }

      if (!state.unit.file) state.unit.file = paths[0]
      if (paths[0] !== state.unit.file) throw new Error(`only ${state.unit.file} is allowed for ${state.unit.label}`)
      if (!approvedThisTurn && !state.feedbackRevisionAvailable && state.unit.writes === 0) {
        throw new Error('a fresh exact "approve" or feedback message is required before writing')
      }

      if (state.unit.writes > 0 && !state.unit.feedbackRevision) {
        throw new Error("this approval already authorized its one write; complete the todo and end this turn")
      }
      state.unit.writes += 1
      if (!state.unit.feedbackRevision) state.feedbackRevisionAvailable = false
    } catch (error) {
      throw new Error(`COBUILD GATE: ${error instanceof Error ? error.message : String(error)}. End this turn. A new exact "approve" or feedback message may retry.`)
    }
  },

  "tool.execute.after": async (input: any, output: any) => {
    const state = gate(input.sessionID)
    if (state.agent !== "cobuild" || !state.unit) return

    if (input.tool === "todowrite" && Array.isArray(input.args?.todos)) {
      state.todos = input.args.todos.map((todo: Todo) => ({ id: todo.id, content: todo.content, status: todo.status }))
      if (isUnitComplete(input.args.todos, state.unit)) {
        state.unit.open = false
        state.unit.feedbackRevision = false
      }
    }
    if (["edit", "write", "apply_patch"].includes(input.tool)) {
      output.output += state.unit.feedbackRevision
        ? `\n\nCOBUILD GATE: Revision edit for ${state.unit.label} in ${state.unit.file}. Continue only revisions to this unit in this file. You may make additional edits for this feedback; when done, complete only this todo, report, and end your turn. A fresh exact "approve" is required before another unit.`
        : `\n\nCOBUILD GATE: This is the one approved write for ${state.unit.label} in ${state.unit.file}. Complete only this unit's todo, report it, and end your turn. A fresh exact "approve" is required before another unit.`
    }
  },
})

export default plugin
