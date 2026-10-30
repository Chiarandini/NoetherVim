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

--- Hook files that sit on top of a distro file of the same name.
local CORE_OVERRIDE_MODULES = {
  options = true, keymaps = true, autocmds = true, highlights = true,
}

--- The file of yours that changes the NoetherVim file at `rel`, and its
--- category. Both paths are relative: `rel` to the distribution root, the
--- result to your config directory. Nil for a file nothing of yours can
--- stand in for.
---@param rel string
---@return string?, string?
local function counterpart(rel)
  -- lua/noethervim/plugins/<dir>/<file> → user/plugins/<dir>.lua
  local plugin_subdir = rel:match("^lua/noethervim/plugins/([^/]+)/")
  if plugin_subdir then return "lua/user/plugins/" .. plugin_subdir .. ".lua", "plugin" end
  -- lua/noethervim/plugins/<name>.lua → user/plugins/<name>.lua
  local plugin = rel:match("^lua/noethervim/plugins/(.+%.lua)$")
  if plugin then return "lua/user/plugins/" .. plugin, "plugin" end
  -- lua/noethervim/bundles/<category>/<name>.lua → user/plugins/<name>.lua
  -- User overrides target the bundle by its bare name -- the category
  -- subdirectory is purely organizational in the distro.
  local bundle = rel:match("^lua/noethervim/bundles/[^/]+/([^/]+%.lua)$")
  if bundle then return "lua/user/plugins/" .. bundle, "bundle" end
  -- after/lsp/<name>.lua → your after/lsp/<name>.lua, which loads after it
  local lsp = rel:match("^after/lsp/(.+%.lua)$")
  if lsp then return "after/lsp/" .. lsp, "lsp" end
  -- lua/noethervim/{options,keymaps,autocmds,highlights}.lua → the hook file
  local core = rel:match("^lua/noethervim/([^/]+)%.lua$")
  if core and CORE_OVERRIDE_MODULES[core] then
    return "lua/user/" .. core .. ".lua", core == "keymaps" and "keys" or "core"
  end
  if rel == "lua/noethervim/toggles/options.lua" then return "lua/user/keymaps.lua", "keys" end
  -- the profiles → after/ftplugin/<ft>.lua, the native per-filetype place
  if rel == "lua/noethervim/profiles/apply.lua" then return "after/ftplugin/", "profile" end
  -- ftplugin/<path> → after/ftplugin/<path>, which runs after it
  local ft = rel:match("^ftplugin/(.+)$")
  if ft then return "after/ftplugin/" .. ft, "ftplugin" end
end

