-- NoetherVim bundle: Wrap-aware search
-- Enable with: { import = "noethervim.bundles.writing.wrapsearch" }
--
-- Hard-wrapped prose breaks search: a phrase that reads as one line on screen
-- has a newline in the middle, so `/brown fox` finds nothing when the wrap
-- falls between the two words. The writing profile hard-wraps by default (it
-- adds `t` to formatoptions), so this affects tex, markdown, text, rst, mail
-- and gitcommit buffers out of the box.
--
-- Rewrites the search pattern so a literal space also matches a line break
-- and the next line's indentation. `n`, `N`, search offsets and the search
-- register are unaffected, because the rewritten pattern is what runs.
--
--   g/ / g?  -- search verbatim, for one search
--
-- Acts only in the filetypes listed below, and only when the pattern contains
-- a space; in code nothing changes. See :help wrapsearch.
--
-- Caveat worth knowing before enabling: 'incsearch' previews the pattern you
-- typed, not the rewritten one, so a phrase spanning a wrap shows no preview
-- and then jumps correctly on <CR>.

return {
	{
		"Chiarandini/wrapsearch.nvim",
		event = "VeryLazy",
		opts = {
			-- Mirrors the writing profile's filetype list (see
			-- noethervim.util.filetypes), since those are the buffers the
			-- distro hard-wraps.
			filetypes = {
				"tex", "latex", "plaintex", "markdown", "norg", "text",
				"rst", "typst", "mail", "gitcommit", "gitsendemail",
			},
		},
	},
}
