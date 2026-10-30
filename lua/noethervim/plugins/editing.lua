-- NoetherVim plugin: Editing Enhancements
--  ╔══════════════════════════════════════════════════════════╗
--  ║                   Better file editing                    ║
--  ╚══════════════════════════════════════════════════════════╝

-- vim-visual-multi's leader, two backslashes.
local VM = [[\\]]

return {
	{ -- vim-matchup: smarter % matching
		"andymass/vim-matchup",
		event = "BufReadPost",
		specs = { { "NoetherVim", optional = true, opts = { g = {
			matchup_matchparen_offscreen = { method = "popup" },
		} } } },
	},


	{ -- https://github.com/kylechui/nvim-surround/blob/main/lua/nvim-surround/config.lua
		"kylechui/nvim-surround",
		event = "VeryLazy",
		opts = {},
		specs = {
			{ "NoetherVim", optional = true, opts = require("noethervim.keymaps.rows").contribute("nvim-surround", {
				{ "<C-g>s", "<Plug>(nvim-surround-insert)",          mode = "i", desc = "surround the cursor" },
				{ "<C-g>S", "<Plug>(nvim-surround-insert-line)",     mode = "i", desc = "surround the cursor, on new lines" },
				{ "ys",     "<Plug>(nvim-surround-normal)",          desc = "surround a motion" },
				{ "yS",     "<Plug>(nvim-surround-normal-line)",     desc = "surround a motion, on new lines" },
				{ "yc",     "<Plug>(nvim-surround-normal-cur)",      desc = "surround the current line" },
				{ "yC",     "<Plug>(nvim-surround-normal-cur-line)", desc = "surround the current line, on new lines" },
				{ "ds",     "<Plug>(nvim-surround-delete)",          desc = "delete a surrounding pair" },
				{ "cs",     "<Plug>(nvim-surround-change)",          desc = "change a surrounding pair" },
				{ "cS",     "<Plug>(nvim-surround-change-line)",     desc = "change a surrounding pair, on new lines" },
				{ "S",      "<Plug>(nvim-surround-visual)",          mode = "x", desc = "surround the selection", set = "remaps" },
				{ "gS",     "<Plug>(nvim-surround-visual-line)",     mode = "x", desc = "surround the selection, on new lines" },
			}, { g = { nvim_surround_no_mappings = true } }) },
		},
	},

	--<c-n> in visual mode for multiple cursors
	-- Tutorial: vim -Nu path/to/visual-multi/tutorialrc
	--
	-- VM maps its start keys globally and maps them again each time a
	-- session ends. With its defaults off and <C-n> emptied, it maps none,
	-- and the start keys are rows. <S-Left>/<S-Right> stay free for split
	-- resizing (keymaps.lua).
	{
		"mg979/vim-visual-multi",
		event = "BufReadPost",
		specs = {
			{ "NoetherVim", optional = true, opts = require("noethervim.keymaps.rows").contribute("vim-visual-multi", {
				{ "<C-n>",    "<Plug>(VM-Find-Under)",         nowait = true, desc = "multi-cursor: add the word under the cursor", set = "remaps" },
				{ "<C-n>",    "<Plug>(VM-Find-Subword-Under)", nowait = true, mode = "x", desc = "multi-cursor: add the selection", set = "remaps" },
				{ "<C-Down>", "<Plug>(VM-Add-Cursor-Down)",    nowait = true, desc = "multi-cursor: add a cursor below" },
				{ "<C-Up>",   "<Plug>(VM-Add-Cursor-Up)",      nowait = true, desc = "multi-cursor: add a cursor above" },
				{ VM .. "gS",  "<Plug>(VM-Reselect-Last)",      nowait = true, desc = "multi-cursor: reselect the last cursors" },
				{ VM .. "\\",  "<Plug>(VM-Add-Cursor-At-Pos)",  nowait = true, desc = "multi-cursor: add a cursor here" },
				{ VM .. "/",   "<Plug>(VM-Start-Regex-Search)", nowait = true, desc = "multi-cursor: add cursors by regex" },
				{ VM .. "A",   "<Plug>(VM-Select-All)",         nowait = true, desc = "multi-cursor: add every match of the word" },
				{ VM .. "/",   "<Plug>(VM-Visual-Regex)",       nowait = true, mode = "x", desc = "multi-cursor: add cursors by regex in the selection" },
				{ VM .. "A",   "<Plug>(VM-Visual-All)",         nowait = true, mode = "x", desc = "multi-cursor: add every match of the selection" },
				{ VM .. "a",   "<Plug>(VM-Visual-Add)",         nowait = true, mode = "x", desc = "multi-cursor: add the selection as a region" },
				{ VM .. "f",   "<Plug>(VM-Visual-Find)",        nowait = true, mode = "x", desc = "multi-cursor: find in the selection" },
				{ VM .. "c",   "<Plug>(VM-Visual-Cursors)",     nowait = true, mode = "x", desc = "multi-cursor: a cursor on each selected line" },
			}, {
				g = {
					VM_default_mappings = 0,
					VM_maps = { ["Find Under"] = "", ["Find Subword Under"] = "" },
				},
				-- A session maps its keys on `[`, `]` and `,` for the buffer,
				-- and VM leaves a key alone that already has a buffer mapping:
				-- which-key's triggers. which-key steps aside for the session,
				-- as it does while a macro records, and is rebuilt after it.
				startup = { ["vim-visual-multi.which-key"] = function()
					local function which_key(fn)
						if not package.loaded["which-key"] then return end
						local ok, Buf = pcall(require, "which-key.buf")
						if ok then pcall(fn, Buf, vim.api.nvim_get_current_buf()) end
					end
					local group = vim.api.nvim_create_augroup("noethervim.vm_which_key", { clear = true })
					vim.api.nvim_create_autocmd("User", {
						group = group, pattern = "visual_multi_start",
						callback = function() which_key(function(Buf, buf) Buf.clear({ buf = buf }) end) end,
					})
					vim.api.nvim_create_autocmd("User", {
						group = group, pattern = "visual_multi_exit",
						callback = function()
							which_key(function(Buf, buf)
								Buf.clear({ buf = buf })
								Buf.get({ buf = buf })
							end)
						end,
					})
				end },
			}) },
		},
	},

	--  delete extra white space
	{
		"mcauley-penney/tidy.nvim",
		event = 'VeryLazy',
		-- tidy.nvim exposes only .toggle(), so each side checks the state first.
		specs = {
			{ "NoetherVim", optional = true, opts = require("noethervim.keymaps.rows").contribute("tidy.nvim",
				require("noethervim.toggles").rows("oD",
					function()
						local tidy = require("tidy")
						if not tidy.opts.enabled_on_save then tidy.toggle() end
					end,
					function()
						local tidy = require("tidy")
						if tidy.opts.enabled_on_save then tidy.toggle() end
					end,
					"tidy whitespace (Dirty)")) },
			{ "which-key.nvim", optional = true, opts = require("noethervim.util").labels({
				{ "[oD", icon = { icon = require("noethervim.util").icons.options_on, color = "yellow" }, desc = "tidy ON (remove dirty whitespace)" },
				{ "]oD", icon = { icon = require("noethervim.util").icons.options_off, color = "yellow" }, desc = "tidy OFF" },
			}) },
		},
		opts = {
			filetype_exclude = { "snippets", "diff" },
		},
		config = function(_, opts)
			require("tidy").setup(opts)
		end,
	},
	{
		'mcauley-penney/visual-whitespace.nvim',
		config = true,
		-- Loaded on entering visual mode. A load trigger on v/V/<C-v>
		-- themselves would put mappings on Vim's own keys.
		event = "ModeChanged",
	},

	-- better "." feature
	--
	-- vim-repeat maps . u U <C-R> the first time a plugin calls repeat#set,
	-- unless a mapping already leads to its <Plug> targets. The four
	-- <Plug>(noethervim-repeat-*) rows are such mappings, so it never does;
	-- the keys themselves are rows that call it.
	{
		"tpope/vim-repeat",
		lazy = false,
		specs = { { "NoetherVim", optional = true, opts = require("noethervim.keymaps.rows").contribute("vim-repeat", {
			{ "<Plug>(noethervim-repeat-dot)",      "<Plug>(RepeatDot)" },
			{ "<Plug>(noethervim-repeat-undo)",     "<Plug>(RepeatUndo)" },
			{ "<Plug>(noethervim-repeat-undoline)", "<Plug>(RepeatUndoLine)" },
			{ "<Plug>(noethervim-repeat-redo)",     "<Plug>(RepeatRedo)" },
			{ ".", function()
				if vim.fn["repeat#run"](vim.v.count) == 0 then
					vim.notify(vim.fn["repeat#errmsg"](), vim.log.levels.ERROR)
				end
			end, desc = "repeat, plugin actions included", set = "remaps" },
			{ "u",     function() return vim.fn["repeat#wrap"]("u", vim.v.count) end,
			  expr = true, desc = "undo", set = "remaps" },
			{ "U",     function() return vim.fn["repeat#wrap"]("U", vim.v.count) end,
			  expr = true, desc = "undo line", set = "remaps" },
			{ "<C-R>", function() return vim.fn["repeat#wrap"]("\18", vim.v.count) end,
			  expr = true, desc = "redo", set = "remaps" },
		}) } },
	},

	-- smart-enter.nvim: context dispatched <S-CR>. Owns the global insert
	-- mode <S-CR> (a newline that skips the comment leader) and continues
	-- Markdown lists. The latex bundle merges in LaTeX environment rules.
	--
	-- markdown and shell are configured here rather than in a bundle because
	-- both are edited regardless of which language bundles are enabled: every
	-- repo has a README and an install script. Bundle-gated languages keep
	-- their rules in the bundle, as latex does.
	{
		"Chiarandini/smart-enter.nvim",
		lazy = true,
		specs = { { "NoetherVim", optional = true, opts = require("noethervim.keymaps.rows").contribute("smart-enter.nvim", {
			{ "<S-CR>", function() require("smart_enter").dispatch() end, mode = "i", silent = true, desc = "smart enter" },
		}) } },
		opts = {
			key      = false,
			fallback = "newline",
			filetypes = {
				markdown = { preset = "markdown" },
				-- sh covers .sh, .bash, and every bash/sh shebang; zsh is
				-- its own filetype. There is no `bash` filetype to add.
				sh       = { preset = "shell" },
				zsh      = { preset = "shell" },
			},
		},
		config = function(_, opts)
			require("smart_enter").setup(opts)
		end,
	},
}

