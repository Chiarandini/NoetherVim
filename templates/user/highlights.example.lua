-- Personal highlight overrides for NoetherVim.
-- Copy this file to lua/user/highlights.lua and uncomment/add the lines you want.
-- lua/user/highlights.lua is gitignored - it never ships with the distribution.
--
-- This file runs AFTER the colorscheme is applied, so your overrides
-- are not wiped by the theme.
--
-- See noethervim/highlights.lua for the distro's highlight tweaks.
-- See :help noethervim-user-highlights for documentation.

-- ── Override highlight groups ────────────────────────────────────────────────
-- vim.api.nvim_set_hl(0, "Normal",      { bg = "#1d2021" })
-- vim.api.nvim_set_hl(0, "CursorLine",  { bg = "#282828" })
-- vim.api.nvim_set_hl(0, "SignColumn",   { link = "LineNr" })

-- ── Overrides that survive a theme switch ────────────────────────────────────
-- The nvim_set_hl calls above are wiped the moment you change colorscheme
-- (<Space>C).  Register them through the tweak helper instead and they are
-- re-applied on every switch.  See :help noethervim-colorscheme-tweaks.
-- require("noethervim.util.colorscheme").tweak({
--     Comment    = { italic = true },
--     CursorLine = { bg = "#1a1a2e" },
-- })

-- ── Override Snacks dashboard colours ────────────────────────────────────────
-- vim.api.nvim_set_hl(0, "SnacksDashboardHeader", { fg = "#89b4fa" })
-- vim.api.nvim_set_hl(0, "SnacksDashboardFooter", { fg = "#a6e3a1" })
