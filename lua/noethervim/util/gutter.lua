--- Clickable gutter glyphs.
---
--- A sign carries no click callback. Neither `sign_define` nor an extmark
--- takes one, and the natively drawn sign column offers no hook at all. The
--- only clickable surfaces Neovim has are the format-string options, so the
--- column has to be drawn by a 'statuscolumn' whose sign item sits inside a
--- `%@...@` click region. `autocmds.lua` owns that string; this module owns
--- what happens when the region is clicked.
---
--- A unit hands its handler to NoetherVim's spec, keyed by a Lua pattern
--- matched against the sign name, and a click looks it up there:
---
---   specs = { { "NoetherVim", optional = true, opts = { gutter = {
---     ["^neotest_"] = function(ctx) ... end,
---   } } } }
---
--- Dispatch is on the sign actually drawn, which with 'signcolumn' at `auto`
--- is the highest-priority sign on that line. The action therefore always
--- matches the glyph under the pointer, including on a line two providers
--- both wanted.

local M = {}

---@class noethervim.GutterClick
---@field buf integer
---@field win integer    window the click landed in, not necessarily current
---@field line integer   1-based buffer line the glyph is on
---@field sign string    name of the sign that was drawn
---@field button string  "l", "r" or "m"
---@field clicks integer 2 on the second click of a double click; note the
---                     single-click dispatch still fires first
---@field mods string    one character per modifier held, spaces otherwise

---@type table[]
local handlers = {}

--- Register a handler for signs whose name matches `pattern`, beside the
--- `gutter` section of NoetherVim's spec.
---@param pattern string  Lua pattern matched against the sign name
---@param fn fun(ctx: noethervim.GutterClick)
function M.register(pattern, fn)
  table.insert(handlers, { pattern, fn })
end

--- The sign a reader can actually see on `lnum`: the highest-priority one.
---
--- Legacy signs only. The extmark signs gitsigns and |vim.diagnostic| place
--- are absent from this list, which costs no misdispatch, because every
--- provider registered here outranks them: whenever a pattern matches, the
--- sign it matched is the one on screen.
---@param buf integer
---@param lnum integer
---@return table?
local function drawn_sign(buf, lnum)
  local placed = vim.fn.sign_getplaced(buf, { group = "*", lnum = lnum })[1]
  local best
  for _, sign in ipairs(placed and placed.signs or {}) do
    if not best or sign.priority > best.priority then best = sign end
  end
  return best
end

--- 'statuscolumn' click callback, wired in as
--- `%@v:lua.require'noethervim.util.gutter'.on_click@%s%X`.
---
--- Neovim moves the cursor to the clicked line before this runs, but the
--- window and line come from the mouse rather than from the cursor: a click
--- in an inactive window's gutter has to act on that window, not this one.
---@param _ integer  minwid, unused: one region covers every row
---@param clicks integer
---@param button string
---@param mods string
function M.on_click(_, clicks, button, mods)
  local pos = vim.fn.getmousepos()
  if pos.winid == 0 or pos.line == 0 then return end
  local buf = vim.api.nvim_win_get_buf(pos.winid)
  local sign = drawn_sign(buf, pos.line)
  if not sign then return end
  local all = vim.deepcopy(handlers)
  for pattern, fn in pairs(require("noethervim")._host.gutter or {}) do
    if fn then table.insert(all, { pattern, fn }) end
  end
  for _, handler in ipairs(all) do
    if sign.name:match(handler[1]) then
      return handler[2]({
        buf    = buf,
        win    = pos.winid,
        line   = pos.line,
        sign   = sign.name,
        button = button,
        clicks = clicks,
        mods   = mods,
      })
    end
  end
end

return M
