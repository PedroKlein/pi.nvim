local config = require("pi.config")

local M = {}

---@type PiConfig
M.config = {}

--- Setup pi.nvim with user options
---@param opts PiConfig|nil
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", config.defaults, opts or {})

  -- Initialize submodules
  require("pi.terminal").setup(M.config)
  require("pi.rpc").setup(M.config)
  require("pi.quick").setup(M.config)

  -- Setup auto-reload for file changes
  if M.config.auto_reload then
    M._setup_auto_reload()
  end

  -- Register keymaps
  M._setup_keymaps()
end

--- Setup autoread + checktime for picking up Pi's file edits
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

--- Setup keymaps from config
function M._setup_keymaps()
  local km = M.config.keymaps
  if not km then return end

  local function nmap(key, fn, desc)
    if key and key ~= false then
      vim.keymap.set("n", key, fn, { desc = desc, silent = true })
    end
  end

  --- Visual mode keymaps need to:
  --- 1. Exit visual mode (so '< '> marks are set)
  --- 2. Then call the function
  local function vmap(key, fn, desc)
    if key and key ~= false then
      vim.keymap.set("v", key, function()
        -- Exit visual mode to set '< '> marks, then call in normal mode
        local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
        vim.api.nvim_feedkeys(esc, "x", false)
        -- Defer to next event loop tick so marks are updated
        vim.schedule(fn)
      end, { desc = desc, silent = true })
    end
  end

  local terminal = require("pi.terminal")
  local quick = require("pi.quick")
  local models = require("pi.models")
  local sessions = require("pi.sessions")

  -- Terminal
  nmap(km.toggle, terminal.toggle, "Pi: Toggle terminal")

  -- Send selection to terminal
  vmap(km.send, function()
    local context = require("pi.context")
    vim.ui.input({ prompt = "Message for Pi: " }, function(prompt)
      if not prompt then return end
      terminal.send_submit(context.from_selection(prompt))
    end)
  end, "Pi: Send selection to terminal")

  -- Quick actions (visual mode)
  vmap(km.quick, quick.run_free, "Pi: Quick action on selection")
  vmap(km.explain, function() quick.run_action("explain") end, "Pi: Explain selection")
  vmap(km.refactor, function() quick.run_action("refactor") end, "Pi: Refactor selection")
  vmap(km.fix, function() quick.run_action("fix") end, "Pi: Fix selection")
  vmap(km.review, function() quick.run_action("review") end, "Pi: Review selection")
  vmap(km.docs, function() quick.run_action("docs") end, "Pi: Add docs")
  vmap(km.tests, function() quick.run_action("tests") end, "Pi: Generate tests")

  -- Model / session (normal mode)
  nmap(km.model, models.pick_model, "Pi: Switch model")
  nmap(km.session, sessions.info, "Pi: Session info")
end

return M
