-- diff_modal.lua -- floating-window y/n confirmation that displays a unified
-- diff body.  Used by bundle_toggle.lua and intended to be reused by future
-- file-rewriting features (e.g. template stamping).

local M = {}

---@class noethervim.DiffModalOpts
---@field diff    string                 -- unified diff text (with header)
---@field title   string                 -- shown in the floating window border
---@field on_done fun(accepted: boolean) -- called once with the user's choice

---@param opts noethervim.DiffModalOpts
function M.confirm(opts)
  local diff_text = opts.diff or ""
  local title     = opts.title or "Confirm changes"
  local on_done   = opts.on_done or function() end

  local lines = vim.split(diff_text, "\n", { plain = true })
  -- Drop the trailing empty line that vim.diff's output usually carries so
  -- the prompt sits flush with the diff body.
  if lines[#lines] == "" then table.remove(lines) end
  table.insert(lines, "")
  table.insert(lines, "[y]es / [n]o   (Esc / q to cancel)")

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype   = "diff"
  vim.bo[buf].modifiable = false
  vim.bo[buf].buftype    = "nofile"
  vim.bo[buf].bufhidden  = "wipe"

  local width  = math.min(120, vim.o.columns - 8)
  local height = math.min(#lines + 2, vim.o.lines - 8)
  local row    = math.floor((vim.o.lines - height) / 2)
  local col    = math.floor((vim.o.columns - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative  = "editor",
    width     = width,
    height    = height,
    row       = row,
    col       = col,
    style     = "minimal",
    border    = "rounded",
    title     = " " .. title .. " ",
    title_pos = "center",
  })

  local closed = false
  local function close(accepted)
    if closed then return end
    closed = true
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    on_done(accepted)
  end

  local function map(key, accepted)
    vim.keymap.set("n", key, function() close(accepted) end,
      { buffer = buf, nowait = true, silent = true })
  end
  map("y", true);  map("Y", true)
  map("n", false); map("N", false)
  map("q", false); map("<Esc>", false)

  -- Treat any other dismissal (e.g. window closed externally, picker resumed)
  -- as a rejection so the orchestrator's on_done always fires exactly once.
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    once   = true,
    callback = function() close(false) end,
  })
end

return M
