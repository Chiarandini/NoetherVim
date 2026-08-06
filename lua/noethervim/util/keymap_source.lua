--- Keymap source attribution and navigation.
---
--- Answers two questions about a `(mode, resolved_lhs)` pair:
---   1. Where was it defined?  (`M.owner_file`, `M.origin`)
---   2. Take me there.         (`M.jump`)
---
--- Attribution is driven by four data sources, in priority order:
---
---   1. `keymap_registry`: a setup-time wrapper around `vim.keymap.set`
---      records the file+line of every imperative registration. This is
---      authoritative -- the file is exactly the callsite.
---   2. `util.keymap_sources()`: maps lazy.nvim handler keys to the plugin
---      spec file that owns them. Used for `keys = { ... }` entries that
---      bypass the wrapper.
---   3. Callback introspection via `debug.getinfo(callback, "S")`: for
---      any keymap whose callback is a Lua function, its defining file
---      is usually a good hint. This is the only source that covers
---      keymaps registered after setup() returned -- plugin `config`
---      bodies, ftplugins, and anything loaded at VeryLazy.
---   4. A project-wide text scan, as a last resort.
---
--- Once the file is known, `find_lhs_line` does a canon-aware plain-text
--- search for the lhs to position the cursor.

local M = {}

-- ── Classification ───────────────────────────────────────────────

