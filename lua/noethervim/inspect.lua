-- NoetherVim inspection, comparison, and status commands.
-- Loaded at the end of noethervim.setup().
-- All commands live under the :NoetherVim namespace.
-- See :help noethervim-inspect for documentation.

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
      desc = desc,
      enabled = is_enabled,
    })
  end

  table.sort(items, function(a, b)
    if a.cat_order ~= b.cat_order then return a.cat_order < b.cat_order end
    return a.bundle_name < b.bundle_name
  end)

  Snacks.picker({
    title   = "NoetherVim Bundles",
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
    table.insert(lines, "Loaded LSP overrides: " .. table.concat(nv._user_lsp, ", "))
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
local function locate_in_buffer(lhs)
  pcall(vim.api.nvim_win_set_cursor, 0, { 1, 0 })

  local registry = require("noethervim.util.keymap_registry")
  local forms = registry.source_forms(lhs)
  local canon_forms = {}
  for _, f in ipairs(forms) do canon_forms[#canon_forms + 1] = registry.canon(f) end

  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  -- Lua single-line comment; vimscript `"` comment is intentionally NOT
  -- treated as a comment here because Lua lines frequently start with a
  -- quoted string (lazy spec `"<lhs>", ...`) that would be misclassified.
  local function is_comment(line)
    return line:match("^%s*%-%-") ~= nil
  end

  local function jump(line_no)
    pcall(vim.api.nvim_win_set_cursor, 0, { line_no, 0 })
    vim.cmd("norm! zzzv")
    return line_no
  end

  -- Pass 1: quoted form in any non-comment line.
  for i, line in ipairs(lines) do
    if not is_comment(line) then
      local cline = registry.canon(line)
      for _, cf in ipairs(canon_forms) do
        if cf ~= ""
           and (cline:find('"' .. cf .. '"', 1, true)
                or cline:find("'" .. cf .. "'", 1, true)) then
          return jump(i)
        end
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
          return jump(i)
        end
      end
    end
  end

  -- Pass 3: bare multi-char match in strong keymap-defining context.
  for i, line in ipairs(lines) do
    if not is_comment(line) then
      local strong = line:find("vim%.keymap%.set")
                  or line:find("vim%.api%.nvim_set_keymap")
                  or line:find("keys%s*=%s*{")
                  or line:find("[%s^]toggle%s*%(")
                  or line:find("[%s^]map%s*%(")
      if strong then
        local cline = registry.canon(line)
        for idx, cf in ipairs(canon_forms) do
          if #forms[idx] > 2 and cline:find(cf, 1, true) then
            return jump(i)
          end
        end
      end
    end
  end

  return 0
end

-- ── Shared: jump to keymap source definition ────────────────────
-- Used by diff_keymaps (confirm handler) and the guide (<CR>).

--- Jump to the source definition of a keymap.
--- Opens the file containing the definition (readonly in non-dev mode)
--- and positions the cursor on the defining line.
---
--- @param mode string   Keymap mode ("n", "i", "v", etc.)
--- @param lhs  string   Resolved keymap lhs (from nvim_get_keymap)
--- @param opts? table   { source = string? }  Optional lazy handler source hint.
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

  -- Try each candidate. Registry hits win outright; for the others we
  -- open the file and run the locate cascade. First hit returns.
  local first_opened
  for _, c in ipairs(candidates) do
    if c.line then
      if open_file(c.file, c.line) then return end
    elseif open_file(c.file) then
      first_opened = first_opened or { file = c.file, hint = c.hint }
      if locate_in_buffer(lhs) > 0 then return end
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

  -- Refine [CORE] → [USER] using the registry. If the last
  -- `vim.keymap.set` that touched this key came from a file under
  -- `lua/user/`, the user owns it. The old needle-scanning fallback is
  -- unnecessary now: the registry records the authoritative callsite.
  local udir_norm = vim.fs.normalize(user_dir())
  local registry = require("noethervim.util.keymap_registry")
  for _, item in ipairs(items) do
    if item.tag == "[CORE]" then
      local entry = registry.lookup(item.mode, item.lhs)
      if entry and entry.file
         and vim.startswith(vim.fs.normalize(entry.file), udir_norm) then
        item.tag  = "[USER]"
        item.text = "[USER]" .. item.text:sub(7)
        item.source = entry.file
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
--- Run with :NoetherVim debug keymaps
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

local subcommands = {
  files    = M.files,
  grep     = M.grep,
  user     = M.user,
  plugins  = M.plugins,
  bundles  = M.bundles,
  status   = M.status,
  diff     = function(args) M.diff(args) end,
  override = M.override,
  guide    = function() require("noethervim.guide").open() end,
  debug    = function(args)
    if args == "keymaps" then M.debug_keymaps()
    else vim.notify("NoetherVim: debug targets: keymaps", vim.log.levels.INFO) end
  end,
}

local subcommand_names = vim.tbl_keys(subcommands)
table.sort(subcommand_names)

function M.setup()
  -- ── :NoetherVim command ──────────────────────────────────────
  local function noethervim_handler(opts)
    local args = vim.split(opts.args, "%s+", { trimempty = true })
    local cmd  = args[1]
    if not cmd then
      -- No subcommand: show the source file picker as default
      M.files()
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
      -- Complete debug targets
      if args[2] == "debug" and #args <= 3 then
        return vim.tbl_filter(function(s)
          return s:find(args[3] or "", 1, true) == 1
        end, { "keymaps" })
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
