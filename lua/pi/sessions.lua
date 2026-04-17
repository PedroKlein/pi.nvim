local rpc = require("pi.rpc")

local M = {}

--- Start a new RPC session
function M.new_session()
  rpc.send({ type = "new_session" }, function(resp)
    if resp.success then
      vim.notify("[pi.nvim] New session started", vim.log.levels.INFO)
    else
      vim.notify("[pi.nvim] Failed: " .. (resp.error or "unknown"), vim.log.levels.ERROR)
    end
  end)
end

--- Show session info
function M.info()
  rpc.get_state(function(state)
    if not state then
      vim.notify("[pi.nvim] RPC not running", vim.log.levels.WARN)
      return
    end

    local lines = {
      "Pi Session Info",
      "═══════════════",
      string.format("Model: %s", state.model and (state.model.provider .. "/" .. state.model.id) or "none"),
      string.format("Thinking: %s", state.thinkingLevel or "off"),
      string.format("Streaming: %s", state.isStreaming and "yes" or "no"),
      string.format("Messages: %d", state.messageCount or 0),
      string.format("Session: %s", state.sessionFile or "in-memory"),
    }
    if state.sessionName then
      table.insert(lines, string.format("Name: %s", state.sessionName))
    end

    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
  end)
end

--- Get session stats (tokens, cost)
function M.stats()
  rpc.send({ type = "get_session_stats" }, function(resp)
    if not resp.success or not resp.data then
      vim.notify("[pi.nvim] No stats available", vim.log.levels.WARN)
      return
    end

    local d = resp.data
    local tokens = d.tokens or {}
    local lines = {
      "Pi Session Stats",
      "════════════════",
      string.format("Messages: %d user, %d assistant, %d tool calls",
        d.userMessages or 0, d.assistantMessages or 0, d.toolCalls or 0),
      string.format("Tokens: %d input, %d output, %d total",
        tokens.input or 0, tokens.output or 0, tokens.total or 0),
      string.format("Cost: $%.4f", d.cost or 0),
    }

    if d.contextUsage then
      table.insert(lines, string.format("Context: %d/%d (%d%%)",
        d.contextUsage.tokens or 0,
        d.contextUsage.contextWindow or 0,
        d.contextUsage.percent or 0))
    end

    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
  end)
end

return M
