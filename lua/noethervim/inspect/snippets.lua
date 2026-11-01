--- :NoetherVim snippets: every loaded snippet, on or off, and where it
--- came from.
---@diagnostic disable: undefined-doc-name

local Snacks = require("snacks")
local ui = require("noethervim.inspect.ui")
local confirm_readonly = ui.confirm_readonly
local hint_footer = ui.hint_footer

local M = {}

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
  local engine = require("noethervim.snippets.engine")
  local store  = require("noethervim.snippets.store")
  local snipid = require("noethervim.snippets.id")

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

return M
