-- NoetherVim plugin: Treesitter
--  ╔══════════════════════════════════════════════════════════╗
--  ║                        Treesitter                        ║
--  ╚══════════════════════════════════════════════════════════╝
-- Syntax highlighting and treesitter text objects.
--
-- Override via: { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = { ... } } }
--
-- ON THE `main` BRANCH
-- nvim-treesitter's `main` branch removed the `nvim-treesitter.configs`
-- module that used to read the whole table below and install everything in
-- it. The `opts` shape here is unchanged anyway, because it is the shape
-- users write overrides against; what changed is that `config` now applies
-- it by hand. Anything declared in `opts` and not applied below is dead, so
-- add the wiring at the same time as the option.
--
-- `branch` is pinned rather than left to the repository default. It is not
-- cosmetic: the two branches take different config, and a spec that silently
-- follows whichever branch upstream defaults to would change API underneath
-- this file.
return {

	-- treesitter itself
	{
		"nvim-treesitter/nvim-treesitter",
		event = "BufReadPost",
		branch = "main",

		dependencies = {
			"windwp/nvim-ts-autotag",
			{ -- for vaf, ]i/[i, and so much more! Should really learn more
				"nvim-treesitter/nvim-treesitter-textobjects",
				branch = "main",
			},
		},
		build = ":TSUpdate",
		opts_extend = { "ensure_installed" },

		opts = {
			ensure_installed = { "lua", "vim", "vimdoc", "query", "markdown", "markdown_inline" },
			sync_install = false,
			auto_install = true,
			highlight = {
				enable = true,
				additional_vim_regex_highlighting = false,
				disable = { "latex", "tex", "bib" },
			},
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
						-- `main` renamed this capture from `@scope` to `@local.scope`.
						["as"] = { query = "@local.scope", query_group = "locals", desc = "Select language scope" },
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
					-- `fallback` replays the key literally when no node matched,
					-- which is what keeps >> and << working as plain indent
					-- commands on lines that hold no parameter. >i / <i have no
					-- meaning as literal keys, so they get no fallback.
					swap_next = {
						[">>"] = { query = "@parameter.inner", fallback = true, desc = "swap param right / indent" },
						[">i"] = { query = "@item.outer", desc = "swap item right" },
					},
					swap_previous = {
						["<<"] = { query = "@parameter.inner", fallback = true, desc = "swap param left / unindent" },
						["<i"] = { query = "@item.outer", desc = "swap item left" },
					},
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
				-- No `lsp_interop` block: `main` dropped that module, so the
				-- gPf / gPC peek-definition maps it used to provide have no
				-- implementation left to point at.
			},
		},
		config = function(_, opts)
			require("nvim-ts-autotag").setup({})

			-- ── What `main` no longer does for us ─────────────────────────
			-- Everything from here down applies `opts` by hand. On `master`
			-- a single configs.setup(opts) call did all of it.

			local textobjects = opts.textobjects or {}

			-- Options that used to live inside the textobjects block are now
			-- read from the plugin's own config module, so hand them over
			-- before any keymap runs.
			require("nvim-treesitter-textobjects").setup({
				select = {
					lookahead                      = textobjects.select and textobjects.select.lookahead,
					selection_modes                = textobjects.select and textobjects.select.selection_modes,
					include_surrounding_whitespace = textobjects.select and textobjects.select.include_surrounding_whitespace,
				},
				move = {
					set_jumps = textobjects.move and textobjects.move.set_jumps,
				},
			})

			-- A keymap value is either a bare capture string or a table
			-- carrying the capture plus its query group and description.
			local function capture(value)
				if type(value) == "table" then
					return value.query, value.query_group or "textobjects", value.desc
				end
				return value, "textobjects", nil
			end

			-- Text objects install per buffer rather than globally. `select`
			-- carries a `disable` list, and a filetype opting out has to end
			-- up with no mapping at all: a global map that returned early
			-- would still shadow the `af` / `if` that noethervim-tex defines
			-- for tex buffers.
			local select_blocked = {}
			for _, ft in ipairs(textobjects.select and textobjects.select.disable or {}) do
				select_blocked[ft] = true
			end

			local function install_textobjects(bufnr)
				local ft = vim.bo[bufnr].filetype
				if textobjects.select and textobjects.select.enable and not select_blocked[ft] then
					local select = require("nvim-treesitter-textobjects.select")
					for lhs, value in pairs(textobjects.select.keymaps or {}) do
						local query, group, desc = capture(value)
						vim.keymap.set({ "x", "o" }, lhs, function()
							select.select_textobject(query, group)
						end, { buffer = bufnr, desc = desc or ("select " .. query) })
					end
				end

				if textobjects.move and textobjects.move.enable then
					local move = require("nvim-treesitter-textobjects.move")
					for _, direction in ipairs({
						"goto_next_start", "goto_next_end",
						"goto_previous_start", "goto_previous_end",
					}) do
						for lhs, value in pairs(textobjects.move[direction] or {}) do
							local query, group, desc = capture(value)
							vim.keymap.set({ "n", "x", "o" }, lhs, function()
								move[direction](query, group)
							end, { buffer = bufnr, desc = desc or (direction .. " " .. query) })
						end
					end
				end
			end

			-- `opts.highlight.enable` no longer takes effect on its own, so
			-- start the highlighter explicitly, honouring `highlight.disable`.
			local highlight_disabled = {}
			for _, lang in ipairs(opts.highlight and opts.highlight.disable or {}) do
				highlight_disabled[lang] = true
			end

			local function start_ts(bufnr)
				if not vim.api.nvim_buf_is_valid(bufnr) then return end
				local ft = vim.bo[bufnr].filetype
				if not ft or ft == "" then return end
				install_textobjects(bufnr)
				if not (opts.highlight and opts.highlight.enable) then return end
				local lang = vim.treesitter.language.get_lang(ft) or ft
				if highlight_disabled[lang] or highlight_disabled[ft] then return end
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
			local installed = require("nvim-treesitter.config").get_installed()
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

		-- Swap keymaps. Global rather than per buffer: swap carries no
		-- `disable` list, and these are normal-mode edits.
		--
		-- No-match is detected by comparing changedtick, not by pcall.
		-- swap_textobject RETURNS when nothing matches, it does not raise, so
		-- a pcall around it always reports success and a fallback keyed on
		-- failure never fires. That is what silently cost `>>` its plain
		-- indent behaviour on every line without a parameter under the cursor.
		if textobjects.swap and textobjects.swap.enable then
			local swap = require("nvim-treesitter-textobjects.swap")
			for _, direction in ipairs({ "swap_next", "swap_previous" }) do
				for lhs, value in pairs(textobjects.swap[direction] or {}) do
					local query, group, desc = capture(value)
					local fallback = type(value) == "table" and value.fallback
					vim.keymap.set("n", lhs, function()
						local before = vim.b.changedtick
						swap[direction](query, group)
						if fallback and vim.b.changedtick == before then
							vim.cmd("normal! " .. lhs)
						end
					end, { desc = desc or (direction .. " " .. query) })
				end
			end
		end
		end,
	},
}
