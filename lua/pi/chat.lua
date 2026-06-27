local rpc = require("pi.rpc")

local M = {}

---@class PiChat
---@field output_buf number
---@field output_win number
---@field input_buf number
---@field input_win number
---@field handle table|nil
---@field streaming boolean
---@field title string
local Chat = {}
Chat.__index = Chat

--- Open a new ephemeral chat with an initial prompt
---@param opts { title: string, initial_prompt: string }
---@return PiChat
function M.open(opts)
  local self = setmetatable({
    streaming = false,
    title = opts.title or "Pi",
  }, Chat)

  self:_create_windows()
  self:_setup_keymaps()

  -- Reset RPC session then send initial prompt
  rpc.new_session(function()
    self:_send_prompt(opts.initial_prompt)
  end)

  return self
end

function Chat:_create_windows()
  local width = math.floor(vim.o.columns * 0.7)
  local total_height = math.floor(vim.o.lines * 0.7)
  local input_height = 3
  local output_height = total_height - input_height - 2 -- 2 for borders

  local start_row = math.floor((vim.o.lines - total_height) / 2)
  local start_col = math.floor((vim.o.columns - width) / 2)

  -- Output buffer (readonly markdown)
  self.output_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[self.output_buf].filetype = "markdown"
  vim.bo[self.output_buf].bufhidden = "wipe"

  self.output_win = vim.api.nvim_open_win(self.output_buf, true, {
    relative = "editor",
    width = width,
    height = output_height,
    row = start_row,
    col = start_col,
    border = "rounded",
    title = " " .. self.title .. " ",
    title_pos = "center",
    style = "minimal",
  })
  vim.api.nvim_set_option_value("wrap", true, { win = self.output_win })
  vim.api.nvim_set_option_value("linebreak", true, { win = self.output_win })

  -- Input buffer (editable)
  self.input_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[self.input_buf].filetype = "markdown"
  vim.bo[self.input_buf].bufhidden = "wipe"

  self.input_win = vim.api.nvim_open_win(self.input_buf, false, {
    relative = "editor",
    width = width,
    height = input_height,
    row = start_row + output_height + 2,
    col = start_col,
    border = "rounded",
    title = " Input ",
    title_pos = "left",
    style = "minimal",
  })

  -- Focus stays on output initially (streaming will start there)
end

function Chat:_setup_keymaps()
  local output_opts = { buffer = self.output_buf, silent = true }
  local input_opts = { buffer = self.input_buf, silent = true }

  -- Close
  vim.keymap.set("n", "q", function() self:close() end, output_opts)
  vim.keymap.set("n", "q", function() self:close() end, input_opts)

  -- Tab toggles focus
  vim.keymap.set("n", "<Tab>", function() self:_focus_input() end, output_opts)
  vim.keymap.set("n", "<Tab>", function() self:_focus_output() end, input_opts)
  vim.keymap.set("i", "<Tab>", function()
    vim.cmd("stopinsert")
    self:_focus_output()
  end, input_opts)

  -- i from output jumps to input in insert mode
  vim.keymap.set("n", "i", function() self:_focus_input(true) end, output_opts)
  vim.keymap.set("n", "a", function() self:_focus_input(true) end, output_opts)

  -- Esc from input insert mode goes to output
  vim.keymap.set("i", "<Esc>", function()
    vim.cmd("stopinsert")
    self:_focus_output()
  end, input_opts)

  -- Enter in input sends the message
  vim.keymap.set("n", "<CR>", function() self:_submit_input() end, input_opts)
  vim.keymap.set("i", "<CR>", function() self:_submit_input() end, input_opts)

  -- Ctrl-c aborts without closing
  vim.keymap.set("n", "<C-c>", function() self:_abort() end, output_opts)
  vim.keymap.set("n", "<C-c>", function() self:_abort() end, input_opts)
end

function Chat:_focus_input(insert)
  if self.input_win and vim.api.nvim_win_is_valid(self.input_win) then
    vim.api.nvim_set_current_win(self.input_win)
    if insert then vim.cmd("startinsert") end
  end
end

function Chat:_focus_output()
  if self.output_win and vim.api.nvim_win_is_valid(self.output_win) then
    vim.api.nvim_set_current_win(self.output_win)
  end
end

