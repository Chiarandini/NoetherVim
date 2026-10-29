-- NoetherVim's own spec, merged over the one in your init.lua: a start
-- plugin whatever lazy.nvim's defaults say, so setup() always runs.

-- Loaded while lazy.nvim reads specs, when it never loads a plugin, so a
-- plugin config that writes through it later finds it already loaded
-- instead of pulling NoetherVim in ahead of its turn.
require("noethervim.default")

return {
  "NoetherVim",
  lazy = false,
  config = function(_, opts) require("noethervim").setup(opts) end,
}
