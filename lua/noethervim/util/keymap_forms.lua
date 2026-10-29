--- Source-text forms of a keymap lhs.
---
--- `nvim_get_keymap` reports an lhs in one canonical notation, while source
--- files write it any of several ways: `<leader>x`, `<C-a>`, a
--- SearchLeader concatenation. These helpers produce the plausible written
--- forms so the keymap source finder (util.keymap_source) and the keymap
--- diff picker can locate the line that defines a key.

local M = {}

--- Canonicalise a lhs into the exact form `nvim_get_keymap` reports.
---
--- The round-trip has four steps:
---   1. Expand `<Leader>` / `<LocalLeader>` (case-insensitive). The
---      keymap API does this silently when setting, and `nvim_get_keymap`
---      reports the expanded form.
---   2. `nvim_replace_termcodes` maps every `<Xxx>` form to its internal
---      byte representation.
---   3. `keytrans` reverses (2) back into notation, normalising case
---      (`<C-a>` → `<C-A>`, `<A-x>` → `<M-x>`, etc.).
---   4. `<Space>` is substituted back to a literal space, because
---      `nvim_get_keymap` leaves printable chars (including space) as
---      themselves rather than re-escaping them.
---@param lhs string
---@return string
local function resolve_lhs(lhs)
  local leader      = vim.g.mapleader or "\\"
  local localleader = vim.g.maplocalleader or "\\"
  local s = lhs
  s = s:gsub("<[Ll][Ee][Aa][Dd][Ee][Rr]>",      function() return leader end)
  s = s:gsub("<[Ll][Oo][Cc][Aa][Ll][Ll]eader>", function() return localleader end)
  s = vim.api.nvim_replace_termcodes(s, true, true, true)
  s = vim.fn.keytrans(s)
  s = s:gsub("<Space>", " ")
  return s
end

--- The canonical notation `nvim_get_keymap` reports for `lhs`.
---@type fun(lhs: string): string
M.resolve_lhs = resolve_lhs

--- Canonicalise a string by upper-casing letters between `<` and `>`.
--- The inner class excludes `<`, `>`, and newlines so that:
---   * `"<t", "<cmd>"` is parsed as two separate notation attempts (one
---     unclosed, one closed), not a single span;
---   * a stray `<` (e.g. Lua `<` comparison) does NOT swallow content
---     across line boundaries until the next `>` somewhere later in the
---     file, which would falsely uppercase whole regions when canon is
---     run over a concatenated buffer.
local function canon(s)
  return (s:gsub("<([^<>\n]*)>", function(inner) return "<" .. inner:upper() .. ">" end))
end

--- Returns `s` with every `<...>` group upper-cased, so `<c-a>` and
--- `<C-A>` compare equal.
---@type fun(s: string): string
M.canon = canon

--- Key-notation synonyms that the API collapses but source code may
--- still write in either form.
local KEY_SYNONYMS = {
  { "<[Mm]%-",          "<A-" }, { "<[Aa]%-",     "<M-" },
  { "<[Nn][Ll]>",       "<C-J>" }, { "<[Cc]%-[Jj]>", "<NL>" },
  { "<[Rr]eturn>",      "<CR>" }, { "<[Cc][Rr]>",   "<Return>" },
  { "<[Cc]%-[Mm]>",     "<CR>" }, { "<[Cc][Rr]>",   "<C-M>" },
  { "<[Tt]ab>",         "<C-I>" }, { "<[Cc]%-[Ii]>", "<Tab>" },
  { "<[Bb][Ss]>",       "<C-H>" }, { "<[Cc]%-[Hh]>", "<BS>" },
  { "<[Ee][Ss][Cc]>",   "<C-[>" }, { "<[Cc]%-%[>",   "<Esc>" },
}

--- Round-trip an lhs through replace_termcodes → keytrans to produce
--- the canonical notation form. Calling `keytrans` directly on an
--- already-notation string (e.g. `" <C-B>"` returned literally by
--- nvim_get_keymap) over-escapes the `<` to `<lt>`, producing the
--- wrong form `<Space><lt>C-B>`. Round-tripping forces resolution to
--- bytes first, so keytrans then re-emits the canonical `<Space><C-B>`.
local function safe_keytrans(s)
  return vim.fn.keytrans(vim.api.nvim_replace_termcodes(s, true, true, true))
end

