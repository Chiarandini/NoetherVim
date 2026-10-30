-- noethervim.statusline: the statusline's data, whatever draws it.
--
-- Public (:help noethervim-api): text(id) and visible(id), so any statusline
-- can show a segment a unit declared. Provisional: the segment and busy
-- shapes (noethervim.Segment in types.lua).
--
-- Units declare segments in their anchor's spec,
--   { "NoetherVim", optional = true, opts = { segments = { [id] = seg } } }
-- and `busy` entries the same way; setup() hands both here. Your
-- `statusline` table in lua/user/config.lua adds or replaces segments
-- (`segments`), shows, hides or moves any segment or core block by id
-- (`layout`), drops a whole bar (`bars`), and sets heirline's look (`style`).
-- Visibility is kept here, by id, so the `<C-w>s` keys and the presets work
-- the same for core blocks and unit segments.
--
-- The heirline renderer in plugins/statusline/ reads all of it; its adapter
-- for segments is plugins/statusline/segments.lua.

local M = {}

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


---@type noethervim.StatuslineConfig
local _opts = {}
local _units = {} ---@type table<string, noethervim.Segment|false>
local _busy = {} ---@type table<string, noethervim.Busy|false>

--- Segments that raised an error, by id, with the message. Each is off for
--- the rest of the session; health lists them.
---@type table<string, string>
M.errors = {}

--- The blocks of heirline's main bar, by side, in order: the ids a segment's
--- `place.after` and your `layout` can name besides unit segments.
M.CORE = {
  left  = { "diagnostics", "busy", "filename" },
  right = { "lsp", "git", "profile" },
}

--- Where each block starts out hidden. Every other id starts out shown.
local HIDDEN = { directory = true, proj_relative_dir = true, profile = true, ["latex.pdfsize"] = true }

---@param opts noethervim.StatuslineConfig?
function M.configure(opts)
  _opts = opts or {}
  M.apply_preset("standard")
end

--- The segments and busy entries units declared in NoetherVim's spec.
---@param segments table<string, noethervim.Segment|false>?
---@param busy table<string, noethervim.Busy|false>?
function M.register(segments, busy)
  _units = segments or {}
  _busy = busy or {}
end

local function style() return _opts.style or {} end

--- Heirline color-table overrides from `style.colors`.
function M.get_colors()
  return style().colors or {}
end

--- The resolved edge-style preset (start_left, start_right, mid_left,
--- end_left). Falls back to "round" for unknown / nil names.
function M.get_edges()
  return edge_styles[style().edge_style or "round"] or edge_styles.round
end

