--a-@param opts? { filter?: sidekick.cli.Filter }
local function sidekick_cli_kill(opts)
  local Cli = require("sidekick.cli")
  local State = require("sidekick.cli.state")
  local Util = require("sidekick.util")

  ---@param state sidekick.cli.State
  local function kill(state)
    if not state then
      return
    end
    State.detach(state)
    if state.session and state.session.mux_session then
      if state.session.backend == "tmux" or state.session.mux_backend == "tmux" then
        Util.exec({ "tmux", "kill-session", "-t", state.session.mux_session })
      end
    end
  end

  opts = opts or {}
  Cli.select({
    auto = true,
    filter = Util.merge(opts.filter, { started = true }),
    cb = kill,
  })
end

return {
  "folke/sidekick.nvim",
  opts = {
    cli = {
      tools = {
        opencode = {
          cmd = { "opencode" },
          env = { OPENCODE_THEME = "system" },
        },
      },
      mux = {
        backend = "tmux",
        enabled = false,
      },
      win = {
        split = {
          width = 120
        },
        keys = {
          prompt    = { "<a-p>", "prompt", mode = "t", desc = "insert prompt or context" },
          hide_n    = false,
          files     = false,
          nav_left  = false,
          nav_down  = false,
          nav_up    = false,
          nav_right = false,
        }
      }
    },
    nes = {
      enabled = false
    }
  },
  keys = {
    {
      "<c-\\>",
      function() require("sidekick.cli").toggle({ name = "opencode", focus = true }) end,
      desc = "Sidekick Toggle",
      mode = { "n", "t", "i", "x" },
    },
    {
      "<leader>as",
      function() require("sidekick.cli").select() end,
      desc = "Select CLI",
    },
    {
      "<leader>ad",
      function() require("sidekick.cli").close() end,
      desc = "Detach a CLI Session",
    },
    {
      "<leader>at",
      function() require("sidekick.cli").send({ msg = "{this}" }) end,
      mode = { "x", "n" },
      desc = "Send This",
    },
    {
      "<leader>af",
      function() require("sidekick.cli").send({ msg = "{file}" }) end,
      desc = "Send File",
    },
    {
      "<leader>av",
      function() require("sidekick.cli").send({ msg = "{selection}" }) end,
      mode = { "x" },
      desc = "Send Visual Selection",
    },
    {
      "<leader>ap",
      function() require("sidekick.cli").prompt() end,
      mode = { "n", "x" },
      desc = "Sidekick Select Prompt",
    },
    {
      "<leader>ak",
      sidekick_cli_kill,
      desc = "Kill (Sidekick)"
    },
  },
}