--- Return every plausible source-written form of `resolved_lhs`,
--- separated into two lists:
---
---   primary    -- forms that may match anywhere in source. Includes
---                 the literal lhs, its notation, leader-stripped
---                 forms, SNR→SID translation, and synonym expansions.
---   sl_tail    -- forms derived by stripping the SearchLeader prefix
---                 (e.g. lhs `<Space>/` → tail `"/"`). These match
---                 ONLY on lines that also contain a `SearchLeader`
---                 token, since a bare quoted `"/"` in random code is
---                 not a keymap registration.
---
--- Callers that walk source files should use `primary` everywhere and
--- `sl_tail` only where the SL-context predicate also holds.
---@param resolved_lhs string
---@return string[] primary, string[] sl_tail
function M.source_forms_split(resolved_lhs)
  local primary, tail = {}, {}
  local seen_p, seen_t = {}, {}
  local function add_p(f)
    if not f or f == "" or seen_p[f] then return end
    seen_p[f] = true; primary[#primary + 1] = f
  end
  local function add_t(f)
    if not f or f == "" or seen_t[f] then return end
    seen_t[f] = true; tail[#tail + 1] = f
  end

  add_p(resolved_lhs)
  local notation = safe_keytrans(resolved_lhs)
  if notation ~= resolved_lhs then add_p(notation) end
  local resolved = vim.api.nvim_replace_termcodes(resolved_lhs, true, true, true)
  if resolved ~= resolved_lhs then add_p(resolved) end

  -- Vimscript script-local namespace: `<SNR>42_(name)` is the API form,
  -- but source files write `<sid>(name)` / `<SID>(name)` -- the script
  -- number is assigned at runtime so it never appears as a literal.
  local snr_tail = resolved_lhs:match("^<[Ss][Nn][Rr]>%d+_(.*)$")
  if snr_tail then
    add_p("<sid>" .. snr_tail)
    add_p("<SID>" .. snr_tail)
  end

  local leader      = vim.g.mapleader or "\\"
  local localleader = vim.g.maplocalleader or "\\"
  local sl          = vim.g.mapsearchleader or "<Space>"
  local resolved_sl = vim.api.nvim_replace_termcodes(sl, true, true, true)
  if #leader > 0 and resolved_lhs:sub(1, #leader) == leader then
    add_p("<leader>" .. resolved_lhs:sub(#leader + 1))
    add_p("<Leader>" .. resolved_lhs:sub(#leader + 1))
  end
  if #localleader > 0 and resolved_lhs:sub(1, #localleader) == localleader then
    add_p("<localleader>" .. resolved_lhs:sub(#localleader + 1))
    add_p("<LocalLeader>" .. resolved_lhs:sub(#localleader + 1))
  end

  -- SearchLeader tail goes into the SL-context-only bucket so a quoted
  -- single character (`"/"`, `" "`) does not produce false positives in
  -- unrelated string literals.
  if #resolved_sl > 0 and resolved_lhs:sub(1, #resolved_sl) == resolved_sl then
    local tail_str = resolved_lhs:sub(#resolved_sl + 1)
    local tn = safe_keytrans(tail_str)
    if tn ~= tail_str then
      add_t(tn)
    else
      add_t(tail_str)
    end
  end

  -- Synonym expansion across both buckets.
  local syn_p, syn_t = {}, {}
  for _, f in ipairs(primary) do
    for _, pair in ipairs(KEY_SYNONYMS) do
      if f:find(pair[1]) then syn_p[#syn_p + 1] = f:gsub(pair[1], pair[2]) end
    end
  end
  for _, f in ipairs(tail) do
    for _, pair in ipairs(KEY_SYNONYMS) do
      if f:find(pair[1]) then syn_t[#syn_t + 1] = f:gsub(pair[1], pair[2]) end
    end
  end
  for _, s in ipairs(syn_p) do add_p(s) end
  for _, s in ipairs(syn_t) do add_t(s) end

  return primary, tail
end

--- Back-compat: callers that want every form in one list (no SL context
--- filtering) get them concatenated. New code should prefer
--- `source_forms_split` so SL-tail false-positives can be suppressed.
---@param resolved_lhs string
---@return string[]
function M.source_forms(resolved_lhs)
  local primary, tail = M.source_forms_split(resolved_lhs)
  for _, f in ipairs(tail) do primary[#primary + 1] = f end
  return primary
end

--- True iff the line looks like a SearchLeader concatenation context
--- (`SearchLeader .. "x"`, `SL .. "x"`, etc.) where a bare-tail form
--- can safely be matched. Used to gate SL-tail forms from
--- `source_forms_split`.
function M.line_has_sl_context(line)
  return line:find("SearchLeader") ~= nil
      or line:find("[%w_]SL[%w_]?%s*%.%.") ~= nil
      or line:find("[%s%(%[%{,]sl%s*%.%.") ~= nil
end

return M
