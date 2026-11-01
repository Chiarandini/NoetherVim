--- :NoetherVim diff keymaps: every keymap NoetherVim or you are
--- responsible for, tagged by how it got there.
---@diagnostic disable: undefined-doc-name

local Snacks = require("snacks")
local ui = require("noethervim.inspect.ui")
local user_dir = ui.user_dir
local snapshots = ui.snapshots
local hint_footer = ui.hint_footer
local keymap_source = require("noethervim.inspect.source")
local same_mapping = keymap_source.same_mapping
local callback_file = keymap_source.callback_file
local find_lhs_line = keymap_source.find_lhs_line
local scan_project_for = keymap_source.scan_project_for
local _file_lines = keymap_source.file_lines

local M = {}

-- ── Keymap source helpers ────────────────────────────────────────
--
-- Source attribution, line location, and jump-to-definition all live in
-- `noethervim.inspect.source`. This module only consumes them: the
-- pickers below need the classifiers (`same_mapping`, `is_nvim_default`)
-- to build their item lists, and the file/line resolvers to turn an item
-- into a quickfix entry.

-- ── Comparison: Keymaps ─────────────────────────────

---@class noethervim.inspect.DiffKeymapOpts
---@field thirdparty? boolean  Also list keymaps owned by third-party
---                            plugins (marks.nvim, mini.ai, ...). Off by
---                            default; toggled from inside the picker.

--- The line of yours that deletes `lhs`: a `keymap.del` naming it in a Lua
--- file under your config directory.
---@param lhs string resolved lhs
---@return string? file, integer? line
local function deletion_site(lhs)
  local forms = require("noethervim.inspect.forms").source_forms(lhs)
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
  local key_sources, lazy_managed = require("noethervim.inspect.source").keymap_sources()

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
  local registry = require("noethervim.inspect.source")
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
      -- A few bundle names overflow (named-sessions); a bounded column
      -- beats a wide gutter that is blank on almost every row.
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
  -- cascade as `keymap_source.jump`, but resolving file+line from cached
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
      keymap_source.jump(item.mode, item.lhs,
        { source = item.source, origin = item.origin })
    end,
  })
end

return M
