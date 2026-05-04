-- NoetherVim statusline override registry.
-- Called from noethervim.setup() before plugins load, so the heirline
-- config function can read user preferences at runtime.

local M = {}
local _opts = {}
local _busy_overrides = {}

-- Powerline-family glyphs from the Nerd Font private use area. Constructed
-- with string.char() so the raw UTF-8 bytes can't be corrupted by editor
-- copy-paste -- only the codepoints below are load-bearing.
--
-- Naming convention: a "_left" glyph is an OPENING endcap whose colored
-- (filled) half sits on the right side of its cell, so it transitions
-- the section bg INTO the content that follows.  A "_right" glyph is a
-- CLOSING endcap whose colored half sits on the left side, transitioning
-- the section bg OUT into the surrounding bar.
local function utf8(b1, b2, b3) return string.char(b1, b2, b3) end
local round_left  = utf8(0xee, 0x82, 0xb6) -- U+E0B6 round opener
local round_right = utf8(0xee, 0x82, 0xb4) -- U+E0B4 round closer
local slant_left  = utf8(0xee, 0x82, 0xba) -- U+E0BA lower-right triangle (slant opener)
local slant_right = utf8(0xee, 0x82, 0xbc) -- U+E0BC upper-left triangle  (slant closer in the same direction, so the mode block reads as a right-leaning parallelogram instead of a trapezoid)
local point_left  = utf8(0xee, 0x82, 0xb2) -- U+E0B2 left hard divider (pointy chevron opens section)
local point_right = utf8(0xee, 0x82, 0xb0) -- U+E0B0 right hard divider (pointy chevron closes section)

-- Edge-style presets describing the shape of every section transition in
-- the statusline. A style does not have to fill every slot: a nil slot
-- means the historical flat-edge / vertical-pipe rendering is used.
--   start_left, start_right -- opening/closing endcaps wrapping the left
--     mode block; consumed as ctx.semiCircles by heirline.utils.surround.
--   mid_left -- opening endcap that replaces the `|` separator before the
--     right-side StatusComponent (FileSize/Percentage/Lazy block). nil
--     keeps the classic `|` divider.
--   end_left -- opening endcap rendered immediately before the right-edge
--     ruler block. nil means the right edge stays flush (square) with the
--     screen, matching the historical NoetherVim look.
local edge_styles = {
  round    = { start_left = round_left, start_right = round_right, mid_left = nil,         end_left = nil },
  slant    = { start_left = slant_left, start_right = slant_right, mid_left = slant_left,  end_left = slant_left },
  pointy   = { start_left = point_left, start_right = point_right, mid_left = point_left,  end_left = point_left },
  straight = { start_left = "",         start_right = "",          mid_left = nil,         end_left = nil },
  bubbly   = { start_left = round_left, start_right = round_right, mid_left = round_left,  end_left = round_left },
}

--- Configure statusline overrides. Called once during `noethervim.setup()`
--- with the `statusline` subtable of `lua/user/config.lua`; the recorded
--- values are read at statusline-render time by the heirline component
--- functions.
---
---@param opts noethervim.StatuslineConfig?
function M.configure(opts)
  _opts = opts or {}
end

--- Returns user color overrides.
function M.get_colors()
  return _opts.colors or {}
end

--- Returns extra right-side components.
function M.get_extra_right()
  return _opts.extra_right or {}
end

--- Register a function that can greedily take over the Busy statusline
--- component. Evaluated on every statusline render; the most recently
--- registered override that returns a non-nil spec wins (last-write-wins,
--- so user config naturally trumps bundles that load earlier).
---
--- fn() -> nil | { icon?, label?, hl?, on_click? }
---   icon     -- string shown before the label; defaults to the animated
---              braille spinner frame
---   label    -- short string shown after the icon (e.g. "ai")
---   hl       -- heirline highlight spec (e.g. { fg = "#c678dd", bold = true })
---   on_click -- function invoked on mouse click
---
--- The animated spinner ticks while something is driving vim.bo.busy > 0;
--- overrides wanting animation should increment busy on the relevant buf.
function M.register_busy_override(fn)
  table.insert(_busy_overrides, fn)
end

function M.get_busy_overrides()
  return _busy_overrides
end

--- Returns the resolved edge-style preset (start_left, start_right,
--- end_left). Falls back to "round" for unknown / nil names.
function M.get_edges()
  return edge_styles[_opts.edge_style or "round"] or edge_styles.round
end

--- Lists the known edge-style names. Keep validators in sync via this
--- accessor rather than duplicating the list.
function M.list_edge_styles()
  local names = {}
  for k in pairs(edge_styles) do names[#names + 1] = k end
  table.sort(names)
  return names
end

return M
