local util = require("pi.util")

local M = {}

---@type number|nil
local job_id = nil
---@type string
local buffer = ""
---@type table<string, function>
local pending = {} -- id → callback
---@type table<string, function[]>
local event_handlers = {} -- event type → list of handlers

local config

function M.setup(cfg)
  config = cfg
end

function M.start()
  if job_id then return end

  local cmd = { config.pi_cmd, "--mode", "rpc" }

  for _, flag in ipairs(config.rpc_flags or {}) do
    table.insert(cmd, flag)
  end

  if config.model then
    table.insert(cmd, "--model")
    table.insert(cmd, config.model)
  end

  if config.thinking then
    table.insert(cmd, "--thinking")
    table.insert(cmd, config.thinking)
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

function M.prewarm()
  vim.defer_fn(function()
    M.start()
  end, 100)
end

function M.stop()
  if job_id then
    vim.fn.jobstop(job_id)
    job_id = nil
  end
end

function M.is_running()
  return job_id ~= nil
end

--- Send an RPC command with optional response callback
function M.send(cmd, callback)
  M.start()
  if not job_id then
    if callback then callback({ success = false, error = "RPC process not running" }) end
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

--- Subscribe to an event type. Returns unsubscribe function.
function M.on(event_type, handler)
  if not event_handlers[event_type] then
    event_handlers[event_type] = {}
  end
  table.insert(event_handlers[event_type], handler)

  return function()
    local handlers = event_handlers[event_type]
    if not handlers then return end
    for i, h in ipairs(handlers) do
      if h == handler then
        table.remove(handlers, i)
        return
      end
    end
  end
end

function M._on_stdout(data)
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

function M._handle_event(event)
  if event.type == "response" and event.id and pending[event.id] then
    local cb = pending[event.id]
    pending[event.id] = nil
    cb(event)
    return
  end

  local handlers = event_handlers[event.type]
  if handlers then
    for _, handler in ipairs(handlers) do
      handler(event)
    end
  end
end

--- High-level streaming prompt. Returns a handle for the caller to
--- receive deltas, tool events, and completion.
---@param message string
---@return table handle { on_delta, on_tool, on_done, abort }
function M.prompt_stream(message)
  local handle = {
    _delta_cb = nil,
    _tool_cb = nil,
    _done_cb = nil,
  }

  function handle.on_delta(cb) handle._delta_cb = cb return handle end
  function handle.on_tool(cb) handle._tool_cb = cb return handle end
  function handle.on_done(cb) handle._done_cb = cb return handle end

  function handle.abort()
    M.send({ type = "abort" })
  end

  local unsubs = {}

  table.insert(unsubs, M.on("message_update", function(event)
    local delta = event.assistantMessageEvent
    if delta and delta.type == "text_delta" and handle._delta_cb then
      handle._delta_cb(delta.delta)
    end
  end))

  table.insert(unsubs, M.on("tool_execution_start", function(event)
    if handle._tool_cb then
      handle._tool_cb({ status = "start", tool = event.toolName, args = event.args })
    end
  end))

  table.insert(unsubs, M.on("tool_execution_end", function(event)
    if handle._tool_cb then
      handle._tool_cb({ status = "end", tool = event.toolName })
    end
  end))

  table.insert(unsubs, M.on("agent_end", function()
    for _, unsub in ipairs(unsubs) do unsub() end
    if handle._done_cb then handle._done_cb() end
  end))

  -- Store unsubs so abort can clean up
  function handle.cleanup()
    for _, unsub in ipairs(unsubs) do unsub() end
  end

  M.send({ type = "prompt", message = message }, function(resp)
    if not resp.success then
      for _, unsub in ipairs(unsubs) do unsub() end
      vim.notify("[pi.nvim] Prompt failed: " .. (resp.error or "unknown"), vim.log.levels.ERROR)
    end
  end)

  return handle
end

--- Reset the RPC session (wipe conversation, keep process alive)
function M.new_session(callback)
  M.send({ type = "new_session" }, function(resp)
    if callback then callback(resp) end
  end)
end

--- Get available models
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
function M.set_model(provider, model_id, callback)
  M.send({ type = "set_model", provider = provider, modelId = model_id }, callback)
end

--- Set thinking level
function M.set_thinking(level, callback)
  M.send({ type = "set_thinking_level", level = level }, callback)
end

--- Get current state
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
