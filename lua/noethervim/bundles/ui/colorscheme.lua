---@bundle colorscheme
---@desc nine themes beyond the shipped gruvbox
---@about Breadth only. The theming machinery lives in core and keeps working
---       without this bundle: SearchLeader+C picks the active scheme and the
---       choice survives restarts, and colorscheme.tweak() carries highlight
---       overrides across switches. All nine are lazy, so only the active one
---       loads.
---@requires none
-- NoetherVim bundle: Colorscheme Collection
-- Enable with: { import = "noethervim.bundles.ui.colorscheme" }
--
-- Nine colorschemes beyond the gruvbox that core already ships. This bundle
-- is breadth only: the machinery that makes theming work lives in core, and
-- keeps working without it.
--   - SearchLeader+C picks the active scheme and the pick survives restarts
--   - require("noethervim.util.colorscheme").tweak() overrides highlights
--     across theme switches
--
-- All schemes are lazy=true, so only the active one loads and startup cost is
-- zero. Disk cost is not: the nine total ~18MB (kanagawa 6.0MB, tokyonight
-- 3.6MB, nightfox 2.5MB, catppuccin 2.3MB), which is why they are opt-in.
--
-- The persisted pick takes priority over `colorscheme` in lua/user/config.lua.
-- `:checkhealth noethervim` reports which of the two is in force. To make the
-- config file authoritative again, set `colorscheme_persistence = false`.

return {

  -- ── Mainstream picks ──────────────────────────────────────────────────────
  -- The schemes with the widest install base, and correspondingly the deepest
  -- first-party integrations with the plugins NoetherVim's UI is built from
  -- (snacks, blink.cmp, which-key, trouble, gitsigns). Start here.

  { "catppuccin/nvim",   name = "catppuccin", lazy = true },
  { "folke/tokyonight.nvim",                  lazy = true },
  { "rose-pine/neovim",  name = "rose-pine",  lazy = true },
  { "rebelot/kanagawa.nvim",                  lazy = true },

  -- ── Long tail ─────────────────────────────────────────────────────────────
  -- Well maintained, narrower followings. Several are ports of themes from
  -- outside the Neovim ecosystem, so expect fewer plugin-specific highlights.

  { "navarasu/onedark.nvim",                  lazy = true },
  { "nordtheme/vim",     name = "nord",       lazy = true },
  { "neanias/everforest-nvim",                lazy = true },
  { "EdenEast/nightfox.nvim",                 lazy = true },
  { "maxmx03/solarized.nvim",                 lazy = true },
}
