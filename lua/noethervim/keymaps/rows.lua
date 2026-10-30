--- Distro mappings as data ("rows").
---
--- A unit declares its keys in its anchor plugin's spec rather than in that
--- plugin's lazy.nvim `keys`:
---
---   specs = { { "NoetherVim", optional = true, opts = { rows = {
---     { "L", peek, desc = "peek fold", owner = "nvim-ufo" },
---   } } } }
---
--- setup() maps every row once, at startup, through a sourced file, so each
--- mapping carries NoetherVim's script id. Nothing maps a row again later,
--- which is what makes your `vim.keymap.set` and `vim.keymap.del` stick: a
--- lazy.nvim `keys` entry is mapped again every time its plugin loads.
---
--- A row is skipped when:
---   - a mapping of yours (or another plugin's) is already on the key; one of
---     Neovim's own default mappings is replaced as usual
---   - its owner plugin is not in the spec, or its spec says `{ lhs, false }`
---   - its `set` is switched off: `keymaps = { remaps = false }` in
---     lua/user/config.lua
---
--- `ft` rows are buffer-local, mapped on FileType; `lsp` rows are
--- buffer-local, mapped on LspAttach when the server supports the method.
--- Both skip a buffer mapping of yours (after/ftplugin runs first).
---
--- Fields: see noethervim.Row in types.lua.

local M = {}

local NOT_OPTS = { owner = true, set = true, mode = true, ft = true, lsp = true, _source = true }

local home = vim.env.HOME and vim.fs.normalize(vim.env.HOME)

--- `path` with the home directory written as `~`, without a call into Vim.
---@param path string
local function tilde(path)
  if home and path:sub(1, #home + 1) == home .. "/" then return "~" .. path:sub(#home + 1) end
  return path
end

---@param x any
---@return table
local function list(x)
  if x == nil then return {} end
  return type(x) == "table" and x or { x }
end

--- The rhs and nvim_set_keymap() options for a row, with vim.keymap.set's
--- defaults; called directly, it costs a fraction of vim.keymap.set at the
--- few hundred rows mapped during startup.
---@param row noethervim.Row
---@return string rhs, table opts
local function keymap_args(row)
  local opts = {}
  for k, v in pairs(row) do
    if type(k) == "string" and not NOT_OPTS[k] then opts[k] = v end
  end
  local rhs, remap = row[2], opts.remap
  opts.remap = nil
  -- A <Plug> target only works remapped, as lazy.nvim's keys assume too.
  if remap == nil and type(rhs) == "string" and rhs:lower():find("^<plug>") then remap = true end
  opts.noremap = not remap
  -- Only for a Lua callback. A string rhs is a Vimscript expression whose
  -- <> notation is converted once, when it is mapped, as with `:map <expr>`;
  -- converting its result again turns a returned <Plug> into typed text.
  if opts.expr and type(rhs) == "function" and opts.replace_keycodes ~= false then opts.replace_keycodes = true end
  if type(rhs) == "function" then
    opts.callback = rhs
    rhs = ""
  end
  return rhs --[[@as string]], opts
end

--- A row's `<Plug>` target exists only once its owner has loaded. Until
--- then a stand-in on the target loads the owner, which defines the real
--- target over it, and passes the key through: what lazy.nvim's own key
--- triggers do, moved one step down so the row itself never changes.
local stubbed = {} ---@type table<string, true>
---@param row noethervim.Row
---@param mode string
local function stub_target(row, mode)
  local plug = type(row[2]) == "string" and row[2]:match("^<[Pp][Ll][Uu][Gg]>%b()$")
  if not plug or not row.owner or vim.startswith(row[1]:lower(), "<plug>") then return end
  local plugin = require("lazy.core.config").plugins[row.owner]
  if not plugin or plugin._.loaded or stubbed[mode .. plug] then return end
  if not vim.tbl_isempty(vim.fn.maparg(plug, mode, false, true)) then return end
  stubbed[mode .. plug] = true
  vim.keymap.set(mode, plug, function()
    pcall(vim.keymap.del, mode, plug)
    require("lazy.core.loader").load(plugin, { keys = plug })
    return "<Ignore>" .. plug
  end, { expr = true, remap = true, desc = "load " .. row.owner })
end

--- Where a row was declared, for `:NoetherVim where`.
---@param row noethervim.Row
local function source_of(row)
  if row._source then return row._source end
  local rhs = row[2]
  if type(rhs) == "function" then
    local info = debug.getinfo(rhs, "S")
    if info.source:sub(1, 1) == "@" then
      return tilde(info.source:sub(2)) .. ":" .. info.linedefined
    end
  end
  return row.owner and (row.owner .. "'s row") or "a NoetherVim row"
end

--- Rows after replacement by identity (mode, lhs, ft, lsp): a later row
--- replaces an earlier one, and a row whose rhs is `false` removes it.
---@param rows noethervim.Row[]
---@return { row: noethervim.Row, mode: string }[]
function M.resolve(rows)
  local by, order = {}, {}
  for _, row in ipairs(rows or {}) do
    local modes = list(row.mode)
    if #modes == 0 then modes = { "n" } end
    for _, mode in ipairs(modes) do
      local fts = list(row.ft)
      table.sort(fts)
      local id = table.concat({ mode, vim.keycode(row[1]), table.concat(fts, ","), tostring(row.lsp or "") }, "\0")
      if not by[id] then table.insert(order, id) end
      by[id] = { row = row, mode = mode }
    end
  end
  local out = {}
  for _, id in ipairs(order) do
    if by[id].row[2] ~= false then table.insert(out, by[id]) end
  end
  return out
end

--- `{ lhs, false }` entries on a plugin's spec, as "mode keycode" keys. The
--- spec is read once per plugin: it does not change after startup.
local removed_cache = {} ---@type table<string, table<string, true>>
---@param plugin table
local function removed_keys(plugin)
  if removed_cache[plugin.name] then return removed_cache[plugin.name] end
  local out = {}
  local ok, keys = pcall(require("lazy.core.plugin").values, plugin, "keys", true)
  for _, key in ipairs(ok and keys or {}) do
    if type(key) == "table" and key[2] == false and type(key[1]) == "string" then
      local modes = list(key.mode)
      if #modes == 0 then modes = { "n" } end
      for _, m in ipairs(modes) do
        for _, single in ipairs(m == "v" and { "v", "x", "s" } or { m }) do
          out[single .. " " .. vim.keycode(key[1])] = true
        end
      end
    end
  end
  removed_cache[plugin.name] = out
  return out
end

--- Why a row is off, or nil when it is on.
---@param row noethervim.Row
---@param mode string
---@return string?
function M.off(row, mode)
  if row.set then
    local sets = require("noethervim.config").get().keymaps
    if type(sets) == "table" and sets[row.set] == false then
      return "set `" .. row.set .. "` is off in lua/user/config.lua"
    end
  end
  if not row.owner then return nil end
  local plugin = require("lazy.core.config").plugins[row.owner]
  if not plugin or plugin._.cond == false then return row.owner .. " is not enabled" end
  local removed = removed_keys(plugin)
  if removed[mode .. " " .. vim.keycode(row[1])] then
    return "{ \"" .. row[1] .. "\", false } on " .. row.owner
  end
end

---@param row noethervim.Row
---@param mode string
---@return noethervim.DefaultRecord
local function record(row, mode)
  return { kind = "map", name = row[1], mode = mode, source = source_of(row), plugin = row.owner, desc = row.desc }
end

--- Whether a global row may be mapped now: not off, and no mapping of
--- yours on the key. A row that may not is recorded for `:NoetherVim where`.
---@param row noethervim.Row
---@param mode string
---@return boolean
function M.free(row, mode)
  local default = require("noethervim.default")
  local rec = record(row, mode)
  local why = M.off(row, mode)
  if why then
    rec.by, rec.off = why, true
    table.insert(default.yielded, rec)
    return false
  end
  local m = default.blocking(mode, row[1])
  if m then
    default.note_map(rec, m)
    return false
  end
  return true
end

--- Map one global row now, unless something keeps it off. Mapped from the
--- caller's script context: a sourced file signs it.
---@param row noethervim.Row
---@param mode string
function M.map_global(row, mode)
  if not M.free(row, mode) then return end
  stub_target(row, mode)
  local rhs, opts = keymap_args(row)
  vim.api.nvim_set_keymap(mode, row[1], rhs, opts)
  require("noethervim.default").note_map(record(row, mode))
end

--- A buffer mapping on `lhs` that neither NoetherVim nor Neovim made.
---@param buf integer
local function buffer_claim(buf, mode, lhs)
  local class = require("noethervim.default").class
  local raw = vim.keycode(lhs)
  for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, mode)) do
    if (m.lhsraw == raw or m.lhsrawalt == raw) and class(m.sid) ~= "distro" and class(m.sid) ~= "runtime" then
      return m
    end
  end
