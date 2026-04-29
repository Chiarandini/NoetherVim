-- NoetherVim inspection, comparison, and status commands.
-- Loaded at the end of noethervim.setup().
-- All commands live under the :NoetherVim namespace.
-- See :help noethervim-inspect for documentation.

-- Snacks ships its own LuaCATS classes (snacks.picker.Highlight, etc.) but
-- they aren't visible to lua-language-server in standalone --check mode
-- because the snacks plugin path is install-location-specific. IDE users
-- with lazydev.nvim see the types normally; CI uses this disable to avoid
-- the false-positive without giving up the annotation.
---@diagnostic disable: undefined-doc-name

local SearchLeader = require("noethervim.util").search_leader
local Snacks = require("snacks")

local M = {}

-- ── Helpers ──────────────────────────────────────────────────────

--- Resolve the root directory of the NoetherVim installation.
local function noethervim_root()
  local init = vim.api.nvim_get_runtime_file("lua/noethervim/init.lua", false)[1]
  if not init then return nil end
  -- init is <root>/lua/noethervim/init.lua → go up 3 levels
  return vim.fn.fnamemodify(init, ":h:h:h")
end

--- Return the effective NoetherVim root: the dev directory when
--- vim.g.noethervim_dev is set, otherwise the installed location.
local function effective_root()
  if vim.g.noethervim_dev then
    return vim.fn.expand(vim.g.noethervim_dev)
  end
  return noethervim_root()
end

--- Resolve the user config lua/user/ directory.
local function user_dir()
  return vim.fn.stdpath("config") .. "/lua/user/"
end

--- Get snapshot data from the init module.
local function snapshots()
  return require("noethervim")._snapshots
end

--- Confirm callback for pickers that should open files readonly.
--- Prevents accidental edits to distribution source or installed plugins.
--- In dev mode (vim.g.noethervim_dev), NoetherVim source files open editable.
local function confirm_readonly(picker, item)
  picker:close()
  if not item or not item.file then return end
  -- Resolve the full path (item.file may be relative to item.cwd)
  local file = Snacks.picker.util.path(item)
  if not file then return end
  -- In dev mode, open NoetherVim source files as editable
  local editable = false
  if vim.g.noethervim_dev then
    local dev = vim.fs.normalize(vim.fn.expand(vim.g.noethervim_dev))
    editable = vim.startswith(vim.fs.normalize(file), dev)
  end
  if editable then
    vim.cmd("edit " .. vim.fn.fnameescape(file))
  else
    vim.cmd("view " .. vim.fn.fnameescape(file))
    vim.bo.readonly = true
    vim.bo.modifiable = false
  end
  if item.pos and item.pos[1] and item.pos[1] > 0 then
    pcall(vim.api.nvim_win_set_cursor, 0, { item.pos[1], item.pos[2] or 0 })
    vim.cmd("norm! zzzv")
  end
end

-- ── Bundle catalog ──────────────────────────────────────────────
-- Short human-readable descriptions keyed by bundle name.  The filesystem
-- layout (bundles/<category>/<name>.lua) is the authoritative source for
-- which bundles exist and which category they belong to; this table just
-- adds the prose for the picker.  Adding a bundle without an entry here
-- falls back to "(no description)" -- see dev-docs/bundle-development.md.

local bundle_descriptions = {
  -- languages
  rust            = "rustaceanvim -- macro expansion, runnables, crate graph",
  go              = "go.nvim -- test gen, struct tags, interface impl",
  java            = "nvim-jdtls -- proper Java LSP support",
  python          = "venv-selector -- virtual environment switching",
  latex           = "VimTeX + noethervim-tex (snippets, textobjects)",
  ["latex-zotero"] = "Zotero citation picker",
  ["web-dev"]     = "template-string auto-conversion + color preview",
  -- tools
  debug           = "nvim-dap + UI (Python, Lua, JS/TS, Go)",
  test            = "neotest test runner",
  repl            = "iron.nvim interactive REPL",
  ["task-runner"] = "overseer.nvim + compiler.nvim (run file)",
  database        = "vim-dadbod + UI + SQL completion",
  http            = "kulala.nvim HTTP/REST/gRPC/GraphQL client",
  git             = "Fugit2, diffview, git-conflict",
  ai              = "CodeCompanion (Anthropic, OpenAI, Gemini, Ollama)",
  ["smart-actions"] = "AI-suggested code actions on grA (Claude Code / Anthropic)",
  refactoring     = "extract function/variable/block",
  -- navigation
  harpoon         = "fast per-project file marks",
  flash           = "enhanced f/t and / motions with labels",
  projects        = "project switcher via snacks.picker",
  ["editing-extras"] = "argmark + decorative comment boxes",
  -- writing
  markdown        = "render, preview, tables, math, image paste",
  obsidian        = "Obsidian vault integration (pair with markdown bundle)",
  neorg           = ".norg wiki / note-taking",
  -- terminal
  ["better-term"] = "named/numbered terminal windows",
  tmux            = "automatic tmux window naming",
  ["remote-dev"]  = "distant.nvim SSH editing",
  -- ui
  colorscheme     = "10 popular themes + persistence",
  ["eye-candy"]   = "animations, scrollbar, block display",
  minimap         = "sidebar minimap with git/diagnostic markers",
  helpview        = "rendered :help pages",
  tableaux        = "noethervim-tableaux -- animated mathematical dashboard scenes",
  -- practice
  training        = "vim-be-good, speedtyper, typr",
  ["dev-tools"]   = "StartupTime benchmarking, Luapad scratchpad",
  presentation    = "presenting.nvim + showkeys",
  hardtime        = "motion habit trainer",
}

-- Display order and human-readable labels for filesystem category names.
-- Any category present on disk but missing here renders as its raw name at
-- the end of the list.
local cat_order = {
  languages = 1, tools = 2, navigation = 3, writing = 4,
  terminal = 5, ui = 6, practice = 7,
}
local cat_label = {
  languages = "Languages", tools = "Tools", navigation = "Navigation",
  writing = "Writing", terminal = "Terminal", ui = "UI", practice = "Practice",
}

-- ── File & Grep Pickers (Phase 5) ───────────────────────────────

function M.files()
  local root = effective_root()
  if not root then return vim.notify("NoetherVim: cannot locate source directory", vim.log.levels.ERROR) end
  Snacks.picker.files({ cwd = root, title = "NoetherVim Source", confirm = confirm_readonly })
end

function M.grep()
  local root = effective_root()
  if not root then return vim.notify("NoetherVim: cannot locate source directory", vim.log.levels.ERROR) end
  Snacks.picker.grep({ cwd = root, title = "NoetherVim Grep", confirm = confirm_readonly })
end

