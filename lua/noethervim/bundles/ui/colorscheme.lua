-- NoetherVim bundle: Colorscheme Collection
-- Enable with: { import = "noethervim.bundles.ui.colorscheme" }
--
-- Provides:
--   - 10 popular colorschemes (installed but lazy — zero startup cost)
--   - Persistence: SearchLeader+C picks persist across restarts
--   - Highlight tweaks: user overrides survive colorscheme switches
--
-- All schemes are lazy=true — only the active one loads. Disk cost is
-- minimal (~2MB total); startup cost is zero.
--
-- Tweaking highlights: in lua/user/highlights.lua, use:
--   require("noethervim.util.colorscheme").tweak({
--       Comment   = { italic = true },
--       CursorLine = { bg = "#1a1a2e" },
--   })
-- These re-apply automatically when you switch colorschemes.
--
-- The persisted choice takes priority over opts.colorscheme in init.lua.
-- To reset, delete: vim.fn.stdpath("data") .. "/noethervim_colorscheme"

return {

  -- ── Persistence + tweak engine ────────────────────────────────────────────
  -- Passes a flag via opts (deep-merged by lazy.nvim, unlike config which
  -- gets replaced). setup() in init.lua checks this flag.
  {
    "Chiarandini/NoetherVim",
    opts = { colorscheme_persistence = true },
  },

  -- ── Colorschemes ──────────────────────────────────────────────────────────
  -- All lazy=true: installed on disk, loaded only when selected.

  { "ellisonleao/gruvbox.nvim",             lazy = true },
  { "catppuccin/nvim",        name = "catppuccin",      lazy = true },
  { "folke/tokyonight.nvim",                lazy = true },
  { "rose-pine/neovim",       name = "rose-pine",       lazy = true },
  { "rebelot/kanagawa.nvim",                lazy = true },
  { "navarasu/onedark.nvim",                lazy = true },
  { "nordtheme/vim",          name = "nord",            lazy = true },
  { "neanias/everforest-nvim",              lazy = true },
  { "EdenEast/nightfox.nvim",              lazy = true },
  { "maxmx03/solarized.nvim",              lazy = true },
}