--- Compare two keymap snapshots for equality.
--- Callback functions from nvim_get_keymap get new references on each
--- call, so identity comparison fails for Neovim defaults.  When both
--- have callbacks and the same rhs, fall back to comparing `desc`: two
--- distinct Lua mappings on the same lhs (e.g. Neovim's `:cnext` default
--- versus NoetherVim's quickfix/Trouble wrapper) are otherwise
--- indistinguishable and would be silently filtered as "unchanged".
function M.same_mapping(a, b)
  if a.rhs ~= b.rhs then return false end
  if a.callback == b.callback then return true end
  if a.callback and b.callback then return (a.desc or "") == (b.desc or "") end
  return false
end

--- Is this keymap a Neovim built-in default? Two signals: a callback
--- defined somewhere in the Neovim runtime (`vim/_core/defaults.lua` and
--- friends), or a desc following the `:help <X>-default` convention used
--- by rhs-only builtins like `&`, `Y`, `<C-L>`.
---
--- Needed in addition to the baseline snapshot because a chunk of the
--- 0.12 defaults register lazily, after `noethervim.setup()` has already
--- taken its baseline.
---
--- Deliberately does NOT test `km.sid < 0`: the negative script-id range
--- is a set of sentinels, and the one these keymaps carry is `SID_LUA`
--- (-8), meaning "set from Lua" -- true of every Lua keymap in the
--- config, not just Neovim's own.
---@param km table  A keymap as returned by nvim_get_keymap
function M.is_nvim_default(km)
  local file = M.callback_file(km.callback)
  if file then
    -- Runtime Lua modules are loaded with a bare chunkname (`vim/_core/
    -- defaults`, no directory, no extension), so an absolute-path test
    -- alone misses them. Both spellings are checked.
    if file:match("^vim[/%.]") then return true end
    local rt = vim.env.VIMRUNTIME
    if rt and rt ~= "" and vim.startswith(vim.fs.normalize(file), vim.fs.normalize(rt)) then
      return true
    end
  end
  if km.desc and km.desc:match("^:help .+%-default$") then return true end
  return false
end

--- Is this keymap a lazy.nvim loading stub rather than a real definition?
--- Lazy installs one for every `keys = { ... }` spec entry; its callback
--- lives in lazy's own handler, so callback introspection would attribute
--- the key to lazy.nvim instead of the spec file that declared it.
---@param km? table  A keymap as returned by nvim_get_keymap
function M.is_lazy_stub(km)
  if not km then return false end
  local file = M.callback_file(km.callback)
  return file ~= nil and file:find("lazy/core/handler", 1, true) ~= nil
end

--- Return the Lua source file that defines `callback`, or nil.
function M.callback_file(callback)
  if type(callback) ~= "function" then return nil end
  local info = debug.getinfo(callback, "S")
  if not info or not info.source then return nil end
  local src = info.source
  if src:sub(1, 1) == "@" then src = src:sub(2) end
  if src == "" or src:match("^%[") then return nil end
  return src
end

-- ── Origin (which part of the config owns this key) ──────────────

local function distro_root()
  if vim.g.noethervim_dev then return vim.fn.expand(vim.g.noethervim_dev) end
  local init = vim.api.nvim_get_runtime_file("lua/noethervim/init.lua", false)[1]
  return init and vim.fn.fnamemodify(init, ":h:h:h") or nil
end

--- Map an absolute path to a short origin label, or nil when the path is
--- outside the distro and user trees (third-party plugin, Neovim runtime).
---
--- Bundle files yield their own stem so a user can tell at a glance which
--- opt-in bundle a key came from; everything else in the distro is "core".
---@param path? string
---@return string? origin  bundle stem, "core", "user", or nil
function M.origin_of_file(path)
  if not path or path == "" then return nil end
  local p = vim.fs.normalize(path)
  local bundle = p:match("/lua/noethervim/bundles/[^/]+/([^/]+)%.lua$")
  if bundle then return bundle end
  local root = distro_root()
  if root and vim.startswith(p, vim.fs.normalize(root)) then return "core" end
  if vim.startswith(p, vim.fs.normalize(vim.fn.stdpath("config") .. "/lua/user")) then
    return "user"
  end
  return nil
end

--- Name of the lazy plugin whose tree contains `path`, or nil.
--- In a released install NoetherVim itself lives under the lazy root, so
--- a plain "is it under lazy/" test would call the distro a third-party
--- plugin; `origin_of_file` is consulted first to rule that out.
---@param path? string
---@return string? plugin_name
function M.plugin_of_file(path)
  if not path or path == "" then return nil end
  if M.origin_of_file(path) then return nil end
  local p = vim.fs.normalize(path)
  local root = vim.fs.normalize(vim.fn.stdpath("data") .. "/lazy") .. "/"
  if not vim.startswith(p, root) then return nil end
  local name = p:sub(#root + 1):match("^([^/]+)")
  -- lazy.nvim is the loader, never the answer to "who defines this key".
  if name == "lazy.nvim" then return nil end
  return name
end

--- Name the plugin behind a `<Plug>`-based rhs, or nil.
---
--- Rescues rhs-only plugin keymaps, which have no callback to introspect
--- and so leave the file-based cascade with nothing to go on. Their rhs
--- almost always names the plugin: nvim-surround maps `<C-g>s` to
--- `<Plug>(nvim-surround-insert)`. The payload is matched against lazy's
--- plugin names, longest first so `nvim-surround` beats a shorter plugin
--- that happens to share a prefix.
---@param rhs? string
---@return string? plugin_name
function M.plugin_from_rhs(rhs)
  if not rhs or rhs == "" then return nil end
  local payload = rhs:match("<[Pp]lug>%((.-)%)") or rhs:match("<[Pp]lug>([%w_%-%.]+)")
  if not payload then return nil end
  payload = payload:lower()
  local ok, lazy_cfg = pcall(require, "lazy.core.config")
  if not ok or not lazy_cfg.plugins then return nil end
  local best
  for name in pairs(lazy_cfg.plugins) do
    for _, stem in ipairs({ name, (name:gsub("%.nvim$", "")) }) do
      if stem ~= "" and vim.startswith(payload, stem:lower())
         and (not best or #stem > #best.stem) then
        best = { name = name, stem = stem }
      end
    end
  end
  return best and best.name or nil
end

--- The NoetherVim or user spec file that declares `plugin_name`, or nil.
--- This is the file a user edits to change or disable one of the plugin's
--- keymaps, which makes it the useful destination for a key the distro
--- installs but does not itself define.
---@param plugin_name? string
---@return string? spec_file
function M.spec_file_for_plugin(plugin_name)
  if not plugin_name then return nil end
  local by_plugin = require("noethervim.util").plugin_spec_files()
  local files = by_plugin[plugin_name]
  return files and files[1] or nil
end

--- Best-effort owning file for a keymap, without opening any buffer.
--- Consults the registry, then the lazy spec hint, then the callback.
--- Deliberately does NOT run the project-wide scan: this is called once
--- per keymap while building a picker, and the scan is O(files).
---@param mode string
---@param lhs string
---@param opts? { source?: string, callback?: function }
---@return string? path
function M.owner_file(mode, lhs, opts)
  opts = opts or {}
  local entry = require("noethervim.util.keymap_registry").lookup(mode, lhs)
  if entry and entry.file and entry.file ~= "" then return entry.file end
  if opts.source then return opts.source end
  local file = M.callback_file(opts.callback)
  -- A lazy loading stub points at lazy.nvim, which tells us nothing about
  -- who declared the key. Better to report "unknown" than to blame lazy.
  if file and file:find("lazy/core/handler", 1, true) then return nil end
  return file
end

-- ── Source-line location ─────────────────────────────────────────

--- Mode synonyms used so source-attribution tolerates the asymmetric
--- vim mode model: `:vmap` registers in both Visual and Select, `:xmap`
--- only Visual, `:smap` only Select. So when looking for an
--- API-reported `s`-mode keymap, a `vim.keymap.set("v", ...)` line is
--- a valid source.
local MODE_GROUPS = {
  n = { "n" },
  i = { "i" },
  c = { "c" },
  t = { "t" },
  o = { "o" },
  v = { "v", "x" },
  x = { "v", "x" },
  s = { "v", "s" },
}
local VIMSCRIPT_PREFIXES = {
  n = { "nnoremap", "nmap" },
  i = { "inoremap", "imap" },
  v = { "vnoremap", "vmap", "xnoremap", "xmap" },
  x = { "xnoremap", "xmap", "vnoremap", "vmap" },
  s = { "snoremap", "smap", "vnoremap", "vmap" },
  o = { "onoremap", "omap" },
  c = { "cnoremap", "cmap" },
  t = { "tnoremap", "tmap" },
}

--- Does `line` look compatible with `mode` (or be mode-agnostic)?
--- A line is rejected only when it carries explicit conflicting mode
--- evidence -- a vimscript prefix in another mode, a `vim.keymap.set`
--- whose first arg names a different mode, or a `mode = "x"` field
--- inside a lazy `{ "<lhs>", ..., mode = "x" }` entry.
local function line_mode_ok(line, mode, lhs)
  if not mode then return true end
  -- `<Plug>` mappings are plugin-internal handles that frequently get
  -- registered in unexpected mode combinations; trying to filter them
  -- by mode produces false negatives. Skip the mode check entirely.
  if lhs and lhs:find("<[Pp]lug>", 1, false) then return true end
  for k, prefixes in pairs(VIMSCRIPT_PREFIXES) do
    for _, p in ipairs(prefixes) do
      if line:match("^%s*" .. p .. "%s") or line:match("^%s*" .. p .. "!%s") then
        return MODE_GROUPS[mode] and vim.tbl_contains(MODE_GROUPS[mode], k)
      end
    end
  end
  local first = line:match("vim%.keymap%.set%s*%(%s*({[^}]+})")
  if first then
    local accept = MODE_GROUPS[mode] or { mode }
    for _, m in ipairs(accept) do
      if first:find('"' .. m .. '"', 1, true) or first:find("'" .. m .. "'", 1, true) then
        return true
      end
    end
    return false
  end
  first = line:match("vim%.keymap%.set%s*%(%s*[\"']([^\"']+)[\"']")
  if first then
    local accept = MODE_GROUPS[mode] or { mode }
    return vim.tbl_contains(accept, first)
  end
  local mode_attr = line:match('mode%s*=%s*"([^"]+)"')
                 or line:match("mode%s*=%s*'([^']+)'")
  if mode_attr then
    local accept = MODE_GROUPS[mode] or { mode }
    return vim.tbl_contains(accept, mode_attr)
  end
  -- Table-form lazy `mode = { "n", "v" }`. Accept iff at least one
  -- listed mode is compatible with the lookup mode.
  local mode_table = line:match("mode%s*=%s*({[^}]+})")
  if mode_table then
    local accept = MODE_GROUPS[mode] or { mode }
    for entry in mode_table:gmatch('"([^"]+)"') do
      if vim.tbl_contains(accept, entry) then return true end
    end
    for entry in mode_table:gmatch("'([^']+)'") do
      if vim.tbl_contains(accept, entry) then return true end
    end
    return false
  end
  return true
end

--- Reject quoted-string matches that look like keymap lhs syntactically
--- but are actually something else. Two patterns covered:
---
---   1. Lua hash-key assignment `["X"] = ...` -- common in plugin
---      config tables (`task-runner` and `snacks` use these to disable
---      defaults or define plugin-internal mappings).
---   2. The mode argument of `vim.keymap.set` -- when looking up an
---      `n`-mode `v` keymap, the line `vim.keymap.set({"n","v"}, ...)`
---      contains a quoted `"v"` that is the *mode*, not the lhs.
---
--- `match_pos` and `match_end` are 1-indexed and refer to the bounds of
--- the matched quoted string (including the quote characters).
local function should_reject_match(line, match_pos, match_end)
  -- Lua hash-key: `[<match>] = ...`
  if match_pos > 1 and line:sub(match_pos - 1, match_pos - 1) == "[" then
    local rest = line:sub(match_end + 1)
    if rest:match("^%s*%]%s*=") then return true end
  end
  -- Mode-arg of vim.keymap.set / nvim_set_keymap: walk forward from the
  -- call's opening paren and check whether `match_pos` is still inside
  -- the first argument (no top-level comma seen yet).
  local prefix = line:sub(1, match_pos - 1)
  local set_pos
  for p in prefix:gmatch("()vim%.keymap%.set%s*%(") do set_pos = p end
  if not set_pos then
    for p in prefix:gmatch("()nvim_set_keymap%s*%(") do set_pos = p end
  end
  if set_pos then
    local paren = line:find("%(", set_pos, false)
    if paren then
      local depth = 0
      for i = paren + 1, match_pos - 1 do
        local c = line:sub(i, i)
        if c == "{" then depth = depth + 1
        elseif c == "}" then depth = depth - 1
        elseif c == "," and depth == 0 then
          return false  -- past first arg, match is in lhs/rhs/opts
        end
      end
      return true  -- still inside first arg = mode argument
    end
  end
  -- Lazy keys mode-table: `{ "<lhs>", fn, mode = { "n", "v" }, ... }`.
  -- The `"n"` and `"v"` here are the mode list, not the lhs. Detect by
  -- finding `mode%s*=%s*{` before the match and checking that we are
  -- still inside that brace.
  local mode_pos
  for p in prefix:gmatch("()mode%s*=%s*{") do mode_pos = p end
  if mode_pos then
    local brace = line:find("{", mode_pos, false)
    if brace then
      local depth = 1
      for i = brace + 1, match_pos - 1 do
        local c = line:sub(i, i)
        if c == "{" then depth = depth + 1
        elseif c == "}" then depth = depth - 1 end
        if depth == 0 then return false end  -- exited the mode table
      end
      return true
    end
  end
  return false
end

--- True iff `line` looks like a keymap registration -- a strong context
--- where short single-/double-character lhs are safe to match. Short
--- lhs (e.g. `<`, `>`, `T`, `v`) match countless unrelated quoted
--- string literals and only become trustworthy in actual reg lines.
--- `in_keys_block` (optional, computed by `compute_keys_blocks`) flags
--- lines that sit inside a multi-line `keys = { ... }` lazy spec; the
--- `keys = {` opener may be several lines above the entry being tested.
local function line_is_strong_context(line, in_keys_block)
  if in_keys_block then return true end
  return line:find("vim%.keymap%.set") ~= nil
      or line:find("vim%.api%.nvim_set_keymap") ~= nil
      or line:find("vim%.api%.nvim_buf_set_keymap") ~= nil
      or line:find("keys%s*=%s*{") ~= nil
      or line:match("^%s*[vnxsoic]?n?o?r?e?map[!]?%s") ~= nil
      or line:find("[%s^]toggle%s*%(") ~= nil
      or line:find("[%s^]map%s*%(") ~= nil
end

--- Strip inline Lua comments (`-- ...`) from a line so brace-depth
--- tracking and `keys = {` detection do not trip over commented-out
--- snippets like `-- keys = { ... }` in docstrings.
local function strip_lua_comment(line)
  -- Conservative: cut from the first `--` that is not preceded by
  -- another non-space char that suggests it is inside a string.
  -- For our purposes, even the naive case-insensitive split suffices --
  -- we do not need lexer-grade accuracy, just to skip docstrings.
  local cut = line:find("%-%-")
  if cut then return line:sub(1, cut - 1) end
  return line
end

--- Pre-compute, for each line, whether it sits inside a multi-line
--- `keys = { ... }` block. Brace-depth tracking, single pass.
--- Comments are stripped before detection so `-- keys = { ... }` in a
--- docstring does not (a) start a phantom keys block or (b) contribute
--- to the brace depth. Returns an array `t` where `t[i]` is true iff
--- line `i` is inside a real keys block.
local function compute_keys_blocks(lines)
  local in_keys = {}
  local depth = 0
  local keys_depth = nil
  for i, line in ipairs(lines) do
    local code = strip_lua_comment(line)
    if code:find("keys%s*=%s*{") then
      keys_depth = keys_depth or depth
    end
    in_keys[i] = keys_depth ~= nil
    for c in code:gmatch("[{}]") do
      depth = depth + (c == "{" and 1 or -1)
    end
    if keys_depth and depth <= keys_depth then
      keys_depth = nil
    end
  end
  return in_keys
end

--- Try every quoted-form match position in a canon-text line; return
--- true on the first match that is not rejected by structural filters.
--- For short lhs (≤2 chars) the line must additionally pass the strong
--- keymap-context check, since short forms occur incidentally in many
--- unrelated string literals.
local function line_has_quoted_match(raw_line, canon_line, canon_forms, opts)
  opts = opts or {}
  local short = opts.short
  if short and not line_is_strong_context(raw_line, opts.in_keys_block) then
    return false
  end
  for _, cf in ipairs(canon_forms) do
    if cf ~= "" then
      for _, q in ipairs({ '"', "'" }) do
        local needle = q .. cf .. q
        local search = 1
        while true do
          local mstart, mend = canon_line:find(needle, search, true)
          if not mstart then break end
          if not should_reject_match(raw_line, mstart, mend) then
            return true
          end
          search = mend + 1
        end
      end
    end
  end
  return false
end

--- Locate the defining line of `lhs` within `lines` via a canon-aware
--- text scan.
---
--- `registry.source_forms_split(lhs)` produces every plausible written
--- form (literal, notation, leader-stripped, SearchLeader tail, synonym
--- expansion, etc.); `registry.canon` upper-cases the content inside
--- `<...>` groups so `<c-a>` and `<C-A>` match interchangeably. Pass 1
--- prefers quoted forms in any non-comment line (specific), pass 2
--- handles the `toggle("base", ...)` helper pattern, pass 3 accepts
--- bare multi-char matches in strong keymap-defining contexts.
---
--- `mode` is optional: when provided, lines with conflicting mode
--- evidence are skipped so an `n`-mode `<C-V>` does not land on the
--- `i`-mode `<C-v>` definition in the same file.
--- Side-effect-free. Returns the 1-based line number, or 0 on no match.
function M.find_lhs_line(lines, lhs, mode)
  local registry = require("noethervim.util.keymap_registry")
  local primary_forms, tail_forms = registry.source_forms_split(lhs)
  local primary_canon, tail_canon = {}, {}
  for _, f in ipairs(primary_forms) do primary_canon[#primary_canon + 1] = registry.canon(f) end
  for _, f in ipairs(tail_forms)    do tail_canon[#tail_canon + 1] = registry.canon(f) end
  -- Combined view used by the bare-context (pass 3) loop.
  local forms, canon_forms = {}, {}
  for _, f in ipairs(primary_forms) do forms[#forms + 1] = f; canon_forms[#canon_forms + 1] = registry.canon(f) end
  for _, f in ipairs(tail_forms)    do forms[#forms + 1] = f; canon_forms[#canon_forms + 1] = registry.canon(f) end

  -- Lua single-line comment; vimscript `"` comment is intentionally NOT
  -- treated as a comment here because Lua lines frequently start with a
  -- quoted string (lazy spec `"<lhs>", ...`) that would be misclassified.
  local function is_comment(line)
    return line:match("^%s*%-%-") ~= nil
  end

  -- Pass 1: quoted form in any non-comment, mode-compatible line.
  -- Primary forms match anywhere except in mode-arg / hash-key
  -- positions; SL-tail forms (`"/"`, `"<Space>"`) additionally require
  -- a SearchLeader concatenation context on the line. Short lhs
  -- (≤2 chars) require strong keymap-defining context everywhere
  -- (a multi-line `keys = { ... }` block counts as strong).
  local short_lhs = #lhs <= 2
  local in_keys = compute_keys_blocks(lines)
  for i, line in ipairs(lines) do
    if not is_comment(line) and line_mode_ok(line, mode, lhs) then
      local cline = registry.canon(line)
      local opts = { short = short_lhs, in_keys_block = in_keys[i] }
      if line_has_quoted_match(line, cline, primary_canon, opts) then
        return i
      end
      if #tail_canon > 0 and registry.line_has_sl_context(line)
         and line_has_quoted_match(line, cline, tail_canon, opts) then
        return i
      end
    end
  end

  -- Pass 2: toggle("base", ...) for bracket-prefixed lhs.
  local tbase = lhs:match("^[%[%]](.*)$")
  if tbase and tbase ~= "" then
    local ctbase = registry.canon(tbase)
    for i, line in ipairs(lines) do
      if not is_comment(line) and line:find("toggle%s*%(") then
        local cline = registry.canon(line)
        if cline:find('"' .. ctbase .. '"', 1, true)
           or cline:find("'" .. ctbase .. "'", 1, true) then
          return i
        end
      end
    end
  end

  -- Pass 2.5: 2-char bracket-prefixed bare match restricted to
  -- vimscript :map-family lines, e.g. toggles.lua's `nmap [e
  -- <Plug>(nv-move-up)` heredoc inside `vim.cmd[[...]]`. These lhs
  -- (`[e`, `]e`, etc.) are too short for the multi-char bare pass but
  -- the vimscript-prefix context is specific enough to be safe.
  if #lhs == 2 and (lhs:sub(1,1) == "[" or lhs:sub(1,1) == "]") then
    local cl = registry.canon(lhs)
    for i, line in ipairs(lines) do
      if not is_comment(line) and line_mode_ok(line, mode, lhs)
         and line:match("^%s*[vnxsoic]?n?o?r?e?map[!]?%s") then
        if registry.canon(line):find(cl, 1, true) then return i end
      end
    end
  end

  -- Pass 3: bare multi-char match in strong keymap-defining context.
  -- Includes vimscript `:nmap`/`:map`-style lines so we can pinpoint
  -- toggles.lua's `nmap [<Space> <Plug>(nv-blank-up)` registrations
  -- where the lhs is unquoted. Mode-checked so an `i`-only `nnoremap`
  -- block does not catch an `n`-mode lookup.
  for i, line in ipairs(lines) do
    if not is_comment(line) and line_mode_ok(line, mode, lhs) then
      local strong = line:find("vim%.keymap%.set")
                  or line:find("vim%.api%.nvim_set_keymap")
                  or line:find("keys%s*=%s*{")
                  or line:match("^%s*[vnxsoic]?n?o?r?e?map[!]?%s")
                  or line:find("[%s^]toggle%s*%(")
                  or line:find("[%s^]map%s*%(")
      if strong then
        local cline = registry.canon(line)
        for idx, cf in ipairs(canon_forms) do
          if #forms[idx] > 2 and cline:find(cf, 1, true) then
            return i
          end
        end
      end
    end
  end

  return 0
end

local function locate_in_buffer(lhs, mode)
  pcall(vim.api.nvim_win_set_cursor, 0, { 1, 0 })
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local line_no = M.find_lhs_line(lines, lhs, mode)
  if line_no > 0 then
    pcall(vim.api.nvim_win_set_cursor, 0, { line_no, 0 })
    vim.cmd("norm! zzzv")
  end
  return line_no
end

-- ── Project-wide fallback scan ───────────────────────────────────

--- Last-resort project-wide scan. Returns two ordered lists, lazily
--- populated and cached:
---
---   1. `project_files()`  -- distro + user trees only. The "owned"
---      surface; tried first so user/distro source always wins.
---   2. `plugin_files()`   -- third-party plugin sources under
---      `~/.local/share/<APPNAME>/lazy/*/lua/`. Tried last for keymaps
---      defined inside plugins themselves (e.g. `<Plug>` mappings,
---      nvim-surround's `cs`/`cr`/`ds`, vim-abolish, etc.). Ignored
---      `vim.fn.stdpath('data')` is appname-aware so dev configs
---      (`nvdn`) and the shipped config see distinct lazy roots.
---
--- Used as the final fallback in `M.jump` when registry, opts.source,
--- and callback introspection all come up empty.
local _project_files_cache, _plugin_files_cache

local function _walk(dir, files)
  if not dir then return end
  local handle = vim.uv.fs_scandir(dir)
  if not handle then return end
  while true do
    local name, ftype = vim.uv.fs_scandir_next(handle)
    if not name then break end
    local p = dir .. "/" .. name
    if ftype == "directory" then
      _walk(p, files)
    elseif (ftype == "file" or ftype == "link")
       and (name:match("%.lua$") or name:match("%.vim$")) then
      files[#files + 1] = p
    end
  end
end

local function project_files()
  if _project_files_cache then return _project_files_cache end
  local files = {}
  local root = distro_root()
  -- Walk user first so user overrides outrank distro-default matches when
  -- both define the same keymap (overrides are the more useful landing).
  _walk(vim.fn.stdpath("config") .. "/lua/user", files)
  if root then _walk(root .. "/lua/noethervim", files) end
  _project_files_cache = files
  return files
end

local function plugin_files()
  if _plugin_files_cache then return _plugin_files_cache end
  local files = {}
  local lazy_root = vim.fn.stdpath("data") .. "/lazy"
  if vim.uv.fs_stat(lazy_root) then
    local handle = vim.uv.fs_scandir(lazy_root)
    if handle then
      while true do
        local name, ftype = vim.uv.fs_scandir_next(handle)
        if not name then break end
        if ftype == "directory" then
          -- Restrict to lua/, plugin/, autoload/, ftplugin/ -- the
          -- subdirs Vim/Lua keymaps are written in. Avoids scanning
          -- vendored deps, doc/, test/, etc.
          for _, sub in ipairs({ "lua", "plugin", "autoload", "ftplugin", "after" }) do
            _walk(lazy_root .. "/" .. name .. "/" .. sub, files)
          end
        end
      end
    end
  end
  _plugin_files_cache = files
  return files
end

--- File-content cache for the project scan. Source files are read-only
--- within a session, so a single read per file pays for every jump
--- that needs to consult it.
local _file_lines_cache = {}

--- Read a file's lines, cached for the session. Returns nil when the
--- file cannot be read.
---@param path string
---@return string[]?
function M.file_lines(path)
  local c = _file_lines_cache[path]
  if c == nil then
    local ok, lines = pcall(vim.fn.readfile, path)
    c = (ok and lines) or false
    _file_lines_cache[path] = c
  end
  return c or nil
end

--- Scan the distro, user, and (last) plugin trees for a file that looks
--- like it defines `lhs`. Returns the path, or nil.
---@param lhs string
---@param mode? string
---@return string?
function M.scan_project_for(lhs, mode)
  local registry = require("noethervim.util.keymap_registry")
  local primary_forms, tail_forms = registry.source_forms_split(lhs)
  -- Bare needles for pass-2 (multi-char only, strong context).
  local forms, canon_forms = {}, {}
  for _, f in ipairs(primary_forms) do forms[#forms + 1] = f; canon_forms[#canon_forms + 1] = registry.canon(f) end
  for _, f in ipairs(tail_forms)    do forms[#forms + 1] = f; canon_forms[#canon_forms + 1] = registry.canon(f) end

  --- Strong context = a line that obviously hosts a keymap registration.
  --- Used for bare (unquoted) matches so we do not pick up the lhs as
  --- a substring of a docstring or unrelated string.
  local function is_strong(line)
    return line:find("vim%.keymap%.set")
        or line:find("vim%.api%.nvim_set_keymap")
        or line:find("keys%s*=%s*{")
        or line:match("^%s*[vnxsoic]?n?o?r?e?map[!]?%s")
        or line:find("[%s^]toggle%s*%(")
        or line:find("[%s^]map%s*%(")
  end

  --- Pre-build canon-form lists. Primary forms match anywhere except
  --- where structural filters reject (mode-arg, hash-key); SL-tail
  --- forms additionally require a SearchLeader concatenation context.
  --- Bare-multi-char fallback covers vimscript-map style lines where
  --- the lhs is unquoted. Short lhs (≤2 chars) require strong context.
  local primary_canon, tail_canon, bare_needles = {}, {}, {}
  for _, f in ipairs(primary_forms) do
    local cf = registry.canon(f)
    if cf ~= "" then
      primary_canon[#primary_canon + 1] = cf
      if #f > 2 then bare_needles[#bare_needles + 1] = cf end
    end
  end
  for _, f in ipairs(tail_forms) do
    local cf = registry.canon(f)
    if cf ~= "" then tail_canon[#tail_canon + 1] = cf end
  end
  local short_lhs = #lhs <= 2

  --- Try a single file. We walk lines so the mode filter and the
  --- per-line context check can both apply. Lines with a clearly
  --- conflicting mode (e.g. `vim.keymap.set("i", "<C-V>", ...)` when
  --- searching for an `n`-mode keymap) are skipped.
  local function try(path)
    local lines = M.file_lines(path)
    if not lines then return nil end
    local is_vim = path:match("%.vim$") ~= nil
    local function comment(line)
      return line:match("^%s*%-%-") ~= nil
          or (is_vim and line:match('^%s*"') ~= nil)
    end
    local in_keys = compute_keys_blocks(lines)
    -- Pass 1: primary quoted needle (rejection-filtered);
    -- SL-tail needle only on SearchLeader concatenation lines.
    for i, line in ipairs(lines) do
      if not comment(line) and line_mode_ok(line, mode, lhs) then
        local cline = registry.canon(line)
        local opts = { short = short_lhs, in_keys_block = in_keys[i] }
        if line_has_quoted_match(line, cline, primary_canon, opts) then
          return path
        end
        if #tail_canon > 0 and registry.line_has_sl_context(line)
           and line_has_quoted_match(line, cline, tail_canon, opts) then
          return path
        end
      end
    end
    -- Pass 2: bare multi-char needle in strong context (mode-checked).
    for _, line in ipairs(lines) do
      if not comment(line) and is_strong(line)
         and line_mode_ok(line, mode, lhs) then
        local cline = registry.canon(line)
        for _, n in ipairs(bare_needles) do
          if cline:find(n, 1, true) then return path end
        end
      end
    end
    -- Pass 3: 2-char bracket-prefixed bare match restricted to vimscript
    -- :map-family lines (e.g. `nmap [e <Plug>(nv-move-up)`).
    if #lhs == 2 and (lhs:sub(1,1) == "[" or lhs:sub(1,1) == "]") then
      local cl = registry.canon(lhs)
      for _, line in ipairs(lines) do
        if not comment(line) and line_mode_ok(line, mode, lhs)
           and line:match("^%s*[vnxsoic]?n?o?r?e?map[!]?%s") then
          if registry.canon(line):find(cl, 1, true) then return path end
        end
      end
    end
    return nil
  end

  -- Project (distro + user) first; only fall through to third-party
  -- plugin sources for keymaps we cannot find in the owned tree.
  for _, path in ipairs(project_files()) do
    local hit = try(path)
    if hit then return hit end
  end
  for _, path in ipairs(plugin_files()) do
    local hit = try(path)
    if hit then return hit end
  end
  return nil
end

-- ── Jump to source definition ────────────────────────────────────

---@class noethervim.KeymapJumpOpts
---@field source? string  Lazy handler source hint (path to the spec file
---                       that registered the keymap), used as a fallback
---                       when keymap_registry can't resolve the call site.
---@field origin? string  Ownership label from the diff picker. `"plugin"`
---                       suppresses the project-wide scan, which would
---                       otherwise land on a coincidental text match in
---                       distro source for a key the distro never defined.

--- Jump to the source definition of a keymap.
--- Opens the file containing the definition (readonly in non-dev mode)
--- and positions the cursor on the defining line.
---
---@param mode string   Keymap mode ("n", "i", "v", etc.)
---@param lhs  string   Resolved keymap lhs (from nvim_get_keymap)
---@param opts? noethervim.KeymapJumpOpts
function M.jump(mode, lhs, opts)
  opts = opts or {}
  local readonly_default = not vim.g.noethervim_dev
  local dev = vim.g.noethervim_dev
    and vim.fs.normalize(vim.fn.expand(vim.g.noethervim_dev))

  local function open_file(path, line)
    if not path or not vim.uv.fs_stat(path) then return false end
    -- In dev mode, open NoetherVim source files editable; others readonly.
    local make_readonly = readonly_default
    if dev and vim.startswith(vim.fs.normalize(path), dev) then
      make_readonly = false
    end
    vim.cmd((make_readonly and "view " or "edit ") .. vim.fn.fnameescape(path))
    if make_readonly then vim.bo.readonly = true; vim.bo.modifiable = false end
    if line and line > 0 then
      pcall(vim.api.nvim_win_set_cursor, 0, { line, 0 })
      vim.cmd("norm! zzzv")
    end
    return true
  end

  -- Assemble candidates in priority order. Registry entries carry an
  -- authoritative line and short-circuit immediately; the others are
  -- file hints that feed through `locate_in_buffer`. If a LAZY file
  -- opens but the cascade can't pinpoint the line, we fall through to
  -- the callback file before giving up -- `keymap_sources()` attribution
  -- is first-repo-wins and occasionally points at a file that mentions
  -- the plugin but does not define the specific keymap.
  local candidates = {}

  local entry = require("noethervim.util.keymap_registry").lookup(mode, lhs)
  if entry then
    candidates[#candidates + 1] = { file = entry.file, line = entry.line, hint = "registry" }
  end
  if opts.source then
    candidates[#candidates + 1] = { file = opts.source, hint = "lazy spec" }
  end
  -- The normal-mode pass is a fallback for keys registered for several
  -- modes in one `vim.keymap.set` call. It is marked `cross_mode` because
  -- it can equally pick up an unrelated key that merely shares an lhs --
  -- a `c`-mode `<Left>` from a completion plugin against an `n`-mode
  -- `<Left>` of the distro's -- and ownership must not be inferred from
  -- that. Good enough to open as a last resort, not to reason about.
  for _, m in ipairs(mode == "n" and { "n" } or { mode, "n" }) do
    for _, km in ipairs(vim.api.nvim_get_keymap(m)) do
      if km.lhs == lhs then
        -- A lazy loading stub points at lazy.nvim, not at whoever declared
        -- the key. Taking it as a candidate would attribute every
        -- not-yet-loaded plugin keymap to lazy.nvim itself.
        local f = not M.is_lazy_stub(km) and M.callback_file(km.callback) or nil
        if f then
          candidates[#candidates + 1] =
            { file = f, hint = "callback file", cross_mode = m ~= mode }
          break
        end
      end
    end
  end

  -- Third-party keymaps get redirected, not chased. The plugin's own
  -- source is not the user's to edit and is overwritten on update; the
  -- spec file that installs the plugin is where a key gets changed or
  -- disabled, so that is where we land.
  --
  -- Skipping the project scan here matters as much as the redirect. The
  -- scan walks the distro and user trees first and returns the first
  -- textual match, which for a short lhs like `<C-E>` or `<Tab>` is
  -- essentially always a coincidence in an unrelated file.
  -- Only when nothing we own claims the key: a distro or user candidate,
  -- even one that fails to pinpoint a line, outranks any plugin source.
  local plugin, owned = nil, false
  for _, c in ipairs(candidates) do
    if not c.cross_mode then
      if M.origin_of_file(c.file) then owned = true end
      plugin = plugin or M.plugin_of_file(c.file)
    end
  end
  if not plugin then
    -- rhs-only plugin keymaps reach here with no candidates at all.
    for _, m in ipairs(mode == "n" and { "n" } or { mode, "n" }) do
      for _, km in ipairs(vim.api.nvim_get_keymap(m)) do
        if km.lhs == lhs then
          plugin = plugin or M.plugin_from_rhs(km.rhs)
          break
        end
      end
    end
  end
  if not owned and (plugin or opts.origin == "plugin") then
    local spec = plugin and M.spec_file_for_plugin(plugin)
    if spec and open_file(spec) then
      -- The spec may itself declare the key (a lazy `keys = {...}` entry);
      -- prefer that line, else park on the line that names the plugin.
      -- Match the quoted repo string rather than the bare name: with
      -- 'ignorecase' the bare name also hits prose like the "Blink.cmp"
      -- in a file's header comment, which is a useless landing.
      if locate_in_buffer(lhs, mode) == 0 then
        local quoted = "[\"'][^\"']*" .. vim.fn.escape(plugin, "/\\.*$^~[]") .. "[\"']"
        if pcall(vim.fn.search, quoted, "w") then vim.cmd("norm! zzzv") end
      end
      return vim.notify(string.format(
        "NoetherVim: [%s] %s comes from %s; opened the spec that installs it.",
        mode, lhs, plugin), vim.log.levels.INFO)
    end
    return vim.notify(plugin
      and string.format("NoetherVim: [%s] %s comes from %s, which no spec file claims.",
                        mode, lhs, plugin)
      or string.format("NoetherVim: [%s] %s is defined by a plugin, not by NoetherVim or your config.",
                       mode, lhs), vim.log.levels.INFO)
  end

  -- Final fallback: project-wide text scan. Catches lazy `keys = {...}`
  -- entries in spec files whose plugin name we couldn't resolve and
  -- rhs-only keymaps with no callback to introspect. Mode-aware so an
  -- `n`-mode `<C-V>` does not land on the `i`-mode definition.
  --
  -- Suppressed for plugin-owned keys even when a distro candidate exists:
  -- the spec that lazy-declares a key can legitimately fail to pinpoint
  -- it, and the scan's consolation prize is a coincidence in an unrelated
  -- file. "Opened X, could not pinpoint" beats a confident wrong answer.
  if opts.origin ~= "plugin" then
    local scanned = M.scan_project_for(lhs, mode)
    if scanned then
      candidates[#candidates + 1] = { file = scanned, hint = "project scan" }
    end
  end

  -- Try each candidate. Registry hits win outright; for the others we
  -- open the file and run the locate cascade. First hit returns.
  -- Tracks the last candidate opened, not the first: when several open
  -- without pinpointing, the buffer left on screen is the last one, and a
  -- message naming a different file reads as a bug.
  local last_opened
  for _, c in ipairs(candidates) do
    if c.line then
      if open_file(c.file, c.line) then return end
    elseif open_file(c.file) then
      last_opened = { file = c.file, hint = c.hint }
      if locate_in_buffer(lhs, mode) > 0 then return end
    end
  end

  if last_opened then
    vim.notify(string.format(
      "NoetherVim: opened %s (%s) but could not pinpoint [%s] %s -- try /-searching.",
      vim.fn.fnamemodify(last_opened.file, ":~:."), last_opened.hint, mode, lhs),
      vim.log.levels.INFO)
  else
    vim.notify(
      ("NoetherVim: could not locate a source file for [%s] %s"):format(mode, lhs),
      vim.log.levels.INFO)
  end
end

return M
