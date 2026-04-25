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
    forms[#forms + 1] = tail
    local tn = vim.fn.keytrans(tail)
    if tn ~= tail then forms[#forms + 1] = tn end
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

--- Return every plausible source-written form of `resolved_lhs`. Used
--- by locate cascades and by attribution logic that needs to check
--- whether a file contains the lhs in any notation.
---@param resolved_lhs string
---@return string[]
function M.source_forms(resolved_lhs)
  local forms, seen = {}, {}
  local function add(f)
    if not f or f == "" or seen[f] then return end
    seen[f] = true
    forms[#forms + 1] = f
  end
  add(resolved_lhs)
  local notation = vim.fn.keytrans(resolved_lhs)
  if notation ~= resolved_lhs then add(notation) end
  local resolved = vim.api.nvim_replace_termcodes(resolved_lhs, true, true, true)
  if resolved ~= resolved_lhs then add(resolved) end
  -- Vimscript script-local namespace: `<SNR>42_(name)` is the API form,
  -- but source files write `<sid>(name)` / `<SID>(name)` -- the script
  -- number is assigned at runtime so it never appears as a literal. We
  -- synthesise both spellings of the source form whenever the lhs has a
  -- resolved SNR prefix.
  local snr_tail = resolved_lhs:match("^<[Ss][Nn][Rr]>%d+_(.*)$")
  if snr_tail then
    add("<sid>" .. snr_tail)
    add("<SID>" .. snr_tail)
  end
  -- Bracket-strip (e.g. `[oa` → `oa`) is intentionally NOT added: the
  -- stripped form may be a legitimate distinct keymap. Callers that
  -- want toggle-helper matching should check `toggle(` context and
  -- derive the base explicitly.

  local leader      = vim.g.mapleader or "\\"
  local localleader = vim.g.maplocalleader or "\\"
  local sl          = vim.g.mapsearchleader or "<Space>"
  local resolved_sl = vim.api.nvim_replace_termcodes(sl, true, true, true)
  if #leader > 0 and resolved_lhs:sub(1, #leader) == leader then
    add("<leader>" .. resolved_lhs:sub(#leader + 1))
    add("<Leader>" .. resolved_lhs:sub(#leader + 1))
  end
  if #localleader > 0 and resolved_lhs:sub(1, #localleader) == localleader then
    add("<localleader>" .. resolved_lhs:sub(#localleader + 1))
    add("<LocalLeader>" .. resolved_lhs:sub(#localleader + 1))
  end
  if #resolved_sl > 0 and resolved_lhs:sub(1, #resolved_sl) == resolved_sl then
    local tail = resolved_lhs:sub(#resolved_sl + 1)
    add(tail)
    local tn = vim.fn.keytrans(tail)
    if tn ~= tail then add(tn) end
  end

  -- Synonym expansion.
  local syn = {}
  for _, f in ipairs(forms) do
    for _, pair in ipairs(KEY_SYNONYMS) do
      if f:find(pair[1]) then syn[#syn + 1] = f:gsub(pair[1], pair[2]) end
    end
  end
  for _, s in ipairs(syn) do add(s) end
  return forms
end

return M
