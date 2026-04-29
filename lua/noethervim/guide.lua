-- NoetherVim keymap namespace guide.
-- Interactive reference buffer showing all keymaps organized by namespace.
-- Opened via :NoetherVim keymap-guide or SearchLeader+?
-- See :help noethervim-guide

local M = {}

-- ── Highlight groups ────────────────────────────────────────────

local ns_id

local HL = {
  title   = "NoetherGuideTitle",
  section = "NoetherGuideSection",
  sub     = "NoetherGuideSub",
  key     = "NoetherGuideKey",
  desc    = "NoetherGuideDesc",
  note    = "NoetherGuideNote",
  sep     = "NoetherGuideSep",
}

local function ensure_highlights()
  local links = {
    [HL.title]   = "Title",
    [HL.section] = "Statement",
    [HL.sub]     = "Type",
    [HL.key]     = "Special",
    [HL.desc]    = "Comment",
    [HL.note]    = "DiagnosticInfo",
    [HL.sep]     = "NonText",
  }
  for name, target in pairs(links) do
    if vim.fn.hlexists(name) == 0 or vim.api.nvim_get_hl(0, { name = name }) == nil then
      vim.api.nvim_set_hl(0, name, { link = target })
    end
  end
  if not ns_id then
    ns_id = vim.api.nvim_create_namespace("noethervim_guide")
  end
end

-- ── Builder state ───────────────────────────────────────────────
-- Accumulates lines, extmark highlights, and per-line jump data
-- for the guide buffer.  Reset before each render.

local B = {}

function B.reset()
  B.lines = {}
  B.marks = {}   -- { line_0, col_start, col_end, hl_group }
  B.jump  = {}   -- line_1 -> { mode, lhs }
end

