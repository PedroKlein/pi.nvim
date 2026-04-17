# pi.nvim

Neovim plugin for [Pi coding agent](https://github.com/badlogic/pi-mono) — two modes of interaction:

1. **Terminal mode** — Pi's full TUI in a split, with nvim feeding it context
2. **Quick actions** — Headless RPC for instant explain/refactor/fix on selections

## Requirements

- Neovim ≥ 0.10
- [Pi](https://github.com/badlogic/pi-mono) installed globally: `npm install -g @mariozechner/pi-coding-agent`

## Installation

### lazy.nvim

```lua
{
  "PedroKlein/pi.nvim",
  cmd = { "Pi", "PiSend", "PiQuick", "PiModel", "PiThinking", "PiSession", "PiStop" },
  keys = {
    { "<leader>ao", desc = "Pi: Toggle terminal" },
    { "<leader>as", desc = "Pi: Send selection", mode = "v" },
    { "<leader>aq", desc = "Pi: Quick action", mode = "v" },
    { "<leader>ae", desc = "Pi: Explain", mode = "v" },
    { "<leader>ar", desc = "Pi: Refactor", mode = "v" },
    { "<leader>af", desc = "Pi: Fix", mode = "v" },
    { "<leader>av", desc = "Pi: Review", mode = "v" },
    { "<leader>ad", desc = "Pi: Add docs", mode = "v" },
    { "<leader>at", desc = "Pi: Generate tests", mode = "v" },
    { "<leader>am", desc = "Pi: Switch model" },
  },
  opts = {},
  config = function(_, opts)
    require("pi").setup(opts)
  end,
}
```

### Local development

For development, point lazy.nvim to the local path:

```lua
{
  dir = "~/Dev/Personal/pi.nvim",
  opts = {},
  config = function(_, opts)
    require("pi").setup(opts)
  end,
}
```

## Usage

### Commands

| Command                         | Description                                               |
| ------------------------------- | --------------------------------------------------------- |
| `:Pi`                           | Toggle Pi terminal split                                  |
| `:PiSend <msg>`                 | Send message (with optional visual selection) to terminal |
| `:'<,'>PiQuick [action]`        | Quick action on selection (or free-form prompt)           |
| `:PiModel`                      | Pick model via `vim.ui.select`                            |
| `:PiThinking`                   | Pick thinking level                                       |
| `:PiSession [info\|new\|stats]` | Session management                                        |
| `:PiStop`                       | Kill all Pi processes                                     |

### Default Keymaps

All keymaps use the `<leader>a` prefix (AI).

| Key          | Mode | Action                              |
| ------------ | ---- | ----------------------------------- |
| `<leader>ao` | n    | Toggle Pi terminal                  |
| `<leader>as` | v    | Send selection + prompt to terminal |
| `<leader>aq` | v    | Free-form quick action on selection |
| `<leader>ae` | v    | Explain selection (float)           |
| `<leader>ar` | v    | Refactor selection (inline diff)    |
| `<leader>af` | v    | Fix selection (inline diff)         |
| `<leader>av` | v    | Review selection (float)            |
| `<leader>ad` | v    | Add docs (inline diff)              |
| `<leader>at` | v    | Generate tests (float)              |
| `<leader>am` | n    | Switch model                        |
| `<leader>ai` | n    | Session info                        |

### Quick Actions

Quick actions use Pi's RPC mode for headless operations. Results display based on the action type:

- **Float**: `explain`, `review`, `tests` — opens a floating window with the response
- **Inline diff**: `refactor`, `fix`, `docs` — shows a diff split; `<leader>pa` to accept, `<leader>px` to reject

### Terminal Mode

`:Pi` opens Pi's full interactive TUI in a split. Use `<leader>as` in visual mode to send selected code with a prompt directly into the terminal.

While inside the terminal buffer (terminal mode), the following keymaps are available:

| Key              | Action                                  |
| ---------------- | --------------------------------------- |
| `<Esc><Esc>`     | Exit terminal mode → normal mode        |
| `<leader>ao`     | Hide the terminal (toggle key)          |
| `<C-h/j/k/l>`   | Navigate to adjacent windows            |

## Configuration

````lua
require("pi").setup({
  -- Terminal split direction: "vertical", "horizontal", or "float"
  split = "vertical",
  split_size = 0.4, -- fraction (0-1) or absolute number (cols for vertical, rows for horizontal)

  -- Float options (when split = "float")
  float_opts = {
    relative = "editor",
    width = 0.8,
    height = 0.8,
    border = "rounded",
  },

  -- Model defaults (for RPC process)
  model = nil, -- e.g. "anthropic/claude-sonnet-4-20250514"
  thinking = "medium",

  -- Pi binary
  pi_cmd = "pi",
  rpc_args = {},      -- extra args for the RPC process
  terminal_args = {}, -- extra args for the terminal process

  -- Auto-reload buffers when Pi edits files
  auto_reload = true,

  -- Custom actions (merged with built-in actions)
  actions = {
    my_action = {
      prompt = "Do something with {file}:\n```{filetype}\n{code}\n```",
      result = "float", -- "float", "inline-diff", or "replace"
      desc = "My custom action",
    },
  },

  -- Keymap overrides (set to false to disable)
  keymaps = {
    toggle = "<leader>ao",
    send = "<leader>as",
    quick = "<leader>aq",
    -- ...
  },
})
````

## Architecture

```
┌──────────────────────────────────────────────┐
│  nvim                                        │
│                                              │
│  ┌──────────────┐    ┌─────────────────────┐ │
│  │ Code Buffers │───→│ pi.nvim (Lua)       │ │
│  │              │←───│                     │ │
│  └──────────────┘    └──┬──────────┬───────┘ │
│                         │          │         │
│               ┌─────────┴──┐  ┌───┴───────┐ │
│               │ RPC Client │  │ Terminal   │ │
│               │ pi --mode  │  │ Buffer     │ │
│               │   rpc      │  │ pi (TUI)   │ │
│               │ (headless) │  │ (interact) │ │
│               └────────────┘  └───────────┘ │
└──────────────────────────────────────────────┘
```

- **RPC process**: Headless, for quick actions. Spawned on demand, stays alive for the session.
- **Terminal process**: Full Pi TUI in a `:terminal` buffer. You interact with it directly; nvim sends context into it.

## License

MIT
