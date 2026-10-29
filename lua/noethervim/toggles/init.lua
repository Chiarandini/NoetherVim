-- Toggle helpers, shared by the definitions in toggles/options.lua and by
-- the toggle feedback the mappings report through.
--
-- toggle(lhs, enable_rhs, disable_rhs, desc)  → maps [lhs and ]lhs
-- map(lhs, rhs, desc)                         → single directional map

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
function M.map(lhs, rhs, desc, echo)
  local descr = desc or ""
  if type(rhs) == "string" then
    if echo ~= false then
      vim.keymap.set("n", lhs,
        rhs .. '<cmd>lua require("noethervim.toggles")._notify("' .. descr .. '")<cr>',
        { desc = descr })
    else
      vim.keymap.set("n", lhs, rhs, { desc = descr })
    end
  elseif type(rhs) == "function" then
    if echo ~= false then
      vim.keymap.set("n", lhs, function()
        rhs()
        M._notify(descr)
      end, { desc = descr })
    else
      vim.keymap.set("n", lhs, rhs, { desc = descr })
    end
  end
end

---@param lhs string
---@param enable string|function
---@param disable string|function
---@param desc string
function M.toggle(lhs, enable, disable, desc)
  M.map("[" .. lhs, enable,  "enabling: "  .. desc)
  M.map("]" .. lhs, disable, "disabling: " .. desc)
end

return M