function B.ln(text, hl)
  B.lines[#B.lines + 1] = text or ""
  if hl and text and #text > 0 then
    B.marks[#B.marks + 1] = { #B.lines - 1, 0, #text, hl }
  end
end

function B.sep()
  B.ln(string.rep("\u{2500}", 64), HL.sep)
end

local KEY_WIDTH = 24

--- Render a single keymap entry with aligned columns and highlights.
function B.keymap(lhs_display, desc, lhs_resolved, mode)
  local indent = "    "
  mode = mode or "n"
  local gap = math.max(1, KEY_WIDTH - #lhs_display)
  local text = indent .. lhs_display .. string.rep(" ", gap) .. desc
  B.lines[#B.lines + 1] = text
  B.marks[#B.marks + 1] = {
    #B.lines - 1, #indent, #indent + #lhs_display, HL.key,
  }
  B.marks[#B.marks + 1] = {
    #B.lines - 1, #indent + #lhs_display + gap, #text, HL.desc,
  }
  if lhs_resolved then
    B.jump[#B.lines] = { mode = mode, lhs = lhs_resolved }
  end
end

--- Render a paired keymap entry ([x  ]x  description).
function B.pair(open_d, close_d, desc, open_lhs)
  B.keymap(open_d .. "  " .. close_d, desc, open_lhs, "n")
end

--- Convert a resolved lhs to human-readable display text.
--- keytrans converts special keys to notation (<Space>, <C-W>, etc.)
--- but also escapes literal "<" as "<lt>".  Undo that for display.
local function display_lhs(lhs)
  return vim.fn.keytrans(lhs):gsub("<lt>", "<")
end

-- ── Keymap collection ───────────────────────────────────────────

--- Collect all described keymaps (global + buffer-local for bufnr).
local function collect(bufnr)
  local kms = {}
  for _, mode in ipairs({ "n", "i", "v", "x", "s", "c", "t" }) do
    kms[mode] = {}
    for _, km in ipairs(vim.api.nvim_get_keymap(mode)) do
      if (km.desc or "") ~= "" and not km.lhs:find("<Plug>") then
        kms[mode][km.lhs] = { desc = km.desc }
      end
    end
    -- Buffer-local keymaps override global (captures LSP keymaps, etc.)
    if vim.api.nvim_buf_is_valid(bufnr) then
      for _, km in ipairs(vim.api.nvim_buf_get_keymap(bufnr, mode)) do
        if (km.desc or "") ~= "" and not km.lhs:find("<Plug>") then
          kms[mode][km.lhs] = { desc = km.desc }
        end
      end
    end
  end
  return kms
end

--- Return sorted keymaps matching a prefix, optionally excluding sub-prefixes.
local function prefix_match(mode_kms, pfx, excludes)
  local out = {}
  for lhs, d in pairs(mode_kms) do
    if #lhs > #pfx and lhs:sub(1, #pfx) == pfx then
      local dominated = false
      if excludes then
        for _, ex in ipairs(excludes) do
          if lhs:sub(1, #ex) == ex then
            dominated = true
            break
          end
        end
      end
      if not dominated then
        out[#out + 1] = { lhs = lhs, display = display_lhs(lhs), desc = d.desc }
      end
    end
  end
  table.sort(out, function(a, b) return a.lhs < b.lhs end)
  return out
end

--- Pair up [ / ] keymaps.  Returns (navigation_pairs, option_toggle_pairs).
local function bracket_pairs(mode_kms)
  local open, close = {}, {}
  for lhs, d in pairs(mode_kms) do
    if lhs:sub(1, 1) == "[" and #lhs > 1 then
      open[lhs:sub(2)] = { lhs = lhs, desc = d.desc }
    elseif lhs:sub(1, 1) == "]" and #lhs > 1 then
      close[lhs:sub(2)] = { lhs = lhs, desc = d.desc }
    end
  end

  local seen, suffixes = {}, {}
  for s in pairs(open)  do
    if not seen[s] then seen[s] = true; suffixes[#suffixes + 1] = s end
  end
  for s in pairs(close) do
    if not seen[s] then seen[s] = true; suffixes[#suffixes + 1] = s end
  end
  table.sort(suffixes)

  local nav, opt = {}, {}
  for _, s in ipairs(suffixes) do
    local o, c = open[s], close[s]
    local desc = (c and c.desc) or (o and o.desc) or ""
    -- Strip directional/toggle prefixes to get a clean noun
    desc = desc
      :gsub("^enabling:%s*", ""):gsub("^disabling:%s*", "")
      :gsub("^next%s+", ""):gsub("^prev%s+", "")
      :gsub("^no%s+", "")
    local entry = {
      open_d  = o and display_lhs(o.lhs) or ("[" .. s),
      close_d = c and display_lhs(c.lhs) or ("]" .. s),
      desc    = desc,
      lhs     = o and o.lhs or (c and c.lhs),
    }
    if s:sub(1, 1) == "o" and #s > 1 then
      opt[#opt + 1] = entry
    else
      nav[#nav + 1] = entry
    end
  end
  return nav, opt
end

-- ── Source jumping ──────────────────────────────────────────────
-- Delegates to the shared jump_to_keymap function in inspect.lua,
-- which handles context-aware search patterns, mode-aware matching,
-- comment skipping, lazy handler resolution, and user file fallback.

-- ── Render and display ──────────────────────────────────────────

function M.open()
  ensure_highlights()
  B.reset()

  local source_buf = vim.api.nvim_get_current_buf()
  local kms = collect(source_buf)

  -- Resolve prefix keys
  local sl   = vim.api.nvim_replace_termcodes(
    vim.g.mapsearchleader or "<Space>", true, true, true)
  local sl_d = vim.g.mapsearchleader or "<Space>"
  local ldr  = vim.g.mapleader or "\\"
  local ldr_d = display_lhs(ldr)
  local cw   = vim.api.nvim_replace_termcodes("<C-w>", true, true, true)

  -- Extra lhs values to include in the window section
  local win_extras = {}
  for _, k in ipairs({ "<C-h>", "<C-j>", "<C-k>", "<C-l>" }) do
    win_extras[#win_extras + 1] = vim.api.nvim_replace_termcodes(k, true, true, true)
  end

  -- Track displayed keymaps so "General" section shows only remainders
  local used = {}

  -- ═══════════════════════════════════════════════════════════════
  --  Header
  -- ═══════════════════════════════════════════════════════════════

  B.ln("NoetherVim Keymap Guide", HL.title)
  B.ln(string.rep("\u{2550}", 64), HL.title)
  B.ln()
  B.ln("  Press q to close.  Press <CR> on a keymap to jump to its source.", HL.note)
  B.ln()
  B.ln("  NoetherVim organizes keymaps into semantic namespaces.")
  B.ln("  Each prefix carries a consistent meaning across the distribution.")

  -- ═══════════════════════════════════════════════════════════════
  --  SearchLeader
  -- ═══════════════════════════════════════════════════════════════

  B.ln()
  B.sep()
  B.ln("  SearchLeader (" .. sl_d .. ")  --  fuzzy navigation and search", HL.section)
  B.sep()

  local sl_sub = {
    { key = "f", title = "Find" },
    { key = "g", title = "Grep" },
    { key = "l", title = "LSP" },
    { key = "d", title = "Diagnostics" },
    { key = "G", title = "Git" },
    { key = "c", title = "Config / Inspection" },
  }

  local sl_shown = {}
  for _, sg in ipairs(sl_sub) do
    local items = prefix_match(kms.n, sl .. sg.key)
    if #items > 0 then
      B.ln()
      B.ln("  " .. sg.title, HL.sub)
      for _, it in ipairs(items) do
        B.keymap(it.display, it.desc, it.lhs)
        sl_shown[it.lhs] = true
      end
    end
  end

  -- Remaining SearchLeader keymaps not in a named sub-group
  local sl_rest = {}
  for lhs, d in pairs(kms.n) do
    if lhs:sub(1, #sl) == sl and not sl_shown[lhs] then
      sl_rest[#sl_rest + 1] = { lhs = lhs, display = display_lhs(lhs), desc = d.desc }
    end
  end
  if #sl_rest > 0 then
    table.sort(sl_rest, function(a, b) return a.lhs < b.lhs end)
    B.ln()
    B.ln("  Other", HL.sub)
    for _, it in ipairs(sl_rest) do
      B.keymap(it.display, it.desc, it.lhs)
    end
  end

  for lhs in pairs(kms.n) do
    if lhs:sub(1, #sl) == sl then used[lhs] = true end
  end

  -- ═══════════════════════════════════════════════════════════════
  --  [ / ]  directional navigation and toggles
  -- ═══════════════════════════════════════════════════════════════

  B.ln()
  B.sep()
  B.ln("  [ / ]  --  directional navigation and toggles", HL.section)
  B.sep()
  B.ln()
  B.ln("  [ = backward / previous / enable    ] = forward / next / disable", HL.note)

  local nav, opt = bracket_pairs(kms.n)

  if #nav > 0 then
    B.ln()
    B.ln("  Navigation", HL.sub)
    for _, p in ipairs(nav) do
      B.pair(p.open_d, p.close_d, p.desc, p.lhs)
    end
  end
  if #opt > 0 then
    B.ln()
    B.ln("  Option Toggles   [o = on,  ]o = off", HL.sub)
    for _, p in ipairs(opt) do
      B.pair(p.open_d, p.close_d, p.desc, p.lhs)
    end
  end

  for lhs in pairs(kms.n) do
    if lhs:sub(1, 1) == "[" or lhs:sub(1, 1) == "]" then used[lhs] = true end
  end

  -- ═══════════════════════════════════════════════════════════════
  --  <C-w>  window and panel management
  -- ═══════════════════════════════════════════════════════════════

  B.ln()
  B.sep()
  B.ln("  <C-w>  --  window and panel management", HL.section)
  B.sep()
  B.ln()

  -- <C-h/j/k/l> shortcuts
  for _, lhs in ipairs(win_extras) do
    local d = kms.n[lhs]
    if d and not used[lhs] then
      B.keymap(display_lhs(lhs), d.desc, lhs)
      used[lhs] = true
    end
  end

  -- <C-w> prefixed keymaps
  local cw_items = prefix_match(kms.n, cw)
  for _, it in ipairs(cw_items) do
    if not used[it.lhs] then
      B.keymap(it.display, it.desc, it.lhs)
      used[it.lhs] = true
    end
  end

  -- Split/tab shortcuts (|, +, _) are conceptually window management
  for _, k in ipairs({ "|", "+", "_" }) do
    local d = kms.n[k]
    if d and not used[k] then
      B.keymap(k, d.desc, k)
      used[k] = true
    end
  end

  -- Arrow keys for resize
  for _, k in ipairs({ "<Up>", "<Down>", "<Left>", "<Right>" }) do
    local lhs = vim.api.nvim_replace_termcodes(k, true, true, true)
    local d = kms.n[lhs]
    if d and not used[lhs] then
      B.keymap(display_lhs(lhs), d.desc, lhs)
      used[lhs] = true
    end
  end

  -- ═══════════════════════════════════════════════════════════════
  --  g  goto and LSP actions
  -- ═══════════════════════════════════════════════════════════════

  -- Collect g-keymaps that aren't already used (avoids overlap with
  -- SearchLeader keymaps like <Space>gp if SearchLeader were 'g').
  local g_items = prefix_match(kms.n, "g")
  local g_filtered = {}
  for _, it in ipairs(g_items) do
    if not used[it.lhs] then
      g_filtered[#g_filtered + 1] = it
    end
  end

  if #g_filtered > 0 then
    B.ln()
    B.sep()
    B.ln("  g  --  goto and LSP actions", HL.section)
    B.sep()
    B.ln()
    B.ln("  LSP keymaps require an attached language server.", HL.note)
    B.ln()
    for _, it in ipairs(g_filtered) do
      B.keymap(it.display, it.desc, it.lhs)
      used[it.lhs] = true
    end
  end

  -- ═══════════════════════════════════════════════════════════════
  --  Z  buffer management
  -- ═══════════════════════════════════════════════════════════════

  local z_items = prefix_match(kms.n, "Z")
  local z_filtered = {}
  for _, it in ipairs(z_items) do
    if not used[it.lhs] then z_filtered[#z_filtered + 1] = it end
  end

  if #z_filtered > 0 then
    B.ln()
    B.sep()
    B.ln("  Z  --  buffer management", HL.section)
    B.sep()
    B.ln()
    for _, it in ipairs(z_filtered) do
      B.keymap(it.display, it.desc, it.lhs)
      used[it.lhs] = true
    end
  end

  -- ═══════════════════════════════════════════════════════════════
  --  <Leader>  global actions
  -- ═══════════════════════════════════════════════════════════════

  local ldr_items = prefix_match(kms.n, ldr)
  local ldr_filtered = {}
  for _, it in ipairs(ldr_items) do
    if not used[it.lhs] then ldr_filtered[#ldr_filtered + 1] = it end
  end

  if #ldr_filtered > 0 then
    B.ln()
    B.sep()
    B.ln("  <Leader> (" .. ldr_d .. ")  --  global actions", HL.section)
    B.sep()
    B.ln()
    for _, it in ipairs(ldr_filtered) do
      B.keymap(it.display, it.desc, it.lhs)
      used[it.lhs] = true
    end
  end

  -- ═══════════════════════════════════════════════════════════════
  --  Normal mode  general
  -- ═══════════════════════════════════════════════════════════════

  local general = {}
  for lhs, d in pairs(kms.n) do
    if not used[lhs] then
      general[#general + 1] = { lhs = lhs, display = display_lhs(lhs), desc = d.desc }
    end
  end

  if #general > 0 then
    table.sort(general, function(a, b) return a.lhs < b.lhs end)
    B.ln()
    B.sep()
    B.ln("  Normal mode  --  general", HL.section)
    B.sep()
    B.ln()
    for _, it in ipairs(general) do
      B.keymap(it.display, it.desc, it.lhs)
    end
  end

  -- ═══════════════════════════════════════════════════════════════
  --  Insert mode
  -- ═══════════════════════════════════════════════════════════════

  local insert = {}
  for lhs, d in pairs(kms.i) do
    insert[#insert + 1] = { lhs = lhs, display = display_lhs(lhs), desc = d.desc }
  end

  if #insert > 0 then
    table.sort(insert, function(a, b) return a.lhs < b.lhs end)
    B.ln()
    B.sep()
    B.ln("  Insert mode", HL.section)
    B.sep()
    B.ln()
    for _, it in ipairs(insert) do
      B.keymap(it.display, it.desc, it.lhs, "i")
    end
  end

  -- ═══════════════════════════════════════════════════════════════
  --  Visual mode
  -- ═══════════════════════════════════════════════════════════════

  local visual = {}
  for lhs, d in pairs(kms.v) do
    visual[#visual + 1] = { lhs = lhs, display = display_lhs(lhs), desc = d.desc }
  end

  if #visual > 0 then
    table.sort(visual, function(a, b) return a.lhs < b.lhs end)
    B.ln()
    B.sep()
    B.ln("  Visual mode", HL.section)
    B.sep()
    B.ln()
    for _, it in ipairs(visual) do
      B.keymap(it.display, it.desc, it.lhs, "v")
    end
  end

  -- ═══════════════════════════════════════════════════════════════
  --  Command-line mode
  -- ═══════════════════════════════════════════════════════════════

  local cmdline = {}
  for lhs, d in pairs(kms.c) do
    cmdline[#cmdline + 1] = { lhs = lhs, display = display_lhs(lhs), desc = d.desc }
  end

  if #cmdline > 0 then
    table.sort(cmdline, function(a, b) return a.lhs < b.lhs end)
    B.ln()
    B.sep()
    B.ln("  Command-line mode", HL.section)
    B.sep()
    B.ln()
    for _, it in ipairs(cmdline) do
      B.keymap(it.display, it.desc, it.lhs, "c")
    end
  end

  -- ═══════════════════════════════════════════════════════════════
  --  Create the buffer
  -- ═══════════════════════════════════════════════════════════════

  vim.cmd("tabnew")
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].buftype   = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile  = false
  vim.bo[buf].filetype  = "noethervim-guide"
  pcall(vim.api.nvim_buf_set_name, buf, "noethervim://guide")

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, B.lines)
  vim.bo[buf].modifiable = false

  -- Apply highlights
  for _, m in ipairs(B.marks) do
    pcall(vim.api.nvim_buf_add_highlight, buf, ns_id, m[4], m[1], m[2], m[3])
  end

  vim.api.nvim_win_set_cursor(0, { 1, 0 })

  -- Buffer-local keymaps
  local jump_data = B.jump
  vim.keymap.set("n", "q", "<cmd>close<cr>", {
    buffer = buf, silent = true, nowait = true,
  })
  vim.keymap.set("n", "<CR>", function()
    local row = vim.api.nvim_win_get_cursor(0)[1]
    local data = jump_data[row]
    if not data then return end
    require("noethervim.inspect").jump_to_keymap(data.mode, data.lhs)
  end, {
    buffer = buf, silent = true, desc = "jump to keymap source",
  })
end

return M
