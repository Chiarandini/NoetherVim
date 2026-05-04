-- NoetherVim highlight overrides

-- Keep sign column visually integrated with the background.
-- Re-applied on ColorScheme so it persists across theme changes.
local function apply_signcolumn_hl()
  vim.cmd("hi! link SignColumn Normal")
end
apply_signcolumn_hl()

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

vim.api.nvim_create_autocmd("ColorScheme", {
  group    = vim.api.nvim_create_augroup("noethervim_signcolumn", { clear = true }),
  callback = apply_signcolumn_hl,
})

-- ──────────────────────────────────────────────────────────────
--  Signcolumn icon cleanup
--  Colorschemes often style the base Diagnostic<Level> groups with
--  extra attrs (italic, underline, bg) meant for virtual text. When
--  those groups are used as a sign's texthl the extras leak into the
--  glyph, producing a colored square in the signcolumn that doesn't
--  match the surrounding bg. Neovim ships DiagnosticSign<Level> for
--  this purpose -- re-derive each one as fg-only so any plugin that
--  uses them (DAP, diagnostics, mini.diff, etc.) renders cleanly.
-- ──────────────────────────────────────────────────────────────
local function clean_diagnostic_sign_hls()
  for _, lvl in ipairs({ "Error", "Warn", "Info", "Hint" }) do
    local fg = get_hl_fg("DiagnosticSign" .. lvl) or get_hl_fg("Diagnostic" .. lvl)
    if fg then
      vim.api.nvim_set_hl(0, "DiagnosticSign" .. lvl, { fg = fg })
    end
  end
end
clean_diagnostic_sign_hls()

vim.api.nvim_create_autocmd("ColorScheme", {
  group    = vim.api.nvim_create_augroup("noethervim_diagnostic_sign_hls", { clear = true }),
  callback = clean_diagnostic_sign_hls,
})

-- ──────────────────────────────────────────────────────────────
--  Gruvbox heading-stripe softening
--  render-markdown.nvim links RenderMarkdownH{1..6}Bg to the Diff*
--  groups by default. Gruvbox's diff bgs are intentionally loud (so
--  real diffs pop), which makes the heading row stripe overpowering
--  in normal mode. Re-paint the bg groups to gruvbox's bg2; bg1 is
--  already taken by CursorLine / ColorColumn / RenderMarkdownCodeInline
--  so reusing it makes the heading stripe blend with inline code.
--  bg2 is one tone deeper, still earthy, and visibly distinct.
-- ──────────────────────────────────────────────────────────────
local function apply_gruvbox_heading_hls()
  if not (vim.g.colors_name or ""):match("^gruvbox") then return end
  for i = 1, 6 do
    vim.api.nvim_set_hl(0, "RenderMarkdownH" .. i .. "Bg", { bg = "#504945" })
  end
end
apply_gruvbox_heading_hls()

