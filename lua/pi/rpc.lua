local util = require("pi.util")

local M = {}

---@type number|nil
local job_id = nil
---@type string
local buffer = ""
---@type table<string, function>
local pending = {} -- id → callback
---@type table<string, function>
local event_handlers = {} -- event type → handler

local config -- set via M.setup()

function M.setup(cfg)
  config = cfg
end

--- Start the RPC subprocess (if not already running)
function M.start()
  if job_id then return end

  local cmd = { config.pi_cmd, "--mode", "rpc", "--no-session", "--no-extensions" }

  if config.model then
    table.insert(cmd, "--model")
    table.insert(cmd, config.model)
  end

  if config.thinking then
    table.insert(cmd, "--thinking")
    table.insert(cmd, config.thinking)
  end

  for _, arg in ipairs(config.rpc_args or {}) do
    table.insert(cmd, arg)
  end

  buffer = ""
  job_id = vim.fn.jobstart(cmd, {
    on_stdout = function(_, data)
      M._on_stdout(data)
    end,
    on_stderr = function(_, data)
      for _, line in ipairs(data) do
        if line and #line > 0 then
          vim.schedule(function()
            vim.notify("[pi.nvim rpc stderr] " .. line, vim.log.levels.DEBUG)
          end)
        end
      end
    end,
    on_exit = function(_, code)
      job_id = nil
      buffer = ""
      pending = {}
      if code ~= 0 and code ~= 143 then
        vim.schedule(function()
          vim.notify("[pi.nvim] RPC process exited with code " .. code, vim.log.levels.WARN)
        end)
      end
    end,
    stdout_buffered = false,
  })

  if not job_id or job_id <= 0 then
    vim.notify("[pi.nvim] Failed to start RPC process. Is `" .. config.pi_cmd .. "` installed?", vim.log.levels.ERROR)
    job_id = nil
  end
end

--- Stop the RPC subprocess
function M.stop()
  if job_id then
    vim.fn.jobstop(job_id)
    job_id = nil
  end
end

--- Check if the RPC process is running
---@return boolean
function M.is_running()
  return job_id ~= nil
end

--- Send an RPC command
---@param cmd table The command object (type, etc.)
---@param callback function|nil Called with the response
function M.send(cmd, callback)
  M.start()
  if not job_id then
    if callback then
      callback({ success = false, error = "RPC process not running" })
    end
    return
  end
  local id = util.id()
  cmd.id = id
  if callback then
    pending[id] = callback
  end
  local json = vim.json.encode(cmd) .. "\n"
  vim.fn.chansend(job_id, json)
end

--- Register an event handler for streaming events
---@param event_type string
---@param handler function
---@return function unsubscribe
function M.on(event_type, handler)
  event_handlers[event_type] = handler
  return function()
    if event_handlers[event_type] == handler then
      event_handlers[event_type] = nil
    end
  end
end

--- Process stdout data from the RPC process.
--- nvim's jobstart on_stdout gives a list of strings split by newlines.
--- E.g. ["partial"] or ["end of prev", "start of next"] or ["complete", ""].
---@param data string[]
function M._on_stdout(data)
  -- nvim splits on \n, so join with \n to reconstruct the stream
  -- The last element is always "" if the chunk ended with \n,
  -- or a partial line if it didn't.
  for i, chunk in ipairs(data) do
    if i > 1 then
      buffer = buffer .. "\n"
    end
    buffer = buffer .. chunk
  end

  local events, remainder = util.parse_jsonl(buffer)
  buffer = remainder

  if #events > 0 then
    vim.schedule(function()
      for _, event in ipairs(events) do
        M._handle_event(event)
      end
    end)
  end
end

--- Route an event to the appropriate handler
---@param event table
function M._handle_event(event)
  -- Response to a pending request
  if event.type == "response" and event.id and pending[event.id] then
    local cb = pending[event.id]
    pending[event.id] = nil
    cb(event)
    return
  end

  -- Streaming event → registered handler
  local handler = event_handlers[event.type]
  if handler then
    handler(event)
  end
end

-- Convenience wrappers for common RPC commands

--- Send a prompt
---@param message string
---@param callback function|nil
function M.prompt(message, callback)
  M.send({ type = "prompt", message = message }, callback)
end

--- Abort current operation
---@param callback function|nil
function M.abort(callback)
  M.send({ type = "abort" }, callback)
end

--- Get available models
---@param callback function Called with response.data.models
function M.get_models(callback)
  M.send({ type = "get_available_models" }, function(resp)
    if resp.success and resp.data then
      callback(resp.data.models)
    else
      callback({})
    end
  end)
end

--- Set model
---@param provider string
---@param model_id string
---@param callback function|nil
function M.set_model(provider, model_id, callback)
  M.send({ type = "set_model", provider = provider, modelId = model_id }, callback)
end

--- Set thinking level
---@param level string
---@param callback function|nil
function M.set_thinking(level, callback)
  M.send({ type = "set_thinking_level", level = level }, callback)
end

--- Get current state
---@param callback function
function M.get_state(callback)
  M.send({ type = "get_state" }, function(resp)
    if resp.success and resp.data then
      callback(resp.data)
    else
      callback(nil)
    end
  end)
end

return M
