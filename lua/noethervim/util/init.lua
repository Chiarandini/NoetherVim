--- NoetherVim utility module
--- Usage:  local nv = require("noethervim.util")
---         nv.icons.search  →  "󰍉"

local M = {}

M.icons         = require("noethervim.util.icons")
M.copy_pdf      = require("noethervim.util.copy_pdf")
M.search_leader = vim.g.mapsearchleader or "<space>"

--- Plain (non-magic) string replacement.
---@param s string
---@param substring string
---@param replacement string
---@param n? integer  max replacements
---@return string
function M.str_replace(s, substring, replacement, n)
  return (s:gsub(substring:gsub("%p", "%%%0"), replacement:gsub("%%", "%%%%"), n))
end

return M
