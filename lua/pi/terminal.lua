local M = {}

---@type number|nil
local term_bufnr = nil
---@type number|nil
local term_chanid = nil
---@type number|nil
local term_winid = nil

local config -- set via M.setup()

function M.setup(cfg)
  config = cfg
end

--- Check if the terminal is alive
---@return boolean
function M.is_open()
  return term_bufnr ~= nil
    and vim.api.nvim_buf_is_valid(term_bufnr)
    and term_chanid ~= nil
end

--- Check if the terminal window is visible
---@return boolean
function M.is_visible()
  return M.is_open()
    and term_winid ~= nil
    and vim.api.nvim_win_is_valid(term_winid)
end

--- Open the Pi terminal (or focus if already open)
function M.open()
  if M.is_visible() then
    vim.api.nvim_set_current_win(term_winid)
    vim.cmd("startinsert")
    return
  end

  -- Buffer exists but window was closed — reopen it
  if M.is_open() then
    M._open_split()
    vim.api.nvim_win_set_buf(term_winid, term_bufnr)
    M._setup_terminal_window()
    vim.cmd("startinsert")
    return
  end

  -- Fresh start: create split first, then termopen in it
  M._open_split()

  local cmd = { config.pi_cmd }
  for _, arg in ipairs(config.terminal_args or {}) do
    table.insert(cmd, arg)
  end

  term_chanid = vim.fn.termopen(cmd, {
    on_exit = function()
      term_bufnr = nil
      term_chanid = nil
      -- Close the window if it's still around
      if term_winid and vim.api.nvim_win_is_valid(term_winid) then
        vim.api.nvim_win_close(term_winid, true)
      end
      term_winid = nil
    end,
  })
  term_bufnr = vim.api.nvim_get_current_buf()

  -- Name the buffer for easy identification
  pcall(vim.api.nvim_buf_set_name, term_bufnr, "pi://terminal")

  -- Clean up the terminal window: no line numbers, sign column, etc.
  M._setup_terminal_window()

  -- Terminal-mode keymaps (buffer-local to the Pi terminal)
  M._setup_terminal_keymaps()

  -- Enter terminal mode
  vim.cmd("startinsert")
end

--- Clean terminal window: disable line numbers, sign column, etc.
function M._setup_terminal_window()
  if not term_winid or not vim.api.nvim_win_is_valid(term_winid) then return end
  M._apply_terminal_win_opts(term_winid)

  -- Re-apply on BufEnter/WinEnter to fight LazyVim autocmds that restore line numbers
  if term_bufnr and vim.api.nvim_buf_is_valid(term_bufnr) then
    local group = vim.api.nvim_create_augroup("PiTerminalClean", { clear = true })
    vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter", "TermOpen" }, {
      group = group,
      buffer = term_bufnr,
      callback = function()
        local win = vim.api.nvim_get_current_win()
        M._apply_terminal_win_opts(win)
      end,
    })
  end
end

--- Apply clean window options to a window
---@param win number
function M._apply_terminal_win_opts(win)
  if not win or not vim.api.nvim_win_is_valid(win) then return end
  vim.api.nvim_set_option_value("number", false, { win = win })
  vim.api.nvim_set_option_value("relativenumber", false, { win = win })
  vim.api.nvim_set_option_value("signcolumn", "no", { win = win })
  vim.api.nvim_set_option_value("foldcolumn", "0", { win = win })
  vim.api.nvim_set_option_value("colorcolumn", "", { win = win })
  vim.api.nvim_set_option_value("cursorline", false, { win = win })
  pcall(vim.api.nvim_set_option_value, "statuscolumn", "", { win = win })
end

--- Setup keymaps local to the Pi terminal buffer
function M._setup_terminal_keymaps()
  if not term_bufnr then return end
  local buf = term_bufnr
  local opts = { buffer = buf, silent = true }

  -- <Esc><Esc> exits terminal mode → normal mode
  vim.keymap.set("t", "<Esc><Esc>", [[<C-\><C-n>]], vim.tbl_extend("force", opts, { desc = "Exit terminal mode" }))

  -- Toggle Pi from terminal mode without leaving it first
  local toggle_key = config.keymaps and config.keymaps.toggle or "<leader>ao"
  vim.keymap.set("t", toggle_key, function()
    vim.cmd([[stopinsert]])
    M.hide()
  end, vim.tbl_extend("force", opts, { desc = "Pi: Hide terminal" }))

  -- <C-h/j/k/l> to navigate away from terminal to other windows
  vim.keymap.set("t", "<C-h>", [[<C-\><C-n><C-w>h]], vim.tbl_extend("force", opts, { desc = "Go to left window" }))
  vim.keymap.set("t", "<C-j>", [[<C-\><C-n><C-w>j]], vim.tbl_extend("force", opts, { desc = "Go to below window" }))
  vim.keymap.set("t", "<C-k>", [[<C-\><C-n><C-w>k]], vim.tbl_extend("force", opts, { desc = "Go to above window" }))
  vim.keymap.set("t", "<C-l>", [[<C-\><C-n><C-w>l]], vim.tbl_extend("force", opts, { desc = "Go to right window" }))
end

--- Create the split/float window (places cursor in the new window)
function M._open_split()
  local split = config.split or "vertical"

  if split == "float" then
    local opts = config.float_opts or {}
    local width = opts.width or 0.8
    local height = opts.height or 0.8

    -- Convert ratios to absolute values
    if width <= 1 then width = math.floor(vim.o.columns * width) end
    if height <= 1 then height = math.floor(vim.o.lines * height) end

    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    -- For float: create a scratch buffer that termopen will use
    local buf = vim.api.nvim_create_buf(false, true)
    term_winid = vim.api.nvim_open_win(buf, true, {
      relative = "editor",
      width = width,
      height = height,
      row = row,
      col = col,
      border = opts.border or "rounded",
      style = "minimal",
    })
  elseif split == "horizontal" then
    local size = ""
    if config.split_size then
      local s = config.split_size
      if s > 0 and s <= 1 then s = math.floor(vim.o.lines * s) end
      size = tostring(s)
    end
    vim.cmd(size .. "split | enew")
    term_winid = vim.api.nvim_get_current_win()
  else
    -- vertical (default)
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

--- Close the terminal window (but keep the process alive)
function M.hide()
  if term_winid and vim.api.nvim_win_is_valid(term_winid) then
    vim.api.nvim_win_close(term_winid, true)
    term_winid = nil
  end
end

--- Toggle the terminal
function M.toggle()
  if M.is_visible() then
    M.hide()
  else
    M.open()
  end
end

--- Send text to the Pi terminal's stdin (types into Pi's editor)
---@param text string
function M.send(text)
  if not M.is_open() then
    M.open()
    -- Small delay to let Pi's TUI initialize before sending
    vim.defer_fn(function()
      if term_chanid then
        vim.api.nvim_chan_send(term_chanid, text)
      end
    end, 500)
    return
  end

  vim.api.nvim_chan_send(term_chanid, text)
end

--- Send text and submit it (press Enter)
---@param text string
function M.send_submit(text)
  M.send(text .. "\n")
end

--- Kill the terminal process
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