vim.api.nvim_create_autocmd("ColorScheme", {
  group    = vim.api.nvim_create_augroup("noethervim_gruvbox_heading_hls", { clear = true }),
  callback = apply_gruvbox_heading_hls,
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

  -- Matched characters: muted blue, bold -- visible but not distracting.
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

-- ──────────────────────────────────────────────────────────────
--  Inlay hint + line-blame readability
--
--  Many colorschemes (gruvbox in particular -- it explicitly does
--  `LspInlayHint = { link = "comment" }`) render virtual text in the
--  same dim grey as surrounding comments, so inferred types and inlay
--  parameter names disappear visually.  We force every "informational
--  virtual text" group to a hand-picked accent that's clearly distinct
--  from Comment in the active theme:
--    LspInlayHint(.Type|.Parameter)   -- typed inline LSP hints
--    DiagnosticVirtualText.*          -- inline diagnostics
--    GitSignsCurrentLineBlame         -- inline blame chip
--
--  Gruvbox uses the palette's bright orange #fe8019 -- it's loud
--  enough not to be confused with grey comments while still belonging
--  in the earthy palette.  Other schemes fall back to DiagnosticHint
--  (intentionally distinct from Comment in nearly every modern theme).
-- ──────────────────────────────────────────────────────────────

local function pick_hint_fg()
  local cs = vim.g.colors_name or ""
  if cs:match("gruvbox") then
    -- A calm muted teal -- gruvbox-material's "aqua" tone.  Sits between
    -- bright_aqua (#8ec07c, used by DiagnosticHint -- too neon, blends with
    -- hints) and bright_blue (#83a598, used by DiagnosticInfo -- would conflict
    -- with info-severity virtual text).  Reads as "informational, distinct
    -- from code" without competing with diagnostics.  Light variant uses
    -- gruvbox's faded teal so the contrast pops the same way.
    return vim.o.background == "light" and "#427b58" or "#7daea3"
  end
  local fg = get_hl_fg("DiagnosticHint")
  if fg and fg ~= get_hl_fg("Comment") then return fg end
  return get_hl_fg("NonText") or fg or "#83a598"
end

-- Pick a "just changed" accent for nvim-dap-virtual-text.  This is the
-- transient flash that fires when a variable's value updates in the
-- debugger -- it should be loud enough to grab the eye for one redraw,
-- then revert to the calm hint colour on the next step.
local function pick_changed_fg()
  local cs = vim.g.colors_name or ""
  if cs:match("gruvbox") then
    -- bright yellow / faded yellow from gruvbox's palette: classic
    -- "attention" colour, distinct from both error-red and hint-teal.
    return vim.o.background == "light" and "#b57614" or "#fabd2f"
  end
  return get_hl_fg("DiagnosticWarn") or "#fabd2f"
end

local function apply_hint_highlights()
  local hint_fg = pick_hint_fg()
  local spec = { fg = hint_fg, italic = true }
  -- Calm "informational" virtual text -- adopts the muted teal accent.
  for _, group in ipairs({
    -- LSP-driven inlay hints (parameter names, inferred types).
    "LspInlayHint",
    "LspInlayHintType",
    "LspInlayHintParameter",
    -- Inline diagnostic virtual text (when not using tiny-inline-diagnostic).
    "DiagnosticVirtualTextHint",
    "DiagnosticVirtualTextInfo",
    -- Inline blame chip from gitsigns.
    "GitSignsCurrentLineBlame",
    -- nvim-dap-virtual-text: steady-state variable value display.
    "NvimDapVirtualText",
    "NvimDapVirtualTextInfo",
  }) do
    vim.api.nvim_set_hl(0, group, spec)
  end
  -- Loud transient accent for dap value changes -- bold + non-italic so
  -- the flash differs from the steady-state inlay shape, not just colour.
  vim.api.nvim_set_hl(0, "NvimDapVirtualTextChanged",
    { fg = pick_changed_fg(), bold = true })
  -- Errors during debug variable resolution stay theme-red.  Linking
  -- (rather than setting fg directly) means colorscheme changes flow
  -- through automatically.
  vim.api.nvim_set_hl(0, "NvimDapVirtualTextError",
    { link = "DiagnosticError" })
end

apply_hint_highlights()

vim.api.nvim_create_autocmd("ColorScheme", {
  group    = vim.api.nvim_create_augroup("noethervim_hint_highlights", { clear = true }),
  callback = apply_hint_highlights,
})

-- Diagnosis helper: `:NoetherVimHintColors` prints the resolved fg of
-- every group we touch and how it compares to Comment.  Run it if the
-- inlay hints still look like comments -- the answer reveals whether
-- the override didn't take, or whether the source is a different
-- highlight group than we override.
-- :NoetherVimHighlightUnderCursor -- print every highlight (extmark, syntax,
-- treesitter, semantic-token) covering the position under the cursor.  Run
-- this with the cursor sitting on the offending grey blob: the output names
-- the exact group, which we can then add to `apply_hint_highlights` above.
vim.api.nvim_create_user_command("NoetherVimHighlightUnderCursor", function()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row = row - 1   -- nvim_win_get_cursor is (1,0); extmark API is (0,0)
  local buf = vim.api.nvim_get_current_buf()
  local lines = { string.format("at row=%d col=%d:", row + 1, col) }

  -- Syntax stack (legacy regex syntax)
  local syn = vim.fn.synID(row + 1, col + 1, 1)
  if syn > 0 then
    local name = vim.fn.synIDattr(syn, "name")
    local trans = vim.fn.synIDattr(vim.fn.synIDtrans(syn), "name")
    lines[#lines + 1] = string.format("  syntax: %s (-> %s)", name, trans)
  end

  -- Treesitter captures
  local ts_caps = vim.treesitter.get_captures_at_cursor(0)
  if ts_caps and #ts_caps > 0 then
    lines[#lines + 1] = "  treesitter: @" .. table.concat(ts_caps, ", @")
  end

  -- LSP semantic tokens
  local ok_st, st = pcall(vim.lsp.semantic_tokens.get_at_pos, buf, row, col)
  if ok_st and st and #st > 0 then
    local names = {}
    for _, t in ipairs(st) do names[#names + 1] = t.type end
    lines[#lines + 1] = "  semantic: " .. table.concat(names, ", ")
  end

  -- Extmarks (virtual text, inlay hints, diagnostics, gitsigns blame, dap
  -- virtual text -- *all* go through extmarks, so this is the canonical
  -- way to find what's painting that grey strip).
  local marks = vim.api.nvim_buf_get_extmarks(buf, -1, { row, 0 }, { row, -1 },
    { details = true, hl_name = true })
  if #marks > 0 then
    lines[#lines + 1] = string.format("  %d extmark(s) on this row:", #marks)
    for _, m in ipairs(marks) do
      local d = m[4] or {}
      local hl = d.hl_group or (d.virt_text and d.virt_text[1] and d.virt_text[1][2]) or "(no hl)"
      local kind
      if d.virt_text then
        kind = "virt_text=" .. vim.inspect(d.virt_text):gsub("%s+", " ")
      elseif d.virt_lines then
        kind = "virt_lines"
      elseif d.hl_group then
        kind = "highlight"
      else
        kind = "other"
      end
      lines[#lines + 1] = string.format("    [%s] hl=%s  ns=%s", kind, hl, d.ns_id or "?")
    end
  end

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO,
    { title = "highlight under cursor" })
end, { desc = "show every highlight/extmark at cursor" })

