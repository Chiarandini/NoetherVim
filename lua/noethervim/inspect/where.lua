--- `:NoetherVim where <name>`: who set a key, an option, a command or a
--- plugin, what NoetherVim did about a value of yours there, and the line
--- that changes it. A name that is several of these (`ai` is a key and
--- 'autoindent') gets a report for each.

local M = {}

local MODES = { "n", "x", "s", "o", "i", "c", "t" }

local function real(path)
  return vim.fs.normalize(vim.uv.fs_realpath(path) or path)
end

local roots = {
  { "yours", real(vim.fn.stdpath("config")) },
  { "NoetherVim", real((debug.getinfo(1, "S").source:sub(2):gsub("/lua/noethervim/inspect/where%.lua$", ""))) },
  { "plugin", real(vim.fn.stdpath("data") .. "/lazy") },
  { "Neovim", vim.env.VIMRUNTIME and real(vim.env.VIMRUNTIME) or nil },
}

--- Who a file belongs to, and the file shortened for display.
---@param path string
---@return string who, string shown
local function owner_of(path)
  local p = real(path)
  for _, root in ipairs(roots) do
    if root[2] and vim.startswith(p, root[2] .. "/") then
      local rest = p:sub(#root[2] + 2)
      if root[1] == "plugin" then return "plugin " .. rest:match("^[^/]+"), vim.fn.fnamemodify(p, ":~") end
      return root[1], vim.fn.fnamemodify(p, ":~")
    end
  end
  return "another source", vim.fn.fnamemodify(p, ":~")
end

--- Where a mapping was made: the file of its Lua callback, else its script.
---@param m table maparg() dict
---@return string who, string where
local function origin(m)
  if m.callback then
    local info = debug.getinfo(m.callback, "S")
    if info.source:sub(1, 1) == "@" then
      local who, shown = owner_of(info.source:sub(2))
      return who, shown .. ":" .. info.linedefined
    end
  end
  if m.sid and m.sid > 0 then
    local script = vim.fn.getscriptinfo({ sid = m.sid })[1]
    if script then return owner_of(script.name) end
  end
  if m.sid == -8 then return "Neovim or Lua", "no file recorded" end
  return "unknown", "sid " .. tostring(m.sid)
end

--- Lazy specs that declare `lhs` in `mode` through `keys`.
---@return { plugin: table, key: table }[]
local function lazy_keys(lhs, mode)
  local out = {}
  local id = vim.keycode(lhs)
  for _, plugin in pairs(require("lazy.core.config").plugins) do
    for _, key in pairs(plugin._.handlers and plugin._.handlers.keys or {}) do
      local modes = type(key.mode) == "table" and key.mode or { key.mode or "n" }
      local hit = false
      for _, m in ipairs(modes) do
        if m == mode or (m == "v" and (mode == "x" or mode == "s")) then hit = true end
      end
      if hit and vim.keycode(key.lhs) == id then table.insert(out, { plugin = plugin, key = key }) end
    end
  end
  return out
end

---@param lines string[]
local function report(lines)
  local chunks = {}
  for i, line in ipairs(lines) do
    table.insert(chunks, { line .. (i < #lines and "\n" or "") })
  end
  vim.api.nvim_echo(chunks, true, {})
end

--- What is known about `lhs` in every mode it is mapped or was mapped in,
--- or nil when it is not a key anything maps.
---@param lhs string
---@return string[]?
function M.key(lhs)
  local default = require("noethervim.default")
  local id = vim.keycode(lhs)
  local lines = { lhs }
  for _, mode in ipairs(MODES) do
    local m = vim.fn.maparg(lhs, mode, false, true)
    local yielded = vim.tbl_filter(function(r)
      return r.kind == "map" and r.mode == mode and vim.keycode(r.name) == id
    end, default.yielded)
    local owned = default.owned.map[mode .. " " .. id]
    local specs = lazy_keys(lhs, mode)
    if not vim.tbl_isempty(m) or #yielded > 0 or #specs > 0 then
      local active = "(nothing)"
      local who = nil
      -- A NoetherVim mapping carries NoetherVim's script id; one made over
      -- it later (yours) does not.
      local ours = owned and not vim.tbl_isempty(m) and default.class(m.sid) == "distro"
      if not vim.tbl_isempty(m) then
        local where
        who, where = origin(m)
        if ours then
          who = "NoetherVim"
          where = owned.source .. (owned.plugin and (", " .. owned.plugin) or "")
        end
        active = ("%s: %s%s%s"):format(who, where,
          m.desc and m.desc ~= "" and (' "' .. m.desc .. '"') or "",
          m.buffer == 1 and " (this buffer only)" or "")
      end
      table.insert(lines, ("  %s  active   %s"):format(mode, active))
      if owned and not ours then
        table.insert(lines, ("     replaced NoetherVim, %s%s%s, by a mapping made later"):format(
          owned.plugin and (owned.plugin .. ", ") or "", owned.source, owned.desc and (' "' .. owned.desc .. '"') or ""))
      end
      for _, r in ipairs(yielded) do
        table.insert(lines, ("     %s  NoetherVim, %s%s: %s%s"):format(
          r.off and "off    " or "yielded",
          r.plugin and (r.plugin .. ", ") or "", r.source, r.desc and ('"' .. r.desc .. '" ') or "",
          r.off and ("skipped: " .. r.by)
            or ("skipped because yours was there first" .. (r.by and (" (" .. r.by .. ")") or ""))))
        if r.off and r.by:find("false } on", 1, true) then
          table.insert(lines, "     undo     remove that `{ lhs, false }` from your spec for "
            .. (r.plugin or "the plugin") .. " and restart")
        elseif r.off and r.by:find("set `", 1, true) then
          table.insert(lines, "     undo     remove the set from `keymaps` in lua/user/config.lua and restart")
        end
      end
      for _, s in ipairs(specs) do
        local url = s.plugin[1] or s.plugin.name
        local note = s.key.desc and (' "' .. s.key.desc .. '"') or ""
        table.insert(lines, ("     lazy     %s declares it in `keys`%s"):format(s.plugin.name, note))
        table.insert(lines, "     change   lazy maps it again whenever " .. s.plugin.name
          .. " loads, so a change in lua/user/keymaps.lua does not hold; in lua/user/plugins/ write")
        table.insert(lines, ('                { "%s", keys = { { "%s", <your rhs> } } }   to replace it'):format(url, lhs))
        table.insert(lines, ('                { "%s", keys = { { "%s", false } } }   to remove it'):format(url, lhs))
      end
      if (#yielded > 0 or (owned and not ours)) and who == "yours" then
        table.insert(lines, "     undo     remove your mapping and restart, and NoetherVim's comes back")
      end
    end
  end
  if #lines == 1 then return nil end
  return lines
end

--- Who set the value behind script id `sid`, for a report line.
---@param sid integer
---@return string
local function setter(sid)
  local default = require("noethervim.default")
  if sid == 0 then return "Neovim's default" end
  local class = default.class(sid)
  if class == "none" then return "Lua, with no file recorded" end
  if class == "distro" then return "NoetherVim: " .. default.describe(sid) end
  if class == "runtime" then return "Neovim: " .. default.describe(sid) end
  local info = sid > 0 and vim.fn.getscriptinfo({ sid = sid })[1]
  if not info then return default.describe(sid) end
  if real(info.name) == real(vim.fn.stdpath("config") .. "/init.lua") then
    -- lazy.nvim configures plugins while init.lua runs, under its id.
    return "init.lua: yours, or a plugin lazy.nvim set up from it"
  end
  local who, shown = owner_of(info.name)
  return who .. ": " .. shown
end

local function value(v)
  return type(v) == "string" and ("%q"):format(v) or tostring(v)
end

--- What is known about option `name` here, or nil when it is not one.
---@param name string
---@return string[]?
function M.option(name)
  local ok, info = pcall(vim.api.nvim_get_option_info2, name, {})
  if not ok then return nil end
  name = info.name
  local default = require("noethervim.default")
  local profiles = require("noethervim.profiles")
  local buf = vim.api.nvim_get_current_buf()
  local ft = vim.bo[buf].filetype
  local here = info.scope == "buf" and ("buffer " .. buf) or info.scope == "win"
    and ("window " .. vim.api.nvim_get_current_win()) or nil
  local lines = { ("%s  (option%s)"):format(name, here and (", " .. here .. (ft ~= "" and (", " .. ft) or "")) or "") }

  local global = vim.api.nvim_get_option_info2(name, { scope = "global" })
  local gby = setter(global.last_set_sid)
  local owned = default.owned.o[name]
  if owned and default.class(global.last_set_sid) == "distro" then
    -- A late write carries the broker's id; the record has the real site.
    gby = "NoetherVim: " .. owned.source .. (owned.plugin and (", when " .. owned.plugin .. " loaded") or "")
  end
  table.insert(lines, ("  global   %s  %s"):format(
    value(vim.api.nvim_get_option_value(name, { scope = "global" })), gby))
  local class = profiles.of(buf)
  local managed = class and vim.tbl_contains(profiles.MANAGED, name)
  if here then
    local scope = info.scope == "buf" and { buf = buf } or { win = vim.api.nvim_get_current_win() }
    local l = vim.api.nvim_get_option_info2(name, scope)
    local by = setter(l.last_set_sid)
    if managed and default.class(l.last_set_sid) == "distro" then by = "NoetherVim: the " .. class .. " profile" end
    table.insert(lines, ("  here     %s  %s"):format(value(vim.api.nvim_get_option_value(name, scope)), by))
    local claim = default.claims(buf)[name]
    if managed and claim then
      table.insert(lines, ("  profile  the %s profile leaves it alone in this buffer: yours (%s)"):format(class, claim))
    end
  end
  for _, r in ipairs(default.yielded) do
    if r.kind == "o" and r.name == name then
      table.insert(lines, ("  yielded  NoetherVim, %s%s: skipped because yours was there first (%s)"):format(
        r.plugin and (r.plugin .. ", ") or "", r.source, r.by or "?"))
    end
  end

  local current = here and vim.api.nvim_get_option_value(name, info.scope == "buf" and { buf = buf } or {})
    or vim.api.nvim_get_option_value(name, { scope = "global" })
  table.insert(lines, ("  change   everywhere: lua/user/options.lua   vim.o.%s = %s"):format(name, value(current)))
  if here and ft ~= "" then
    table.insert(lines, ("           %s only: after/ftplugin/%s.lua   vim.opt_local.%s = %s"):format(
      ft, ft, name, value(current)))
    if class == "writing" and (name == "wrap" or name == "linebreak") then
      table.insert(lines, "           prose wraps whatever your global says; set it per filetype instead")
    end
  end
  return lines
end

--- Where a Lua function was defined, as (who, "file:line").
local function defined(fn)
  local info = debug.getinfo(fn, "S")
  if info.source:sub(1, 1) ~= "@" then return nil end
  local who, shown = owner_of(info.source:sub(2))
  return who, shown .. ":" .. info.linedefined, info.source:sub(2)
end

--- The lazy.nvim plugin a `cmd` trigger named `name` loads, if any.
local function cmd_trigger(name)
  for _, plugin in pairs(require("lazy.core.config").plugins) do
    if plugin._.handlers and plugin._.handlers.cmd and plugin._.handlers.cmd[name] then return plugin end
  end
end

--- What is known about user command `name`, or nil when there is none.
---@param name string
---@return string[]?
function M.command(name)
  name = name:gsub("^:", "")
  local default = require("noethervim.default")
  local local_cmd = vim.api.nvim_buf_get_commands(0, {})[name]
  local cmd = local_cmd or vim.api.nvim_get_commands({})[name]
  local owned = default.owned.command[name]
  local yielded = vim.tbl_filter(function(r) return r.kind == "command" and r.name == name end, default.yielded)
  if not cmd and not owned and #yielded == 0 then return nil end
  local lines = { (":%s  (command)"):format(name) }
  local who
  if cmd then
    local where, file
    if type(cmd.callback) == "function" then who, where, file = defined(cmd.callback) end
    local trigger = cmd_trigger(name)
    if file and file:find("/lazy/core/handler/", 1, true) and trigger then
      who = "plugin " .. trigger.name
      table.insert(lines, ("  active   lazy.nvim: loads %s on first use"):format(trigger.name))
    else
      if not who then who, where = setter(cmd.script_id), nil end
      table.insert(lines, ("  active   %s%s%s"):format(who, where and (": " .. where) or "",
        local_cmd and " (this buffer only)" or ""))
    end
  end
  for _, r in ipairs(yielded) do
    table.insert(lines, ("  yielded  NoetherVim, %s%s: skipped because yours was there first (%s)"):format(
      r.plugin and (r.plugin .. ", ") or "", r.source, r.by or "?"))
  end
  if who == "yours" and #yielded > 0 then
    table.insert(lines, "  undo     remove yours and restart, and NoetherVim's comes back")
  elseif who == "NoetherVim" then
    table.insert(lines, ("  change   a :%s of yours in after/plugin/ replaces it; "
      .. "vim.api.nvim_del_user_command(%q) there removes it"):format(name, name))
  elseif who and who:find("^plugin ") then
    table.insert(lines, ("  change   it is %s's: see its docs, or switch the plugin off (:NoetherVim where %s)"):format(
      who:sub(8), who:sub(8)))
  end
  return lines
end

--- The lazy.nvim plugin `name` names: its name, its `owner/repo`, or its
--- name without a `.nvim`/`.vim`/`.lua` suffix, ignoring case.
---@return table? plugin, boolean? disabled
local function find_plugin(name)
  local config = require("lazy.core.config")
  local want = name:lower()
  for _, set in ipairs({ { config.plugins, false }, { config.spec.disabled or {}, true } }) do
    for pname, plugin in pairs(set[1]) do
      local bare = pname:lower():gsub("%.nvim$", ""):gsub("%.vim$", ""):gsub("%.lua$", "")
      if pname:lower() == want or (plugin[1] or ""):lower() == want or bare == want then
        return plugin, set[2]
      end
    end
  end
end

--- The spec files that declare `plugin`: NoetherVim's, enabled bundles',
--- and yours.
local function spec_files(plugin)
  local files = require("noethervim.util").plugin_spec_files()[plugin.name] or {}
  local modules = {}
  for _, mod in ipairs(require("lazy.core.config").spec.modules or {}) do modules[mod] = true end
  return vim.tbl_filter(function(file)
    local bundle = file:match("lua/(noethervim/bundles/.+)%.lua$")
    return not bundle or modules[bundle:gsub("/", ".")]
  end, files)
end

--- What is known about lazy.nvim plugin `name`, or nil when there is none.
---@param name string
---@return string[]?
function M.plugin(name)
  local plugin, disabled = find_plugin(name)
  if not plugin then return nil end
  local url = plugin[1] or plugin.dir or plugin.name
  local lines = { ("%s  (plugin %s)"):format(plugin.name, url) }
  if plugin.name == "NoetherVim" then
    table.insert(lines, "  host     the distribution itself: each plugin spec hands it its keys,")
    table.insert(lines, "           globals and startup code, and they go when that plugin is off")
    return lines
  end
  if disabled then
    table.insert(lines, "  off      enabled = false, so nothing NoetherVim attaches to it is set up either")
  elseif plugin._.cond == false then
    table.insert(lines, "  off      cond is false: installed, never loaded")
  elseif plugin._.loaded then
    local why = {}
    for k, v in pairs(plugin._.loaded) do
      if k ~= "time" then table.insert(why, k .. " " .. tostring(v)) end
    end
    table.sort(why)
    table.insert(lines, ("  loaded   by %s, in %.1f ms"):format(table.concat(why, ", "),
      (plugin._.loaded.time or 0) / 1e6))
  else
    local on = {}
    for _, kind in ipairs({ "event", "ft", "cmd", "keys" }) do
      local h = plugin._.handlers and plugin._.handlers[kind]
      if h and next(h) then
        local ids = vim.tbl_keys(h)
        table.sort(ids)
        table.insert(on, kind .. " " .. table.concat(ids, " "))
      end
    end
    table.insert(lines, "  waiting  loads on " .. (#on > 0 and table.concat(on, "; ") or "require() or a plugin that needs it"))
  end
  for _, file in ipairs(disabled and {} or spec_files(plugin)) do
    local who, shown = owner_of(file)
    table.insert(lines, ("  spec     %s: %s"):format(who, shown))
  end

  local default = require("noethervim.default")
  local rows, seen, off = 0, {}, 0
  for _, rec in pairs(default.owned.map) do
    if rec.plugin == plugin.name and not seen[rec] then seen[rec], rows = true, rows + 1 end
  end
  for _, rec in ipairs(default.yielded) do
    if rec.kind == "map" and rec.plugin == plugin.name then off = off + 1 end
  end
  if rows + off > 0 then
    table.insert(lines, ("  keys     %d NoetherVim key%s mapped%s; :NoetherVim diff keymaps lists them"):format(
      rows, rows == 1 and "" or "s", off > 0 and (", " .. off .. " off or yours") or ""))
  end
  -- No dots: lazy imports lua/user/plugins/<file> as a module name.
  local short = plugin.name:gsub("%.nvim$", ""):gsub("%.lua$", ""):gsub("%.", "-")
  if disabled then
    table.insert(lines, "  undo     remove `enabled = false` from your spec for it and restart")
  else
    table.insert(lines, ("  off      lua/user/plugins/%s.lua   { %q, enabled = false }"):format(short, url))
  end
  return lines
end

--- Print every report `name` has: as a key, an option, a command, a plugin.
---@param name? string
function M.run(name)
  if not name or name == "" then
    vim.notify("usage: :NoetherVim where <key|option|command|plugin>", vim.log.levels.WARN)
    return
  end
  local out = {}
  for _, of in ipairs({ M.key, M.option, M.command, M.plugin }) do
    local section = of(name)
    if section then
      if #out > 0 then table.insert(out, "") end
      vim.list_extend(out, section)
    end
  end
  if #out == 0 then
    out = { name, "  not a key, option, command or plugin anything set up" }
  end
  report(out)
end

return M
