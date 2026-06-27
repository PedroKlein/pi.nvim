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
