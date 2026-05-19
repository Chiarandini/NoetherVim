--- Direction-aware window resizing.
---
--- Default :resize / :vertical resize grows the current window by
--- preferring its right/bottom border, falling back to the left/top
--- when the window is already against the screen edge. That makes the
--- arrow-key bindings feel inverted in the "right-most window" case.
---
--- This module instead binds *direction of motion* to the arrow:
---   grow_right grows the right edge rightward, requires a right neighbor;
---   grow_left  grows the left  edge leftward,  requires a left  neighbor;
---   grow_down  grows the bottom edge downward, requires a bottom neighbor;
---   grow_up    grows the top   edge upward,    requires a top   neighbor.
---
--- shrink_* moves the same edge the other way. Every operation is a
--- silent no-op when the relevant neighbor is missing, so pressing
--- <Left> in the leftmost window does nothing (instead of secretly
--- pushing the right edge inward, which is the surprising legacy
--- behaviour).
---
--- Built on |win_move_separator()| and |win_move_statusline()|, which
--- treat the resize like a mouse drag of the inter-window border. Note
--- that win_move_statusline() on the bottom-most window will happily
--- swallow rows from 'cmdheight' if you let it -- we forbid that by
--- guarding every operation with an explicit neighbor() check.

local M = {}

--- Step size (columns/rows) for every direction by default.
M.amount = 2

--- Return the winid of the neighbor in {dir} ("h"/"j"/"k"/"l"), or nil.
--- Uses |winnr()| with an explicit count so we never have to switch
--- windows (no WinEnter/WinLeave side effects).
local function neighbor(dir)
  local cur = vim.fn.winnr()
  local nbr = vim.fn.winnr("1" .. dir)
  if nbr == cur then return nil end
  return vim.fn.win_getid(nbr)
end

--- True when there's nothing to resize against: either the current
--- tabpage has at most one non-floating window, or the current window
--- is itself a float (win_move_separator/statusline don't apply to
--- floats).  Lets callers fall back to plain cursor motion.
function M.is_solo()
  if vim.api.nvim_win_get_config(0).relative ~= "" then
    return true
  end
  local count = 0
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_config(win).relative == "" then
      count = count + 1
      if count > 1 then return false end
    end
  end
  return true
end

function M.grow_right(amount)
  if neighbor("l") then
    vim.fn.win_move_separator(0, amount or M.amount)
  end
end

function M.grow_left(amount)
  local left = neighbor("h")
  if left then
    vim.fn.win_move_separator(left, -(amount or M.amount))
  end
end

function M.grow_down(amount)
  if neighbor("j") then
    vim.fn.win_move_statusline(0, amount or M.amount)
  end
end

function M.grow_up(amount)
  local up = neighbor("k")
  if up then
    vim.fn.win_move_statusline(up, -(amount or M.amount))
  end
end

function M.shrink_right(amount)
  if neighbor("l") then
    vim.fn.win_move_separator(0, -(amount or M.amount))
  end
end

function M.shrink_left(amount)
  local left = neighbor("h")
  if left then
    vim.fn.win_move_separator(left, amount or M.amount)
  end
end

function M.shrink_down(amount)
  if neighbor("j") then
    vim.fn.win_move_statusline(0, -(amount or M.amount))
  end
end

function M.shrink_up(amount)
  local up = neighbor("k")
  if up then
    vim.fn.win_move_statusline(up, amount or M.amount)
  end
end

return M
