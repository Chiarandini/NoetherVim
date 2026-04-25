--- Setup-time registry of keymap registration sites.
---
--- During `noethervim.setup()` we wrap `vim.keymap.set` so every call
--- records the file and line of the callsite, keyed by mode|resolved_lhs.
--- The wrapper is installed once and removed before `setup()` returns --
--- nothing persists into user-time. Users writing `vim.keymap.set` at
--- runtime (ftplugin, post-load plugin configs, interactive :lua) hit the
--- stock function.
---
--- Consumers (the :NoetherVim diff keymaps picker, the guide jump
--- handler) look up entries via `lookup(mode, resolved_lhs)`, which
--- returns an authoritative { file, line } when available. Lazy-managed
--- `keys = {...}` specs bypass the wrapper and are attributed through
--- `util.keymap_sources()` instead.

local M = {}

M._registry = {}   -- [mode|resolved_lhs] = { file, line }  (last-write-wins)
M._history  = {}   -- [mode|resolved_lhs] = { {file, line}, ... }  (all writes, for overlap detection)
M._orig     = nil

--- Canonicalise an lhs into the exact form `nvim_get_keymap` reports.
---
--- The round-trip has four steps:
---   1. Expand `<Leader>` / `<LocalLeader>` (case-insensitive) -- the
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

--- File-content cache used during stack-climbing to detect helper frames.
--- Cleared when the wrapper uninstalls.
local _line_cache = {}
local function read_line(file, n)
  if n == nil or n <= 0 then return nil end
  local c = _line_cache[file]
  if c == nil then
    local ok, lines = pcall(vim.fn.readfile, file)
    c = (ok and lines) or false
    _line_cache[file] = c
  end
  if c == false then return nil end
  return c[n]
end

--- Does the source at `file:line` contain a literal string matching a
--- canonical form of the lhs? If yes, the frame is the "semantic"
--- registration site. If no, we are probably inside a helper (e.g.
--- `toggles.lua`'s local `map()` that calls `vim.keymap.set(lhs, ...)`
--- with a variable), and the true registration site is further up.
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

