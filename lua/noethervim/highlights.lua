-- NoetherVim highlight overrides

-- Keep sign column visually integrated with the background
vim.cmd("hi! link SignColumn Normal")

-- ── Helpers ──────────────────────────────────────────────────────

local function get_hl_fg(name)
  local ok, result = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
  if ok and result and result.fg then
    return string.format("#%06x", result.fg)
  end
end

-- ──────────────────────────────────────────────────────────────
--  Snacks dashboard header colour
--  Set a fallback immediately so the header has colour even before
--  the colorscheme loads.  Then re-derive from DiagnosticWarn on
--  every ColorScheme event (fires synchronously before VimEnter,
--  so the dashboard renders with correct colours from the start).
--  (Footer is handled in snacks.lua via a custom highlight group.)
-- ──────────────────────────────────────────────────────────────
vim.api.nvim_set_hl(0, "SnacksDashboardHeader", { fg = "#fabd2f" })

local function apply_dashboard_header_hl()
  vim.api.nvim_set_hl(0, "SnacksDashboardHeader", { fg = get_hl_fg("DiagnosticWarn") or "#fabd2f" })
end

vim.api.nvim_create_autocmd("ColorScheme", {
  group    = vim.api.nvim_create_augroup("noethervim_dashboard_header", { clear = true }),
  callback = apply_dashboard_header_hl,
})

-- ──────────────────────────────────────────────────────────────
--  Blink.cmp completion highlights
--  Derive all colors from the active colorscheme so the completion
--  menu adapts to any theme.  Re-applied on ColorScheme changes.
-- ──────────────────────────────────────────────────────────────

local function apply_blink_highlights()
  local set = vim.api.nvim_set_hl

  -- Float consistency: menu and docs use the floating-window palette
  -- instead of the default Pmenu grey.
  set(0, "BlinkCmpMenu",                   { link = "NormalFloat" })
  set(0, "BlinkCmpMenuBorder",             { link = "FloatBorder" })
  set(0, "BlinkCmpDocBorder",              { link = "FloatBorder" })
  set(0, "BlinkCmpSignatureHelpBorder",    { link = "FloatBorder" })

  -- Matched characters: muted blue, bold — visible but not distracting.
  set(0, "BlinkCmpLabelMatch", { fg = get_hl_fg("Identifier") or "#83a598", bold = true })

  -- Semantic kind coloring: link each LSP kind to the highlight group
  -- that represents the same concept in the editor.
  set(0, "BlinkCmpKindFunction",      { link = "Function" })
  set(0, "BlinkCmpKindMethod",        { link = "Function" })
  set(0, "BlinkCmpKindConstructor",   { link = "Function" })

  set(0, "BlinkCmpKindClass",         { link = "Type" })
  set(0, "BlinkCmpKindStruct",        { link = "Type" })
  set(0, "BlinkCmpKindInterface",     { link = "Type" })
  set(0, "BlinkCmpKindEnum",          { link = "Type" })
  set(0, "BlinkCmpKindTypeParameter", { link = "Type" })

  set(0, "BlinkCmpKindVariable",      { link = "Identifier" })
  set(0, "BlinkCmpKindField",         { link = "Identifier" })
  set(0, "BlinkCmpKindProperty",      { link = "Identifier" })

  set(0, "BlinkCmpKindConstant",      { link = "Constant" })
  set(0, "BlinkCmpKindValue",         { link = "Constant" })
  set(0, "BlinkCmpKindEnumMember",    { link = "Constant" })

  set(0, "BlinkCmpKindKeyword",       { link = "Keyword" })
  set(0, "BlinkCmpKindOperator",      { link = "Operator" })
  set(0, "BlinkCmpKindModule",        { link = "Include" })

  set(0, "BlinkCmpKindSnippet",       { link = "Special" })
  set(0, "BlinkCmpKindReference",     { link = "Special" })
  set(0, "BlinkCmpKindEvent",         { link = "Special" })
  set(0, "BlinkCmpKindColor",         { link = "Special" })

  set(0, "BlinkCmpKindFile",          { link = "Directory" })
  set(0, "BlinkCmpKindFolder",        { link = "Directory" })

  set(0, "BlinkCmpKindUnit",          { link = "Number" })
  set(0, "BlinkCmpKindText",          { link = "Comment" })
end

apply_blink_highlights()

vim.api.nvim_create_autocmd("ColorScheme", {
  group    = vim.api.nvim_create_augroup("noethervim_blink_highlights", { clear = true }),
  callback = apply_blink_highlights,
})
