-- Personal option overrides for NoetherVim.
-- Copy this file to lua/user/options.lua and uncomment the lines you want.
-- lua/user/options.lua is gitignored - it never ships with the distribution.
--
-- This file runs immediately after noethervim/options.lua, so any value
-- you set here overwrites the distro default (last-write-wins).
--
-- See noethervim/options.lua for the full list of defaults.
-- See :help noethervim-user-options for documentation.

-- ── Text layout ──────────────────────────────────────────────────────────────
-- vim.o.textwidth     = 120   -- default: 100
-- vim.o.wrap          = true  -- default: false (prose profile enables it)
-- vim.o.formatoptions = "tcq" -- default: "croq1jn" (prose profile adds "t")

-- ── Indentation ──────────────────────────────────────────────────────────────
-- vim.o.tabstop    = 2  -- default: 4
-- vim.o.shiftwidth = 2  -- default: 4

-- ── Scrolling ────────────────────────────────────────────────────────────────
-- vim.o.scrolloff = 8   -- default: 4

-- ── Search ───────────────────────────────────────────────────────────────────
-- vim.o.hlsearch = false -- default: true (<Esc> clears; [oh/]oh toggles)

-- ── Navigation ───────────────────────────────────────────────────────────────
-- vim.o.autochdir = true  -- default: false

-- ── UI ───────────────────────────────────────────────────────────────────────
-- conceallevel = 2 is set per-buffer by the prose profile in
-- noethervim/autocmds.lua (tex, markdown, norg, rst, typst, ...).
-- Override globally here if needed:
-- vim.o.conceallevel = 0