function M.user()
  local dir = user_dir()
  if vim.fn.isdirectory(dir) == 0 then
    return vim.notify("NoetherVim: no user config directory at " .. dir, vim.log.levels.INFO)
  end
  Snacks.picker.files({ cwd = dir, title = "User Config" })
end

function M.bundles()
  local root = effective_root()
  if not root then return vim.notify("NoetherVim: cannot locate source directory", vim.log.levels.ERROR) end

  -- Detect which bundles are enabled via lazy.nvim's imported modules.
  -- Import keys look like "noethervim.bundles.<category>.<name>"; keep
  -- only the trailing <name> so the lookup matches filesystem basenames.
  local enabled = {}
  local ok, lazy_cfg = pcall(require, "lazy.core.config")
  if ok and lazy_cfg.spec then
    for _, mod in ipairs(lazy_cfg.spec.modules) do
      local tail = mod:match("^noethervim%.bundles%.(.+)$")
      if tail then
        local name = tail:match("([^.]+)$")
        enabled[name] = true
      end
    end
  end

  local util = require("noethervim.util")
  local icons = require("noethervim.util.icons")
  local items = {}
  for _, entry in ipairs(util.scan_bundles(root .. "/lua/noethervim/bundles")) do
    local is_enabled = enabled[entry.name] or false
    local desc = bundle_descriptions[entry.name] or "(no description)"
    local label = cat_label[entry.category] or entry.category
    table.insert(items, {
      text = label .. " " .. entry.name .. " " .. desc .. (is_enabled and " enabled" or ""),
      file = entry.path,
      cat_order = cat_order[entry.category] or 99,
      cat_text = "[" .. label .. "]",
      bundle_name = entry.name,
      category = entry.category,
      desc = desc,
      enabled = is_enabled,
    })
  end

  table.sort(items, function(a, b)
    if a.cat_order ~= b.cat_order then return a.cat_order < b.cat_order end
    return a.bundle_name < b.bundle_name
  end)

  Snacks.picker({
    title   = "NoetherVim Bundles  [<C-y>] enable  [<C-x>] disable",
    items   = items,
    preview = "file",
    confirm = confirm_readonly,
    format  = function(item)
      local ret = {} ---@type snacks.picker.Highlight[]
      ret[#ret + 1] = { string.format("%-14s", item.cat_text), "SnacksPickerLabel" }
      ret[#ret + 1] = { string.format("%-18s", item.bundle_name) }
      if item.enabled then
        ret[#ret + 1] = { icons.checkmark .. " ", "DiagnosticOk" }
      else
        ret[#ret + 1] = { "  " }
      end
      ret[#ret + 1] = { item.desc, "Comment" }
      return ret
    end,
    actions = {
      enable_bundle = function(picker)
        local item = picker:current()
        if not item or not item.bundle_name or not item.category then return end
        picker:close()
        require("noethervim.util.bundle_toggle").enable(item.category, item.bundle_name)
      end,
      disable_bundle = function(picker)
        local item = picker:current()
        if not item or not item.bundle_name or not item.category then return end
        picker:close()
        require("noethervim.util.bundle_toggle").disable(item.category, item.bundle_name)
      end,
    },
    win = {
      input = {
        keys = {
          ["<C-y>"] = { "enable_bundle",  mode = { "i", "n" }, desc = "enable bundle"  },
          ["<C-x>"] = { "disable_bundle", mode = { "i", "n" }, desc = "disable bundle" },
        },
      },
      list = {
        keys = {
          ["<C-y>"] = { "enable_bundle",  desc = "enable bundle"  },
          ["<C-x>"] = { "disable_bundle", desc = "disable bundle" },
        },
      },
    },
  })
end

function M.templates()
  local root = effective_root()
  if not root then return vim.notify("NoetherVim: cannot locate source directory", vim.log.levels.ERROR) end

  local templates = require("noethervim.util.templates")
  local items = templates.list(root)
  if #items == 0 then
    return vim.notify("NoetherVim: no templates found under templates/", vim.log.levels.WARN)
  end

  local picker_items = {}
  for _, t in ipairs(items) do
    picker_items[#picker_items + 1] = {
      text     = t.rel .. " " .. t.desc .. (t.exists and " exists" or ""),
      file     = t.src,
      rel      = t.rel,
      src      = t.src,
      dest     = t.dest,
      exists   = t.exists,
      desc     = t.desc,
    }
  end

  Snacks.picker({
    title   = "NoetherVim Templates  [<C-y>] stamp into lua/user/",
    items   = picker_items,
    preview = "file",
    confirm = confirm_readonly,
    format  = function(item)
      local ret = {} ---@type snacks.picker.Highlight[]
      if item.exists then
        ret[#ret + 1] = { "[exists] ", "DiagnosticHint" }
      else
        ret[#ret + 1] = { "[new]    ", "DiagnosticOk" }
      end
      ret[#ret + 1] = { string.format("%-32s", item.rel) }
      ret[#ret + 1] = { item.desc, "Comment" }
      return ret
    end,
    actions = {
      stamp_template = function(picker)
        local item = picker:current()
        if not item or not item.src or not item.dest then return end
        picker:close()
        require("noethervim.util.templates").stamp(item.src, item.dest)
      end,
    },
    win = {
      input = {
        keys = {
          ["<C-y>"] = { "stamp_template", mode = { "i", "n" }, desc = "stamp template into lua/user/" },
        },
      },
      list = {
        keys = {
          ["<C-y>"] = { "stamp_template", desc = "stamp template into lua/user/" },
        },
      },
    },
  })
end

function M.plugins()
  local plugin_dir = vim.fn.stdpath("data") .. "/lazy"
  if vim.fn.isdirectory(plugin_dir) == 0 then
    return vim.notify("NoetherVim: no lazy plugin directory found", vim.log.levels.ERROR)
  end
  Snacks.picker.files({ cwd = plugin_dir, title = "Installed Plugins", confirm = confirm_readonly })
end

-- ── Status (Phase 4.3) ──────────────────────────────────────────

function M.status()
  local nv = require("noethervim")
  local lines = {}

  if nv._user_loaded then
    table.insert(lines, "User overrides: ACTIVE")
  else
    table.insert(lines, "User overrides: DISABLED")
    if vim.env.NOETHERVIM_NO_USER then
      table.insert(lines, "  (NOETHERVIM_NO_USER is set)")
    end
    if vim.g.noethervim_no_user then
      table.insert(lines, "  (vim.g.noethervim_no_user is set)")
    end
  end

  if #nv._user_modules > 0 then
    table.insert(lines, "Loaded modules: " .. table.concat(nv._user_modules, ", "))
  end
  if #nv._user_lsp > 0 then
    table.insert(lines, "Loaded user LSP files: " .. table.concat(nv._user_lsp, ", "))
  end
  if #nv._user_overrides > 0 then
    table.insert(lines, "Loaded overrides: " .. table.concat(nv._user_overrides, ", "))
  end
  if #nv._user_modules == 0 and #nv._user_lsp == 0 and #nv._user_overrides == 0 and nv._user_loaded then
    table.insert(lines, "No user override files found.")
  end

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "NoetherVim" })
end

-- ── Keymap source helpers ────────────────────────────────────────
--
-- Source attribution for a (mode, resolved_lhs) pair is driven by three
-- data sources, in priority order:
--
--   1. `keymap_registry`: a setup-time wrapper around `vim.keymap.set`
--      records the file+line of every imperative registration. This is
--      authoritative -- the file is exactly the callsite.
--   2. `util.keymap_sources()`: maps lazy.nvim handler keys to the plugin
--      spec file that owns them. Used for `keys = { ... }` entries that
--      bypass the wrapper.
--   3. Callback introspection via `debug.getinfo(callback, "S")`: for
--      any keymap whose callback is a Lua function, its defining file
--      is usually a good hint.
--
-- Once the file is known, `locate_in_buffer` does a small plain-text
-- search for the lhs to position the cursor. The search tries a couple
-- of forms (quoted, notation, bare) and stops at the first match.

--- Compare two keymap snapshots for equality.
--- Callback functions from nvim_get_keymap get new references on each
--- call, so identity comparison fails for Neovim defaults.  When both
--- have callbacks and the same rhs, treat them as equal.
local function same_mapping(a, b)
  if a.rhs ~= b.rhs then return false end
  if a.callback == b.callback then return true end
  if a.callback and b.callback then return true end
  return false
end

--- Return the Lua source file that defines `callback`, or nil.
local function callback_file(callback)
  if type(callback) ~= "function" then return nil end
  local info = debug.getinfo(callback, "S")
  if not info or not info.source then return nil end
  local src = info.source
  if src:sub(1, 1) == "@" then src = src:sub(2) end
  if src == "" or src:match("^%[") then return nil end
  return src
end

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

--- Locate the defining line of `lhs` in the current buffer via a
--- canon-aware text scan.
---
--- `registry.source_forms(lhs)` produces every plausible written form
--- (literal, notation, leader-stripped, SearchLeader tail, synonym
--- expansion, etc.); `registry.canon` upper-cases the content inside
--- `<...>` groups so `<c-a>` and `<C-A>` match interchangeably. Pass 1
--- prefers quoted forms in any non-comment line (specific), pass 2
--- handles the `toggle("base", ...)` helper pattern, pass 3 accepts
--- bare multi-char matches in strong keymap-defining contexts. The
--- cursor is parked on line 1 first for determinism.
--- Returns the matched line number, or 0 on no match.
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

--- `mode` is optional: when provided, lines with conflicting mode
--- evidence are skipped so an `n`-mode `<C-V>` does not land on the
--- `i`-mode `<C-v>` definition in the same file.
--- Side-effect-free line search. Returns the 1-based line number where
--- `lhs` appears to be defined in `lines`, or 0. Used both by the
--- buffer-cursor `locate_in_buffer` and by the qf builder which needs
--- a line for a file it doesn't open.
local function find_lhs_line(lines, lhs, mode)
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
  local line_no = find_lhs_line(lines, lhs, mode)
  if line_no > 0 then
    pcall(vim.api.nvim_win_set_cursor, 0, { line_no, 0 })
    vim.cmd("norm! zzzv")
  end
  return line_no
end

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
--- Used as the final fallback in `jump_to_keymap` when registry,
--- opts.source, and callback introspection all come up empty.
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
  local init = vim.api.nvim_get_runtime_file("lua/noethervim/init.lua", false)[1]
  local distro_root = vim.g.noethervim_dev and vim.fn.expand(vim.g.noethervim_dev)
    or (init and vim.fn.fnamemodify(init, ":h:h:h"))
  -- Walk user first so user overrides outrank distro-default matches when
  -- both define the same keymap (overrides are the more useful landing).
  _walk(vim.fn.stdpath("config") .. "/lua/user", files)
  if distro_root then _walk(distro_root .. "/lua/noethervim", files) end
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
local function _file_lines(path)
  local c = _file_lines_cache[path]
  if c == nil then
    local ok, lines = pcall(vim.fn.readfile, path)
    c = (ok and lines) or false
    _file_lines_cache[path] = c
  end
  return c or nil
end

local function scan_project_for(lhs, mode)
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
    local lines = _file_lines(path)
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
    -- Bracket-prefixed 2-char forms (`[e`, `]e`, `[t`, ...) also accepted
    -- when the line is a vimscript :nmap-style declaration -- catches
    -- the toggles.lua `vim.cmd[[ nmap [e <Plug>(nv-move-up) ]]` heredoc.
    if #bare_needles > 0 or true then
      for _, line in ipairs(lines) do
        if not comment(line) and is_strong(line)
           and line_mode_ok(line, mode, lhs) then
          local cline = registry.canon(line)
          for _, n in ipairs(bare_needles) do
            if cline:find(n, 1, true) then return path end
          end
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

-- ── Shared: jump to keymap source definition ────────────────────
-- Used by diff_keymaps (confirm handler) and the guide (<CR>).

---@class noethervim.inspect.JumpOpts
---@field source? string  Lazy handler source hint (path to the spec file
---                       that registered the keymap), used as a fallback
---                       when keymap_registry can't resolve the call site.

--- Jump to the source definition of a keymap.
--- Opens the file containing the definition (readonly in non-dev mode)
--- and positions the cursor on the defining line.
---
---@param mode string   Keymap mode ("n", "i", "v", etc.)
---@param lhs  string   Resolved keymap lhs (from nvim_get_keymap)
---@param opts? noethervim.inspect.JumpOpts
function M.jump_to_keymap(mode, lhs, opts)
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
  for _, m in ipairs(mode == "n" and { "n" } or { mode, "n" }) do
    for _, km in ipairs(vim.api.nvim_get_keymap(m)) do
      if km.lhs == lhs then
        local f = callback_file(km.callback)
        if f then
          candidates[#candidates + 1] = { file = f, hint = "callback file" }
          break
        end
      end
    end
  end

  -- Final fallback: project-wide text scan. Catches lazy `keys = {...}`
  -- entries in spec files whose plugin name we couldn't resolve and
  -- rhs-only keymaps with no callback to introspect. Mode-aware so an
  -- `n`-mode `<C-V>` does not land on the `i`-mode definition.
  local scanned = scan_project_for(lhs, mode)
  if scanned then
    candidates[#candidates + 1] = { file = scanned, hint = "project scan" }
  end

  -- Try each candidate. Registry hits win outright; for the others we
  -- open the file and run the locate cascade. First hit returns.
  local first_opened
  for _, c in ipairs(candidates) do
    if c.line then
      if open_file(c.file, c.line) then return end
    elseif open_file(c.file) then
      first_opened = first_opened or { file = c.file, hint = c.hint }
      if locate_in_buffer(lhs, mode) > 0 then return end
    end
  end

  if first_opened then
    vim.notify(string.format(
      "NoetherVim: opened %s (%s) but could not pinpoint [%s] %s -- try /-searching.",
      vim.fn.fnamemodify(first_opened.file, ":~:."), first_opened.hint, mode, lhs),
      vim.log.levels.INFO)
  else
    vim.notify(
      ("NoetherVim: could not locate a source file for [%s] %s"):format(mode, lhs),
      vim.log.levels.INFO)
  end
end

-- ── Comparison: Keymaps (Phase 6.1) ─────────────────────────────

function M.diff_keymaps()
  local snap = snapshots()
  if not snap.keymaps_before or not snap.keymaps_after then
    return vim.notify("NoetherVim: no keymap snapshots (user overrides may be disabled)", vim.log.levels.WARN)
  end

  local before = snap.keymaps_before
  local after  = snap.keymaps_after
  local items  = {}

  -- Map resolved keymaps to lazy plugin modules for source navigation.
  -- `managed` includes ALL lazy handler keys (even user-only dev plugins
  -- that keymap_sources can't map to a spec file).
  local key_sources, lazy_managed = require("noethervim.util").keymap_sources()

  -- Baseline: keymaps that existed before NoetherVim core loaded.
  -- Keymaps present in baseline, unchanged by core AND user, and not
  -- from any lazy spec are Neovim defaults -- skip them.
  local baseline = snap.keymaps_baseline or {}

  -- Collect all keys from both snapshots
  local all_keys = {}
  for k in pairs(before) do all_keys[k] = true end
  for k in pairs(after)  do all_keys[k] = true end

  for key in pairs(all_keys) do
    local bl = baseline[key]
    local b  = before[key]
    local a  = after[key]
    local tag, mode, lhs, desc

    if a and not b then
      -- New keymap added by user
      tag  = "[USER]"
      mode = a.mode
      lhs  = a.lhs
      desc = a.desc
    elseif b and not a then
      -- Keymap deleted by user
      tag  = "[DELETED]"
      mode = b.mode
      lhs  = b.lhs
      desc = b.desc
    elseif a and b then
      -- Check if changed
      local changed = (a.rhs ~= b.rhs) or (a.callback ~= b.callback)
      if changed then
        tag  = "[OVERRIDE]"
        mode = a.mode
        lhs  = a.lhs
        desc = a.desc ~= "" and a.desc or b.desc
      else
        -- Skip Neovim defaults: present in baseline, unchanged by
        -- core and user, and not managed by any lazy spec.
        if bl and not key_sources[key] and not lazy_managed[key]
           and same_mapping(bl, b) then
          goto continue
        end
        tag  = "[CORE]"
        mode = a.mode
        lhs  = a.lhs
        desc = a.desc
      end
    end

    if tag then
      local display_lhs = lhs:gsub(" ", "␣"):gsub("<lt>", "<")
      table.insert(items, {
        text   = tag .. " " .. mode .. " " .. display_lhs .. " " .. desc,
        tag    = tag,
        mode   = mode,
        lhs    = lhs,
        desc   = desc,
        source = key_sources[key],
      })
    end
    ::continue::
  end

  -- Refine [CORE] → [USER]: a key is user-owned if either the registry
  -- (imperative `vim.keymap.set` callsite) or the lazy-handler
  -- attribution (lazy `keys = {...}` spec file) places its definition
  -- under `lua/user/`. The lazy path matters because user plugin specs
  -- bypass the setup-time wrapper, so the registry alone misses them.
  local udir_norm = vim.fs.normalize(user_dir())
  local registry = require("noethervim.util.keymap_registry")
  for _, item in ipairs(items) do
    if item.tag == "[CORE]" then
      local owner_file
      local entry = registry.lookup(item.mode, item.lhs)
      if entry and entry.file
         and vim.startswith(vim.fs.normalize(entry.file), udir_norm) then
        owner_file = entry.file
      elseif item.source
         and vim.startswith(vim.fs.normalize(item.source), udir_norm) then
        owner_file = item.source
      end
      if owner_file then
        item.tag  = "[USER]"
        item.text = "[USER]" .. item.text:sub(7)
        item.source = owner_file
      end
    end
  end

  -- Sort: USER/OVERRIDE/DELETED first, then by mode+lhs
  local tag_order = { ["[USER]"] = 1, ["[OVERRIDE]"] = 2, ["[DELETED]"] = 3, ["[CORE]"] = 4 }
  local tag_hl = {
    ["[USER]"]     = "DiagnosticOk",
    ["[OVERRIDE]"] = "DiagnosticWarn",
    ["[DELETED]"]  = "DiagnosticError",
    ["[CORE]"]     = "Comment",
  }
  table.sort(items, function(a, b)
    local oa = tag_order[a.tag] or 5
    local ob = tag_order[b.tag] or 5
    if oa ~= ob then return oa < ob end
    if a.mode ~= b.mode then return a.mode < b.mode end
    return a.lhs < b.lhs
  end)

  -- Build a quickfix entry for one item using the same candidate
  -- cascade as `M.jump_to_keymap`, but resolving file+line from cached
  -- file content instead of opening the buffer. Returns nil if no
  -- candidate file can be found. Closes over the outer-scope `registry`.
  local function resolve_qf_entry(item)
    local display_lhs = item.lhs:gsub(" ", "␣"):gsub("<lt>", "<")
    local text = string.format("%-11s [%s] %-16s %s",
                               item.tag, item.mode, display_lhs, item.desc or "")

    local entry = registry.lookup(item.mode, item.lhs)
    if entry and entry.file and entry.line then
      return { filename = entry.file, lnum = entry.line, col = 1, text = text }
    end

    local candidates = {}
    if entry and entry.file then candidates[#candidates + 1] = entry.file end
    if item.source then candidates[#candidates + 1] = item.source end
    for _, m in ipairs(item.mode == "n" and { "n" } or { item.mode, "n" }) do
      for _, km in ipairs(vim.api.nvim_get_keymap(m)) do
        if km.lhs == item.lhs then
          local f = callback_file(km.callback)
          if f then candidates[#candidates + 1] = f; break end
        end
      end
    end
    local scanned = scan_project_for(item.lhs, item.mode)
    if scanned then candidates[#candidates + 1] = scanned end

    for _, file in ipairs(candidates) do
      local lines = _file_lines(file)
      if lines then
        local line_no = find_lhs_line(lines, item.lhs, item.mode)
        if line_no > 0 then
          return { filename = file, lnum = line_no, col = 1, text = text }
        end
      end
    end

    -- File found but line not pinpointed; still emit so user lands in
    -- the right file. `]q` will at least take them somewhere meaningful.
    if candidates[1] then
      return { filename = candidates[1], lnum = 1, col = 1, text = text .. "  (line not pinpointed)" }
    end
    return nil
  end

  local function send_to_qf(picker)
    local sel = picker:selected()
    local picked = #sel > 0 and sel or picker:items()
    picker:close()
    local qf = {}
    for _, item in ipairs(picked) do
      local e = resolve_qf_entry(item)
      if e then qf[#qf + 1] = e end
    end
    if #qf == 0 then
      return vim.notify("NoetherVim: no keymap sources could be located", vim.log.levels.WARN)
    end
    vim.fn.setqflist({}, " ", { title = "NoetherVim Keymaps", items = qf })
    vim.cmd("botright copen")
  end

  Snacks.picker({
    title  = "NoetherVim Keymap Comparison",
    items  = items,
    layout = { preset = "select", preview = "main" },
    win = { input = { keys = {
      -- Space inserts ␣ so the search matches the visible display
      ["<Space>"] = {
        function() vim.api.nvim_feedkeys("␣", "n", true) end,
        mode = { "i" }, nowait = true, desc = "insert ␣",
      },
    } } },
    format = function(item)
      local ret = {} ---@type snacks.picker.Highlight[]
      ret[#ret + 1] = { string.format("%-11s", item.tag), tag_hl[item.tag] or "Comment" }
      ret[#ret + 1] = { string.format(" [%s] ", item.mode), "Special" }
      -- Replace literal spaces with ␣ so SearchLeader prefixes are visible
      ret[#ret + 1] = { string.format("%-16s ", item.lhs:gsub(" ", "␣"):gsub("<lt>", "<")), "SnacksPickerFile" }
      ret[#ret + 1] = { item.desc, "Comment" }
      return ret
    end,
    actions = {
      -- Override snacks' default qflist action (bound to <C-q>) to
      -- resolve each keymap's file+line via the same candidate cascade
      -- the picker's confirm uses, rather than the default which only
      -- reads `item.file`/`item.pos` (these items have neither).
      qflist = send_to_qf,
    },
    confirm = function(picker, item)
      picker:close()
      -- jump_to_keymap consults the registry first, so USER/OVERRIDE
      -- items land in the exact user file+line that registered them --
      -- not just user/keymaps.lua.
      M.jump_to_keymap(item.mode, item.lhs, { source = item.source })
    end,
  })
end

-- ── Comparison: Options (Phase 6.2) ─────────────────────────────

function M.diff_options()
  local snap = snapshots()
  if not snap.options_before or not snap.options_after then
    return vim.notify("NoetherVim: no option snapshots (user overrides may be disabled)", vim.log.levels.WARN)
  end

  local before = snap.options_before
  local after  = snap.options_after
  local items  = {}

  for name, default_val in pairs(before) do
    local current_val = after[name]
    local tag = (current_val ~= default_val) and "[OVERRIDE]" or "[CORE]"
    table.insert(items, {
      text        = tag .. " " .. name .. " " .. tostring(current_val) .. " " .. tostring(default_val),
      tag         = tag,
      name        = name,
      current     = tostring(current_val),
      default_val = tostring(default_val),
    })
  end

  local tag_order = { ["[OVERRIDE]"] = 1, ["[CORE]"] = 2 }
  local tag_hl = {
    ["[OVERRIDE]"] = "DiagnosticWarn",
    ["[CORE]"]     = "Comment",
  }
  table.sort(items, function(a, b)
    local oa = tag_order[a.tag] or 3
    local ob = tag_order[b.tag] or 3
    if oa ~= ob then return oa < ob end
    return a.name < b.name
  end)

  Snacks.picker({
    title  = "NoetherVim Option Comparison",
    items  = items,
    layout = { preset = "select", preview = "main" },
    format = function(item)
      local ret = {} ---@type snacks.picker.Highlight[]
      ret[#ret + 1] = { string.format("%-11s", item.tag), tag_hl[item.tag] or "Comment" }
      ret[#ret + 1] = { string.format(" %-20s", item.name), "SnacksPickerFile" }
      ret[#ret + 1] = { " = " }
      ret[#ret + 1] = { string.format("%-12s", item.current), item.tag == "[OVERRIDE]" and "DiagnosticWarn" or "SnacksPickerFile" }
      ret[#ret + 1] = { " (default: ", "Comment" }
      ret[#ret + 1] = { item.default_val, "Comment" }
      ret[#ret + 1] = { ")", "Comment" }
      return ret
    end,
    confirm = function(picker, item)
      picker:close()
      local file, readonly
      if item.tag == "[OVERRIDE]" then
        file = user_dir() .. "options.lua"
        readonly = false
      else
        local root = effective_root()
        if root then file = root .. "/lua/noethervim/options.lua" end
        readonly = not vim.g.noethervim_dev
      end
      if file and vim.uv.fs_stat(file) then
        vim.cmd((readonly and "view " or "edit ") .. vim.fn.fnameescape(file))
        if readonly then vim.bo.readonly = true; vim.bo.modifiable = false end
        vim.fn.search(vim.fn.escape(item.name, "/\\[]{}().*+^$~"), "w")
      end
    end,
  })
end

-- ── Debug: keymap source diagnostic ─────────────────────────────

--- Show the source attribution for every tracked keymap. For each key
--- in the diff set, report the data source that would drive a jump:
---   REG   — captured by the setup-time registry (exact file + line)
---   LAZY  — attributed via lazy.nvim handler metadata (spec file)
---   CB    — inferred from the callback function's defining file
---   ----  — no source available; jump would notify and do nothing
--- Run with :NoetherVim debug-keymaps
function M.debug_keymaps()
  local snap = snapshots()
  if not snap.keymaps_before or not snap.keymaps_after then
    return vim.notify("NoetherVim: no keymap snapshots", vim.log.levels.WARN)
  end

  local key_sources, lazy_managed = require("noethervim.util").keymap_sources()
  local registry = require("noethervim.util.keymap_registry")

  local baseline = snap.keymaps_baseline or {}
  local before   = snap.keymaps_before
  local after    = snap.keymaps_after

  local all_keys = {}
  for k in pairs(before) do all_keys[k] = true end
  for k in pairs(after)  do all_keys[k] = true end

  local results = {}
  local skipped = 0
  for key in pairs(all_keys) do
    local a, b, bl = after[key], before[key], baseline[key]
    -- Same Neovim-default filter as diff_keymaps.
    if a and b and bl and not key_sources[key] and not lazy_managed[key]
       and same_mapping(bl, b) and same_mapping(b, a) then
      skipped = skipped + 1
    else
      local km = a or b
      local entry = registry.lookup(km.mode, km.lhs)
      local kind, file, line
      if entry then
        kind, file, line = "REG ", entry.file, entry.line
      elseif key_sources[key] then
        kind, file = "LAZY", key_sources[key]
      else
        local cb_file = callback_file(km.callback)
        if cb_file then kind, file = "CB  ", cb_file
        else kind = "----" end
      end
      results[#results + 1] = {
        kind = kind, mode = km.mode, lhs = km.lhs, desc = km.desc,
        file = file and vim.fn.fnamemodify(file, ":t") or "???",
        line = line,
      }
    end
  end

  table.sort(results, function(a, b)
    if a.kind ~= b.kind then return a.kind > b.kind end  -- ---- first, then CB, LAZY, REG
    if a.mode ~= b.mode then return a.mode < b.mode end
    return a.lhs < b.lhs
  end)

  local counts = { REG = 0, LAZY = 0, CB = 0, MISS = 0 }
  for _, r in ipairs(results) do
    local k = r.kind:gsub("%s", "")
    if k == "" then counts.MISS = counts.MISS + 1
    else counts[k] = (counts[k] or 0) + 1 end
  end

  local out = {
    "NoetherVim Keymap Source Diagnostic",
    string.format("Total: %d keymaps  (REG:%d  LAZY:%d  CB:%d  none:%d  Neovim defaults filtered: %d)",
      #results, counts.REG, counts.LAZY, counts.CB, counts.MISS, skipped),
    string.rep("─", 80),
  }
  for _, r in ipairs(results) do
    out[#out + 1] = string.format("[%s] [%s] %-20s  %-24s %-6s %s",
      r.kind, r.mode, r.lhs, r.file,
      r.line and ("L" .. r.line) or "",
      r.desc)
  end

  vim.cmd("tabnew")
  vim.bo.buftype = "nofile"
  vim.bo.bufhidden = "wipe"
  vim.bo.swapfile = false
  vim.api.nvim_buf_set_name(0, "noethervim://keymap-diagnostic")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, out)
end

-- ── Comparison: File side-by-side (Phase 6.3) ───────────────────

--- Scan a directory for .lua module names (without extension).
local function scan_lua_modules(dir)
  local modules = {}
  local handle = vim.uv.fs_scandir(dir)
  if not handle then return modules end
  while true do
    local name, ftype = vim.uv.fs_scandir_next(handle)
    if not name then break end
    if (ftype == "file" or ftype == "link") and name:match("%.lua$") then
      modules[#modules + 1] = name:gsub("%.lua$", "")
    end
  end
  table.sort(modules)
  return modules
end

--- Open a side-by-side split for a specific module (direct call path).
--- Used by :NoetherVim diff <name> when a name is provided.
local function open_diff_split(module_name)
  local root = effective_root()
  if not root then return vim.notify("NoetherVim: cannot locate source directory", vim.log.levels.ERROR) end

  local upstream = nil
  local candidates = {
    root .. "/lua/noethervim/" .. module_name .. ".lua",
    root .. "/lua/noethervim/plugins/" .. module_name .. ".lua",
    root .. "/lua/noethervim/lsp/" .. module_name .. ".lua",
  }
  for _, path in ipairs(candidates) do
    if vim.uv.fs_stat(path) then
      upstream = path
      break
    end
  end
  if not upstream then
    -- Bundles live under category subdirectories; search by basename.
    for _, entry in ipairs(require("noethervim.util").scan_bundles(root .. "/lua/noethervim/bundles")) do
      if entry.name == module_name then
        upstream = entry.path
        break
      end
    end
  end

  if not upstream then
    return vim.notify("NoetherVim: no upstream file found for '" .. module_name .. "'", vim.log.levels.WARN)
  end

  local udir = user_dir()
  local user_file = nil
  local user_candidates = {
    udir .. module_name .. ".lua",
    udir .. "plugins/" .. module_name .. ".lua",
    udir .. "overrides/" .. module_name .. ".lua",
    udir .. "lsp/" .. module_name .. ".lua",
  }
  for _, path in ipairs(user_candidates) do
    if vim.uv.fs_stat(path) then
      user_file = path
      break
    end
  end

  local readonly = not vim.g.noethervim_dev
  if readonly then
    vim.cmd("view " .. vim.fn.fnameescape(upstream))
    vim.bo.readonly = true
    vim.bo.modifiable = false
  else
    vim.cmd("edit " .. vim.fn.fnameescape(upstream))
  end
  if user_file then
    vim.cmd("vsplit " .. vim.fn.fnameescape(user_file))
  else
    vim.notify("NoetherVim: no user override for '" .. module_name .. "' (showing upstream only)", vim.log.levels.INFO)
  end
end

--- Open a side-by-side diff of a NoetherVim core module against the user's
--- override for the same module. With no argument, presents a Snacks picker
--- of every module that has (or could have) an override.
---
---@param module_name? string  Bare module name (e.g. "telescope", "snacks").
function M.diff_file(module_name)
  -- Direct open when called with a specific module name
  if module_name and module_name ~= "" then
    open_diff_split(module_name)
    return
  end

  -- Picker mode -- browse all diffable modules
  local root = effective_root()
  if not root then return vim.notify("NoetherVim: cannot locate source directory", vim.log.levels.ERROR) end
  local udir = user_dir()
  local icons = require("noethervim.util.icons")

  local diff_cat_order = { Core = 1, Plugin = 2, Bundle = 3, LSP = 4 }
  -- Flat-scan groups (bundles are handled separately -- they live under
  -- category subdirectories, not directly in bundles/).
  local groups = {
    { cat = "Core",   dir = root .. "/lua/noethervim",         user_dirs = { udir } },
    { cat = "Plugin", dir = root .. "/lua/noethervim/plugins", user_dirs = { udir .. "plugins/" } },
    { cat = "LSP",    dir = root .. "/lua/noethervim/lsp",     user_dirs = { udir .. "lsp/" } },
  }

  -- Detect which bundles are enabled (same logic as M.bundles()).
  local enabled_bundles = {}
  local ok, lazy_cfg = pcall(require, "lazy.core.config")
  if ok and lazy_cfg.spec then
    for _, mod in ipairs(lazy_cfg.spec.modules) do
      local tail = mod:match("^noethervim%.bundles%.(.+)$")
      if tail then
        local name = tail:match("([^.]+)$")
        enabled_bundles[name] = true
      end
    end
  end

  local items = {}

  local function add_item(cat, name, upstream_path, user_candidates, is_enabled)
    local user_path = nil
    for _, candidate in ipairs(user_candidates) do
      if vim.uv.fs_stat(candidate) then
        user_path = candidate
        break
      end
    end
    if not user_path then
      local override = udir .. "overrides/" .. name .. ".lua"
      if vim.uv.fs_stat(override) then user_path = override end
    end
    table.insert(items, {
      text      = cat .. " " .. name
                  .. (is_enabled and " enabled" or "")
                  .. (user_path and " override" or ""),
      file      = upstream_path,
      cat       = cat,
      cat_order = diff_cat_order[cat] or 99,
      name      = name,
      upstream  = upstream_path,
      user_file = user_path,
      has_override = user_path ~= nil,
      enabled   = is_enabled,
    })
  end

  for _, group in ipairs(groups) do
    for _, mod in ipairs(scan_lua_modules(group.dir)) do
      if not (group.cat == "Core" and mod == "init") then
        local upstream_path = vim.fs.joinpath(group.dir, mod .. ".lua")
        local user_candidates = {}
        for _, ud in ipairs(group.user_dirs) do
          user_candidates[#user_candidates + 1] = ud .. mod .. ".lua"
        end
        add_item(group.cat, mod, upstream_path, user_candidates, true)
      end
    end
  end

  -- Bundles (category subdirectories)
  for _, entry in ipairs(require("noethervim.util").scan_bundles(root .. "/lua/noethervim/bundles")) do
    add_item("Bundle", entry.name, entry.path, { udir .. "plugins/" .. entry.name .. ".lua" },
      enabled_bundles[entry.name] or false)
  end

  table.sort(items, function(a, b)
    if a.cat_order ~= b.cat_order then return a.cat_order < b.cat_order end
    return a.name < b.name
  end)

  Snacks.picker({
    title   = "NoetherVim Module Comparison",
    items   = items,
    preview = "file",
    format  = function(item)
      local ret = {} ---@type snacks.picker.Highlight[]
      ret[#ret + 1] = { string.format("%-10s", "[" .. item.cat .. "]"), "SnacksPickerLabel" }
      ret[#ret + 1] = { string.format(" %-22s", item.name) }
      -- Enabled status (checkmark for enabled bundles, spacer otherwise)
      if item.cat == "Bundle" and item.enabled then
        ret[#ret + 1] = { icons.checkmark .. " ", "DiagnosticOk" }
      else
        ret[#ret + 1] = { "  " }
      end
      -- Override status
      if item.has_override then
        ret[#ret + 1] = { "override", "DiagnosticWarn" }
      else
        ret[#ret + 1] = { "--", "Comment" }
      end
      return ret
    end,
    confirm = function(picker, item)
      picker:close()
      local readonly = not vim.g.noethervim_dev
      if readonly then
        vim.cmd("view " .. vim.fn.fnameescape(item.upstream))
        vim.bo.readonly = true
        vim.bo.modifiable = false
      else
        vim.cmd("edit " .. vim.fn.fnameescape(item.upstream))
      end
      if item.user_file then
        vim.cmd("vsplit " .. vim.fn.fnameescape(item.user_file))
      else
        vim.notify("NoetherVim: no user override for '" .. item.name .. "' (showing upstream only)", vim.log.levels.INFO)
      end
    end,
  })
end

-- ── Diff dispatcher ──────────────────────────────────────────────

--- Subcommand dispatcher for `:NoetherVim diff`.
---
---@param what? "keymaps"|"options"|string
---     `"keymaps"` opens the keymap diff picker, `"options"` opens the
---     option diff picker; any other string is treated as a module name
---     and forwarded to `diff_file()`.
function M.diff(what)
  if what == "keymaps" then
    M.diff_keymaps()
  elseif what == "options" then
    M.diff_options()
  else
    M.diff_file(what)
  end
end

-- ── Override: open user file for current source ─────────────

--- Core modules with direct user overrides in lua/user/.
local CORE_OVERRIDE_MODULES = {
  options = true, keymaps = true, autocmds = true, highlights = true,
}

--- Map a NoetherVim source file to its user override path.
--- Returns (user_path, category) or (nil, nil).
local function map_to_user_path(bufpath)
  local root = effective_root()
  if not root then return nil, nil end
  local config = vim.fn.stdpath("config")
  local udir = user_dir()

  -- Resolve real paths so symlinks don't break the prefix check.
  bufpath = vim.uv.fs_realpath(bufpath) or vim.fs.normalize(bufpath)
  root = vim.uv.fs_realpath(root) or vim.fs.normalize(root)
  if not vim.startswith(bufpath, root .. "/") then return nil, nil end
  local rel = bufpath:sub(#root + 2)

  -- lua/noethervim/plugins/<dir>/<file> → user/plugins/<dir>.lua
  local plugin_subdir = rel:match("^lua/noethervim/plugins/([^/]+)/")
  if plugin_subdir then
    return udir .. "plugins/" .. plugin_subdir .. ".lua", "plugin"
  end
  -- lua/noethervim/plugins/<name>.lua → user/plugins/<name>.lua
  local plugin = rel:match("^lua/noethervim/plugins/(.+%.lua)$")
  if plugin then return udir .. "plugins/" .. plugin, "plugin" end
  -- lua/noethervim/bundles/<category>/<name>.lua → user/plugins/<name>.lua
  -- User overrides target the bundle by its bare name -- the category
  -- subdirectory is purely organizational in the distro.
  local bundle = rel:match("^lua/noethervim/bundles/[^/]+/([^/]+%.lua)$")
  if bundle then return udir .. "plugins/" .. bundle, "bundle" end
  -- lua/noethervim/lsp/<name>.lua → user/lsp/<name>.lua
  local lsp = rel:match("^lua/noethervim/lsp/(.+%.lua)$")
  if lsp then return udir .. "lsp/" .. lsp, "lsp" end
  -- lua/noethervim/<name>.lua → user/<name>.lua or user/overrides/<name>.lua
  local core = rel:match("^lua/noethervim/([^/]+)%.lua$")
  if core then
    if CORE_OVERRIDE_MODULES[core] then
      return udir .. core .. ".lua", "core"
    end
    return udir .. "overrides/" .. core .. ".lua", "override"
  end
  -- ftplugin/<path> → <config>/ftplugin/<path>
  local ft = rel:match("^ftplugin/(.+)$")
  if ft then return config .. "/ftplugin/" .. ft, "ftplugin" end

  return nil, nil
end

--- Minimal seed content for a new override file.
local function seed_content(rel_path, category)
  local name = vim.fn.fnamemodify(rel_path, ":t:r")
  local lines = { "-- Override: " .. rel_path }
  if category == "plugin" or category == "bundle" then
    lines[#lines + 1] = "-- See :help noethervim-user-plugins"
    lines[#lines + 1] = "return {}"
  elseif category == "lsp" then
    lines[#lines + 1] = "-- See :help noethervim-user-lsp"
    lines[#lines + 1] = 'vim.lsp.config("' .. name .. '", {'
    lines[#lines + 1] = "})"
  elseif category == "core" then
    lines[#lines + 1] = "-- See noethervim/" .. name .. ".lua for defaults."
  elseif category == "override" then
    lines[#lines + 1] = "-- Imperative override (runs after all other setup)."
    lines[#lines + 1] = "-- See :help noethervim-user-overrides"
  elseif category == "ftplugin" then
    lines[#lines + 1] = "-- Filetype settings -- runs after the distribution ftplugin."
  end
  lines[#lines + 1] = ""
  return table.concat(lines, "\n")
end

function M.override()
  local bufpath = vim.api.nvim_buf_get_name(0)
  if bufpath == "" then
    return vim.notify("NoetherVim: current buffer has no file", vim.log.levels.WARN)
  end

  local user_path, category = map_to_user_path(bufpath)
  if not user_path then
    return vim.notify("NoetherVim: no override mapping for this file", vim.log.levels.WARN)
  end

  -- Create parent directory if needed
  local parent = vim.fn.fnamemodify(user_path, ":h")
  if vim.fn.isdirectory(parent) == 0 then
    vim.fn.mkdir(parent, "p")
  end

  -- Seed the file with a minimal template if it's new
  local is_new = not vim.uv.fs_stat(user_path)
  if is_new then
    local root = vim.fs.normalize(effective_root())
    local rel = vim.fs.normalize(bufpath):sub(#root + 2)
    local content = seed_content(rel, category)
    local fd = vim.uv.fs_open(user_path, "w", 420) -- 0644
    if fd then
      vim.uv.fs_write(fd, content)
      vim.uv.fs_close(fd)
    end
  end

  vim.cmd("vsplit " .. vim.fn.fnameescape(user_path))
  if is_new then
    vim.notify("NoetherVim: created " .. vim.fn.fnamemodify(user_path, ":~"), vim.log.levels.INFO)
  end
end

-- ── Command dispatcher ───────────────────────────────────────────

-- One-liner per subcommand.  Surfaced in the no-arg help printout.
local subcommand_descriptions = {
  files             = "Browse NoetherVim source files",
  grep              = "Live grep over NoetherVim source",
  user              = "Browse files in lua/user/",
  plugins           = "Browse installed plugins",
  bundles           = "Bundle picker (<C-y> enable, <C-x> disable)",
  templates         = "Stamp user-config templates into lua/user/ (<C-y>)",
  ["keymap-guide"]  = "Keymap namespace reference buffer",
  status            = "Show which user override files are loaded",
  diff              = "Compare overrides vs distro defaults (keymaps / options / file)",
  override          = "Open the user override file matching the current buffer",
  ["debug-keymaps"] = "Trace where each keymap was registered",
}

local subcommands = {
  files             = M.files,
  grep              = M.grep,
  user              = M.user,
  plugins           = M.plugins,
  bundles           = M.bundles,
  templates         = M.templates,
  ["keymap-guide"]  = function() require("noethervim.guide").open() end,
  status            = M.status,
  diff              = function(args) M.diff(args) end,
  override          = M.override,
  ["debug-keymaps"] = function() M.debug_keymaps() end,
}

local subcommand_names = vim.tbl_keys(subcommands)
table.sort(subcommand_names)

local function print_help()
  local lines = { "NoetherVim subcommands:", "" }
  for _, name in ipairs(subcommand_names) do
    lines[#lines + 1] = string.format("  %-15s  %s", name, subcommand_descriptions[name] or "")
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Tab-complete after `:NoetherVim ` to pick one."
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "NoetherVim" })
end

function M.setup()
  -- ── :NoetherVim command ──────────────────────────────────────
  local function noethervim_handler(opts)
    local args = vim.split(opts.args, "%s+", { trimempty = true })
    local cmd  = args[1]
    if not cmd then
      print_help()
      return
    end
    local fn = subcommands[cmd]
    if fn then
      fn(args[2])
    else
      vim.notify("NoetherVim: unknown subcommand '" .. cmd .. "'", vim.log.levels.ERROR)
    end
  end

  local noethervim_cmd_opts = {
    nargs = "*",
    complete = function(_, cmdline)
      local args = vim.split(cmdline, "%s+", { trimempty = true })
      -- Complete subcommand name
      if #args <= 2 then
        return vim.tbl_filter(function(s)
          return s:find(args[2] or "", 1, true) == 1
        end, subcommand_names)
      end
      -- Complete diff targets (auto-generated from filesystem)
      if args[2] == "diff" and #args <= 3 then
        local targets = {}
        local seen = {}
        local root = effective_root()
        if root then
          for _, dir in ipairs({
            root .. "/lua/noethervim",
            root .. "/lua/noethervim/plugins",
            root .. "/lua/noethervim/lsp",
          }) do
            for _, mod in ipairs(scan_lua_modules(dir)) do
              if mod ~= "init" and not seen[mod] then
                seen[mod] = true
                targets[#targets + 1] = mod
              end
            end
          end
          for _, entry in ipairs(require("noethervim.util").scan_bundles(root .. "/lua/noethervim/bundles")) do
            if not seen[entry.name] then
              seen[entry.name] = true
              targets[#targets + 1] = entry.name
            end
          end
        end
        table.sort(targets)
        return vim.tbl_filter(function(s)
          return s:find(args[3] or "", 1, true) == 1
        end, targets)
      end
      return {}
    end,
    desc = "NoetherVim inspection and comparison commands",
  }

  vim.api.nvim_create_user_command("NoetherVim",  noethervim_handler, noethervim_cmd_opts)
  vim.api.nvim_create_user_command("NeotherVim",  noethervim_handler, noethervim_cmd_opts) -- common misspelling alias

  -- ── Keymaps (SearchLeader+c prefix) ──────────────────────────
  -- Note: SearchLeader+cu (user settings), +cc (config lua),
  -- +cf (ftplugins), +cs (snippets) are defined in
  -- snacks.lua.  These keymaps extend the same namespace.
  vim.keymap.set("n", SearchLeader .. "cnn", M.files,        { desc = "[n]oetherVim source" })
  vim.keymap.set("n", SearchLeader .. "cng", M.grep,         { desc = "[n]oetherVim [g]rep" })
  vim.keymap.set("n", SearchLeader .. "cb", M.bundles,       { desc = "[b]undles" })
  vim.keymap.set("n", SearchLeader .. "ct", M.templates,     { desc = "[t]emplates" })
  vim.keymap.set("n", SearchLeader .. "ck", M.diff_keymaps, { desc = "diff [k]eymaps" })
  vim.keymap.set("n", SearchLeader .. "co", M.diff_options, { desc = "diff [o]ptions" })

  vim.keymap.set("n", SearchLeader .. "?", function()
    require("noethervim.guide").open()
  end, { desc = "keymap guide" })

  vim.keymap.set("n", "<leader>i", "<cmd>edit $MYVIMRC<cr>", { desc = "open [i]nit.lua" })

  -- ── upstream compare ────────────────────────────────────────
  vim.keymap.set("n", SearchLeader .. "cd", function()
    M.diff_file()
  end, { desc = "[d]iff file" })

  vim.keymap.set("n", SearchLeader .. "ce", M.override, { desc = "[e]dit override" })
end

return M
