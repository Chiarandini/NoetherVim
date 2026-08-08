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
-- the section bg INTO the content that follows. A "_right" glyph is a
-- CLOSING endcap whose colored half sits on the left side, transitioning
-- the section bg OUT into the surrounding bar.
local function utf8(b1, b2, b3) return string.char(b1, b2, b3) end
local round_left  = utf8(0xee, 0x82, 0xb6) -- U+E0B6 round opener
local round_right = utf8(0xee, 0x82, 0xb4) -- U+E0B4 round closer
-- The four Powerline slant glyphs. An OPENER sits at a section's left edge
-- with its filled half on the right; a CLOSER sits at the right edge with
-- its filled half on the left. Pairing an opener with the closer that leans
-- the same way gives a parallelogram; pairing it with the other one gives a
-- trapezoid. That is the whole of the shape space, and it is why there are
-- exactly four slant styles below.
local slant_open_r  = utf8(0xee, 0x82, 0xba) -- U+E0BA lower-right triangle
local slant_close_r = utf8(0xee, 0x82, 0xbc) -- U+E0BC upper-left triangle
local slant_open_l  = utf8(0xee, 0x82, 0xbe) -- U+E0BE upper-right triangle
local slant_close_l = utf8(0xee, 0x82, 0xb8) -- U+E0B8 lower-left triangle
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
--
-- The slant family, by the shape the mode block ends up as:
--   slant       both edges lean right -- a right-leaning parallelogram
--   slant_left  both edges lean left  -- the mirror of it
--   slant_in    edges lean towards each other -- a trapezoid
--   slant_out   edges lean apart      -- the other trapezoid
-- `slant` keeps its meaning, so an existing config is unaffected.
local edge_styles = {
  round      = { start_left = round_left,   start_right = round_right,   mid_left = nil,           end_left = nil },
  slant      = { start_left = slant_open_r, start_right = slant_close_r, mid_left = slant_open_r,  end_left = slant_open_r },
  slant_left = { start_left = slant_open_l, start_right = slant_close_l, mid_left = slant_open_l,  end_left = slant_open_l },
  slant_in   = { start_left = slant_open_r, start_right = slant_close_l, mid_left = slant_open_r,  end_left = slant_open_r },
  slant_out  = { start_left = slant_open_l, start_right = slant_close_r, mid_left = slant_open_l,  end_left = slant_open_l },
  pointy     = { start_left = point_left,   start_right = point_right,   mid_left = point_left,    end_left = point_left },
  straight   = { start_left = "",           start_right = "",            mid_left = nil,           end_left = nil },
  bubbly     = { start_left = round_left,   start_right = round_right,   mid_left = round_left,    end_left = round_left },
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

--- Returns the tab modified-indicator glyph. Defaults to `" ●"`; users
--- can override via `statusline.tab_modified_indicator` in user/config.lua
--- (e.g. `" [+]"` for the vim-default look).
function M.get_tab_modified_indicator()
  return _opts.tab_modified_indicator or " ●"
end

--- True when the filetype-profile marker should be rendered. Off unless
--- True unless `statusline.mode_background = false` in `lua/user/config.lua`.
---
--- The bar shifts to a blue background in insert mode, so the editor's most
--- consequential hidden state is legible from the shape of the bar rather
--- than only from reading the mode chip. It is on by default for that
--- reason, and off in one line for anyone who finds the movement noisy.
function M.mode_background()
  return _opts.mode_background ~= false
end

--- `statusline.filetype_profile = true` in `lua/user/config.lua`.
function M.show_filetype_profile()
  return _opts.filetype_profile == true
end

--- Returns the handler for clicking the git block in the statusline.
---
--- lazygit is a nice default but an optional external program, so the
--- default handler only reaches for it when it is actually on PATH and
--- otherwise opens snacks' git-status picker, which always ships. Set
--- `statusline.git_click` in `lua/user/config.lua` to a function of your
--- own to replace both.
---@return fun()
function M.get_git_click()
  if type(_opts.git_click) == "function" then return _opts.git_click end
  return function()
    if vim.fn.executable("lazygit") == 1 then
      -- Deferred so the click's own redraw finishes before the terminal
      -- window steals focus.
      vim.defer_fn(function() Snacks.terminal("lazygit") end, 100)
    else
      Snacks.picker.git_status({ title = "Git Status" })
    end
  end
end

return M
