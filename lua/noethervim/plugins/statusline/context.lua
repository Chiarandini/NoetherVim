-- Shared state and helpers for the heirline statusline.
-- Colors and mode_colors are populated by init.lua and mutated in-place
-- on ColorScheme changes, so all references across modules stay valid.

local M = {}

M.semiCircles = { "", "" }

-- Flexible-component priorities. Heirline collapses every flexible
-- component at priority N before considering N+1. Components at the
-- same priority collapse together on the same redraw, which causes a
-- visible "herd flicker" when the bar's width oscillates by a few cells
-- across the threshold (e.g. while typing in insert mode with debug
-- panes open and diagnostic counts ticking). Spread same-class
-- components across distinct levels to avoid the synchronized flip.
M.priority = {
  max     = 5,
  high    = 4,
  mid     = 3,
  mid_low = 2,
  low     = 1,
  none    = 0,
}

M.lspColor = {
  lua = "#718ECF",
  tex = "#8CAC60",
  typescriptreact = "#0C79B3",
  javascript = "#0C79B3",
  python = "#FFD141",
}

M.mode_names = {
  n = "N", no = "N?", nov = "N?", noV = "N?", ["no\22"] = "N?",
  niI = "Ni", niR = "Nr", niV = "Nv", nt = "Nt",
  v = "V", vs = "Vs", V = "V_", Vs = "Vs",
  ["\22"] = "^V", ["\22s"] = "^V",
  s = "S", S = "S_", ["\19"] = "^S",
  i = "I", ic = "Ic", ix = "Ix",
  R = "R", Rc = "Rc", Rx = "Rx", Rv = "Rv", Rvc = "Rv", Rvx = "Rv",
  c = "C", cv = "Ex",
  r = "...", rm = "M", ["r?"] = "?", ["!"] = "!", t = "T",
}

-- Populated by init.lua before any component is rendered.
M.colors = {}
M.mode_colors = {}

function M.make_mode_colors(colors)
  return {
    -- Base modes
    n = colors.green,
    i = colors.light_blue,
    v = colors.visual_orange,
    V = colors.visual_orange,
    s = colors.light_orange,
    S = colors.light_orange,
    R = colors.red,
    c = colors.command_line,
    t = colors.terminal_blue,

    -- Normal mode variations
    no = colors.light_orange,
    nov = colors.light_orange,
    noV = colors.light_orange,
    ["no\22"] = colors.light_orange,
    niI = colors.normal_insert_green,
    niR = colors.normal_insert_green,
    niV = colors.normal_insert_green,
    nt = colors.normal_terminal_green,

    -- Visual mode variations
    vs = colors.visual_select_orange,
    Vs = colors.visual_select_orange,
    ["\22"] = colors.cyan,
    ["\22s"] = colors.cyan,

    -- Select block
    ["\19"] = colors.select_block_orange,

    -- Insert mode variations
    ic = colors.insert_completion_blue,
    ix = colors.insert_completion_blue,

    -- Replace mode variations
    r = colors.red,
    Rv = colors.replace_variation_red,
    Rc = colors.replace_variation_red,
    Rx = colors.replace_variation_red,
    Rvc = colors.replace_variation_red,
    Rvx = colors.replace_variation_red,

    -- Command mode variations
    cv = colors.command_ex_line,

    -- Other
    rm = colors.yellow,
    ["r?"] = colors.light_orange,
    ["!"] = colors.yellow,
  }
end

-- Cache git root lookups by directory path: finddir(".git/..") is a
-- synchronous filesystem walk that fires on every statusline redraw.
local _git_root_cache = {}
function M.cached_git_root(path)
  if _git_root_cache[path] == nil then
    _git_root_cache[path] = vim.fn.finddir(".git/..", path .. ";")
  end
  return _git_root_cache[path]
end

-- ── Mode-aware statusline background ──────────────────────────────
-- The bottom statusline shifts from default_gray (normal-ish modes) to
-- default_blue when in insert mode, so the editor's "global state"
-- shows up in the bar as well as in the mode chip.  Heirline propagates
-- the parent component's `hl.bg` to children that don't override it,
-- but every once in a while a component returns a fresh hl table from
-- a function (`hl = function() return {fg=...} end`) and the bg merge
-- doesn't carry through cleanly -- the component renders with the
-- terminal's default bg instead of matching the bar.  Rather than
-- chase that case-by-case, components can call `ctx.mode_bg()` (or use
-- the `ctx.with_mode_bg` wrapper) to embed the correct bg directly.
--
-- Both helpers read live state from `vim.fn.mode()` / `M.colors`, so
-- they pick up theme changes and mode switches automatically.

--- Current statusline background colour for the active mode.
function M.mode_bg()
  local mode = vim.fn.mode(1):sub(1, 1)
  if mode == "i" then
    return M.colors.default_blue
  end
  return M.colors.default_gray
end

--- Wrap a heirline `hl` value (table OR function returning a table) so
--- the resolved table always has `bg` set to the current mode-aware
--- background.  An explicit `bg` in the wrapped spec wins, so callers
--- can still opt out for components that want their own bg.
---
---@param hl table|fun(self?:table):table
---@return fun(self?:table):table
function M.with_mode_bg(hl)
  return function(self)
    local resolved = type(hl) == "function" and hl(self) or hl
    resolved = resolved and vim.tbl_extend("keep", {}, resolved) or {}
    if resolved.bg == nil then
      resolved.bg = M.mode_bg()
    end
    return resolved
  end
end

return M
