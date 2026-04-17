local rpc = require("pi.rpc")

local M = {}

--- Open a picker to switch models
function M.pick_model()
  rpc.get_models(function(models)
    if not models or #models == 0 then
      vim.notify("[pi.nvim] No models available", vim.log.levels.WARN)
      return
    end

    local items = {}
    for _, m in ipairs(models) do
      table.insert(items, {
        label = string.format("%s/%s", m.provider, m.id),
        provider = m.provider,
        model_id = m.id,
        name = m.name,
        context = m.contextWindow,
      })
    end

    vim.ui.select(items, {
      prompt = "Select Pi model:",
      format_item = function(item)
        local ctx = item.context and string.format(" (%dk ctx)", item.context / 1000) or ""
        return item.label .. ctx
      end,
    }, function(choice)
      if not choice then return end
      rpc.set_model(choice.provider, choice.model_id, function(resp)
        if resp.success then
          vim.notify("[pi.nvim] Model set to " .. choice.label, vim.log.levels.INFO)
        else
          vim.notify("[pi.nvim] Failed to set model: " .. (resp.error or "unknown"), vim.log.levels.ERROR)
        end
      end)
    end)
  end)
end

--- Open a picker to switch thinking level
function M.pick_thinking()
  local levels = { "off", "minimal", "low", "medium", "high", "xhigh" }

  vim.ui.select(levels, {
    prompt = "Select thinking level:",
  }, function(choice)
    if not choice then return end
    rpc.set_thinking(choice, function(resp)
      if resp.success then
        vim.notify("[pi.nvim] Thinking level set to " .. choice, vim.log.levels.INFO)
      else
        vim.notify("[pi.nvim] Failed: " .. (resp.error or "unknown"), vim.log.levels.ERROR)
      end
    end)
  end)
end

return M
