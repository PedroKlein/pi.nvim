local M = {}

---@class PiConfig
---@field split "vertical"|"horizontal"|"float" Split direction for the Pi terminal
---@field split_size number|nil Size of the split (width for vertical, height for horizontal)
---@field float_opts table|nil Options for floating window (if split = "float")
---@field model string|nil Default model (e.g. "anthropic/claude-sonnet-4-20250514")
---@field thinking string Thinking level: "off"|"minimal"|"low"|"medium"|"high"|"xhigh"
---@field pi_cmd string Path to the pi binary
---@field rpc_args string[] Extra args passed to the RPC process
---@field terminal_args string[] Extra args passed to the terminal process
---@field auto_reload boolean Auto-reload buffers when Pi edits files
---@field actions table<string, PiAction> Built-in and custom actions
---@field keymaps table<string, string|false> Keymap overrides (set to false to disable)

---@class PiAction
---@field prompt string Prompt template (use {code} and {filetype} placeholders)
---@field result "float"|"inline-diff"|"replace" How to display the result
---@field desc string Description for keybinding

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
  rpc_args = {},
  terminal_args = {},
  auto_reload = true,

  actions = {
    explain = {
      prompt = "Explain this code concisely:\n```{filetype}\n{code}\n```",
      result = "float",
      desc = "Explain selection",
    },
    refactor = {
      prompt = "Refactor this code for clarity and maintainability. Return ONLY the refactored code, no explanation:\n```{filetype}\n{code}\n```",
      result = "inline-diff",
      desc = "Refactor selection",
    },
    fix = {
      prompt = "Fix any bugs in this code. Return ONLY the fixed code, no explanation:\n```{filetype}\n{code}\n```",
      result = "inline-diff",
      desc = "Fix selection",
    },
    review = {
      prompt = "Review this code. List issues, potential bugs, and improvements:\n```{filetype}\n{code}\n```",
      result = "float",
      desc = "Review selection",
    },
    docs = {
      prompt = "Add documentation comments to this code. Return ONLY the documented code:\n```{filetype}\n{code}\n```",
      result = "inline-diff",
      desc = "Add docs to selection",
    },
    tests = {
      prompt = "Write tests for this code:\n```{filetype}\n{code}\n```",
      result = "float",
      desc = "Generate tests for selection",
    },
  },

  keymaps = {
    toggle = "<leader>ao",
    send = "<leader>as",
    quick = "<leader>aq",
    explain = "<leader>ae",
    refactor = "<leader>ar",
    fix = "<leader>af",
    review = "<leader>av",
    docs = "<leader>ad",
    tests = "<leader>at",
    model = "<leader>am",
    session = "<leader>ai",
  },
}

return M
