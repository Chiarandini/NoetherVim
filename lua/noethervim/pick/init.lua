--- The picker seam (|noethervim-pick|). The keys that find files, grep and
--- the rest open a verb by name, and the engine routed to that verb serves
--- it; snacks serves every verb nothing else claims.
---
--- A verb's engine is, in order: `pick.route` in lua/user/config.lua, a
--- unit's `route` on NoetherVim's spec, then snacks. An engine is a table of
--- functions by verb, each called with the verb's opts (`cwd` always set);
--- one that returns `false` declines, and snacks serves the call instead.
--- `resume` goes back to whichever engine served last.

local M = {}

--- Every verb, in the order the docs list them.
M.VERBS = { "files", "grep", "grep_word", "recent", "buffers", "resume", "headings", "labels", "citations" }

local last ---@type string? the engine that served the most recent pick

--- The project `buf` belongs to, or the cwd's without `buf`: the nearest
--- directory up from it holding `.git`, else the cwd.
---@param buf? integer
---@return string
function M.root(buf)
  local cwd = vim.uv.cwd() --[[@as string]]
  local from = cwd
  if buf then
    local name = vim.api.nvim_buf_get_name(buf)
    if name ~= "" and vim.bo[buf].buftype == "" then from = vim.fs.dirname(name) end
  end
  return vim.fs.root(from, ".git") or cwd
end

--- The engines by name: snacks, then each unit's, then yours.
---@return table<string, table<string, fun(opts: table): boolean?>>
local function engines()
  local user = (require("noethervim.config").get().pick or {}).engines or {}
  return vim.tbl_extend("force", { snacks = require("noethervim.pick.snacks_engine") },
    require("noethervim")._host.engines or {}, user)
end
M.engines = engines

--- Which engine `verb` is routed to, and where that was decided.
---@param verb string
---@return string engine, string from
function M.serving(verb)
  local user = ((require("noethervim.config").get().pick or {}).route or {})[verb]
  if user then return user, "lua/user/config.lua" end
  local unit = (require("noethervim")._host.route or {})[verb]
  if unit then return unit, "its bundle" end
  return "snacks", "the default"
end

--- Record that engine `name` served the most recent pick. An engine opened
--- outside open() (its own command, a snacks picker on another key) says
--- so, and `resume` goes back to it.
---@param name string
function M.served(name)
  require("noethervim.pick.snacks_engine")
  last = name
end

--- Open `verb` with the engine routed to it, or with snacks when that engine
--- is missing, lacks the verb or declines.
---@param verb string
---@param opts? table passed on to the engine; `cwd` defaults to the cwd
function M.open(verb, opts)
  opts = vim.tbl_extend("keep", opts or {}, { cwd = vim.uv.cwd() })
  local all = engines()
  local name = verb == "resume" and (last or "snacks") or M.serving(verb)
  local fn = all[name] and all[name][verb]
  if name ~= "snacks" and fn and fn(opts) ~= false then
    last = name
    return
  end
  fn = all.snacks and all.snacks[verb]
  if not fn then
    vim.notify(('Nothing serves "%s": route it with `pick.route` in lua/user/config.lua, '
      .. "or enable the bundle that does."):format(verb), vim.log.levels.WARN)
    return
  end
  last = "snacks"
  fn(opts)
end

--- A row opening `verb`. `fields` are the row's other fields, and `args`
--- its opts: a table, or a function returning them when the key is pressed.
---@param lhs string
---@param verb string
---@param fields? table
---@return noethervim.Row
function M.row(lhs, verb, fields)
  fields = fields or {}
  local args = fields.args
  local row = vim.tbl_extend("force", fields, {
    lhs,
    function() M.open(verb, type(args) == "function" and args() or args) end,
    verb = verb,
    _source = require("noethervim.keymaps.rows").here(1),
  })
  row.args = nil
  return row
end

return M
