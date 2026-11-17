return {
  "sudo-tee/opencode.nvim",
  commit = "494e474f58c45218a4cf7c7d2e76b0408de09daa",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  config = function()
    local api = vim.api
    local fn = vim.fn
    local Promise = require("opencode.promise")
    local context = require("opencode.context")
    local session_runtime = require("opencode.services.session_runtime")
    local agent_model = require("opencode.services.agent_model")
    local config_file = require("opencode.config_file")
    local nvim_opencode_config = vim.fs.joinpath(vim.fn.stdpath("config"), "opencode-nvim.json")

    local nvim_agents = {
      coworker = true,
      cobuild = true,
    }

    local get_opencode_agents = config_file.get_opencode_agents
    config_file.get_opencode_agents = Promise.async(function()
      local agents = get_opencode_agents():await()
      return vim.tbl_filter(function(agent)
        return nvim_agents[agent] == true
      end, agents)
    end)

    local apply_server_agent = agent_model.apply_server_agent
    agent_model.apply_server_agent = function(agent)
      if nvim_agents[agent] then
        local was_cobuild = require("opencode.state").store.get("current_mode") == "cobuild"
        apply_server_agent(agent)
        if agent == "cobuild" and not was_cobuild then
          require("utils.changes").start_unit()
        end
      end
    end

    local opencode_filetypes = {
      opencode = true,
      opencode_output = true,
      opencode_footer = true,
    }

    local mode_profiles = {
      coworker = {
        provider = "github-copilot",
        model = "gpt-6.1-sol",
        variant = "medium",
      },
      cobuild = {
        provider = "github-copilot",
        model = "gpt-6-luna",
        variant = "xhigh",
      },
    }

    local cobuild_approval_questions = {}

    local function contains_approve(value)
      if value == "Approve" then return true end
      if type(value) == "table" then
        for _, item in pairs(value) do
          if contains_approve(item) then return true end
        end
      end
      return false
    end

    local function question_id(properties)
      local form = properties.form or properties
      return properties.id or properties.requestID or properties.requestId or form.id
    end

    local function has_cobuild_approval_header(properties)
      for _, question in ipairs(properties.questions or {}) do
        if question.header == "CoBuild approval" then return true end
      end
      local form = properties.form or properties
      if form.title == "CoBuild approval" then return true end
      for _, field in ipairs(form.fields or {}) do
        if field.title == "CoBuild approval" then return true end
      end
      return false
    end

    local function track_cobuild_approval(args)
      local event = args.data and args.data.event
      local properties = event and event.properties or {}
      local event_type = event and event.type
      local id = question_id(properties)
      if event_type == "question.asked" or event_type == "form.created" then
        local state = require("opencode.state")
        if state.store.get("current_mode") == "cobuild" and has_cobuild_approval_header(properties) and id then
          cobuild_approval_questions[id] = true
        end
      elseif event_type == "question.replied" or event_type == "form.replied" then
        local request_id = event_type == "question.replied" and (properties.requestID or properties.requestId) or id
        if request_id and cobuild_approval_questions[request_id] then
          cobuild_approval_questions[request_id] = nil
          local form = properties.form or properties
          if contains_approve(properties.answers or properties.answer or form.answer) then
            require("utils.changes").start_unit()
          end
        end
      elseif event_type == "question.rejected" or event_type == "form.cancelled" then
        if id then cobuild_approval_questions[id] = nil end
      end
    end

    api.nvim_create_autocmd("User", {
      pattern = {
        "OpencodeEvent:question.asked",
        "OpencodeEvent:question.replied",
        "OpencodeEvent:question.rejected",
        "OpencodeEvent:form.created",
        "OpencodeEvent:form.replied",
        "OpencodeEvent:form.cancelled",
      },
      group = api.nvim_create_augroup("CoBuildUnitApproval", { clear = true }),
      callback = track_cobuild_approval,
    })

    local function async(callback)
      Promise.async(callback)()
    end

    local function open_session(options)
      return session_runtime
          .open(vim.tbl_extend("force", { new_session = false }, options or {}))
          :await()
    end

    local function switch_mode_with_profile()
      async(function()
        local state = require("opencode.state")
        local current_mode = state.store.get("current_mode")
        local next_mode = current_mode == "coworker" and "cobuild" or "coworker"

        if not agent_model.switch_to_mode(next_mode):await() then
          return
        end

        local profile = mode_profiles[next_mode]
        agent_model.set_model(profile.provider, profile.model)
        agent_model.set_variant(profile.variant)
        if next_mode == "cobuild" then
          require("utils.changes").start_unit()
        end
      end)
    end

    local function switch_to_coworker()
      if not agent_model.switch_to_mode("coworker"):await() then
        return
      end

      local profile = mode_profiles.coworker
      agent_model.set_model(profile.provider, profile.model)
      agent_model.set_variant(profile.variant)
    end

    local function add_visual_selection_inline()
      local buf = api.nvim_get_current_buf()
      local mode = fn.mode(1)
      if not mode:match("^[vV\22]") then
        return
      end

      local start_pos = fn.getpos("v")
      local end_pos = fn.getpos(".")
      local first_pos, last_pos = start_pos, end_pos
      if first_pos[2] > last_pos[2]
          or (first_pos[2] == last_pos[2] and first_pos[3] > last_pos[3])
      then
        first_pos, last_pos = last_pos, first_pos
      end

      local lines = api.nvim_buf_get_lines(buf, first_pos[2] - 1, last_pos[2], false)
      if mode == "v" then
        local first_col = math.min(start_pos[3], end_pos[3]) - 1
        local last_col = math.max(start_pos[3], end_pos[3])
        if first_pos[2] == last_pos[2] then
          lines[1] = (lines[1] or ""):sub(first_col + 1, last_col)
        else
          lines[1] = (lines[1] or ""):sub(first_pos[3])
          lines[#lines] = (lines[#lines] or ""):sub(1, last_pos[3])
        end
      elseif mode == "\22" then
        local first_col = math.min(start_pos[3], end_pos[3]) - 1
        local last_col = math.max(start_pos[3], end_pos[3])
        for i, line in ipairs(lines) do
          lines[i] = line:sub(first_col + 1, last_col)
        end
      end

      local text = table.concat(lines, "\n")
      if text:match("^%s*$") then
        vim.notify("No visual selection found", vim.log.levels.WARN)
        return
      end

      local path
      local ok, changes = pcall(require, "utils.changes")
      if ok then
        path = changes.current_file_path()
      end
      if not path then
        local name = api.nvim_buf_get_name(buf)
        if name ~= "" and fn.filereadable(name) == 1 then
          path = name
        end
      end

      local filetype = path and vim.filetype.match({ filename = path }) or vim.bo[buf].filetype
      local fence_length = 3
      for run in text:gmatch("`+") do
        fence_length = math.max(fence_length, #run + 1)
      end
      local fence = string.rep("`", fence_length)
      local block = string.format("%s%s\n%s\n%s", fence, filetype or "", text, fence)
      if path then
        block = string.format("**`%s`**\n\n%s", path, block)
      end

      api.nvim_feedkeys(api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", true)
      async(function()
        open_session({ focus = "input", start_insert = false })
        require("opencode.ui.input_window")._append_to_input(block)
        vim.cmd("stopinsert")
      end)
    end

    local function toggle_panel()
      return require("opencode.api").toggle()
    end

    local function add_current_file()
      local file = api.nvim_buf_get_name(0)

      if file == "" then
        vim.notify("Current buffer has no file to add", vim.log.levels.WARN)
        return
      end

      context.add_file(file)
    end

    local function open_input()
      Promise.async(function()
        local state = require("opencode.state")
        local ui = require("opencode.ui.ui")

        open_session({ focus = "input", start_insert = false })

        local observation = state.session.active_observation()
        if not observation then
          error("OpenCode session is not active")
        end

        if observation:read().sync.session.state ~= "current" then
          observation:_start_resource("session")
        end

        for _ = 1, 60 do
          if state.session.active_observation() ~= observation then
            return
          end

          local sync = observation:read().sync.session
          if sync.state == "current" then
            ui.focus_input({ restore_position = true, start_insert = false })
            return
          end

          if sync.state == "error" or sync.state == "unsupported" then
            error("Session metadata unavailable: " .. vim.inspect(sync))
          end

          Promise.delay(50):await()
        end

        error("Timed out waiting for OpenCode session metadata")
      end)():catch(function(err)
        vim.notify("OpenCode input: " .. tostring(err), vim.log.levels.ERROR)
      end)
    end

    local function approve_step()
      local win = api.nvim_get_current_win()
      local cursor = api.nvim_win_get_cursor(win)
      require("opencode.api").question_answer()
      vim.schedule(function()
        if api.nvim_win_is_valid(win) then
          api.nvim_set_current_win(win)
          api.nvim_win_set_cursor(win, cursor)
        end
      end)
    end

    local function open_output()
      async(function()
        open_session({
          focus = "output",
          start_insert = false,
        })

        local observation = require("opencode.state").session.active_observation()
        if not observation then
          vim.notify("OpenCode session is not active", vim.log.levels.WARN)
          return
        end

        observation:_start_resource("messages")
      end)
    end

    local function start_new_session()
      async(function()
        local saved_context = context.get_context()
        local saved_selections = vim.deepcopy(saved_context.selections or {})
        local saved_files = vim.deepcopy(saved_context.mentioned_files or {})

        open_session({
          new_session = true,
          start_insert = false,
        })
        switch_to_coworker()

        for _, selection in ipairs(saved_selections) do
          context.add_selection(selection)
        end
        for _, file in ipairs(saved_files) do
          context.add_file(file)
        end
      end)
    end

    local function unload_attachments()
      context.unload_attachments()
    end

    local function paste_image()
      local state = require("opencode.state")
      local ui = require("opencode.ui.ui")
      local image_handler = require("opencode.image_handler")
      local mention = require("opencode.ui.mention")

      ui.focus_input({ restore_position = true, start_insert = false })

      local windows = state.windows
      if not windows then
        vim.notify("OpenCode input window is not open", vim.log.levels.WARN)
        return
      end

      local win = windows.input_win
      local buf = windows.input_buf
      if not win or not buf or not api.nvim_win_is_valid(win) or not api.nvim_buf_is_valid(buf) then
        vim.notify("OpenCode input window is not available", vim.log.levels.WARN)
        return
      end

      -- Save the image before changing the input buffer.
      local image_path = image_handler.save_clipboard_image()
      if not image_path then
        vim.notify("No image found in clipboard.", vim.log.levels.WARN)
        return
      end

      local row, col = unpack(api.nvim_win_get_cursor(win))

      -- Add the image mention on a new line without splitting existing text.
      api.nvim_buf_set_lines(buf, row, row, false, { "@" })
      api.nvim_win_set_cursor(win, { row + 1, 0 })

      -- Match the current plugin's paste workflow: insert a mention
      -- and register the saved image as context.
      local name = fn.fnamemodify(image_path, ":t")
      mention.mention(function(mention_cb)
        mention_cb(name)
        context.add_file(image_path)
      end)

      -- Mention insertion is scheduled by opencode.nvim, so run afterward.
      vim.schedule(function()
        if not api.nvim_win_is_valid(win) or not api.nvim_buf_is_valid(buf) then
          return
        end
        if api.nvim_win_get_buf(win) ~= buf then
          return
        end

        -- Leave an empty line after the image mention for continued typing.
        api.nvim_buf_set_lines(buf, row + 1, row + 1, false, { "" })
        api.nvim_set_current_win(win)
        api.nvim_win_set_cursor(win, { row + 2, 0 })

        vim.cmd("stopinsert")
      end)
    end

    local function reset_window_width()
      local default_width = math.floor(vim.o.columns * 0.35)

      for _, win in ipairs(api.nvim_list_wins()) do
        local buf = api.nvim_win_get_buf(win)
        if opencode_filetypes[vim.bo[buf].filetype] then
          pcall(api.nvim_win_set_width, win, default_width)
        end
      end
    end

    local function delete_all_sessions()
      if fn.confirm("Delete ALL opencode sessions?", "&Yes\n&No", 2) ~= 1 then
        return
      end

      fn.jobstart({ "opencode", "session", "list" }, {
        stdout_buffered = true,
        on_stdout = function(_, data)
          local ids = {}
          for _, line in ipairs(data) do
            local id = line:match("^(ses_%S+)")
            if id then
              table.insert(ids, id)
            end
          end

          if #ids == 0 then
            vim.notify("opencode: no sessions to delete", vim.log.levels.INFO)
            return
          end

          local deleted = 0
          local total = #ids
          for _, id in ipairs(ids) do
            fn.jobstart({ "opencode", "session", "delete", id }, {
              on_exit = function(_, code)
                if code == 0 then
                  deleted = deleted + 1
                else
                  vim.notify("opencode: failed to delete session " .. id, vim.log.levels.WARN)
                end
                if deleted == total then
                  vim.notify(string.format("opencode: deleted %d session(s)", total), vim.log.levels.INFO)
                end
              end,
            })
          end
        end,
        on_exit = function(_, code)
          if code ~= 0 then
            vim.notify("opencode: session list command failed", vim.log.levels.ERROR)
          end
        end,
      })
    end

    local function close_other_windows()
      local current_win = api.nvim_get_current_win()
      local window_utils = require("utils.windows")
      local focused_is_opencode = window_utils.is_opencode_window(current_win)

      -- Keep the leftmost non-OpenCode window when focused on OpenCode.
      local leftmost
      if focused_is_opencode then
        leftmost = window_utils.leftmost_window(0)
      end

      for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
        if win ~= current_win and win ~= leftmost then
          local buf = api.nvim_win_get_buf(win)
          if not opencode_filetypes[vim.bo[buf].filetype] then
            pcall(api.nvim_win_close, win, false)
          end
        end
      end
    end

    require("opencode").setup({
      preferred_picker = "mini.pick",
      preferred_completion = "blink",
      default_global_keymaps = true,
      default_mode = "coworker",
      default_system_prompt = nil,
      keymap_prefix = "<leader>o",
      opencode_executable = "opencode",
      server = {
        -- Use a dedicated process with the Neovim-only agent profile rather
        -- than attaching to OpenCode's shared native service.
        url = "http://127.0.0.1",
        port = 47631,
        password_file = vim.fn.stdpath("state") .. "/opencode/v1-47631.password",
        spawn_command = function(port, url, env)
          local server_env = vim.tbl_extend("force", env or {}, {
            OPENCODE_CONFIG = nvim_opencode_config,
          })
          local job_id = fn.jobstart({
            "opencode",
            "serve",
            "--port",
            tostring(port),
            "--hostname",
            "127.0.0.1",
          }, {
            detach = true,
            env = server_env,
          })
          if job_id <= 0 then
            error("failed to start Neovim OpenCode server (jobstart returned " .. job_id .. ")")
          end
          return fn.jobpid(job_id)
        end,
      },

      context = {
        current_file = {
          enabled = true,
        },
        diagnostics = {
          enabled = true,
        }
      },

      keymap = {
        editor = {
          ["<C-\\>"] = { toggle_panel },
          ["<leader>/"] = { "quick_chat", mode = { "n", "x" } },
          ["<leader>ot"] = { "configure_variant" },
          ["<leader>av"] = { add_visual_selection_inline, mode = { "v" }, desc = "Insert selection into OpenCode input", },
          ["<leader>af"] = { add_current_file, mode = { "n" } },
          ["<leader>oi"] = { open_input, mode = { "n" } },
          ["<leader>oa"] = { approve_step, mode = { "n" }, desc = "Approve the current OpenCode question", },
          ["<leader>oo"] = { open_output, mode = { "n" }, desc = "Open and refresh OpenCode output", },
          ["<leader>ox"] = { unload_attachments },
          ["<leader>on"] = { start_new_session },
          ["<leader>ov"] = { paste_image },
          ["<leader>ods"] = false,
        },

        input_window = {
          ["j"] = { function() vim.cmd("normal! gj") end, mode = "n" },
          ["k"] = { function() vim.cmd("normal! gk") end, mode = "n" },
          ["<leader>ods"] = false,
          ["<M-m>"] = false,
          ["<S-tab>"] = { switch_mode_with_profile, mode = { "n" } },
          ["<C-c>"] = {
            function()
              local ok, state = pcall(require, "opencode.state")
              if ok and state.jobs.is_running() then
                require("opencode.api").cancel()
              end
            end,
            mode = { "n" },
          },
        },
        output_window = {
          ["<leader>ods"] = false,
          ["j"] = { function() vim.cmd("normal! gj") end, mode = "n" },
          ["k"] = { function() vim.cmd("normal! gk") end, mode = "n" },
        }
      },

      ui = {
        restore_tabs_on_startup = false,
        window_width = 0.35,
        zoom_width = 0.8,
        picker_width = false,

        input = {
          text = {
            wrap = true,
          },
        },

        output = {
          tools = {
            show_output = false,
            show_reasoning_output = false,
          }
        }
      },
    })

    local notes_dir = vim.fs.normalize("/home/tyler/vault/obsidian-developer-vault")

    -- Warm up the OpenCode server without opening panels.
    vim.schedule(function()
      if #api.nvim_list_uis() == 0 then
        return
      end

      local cwd = vim.fs.normalize(fn.getcwd())
      local in_notes = cwd == notes_dir or cwd:sub(1, #notes_dir + 1) == notes_dir .. "/"
      if in_notes then
        return
      end

      require("opencode.server_job")
          .ensure_server()
          :catch(function(err)
            vim.notify("OpenCode server startup: " .. tostring(err), vim.log.levels.ERROR)
          end)
    end)

    vim.keymap.set("n", "<leader>ow", reset_window_width, {
      desc = "Reset opencode window size",
    })

    -- Delete all saved opencode sessions
    vim.keymap.set("n", "<leader>ods", delete_all_sessions, {
      desc = "Delete all opencode sessions",
    })

    -- Close open windows except the focused and opencode related windows.
    -- If focused on an opencode window, also keep the leftmost non-opencode window.
    vim.keymap.set("n", "<leader>wo", close_other_windows)
  end,
}
