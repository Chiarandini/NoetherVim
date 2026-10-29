--- `:NoetherVim where <key>`: who maps a key, what NoetherVim did about a
--- mapping of yours on it, and the line that changes it.

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

--- Print what is known about `lhs` in every mode it is mapped or was
--- mapped in.
---@param lhs? string
function M.key(lhs)
  if not lhs or lhs == "" then
    vim.notify("usage: :NoetherVim where <key>", vim.log.levels.WARN)
    return
  end
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
      if not vim.tbl_isempty(m) then
        local where
        who, where = origin(m)
        if owned then
          who = "NoetherVim"
          where = owned.source .. (owned.plugin and (", " .. owned.plugin .. "'s config") or "")
        end
        active = ("%s: %s%s%s"):format(who, where,
          m.desc and m.desc ~= "" and (' "' .. m.desc .. '"') or "",
          m.buffer == 1 and " (this buffer only)" or "")
      end
      table.insert(lines, ("  %s  active   %s"):format(mode, active))
      for _, r in ipairs(yielded) do
        table.insert(lines, ("     yielded  NoetherVim, %s%s: %s%s"):format(
          r.plugin and (r.plugin .. "'s config, ") or "", r.source, r.desc and ('"' .. r.desc .. '" ') or "",
          "skipped because yours was there first"))
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
      if #yielded > 0 and who == "yours" then
        table.insert(lines, "     undo     remove your mapping and restart, and NoetherVim's comes back")
      end
    end
  end
  if #lines == 1 then table.insert(lines, "  not mapped in any mode") end
  report(lines)
end

return M
