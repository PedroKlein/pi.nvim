local M = {}

---@class PiAction
---@field prompt string
---@field desc string

---@class PiConfig
---@field split "vertical"|"horizontal"|"float"
---@field split_size number|nil
---@field float_opts table|nil
---@field model string|nil
---@field thinking string
---@field pi_cmd string
---@field rpc_flags string[]
---@field terminal_args string[]
---@field prewarm boolean
---@field auto_reload boolean
---@field actions table<string, PiAction>
---@field keymaps table<string, string|false>

---@type PiConfig
M.defaults = {
  split = "vertical",
  split_size = 0.4,
  float_opts = {
    relative = "editor",
    width = 0.8,
    height = 0.8,
    border = "rounded",
  },
  model = nil,
  thinking = "medium",
  pi_cmd = "pi",
  prewarm = true,
  auto_reload = true,

  -- RPC process flags (terminal uses plain pi with user's config)
  rpc_flags = {
    "--no-session",
    "--no-extensions",
    "--no-skills",
    "--no-prompt-templates",
    "--no-themes",
  },

  -- Extra args appended to terminal process
  terminal_args = {},

  actions = {
    explain = {
      prompt = table.concat({
        "You are reviewing code in a Neovim editor. The user selected code at {file}:{start_line}-{end_line}.",
        "",
        "Before answering, use your tools to read the file and understand the surrounding context — imports, types, callers, and callees. Then explain clearly what this code does, why it exists, and how it fits into the broader system.",
        "",
        "Selected code:",
        "```{filetype}",
        "{code}",
        "```",
      }, "\n"),
      desc = "Explain selection",
    },
    review = {
      prompt = table.concat({
        "You are reviewing code in a Neovim editor. The user selected code at {file}:{start_line}-{end_line}.",
        "",
        "Before answering, use your tools to explore the codebase — read related files, check how this code is used, and understand the surrounding architecture. Then provide a focused code review: identify bugs, edge cases, design issues, and missed error handling. Be specific and reference line numbers.",
        "",
        "Selected code:",
        "```{filetype}",
        "{code}",
        "```",
      }, "\n"),
      desc = "Review selection",
    },
  },

  keymaps = {
    toggle = "<leader>ao",
    toggle_float = "<leader>aO",
    send = "<leader>as",
    quick = "<leader>aq",
    explain = "<leader>ae",
    review = "<leader>av",
    model = "<leader>am",
    session = "<leader>ai",
    resume = "<leader>ar",
  },
}

return M