--- Lists the known edge-style names. Keep validators in sync via this
--- accessor rather than duplicating the list.
function M.list_edge_styles()
  local names = {}
  for k in pairs(edge_styles) do names[#names + 1] = k end
  table.sort(names)
  return names
end

--- The tab modified-indicator glyph, `style.tab_modified_indicator`.
function M.get_tab_modified_indicator()
  return style().tab_modified_indicator or " ●"
end

--- True unless `style.mode_background = false`.
---
--- The bar shifts to a blue background in insert mode, so the editor's most
--- consequential hidden state is legible from the shape of the bar rather
--- than only from reading the mode chip. It is on by default for that
--- reason, and off in one line for anyone who finds the movement noisy.
function M.mode_background()
  return style().mode_background ~= false
end

--- Which bars heirline draws: `bars = { tabline = false }` drops one.
---@param bar "statusline"|"tabline"|"winbar"
---@return boolean
function M.bar(bar)
  return (_opts.bars or {})[bar] ~= false
end

-- ── Segments ─────────────────────────────────────────────────────────

--- The segment `id` as configured: yours from `segments` in place of a
--- unit's, with a `layout` table merged over its `place`. Nil for an id
--- nothing declares, or one that raised an error.
---@param id string
---@return noethervim.Segment?
function M.segment(id)
  if M.errors[id] then return nil end
  local seg = (_opts.segments or {})[id]
  if seg == nil then seg = _units[id] end
  if not seg then return nil end
  local layout = (_opts.layout or {})[id]
  if type(layout) == "table" then
    seg = vim.tbl_extend("force", seg, { place = vim.tbl_extend("force", seg.place or {}, layout) })
  end
  return seg
end

--- Every segment id, units' and yours, sorted.
---@return string[]
function M.ids()
  local ids = {}
  for id in pairs(_units) do if _units[id] then ids[#ids + 1] = id end end
  for id, seg in pairs(_opts.segments or {}) do
    if seg and not _units[id] then ids[#ids + 1] = id end
  end
  table.sort(ids)
  return ids
end

--- Run `fn` for segment `id`; an error turns the segment off for the
--- session and is reported once.
local function guard(id, fn, ...)
  local ok, res = pcall(fn, ...)
  if ok then return res end
  M.errors[id] = tostring(res)
  vim.schedule(function()
    vim.notify(("statusline segment %q failed and is off until restart: %s"):format(id, res),
      vim.log.levels.WARN)
  end)
end

--- One repeating redraw per `refresh` interval in use: the statusline is
--- drawn only when something happens, so a clock would otherwise stand
--- still. Started the first time such a segment shows.
local timers = {} ---@type table<integer, uv.uv_timer_t>
local function keep_fresh(ms)
  if timers[ms] then return end
  timers[ms] = vim.uv.new_timer()
  timers[ms]:start(ms, ms, vim.schedule_wrap(function() pcall(vim.cmd.redrawstatus) end))
end

---@param win? integer
---@return noethervim.SegmentCtx
local function context(win)
  win = win or vim.api.nvim_get_current_win()
  return { win = win, buf = vim.api.nvim_win_get_buf(win) }
end

--- Segment `id`'s chunks for `win`, or nil when it shows nothing there.
---@param id string
---@param win? integer
---@return { [1]: string, [2]: (string|table)? }[]?
function M.chunks(id, win)
  local seg = M.segment(id)
  if not seg or not M.shown(id) then return nil end
  local ctx = context(win)
  if seg.cond and not guard(id, seg.cond, ctx) then return nil end
  local out = guard(id, seg.provider, ctx)
  if type(out) == "string" then out = { { out, seg.hl } } end
  if type(out) ~= "table" then return nil end
  local text = ""
  for _, c in ipairs(out) do text = text .. (c[1] or "") end
  if text == "" then return nil end
  if type(seg.refresh) == "number" and seg.refresh > 0 then keep_fresh(math.max(100, seg.refresh)) end
  return out
end

--- Segment `id` as plain text for `win` (the current window by default),
--- or "" when it shows nothing. Public: any statusline can show it.
---@param id string
---@param win? integer
---@return string
function M.text(id, win)
  local text = ""
  for _, c in ipairs(M.chunks(id, win) or {}) do text = text .. c[1] end
  return text
end

--- True when segment `id` has something to show in `win`. Public.
---@param id string
---@param win? integer
---@return boolean
function M.visible(id, win)
  return M.chunks(id, win) ~= nil
end

--- Run segment `id`'s click handler.
---@param id string
---@param button string "l", "m" or "r"
function M.click(id, button)
  local seg = M.segment(id)
  if seg and seg.click then guard(id, seg.click, context(), button) end
end

--- What fills the busy slot now: the first busy entry (by id) that answers,
--- `true` for the plain spinner or a table that labels it. Nil when none.
---@return true|{ icon?: string, label?: string, hl?: table, click?: fun() }|nil
function M.busy()
  local ids = vim.tbl_keys(_busy)
  table.sort(ids)
  for _, id in ipairs(ids) do
    if _busy[id] and not M.errors["busy." .. id] then
      local res = guard("busy." .. id, _busy[id])
      if res then return res end
    end
  end
end

-- ── Visibility and presets ───────────────────────────────────────────
--
-- A preset is a complete visibility state, so switching to one lands on a
-- known bar rather than on whatever the `<C-w>s` keys last left behind.
-- `standard` is the bar a fresh start gives you; every other preset is an
-- override on top of it. A block you set in `layout` keeps your setting
-- through every preset.

local _shown = {} ---@type table<string, boolean>
local _preset = "standard"

local preset_overrides = {
  -- Quiet the blocks that have nothing to say about a document being
  -- compiled, and add the PDF size (the latex bundle's segment, which
  -- gates itself to TeX-family filetypes).
  pdf = { git = false, lsp = false, directory = false, ["latex.pdfsize"] = true },
}

--- Whether block or segment `id` is shown.
---@param id string
---@return boolean
function M.shown(id)
  if _shown[id] == nil then return not HIDDEN[id] end
  return _shown[id]
end

---@param id string
---@param on boolean
function M.set_shown(id, on)
  _shown[id] = on
end

---@param id string
function M.toggle(id)
  _shown[id] = not M.shown(id)
end

--- Stamp every block with `name`'s visibility and record it as current.
---@param name "standard"|"pdf"
function M.apply_preset(name)
  _shown = {}
  for id, on in pairs(preset_overrides[name] or {}) do _shown[id] = on end
  for id, layout in pairs(_opts.layout or {}) do
    if layout ~= nil then _shown[id] = layout ~= false end
  end
  _preset = name
end

--- The preset applied last. The individual toggles deliberately leave this
--- alone: after `<C-w>s<C-p>`, where going back leads should stay
--- `standard` even if git has since been switched on by hand.
---@return string
function M.current_preset()
  return _preset
end

--- Apply `name`, or return to `standard` when it is already current.
---@param name "pdf"
function M.toggle_preset(name)
  M.apply_preset(M.current_preset() == name and "standard" or name)
end

--- Returns the handler for clicking the git block in the statusline.
---
--- lazygit is a nice default but an optional external program, so the
--- default handler only reaches for it when it is actually on PATH and
--- otherwise opens snacks' git-status picker, which always ships. Set
--- `style.git_click` in `lua/user/config.lua` to a function of your own to
--- replace both.
---@return fun()
function M.get_git_click()
  if type(style().git_click) == "function" then return style().git_click end
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
