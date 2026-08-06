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

--- Build a snacks footer listing the picker's non-obvious keys.
---
--- Snacks draws this on the input window's bottom border, which spans the
--- list column only -- half the layout, measuring 38 columns on an
--- 80-column terminal.  Neovim truncates a longer footer without warning,
--- so hints are dropped from the front (the most obvious keys) until the
--- assembled text fits, and the full key list stays one `<F1>` away.
---@param hints [string, string][]  { key, label } pairs, least important first
---@return snacks.picker.Highlight[]
local function hint_footer(hints)
  local budget = 36
  local width = 2 -- the leading and trailing pad below
  local kept = {}
  for i = #hints, 1, -1 do
    local cost = #hints[i][1] + 1 + #hints[i][2] + (#kept > 0 and 2 or 0)
    if width + cost > budget then break end
    width = width + cost
    table.insert(kept, 1, hints[i])
  end

  local footer = { { " ", "SnacksFooter" } }
  for i, hint in ipairs(kept) do
    if i > 1 then footer[#footer + 1] = { "  ", "SnacksFooter" } end
    footer[#footer + 1] = { hint[1], "SnacksFooterKey" }
    footer[#footer + 1] = { " " .. hint[2], "SnacksFooterDesc" }
  end
  footer[#footer + 1] = { " ", "SnacksFooter" }
  return footer
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
  refactoring     = "extract function/variable/block",
  octo            = "GitHub PRs/issues/reviews via gh CLI (<C-w>O)",
  -- navigation
  harpoon         = "fast per-project file marks",
  flash           = "enhanced f/t and / motions with labels",
  projects        = "project switcher via snacks.picker",
  ["editing-extras"] = "argmark + decorative comment boxes",
  yanky           = "yank ring -- cycle through paste history (<C-p>/<C-n>)",
  -- writing
  markdown        = "render, preview, tables, math, image paste",
  wrapsearch      = "search across hard-wrapped lines (/ and ?)",
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
  ["nvim-dev"]    = "StartupTime, Luapad, vimls -- Neovim config development",
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
        footer     = hint_footer({ { "<cr>", "open" }, { "<c-y>", "enable" }, { "<f1>", "keys" } }),
        footer_pos = "center",
        keys = {
          ["<CR>"]  = { "confirm",        mode = { "i", "n" }, desc = "open bundle source (readonly)" },
          ["<C-y>"] = { "enable_bundle",  mode = { "i", "n" }, desc = "enable bundle"  },
          ["<C-x>"] = { "disable_bundle", mode = { "i", "n" }, desc = "disable bundle" },
        },
      },
      list = {
        keys = {
          ["<CR>"]  = { "confirm",        desc = "open bundle source (readonly)" },
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
    title   = "NoetherVim Templates",
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
        footer     = hint_footer({ { "<cr>", "open" }, { "<c-y>", "stamp" }, { "<f1>", "keys" } }),
        footer_pos = "center",
        keys = {
          ["<CR>"]  = { "confirm",        mode = { "i", "n" }, desc = "open template (readonly)" },
          ["<C-y>"] = { "stamp_template", mode = { "i", "n" }, desc = "stamp template into lua/user/" },
        },
      },
      list = {
        keys = {
          ["<CR>"]  = { "confirm",        desc = "open template (readonly)" },
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
-- Source attribution, line location, and jump-to-definition all live in
-- `noethervim.util.keymap_source`.  This module only consumes them: the
-- pickers below need the classifiers (`same_mapping`, `is_nvim_default`)
-- to build their item lists, and the file/line resolvers to turn an item
-- into a quickfix entry.

local keymap_source    = require("noethervim.util.keymap_source")
local same_mapping     = keymap_source.same_mapping
local callback_file    = keymap_source.callback_file
local find_lhs_line    = keymap_source.find_lhs_line
local scan_project_for = keymap_source.scan_project_for
local _file_lines      = keymap_source.file_lines

-- ── Shared: jump to keymap source definition ────────────────────
-- Used by diff_keymaps (confirm handler) and the guide (<CR>).

--- Jump to the source definition of a keymap.  Delegates to
--- `util.keymap_source.jump`; kept under this name because `guide.lua`
--- and the keymap-landing test suite call it here.
---
---@param mode string   Keymap mode ("n", "i", "v", etc.)
---@param lhs  string   Resolved keymap lhs (from nvim_get_keymap)
---@param opts? noethervim.KeymapJumpOpts
function M.jump_to_keymap(mode, lhs, opts)
  return keymap_source.jump(mode, lhs, opts)
end

-- ── Comparison: Keymaps (Phase 6.1) ─────────────────────────────

---@class noethervim.inspect.DiffKeymapOpts
---@field thirdparty? boolean  Also list keymaps owned by third-party
---                            plugins (marks.nvim, mini.ai, ...). Off by
---                            default; toggled from inside the picker.

--- Picker over every keymap NoetherVim or the user is responsible for,
--- tagged by how it got there and by which part of the config owns it.
---@param opts? noethervim.inspect.DiffKeymapOpts
function M.diff_keymaps(opts)
  opts = opts or {}
  local thirdparty = opts.thirdparty or false

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

  -- Live keymap index, built once and used twice below: to rescue lazy
  -- loading stubs from the Neovim-default filter, and to merge in
  -- everything registered after the snapshots were taken.
  local MODES = { "n", "i", "v", "x", "s", "o", "c", "t" }
  local live, live_buflocal = {}, {}
  for _, mode in ipairs(MODES) do
    for _, km in ipairs(vim.api.nvim_get_keymap(mode)) do
      live[mode .. "|" .. km.lhs] = km
    end
    -- Buffer-local maps never appear in any snapshot (nvim_get_keymap is
    -- global-only), so LSP and ftplugin keymaps only surface here, and
    -- only for the buffer the picker was opened from.
    for _, km in ipairs(vim.api.nvim_buf_get_keymap(0, mode)) do
      local k = mode .. "|" .. km.lhs
      if not live[k] then
        live[k] = km
        live_buflocal[k] = true
      end
    end
  end

  -- Collect all keys from both snapshots
  local all_keys = {}
  for k in pairs(before) do all_keys[k] = true end
  for k in pairs(after)  do all_keys[k] = true end

  for key in pairs(all_keys) do
    local bl = baseline[key]
    local b  = before[key]
    local a  = after[key]
    local tag, mode, lhs, desc

    -- `<Plug>` handles are plumbing: never pressed directly, only pointed
    -- at by a real keymap. The guide filters them for the same reason.
    if (a or b).lhs:find("<Plug>", 1, true) then goto continue end

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
        --
        -- A lazy loading stub is exempt: lazy installs its `keys = {...}`
        -- stubs before NoetherVim's config runs, so they sit in the
        -- baseline looking exactly like a default that nobody touched.
        -- They are plugin keymaps, and `keymap_sources()` does not always
        -- manage to attribute them to a spec file.
        if bl and not key_sources[key] and not lazy_managed[key]
           and same_mapping(bl, b)
           and not keymap_source.is_lazy_stub(live[key]) then
          goto continue
        end
        tag  = "[CORE]"
        mode = a.mode
        lhs  = a.lhs
        desc = a.desc
      end
    end

    if tag then
      table.insert(items, {
        tag      = tag,
        mode     = mode,
        lhs      = lhs,
        desc     = desc,
        source   = key_sources[key],
        callback = (a or b).callback,
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
        item.source = owner_file
      end
    end
  end

  -- Live merge.  The snapshots are taken inside setup(), so every keymap
  -- registered later is invisible to the diff above: plugin `config` and
  -- `opts` bodies, ftplugins, and anything a lazy-loaded plugin sets when
  -- it finally loads.  Walk the live keymap tables and add what is
  -- missing, keeping only keys the distro or the user actually owns --
  -- `<Plug>` handles and Neovim's own defaults are noise here, and
  -- plugin-internal keymaps belong to <SearchLeader>fk unless the user
  -- asks for them.
  local seen = {}
  for _, item in ipairs(items) do seen[item.mode .. "|" .. item.lhs] = true end

  for key, km in pairs(live) do
    if not seen[key]
       and not km.lhs:find("<Plug>", 1, true)
       and not keymap_source.is_nvim_default(km) then
      local mode = key:match("^([^|]+)|")
      local file = keymap_source.owner_file(mode, km.lhs, {
        source = key_sources[key], callback = km.callback,
      })
      local origin = keymap_source.origin_of_file(file)
      if not origin and thirdparty then origin = "plugin" end
      if origin then
        seen[key] = true
        items[#items + 1] = {
          tag      = origin == "user" and "[USER]" or "[CORE]",
          mode     = mode,
          lhs      = km.lhs,
          desc     = km.desc or "",
          source   = file,
          callback = km.callback,
          origin   = origin,
          buflocal = live_buflocal[key] or nil,
        }
      end
    end
  end

  --- Pad to a display width. `%-Ns` counts bytes, and both the `␣` that
  --- stands in for a literal space in the lhs column and the truncation
  --- ellipsis below are three bytes wide but one column -- byte padding
  --- leaves every leader-prefixed row short.
  local function pad(s, w)
    return s .. string.rep(" ", math.max(0, w - vim.fn.strdisplaywidth(s)))
  end

  -- Origin for the snapshot-derived items, and the search text for all of
  -- them.  Origin is the bundle stem for bundle-owned keys so an opt-in
  -- bundle's contributions stand out; everything else in the distro is
  -- "core", which renders blank because it is the overwhelming majority.
  local ORIGIN_MAX = 12
  local origin_w = 0
  for _, item in ipairs(items) do
    if not item.origin then
      -- Prefer the live callback over the snapshot's: once a lazy plugin
      -- has loaded, the live one points at the file that really defines
      -- the key, while the snapshot still holds the loading stub.
      local km = live[item.mode .. "|" .. item.lhs]
      item.origin = keymap_source.origin_of_file(
        keymap_source.owner_file(item.mode, item.lhs,
          { source = item.source, callback = (km and km.callback) or item.callback })) or ""
    end
    if item.origin == "core" or item.origin == "user" then
      item.label = ""
    else
      -- `editing-extras` is the only bundle name that overflows; a bounded
      -- column beats a 15-wide gutter that is blank on almost every row.
      item.label = #item.origin > ORIGIN_MAX
        and (item.origin:sub(1, ORIGIN_MAX - 1) .. "…") or item.origin
      origin_w = math.max(origin_w, vim.fn.strdisplaywidth(item.label))
    end
    -- `text` drives the picker's fuzzy matching, so the origin goes in:
    -- typing "latex" narrows to the latex bundle's keys.
    local display_lhs = item.lhs:gsub(" ", "␣"):gsub("<lt>", "<")
    item.text = table.concat({
      item.tag, item.mode, display_lhs, item.desc, item.origin,
      item.buflocal and "buffer" or "",
    }, " ")
  end
  -- `origin_w == 0` collapses the column entirely, which is the whole
  -- picture on an install with no bundles enabled.

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
    local text = string.format("%-11s [%s] %s %s%s",
                               item.tag, item.mode, pad(display_lhs, 16),
                               item.label ~= "" and (item.label .. "  ") or "",
                               item.desc or "")

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
    title  = "NoetherVim Keymap Comparison" .. (thirdparty and " + plugins" or ""),
    items  = items,
    layout = { preset = "select", preview = "main" },
    win = { input = {
      -- Least important first: hint_footer drops from the front. `<c-x>`
      -- outranks `<cr>`/`<c-q>` because it is the one key here a user
      -- cannot guess, and the label stays a constant `plugins` rather
      -- than flipping `+`/`-` so the footer does not reshuffle on toggle
      -- -- the title carries the state.
      footer     = hint_footer({
        { "<cr>", "source" }, { "<c-q>", "qf" },
        { "<c-x>", "plugins" }, { "<f1>", "keys" },
      }),
      footer_pos = "center",
      keys = {
        -- Space inserts ␣ so the search matches the visible display
        ["<Space>"] = {
          function() vim.api.nvim_feedkeys("␣", "n", true) end,
          mode = { "i" }, nowait = true, desc = "insert ␣",
        },
        ["<C-x>"] = { "toggle_thirdparty", mode = { "i", "n" },
                      desc = "third-party plugin keys" },
      },
    } },
    format = function(item)
      local ret = {} ---@type snacks.picker.Highlight[]
      ret[#ret + 1] = { string.format("%-11s", item.tag), tag_hl[item.tag] or "Comment" }
      ret[#ret + 1] = { string.format(" [%s] ", item.mode), "Special" }
      -- Replace literal spaces with ␣ so SearchLeader prefixes are visible
      ret[#ret + 1] = { pad(item.lhs:gsub(" ", "␣"):gsub("<lt>", "<"), 16) .. " ", "SnacksPickerFile" }
      if origin_w > 0 then
        ret[#ret + 1] = { pad(item.label, origin_w) .. " ",
                          item.label == "plugin" and "NonText" or "Special" }
      end
      ret[#ret + 1] = { item.desc, "Comment" }
      if item.buflocal then
        ret[#ret + 1] = { "  (buffer)", "NonText" }
      end
      return ret
    end,
    actions = {
      -- Override snacks' default qflist action (bound to <C-q>) to
      -- resolve each keymap's file+line via the same candidate cascade
      -- the picker's confirm uses, rather than the default which only
      -- reads `item.file`/`item.pos` (these items have neither).
      qflist = send_to_qf,
      -- Reopen rather than re-filter: the third-party set changes which
      -- items exist, not just which are shown, and rebuilding is cheap.
      toggle_thirdparty = function(picker)
        picker:close()
        M.diff_keymaps({ thirdparty = not thirdparty })
      end,
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
    win = { input = {
      footer     = hint_footer({ { "<cr>", "source" }, { "<f1>", "keys" } }),
      footer_pos = "center",
    } },
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

--- Semantic diff targets: these compare live state, not file contents.
local SEMANTIC_DIFF_TARGETS = { "keymaps", "options", "autocmds" }

--- Subcommand dispatcher for `:NoetherVim diff`.
---
---@param what? "keymaps"|"options"|"autocmds"|string
---     The three semantic targets open their own comparison picker; any
---     other string is treated as a module name and forwarded to
---     `diff_file()`, which falls back to a module picker when nil.
function M.diff(what)
  if what == "keymaps" then
    M.diff_keymaps()
  elseif what == "options" then
    M.diff_options()
  elseif what == "autocmds" then
    M.diff_autocmds()
  else
    M.diff_file(what)
  end
end

--- Every accepted argument to `:NoetherVim diff` -- the semantic targets
--- first, then one entry per distro module (core, plugin, lsp, bundle).
---@return string[]
local function diff_targets()
  local targets, seen = {}, {}
  for _, name in ipairs(SEMANTIC_DIFF_TARGETS) do
    seen[name] = true
    targets[#targets + 1] = name
  end
  local root = effective_root()
  if not root then return targets end

  local modules = {}
  for _, dir in ipairs({
    root .. "/lua/noethervim",
    root .. "/lua/noethervim/plugins",
    root .. "/lua/noethervim/lsp",
  }) do
    for _, mod in ipairs(scan_lua_modules(dir)) do
      if mod ~= "init" and not seen[mod] then
        seen[mod] = true
        modules[#modules + 1] = mod
      end
    end
  end
  for _, entry in ipairs(require("noethervim.util").scan_bundles(root .. "/lua/noethervim/bundles")) do
    if not seen[entry.name] then
      seen[entry.name] = true
      modules[#modules + 1] = entry.name
    end
  end
  table.sort(modules)
  vim.list_extend(targets, modules)
  return targets
end

-- ── Comparison: Autocommands ────────────────────────────────────
--
-- Autocommands are additive, so the interesting question is not "which
-- line changed" but "is the core augroup still the one doing the work".
-- The documented way to override a core autocmd is to clear its augroup
-- and re-register (see |noethervim-user-autocmds|), and that is exactly
-- what this picker reports:
--
--   [CORE]     distro augroup, still populated from distro source
--   [OVERRIDE] distro augroup, but its handlers now come from lua/user/
--   [CLEARED]  distro augroup that exists but holds no handlers
--   [INACTIVE] never created this session (disabled bundle, plugin not
--              triggered, config flag off) -- absence here is expected
--   [USER]     augroup the distro never registers

--- Augroup names the distribution registers, scraped from its own source.
--- Scraping beats a hardcoded list: it cannot drift when an augroup is
--- added or renamed.
---@param root string
---@return table<string, string>  augroup name -> defining file
local function distro_augroups(root)
  local found = {}
  local files = vim.fn.globpath(root .. "/lua/noethervim", "**/*.lua", false, true)
  for _, file in ipairs(files) do
    local fd = io.open(file, "r")
    if fd then
      for line in fd:lines() do
        local name = line:match('nvim_create_augroup%(%s*"([^"]+)"')
        if name and not found[name] then found[name] = file end
      end
      fd:close()
    end
  end
  return found
end

--- Was this augroup ever created in this session?
---
--- Scraping the source tells us an augroup *can* exist, not that it does:
--- the `nvim_create_augroup` call may sit behind a disabled bundle or a
--- config flag that is off. `nvim_get_autocmds` draws the line for us --
--- it errors on a group that was never created and returns an empty list
--- for one that exists but holds nothing.
---@param group string
---@return boolean
local function augroup_exists(group)
  return (pcall(vim.api.nvim_get_autocmds, { group = group }))
end

--- Where a live autocmd's callback was defined, as file + line.
---@param cmd table  entry from nvim_get_autocmds
---@return string? file
---@return integer? line
local function autocmd_source(cmd)
  if type(cmd.callback) ~= "function" then return nil, nil end
  local ok, info = pcall(debug.getinfo, cmd.callback, "S")
  if not ok or not info or not info.source or info.source:sub(1, 1) ~= "@" then
    return nil, nil
  end
  return info.source:sub(2), info.linedefined
end

function M.diff_autocmds()
  local root = effective_root()
  if not root then return vim.notify("NoetherVim: cannot locate source directory", vim.log.levels.ERROR) end
  local distro = distro_augroups(root)
  local udir = vim.fs.normalize(user_dir())
  local normroot = vim.fs.normalize(root)

  -- Collect live autocmds grouped by augroup.
  local live = {}
  for _, cmd in ipairs(vim.api.nvim_get_autocmds({})) do
    local group = cmd.group_name
    if group then
      local entry = live[group] or { count = 0, events = {}, from_user = false, file = nil, line = nil }
      entry.count = entry.count + 1
      if not vim.tbl_contains(entry.events, cmd.event) then
        entry.events[#entry.events + 1] = cmd.event
      end
      local file, line = autocmd_source(cmd)
      if file then
        file = vim.fs.normalize(file)
        if vim.startswith(file, udir) then entry.from_user = true end
        -- Prefer a user file as the jump target; it is the one being edited.
        if not entry.file or (entry.from_user and vim.startswith(file, udir)) then
          entry.file, entry.line = file, line
        end
      end
      live[group] = entry
    end
  end

  local items = {}
  local function add(group, tag, entry, fallback_file)
    table.sort(entry and entry.events or {})
    table.insert(items, {
      text   = tag .. " " .. group .. " " .. table.concat(entry and entry.events or {}, " "),
      tag    = tag,
      group  = group,
      count  = entry and entry.count or 0,
      events = table.concat(entry and entry.events or {}, ", "),
      file   = (entry and entry.file) or fallback_file,
      line   = entry and entry.line or nil,
    })
  end

  for group, src in pairs(distro) do
    local entry = live[group]
    if not entry then
      add(group, augroup_exists(group) and "[CLEARED]" or "[INACTIVE]", nil, src)
    elseif entry.from_user then
      add(group, "[OVERRIDE]", entry, src)
    else
      add(group, "[CORE]", entry, src)
    end
  end
  for group, entry in pairs(live) do
    if not distro[group] then
      -- Neovim's own augroups are noise here; only surface groups whose
      -- handlers were defined under the user's config directory.
      local file = entry.file
      if file and (vim.startswith(file, udir) or not vim.startswith(file, normroot)) then
        if vim.startswith(file, vim.fs.normalize(vim.fn.stdpath("config"))) then
          add(group, "[USER]", entry, nil)
        end
      end
    end
  end

  local tag_order = {
    ["[OVERRIDE]"] = 1, ["[CLEARED]"] = 2, ["[USER]"] = 3,
    ["[CORE]"] = 4, ["[INACTIVE]"] = 5,
  }
  local tag_hl = {
    ["[OVERRIDE]"] = "DiagnosticWarn",
    ["[CLEARED]"]  = "DiagnosticError",
    ["[USER]"]     = "DiagnosticOk",
    ["[CORE]"]     = "Comment",
    ["[INACTIVE]"] = "NonText",
  }
  table.sort(items, function(a, b)
    local oa, ob = tag_order[a.tag] or 9, tag_order[b.tag] or 9
    if oa ~= ob then return oa < ob end
    return a.group < b.group
  end)

  Snacks.picker({
    title  = "NoetherVim Autocommand Comparison",
    items  = items,
    layout = { preset = "select", preview = "main" },
    win = { input = {
      footer     = hint_footer({ { "<cr>", "source" }, { "<f1>", "keys" } }),
      footer_pos = "center",
    } },
    format = function(item)
      local ret = {} ---@type snacks.picker.Highlight[]
      ret[#ret + 1] = { string.format("%-11s", item.tag), tag_hl[item.tag] or "Comment" }
      ret[#ret + 1] = { string.format(" %-28s", item.group), "SnacksPickerFile" }
      ret[#ret + 1] = { string.format("%-3d ", item.count), "Number" }
      ret[#ret + 1] = { item.events, "Comment" }
      return ret
    end,
    confirm = function(picker, item)
      picker:close()
      if not item.file or not vim.uv.fs_stat(item.file) then
        return vim.notify("NoetherVim: no source recorded for " .. item.group, vim.log.levels.WARN)
      end
      local readonly = vim.startswith(item.file, normroot) and not vim.g.noethervim_dev
      vim.cmd((readonly and "view " or "edit ") .. vim.fn.fnameescape(item.file))
      if readonly then vim.bo.readonly = true; vim.bo.modifiable = false end
      if item.line then
        pcall(vim.api.nvim_win_set_cursor, 0, { item.line, 0 })
      else
        vim.fn.search(vim.fn.escape(item.group, "/\\[]{}().*+^$~"), "w")
      end
      vim.cmd("norm! zz")
    end,
  })
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
  diff              = "Compare overrides vs distro defaults (keymaps / options / autocmds / module)",
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
      -- No `trimempty`: a trailing space has to survive as an empty final
      -- element, otherwise `:NoetherVim diff <Tab>` is indistinguishable
      -- from `:NoetherVim diff<Tab>` and completes subcommands instead of
      -- diff targets.
      local args = vim.split((cmdline:gsub("^%s+", "")), "%s+")
      -- Complete subcommand name
      if #args <= 2 then
        return vim.tbl_filter(function(s)
          return s:find(args[2] or "", 1, true) == 1
        end, subcommand_names)
      end
      -- Complete diff targets
      if args[2] == "diff" and #args == 3 then
        return vim.tbl_filter(function(s)
          return s:find(args[3], 1, true) == 1
        end, diff_targets())
      end
      return {}
    end,
    desc = "NoetherVim inspection and comparison commands",
  }

  vim.api.nvim_create_user_command("NoetherVim",  noethervim_handler, noethervim_cmd_opts)
  vim.api.nvim_create_user_command("NeotherVim",  noethervim_handler, noethervim_cmd_opts) -- common misspelling alias

end

return M
