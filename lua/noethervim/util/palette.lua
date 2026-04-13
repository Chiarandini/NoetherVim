-- NoetherVim statusline palette resolver.
-- Returns the full color table expected by the heirline statusline config.
--
-- When gruvbox is active, returns the hand-tuned gruvbox palette that
-- preserves the exact current statusline appearance.  For every other
-- colorscheme the palette is derived from standard highlight groups so the
-- statusline matches the active theme.
--
-- User overrides (via opts.statusline.colors) are NOT applied here — the
-- caller merges them on top with vim.tbl_extend("force", ...).

local M = {}

-- ── Helpers ──────────────────────────────────────────────────────

---@param group string
---@param attr "fg"|"bg"
---@return string|nil  hex color string or nil
local function hl(group, attr)
  local ok, result = pcall(vim.api.nvim_get_hl, 0, { name = group, link = false })
  if not ok or not result then return nil end
  local val = result[attr]
  if val == nil then return nil end
  return string.format("#%06x", val)
end

local function hex_to_rgb(hex)
  hex = hex:gsub("#", "")
  return tonumber(hex:sub(1, 2), 16),
         tonumber(hex:sub(3, 4), 16),
         tonumber(hex:sub(5, 6), 16)
end

local function rgb_to_hex(r, g, b)
  return string.format("#%02x%02x%02x",
    math.max(0, math.min(255, math.floor(r + 0.5))),
    math.max(0, math.min(255, math.floor(g + 0.5))),
    math.max(0, math.min(255, math.floor(b + 0.5))))
end

--- Linear interpolation: t=0 → c1, t=1 → c2.
local function blend(c1, c2, t)
  local r1, g1, b1 = hex_to_rgb(c1)
  local r2, g2, b2 = hex_to_rgb(c2)
  return rgb_to_hex(
    r1 + (r2 - r1) * t,
    g1 + (g2 - g1) * t,
    b1 + (b2 - b1) * t)
end

--- Move toward white: t=0 → color, t=1 → white.
local function lighten(color, t)
  return blend(color, "#ffffff", t)
end

--- Move toward black: t=0 → color, t=1 → black.
local function darken(color, t)
  return blend(color, "#000000", t)
end

-- ── Derived palette ──────────────────────────────────────────────

--- Build a palette from the active colorscheme's standard highlight groups.
--- Works with any well-behaved colorscheme.
local function from_highlights()
  -- Base colors from universal highlight groups
  local bg     = hl("Normal", "bg")            or "#282828"
  local fg     = hl("Normal", "fg")            or "#ebdbb2"
  local green  = hl("String", "fg")            or "#98c379"
  local blue   = hl("Function", "fg")          or "#61afef"
  local red    = hl("DiagnosticError", "fg")   or "#e06c75"
  local yellow = hl("Type", "fg")              or "#e5c07b"
  local orange = hl("Constant", "fg")          or hl("WarningMsg", "fg") or "#d19a66"
  local purple = hl("Statement", "fg")         or "#c678dd"
  local cyan   = hl("Special", "fg")           or "#56b6c2"
  local gray   = hl("Comment", "fg")           or "#7c6f64"

  return {
    bg = bg,

    -- Background tones (derived from Normal bg/fg blend)
    default_gray  = blend(bg, fg, 0.08),
    light_gray    = blend(bg, fg, 0.20),
    default_blue  = darken(blue, 0.65),

    -- Text
    text_gray       = fg,
    text_unselected = gray,
    text_light_gray = fg,

    -- Greens
    green                 = green,
    dark_green            = darken(green, 0.60),
    light_green           = lighten(green, 0.20),
    normal_insert_green   = blend(green, blue, 0.15),
    normal_terminal_green = blend(green, purple, 0.10),
    command_line          = green,
    command_ex_line       = lighten(green, 0.15),

    -- Blues
    light_blue             = blue,
    medium_blue            = blend(blue, bg, 0.30),
    insert_completion_blue = lighten(blue, 0.25),

    -- Reds
    light_red             = red,
    replace_variation_red = lighten(red, 0.10),

    -- Oranges / yellows
    yellow               = yellow,
    orange               = orange,
    light_orange         = lighten(orange, 0.30),
    visual_orange        = orange,
    visual_select_orange = lighten(orange, 0.15),
    select_block_orange  = lighten(yellow, 0.30),
    lazy_updates         = blend(orange, red, 0.15),

    -- Terminal
    terminal_blue = purple,

    -- Git
    git_add    = hl("Added", "fg")   or hl("GitSignsAdd", "fg")    or green,
    git_change = hl("Changed", "fg") or hl("GitSignsChange", "fg") or cyan,
    git_del    = hl("Removed", "fg") or hl("GitSignsDelete", "fg") or red,

    -- Always derived from highlight groups (same as current behaviour)
    bright_bg  = hl("Folded", "bg")          or blend(bg, fg, 0.10),
    bright_fg  = hl("Folded", "fg")          or blend(fg, bg, 0.30),
    red        = red,
    dark_red   = hl("DiffDelete", "bg")      or darken(red, 0.50),
    blue       = blue,
    gray       = hl("NonText", "fg")         or gray,
    purple     = purple,
    cyan       = cyan,
    diag_warn  = hl("DiagnosticWarn", "fg")  or yellow,
    diag_error = hl("DiagnosticError", "fg") or red,
    diag_hint  = hl("DiagnosticHint", "fg")  or cyan,
    diag_info  = hl("DiagnosticInfo", "fg")  or blue,
  }