--- Map a NoetherVim source file to the file of yours that changes it.
--- Returns (user_path, category) or (nil, nil) for a file nothing of yours
--- can stand in for.
local function map_to_user_path(bufpath)
  local root = effective_root()
  if not root then return nil, nil end
  -- Resolve real paths so symlinks don't break the prefix check.
  bufpath = vim.uv.fs_realpath(bufpath) or vim.fs.normalize(bufpath)
  root = vim.uv.fs_realpath(root) or vim.fs.normalize(root)
  if not vim.startswith(bufpath, root .. "/") then return nil, nil end
  local target, category = counterpart(bufpath:sub(#root + 2))
  if not target then return nil, nil end
  return vim.fn.stdpath("config") .. "/" .. target, category
end

--- Get snapshot data from the init module.
local function snapshots()
  return require("noethervim")._snapshots_now()
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
--- list column only -- roughly 45% of the screen. Neovim truncates a longer
--- footer without warning, so hints are dropped from the front (the most
--- obvious keys) until the assembled text fits, and the full key list stays
--- one `<F1>` away.
---
--- The budget scales with the terminal rather than assuming 80 columns, so a
--- wide window shows every hint instead of silently dropping the ones a
--- narrow window could not have fitted either way.
---@param hints [string, string][]  { key, label } pairs, least important first
---@return snacks.picker.Highlight[]
local function hint_footer(hints)
  local budget = math.max(20, math.floor(vim.o.columns * 0.45))
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
-- Bundle descriptions come from each bundle file's `@desc` annotation, via
-- util.bundle_meta. The filesystem layout (bundles/<category>/<name>.lua)
-- remains authoritative for which bundles exist and their category.
--
-- Parsed rather than listed here so there is one authored copy: the same
-- annotation feeds :checkhealth and the docs site. A bundle whose header
-- lacks @desc shows "(no description)".

-- Display order and readable labels for filesystem category names.
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
  local config = vim.fn.stdpath("config") .. "/"
  Snacks.picker.files({
    cwd     = root,
    title   = "NoetherVim Source",
    confirm = confirm_readonly,
    -- A file `:NoetherVim override` can stand in for names the file of
    -- yours that does, highlighted once it exists.
    transform = function(item)
      item.user_file = counterpart(item.file)
      item.has_override = item.user_file ~= nil and vim.uv.fs_stat(config .. item.user_file) ~= nil
    end,
    format = function(item, picker)
      local ret = Snacks.picker.format.file(item, picker)
      if item.user_file then
        ret[#ret + 1] = { "  → " .. item.user_file, item.has_override and "DiagnosticWarn" or "Comment" }
      end
      return ret
    end,
    win = {
      input = {
        footer     = hint_footer({ { "<cr>", "open" }, { "→", "your file that changes it" } }),
        footer_pos = "center",
      },
    },
  })
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
  -- Import keys look like "noethervim.bundles.<category>.<name>"; key on
  -- "<category>.<name>" so same-named bundles in two categories stay apart.
  local enabled = {}
  local ok, lazy_cfg = pcall(require, "lazy.core.config")
  if ok and lazy_cfg.spec then
    for _, mod in ipairs(lazy_cfg.spec.modules) do
      local key = mod:match("^noethervim%.bundles%.(.+)$")
      if key then enabled[key] = true end
    end
  end

  local icons = require("noethervim.util.icons")
  local bundle_meta = require("noethervim.util.bundle_meta")
  local items = {}
  for _, meta in ipairs(bundle_meta.scan(root .. "/lua/noethervim/bundles")) do
    local entry = { name = meta.name, category = meta.category, path = meta.path }
    local is_enabled = enabled[entry.category .. "." .. entry.name] or false
    local desc = meta.desc or "(no description)"
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
      -- Seeding an override is the step that follows reading a bundle, so the
      -- affordance belongs where that decision gets made. `:NoetherVim
      -- override` maps from the current buffer, hence the edit first.
      override_bundle = function(picker)
        local item = picker:current()
        if not item or not item.file then return end
        picker:close()
        vim.cmd("edit " .. vim.fn.fnameescape(item.file))
        M.override()
      end,
    },
    win = {
      input = {
        footer     = hint_footer({ { "<cr>", "open" }, { "<c-o>", "override" }, { "<c-y>", "enable" } }),
        footer_pos = "center",
        keys = {
          ["<CR>"]  = { "confirm",         mode = { "i", "n" }, desc = "open bundle source (readonly)" },
          ["<C-y>"] = { "enable_bundle",   mode = { "i", "n" }, desc = "enable bundle"  },
          ["<C-x>"] = { "disable_bundle",  mode = { "i", "n" }, desc = "disable bundle" },
          ["<C-o>"] = { "override_bundle", mode = { "i", "n" }, desc = "seed a user override for this bundle" },
        },
      },
      list = {
        keys = {
          ["<CR>"]  = { "confirm",         desc = "open bundle source (readonly)" },
          ["<C-y>"] = { "enable_bundle",   desc = "enable bundle"  },
          ["<C-x>"] = { "disable_bundle",  desc = "disable bundle" },
          ["<C-o>"] = { "override_bundle", desc = "seed a user override for this bundle" },
        },
      },
    },
  })
end

