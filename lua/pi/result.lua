local M = {}

---@type number|nil
local float_bufnr = nil
---@type number|nil
local float_winid = nil

--- Show text in a floating window
---@param text string
---@param opts table|nil { title?: string, filetype?: string }
function M.show_float(text, opts)
  opts = opts or {}

  -- Close existing float
  M.close_float()

  local lines = vim.split(text, "\n")

  -- Calculate dimensions
  local max_width = 0
  for _, line in ipairs(lines) do
    max_width = math.max(max_width, #line)
  end
  local width = math.min(math.max(max_width + 2, 40), math.floor(vim.o.columns * 0.8))
  local height = math.min(#lines + 1, math.floor(vim.o.lines * 0.7))

  float_bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(float_bufnr, 0, -1, false, lines)
  vim.bo[float_bufnr].modifiable = false
  vim.bo[float_bufnr].filetype = opts.filetype or "markdown"

  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  float_winid = vim.api.nvim_open_win(float_bufnr, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    border = "rounded",
    title = opts.title and (" " .. opts.title .. " ") or nil,
    title_pos = opts.title and "center" or nil,
    style = "minimal",
  })

  -- Close on q or Escape
  vim.keymap.set("n", "q", function() M.close_float() end, { buffer = float_bufnr })
  vim.keymap.set("n", "<Esc>", function() M.close_float() end, { buffer = float_bufnr })
end

--- Close the floating result window
function M.close_float()
  if float_winid and vim.api.nvim_win_is_valid(float_winid) then
    vim.api.nvim_win_close(float_winid, true)
  end
  if float_bufnr and vim.api.nvim_buf_is_valid(float_bufnr) then
    vim.api.nvim_buf_delete(float_bufnr, { force = true })
  end
  float_winid = nil
  float_bufnr = nil
end

--- Apply an inline diff: replace lines in the original buffer
--- Shows the diff in a vertical split for review before accepting
---@param original_bufnr number Buffer to modify
---@param start_line number 1-indexed start line
---@param end_line number 1-indexed end line
---@param new_text string Replacement text
function M.show_inline_diff(original_bufnr, start_line, end_line, new_text)
  local new_lines = vim.split(new_text, "\n")

  -- Remove trailing empty line if present (common from code blocks)
  if #new_lines > 0 and new_lines[#new_lines] == "" then
    table.remove(new_lines)
  end

  -- Create a scratch buffer with the proposed change
  local diff_bufnr = vim.api.nvim_create_buf(false, true)
  local original_lines = vim.api.nvim_buf_get_lines(original_bufnr, 0, -1, false)

  -- Build the proposed full file
  local proposed = {}
  for i = 1, start_line - 1 do
    table.insert(proposed, original_lines[i])
  end
  for _, line in ipairs(new_lines) do
    table.insert(proposed, line)
  end
  for i = end_line + 1, #original_lines do
    table.insert(proposed, original_lines[i])
  end

  vim.api.nvim_buf_set_lines(diff_bufnr, 0, -1, false, proposed)
  vim.bo[diff_bufnr].filetype = vim.bo[original_bufnr].filetype

  -- Open diff view
  vim.cmd("vsplit")
  local diff_winid = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(diff_winid, diff_bufnr)
  vim.cmd("diffthis")

  -- Switch to original and enable diff
  vim.cmd("wincmd p")
  vim.cmd("diffthis")

  -- Keybindings in diff buffer: accept or reject
  vim.keymap.set("n", "<leader>pa", function()
    -- Accept: apply the changes to the original buffer
    vim.api.nvim_buf_set_lines(original_bufnr, start_line - 1, end_line, false, new_lines)
    vim.cmd("diffoff!")
    vim.api.nvim_win_close(diff_winid, true)
    vim.api.nvim_buf_delete(diff_bufnr, { force = true })
    vim.notify("[pi.nvim] Changes applied", vim.log.levels.INFO)
  end, { buffer = diff_bufnr, desc = "Accept Pi changes" })

  vim.keymap.set("n", "<leader>px", function()
    -- Reject: close diff without applying
    vim.cmd("diffoff!")
    vim.api.nvim_win_close(diff_winid, true)
    vim.api.nvim_buf_delete(diff_bufnr, { force = true })
    vim.notify("[pi.nvim] Changes rejected", vim.log.levels.INFO)
  end, { buffer = diff_bufnr, desc = "Reject Pi changes" })

  vim.notify("[pi.nvim] Review diff: <leader>pa to accept, <leader>px to reject", vim.log.levels.INFO)
end

return M
