-- Toggle helpers, shared by the definitions in toggles/options.lua and by
-- the toggle feedback the mappings report through.
--
-- toggle(lhs, enable_rhs, disable_rhs, desc, row)  → maps [lhs and ]lhs
-- map(lhs, rhs, desc, echo, row)                   → single directional map
-- rows(lhs, enable_rhs, disable_rhs, desc)         → the same pair, as rows
--                                                    a unit contributes
--
-- The first two map rows (keymaps/rows.lua) from a sourced core file; `row`
-- adds row fields such as `owner` and `set`.

local M = {}

--- Style of confirmation message emitted when a toggle fires. Read each
--- time so a user can flip it at runtime without restarting. Values:
---   "notify" (default) -- vim.notify, picked up by snacks as a toast
---   "echo"             -- nvim_echo, classic cmdline message (kept in :messages)
---   "off"              -- silent
local function feedback_style()
  local style = require("noethervim.config").get().toggle_feedback
  return type(style) == "string" and style or "notify"
end

--- Emit a toggle confirmation message through the channel `toggle_feedback`
--- in lua/user/config.lua names. Public (:help noethervim-api), so a toggle
--- of yours reports the way NoetherVim's do, and changing the channel flips
--- every one of them at once.
---@param text string
function M.notify(text)
  local style = feedback_style()
  if style == "off" then return end
  if style == "echo" then
    vim.api.nvim_echo({ { text } }, true, {})
    return
  end
  vim.notify(text, vim.log.levels.INFO)
end

--- `rhs`, reporting `descr` through notify() once it ran.
---@param rhs string|function
---@param descr string
---@return string|function
local function notifying(rhs, descr)
  if type(rhs) == "string" then
    return rhs .. '<cmd>lua require("noethervim.toggles").notify("' .. descr .. '")<cr>'
  end
  return function()
    rhs()
    M.notify(descr)
  end
end

---@param lhs string
---@param rhs string|function
---@param desc? string
---@param echo? boolean  false: no confirmation message
---@param row? table row fields (`owner`, `set`, `_source`)
function M.map(lhs, rhs, desc, echo, row)
  local rows = require("noethervim.keymaps.rows")
  local descr = desc or ""
  local opts = vim.tbl_extend("force", { desc = descr, _source = rows.here(1) }, row or {})
  if echo ~= false then rhs = notifying(rhs, descr) end
  rows.map("n", lhs, rhs, opts)
end

--- The `[lhs` / `]lhs` pair as rows, for a unit to contribute from its
--- anchor's spec, so the toggle goes when the unit does:
---
---   opts = rows.contribute("tint.nvim", toggles.rows("o<c-t>", on, off, "tint"))
---@param lhs string the keys after `[` and `]`
---@param enable string|function
---@param disable string|function
---@param desc string
---@return noethervim.Row[]
function M.rows(lhs, enable, disable, desc)
  local source = require("noethervim.keymaps.rows").here(1)
  local function row(bracket, rhs, verb)
    local d = verb .. ": " .. desc
    return { bracket .. lhs, notifying(rhs, d), desc = d, _source = source }
  end
  return { row("[", enable, "enabling"), row("]", disable, "disabling") }
end

---@param lhs string
---@param enable string|function
---@param disable string|function
---@param desc string
---@param row? table row fields (`owner`, `set`)
function M.toggle(lhs, enable, disable, desc, row)
  row = vim.tbl_extend("force", { _source = require("noethervim.keymaps.rows").here(1) }, row or {})
  M.map("[" .. lhs, enable,  "enabling: "  .. desc, nil, row)
  M.map("]" .. lhs, disable, "disabling: " .. desc, nil, row)
end

return M