--- Every loaded snippet, with what it is doing and where it came from.
---
--- Items carry a snippet id rather than the snippet itself. `picker:selected()`
--- returns `vim.deepcopy` of its items, and a LuaSnip snippet is a table of
--- functions and metatables: copying one is expensive, copying 126 of them is
--- worse, and switching off the copy would do nothing to the snippet the
--- reader is actually typing against.
--- @param opts { only_off: boolean }|nil
function M.snippets(opts)
  opts = type(opts) == "table" and opts or {}
  local only_off = opts.only_off or false
  local ok, ls = pcall(require, "luasnip")
  if not ok then
    return vim.notify("NoetherVim: LuaSnip is not loaded yet; type in a buffer first",
      vim.log.levels.WARN)
  end
  local engine = require("noethervim.util.snippets")
  local store  = require("noethervim.util.snippet_store")
  local snipid = require("noethervim.util.snippet_id")

  -- Which list is responsible for a snippet being off, recomputed after every
  -- change so the marks stay true while the picker is open.
  local blamed = {}
  local function reblame()
    blamed = {}
    for _, rec in ipairs(store.records()) do
      blamed[table.concat({ rec.ft, rec.owner, rec.file, rec.trigger }, "\0")] =
        rec.source
    end
  end
  reblame()

  -- `ls.get_snippets(nil, ...)` is keyed by filetype and covers every one that
  -- has loaded, which `ls.available()` does not: that is scoped to the current
  -- buffer, and a snippet you want to switch off is often in another filetype.
  local items = {}
  for _, kind in ipairs({ "snippets", "autosnippets" }) do
    for ft, list in pairs(ls.get_snippets(nil, { type = kind }) or {}) do
      for _, snip in ipairs(list) do
        -- Invalidated snippets are the husks a file reload leaves behind.
        -- Listing them would offer the reader a snippet that no longer fires.
        if not snip.invalidated then
          local idty = snipid.identity(snip, ft)
          local src  = ls.snippet_source.get(snip)
          local desc = snip.dscr and table.concat(snip.dscr, " ") or ""
          -- A pattern trigger is not a name. `([%s%a%(%)%[%]%{%}%$])00` says
          -- nothing; the snippet's own name does. Kept searchable by both.
          local pattern = engine.is_pattern_trigger(snip)
          local label   = snip.trigger
          if pattern then
            label = (snip.name and snip.name ~= "" and snip.name)
              or (desc ~= "" and desc)
              or snip.trigger
          end
          items[#items + 1] = {
            label    = label,
            pattern  = pattern,
            text     = table.concat(
              { ft, label, snip.trigger, desc, idty and idty.file or "" }, " "),
            file     = src and src.file or nil,
            pos      = src and src.line and { src.line, 0 } or nil,
            snip_id  = snip.id,
            ft       = ft,
            trigger  = snip.trigger,
            auto     = kind == "autosnippets",
            desc     = desc,
            owner    = idty and idty.owner or nil,
            rel      = idty and idty.file or nil,
            nameable = idty ~= nil,
          }
        end
      end
    end
  end
  if only_off then
    items = vim.tbl_filter(function(item)
      local snip = item.snip_id and ls.get_id_snippet(item.snip_id)
      return snip ~= nil and engine.state(snip) == "off"
    end, items)
    if #items == 0 then
      return vim.notify("NoetherVim: no snippets are switched off", vim.log.levels.INFO)
    end
  end
  if #items == 0 then
    return vim.notify("NoetherVim: no snippets are loaded for this buffer's filetype",
      vim.log.levels.WARN)
  end
  -- Literal triggers first within a filetype. Sorted purely alphabetically
  -- the list opens on a wall of regex, since `(` sorts before every letter.
  table.sort(items, function(a, b)
    if a.ft ~= b.ft then return a.ft < b.ft end
    if a.pattern ~= b.pattern then return b.pattern end
    return a.label:lower() < b.label:lower()
  end)

  local function live(item)
    return item.snip_id and ls.get_id_snippet(item.snip_id) or nil
  end

  --- What to show in the left-hand column, and why it differs from default.
  local function mark(item)
    local snip = live(item)
    if not snip then return { "  gone   ", "Comment" } end
    local state = engine.state(snip)
    if state == "shipped_off" then
      return { "  hidden ", "Comment" }
    end
    if state == "on" then
      return { "  on     ", "DiagnosticOk" }
    end
    local why = blamed[table.concat(
      { item.ft, item.owner or "", item.rel or "", item.trigger }, "\0")]
    if why == "config" then return { "  blocked", "DiagnosticWarn" } end
    if why == "toggle" then return { "  off    ", "DiagnosticWarn" } end
    -- Off, but nothing remembers it: a snippet with no recorded source.
    return { "  session", "DiagnosticHint" }
  end

  --- Open a snippet where it is defined.
  ---
  --- Not `confirm_readonly`: that one is for browsing distribution source and
  --- only ever makes a file editable when it sits in the dev tree, so it would
  --- open your own snippets read-only. The rule here is :LuaSnipEdit's, which
  --- is about who owns the file: writing into a plugin's tree is what needs
  --- guarding, because the next :Lazy update discards it.
  local function confirm_snippet(picker, item)
    picker:close()
    if not item or not item.file then
      return
    end
    local owner = snipid.owner(item.file)
    local plugin_owned = owner ~= "config" and owner ~= "absolute"
    if plugin_owned then
      vim.cmd("view " .. vim.fn.fnameescape(item.file))
      vim.bo.readonly = true
      vim.bo.modifiable = false
    else
      vim.cmd("edit " .. vim.fn.fnameescape(item.file))
    end
    if item.pos and item.pos[1] and item.pos[1] > 0 then
      pcall(vim.api.nvim_win_set_cursor, 0, { item.pos[1], item.pos[2] or 0 })
      vim.cmd("norm! zzzv")
    end
  end

  local function apply_to_selection(picker, want)
    local chosen = picker:selected({ fallback = true })
    local unnamed = 0
    for _, item in ipairs(chosen) do
      local snip = live(item)
      if snip then
        local named = store.set(snip, item.ft, want)
        if not named then unnamed = unnamed + 1 end
      end
    end
    reblame()
    -- `force`, or `update()` leaves the list clean and render() returns early,
    -- so the marks would not change and the key would look like it did nothing.
    picker.list:update({ force = true })
    local changed = #chosen - unnamed
    if changed > 0 then
      vim.notify(("%d snippet%s switched %s"):format(
        changed, changed == 1 and "" or "s", want))
    end
    if unnamed > 0 then
      vim.notify(
        ("%d snippet%s switched %s for this session only: LuaSnip recorded no\n"
          .. "source for them, so there is no stable name to remember.")
          :format(unnamed, unnamed == 1 and "" or "s", want),
        vim.log.levels.WARN)
    end
  end

  Snacks.picker({
    title   = only_off and "NoetherVim Snippets (switched off)" or "NoetherVim Snippets",
    items   = items,
    preview = "file",
    confirm = confirm_snippet,
    format  = function(item)
      local ret = {} ---@type snacks.picker.Highlight[]
      ret[#ret + 1] = mark(item)
      ret[#ret + 1] = { string.format(" %-10s", item.ft), "SnacksPickerLabel" }
      local label = item.label
      if #label > 22 then label = label:sub(1, 21) .. "…" end
      ret[#ret + 1] = { string.format("%-23s", label),
        item.pattern and "Special" or nil }
      ret[#ret + 1] = { item.auto and "auto " or "     ", "Comment" }
      if item.desc ~= "" then
        ret[#ret + 1] = { item.desc, "Comment" }
      else
        ret[#ret + 1] = { item.rel or "no source recorded", "NonText" }
      end
      return ret
    end,
    actions = {
      disable_snippet = function(picker) apply_to_selection(picker, "off") end,
      enable_snippet  = function(picker) apply_to_selection(picker, "on") end,
      -- The durable list lives in the reader's own config, which nothing here
      -- rewrites, so the entry is handed over to paste rather than applied.
      only_off_toggle = function(picker)
        picker:close()
        M.snippets({ only_off = not only_off })
      end,
      copy_config_entry = function(picker)
        local lines = {}
        for _, item in ipairs(picker:selected({ fallback = true })) do
          if item.nameable then
            lines[#lines + 1] = ("  { ft = %q, trigger = %q, owner = %q, file = %q },")
              :format(item.ft, item.trigger, item.owner, item.rel)
          end
        end
        if #lines == 0 then
          return vim.notify(
            "NoetherVim: no source recorded for that snippet, so it cannot be\n"
              .. "named in user/config.lua",
            vim.log.levels.WARN)
        end
        local text = table.concat(lines, "\n")
        vim.fn.setreg("+", text)
        vim.fn.setreg('"', text)
        vim.notify(("Copied %d entr%s for snippets_disabled in user/config.lua")
          :format(#lines, #lines == 1 and "y" or "ies"))
      end,
    },
    win = {
      input = {
        footer     = hint_footer({
          { "<cr>", "open" }, { "<c-x>", "off" }, { "<c-y>", "on" },
          { "<c-o>", "copy" }, { "<a-o>", only_off and "all" or "only off" },
        }),
        footer_pos = "center",
        keys = {
          ["<CR>"]  = { "confirm",           mode = { "i", "n" }, desc = "open the snippet's source (readonly)" },
          ["<C-x>"] = { "disable_snippet",   mode = { "i", "n" }, desc = "switch snippet off" },
          ["<C-y>"] = { "enable_snippet",    mode = { "i", "n" }, desc = "switch snippet on" },
          ["<C-o>"] = { "copy_config_entry", mode = { "i", "n" }, desc = "copy a user/config.lua entry" },
          ["<A-o>"] = { "only_off_toggle",   mode = { "i", "n" }, desc = "show only switched-off snippets" },
        },
      },
      list = {
        keys = {
          ["<CR>"]  = { "confirm",           desc = "open the snippet's source (readonly)" },
          ["<C-x>"] = { "disable_snippet",   desc = "switch snippet off" },
          ["<C-y>"] = { "enable_snippet",    desc = "switch snippet on" },
          ["<C-o>"] = { "copy_config_entry", desc = "copy a user/config.lua entry" },
          ["<A-o>"] = { "only_off_toggle",   desc = "show only switched-off snippets" },
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
      write_template = function(picker)
        local item = picker:current()
        if not item or not item.src or not item.dest then return end
        picker:close()
        require("noethervim.util.templates").write(item.src, item.dest)
      end,
    },
    win = {
      input = {
        footer     = hint_footer({ { "<cr>", "open" }, { "<c-y>", "write" } }),
        footer_pos = "center",
        keys = {
          ["<CR>"]  = { "confirm",        mode = { "i", "n" }, desc = "open template (readonly)" },
          ["<C-y>"] = { "write_template", mode = { "i", "n" }, desc = "write template into lua/user/" },
        },
      },
      list = {
        keys = {
          ["<CR>"]  = { "confirm",        desc = "open template (readonly)" },
          ["<C-y>"] = { "write_template", desc = "write template into lua/user/" },
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
    table.insert(lines, "Sourced from lua/user/: " .. table.concat(nv._user_modules, ", "))
  elseif nv._user_loaded then
    table.insert(lines, "No hook files in lua/user/.")
  end

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "NoetherVim" })
end

-- ── Keymap source helpers ────────────────────────────────────────
--
-- Source attribution, line location, and jump-to-definition all live in
-- `noethervim.util.keymap_source`. This module only consumes them: the
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

--- Jump to the source definition of a keymap. Delegates to
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

--- The line of yours that deletes `lhs`: a `keymap.del` naming it in a Lua
--- file under your config directory.
---@param lhs string resolved lhs
---@return string? file, integer? line
local function deletion_site(lhs)
  local forms = require("noethervim.util.keymap_forms").source_forms(lhs)
  local cfg = vim.fn.stdpath("config")
  local files = {}
  for _, glob in ipairs({ "lua/user/**/*.lua", "plugin/**/*.lua", "after/**/*.lua" }) do
    vim.list_extend(files, vim.fn.globpath(cfg, glob, false, true))
  end
  for _, file in ipairs(files) do
    for n, line in ipairs(vim.fn.readfile(file)) do
      if line:find("keymap.del", 1, true) then
        for _, f in ipairs(forms) do
          if line:find('"' .. f .. '"', 1, true) or line:find("'" .. f .. "'", 1, true) then
            return file, n
          end
        end
      end
    end
  end
end

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
  local yours  = require("noethervim.user_layer").is_yours

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

    -- Between the two snapshots the other start plugins are configured as
    -- well as your files; only a mapping one of your files made is yours.
    if a and not b then
      if not yours(a.sid) then goto continue end
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
      if changed and yours(a.sid) then
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

  -- Refine [CORE] → [USER]: a key is user-owned if either its recorded
  -- source (util.keymap_source.lookup) or the lazy-handler attribution
  -- (lazy `keys = {...}` spec file) places its definition under
  -- `lua/user/`.
  local udir_norm = vim.fs.normalize(user_dir())
  local registry = require("noethervim.util.keymap_source")
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

  -- Live merge. The snapshots are taken inside setup(), so every keymap
  -- registered later is invisible to the diff above: plugin `config` and
  -- `opts` bodies, ftplugins, and anything a lazy-loaded plugin sets when
  -- it finally loads. Walk the live keymap tables and add what is
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
  -- them. Origin is the bundle stem for bundle-owned keys so an opt-in
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

    if item.tag == "[DELETED]" then
      local file, line = deletion_site(item.lhs)
      if file then return { filename = file, lnum = line, col = 1, text = text } end
    end

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
        { "<c-x>", "plugins" },
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
      -- A deleted key lands on the line of yours that deletes it, when one
      -- can be found; NoetherVim's definition otherwise.
      if item.tag == "[DELETED]" then
        local file, line = deletion_site(item.lhs)
        if file then
          vim.cmd("edit " .. vim.fn.fnameescape(file))
          vim.api.nvim_win_set_cursor(0, { line, 0 })
          return
        end
      end
      -- jump_to_keymap consults the registry first, so USER/OVERRIDE
      -- items land in the exact user file+line that registered them --
      -- not just user/keymaps.lua.
      M.jump_to_keymap(item.mode, item.lhs,
        { source = item.source, origin = item.origin })
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

  local yours = require("noethervim.user_layer").is_yours
  for name, default_val in pairs(before) do
    local current_val = after[name]
    local sid = vim.api.nvim_get_option_info2(name, { scope = "global" }).last_set_sid
    local tag = (current_val ~= default_val and yours(sid)) and "[OVERRIDE]" or "[CORE]"
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
      footer     = hint_footer({ { "<cr>", "source" } }),
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
---   REG   — a row, a write through noethervim.default, or a mapping made by a sourced file
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
  local registry = require("noethervim.util.keymap_source")

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

--- Open upstream and the user override side by side, in diff mode.
---
--- `diffthis` on both windows is the point of the command: without it this
--- is two files next to each other and the reader does the comparing, which
--- is exactly the work `:NoetherVim diff` exists to save. Falls back to a
--- lone upstream window when there is no override to compare against.
---
--- Upstream opens readonly outside dev mode, matching every other picker
--- that surfaces distribution source.
---@param upstream string
---@param user_file string?
local function open_pair(upstream, user_file)
  if vim.g.noethervim_dev then
    vim.cmd("edit " .. vim.fn.fnameescape(upstream))
  else
    vim.cmd("view " .. vim.fn.fnameescape(upstream))
    vim.bo.readonly = true
    vim.bo.modifiable = false
  end
  if not user_file then return end

  vim.cmd("diffthis")
  vim.cmd("vsplit " .. vim.fn.fnameescape(user_file))
  vim.cmd("diffthis")
end

--- Open a side-by-side diff for a specific module (direct call path).
--- Used by :NoetherVim diff <name> when a name is provided.
local function open_diff_split(module_name)
  local root = effective_root()
  if not root then return vim.notify("NoetherVim: cannot locate source directory", vim.log.levels.ERROR) end

  local upstream = nil
  local candidates = {
    root .. "/lua/noethervim/" .. module_name .. ".lua",
    root .. "/lua/noethervim/plugins/" .. module_name .. ".lua",
    root .. "/after/lsp/" .. module_name .. ".lua",
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

  local target = map_to_user_path(upstream)
  local user_file = target and vim.uv.fs_stat(target) and target or nil

  open_pair(upstream, user_file)
  if not user_file then
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
  local icons = require("noethervim.util.icons")

  local diff_cat_order = { Core = 1, Plugin = 2, Bundle = 3, LSP = 4 }
  -- Flat-scan groups (bundles are handled separately -- they live under
  -- category subdirectories, not directly in bundles/).
  local groups = {
    { cat = "Core",   dir = root .. "/lua/noethervim" },
    { cat = "Plugin", dir = root .. "/lua/noethervim/plugins" },
    { cat = "LSP",    dir = root .. "/after/lsp" },
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

  -- Only files a file of yours can change are listed.
  local function add_item(cat, name, upstream_path, is_enabled)
    local target = map_to_user_path(upstream_path)
    if not target then return end
    local user_path = vim.uv.fs_stat(target) and target or nil
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
      add_item(group.cat, mod, vim.fs.joinpath(group.dir, mod .. ".lua"), true)
    end
  end

  -- Bundles (category subdirectories)
  for _, entry in ipairs(require("noethervim.util").scan_bundles(root .. "/lua/noethervim/bundles")) do
    add_item("Bundle", entry.name, entry.path, enabled_bundles[entry.name] or false)
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
      open_pair(item.upstream, item.user_file)
      if not item.user_file then
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
    root .. "/after/lsp",
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
      footer     = hint_footer({ { "<cr>", "source" } }),
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

--- Every distinct `owner/repo` string in a spec file, in source order.
---
--- Used to seed a plugin or bundle override with the keys that actually
--- merge. The quotes are part of the pattern, so a path like
--- `"lua/user/plugins"` cannot match -- only a string whose entire contents
--- are two slash-separated segments.
---@param path string
---@return string[]
local function spec_repos(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok or type(lines) ~= "table" then return {} end
  local out, seen = {}, {}
  for _, line in ipairs(lines) do
    for repo in line:gmatch('"([%w%-%._]+/[%w%-%._]+)"') do
      if not seen[repo] then
        seen[repo] = true
        out[#out + 1] = repo
      end
    end
  end
  return out
end

--- The distro's option defaults in `path` (options.lua writes them as
--- `opt.name = value` and `append("name", value)`), as commented lines for
--- your options file.
---@param path string
---@return string[]
local function option_lines(path)
  local out = {}
  for _, line in ipairs(vim.fn.readfile(path)) do
    local code = line:gsub("%s*%-%-.*$", "")
    local name, value = code:match("^%s*opt%.([%w_]+)%s*=%s*(.-)%s*$")
    if name then
      out[#out + 1] = ("-- vim.o.%s = %s"):format(name, value)
    else
      local aname, avalue = code:match('^%s*append%(%s*"([%w_]+)"%s*,%s*(.-)%)%s*$')
      if aname then out[#out + 1] = ("-- vim.opt.%s:append(%s)"):format(aname, avalue) end
    end
  end
  return out
end

--- `vim.keymap.del` lines for every key NoetherVim mapped from `path`.
---@param path string
---@return string[]
local function key_del_lines(path)
  local tail = vim.fn.fnamemodify(path, ":~")
  local out, seen = {}, {}
  for _, rec in pairs(require("noethervim.default").owned.map) do
    if type(rec.source) == "string" and vim.startswith(rec.source, tail .. ":") then
      local line = ('-- vim.keymap.del(%q, %q)'):format(rec.mode, rec.name)
      if not seen[line] then
        seen[line] = true
        out[#out + 1] = line
      end
    end
  end
  table.sort(out)
  return out
end

--- What the writing profile sets, as `vim.opt_local` lines for one filetype.
local PROFILE_LINES = {
  writing = {
    "-- vim.opt_local.wrap = true",
    "-- vim.opt_local.linebreak = true",
    "-- vim.opt_local.spell = true",
    "-- vim.opt_local.conceallevel = 2",
    "-- vim.opt_local.list = false",
    "-- vim.opt_local.formatoptions:append(\"t\")",
  },
  code = {
    "-- vim.opt_local.list = true",
  },
}

--- Lines to add to the file of yours for `rel`, given what it already holds.
---@param rel string            upstream path, relative to the distribution root
---@param category string
---@param upstream string       absolute path to the upstream file
---@param existing string[]     the file's current lines, empty when new
---@param ft? string            the filetype, for a profile
---@return string[]
local function seed_lines(rel, category, upstream, existing, ft)
  local marker = "-- NoetherVim's " .. (ft and (ft .. " profile") or rel) .. ":"
  for _, line in ipairs(existing) do
    if line == marker then return {} end
  end
  local lines = {}
  if category == "plugin" or category == "bundle" then
    if #existing > 0 then return {} end
    lines = { "-- Override: " .. rel,
      "-- Specs merge with the upstream file by repo string.",
      "-- See :help noethervim-user-plugins", "return {" }
    local repos = spec_repos(upstream)
    if #repos == 0 then
      lines[#lines + 1] = "  -- { \"owner/repo\", opts = {} },"
    else
      for _, repo in ipairs(repos) do
        lines[#lines + 1] = ('  -- { "%s", opts = {} },'):format(repo)
      end
    end
    lines[#lines + 1] = "}"
    return lines
  end
  if category == "lsp" then
    if #existing > 0 then return {} end
    lines = { "-- Merged over NoetherVim's " .. rel .. "; a key you set here wins.",
      "-- To start from lspconfig's settings alone instead, set",
      "-- `lsp = { " .. vim.fn.fnamemodify(rel, ":t:r") .. " = false }` in lua/user/config.lua." }
    for _, line in ipairs(vim.fn.readfile(upstream)) do
      if not line:find("lsp_off(", 1, true) then lines[#lines + 1] = line end
    end
    return lines
  end
  lines = { marker }
  if category == "core" and rel:match("options%.lua$") then
    vim.list_extend(lines, option_lines(upstream))
  elseif category == "keys" then
    lines[#lines + 1] = "-- Remove any of them here; to drop every key that changes a Vim key,"
    lines[#lines + 1] = "-- set `keymaps = { remaps = false }` in lua/user/config.lua."
    vim.list_extend(lines, key_del_lines(upstream))
  elseif category == "profile" then
    local class = require("noethervim.profiles").class(ft or "")
    lines[#lines + 1] = "-- A value set here is kept; see :help noethervim-filetype-profiles"
    vim.list_extend(lines, PROFILE_LINES[class or "writing"])
  elseif category == "ftplugin" then
    lines[#lines + 1] = "-- Runs after NoetherVim's " .. rel .. "."
  else
    lines[#lines + 1] = "-- See " .. rel .. " for what NoetherVim sets."
  end
  return lines
end

--- Open the file of yours that changes the current distro file, creating
--- or extending it with a commented starting point.
---
--- Everything written here is a starting point, not a format: the baseline
--- used by the drift check lives in NoetherVim's state directory, so the file
--- can be rewritten from scratch without breaking anything.
function M.override()
  local bufpath = vim.api.nvim_buf_get_name(0)
  if bufpath == "" then
    return vim.notify("NoetherVim: current buffer has no file", vim.log.levels.WARN)
  end

  local user_path, category = map_to_user_path(bufpath)
  if not user_path then
    return vim.notify("NoetherVim: nothing of yours stands in for this file; "
      .. "lua/user/config.lua or after/plugin/ change what it does", vim.log.levels.WARN)
  end

  local root = vim.fs.normalize(effective_root())
  local rel  = vim.fs.normalize(bufpath):sub(#root + 2)

  ---@cast category string
  local function finish(path, ft)
    local is_new = not vim.uv.fs_stat(path)
    local existing = is_new and {} or vim.fn.readfile(path)
    local add = seed_lines(rel, category, bufpath, existing, ft)
    local shown = vim.fn.fnamemodify(path, ":~")

    local function open()
      -- Record what this override is being written against. Re-running the
      -- command re-baselines it, which is how you clear a drift warning once
      -- you have read the upstream change.
      require("noethervim.util.override_base").record(path, rel, bufpath)
      vim.cmd("vsplit " .. vim.fn.fnameescape(path))
    end
    if #add == 0 then return open() end

    -- Nothing is written into your config without your go-ahead: the
    -- addition is shown as a diff first.
    local new = vim.deepcopy(existing)
    if #existing > 0 and existing[#existing] ~= "" then table.insert(new, "") end
    vim.list_extend(new, add)
    local before = #existing > 0 and (table.concat(existing, "\n") .. "\n") or ""
    local body = vim.diff(before, table.concat(new, "\n") .. "\n", { result_type = "unified", ctxlen = 3 })
    require("noethervim.util.diff_modal").confirm({
      title   = (is_new and "Create " or "Add to ") .. shown,
      diff    = ("--- %s\n+++ %s\n%s"):format(shown, shown, body or ""),
      on_done = function(accepted)
        if not accepted then
          vim.notify("NoetherVim: " .. shown .. " left as it was", vim.log.levels.INFO)
          if not is_new then vim.schedule(open) end
          return
        end
        vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
        vim.fn.writefile(new, path)
        vim.notify(("NoetherVim: %s %s"):format(is_new and "created" or "added to", shown), vim.log.levels.INFO)
        vim.schedule(open)
      end,
    })
  end

  if category == "profile" then
    vim.ui.input({ prompt = "Filetype: " }, function(ft)
      if ft and ft ~= "" then finish(user_path .. ft .. ".lua", ft) end
    end)
  else
    finish(user_path)
  end
end

-- ── Command dispatcher ───────────────────────────────────────────

-- One-liner per subcommand. Surfaced in the no-arg help printout.
local subcommand_descriptions = {
  files             = "Browse NoetherVim source files",
  grep              = "Live grep over NoetherVim source",
  user              = "Browse files in lua/user/",
  plugins           = "Browse installed plugins",
  bundles           = "Bundle picker (<C-y> enable, <C-x> disable)",
  snippets          = "Snippet picker (<C-y> on, <C-x> off, <A-o> only off); `snippets off` opens filtered",
  templates         = "Write user-config templates into lua/user/ (<C-y>)",
  ["keymap-guide"]  = "Keymap namespace reference buffer",
  status            = "Show which user override files are loaded",
  diff              = "Compare overrides vs distro defaults (keymaps / options / autocmds / module)",
  override          = "Open the file of yours that changes the current distro file",
  ["debug-keymaps"] = "Trace where each keymap was registered",
  where             = "Who set a key, option, command or plugin, and the line that changes it",
}

--- Each entry receives (arg, bang), so the dispatcher needs no special case
--- for a subcommand that reads the bang.
---@type table<string, fun(arg: string?, bang: boolean?)>
local subcommands = {
  files             = M.files,
  grep              = M.grep,
  user              = M.user,
  plugins           = M.plugins,
  bundles           = M.bundles,
  snippets          = function(arg) M.snippets({ only_off = arg == "off" }) end,
  templates         = M.templates,
  ["keymap-guide"]  = function() require("noethervim.guide").open() end,
  status            = M.status,
  diff              = function(args) M.diff(args) end,
  override          = M.override,
  ["debug-keymaps"] = function() M.debug_keymaps() end,
  where             = function(arg) require("noethervim.inspect.where").run(arg) end,
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

--- Run a `:NoetherVim` subcommand.
---
--- Exported rather than kept inside `setup()` so the command can be created
--- before this module is loaded. Registering it late left `:NoetherVim` as a
--- bare prefix of `:NoetherVimHighlightUnderCursor`, which takes no
--- arguments, so an early `:NoetherVim bundles` failed with a trailing
--- characters error instead of running.
--- @param opts table the table Neovim hands a user-command callback
function M.dispatch(opts)
  local args = vim.split(opts.args, "%s+", { trimempty = true })
  local cmd  = args[1]
  if not cmd then
    print_help()
    return
  end
  local fn = subcommands[cmd]
  if fn then
    fn(args[2], opts.bang)
  else
    vim.notify("NoetherVim: unknown subcommand '" .. cmd .. "'", vim.log.levels.ERROR)
  end
end

--- @param cmdline string
--- @return string[]
function M.complete(_, cmdline)
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
  -- `where` takes keys too, which do not complete; offer the rest.
  if args[2] == "where" and #args == 3 then
    local names = vim.tbl_keys(vim.api.nvim_get_commands({}))
    vim.list_extend(names, vim.tbl_keys(require("lazy.core.config").plugins))
    vim.list_extend(names, vim.fn.getcompletion(args[3], "option"))
    table.sort(names)
    return vim.tbl_filter(function(s)
      return s:find(args[3], 1, true) == 1
    end, names)
  end
  return {}
end

return M
