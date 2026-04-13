-- NoetherVim statusline override registry.
-- Called from noethervim.setup() before plugins load, so the heirline
-- config function can read user preferences at runtime.

local M = {}
local _opts = {}

--- Configure statusline overrides.
--- @param opts table
---   colors      table  — merged into the colors table (vim.tbl_extend "force")
---   extra_right table  — list of heirline component specs appended to the
---                        right side of the main statusline (after GitBlock)
function M.configure(opts)
  _opts = opts or {}
end

--- Returns user color overrides.
function M.get_colors()
  return _opts.colors or {}
end

--- Returns extra right-side components.
function M.get_extra_right()
  return _opts.extra_right or {}
end

return M
