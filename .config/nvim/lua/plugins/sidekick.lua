---@param opts? { filter?: sidekick.cli.Filter }
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
    -- add any options here
    cli = {
      mux = {
        backend = "tmux",
        enabled = true,
      },
      win = {
        keys = {
          hide_n = { "q", "false", mode = "n", desc = "hide the terminal window" },
        }
      }
    },
    nes = {
      enabled = false
    }
  },
  keys = {
    {
      "<tab>",
      function()
        -- if there is a next edit, jump to it, otherwise apply it if any
        if not require("sidekick").nes_jump_or_apply() then
          return "<Tab>" -- fallback to normal tab
        end
      end,
      expr = true,
      desc = "Goto/Apply Next Edit Suggestion",
    },
    {
      "<c-\\>",
      function() require("sidekick.cli").toggle() end,
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
