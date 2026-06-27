local util = require("pi.util")

local M = {}

--- Build context from the current visual selection with line numbers
---@param prompt string|nil
---@return string
function M.from_selection(prompt)
  local lines, start_line, end_line = util.get_visual_selection()
  local code = table.concat(lines, "\n")
  local ft = util.get_filetype()
  local file = util.get_filepath()

  local parts = {}
  if prompt and #prompt > 0 then
    table.insert(parts, prompt)
  end
  table.insert(parts, string.format("File: `%s:%d-%d`", file, start_line, end_line))
  table.insert(parts, string.format("```%s\n%s\n```", ft, code))

  return table.concat(parts, "\n")
end

--- Build a file reference for the current buffer (no code content)
---@param prompt string|nil
---@return string
function M.from_file(prompt)
  local file = util.get_filepath()

  local parts = {}
  if prompt and #prompt > 0 then
    table.insert(parts, prompt)
  end
  table.insert(parts, string.format("@%s", file))

  return table.concat(parts, "\n")
end

--- Build context from the entire current buffer
---@param prompt string|nil
---@return string
function M.from_buffer(prompt)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local code = table.concat(lines, "\n")
  local ft = util.get_filetype()
  local file = util.get_filepath()

  local parts = {}
  if prompt and #prompt > 0 then
    table.insert(parts, prompt)
  end
  table.insert(parts, string.format("File: `%s`", file))
  table.insert(parts, string.format("```%s\n%s\n```", ft, code))

  return table.concat(parts, "\n")
end

return M
