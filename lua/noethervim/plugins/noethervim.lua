-- NoetherVim's own spec, merged over the one in your init.lua: a start
-- plugin whatever lazy.nvim's defaults say, so setup() always runs.

local config = require("noethervim.config")

-- Loaded while lazy.nvim reads specs, when it never loads a plugin, so a
-- plugin config that writes through it later finds it already loaded
-- instead of pulling NoetherVim in ahead of its turn.
require("noethervim.default")

-- NOETHERVIM_NO_USER: none of your directories on 'runtimepath', so Neovim
-- sources nothing from your plugin/, after/ or ftplugin/ either.
if config.user_off() then config.prune_rtp() end

return {
  "NoetherVim",
  lazy = false,
  config = function(_, opts) require("noethervim").setup(opts) end,
}
