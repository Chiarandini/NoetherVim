-- Personal keymap overrides for NoetherVim.
-- Copy this file to lua/user/keymaps.lua and uncomment/add the lines you want.
-- lua/user/keymaps.lua is gitignored -- it never ships with the distribution.
--
-- This file runs after noethervim/keymaps.lua AND noethervim/toggles.lua,
-- so any keymap you set here overwrites the distro default.
--
-- NoetherVim keymap philosophy:
--   SearchLeader   fuzzy navigation / search (default: <Space>, set vim.g.mapsearchleader)
--   <Leader>       global actions
--   <LocalLeader>  filetype-specific actions
--   <C-w>          window navigation / management
--   [x / ]x        prev / next directional navigation
--   [ox / ]ox      toggle option on / off
--
-- See noethervim/keymaps.lua and noethervim/toggles.lua for all defaults.
-- See :help noethervim-user-keymaps for documentation.

-- ── Override a core keymap ───────────────────────────────────────────────────
-- NoetherVim maps ; to : (command-line).  Revert to default:
-- vim.keymap.set("n", ";", ";")

-- ── Remove a core keymap ─────────────────────────────────────────────────────
-- vim.keymap.del("n", "<C-a>")

-- ── Add personal keymaps ─────────────────────────────────────────────────────
-- vim.keymap.set("n", "<space>ev", "<cmd>e $MYVIMRC<cr>", { desc = "edit vimrc" })
-- vim.keymap.set("n", "<space>ez", "<cmd>e ~/.zshrc<cr>",  { desc = "edit zshrc" })
