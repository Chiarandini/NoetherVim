--- Writes NoetherVim makes after its startup layer, made so that a value of
--- yours always wins.
---
--- A plugin's `config` runs whenever lazy.nvim loads it, often long after
--- your options and keymaps ran. A plain `vim.o.timeoutlen = 1500` there
--- would overwrite yours. These helpers read Neovim's own record of who set
--- the current value (the script id behind `:verbose set`) and write only
--- over a value NoetherVim or Neovim set, or nobody did:
---
---   o(name, value)               a global option
---   map(mode, lhs, rhs, opts)    a global mapping
---   command(name, fn, opts)      a user command
---   setlocal(buf, name, value)   a buffer or window option for a buffer
---
--- Every other source counts as yours: your files wherever they live,
--- `init.lua`, a modeline, `-c`, another plugin. A skipped write is
--- recorded for `:NoetherVim where`.
---
--- The write itself runs inside a `User NoetherVimWrite` autocmd that
--- `default/broker.lua` creates. That file is sourced, never required, so
--- every write made through it carries NoetherVim's script id, and
--- `:verbose set timeoutlen?` names NoetherVim rather than whichever plugin
--- load happened to trigger it.

local M = {}

local function real(path)
  return vim.fs.normalize(vim.uv.fs_realpath(path) or path)
end

local root = real((debug.getinfo(1, "S").source:sub(2):gsub("/lua/noethervim/default/init%.lua$", "")))
local runtime = vim.env.VIMRUNTIME and real(vim.env.VIMRUNTIME)

---@class noethervim.DefaultRecord
---@field kind "o"|"map"|"command"
---@field name string option name, lhs, or command name
---@field mode? string
---@field source string file:line of the call
---@field plugin? string the plugin whose config made the call
---@field desc? string
---@field by? string who set the value that was kept

--- Writes made, keyed by kind then name ("mode lhs" for maps).
---@type table<string, table<string, noethervim.DefaultRecord>>
M.owned = { o = {}, map = {}, command = {} }

--- Writes skipped because the value was yours, in the order they happened.
---@type noethervim.DefaultRecord[]
M.yielded = {}

local queue = {}
local nvim_defaults = {} ---@type table<string, true>

local paths = {}
---@param sid integer
---@return string?
local function script(sid)
  if paths[sid] == nil then
    local info = vim.fn.getscriptinfo({ sid = sid })[1]
    -- Neovim's Lua runtime compiled into the binary has no file. At
    -- 'verbose' 1 its writes are recorded under its module name, which
    -- Neovim joins to the current directory: "<cwd>/vim/_core/defaults".
    local embedded = info and not vim.uv.fs_stat(info.name) and info.name:match("vim/[%w_/]+$")
    if embedded then
      paths[sid] = runtime and (runtime .. "/lua/" .. embedded) or embedded
    else
      paths[sid] = info and real(info.name) or false
    end
  end
  return paths[sid] or nil
end

--- Who a script id belongs to.
---   "distro"   a file of NoetherVim's
---   "runtime"  a file of Neovim's ($VIMRUNTIME)
---   "none"     nobody (0), or Lua with no script behind it (-8, -9)
---   "claim"    anything else: yours, a modeline, another plugin
---@param sid integer
---@return "distro"|"runtime"|"none"|"claim"
function M.class(sid)
  if sid == 0 or sid == -8 or sid == -9 then return "none" end
  if sid < 0 then return "claim" end
  local path = script(sid)
  if not path then return "claim" end
  if vim.startswith(path, root .. "/") then return "distro" end
  if runtime and vim.startswith(path, runtime .. "/") then return "runtime" end
  return "claim"
end

--- Short name of a script id's file, for reports.
---@param sid integer
---@return string
function M.describe(sid)
  if sid == 0 then return "nobody" end
  if sid < 0 then return ({ [-1] = "a modeline", [-3] = "a -c argument", [-8] = "Lua", [-9] = "the API" })[sid] or ("sid " .. sid) end
  return vim.fn.fnamemodify(script(sid) or ("sid " .. sid), ":~")