end

-- ── Gruvbox preset ───────────────────────────────────────────────

--- Hand-tuned palette for gruvbox — preserves the exact current statusline.
local function gruvbox_palette()
  local gruvbox_bg, gruvbox_text
  local ok, gruvbox = pcall(require, "gruvbox")
  if ok then
    gruvbox_bg   = gruvbox.palette.dark0
    gruvbox_text = gruvbox.palette.light1
  else
    gruvbox_bg   = "#282828"
    gruvbox_text = "#ebdbb2"
  end

  return {
    bg = gruvbox_bg,

    -- Background tones
    default_gray  = "#333333",
    light_gray    = "#504944",
    default_blue  = "#153E5B",

    -- Text
    text_gray       = gruvbox_text,
    text_unselected = "#7C6F64",
    text_light_gray = "#CDB89A",

    -- Greens
    green                 = "#AFDF01",
    dark_green            = "#056100",
    light_green           = "#8BBA7F",
    normal_insert_green   = "#9CC901",
    normal_terminal_green = "#A1C101",
    command_line          = "#AFDF01",
    command_ex_line       = "#BEEF01",

    -- Blues
    light_blue             = "#4DB6E6",
    medium_blue            = "#2B8CBC",
    insert_completion_blue = "#7AC8F0",

    -- Reds
    light_red             = "#F2584B",
    replace_variation_red = "#F04C4C",

    -- Oranges / yellows
    yellow               = "#E9B144",
    orange               = "#FFA500",
    light_orange         = "#FFE28B",
    visual_orange        = "#FF8700",
    visual_select_orange = "#FF9933",
    select_block_orange  = "#FFD766",
    lazy_updates         = "#F0943C",

    -- Terminal
    terminal_blue = "#B16286",

    -- Git
    git_add    = "#B9BB25",
    git_change = "#8DC07C",
    git_del    = "#FB4A34",

    -- Derived from highlight groups (track gruvbox's own definitions).
    -- Fallbacks ensure every key is non-nil so the full table is returned
    -- even if a highlight group hasn't been defined yet.
    bright_bg  = hl("Folded", "bg")          or "#3c3836",
    bright_fg  = hl("Folded", "fg")          or "#a89984",
    red        = hl("DiagnosticError", "fg") or "#fb4934",
    dark_red   = hl("DiffDelete", "bg")      or "#4a1616",
    blue       = hl("Function", "fg")        or "#83a598",
    gray       = hl("NonText", "fg")         or "#504945",
    purple     = hl("Statement", "fg")       or "#d3869b",
    cyan       = hl("Special", "fg")         or "#8ec07c",
    diag_warn  = hl("DiagnosticWarn", "fg")  or "#fabd2f",
    diag_error = hl("DiagnosticError", "fg") or "#fb4934",
    diag_hint  = hl("DiagnosticHint", "fg")  or "#8ec07c",
    diag_info  = hl("DiagnosticInfo", "fg")  or "#83a598",
  }
end

-- ── Public API ───────────────────────────────────────────────────

--- Resolve the statusline color palette for the current colorscheme.
--- @return table  full colors table for the heirline statusline config
function M.resolve()
  if vim.g.colors_name == "gruvbox" then
    return gruvbox_palette()
  end
  return from_highlights()
end

return M
