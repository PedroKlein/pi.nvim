local rpc = require("pi.rpc")
local result = require("pi.result")
local util = require("pi.util")

local M = {}

local config -- set via M.setup()

function M.setup(cfg)
  config = cfg
end

--- Run a quick action on the visual selection
---@param action_name string Key into config.actions
function M.run_action(action_name)
  local action = config.actions[action_name]
  if not action then
    vim.notify("[pi.nvim] Unknown action: " .. action_name, vim.log.levels.ERROR)
    return
  end

  local lines, start_line, end_line = util.get_visual_selection()
  if #lines == 0 then
    vim.notify("[pi.nvim] No selection found", vim.log.levels.WARN)
    return
  end

  vim.notify("[pi.nvim] Running '" .. action_name .. "' on " .. #lines .. " lines...", vim.log.levels.INFO)

  local code = table.concat(lines, "\n")
  local ft = util.get_filetype()

  local prompt = util.expand_prompt(action.prompt, {
    code = code,
    filetype = ft,
    file = util.get_filepath(),
  })

  M.run(prompt, {
    result_type = action.result,
    title = action.desc or action_name,
    original_bufnr = vim.api.nvim_get_current_buf(),
    start_line = start_line,
    end_line = end_line,
  })
end

--- Run a free-form quick prompt (ask user for prompt, then send with selection)
function M.run_free()
  local lines, start_line, end_line = util.get_visual_selection()
  if #lines == 0 then return end

  local code = table.concat(lines, "\n")
  local ft = util.get_filetype()
  local file = util.get_filepath()
  local bufnr = vim.api.nvim_get_current_buf()

  vim.ui.input({ prompt = "Pi: " }, function(prompt)
    if not prompt or #prompt == 0 then return end

    local full_prompt = string.format(
      "%s\n\nFile: `%s`\n```%s\n%s\n```",
      prompt, file, ft, code
    )

    M.run(full_prompt, {
      result_type = "float",
      title = "Pi",
      original_bufnr = bufnr,
      start_line = start_line,
      end_line = end_line,
    })
  end)
end

--- Run a prompt via RPC and handle the streaming response
---@param prompt string The full prompt to send
---@param opts table { result_type, title, original_bufnr, start_line, end_line }
function M.run(prompt, opts)
  local collected_text = ""
  local result_shown = false

  vim.notify("[pi.nvim] Thinking...", vim.log.levels.INFO)

  -- Listen for streaming text
  local unsub_update = rpc.on("message_update", function(event)
    local delta = event.assistantMessageEvent
    if delta and delta.type == "text_delta" then
      collected_text = collected_text .. delta.delta
    end
  end)

  -- Listen for completion
  local unsub_end
  unsub_end = rpc.on("agent_end", function()
    unsub_update()
    if unsub_end then unsub_end() end

    if result_shown then return end
    result_shown = true

    M._show_result(collected_text, opts)
  end)

  -- Send the prompt
  rpc.prompt(prompt, function(resp)
    if not resp.success then
      unsub_update()
      unsub_end()
      vim.notify("[pi.nvim] Prompt failed: " .. (resp.error or "unknown"), vim.log.levels.ERROR)
    end
  end)
end

--- Display the result based on the action's result_type
---@param text string The response text
---@param opts table
function M._show_result(text, opts)
  if not text or #text == 0 then
    vim.notify("[pi.nvim] Empty response from Pi", vim.log.levels.WARN)
    return
  end

  vim.notify("[pi.nvim] Response received (" .. #text .. " chars)", vim.log.levels.INFO)

  local result_type = opts.result_type or "float"

  if result_type == "float" then
    result.show_float(text, { title = opts.title })
  elseif result_type == "inline-diff" then
    -- Strip markdown code fences if present
    local clean = M._strip_code_fences(text)
    result.show_inline_diff(
      opts.original_bufnr,
      opts.start_line,
      opts.end_line,
      clean
    )
  elseif result_type == "replace" then
    local clean = M._strip_code_fences(text)
    local new_lines = vim.split(clean, "\n")
    if #new_lines > 0 and new_lines[#new_lines] == "" then
      table.remove(new_lines)
    end
    vim.api.nvim_buf_set_lines(opts.original_bufnr, opts.start_line - 1, opts.end_line, false, new_lines)
    vim.notify("[pi.nvim] Selection replaced", vim.log.levels.INFO)
  end
end

--- Strip markdown code fences from a response
---@param text string
---@return string
function M._strip_code_fences(text)
  -- Remove opening ```lang and closing ```
  local stripped = text:gsub("^%s*```%w*%s*\n", ""):gsub("\n%s*```%s*$", "")
  return stripped
end

return M
