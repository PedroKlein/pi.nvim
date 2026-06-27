local M = {}

---@type number|nil
local term_bufnr = nil
---@type number|nil
local term_chanid = nil
---@type number|nil
local term_winid = nil
---@type "split"|"float"
local current_mode = "split"

local config

function M.setup(cfg)
  config = cfg
end

function M.is_open()
  return term_bufnr ~= nil
    and vim.api.nvim_buf_is_valid(term_bufnr)
    and term_chanid ~= nil
end

function M.is_visible()
  return M.is_open()
    and term_winid ~= nil
    and vim.api.nvim_win_is_valid(term_winid)
end

function M.open()
  M._open_with_mode(config.split == "float" and "float" or "split")
end

function M.open_float()
  M._open_with_mode("float")
end

function M._open_with_mode(mode)
  if M.is_visible() then
    vim.api.nvim_set_current_win(term_winid)
    vim.cmd("startinsert")
    return
  end

  -- Buffer exists but window was closed
  if M.is_open() then
    M._create_window(mode)
    vim.api.nvim_win_set_buf(term_winid, term_bufnr)
    M._apply_win_opts(term_winid)
    vim.cmd("startinsert")
    return
  end

  -- Fresh start
  M._create_window(mode)
  current_mode = mode

  local cmd = { config.pi_cmd }
  for _, arg in ipairs(config.terminal_args or {}) do
    table.insert(cmd, arg)
  end

  term_chanid = vim.fn.termopen(cmd, {
    on_exit = function()
      term_bufnr = nil
      term_chanid = nil
      if term_winid and vim.api.nvim_win_is_valid(term_winid) then
        vim.api.nvim_win_close(term_winid, true)
      end
      term_winid = nil
    end,
  })
  term_bufnr = vim.api.nvim_get_current_buf()

  pcall(vim.api.nvim_buf_set_name, term_bufnr, "pi://terminal")
  M._apply_win_opts(term_winid)
  M._setup_keymaps()
  vim.cmd("startinsert")
end

function M._create_window(mode)
  if mode == "float" then
    local opts = config.float_opts or {}
    local width = opts.width or 0.8
    local height = opts.height or 0.8
    if width <= 1 then width = math.floor(vim.o.columns * width) end
    if height <= 1 then height = math.floor(vim.o.lines * height) end

    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    local buf = vim.api.nvim_create_buf(false, true)
    term_winid = vim.api.nvim_open_win(buf, true, {
      relative = "editor",
      width = width,
      height = height,
      row = row,
      col = col,
      border = (opts.border or "rounded"),
      style = "minimal",
    })
  else
    local size = ""
    if config.split_size then
      local s = config.split_size
      if s > 0 and s <= 1 then s = math.floor(vim.o.columns * s) end
      size = tostring(s)
    end
    vim.cmd(size .. "vsplit | enew")
    term_winid = vim.api.nvim_get_current_win()
  end
end

function M._apply_win_opts(win)
  if not win or not vim.api.nvim_win_is_valid(win) then return end
  vim.api.nvim_set_option_value("number", false, { win = win })
  vim.api.nvim_set_option_value("relativenumber", false, { win = win })
  vim.api.nvim_set_option_value("signcolumn", "no", { win = win })
  vim.api.nvim_set_option_value("foldcolumn", "0", { win = win })
  vim.api.nvim_set_option_value("colorcolumn", "", { win = win })
  vim.api.nvim_set_option_value("cursorline", false, { win = win })
  pcall(vim.api.nvim_set_option_value, "statuscolumn", "", { win = win })
end

function M._setup_keymaps()
  if not term_bufnr then return end
  local buf = term_bufnr
  local opts = { buffer = buf, silent = true }

  vim.keymap.set("t", "<Esc><Esc>", [[<C-\><C-n>]], vim.tbl_extend("force", opts, { desc = "Exit terminal mode" }))

  local toggle_key = config.keymaps and config.keymaps.toggle or "<leader>ao"
  vim.keymap.set("t", toggle_key, function()
    vim.cmd("stopinsert")
    M.hide()
  end, vim.tbl_extend("force", opts, { desc = "Pi: Hide terminal" }))

  vim.keymap.set("t", "<C-h>", [[<C-\><C-n><C-w>h]], vim.tbl_extend("force", opts, { desc = "Go left" }))
  vim.keymap.set("t", "<C-j>", [[<C-\><C-n><C-w>j]], vim.tbl_extend("force", opts, { desc = "Go down" }))
  vim.keymap.set("t", "<C-k>", [[<C-\><C-n><C-w>k]], vim.tbl_extend("force", opts, { desc = "Go up" }))
  vim.keymap.set("t", "<C-l>", [[<C-\><C-n><C-w>l]], vim.tbl_extend("force", opts, { desc = "Go right" }))
end

function M.hide()
  if term_winid and vim.api.nvim_win_is_valid(term_winid) then
    vim.api.nvim_win_close(term_winid, true)
    term_winid = nil
  end
end

function M.toggle()
  if M.is_visible() then
    M.hide()
  else
    M.open()
  end
end

function M.toggle_float()
  if M.is_visible() and current_mode == "float" then
    M.hide()
  else
    if M.is_visible() then M.hide() end
    M.open_float()
    current_mode = "float"
  end
end

--- Send text to the terminal. If terminal isn't open, opens it first and
--- waits for the channel to be ready via TermOpen event.
function M.send(text)
  if not M.is_open() then
    M.open()
    -- Wait for terminal to be ready (channel established)
    vim.wait(2000, function() return term_chanid ~= nil end, 50)
  end

  if term_chanid then
    vim.api.nvim_chan_send(term_chanid, text)
  end
end

function M.send_submit(text)
  M.send(text .. "\n")
end

function M.kill()
  if term_chanid then
    pcall(vim.fn.jobstop, term_chanid)
    term_chanid = nil
    term_bufnr = nil
    if term_winid and vim.api.nvim_win_is_valid(term_winid) then
      pcall(vim.api.nvim_win_close, term_winid, true)
    end
    term_winid = nil
  end
end

return M