end

--- True when a global option's current value is yours.
---@param name string
---@return boolean claimed, integer sid
function M.claimed(name)
  local ok, info = pcall(vim.api.nvim_get_option_info2, name, { scope = "global" })
  if not ok then return false, 0 end
  return M.class(info.last_set_sid) == "claim", info.last_set_sid
end

local function caller()
  local info = debug.getinfo(3, "Sl")
  local src = info.source:sub(1, 1) == "@" and info.source:sub(2) or info.short_src
  return vim.fn.fnamemodify(src, ":~") .. ":" .. (info.currentline or 0)
end

local function loading_plugin()
  local ok, loader = pcall(require, "lazy.core.loader")
  local stack = ok and loader.loading or {}
  return stack[#stack] and stack[#stack].name or nil
end

-- The single modes a map-command mode stands for, as the snapshot records them.
local SPLIT = { v = { "x", "s" }, [""] = { "n", "x", "s", "o" }, ["!"] = { "i", "c" } }

--- Record a mapping NoetherVim made, under each single mode it covers, so a
--- lookup by the mode `maparg` reports finds it.
---@param rec noethervim.DefaultRecord
local function own(rec)
  local raw = vim.keycode(rec.name)
  for _, single in ipairs(SPLIT[rec.mode] or { rec.mode }) do
    M.owned.map[single .. " " .. raw] = rec
  end
end

--- True while the broker performs NoetherVim's writes, so the claim
--- observer (profiles/apply.lua) can tell them from yours.
M.writing = false

local function apply(item)
  if item.kind == "local" then
    if item.scope == "buf" then
      if vim.api.nvim_buf_is_valid(item.buf) then vim.bo[item.buf][item.name] = item.value end
    else
      for _, win in ipairs(item.wins) do
        if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == item.buf then
          vim.wo[win][0][item.name] = item.value
        end
      end
    end
  elseif item.kind == "o" then
    vim.o[item.name] = item.value
    M.owned.o[item.name] = item.record
  elseif item.kind == "map" then
    vim.keymap.set(item.mode, item.lhs, item.rhs, item.opts)
    own(item.record)
  elseif item.kind == "command" then
    vim.api.nvim_create_user_command(item.name, item.fn, item.opts or {})
    M.owned.command[item.name] = item.record
  end
end

--- Run the queued writes. Called from the broker's autocmd, so the writes
--- carry its script id.
function M._flush()
  local items = queue
  queue = {}
  M.writing = true
  for _, item in ipairs(items) do
    local ok, err = pcall(apply, item)
    if not ok then
      M.writing = false
      error(err)
    end
  end
  M.writing = false
end

local function enqueue(item)
  table.insert(queue, item)
  -- No handler (setup has not run) or no autocmds allowed here (textlock):
  -- write directly. Ownership is still recorded, only the signature is lost.
  pcall(vim.api.nvim_exec_autocmds, "User", { pattern = "NoetherVimWrite", modeline = false })
  if #queue > 0 then M._flush() end
end

---@param kind "o"|"map"|"command"
---@param name string
---@param extra table
---@return noethervim.DefaultRecord
local function record(kind, name, extra)
  return vim.tbl_extend("force", { kind = kind, name = name, plugin = loading_plugin() }, extra)
end

--- Set a global option unless its current value is yours.
---@param name string
---@param value any
---@return boolean written
function M.o(name, value)
  local claimed, sid = M.claimed(name)
  local rec = record("o", name, { source = caller() })
  if claimed then
    rec.by = M.describe(sid)
    table.insert(M.yielded, rec)
    return false
  end
  enqueue({ kind = "o", name = name, value = value, record = rec })
  return true
end

-- The single mode whose maps answer for a map-command mode.
local FIRST = { v = "x", [""] = "n", ["!"] = "i" }

--- Global mappings by mode and raw lhs, while setup() maps its rows.
---@type table<string, table<string, table>>?
local held

--- Answer `holder` from one read of the global mappings rather than a
--- maparg() per key, while setup() maps the core and unit rows: nothing but
--- NoetherVim's own files run in that window, and a mapping NoetherVim made
--- in it is one a later row may replace anyway.
---@param on boolean
---@return table<string, table[]>? lists nvim_get_keymap() per mode, read once
function M.hold(on)
  held = nil
  if not on then return end
  held = {}
  local lists = {}
  for _, mode in ipairs({ "n", "x", "s", "o", "i", "c", "t", "v" }) do
    lists[mode] = vim.api.nvim_get_keymap(mode)
    local by = {}
    for _, m in ipairs(lists[mode]) do
      by[m.lhsraw] = m
      if m.lhsrawalt then by[m.lhsrawalt] = m end
    end
    held[mode] = by
  end
  return lists
end

--- The global mapping currently on `lhs` in `mode`, if any.
---@param mode string
---@param lhs string
---@return table?
local function holder(mode, lhs)
  if held then return held[FIRST[mode] or mode][vim.keycode(lhs)] end
  local m = vim.fn.maparg(lhs, mode, false, true)
  if vim.tbl_isempty(m) then return nil end
  if m.buffer == 0 then return m end
  -- A buffer-local mapping hides the global one; look the global one up.
  local key = vim.keycode(lhs)
  for _, g in ipairs(vim.api.nvim_get_keymap(mode)) do
    if g.lhsraw == key or g.lhsrawalt == key then return g end
  end
end

--- Whether a distro write may replace the mapping `m`: one NoetherVim made,
--- or one of Neovim's own defaults.
---@param mode string
---@param m table
local function replaceable(mode, m)
  for _, single in ipairs(SPLIT[mode] or { mode }) do
    if M.owned.map[single .. " " .. m.lhsraw] then return true end
  end
  if m.sid == -8 then
    for _, single in ipairs(SPLIT[mode] or { mode }) do
      if nvim_defaults[single .. " " .. m.lhsraw] then return true end
    end
  end
  local class = M.class(m.sid)
  return class == "distro" or class == "runtime"
end

--- The global mapping that keeps NoetherVim off `lhs` in `mode`, if any:
--- one that is neither NoetherVim's nor one of Neovim's defaults.
---@param mode string
---@param lhs string
---@return table?
function M.blocking(mode, lhs)
  local m = holder(mode, lhs)
  if m and not replaceable(mode, m) then return m end
end

--- Record a mapping NoetherVim made (`m` nil) or skipped because of `m`.
---@param rec noethervim.DefaultRecord
---@param m? table the mapping that was kept
function M.note_map(rec, m)
  if m then
    rec.by = m.desc and m.desc ~= "" and (m.desc .. ", " .. M.describe(m.sid)) or M.describe(m.sid)
    table.insert(M.yielded, rec)
  else
    own(rec)
  end
end

--- Map `lhs` globally unless a mapping of yours (or another plugin's) is
--- already there. Neovim's default mappings are replaced as usual.
---@param modes string|string[]
---@param lhs string
---@param rhs string|function
---@param opts? table vim.keymap.set options
---@param meta? { owner?: string, source?: string }
function M.map(modes, lhs, rhs, opts, meta)
  opts = opts or {}
  assert(not (opts.buffer or opts.buf), "default.map is for global mappings")
  local src = meta and meta.source or caller()
  local list = (type(modes) == "table" and modes or { modes }) --[[@as string[] ]]
  for _, mode in ipairs(list) do
    local rec = record("map", lhs, { mode = mode, source = src, desc = opts.desc })
    if meta and meta.owner then rec.plugin = meta.owner end
    local m = M.blocking(mode, lhs)
    if m then
      M.note_map(rec, m)
    else
      enqueue({ kind = "map", mode = mode, lhs = lhs, rhs = rhs, opts = opts, record = rec })
    end
  end
end

-- ── Buffer and window options ─────────────────────────────────────────

--- Per buffer, the options that are yours there, each with who set it.
---@type table<integer, table<string, string>>
local claims = {}

--- Record that `name` is yours in `buf`; NoetherVim no longer writes it
--- there. The first claim's description is kept.
---@param buf integer
---@param name string
---@param by string
function M.claim(buf, name, by)
  claims[buf] = claims[buf] or {}
  claims[buf][name] = claims[buf][name] or by
end

--- The options that are yours in `buf`, each with who set it.
---@param buf integer
---@return table<string, string>
function M.claims(buf)
  return claims[buf] or {}
end

---@param buf integer
function M.forget(buf)
  claims[buf] = nil
end

--- Who set the local value `info` describes, when that is you.
---@param name string
---@param info table nvim_get_option_info2() for the local value
---@param layout? boolean a value inherited from your global is not yours
---@return string?
local function local_claim(name, info, layout)
  local sid = info.last_set_sid
  if M.class(sid) ~= "claim" then return nil end
  if layout and sid == vim.api.nvim_get_option_info2(name, { scope = "global" }).last_set_sid then
    return nil
  end
  return M.describe(sid)
end

--- Set a buffer or window option for `buf` unless it is yours there: in
--- every window showing the buffer, floats aside, with `:setlocal`
--- semantics, so the window's next buffer starts from the global again.
---
--- A value is yours when a file that is neither NoetherVim's nor Neovim's
--- set it (in any window showing the buffer), or when a claim is recorded
--- (`:setlocal`, a toggle, a timer). A `layout` option yields only to a
--- value set for the buffer: one inherited from your global does not count.
---@param buf integer
---@param name string
---@param value any
---@param opts? { layout?: boolean, win?: integer } `win`: that window only
---@return boolean written
function M.setlocal(buf, name, value, opts)
  local layout = opts and opts.layout
  local scope = vim.api.nvim_get_option_info2(name, {}).scope
  local wins = {}
  if scope == "win" then
    for _, win in ipairs(opts and opts.win and { opts.win } or vim.fn.win_findbuf(buf)) do
      if vim.api.nvim_win_get_config(win).relative == "" then table.insert(wins, win) end
    end
    if #wins == 0 then return false end
  end
  local by = claims[buf] and claims[buf][name] ---@type string?
  if not by then
    if scope == "buf" then
      by = local_claim(name, vim.api.nvim_get_option_info2(name, { buf = buf }), layout)
    else
      for _, win in ipairs(wins) do
        by = local_claim(name, vim.api.nvim_get_option_info2(name, { win = win }), layout)
        if by then break end
      end
    end
    if by then M.claim(buf, name, by) end
  end
  if by then return false end
  enqueue({ kind = "local", scope = scope, buf = buf, wins = wins, name = name, value = value })
  return true
end

--- Create a user command unless one of that name already exists.
---@param name string
---@param fn string|function
---@param opts? table nvim_create_user_command options
---@return boolean written
function M.command(name, fn, opts)
  local rec = record("command", name, { source = caller() })
  local existing = vim.api.nvim_get_commands({})[name]
  if existing and not M.owned.command[name] then
    rec.by = M.describe(existing.script_id or 0)
    table.insert(M.yielded, rec)
    return false
  end
  enqueue({ kind = "command", name = name, fn = fn, opts = opts, record = rec })
  return true
end

--- Remember Neovim's own default mappings, so distro mappings may replace
--- them. Called at the head of setup(), when every mapping with no script
--- behind it is one of Neovim's (yours and lazy's carry init.lua's id).
function M.snapshot_defaults()
  for _, mode in ipairs({ "n", "x", "s", "o", "i", "c", "t" }) do
    for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do
      if m.sid == -8 then nvim_defaults[mode .. " " .. m.lhsraw] = true end
    end
  end
end

return M
