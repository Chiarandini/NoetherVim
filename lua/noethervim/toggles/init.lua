-- Toggle helpers, shared by the definitions in toggles/options.lua and by
-- the toggle feedback the mappings report through.
--
-- toggle(lhs, enable_rhs, disable_rhs, desc, row)  → maps [lhs and ]lhs
-- map(lhs, rhs, desc, echo, row)                   → single directional map
--
-- Both map rows (keymaps/rows.lua); `row` adds row fields such as `owner`
-- and `set`.

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

--- Emit a toggle confirmation message via the user-chosen channel. Exposed
--- so the keymap RHS strings can route through a single dispatcher rather
--- than inlining vim.notify -- changing feedback_style flips every toggle
--- at once.
---@param text string
function M._notify(text)
  local style = feedback_style()
  if style == "off" then return end
  if style == "echo" then
    vim.api.nvim_echo({ { text } }, true, {})
    return
  end
  vim.notify(text, vim.log.levels.INFO)
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
  if echo ~= false and type(rhs) == "string" then
    rhs = rhs .. '<cmd>lua require("noethervim.toggles")._notify("' .. descr .. '")<cr>'
  elseif echo ~= false then
    local fn = rhs
    rhs = function()
      fn()
      M._notify(descr)
    end
  end
  rows.map("n", lhs, rhs, opts)
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
