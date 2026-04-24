-- NoetherVim ftplugin: markdown
-- Smart list continuation keymap.
-- wrap / linebreak / spell / conceallevel / <C-l> spell-fix come from
-- the prose profile in autocmds.lua.

local function shift_enter()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()

  -- Helper: insert a new line with the given prefix at the cursor position.
  local function continue_with(prefix)
    vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, { "", prefix })
    vim.api.nvim_win_set_cursor(0, { row + 1, #prefix })
  end

  -- Helper: on an empty item (marker only), remove the marker and exit the list.
  local function exit_list(ws)
    vim.api.nvim_set_current_line(ws)
    vim.api.nvim_win_set_cursor(0, { row, #ws })
  end

  -- Checkbox list: "  - [ ] text" or "  * [x] text"
  local ws, marker, rest = line:match("^(%s*)([-*+])%s+%[.%]%s(.*)")
  if ws and marker then
    if rest == "" then exit_list(ws); return end
    continue_with(ws .. marker .. " [ ] ")
    return
  end

  -- Unordered list: "  - text", "  * text", "  + text"
  ws, marker, rest = line:match("^(%s*)([-*+])%s(.*)")
  if ws and marker then
    if rest == "" then exit_list(ws); return end
    continue_with(ws .. marker .. " ")
    return
  end

  -- Ordered list: "  1. text"
  local ws_num, num
  ws_num, num, rest = line:match("^(%s*)(%d+)%.%s(.*)")
  if ws_num and num then
    if rest == "" then exit_list(ws_num); return end
    continue_with(ws_num .. tostring(tonumber(num) + 1) .. ". ")
    return
  end

  -- Blockquote: "> text"
  local ws_bq, bq = line:match("^(%s*)(>+%s)")
  if ws_bq and bq then
    continue_with(ws_bq .. bq)
    return
  end

  -- Fallback: plain newline
  continue_with("")
end

vim.keymap.set("i", "<s-cr>", shift_enter, { buf = 0, silent = true, desc = "smart list continuation" })
