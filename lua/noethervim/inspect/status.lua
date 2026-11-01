--- :NoetherVim status: which of your hook files were sourced.


local M = {}

-- ── Status ──────────────────────────────────────────

function M.status()
  local nv = require("noethervim")
  local lines = {}

  if nv._user_loaded then
    table.insert(lines, "User overrides: ACTIVE")
  else
    table.insert(lines, "User overrides: DISABLED")
    if vim.env.NOETHERVIM_NO_USER then
      table.insert(lines, "  (NOETHERVIM_NO_USER is set)")
    end
    if vim.g.noethervim_no_user then
      table.insert(lines, "  (vim.g.noethervim_no_user is set)")
    end
  end

  if #nv._user_modules > 0 then
    table.insert(lines, "Sourced from lua/user/: " .. table.concat(nv._user_modules, ", "))
  elseif nv._user_loaded then
    table.insert(lines, "No hook files in lua/user/.")
  end

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "NoetherVim" })
end

return M
