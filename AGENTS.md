# AGENTS.md

## What this project is

A Neovim plugin (pure Lua) that wraps the Pi coding agent. Two modes: RPC-based quick actions in floating chat windows, and a full terminal session.

## Module responsibilities

- `config.lua`: Default config, type definitions. Nothing else.
- `rpc.lua`: Owns the RPC subprocess lifecycle. Sends commands, routes events, manages subscriptions.
- `chat.lua`: Owns the mini-chat UI (two stacked floats). Handles streaming display, user input, window lifecycle.
- `quick.lua`: Glue between actions and chat. Expands prompt templates, opens chat with the expanded prompt.
- `terminal.lua`: Owns the terminal buffer/window. Split and float modes. Sends text to Pi's TUI stdin.
- `context.lua`: Formats editor context (selection, file references) into text for terminal sends.
- `util.lua`: Pure utility functions (id generation, JSONL parsing, visual selection, prompt expansion).
- `models.lua` / `sessions.lua`: Thin wrappers around RPC commands for model/session management.
- `init.lua`: Setup, keymaps, auto-reload. Wires modules together.
- `plugin/pi.lua`: User commands. Loaded before setup.

## Code style

- Minimal comments. Explain "why" when something is non-obvious. Never comment "what" the code does.
- No redundant type annotations on obvious locals.
- Functions should be short and named clearly enough to not need a docstring.
- Avoid deep nesting. Early return over else branches.

## RPC protocol

The plugin communicates with `pi --mode rpc` over stdin/stdout using newline-delimited JSON. Key events:

- `message_update` with `assistantMessageEvent.type == "text_delta"`: streaming text chunks
- `tool_execution_start` / `tool_execution_end`: Pi reading files, searching, running commands
- `agent_end`: response complete
- Send `{ type: "new_session" }` to reset context between mini-chat opens

The RPC process runs with `--no-session --no-extensions --no-skills --no-prompt-templates --no-themes` for minimal startup time. Built-in tools (read, grep, bash, ls) remain available.

## Testing

No automated test suite currently. Verification is manual in Neovim. Key things to check after changes:

1. `:Pi` opens terminal split, `<leader>aO` opens float
2. Visual select + `<leader>ae` opens mini-chat with streaming response
3. Follow-up messages work in mini-chat
4. `q` closes mini-chat cleanly (no orphan windows or processes)
5. `<leader>as` in visual mode sends selection to terminal
6. `q` (normal) and `<C-q>` (terminal mode) hide the terminal float
7. `:PiStop` kills everything
