local config = require("pi.config")

local M = {}

---@type PiConfig
M.config = {}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", config.defaults, opts or {})

  require("pi.terminal").setup(M.config)
  require("pi.rpc").setup(M.config)
  require("pi.quick").setup(M.config)

  if M.config.auto_reload then
    M._setup_auto_reload()
  end

  if M.config.prewarm then
    require("pi.rpc").prewarm()
  end

  M._setup_keymaps()
end

function M._setup_auto_reload()
  vim.o.autoread = true
  local group = vim.api.nvim_create_augroup("PiAutoReload", { clear = true })
  vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold" }, {
    group = group,
    pattern = "*",
    callback = function()
      if vim.fn.getcmdwintype() == "" then
        vim.cmd("checktime")
      end
    end,
  })
end

function M._setup_keymaps()
  local km = M.config.keymaps
  if not km then return end

  local terminal = require("pi.terminal")
  local quick = require("pi.quick")
  local models = require("pi.models")
  local sessions = require("pi.sessions")
  local context = require("pi.context")

  -- Normal mode keymaps
  local function nmap(key, fn, desc)
    if key and key ~= false then
      vim.keymap.set("n", key, fn, { desc = desc, silent = true })
    end
  end

  -- Visual mode: exit visual, schedule the function so marks are set
  local function vmap(key, fn, desc)
    if key and key ~= false then
      vim.keymap.set("v", key, function()
        local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
        vim.api.nvim_feedkeys(esc, "x", false)
        vim.schedule(fn)
      end, { desc = desc, silent = true })
    end
  end

  nmap(km.toggle, terminal.toggle, "Pi: Toggle terminal")
  nmap(km.toggle_float, terminal.toggle_float, "Pi: Toggle terminal (float)")

  -- Unified send: visual sends selection + prompt, normal sends @file + prompt
  vmap(km.send, function()
    vim.ui.input({ prompt = "Message for Pi: " }, function(prompt)
      if not prompt then return end
      terminal.send_submit(context.from_selection(prompt))
    end)
  end, "Pi: Send to terminal")

  nmap(km.send, function()
    vim.ui.input({ prompt = "Message for Pi: " }, function(prompt)
      if not prompt then return end
      terminal.send_submit(context.from_file(prompt))
    end)
  end, "Pi: Send file to terminal")

  -- Quick actions (visual only)
  vmap(km.quick, quick.run_free, "Pi: Quick action on selection")
  vmap(km.explain, function() quick.run_action("explain") end, "Pi: Explain selection")
  vmap(km.review, function() quick.run_action("review") end, "Pi: Review selection")

  -- Model / session
  nmap(km.model, models.pick_model, "Pi: Switch model")
  nmap(km.session, sessions.info, "Pi: Session info")

  -- Register which-key group
  local ok, wk = pcall(require, "which-key")
  if ok then
    wk.add({ { "<leader>a", group = "AI (Pi)" } })
  end
end

return M
