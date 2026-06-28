local chat = require("pi.chat")
local util = require("pi.util")

local M = {}

local config

function M.setup(cfg)
  config = cfg
end

--- Run a named action (explain, review) on the visual selection
function M.run_action(action_name)
  local action = config.actions[action_name]
  if not action then
    vim.notify("[pi.nvim] Unknown action: " .. action_name, vim.log.levels.ERROR)
    return
  end

  local lines, start_line, end_line = util.get_visual_selection()
  if #lines == 0 then
    vim.notify("[pi.nvim] No selection", vim.log.levels.WARN)
    return
  end

  local code = table.concat(lines, "\n")
  local prompt = util.expand_prompt(action.prompt, {
    code = code,
    filetype = util.get_filetype(),
    file = util.get_filepath(),
    start_line = tostring(start_line),
    end_line = tostring(end_line),
  })

  chat.open({
    title = action.desc or action_name,
    initial_prompt = prompt,
  })
end

--- Free-form prompt on visual selection
function M.run_free()
  local lines, start_line, end_line = util.get_visual_selection()
  if #lines == 0 then
    vim.notify("[pi.nvim] No selection", vim.log.levels.WARN)
    return
  end

  local code = table.concat(lines, "\n")
  local ft = util.get_filetype()
  local file = util.get_filepath()
  local context = string.format("File: `%s:%d-%d`\n```%s\n%s\n```", file, start_line, end_line, ft, code)

  vim.ui.input({ prompt = "Pi: " }, function(prompt)
    if not prompt or #prompt == 0 then return end

    local full_prompt = table.concat({
      "You are assisting in a Neovim editor. The user selected code at " .. file .. ":" .. start_line .. "-" .. end_line .. ".",
      "",
      "Use your tools to explore context if needed before answering.",
      "",
      "User request: " .. prompt,
      "",
      context,
    }, "\n")

    chat.open({
      title = "Pi",
      initial_prompt = full_prompt,
    })
  end)
end

--- Explain LSP diagnostics at the cursor line
function M.run_diagnostic()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1] - 1
  local diagnostics = vim.diagnostic.get(0, { lnum = line })

  if #diagnostics == 0 then
    vim.notify("[pi.nvim] No diagnostics on this line", vim.log.levels.WARN)
    return
  end

  local severity_names = { "ERROR", "WARN", "INFO", "HINT" }
  local diag_text = {}
  for _, d in ipairs(diagnostics) do
    local sev = severity_names[d.severity] or "UNKNOWN"
    local source = d.source or "unknown"
    table.insert(diag_text, string.format("[%s] (%s): %s", sev, source, d.message))
  end

  local context_radius = 5
  local total_lines = vim.api.nvim_buf_line_count(0)
  local start_ctx = math.max(0, line - context_radius)
  local end_ctx = math.min(total_lines, line + context_radius + 1)
  local buf_lines = vim.api.nvim_buf_get_lines(0, start_ctx, end_ctx, false)
  local code = table.concat(buf_lines, "\n")
  local file = util.get_filepath()
  local ft = util.get_filetype()

  local prompt = table.concat({
    "You are assisting in a Neovim editor. The user has LSP diagnostics at " .. file .. ":" .. (line + 1) .. ".",
    "",
    "Diagnostics:",
    table.concat(diag_text, "\n"),
    "",
    "Use your tools to read the file and understand the surrounding context — imports, types, related code. Then explain:",
    "1. What this diagnostic means",
    "2. Why it's triggered here",
    "3. How to fix it",
    "",
    "Code around line " .. (line + 1) .. ":",
    "```" .. ft,
    code,
    "```",
  }, "\n")

  chat.open({
    title = "Explain Diagnostic",
    initial_prompt = prompt,
  })
end

--- Fix LSP diagnostics at the cursor line by editing the file directly
function M.run_fix()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1] - 1
  local diagnostics = vim.diagnostic.get(0, { lnum = line })

  if #diagnostics == 0 then
    vim.notify("[pi.nvim] No diagnostics on this line", vim.log.levels.WARN)
    return
  end

  local severity_names = { "ERROR", "WARN", "INFO", "HINT" }
  local diag_text = {}
  for _, d in ipairs(diagnostics) do
    local sev = severity_names[d.severity] or "UNKNOWN"
    local source = d.source or "unknown"
    table.insert(diag_text, string.format("[%s] (%s): %s", sev, source, d.message))
  end

  local context_radius = 5
  local total_lines = vim.api.nvim_buf_line_count(0)
  local start_ctx = math.max(0, line - context_radius)
  local end_ctx = math.min(total_lines, line + context_radius + 1)
  local buf_lines = vim.api.nvim_buf_get_lines(0, start_ctx, end_ctx, false)
  local code = table.concat(buf_lines, "\n")
  local file = util.get_filepath()
  local ft = util.get_filetype()

  local prompt = table.concat({
    "You are assisting in a Neovim editor. The user has LSP diagnostics at " .. file .. ":" .. (line + 1) .. ".",
    "",
    "Diagnostics:",
    table.concat(diag_text, "\n"),
    "",
    "If this is a straightforward fix, use your edit tool to apply it directly to the file. Be minimal — only change what's needed to resolve the diagnostic.",
    "",
    "If the fix is ambiguous or requires broader refactoring, explain the options instead of editing.",
    "",
    "Code around line " .. (line + 1) .. ":",
    "```" .. ft,
    code,
    "```",
  }, "\n")

  chat.open({
    title = "Fix Diagnostic",
    initial_prompt = prompt,
  })
end

--- Review uncommitted git changes in the current file
function M.run_git_review()
  local file = util.get_filepath()
  if file == "[unsaved]" then
    vim.notify("[pi.nvim] Buffer has no file", vim.log.levels.WARN)
    return
  end

  local diff = vim.fn.system({ "git", "diff", "--", file })
  local staged_diff = vim.fn.system({ "git", "diff", "--cached", "--", file })
  local combined = (diff or "") .. (staged_diff or "")

  if combined == "" then
    vim.notify("[pi.nvim] No uncommitted changes in this file", vim.log.levels.INFO)
    return
  end

  local prompt = table.concat({
    "You are reviewing uncommitted changes in a Neovim editor.",
    "",
    "File: " .. file,
    "",
    "Review the following git diff. Look for bugs, edge cases, missed error handling, and anything that could break. Be specific and reference line numbers from the diff.",
    "",
    "```diff",
    vim.fn.trim(combined),
    "```",
  }, "\n")

  chat.open({
    title = "Review Changes",
    initial_prompt = prompt,
  })
end

--- Free-form prompt without selection (normal mode)
function M.run_free_no_selection()
  vim.ui.input({ prompt = "Pi: " }, function(prompt)
    if not prompt or #prompt == 0 then return end

    local file = util.get_filepath()
    local full_prompt = table.concat({
      "You are assisting in a Neovim editor. The user is working on " .. file .. ".",
      "",
      "Use your tools to explore context if needed before answering.",
      "",
      "User request: " .. prompt,
    }, "\n")

    chat.open({
      title = "Pi",
      initial_prompt = full_prompt,
    })
  end)
end

return M