end

local noted = {} ---@type table<string, true>

--- Map buffer rows of one kind. An `lsp` row leaves a key an `ft` row
--- mapped in the buffer: the filetype's key is the more specific one.
---@param buf integer
---@param entries { row: noethervim.Row, mode: string }[]
---@param kind "ft"|"lsp"
local function map_buffer(buf, entries, kind)
  local ours = vim.b[buf].noethervim_rows or {}
  for _, e in ipairs(entries) do
    local row, mode = e.row, e.mode
    local key = mode .. " " .. vim.keycode(row[1])
    local claim = not M.off(row, mode) and buffer_claim(buf, mode, row[1])
    if claim then
      -- One record per key, not per buffer: `where` needs the fact, not a log.
      if not noted[key] then
        noted[key] = true
        require("noethervim.default").note_map(record(row, mode), claim)
      end
    elseif not M.off(row, mode) and not (kind == "lsp" and ours[key] == "ft") then
      stub_target(row, mode)
      local rhs, opts = keymap_args(row)
      vim.api.nvim_buf_set_keymap(buf, mode, row[1], rhs, opts)
      ours[key] = kind
    end
  end
  vim.b[buf].noethervim_rows = ours
end

--- Map every row: global rows now, `ft` and `lsp` rows from autocmds made
--- here. Call it from a sourced file so the mappings are signed.
---@param rows noethervim.Row[]
function M.apply(rows)
  local ok, resolved = pcall(M.resolve, rows)
  if not ok then
    vim.notify("NoetherVim: could not read the key rows: " .. tostring(resolved), vim.log.levels.ERROR)
    return
  end
  local by_ft, lsp_rows, broken = {}, {}, {}
  for _, e in ipairs(resolved) do
    if e.row.ft then
      for _, ft in ipairs(list(e.row.ft)) do
        by_ft[ft] = by_ft[ft] or {}
        table.insert(by_ft[ft], e)
      end
    elseif e.row.lsp then
      table.insert(lsp_rows, e)
    else
      local mapped, err = pcall(M.map_global, e.row, e.mode)
      if not mapped then
        table.insert(broken, ("%s %s (%s): %s"):format(e.mode, tostring(e.row[1]), e.row.owner or "?", err))
      end
    end
  end
  if #broken > 0 then
    vim.notify("NoetherVim: key rows not mapped:\n" .. table.concat(broken, "\n"), vim.log.levels.ERROR)
  end

  local group = vim.api.nvim_create_augroup("noethervim.rows", { clear = true })
  if next(by_ft) then
    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      pattern = vim.tbl_keys(by_ft),
      callback = function(ev) map_buffer(ev.buf, by_ft[ev.match] or {}, "ft") end,
    })
  end
  if #lsp_rows > 0 then
    vim.api.nvim_create_autocmd("LspAttach", {
      group = group,
      callback = function(ev)
        local client = vim.lsp.get_client_by_id(ev.data.client_id)
        if not client then return end
        local entries = vim.tbl_filter(function(e)
          return e.row.lsp == true or client:supports_method(e.row.lsp, ev.buf)
        end, lsp_rows)
        map_buffer(ev.buf, entries, "lsp")
      end,
    })
  end
