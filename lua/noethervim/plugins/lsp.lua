-- NoetherVim plugin: LSP Setup
--  ╔══════════════════════════════════════════════════════════╗
--  ║                        LSP Setup                         ║
--  ╚══════════════════════════════════════════════════════════╝
-- Uses Neovim built-in LSP (vim.lsp.config / vim.lsp.enable) for all servers.
-- nvim-lspconfig is kept only for mason-lspconfig compatibility.
-- Per-server config lives in lua/noethervim/lsp/ (user overrides in lua/user/lsp/).
-- Formatting is handled by conform.nvim; linting by nvim-lint; none-ls is gone.
--
-- Override data values via a user plugin spec:
--   { "neovim/nvim-lspconfig", opts = { diagnostic = { virtual_text = true } } }
--   { "stevearc/conform.nvim", opts = { formatters_by_ft = { rust = { "rustfmt" } } } }
--   { "mfussenegger/nvim-lint", opts = { linters_by_ft = { sh = { "shellcheck" } } } }
local SearchLeader = require("noethervim.util").search_leader

return {
	{
		"j-hui/fidget.nvim",
		event = "LspAttach",
		opts = {},
	},

	{
		"rachartier/tiny-inline-diagnostic.nvim",
		event = "VeryLazy",
		priority = 1000,
		opts = {},
		config = function(_, opts)
			require("tiny-inline-diagnostic").setup(opts)
			vim.diagnostic.config({ virtual_text = false })
		end,
	},

	-- ── conform.nvim: formatter stack ────────────────────────────────────
	-- Replaces none-ls.nvim + mason-null-ls.nvim + prettier.nvim.
	-- <Leader>ff (set in LspAttach below) calls conform with LSP fallback.
	{
		"stevearc/conform.nvim",
		event = { "BufWritePre" },
		cmd   = { "ConformInfo" },
		opts  = {
			formatters_by_ft = {
				lua             = { "stylua" },
				python          = { "black" },
				bib             = { "bibclean" },
				javascript      = { "prettierd" },
				javascriptreact = { "prettierd" },
				typescript      = { "prettierd" },
				typescriptreact = { "prettierd" },
				css             = { "prettierd" },
				html            = { "prettierd" },
				json            = { "prettierd" },
				yaml            = { "prettierd" },
				markdown        = { "prettierd" },
				sh              = { "shfmt" },
			},
			-- No format_on_save — use <Leader>ff for explicit formatting.
		},
		config = function(_, opts)
			require("conform").setup(opts)
			-- Auto-install required formatters via Mason if not already present.
			local mr = require("mason-registry")
			mr.refresh(function()
				for _, tool in ipairs({ "stylua", "bibclean" }) do
					local ok, pkg = pcall(mr.get_package, tool)
					if ok and not pkg:is_installed() then
						pkg:install()
					end
				end
			end)
		end,
	},

	-- ── nvim-lint: linter stack ──────────────────────────────────────────
	-- Companion to conform.nvim: conform handles formatting, nvim-lint
	-- handles diagnostics from non-LSP linters.  Most filetypes are already
	-- covered by their LSP server; add entries here for tools that run
	-- outside the LSP (shellcheck, markdownlint, vale, etc.).
	--
	-- Override via user plugin spec:
	--   { "mfussenegger/nvim-lint", opts = { linters_by_ft = { sh = { "shellcheck" } } } }
	{
		"mfussenegger/nvim-lint",
		event = { "BufReadPost", "BufWritePost", "InsertLeave" },
		opts = {
			linters_by_ft = {
				-- Most linting is provided by LSP servers (basedpyright, ruff,
				-- eslint, lua_ls, …). Add non-LSP linters here or via opts override.
			},
		},
		config = function(_, opts)
			local lint = require("lint")
			lint.linters_by_ft = opts.linters_by_ft

			vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "InsertLeave" }, {
				group = vim.api.nvim_create_augroup("noethervim_lint", { clear = true }),
				callback = function()
					-- Only lint buffers backed by a real file
					if vim.bo.buftype == "" then
						lint.try_lint()
					end
				end,
			})
		end,
	},

	-- ── nvim-lspconfig + Mason + LSP keymaps ─────────────────────────────
	{
		"neovim/nvim-lspconfig",
		event = "BufReadPre",
		keys = {
			{
				"<c-w><c-l>",
				function()
					local clients = vim.lsp.get_clients({ bufnr = 0 })
					if #clients == 0 then
						vim.notify("No LSP clients attached to this buffer", vim.log.levels.INFO)
					else
						local names = vim.tbl_map(function(c) return c.name end, clients)
						vim.notify("LSP: " .. table.concat(names, ", "), vim.log.levels.INFO)
					end
				end,
				desc = require("noethervim.util.icons").nvim_lsp .. " LSP status",
			},
		},
		dependencies = {
			-- lazydev: Neovim-API completions for lua_ls. luvit-meta covers vim.uv types.
			{
				"folke/lazydev.nvim",
				ft = "lua",
				opts = {
					library = {
						{ path = "${3rd}/luv/library", words = { "vim%.uv" } },
					},
				},
			},
			{ "Bilal2453/luvit-meta", lazy = true },
			{
				"williamboman/mason.nvim",
				build = function()
					pcall(vim.cmd, "MasonUpdate")
				end,
				keys = {
					{
						"<c-w><c-m>",
						function() require("mason.ui").open() end,
						desc = require("noethervim.util.icons").mason .. " Mason",
					},
				},
			},
			{ "artemave/workspace-diagnostics.nvim" },
			{ "williamboman/mason-lspconfig.nvim" },
			{
				"hedyhli/outline.nvim",
				opts = {
					outline_window = { auto_close = true },
					preview_window = { auto_preview = true },
					symbol_folding = { autofold_depth = 1 },
				},
			},
		},

		-- ── Overridable data ─────────────────────────────────────────
		-- Note: ensure_installed is an array — overriding it REPLACES
		-- the entire list (lazy.nvim does not merge arrays).
		opts = {
			ensure_installed = {
				'lua_ls', 'basedpyright', 'ruff', 'vimls',
				'eslint', 'ts_ls', 'cssls', 'texlab',
			},
			diagnostic = {
				virtual_text  = false,
				severity_sort = true,
				float = { border = 'rounded', source = 'always' },
			},
		},

		config = function(_, opts)
			local icons = require('noethervim.util.icons')

			vim.lsp.config('*', {
				capabilities = require('blink.cmp').get_lsp_capabilities({
					textDocument = {
						foldingRange = {
							dynamicRegistration = false,
							lineFoldingOnly = true,
						},
					},
				}),
			})


			local function count_lsp_res_changes(lsp_res)
				local count = { instances = 0, files = 0 }
				if lsp_res.documentChanges then
					for _, changed_file in pairs(lsp_res.documentChanges) do
						count.files = count.files + 1
						count.instances = count.instances + #changed_file.edits
					end
				elseif lsp_res.changes then
					for _, changed_file in pairs(lsp_res.changes) do
						count.instances = count.instances + #changed_file
						count.files = count.files + 1
					end
				end
				return count
			end

			local function LspRename()
				local curr_name = vim.fn.expand('<cword>')
				vim.ui.input({ prompt = 'LSP Rename', default = curr_name }, function(new_name)
					if not new_name or #new_name == 0 or curr_name == new_name then return end
					local params = vim.lsp.util.make_position_params()
					params.newName = new_name
					vim.lsp.buf_request(0, 'textDocument/rename', params, function(_, res, ctx)
						if not res then return end
						local client = vim.lsp.get_client_by_id(ctx.client_id)
						vim.lsp.util.apply_workspace_edit(res, client.offset_encoding)
						local changes = count_lsp_res_changes(res)
						vim.notify(string.format(
							'renamed %s instance%s in %s file%s. %s',
							changes.instances, changes.instances == 1 and '' or 's',
							changes.files,     changes.files     == 1 and '' or 's',
							changes.files > 1 and "To save them run ':wa'" or ''
						))
					end)
				end)
			end
			vim.api.nvim_create_user_command('LspRename', LspRename, {})

			vim.api.nvim_create_autocmd('LspAttach', {
				callback = function(args)
					local bufnr  = args.buf
					local client = vim.lsp.get_client_by_id(args.data.client_id)
					if not client then return end

					if client.name == 'ts_ls' then
						require('workspace-diagnostics').populate_workspace_diagnostics(client, bufnr)
					end
					if client.name == 'cssls' then
						client.server_capabilities.definitionProvider = false
					end

					local km_opts = function(desc)
						return { buffer = bufnr, silent = true, desc = desc }
					end

					vim.keymap.set('n', 'gd',  vim.lsp.buf.definition,      km_opts('[g]o to [d]efinition'))
					vim.keymap.set('n', 'gD',  vim.lsp.buf.declaration,     km_opts('[g]o to [D]eclaration'))
					vim.keymap.set('n', 'gt',  vim.lsp.buf.type_definition, km_opts('[g]o to [t]ype definition'))
					vim.keymap.set('n', 'gi',  vim.lsp.buf.implementation,  km_opts('[g]o to [i]mplementation'))
					-- gr/grr/grn: Neovim 0.12 defaults (references, rename) — don't override
					vim.keymap.set('n', 'gR',  '<cmd>Glance references<cr>', km_opts('[G]lance [R]eferences (float)'))
					vim.keymap.set('n', 'gw',  function() vim.lsp.buf.workspace_symbol('') end, km_opts('[g]et [w]orkspace symbols'))
					vim.keymap.set('n', 'gs',  function() vim.lsp.buf.signature_help({ border = 'rounded' }) end, km_opts('[g]et [s]ignature'))
					vim.keymap.set('i', '<C-h>', function() vim.lsp.buf.signature_help({ border = 'rounded' }) end, km_opts('signature help'))
					vim.keymap.set('n', 'gl', vim.diagnostic.open_float, km_opts('diagnostics float'))
					vim.keymap.set('n', ']d', function()
						vim.diagnostic.jump({ count = 1, float = { border = 'rounded' } })
					end, km_opts('next [d]iagnostic'))
					vim.keymap.set('n', '[d', function()
						vim.diagnostic.jump({ count = -1, float = { border = 'rounded' } })
					end, km_opts('prev [d]iagnostic'))
					-- gra/grn: Neovim 0.12 defaults (code action, rename) — don't override
					vim.keymap.set('n',      '<F1>', vim.lsp.buf.code_action,  km_opts('code action'))
					vim.keymap.set('n',      '<F4>', vim.lsp.buf.code_action,  km_opts('code action'))
					vim.keymap.set('x',      '<F1>', vim.lsp.buf.code_action,  km_opts('range code action'))
					vim.keymap.set('n',      '<F2>', LspRename,                km_opts('rename (with count)'))
					-- <Leader>ff: format via conform (falls back to LSP if no formatter configured)
					vim.keymap.set({ 'n', 'x' }, '<Leader>ff', function()
						require("conform").format({ lsp_format = "fallback", bufnr = bufnr })
					end, km_opts('format buffer'))
					vim.keymap.set('n', 'go', '<cmd>Outline<cr>', km_opts('symbols [o]utline'))
					vim.keymap.set('n', SearchLeader .. 'li', vim.lsp.buf.incoming_calls, km_opts('[l]sp [i]ncoming calls'))
					vim.keymap.set('n', SearchLeader .. 'lO', vim.lsp.buf.outgoing_calls, km_opts('[l]sp [O]utgoing calls'))
				end,
			})

			require('mason').setup({
				ui = {
					border = 'rounded',
					icons = {
						package_installed   = '✓',
						package_pending     = '➜',
						package_uninstalled = '✗',
					},
				},
			})

			require('mason-lspconfig').setup({
				ensure_installed   = opts.ensure_installed,
				automatic_enable   = false,
			})

			require('workspace-diagnostics').setup({})

			vim.diagnostic.config(opts.diagnostic)

			vim.diagnostic.config({
				signs = {
					text = {
						[vim.diagnostic.severity.ERROR] = icons.error,
						[vim.diagnostic.severity.WARN]  = icons.warning,
						[vim.diagnostic.severity.HINT]  = icons.loup,
						[vim.diagnostic.severity.INFO]  = icons.info,
					},
				},
			})

			vim.api.nvim_set_hl(0, 'DiagnosticUnderlineHint', { link = 'NONE' })
			vim.api.nvim_set_hl(0, 'DiagnosticUnderlineInfo', { link = 'NONE' })
		end,
	},

	{
		"dnlhc/glance.nvim",
		event = "VeryLazy",
		opts = {},
	},
}
