-- NoetherVim plugin: Treesitter
--  ╔══════════════════════════════════════════════════════════╗
--  ║                        Treesitter                        ║
--  ╚══════════════════════════════════════════════════════════╝
-- Syntax highlighting, text objects, and incremental selection.
--
-- Override via: { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = { ... } } }
return {

	-- treesitter itself
	{
		"nvim-treesitter/nvim-treesitter",
		event = "BufReadPost",

		dependencies = {
			"windwp/nvim-ts-autotag",
			{ -- for vaf, ]m/[m, and so much more! Should really learn more
				-- config happens in tree-sitter.setup itself
				"nvim-treesitter/nvim-treesitter-textobjects",
			},
		},
		build = ":TSUpdate",
		opts_extend = { "ensure_installed" },

		opts = {
			ensure_installed = { "lua", "vim", "vimdoc", "query", "markdown", "markdown_inline" },
			sync_install = false,
			auto_install = true,
			incremental_selection = { enable = true },
			highlight = {
				enable = true,
				additional_vim_regex_highlighting = false,
				disable = { "latex", "tex", "bib" },
			},
			matchup = { enable = true },
			textobjects = {
				select = {
					enable = true,
					disable = {'tex', 'latex'},
					lookahead = true,
					keymaps = {
						["af"] = "@function.outer",
						["if"] = "@function.inner",
						["iC"] = { query = "@class.inner", desc = "Select inner part of a class region" },
						["aC"] = "@class.outer",
						["av"] = "@parameter.outer",
						["iv"] = "@parameter.inner",
						["al"] = "@loop.outer",
						["il"] = "@loop.inner",
						["ai"] = "@conditional.outer",
						["ii"] = "@conditional.inner",
						["ar"] = "@return.outer",
						["ir"] = "@return.inner",
						["ac"] = "@comment.outer",
						["ic"] = "@comment.inner",
						["as"] = { query = "@scope", query_group = "locals", desc = "Select language scope" },
						["aM"] = { query = "@markdown_metadata.outer", desc = "Select YAML front matter" },
					},
					selection_modes = {
						["@parameter.outer"] = "v",
						["@function.outer"] = "V",
						["@class.outer"] = "<c-v>",
					},
					include_surrounding_whitespace = true,
				},
				swap = {
					enable = true,
					swap_next     = { [">>"] = "@parameter.inner", ['>i'] = "@item.outer" },
					swap_previous = { ["<<"] = "@parameter.inner", ['<i'] = "@item.outer" },
				},
				move = {
					enable = true,
					set_jumps = true,
					goto_next_start = {
						[']i'] = "@item.outer",
						["]z"] = { query = "@fold", query_group = "folds", desc = "Next fold" },
						-- LaTeX env navigation (]g/[g, ]p/[p, ]x/[x, ]c/[c, ]P/[P, ]X/[X)
						-- moved to noethervim-tex: lua/noethervim-tex/treesitter_textobjects.lua
					},
					goto_next_end = {},
					goto_previous_start = {
						['[i'] = "@item.outer",
					},
					goto_previous_end = {
						["[M"] = "@function.outer",
					},
				},
				lsp_interop = {
					enable = true,
					border = "none",
					floating_preview_opts = {},
					-- gPf/gPC: peek definition in g namespace (LSP-like action, not debug)
					peek_definition_code = {
						["gPf"] = "@function.outer",
						["gPC"] = "@class.outer",
					},
				},
			},
		},
		config = function(_, opts)
			require("nvim-ts-autotag").setup({})

			-- nvim-treesitter removed the "configs" module; fall back to
			-- the new "config" (singular) API when the old one is absent.
			local ok, configs = pcall(require, "nvim-treesitter.configs")
			if ok then
			---@diagnostic disable-next-line: missing-fields
			configs.setup(opts)
		end -- configs.setup

		-- On nvim-treesitter's `main` branch the `configs` module above is
		-- absent, so `opts.highlight.enable` never takes effect. Start the
		-- highlighter explicitly via FileType, honouring `highlight.disable`.
		if opts.highlight and opts.highlight.enable then
			local disabled = {}
			for _, lang in ipairs(opts.highlight.disable or {}) do
				disabled[lang] = true
			end

			local function start_ts(bufnr)
				if not vim.api.nvim_buf_is_valid(bufnr) then return end
				local ft = vim.bo[bufnr].filetype
				if not ft or ft == "" then return end
				local lang = vim.treesitter.language.get_lang(ft) or ft
				if disabled[lang] or disabled[ft] then return end
				pcall(vim.treesitter.start, bufnr, lang)
			end

			vim.api.nvim_create_autocmd("FileType", {
				group = vim.api.nvim_create_augroup("noethervim_ts_highlight", { clear = true }),
				callback = function(args) start_ts(args.buf) end,
			})

			-- treesitter is lazy-loaded on BufReadPost, so the buffer that
			-- triggered loading already missed FileType -- attach to it now.
			for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
				if vim.api.nvim_buf_is_loaded(bufnr) then
					start_ts(bufnr)
				end
			end
		end

		-- ensure_installed / auto_install: nvim-treesitter's new API no
		-- longer processes these via setup(), so we handle them directly.
		-- All parsers require the tree-sitter CLI (nvim-treesitter now
		-- uses `tree-sitter build`); warn once if missing.
		local ok_parsers, parsers = pcall(require, "nvim-treesitter.parsers")
		local has_ts_cli = vim.fn.executable("tree-sitter") == 1

		if not has_ts_cli then
			vim.notify(
				"tree-sitter CLI not found -- parser auto-install is disabled.\n"
				.. "Install it (e.g. `brew install tree-sitter`) then restart Neovim.",
				vim.log.levels.WARN
			)
		end

		if opts.ensure_installed and has_ts_cli then
			-- nvim-treesitter.config may not exist on newer main-branch builds;
			-- fall back to listing parser .so files on the rtp.
			local ok_cfg, cfg = pcall(require, "nvim-treesitter.config")
			local installed = ok_cfg and cfg.get_installed and cfg.get_installed() or {}
			if #installed == 0 then
				for _, path in ipairs(vim.api.nvim_get_runtime_file("parser/*.so", true)) do
					table.insert(installed, vim.fn.fnamemodify(path, ":t:r"))
				end
			end
			local to_install = vim.tbl_filter(function(lang)
				return not vim.tbl_contains(installed, lang)
			end, opts.ensure_installed)
			if #to_install > 0 then
				vim.cmd("TSInstall " .. table.concat(to_install, " "))
			end
		end

		if opts.auto_install and has_ts_cli and ok_parsers then
			vim.api.nvim_create_autocmd("FileType", {
				group = vim.api.nvim_create_augroup("noethervim_ts_auto_install", { clear = true }),
				callback = function()
					local lang = vim.treesitter.language.get_lang(vim.bo.filetype)
					if not lang then return end
					-- Skip if the parser is already installed or doesn't exist
					-- in nvim-treesitter's registry (plugin-internal filetypes).
					local ok_lang = pcall(vim.treesitter.language.inspect, lang)
					if ok_lang then return end
					if not parsers[lang] then return end
					pcall(vim.cmd, "TSInstall " .. lang)
				end,
			})
		end

		-- Swap keymaps: nvim-treesitter no longer processes textobjects
		-- config, so set up swap bindings directly via the module API.
		-- >> / << try treesitter swap first; fall back to indent if no parameter found.
		local ok_swap, swap = pcall(require, "nvim-treesitter-textobjects.swap")
		if ok_swap then
			vim.keymap.set("n", ">>", function()
				local ok = pcall(swap.swap_next, "@parameter.inner")
				if not ok then vim.cmd("normal! >>") end
			end, { desc = "swap param right / indent" })
			vim.keymap.set("n", "<<", function()
				local ok = pcall(swap.swap_previous, "@parameter.inner")
				if not ok then vim.cmd("normal! <<") end
			end, { desc = "swap param left / unindent" })
			vim.keymap.set("n", ">i", function() swap.swap_next("@item.outer") end, { desc = "swap item right" })
			vim.keymap.set("n", "<i", function() swap.swap_previous("@item.outer") end, { desc = "swap item left" })
		end
		end,
	},
}
