local M = {}

--- Generate a simple unique id for RPC request correlation
---@return string
function M.id()
  return string.format("%s-%s", os.clock(), math.random(100000))
end

--- Get the visual selection as a list of lines.
--- Must be called AFTER exiting visual mode (e.g. keymap should use <Esc> first
--- or be mapped from normal mode after visual).
---@return string[] lines
---@return number start_line (1-indexed)
---@return number end_line (1-indexed)
function M.get_visual_selection()
  -- Ensure we're in normal mode so marks are updated
  local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
  vim.api.nvim_feedkeys(esc, "nx", false)

  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local start_line = start_pos[2]
  local end_line = end_pos[2]

  if start_line == 0 or end_line == 0 then
    vim.notify("[pi.nvim] No visual selection found", vim.log.levels.WARN)
    return {}, 0, 0
  end

  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)

  -- Handle partial line selection for character-wise visual mode
  local mode = vim.fn.visualmode()
  if mode == "v" and #lines > 0 then
    local start_col = start_pos[3]
    local end_col = end_pos[3]
    if #lines == 1 then
      lines[1] = string.sub(lines[1], start_col, end_col)
    else
      lines[1] = string.sub(lines[1], start_col)
      lines[#lines] = string.sub(lines[#lines], 1, end_col)
    end
  end

  return lines, start_line, end_line
end

--- Get the filetype of the current buffer
---@return string
function M.get_filetype()
  return vim.bo.filetype or ""
end

--- Get the current buffer's file path (relative to cwd if possible)
---@return string
function M.get_filepath()
  local path = vim.fn.expand("%:.")
  return path ~= "" and path or "[unsaved]"
end

--- Expand placeholders in a prompt template
--- Uses plain string replacement (no Lua pattern magic)
---@param template string
---@param vars table<string, string>
---@return string
function M.expand_prompt(template, vars)
  local result = template
  for k, v in pairs(vars) do
    -- Use plain find/replace to avoid issues with % in code
    local placeholder = "{" .. k .. "}"
    local start = 1
    while true do
      local i, j = result:find(placeholder, start, true)
      if not i then break end
      result = result:sub(1, i - 1) .. v .. result:sub(j + 1)
      start = i + #v
    end
  end
  return result
end

--- Parse a JSONL buffer: extracts complete JSON lines, returns remainder
---@param buffer string
---@return table[] events Parsed JSON objects
---@return string remainder Unparsed leftover
function M.parse_jsonl(buffer)
  local events = {}
  local remainder = buffer

  while true do
    local nl = remainder:find("\n")
    if not nl then break end

    local line = remainder:sub(1, nl - 1)
    remainder = remainder:sub(nl + 1)

    -- Strip trailing \r
    if line:sub(-1) == "\r" then
      line = line:sub(1, -2)
    end

    if #line > 0 then
      local ok, obj = pcall(vim.json.decode, line)
      if ok then
        table.insert(events, obj)
      end
    end
  end

  return events, remainder
end

return M
