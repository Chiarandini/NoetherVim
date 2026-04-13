-- NoetherVim bundle: Neorg (wiki / note-taking)
-- Enable with: { import = "noethervim.bundles.neorg" }
--
-- Provides nvim-neorg for structured note-taking and personal wiki.
-- Default workspace: ~/neorg/  (override in lua/user/plugins/)
--
-- Key bindings (SearchLeader defaults to <Space>, see vim.g.mapsearchleader):
--   SearchLeader+ww  — open Neorg wiki index
--   SearchLeader+wt  — open wiki in new tab
--   SearchLeader+wv  — open wiki in vertical split
--   SearchLeader+wr  — close all Neorg buffers
local SearchLeader = require("noethervim.util").search_leader

return {
	{
		"nvim-neorg/neorg",
		dependencies = { "3rd/image.nvim" },
		keys = {
			{ SearchLeader .. "ww", "<cmd>Neorg index<cr>",              desc = "Neorg wiki" },
			{ SearchLeader .. "wt", "<cmd>tabe<cr><cmd>Neorg index<cr>", desc = "Neorg wiki (new tab)" },
			{ SearchLeader .. "wv", "<cmd>vs<cr><cmd>Neorg index<cr>",   desc = "Neorg wiki (vsplit)" },
			{ SearchLeader .. "wr", "<cmd>Neorg return<cr>",             desc = "Close Neorg buffers" },
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
