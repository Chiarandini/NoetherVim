-- NoetherVim plugin: Git Setup
--  ╔══════════════════════════════════════════════════════════╗
--  ║                        Git setup                         ║
--  ╚══════════════════════════════════════════════════════════╝
-- Core: gitsigns only -- hunk navigation ([h/]h) and staging are distro conventions.
-- fugitive and flog live in noethervim.bundles.tools.git.
--
-- Override via: { "lewis6991/gitsigns.nvim", opts = { ... } }

return {
	{ -- git gutter signs, hunk navigation and staging
		"lewis6991/gitsigns.nvim",
		event = "VeryLazy",
		opts = {},
		config = function(_, opts)
			local user_on_attach = opts.on_attach
			opts.on_attach = function(bufnr)
					local gs = package.loaded.gitsigns

					local function map(mode, l, r, opts)
						opts = opts or {}
						opts.buffer = bufnr
						vim.keymap.set(mode, l, r, opts)
					end

					map("n", "]c", function()
						if vim.wo.diff then return "]c" end
						vim.schedule(function() gs.next_hunk() end)
						return "<Ignore>"
					end, { expr = true })

					map("n", "[c", function()
						if vim.wo.diff then return "[c" end
						vim.schedule(function() gs.prev_hunk() end)
						return "<Ignore>"
					end, { expr = true })

					-- [h/]h: navigate hunks (directional convention)
					map("n", "[h", function() vim.schedule(function() gs.prev_hunk() end) end)
					map("n", "]h", function() vim.schedule(function() gs.next_hunk() end) end)
					-- [oH/]oH: toggle show-deleted
					map("n", "[oH", function() gs.toggle_deleted(true)  end)
					map("n", "]oH", function() gs.toggle_deleted(false) end)
					-- [og/]og: toggle current-line blame
					map("n", "[og", function() gs.toggle_current_line_blame(true)  end)
					map("n", "]og", function() gs.toggle_current_line_blame(false) end)

					map("n", "<leader>hs", gs.stage_hunk,       { desc = "stage hunk" })
					map("n", "<leader>hr", gs.reset_hunk,       { desc = "reset hunk" })
					map("v", "<leader>hs", function()
						gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
					end)
					map("v", "<leader>hr", function()
						gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
					end)
					map("n", "<leader>hS", gs.stage_buffer,      { desc = "stage buffer" })
					map("n", "<leader>hu", gs.undo_stage_hunk,   { desc = "undo stage hunk" })
					map("n", "<leader>hR", gs.reset_buffer,      { desc = "reset buffer" })
					map("n", "<leader>hp", gs.preview_hunk,      { desc = "preview hunk" })
					map("n", "<leader>hb", function()
						gs.blame_line({ full = true })
					end, { desc = "blame line" })
					map("n", "<leader>hd", gs.diffthis,           { desc = "diff this" })
					map("n", "<leader>hD", function()
						gs.diffthis("~")
					end, { desc = "diff with ~" })
					map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", { desc = "in hunk" })
					if user_on_attach then user_on_attach(bufnr) end
			end
			require("gitsigns").setup(opts)
		end,
	},
}