function Chat:_submit_input()
  if self.streaming then return end

  local lines = vim.api.nvim_buf_get_lines(self.input_buf, 0, -1, false)
  local text = vim.trim(table.concat(lines, "\n"))
  if #text == 0 then return end

  -- Clear input
  vim.api.nvim_buf_set_lines(self.input_buf, 0, -1, false, { "" })
  vim.cmd("stopinsert")

  -- Show user message in output
  self:_append_output("")
  self:_append_output("**You:** " .. text)
  self:_append_output("")

  self:_send_prompt(text)
end

function Chat:_send_prompt(message)
  self.streaming = true
  self:_set_input_readonly(true)

  self.handle = rpc.prompt_stream(message)
    :on_delta(function(delta)
      self:_append_delta(delta)
    end)
    :on_tool(function(event)
      if event.status == "start" then
        local label = event.tool
        if event.args then
          if event.args.command then
            label = label .. ": " .. event.args.command
          elseif event.args.path then
            label = label .. ": " .. event.args.path
          elseif event.args.pattern then
            label = label .. ": " .. event.args.pattern
          end
        end
        self:_append_output("❯ " .. label)
      end
    end)
    :on_done(function()
      self.streaming = false
      self.handle = nil
      self:_set_input_readonly(false)
      self:_append_output("")
      self:_focus_input(true)
    end)
end

function Chat:_append_delta(text)
  if not self.output_buf or not vim.api.nvim_buf_is_valid(self.output_buf) then return end

  -- Temporarily make writable
  vim.bo[self.output_buf].modifiable = true

  local lines = vim.api.nvim_buf_get_lines(self.output_buf, -2, -1, false)
  local last_line = lines[1] or ""

  -- Split delta by newlines and append
  local parts = vim.split(text, "\n", { plain = true })
  parts[1] = last_line .. parts[1]

  local line_count = vim.api.nvim_buf_line_count(self.output_buf)
  vim.api.nvim_buf_set_lines(self.output_buf, line_count - 1, line_count, false, parts)

  vim.bo[self.output_buf].modifiable = false
  self:_scroll_to_bottom()
end

function Chat:_append_output(line)
  if not self.output_buf or not vim.api.nvim_buf_is_valid(self.output_buf) then return end

  vim.bo[self.output_buf].modifiable = true

  local line_count = vim.api.nvim_buf_line_count(self.output_buf)
  -- If buffer is empty (single empty line), replace it
  if line_count == 1 then
    local first = vim.api.nvim_buf_get_lines(self.output_buf, 0, 1, false)[1]
    if first == "" then
      vim.api.nvim_buf_set_lines(self.output_buf, 0, 1, false, { line })
      vim.bo[self.output_buf].modifiable = false
      return
    end
  end

  vim.api.nvim_buf_set_lines(self.output_buf, line_count, line_count, false, { line })
  vim.bo[self.output_buf].modifiable = false
  self:_scroll_to_bottom()
end

function Chat:_scroll_to_bottom()
  if self.output_win and vim.api.nvim_win_is_valid(self.output_win) then
    local line_count = vim.api.nvim_buf_line_count(self.output_buf)
    pcall(vim.api.nvim_win_set_cursor, self.output_win, { line_count, 0 })
  end
end

function Chat:_set_input_readonly(readonly)
  if self.input_buf and vim.api.nvim_buf_is_valid(self.input_buf) then
    vim.bo[self.input_buf].modifiable = not readonly
  end
end

function Chat:_abort()
  if self.handle then
    self.handle.abort()
    self.handle.cleanup()
    self.handle = nil
    self.streaming = false
    self:_set_input_readonly(false)
    self:_append_output("")
    self:_append_output("*(aborted)*")
  end
end

function Chat:close()
  if self.handle then
    self.handle.abort()
    self.handle.cleanup()
    self.handle = nil
  end

  if self.output_win and vim.api.nvim_win_is_valid(self.output_win) then
    vim.api.nvim_win_close(self.output_win, true)
  end
  if self.input_win and vim.api.nvim_win_is_valid(self.input_win) then
    vim.api.nvim_win_close(self.input_win, true)
  end

  self.output_win = nil
  self.input_win = nil
  self.output_buf = nil
  self.input_buf = nil
  self.streaming = false
end

return M