local function frame_has_literal(file, line, resolved_lhs)
  local text = read_line(file, line)
  if not text then return false end
  local ctext = canon(text)
  -- Generate the handful of forms a human would plausibly write.
  local forms = { resolved_lhs, vim.fn.keytrans(resolved_lhs) }
  -- Also try the fully-resolved byte form (e.g. `<lt>t` stored in the
  -- registry → source-written form `<t`). `nvim_replace_termcodes`
  -- strips the `<lt>` notation but leaves `<C-x>` as control bytes;
  -- control bytes will never match printable source, so this helps for
  -- `<lt>`, `<Space>`, and similar printable escapes without hurting
  -- the ctrl cases.
  local resolved = vim.api.nvim_replace_termcodes(resolved_lhs, true, true, true)
  if resolved ~= resolved_lhs then forms[#forms + 1] = resolved end
  if resolved_lhs:match("^[%[%]]") then
    forms[#forms + 1] = resolved_lhs:sub(2)
  end
  local leader      = vim.g.mapleader or "\\"
  local localleader = vim.g.maplocalleader or "\\"
  local sl          = vim.g.mapsearchleader or "<Space>"
  local resolved_sl = vim.api.nvim_replace_termcodes(sl, true, true, true)
  if #leader > 0 and resolved_lhs:sub(1, #leader) == leader then
    forms[#forms + 1] = "<leader>" .. resolved_lhs:sub(#leader + 1)
    forms[#forms + 1] = "<Leader>" .. resolved_lhs:sub(#leader + 1)
  end
  if #localleader > 0 and resolved_lhs:sub(1, #localleader) == localleader then
    forms[#forms + 1] = "<localleader>" .. resolved_lhs:sub(#localleader + 1)
    forms[#forms + 1] = "<LocalLeader>" .. resolved_lhs:sub(#localleader + 1)
  end
  if #resolved_sl > 0 and resolved_lhs:sub(1, #resolved_sl) == resolved_sl then
    local tail = resolved_lhs:sub(#resolved_sl + 1)
    local tn = vim.fn.keytrans(tail)
    if tn ~= tail then
      forms[#forms + 1] = tn
    else
      forms[#forms + 1] = tail
    end
  end
  -- Expand key-notation synonyms over the forms collected so far.
  local syn = {}
  for _, f in ipairs(forms) do
    for _, pair in ipairs(KEY_SYNONYMS) do
      if f:find(pair[1]) then syn[#syn + 1] = f:gsub(pair[1], pair[2]) end
    end
  end
  for _, s in ipairs(syn) do forms[#forms + 1] = s end

  for _, f in ipairs(forms) do
    if f and f ~= "" then
      local cf = canon(f)
      if ctext:find('"' .. cf .. '"', 1, true)
         or ctext:find("'" .. cf .. "'", 1, true) then
        return true
      end
    end
  end
  return false
end

--- Pick the "best" stack frame for attributing this `vim.keymap.set`
--- call. Starts at the user's immediate caller (depth 3: skip the
--- wrapper closure at depth 2 and this helper at depth 1) and climbs
--- until it finds a frame whose source line contains a literal form of
--- the lhs. Falls back to the first user frame if nothing qualifies,
--- preserving the baseline behaviour.
local function pick_frame(resolved_lhs)
  local fallback_file, fallback_line
  for depth = 3, 8 do
    local info = debug.getinfo(depth, "Sl")
    if not info or not info.source then break end
    local file = info.source
    if file:sub(1, 1) == "@" then file = file:sub(2) end
    if file == "" or file:match("^%[") then break end
    local line = info.currentline or 0
    if not fallback_file then
      fallback_file, fallback_line = file, line
    end
    if frame_has_literal(file, line, resolved_lhs) then
      return file, line
    end
  end
  return fallback_file or "", fallback_line or 0
end

--- Install the wrapper. Idempotent -- a second call is a no-op.
function M.install()
  if M._orig then return end
  M._orig = vim.keymap.set
  vim.keymap.set = function(mode, lhs, rhs, opts)
    local modes = type(mode) == "table" and mode or { mode }
    local resolved = resolve_lhs(lhs)
    local file, line = pick_frame(resolved)
    for _, m in ipairs(modes) do
      local key = m .. "|" .. resolved
      M._registry[key] = { file = file, line = line }
      M._history[key] = M._history[key] or {}
      table.insert(M._history[key], { file = file, line = line })
    end
    return M._orig(mode, lhs, rhs, opts)
  end
end

--- Restore the stock `vim.keymap.set`. Only restores if our wrapper is
--- still the active function; if something else has taken over, leave
--- that in place (we're already orphaned).
function M.uninstall()
  if not M._orig then return end
  -- We cannot reliably detect "is our wrapper still active" without
  -- tagging it; in practice nothing else wraps during setup, so restore
  -- unconditionally and clear _orig to mark uninstalled.
  vim.keymap.set = M._orig
  M._orig = nil
  _line_cache = {}  -- free the read-file cache
end

--- Return the registration entry for a (mode, resolved_lhs) pair, or nil.
---@param mode string         single-letter mode as reported by nvim_get_keymap
---@param resolved_lhs string lhs in the form nvim_get_keymap returns
---@return { file: string, line: integer } | nil
function M.lookup(mode, resolved_lhs)
  return M._registry[mode .. "|" .. resolved_lhs]
end

--- Return the full registration history for a (mode, resolved_lhs) pair.
--- Used for overlap detection in the landing test suite: entries with
--- more than one history item indicate either an override (distro then
--- user) or a duplicate (two writes within the same scope).
---@param mode string
---@param resolved_lhs string
---@return { file: string, line: integer }[]
function M.history(mode, resolved_lhs)
  return M._history[mode .. "|" .. resolved_lhs] or {}
end

--- Expose the canonicalisation used internally, so consumers (e.g. the
--- landing test oracle) can translate source-form lhs values into the
--- exact keys `lookup`/`history` use.
---@param lhs string
---@return string
M.resolve_lhs = resolve_lhs

--- Public helper exposing the notation canonicaliser. Returns a string
--- where every `<...>` group has its contents upper-cased, so `<c-a>`
--- and `<C-A>` compare equal.
---@param s string
---@return string
M.canon = canon

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
