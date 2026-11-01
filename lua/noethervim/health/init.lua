--- :checkhealth noethervim: one section per system, then each enabled
--- unit's own checks. A unit keeps those in lua/noethervim/lib/<unit>/
--- checkhealth.lua, a function taking vim.health that reports only when its
--- unit is on. (Not health.lua: Neovim runs every lua/**/health.lua as a
--- healthcheck of its own.)

local M = {}

local SYSTEMS = { "environment", "install", "config", "user", "bundles", "snippets", "statusline", "pick", "lsp" }

function M.check()
  for _, name in ipairs(SYSTEMS) do
    require("noethervim.health." .. name).check()
  end
  for _, file in ipairs(vim.api.nvim_get_runtime_file("lua/noethervim/lib/*/checkhealth.lua", true)) do
    local unit = file:match("lib/([^/]+)/checkhealth%.lua$")
    local ok, check = pcall(require, "noethervim.lib." .. unit .. ".checkhealth")
    if ok and type(check) == "function" then check(vim.health) end
  end
  require("noethervim.health.features").check()
end

return M