end

--- `rows`, each stamped with `owner` unless it names its own: the rows a
--- unit contributes from its anchor's spec.
---@param owner string lazy.nvim name of the anchor plugin
---@param rows noethervim.Row[]
---@return noethervim.Row[]
function M.owned(owner, rows)
  for _, row in ipairs(rows) do
    row.owner = row.owner or owner
  end
  return rows
end

--- The `opts` for a unit's NoetherVim fragment: appends `rows`, stamped
--- with `owner`, to what other units contributed, and merges `sections`
--- (`g`, `startup`, `segments`, `busy`, `gutter`, each keyed by name) over
--- theirs.
---
---   specs = { { "NoetherVim", optional = true,
---     opts = require("noethervim.keymaps.rows").contribute("nvim-ufo", { ... }) } }
---
--- A function rather than a table: lazy.nvim's `opts_extend` only reaches
--- fragments merged after the one that declares it, and a unit's spec can
--- be read before NoetherVim's own. One fragment per unit rather than one
--- per section: lazy.nvim chains a plugin's fragments as metatables, so each
--- one makes every later lookup on NoetherVim's spec a step longer.
---@param owner string lazy.nvim name of the anchor plugin
---@param rows noethervim.Row[]
---@param sections? noethervim.HostOpts
---@return fun(plugin: table, opts: noethervim.HostOpts): noethervim.HostOpts
function M.contribute(owner, rows, sections)
  M.owned(owner, rows)
  return function(_, opts)
    opts.rows = opts.rows or {}
    vim.list_extend(opts.rows, rows)
    for name, section in pairs(sections or {}) do
      opts[name] = vim.tbl_extend("force", opts[name] or {}, section)
    end
    return opts
  end
end

--- `file:line` of the function `level` frames above the caller.
---@param level integer
---@return string
function M.here(level)
  local info = debug.getinfo(level + 2, "Sl")
  return tilde(info.source:sub(2)) .. ":" .. info.currentline
end

--- Map rows from a sourced core file (keymaps.lua, toggles/options.lua),
--- with the same rules as rows from specs.
---@param mode string|string[]
---@param lhs string
---@param rhs string|function
---@param opts? table vim.keymap.set options plus `set`, `owner` and
---  `_source` (the declaring line; the caller's by default)
function M.map(mode, lhs, rhs, opts)
  local row = vim.tbl_extend("force", { _source = M.here(1) }, opts or {}, { lhs, rhs })
  for _, m in ipairs(list(mode)) do M.map_global(row, m) end
end

return M
