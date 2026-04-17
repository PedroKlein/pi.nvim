local util = require("pi.util")

local M = {}

--- Build context from the current visual selection
---@param prompt string|nil Optional prompt to prepend
---@return string formatted message ready to send
function M.from_selection(prompt)
  local lines = util.get_visual_selection()
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

--- Build context from the entire current buffer
---@param prompt string|nil Optional prompt to prepend
---@return string formatted message ready to send
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

--- Build context from nvim diagnostics for the current buffer
---@return string|nil formatted diagnostics or nil if none
function M.from_diagnostics()
  local diags = vim.diagnostic.get(0)
  if #diags == 0 then return nil end

  local parts = { "Current diagnostics:" }
  for _, d in ipairs(diags) do
    local severity = vim.diagnostic.severity[d.severity] or "UNKNOWN"
    table.insert(parts, string.format(
      "  Line %d: [%s] %s",
      d.lnum + 1, severity, d.message
    ))
  end

  return table.concat(parts, "\n")
end

return M
