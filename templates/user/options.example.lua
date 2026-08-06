-- Personal option overrides for NoetherVim.
-- Copy this file to lua/user/options.lua and uncomment the lines you want.
-- lua/user/options.lua lives in your config, not in the distribution:
-- `git pull` and `:Lazy update` never touch it.
--
-- This file runs immediately after noethervim/options.lua, so any value
-- you set here overwrites the distro default (last-write-wins).
--
-- See noethervim/options.lua for the full list of defaults.
-- See :help noethervim-user-options for documentation.

-- ── Text layout ──────────────────────────────────────────────────────────────
-- vim.o.textwidth     = 120   -- default: 100
-- vim.o.wrap          = true  -- default: false (writing profile enables it)
-- vim.o.formatoptions = "tcq" -- default: "croq1jn" (writing profile adds "t")

-- Wrapped lines are marked with an arrow in the number column, not with
-- 'showbreak', so continuation lines stay aligned with the text they
-- continue. To get the inline marker back, set BOTH of these -- an empty
-- statuscolumn reads as "unset" and the writing profile refills it.
-- See :help noethervim-wrap-marker.
-- vim.o.showbreak    = "↳"     -- default: "" (marker lives in the gutter)
-- vim.o.statuscolumn = "%s%=%l "

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
-- conceallevel = 2 is set per-buffer by the writing profile in
-- noethervim/autocmds.lua (tex, markdown, norg, rst, typst, ...).
-- Override globally here if needed:
-- vim.o.conceallevel = 0

-- ── Spell ────────────────────────────────────────────────────────────────────
-- Default is { "en" } -- accepts all English regional dialects (US, UK, ...)
-- so "colour" and "color" both pass. Narrow for stricter checking:
-- vim.opt.spelllang = { "en_us" }            -- US only
-- vim.opt.spelllang = { "en_gb" }            -- UK only
-- vim.opt.spelllang = { "en_us", "de_de" }   -- bilingual

-- ── Sessions ─────────────────────────────────────────────────────────────────
-- Default `sessionoptions` omits `localoptions` to avoid restoring stale
-- buffer-local values (e.g. spelllang frozen at en_us across config updates).
-- Add it back if you want per-buffer option state preserved across sessions:
-- vim.opt.sessionoptions:append("localoptions")
