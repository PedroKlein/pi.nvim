-- pi.nvim auto-loaded commands
-- These are available even before setup() is called,
-- but setup() must be called for keymaps and config.

if vim.g.loaded_pi then return end
vim.g.loaded_pi = true

-- User commands
vim.api.nvim_create_user_command("Pi", function()
  require("pi.terminal").toggle()
end, { desc = "Toggle Pi terminal" })

vim.api.nvim_create_user_command("PiSend", function(opts)
  local terminal = require("pi.terminal")
  if opts.range > 0 then
    local context = require("pi.context")
    terminal.send_submit(context.from_selection(opts.args))
  elseif #opts.args > 0 then
    terminal.send_submit(opts.args)
  else
    vim.notify("[pi.nvim] Usage: :PiSend <message> or visual select + :PiSend", vim.log.levels.WARN)
  end
end, { desc = "Send to Pi terminal", nargs = "*", range = true })

vim.api.nvim_create_user_command("PiQuick", function(opts)
  local quick = require("pi.quick")
  if #opts.args > 0 then
    quick.run_action(opts.args)
  else
    quick.run_free()
  end
end, { desc = "Quick Pi action", nargs = "?", range = true,
  complete = function()
    local cfg = require("pi.config").defaults
    return vim.tbl_keys(cfg.actions)
  end })

vim.api.nvim_create_user_command("PiModel", function()
  require("pi.models").pick_model()
end, { desc = "Switch Pi model" })

vim.api.nvim_create_user_command("PiThinking", function()
  require("pi.models").pick_thinking()
end, { desc = "Switch Pi thinking level" })

vim.api.nvim_create_user_command("PiSession", function(opts)
  local sessions = require("pi.sessions")
  if opts.args == "new" then
    sessions.new_session()
  elseif opts.args == "stats" then
    sessions.stats()
  else
    sessions.info()
  end
end, { desc = "Pi session management", nargs = "?",
  complete = function()
    return { "info", "new", "stats" }
  end })

vim.api.nvim_create_user_command("PiStop", function()
  require("pi.rpc").stop()
  require("pi.terminal").kill()
  vim.notify("[pi.nvim] All Pi processes stopped", vim.log.levels.INFO)
end, { desc = "Stop all Pi processes" })
