---@bundle neorg
---@desc .norg wiki / note-taking
---@requires note="ImageMagick" why="image.nvim renders inline images through it" install="brew install imagemagick, or your package manager" optional=true
---@requires note="a terminal with the kitty graphics protocol" why="displaying those images" install="kitty, WezTerm, or Ghostty" optional=true
-- NoetherVim bundle: Neorg (wiki / note-taking)
-- Enable with: { import = "noethervim.bundles.writing.neorg" }
--
-- Provides nvim-neorg for structured note-taking and personal wiki.
-- Default workspace: ~/neorg/  (override in lua/user/plugins/)
--
-- Key bindings.  These open or close wiki buffers rather than searching, so
-- they live under <Leader> (global actions), not the SearchLeader namespace.
--   <Leader>ww  -- open Neorg wiki index
--   <Leader>wt  -- open wiki in new tab
--   <Leader>wv  -- open wiki in vertical split
--   <Leader>wr  -- close all Neorg buffers

return {
	{
		"nvim-neorg/neorg",
		dependencies = { "3rd/image.nvim" },
		keys = {
			{ "<leader>ww", "<cmd>Neorg index<cr>",              desc = "Neorg wiki" },
			{ "<leader>wt", "<cmd>tabe<cr><cmd>Neorg index<cr>", desc = "Neorg wiki (new tab)" },
			{ "<leader>wv", "<cmd>vs<cr><cmd>Neorg index<cr>",   desc = "Neorg wiki (vsplit)" },
			{ "<leader>wr", "<cmd>Neorg return<cr>",             desc = "Close Neorg buffers" },
			{ "<localleader>nr", "<cmd>Neorg return<cr>", ft = "norg", desc = "return from Neorg" },
			{ "<localleader>nc", "<cmd>Neorg toc<cr>",    ft = "norg", desc = "Neorg TOC" },
		},
		cmd = "Neorg",
		ft  = "norg",
		opts = {
			load = {
				["core.defaults"]  = {},
				["core.itero"]     = {},
				["core.keybinds"]  = {
					config = {
						hook = function(keybinds)
							keybinds.remap_key("norg", "i", "<M-CR>", "<S-CR>")
						end,
					},
				},
				["core.concealer"] = {},
				["core.dirman"]    = {
					config = {
						workspaces       = { home = "~/neorg/" },
						default_workspace = "home",
					},
				},
				-- Completion integration removed: neorg's core.completion only
				-- supports nvim-cmp, but this distro uses blink.cmp. Neorg
				-- completions require a blink source adapter if available.
				["core.export"]            = { config = { export_dir = "export/markdown-export" } },
				-- core.presenter removed in recent neorg versions
				-- ["core.presenter"]         = { config = { zen_mode = "zen-mode" } },
				["core.latex.renderer"]    = { config = { render_on_enter = true } },
			},
		},
	},
}
