-- NoetherVim plugin: Blink.cmp Completion
--  ╔══════════════════════════════════════════════════════════╗
--  ║                   Blink.cmp Completion                   ║
--  ╚══════════════════════════════════════════════════════════╝
--
-- Part 1: core built-in sources (LSP, LuaSnip, lazydev, path, buffer).
-- Part 2: vimtex via blink's built-in complete_func source (calls vim.bo.omnifunc directly).
-- Part 3: custom sources (todos, images, preambles) as native blink modules.
--
-- Replaces nvim-cmp and all hrsh7th satellite plugins.
--

return {
	{
		"saghen/blink.cmp",
		version = "1.*", -- pre-built binaries, no Rust toolchain needed
		event = { "InsertEnter", "CmdlineEnter" },
		dependencies = {
			"L3MON4D3/LuaSnip",
			-- blink v1: LuaSnip is wired via snippets.preset = "luasnip" below.
		},
		opts = {
			-- [oC / ]oC keymaps in toggles.lua flip vim.g.blink_toggle.
			enabled = function()
				return vim.g.blink_toggle ~= false
			end,

			-- ── Keymaps ────────────────────────────────────────────────────────
			-- Tab/S-Tab jump snippet nodes only (no menu navigation -- use C-n/p).
			-- Override individual keys via user/plugins/ opts merging.
			-- See :help noethervim-completion-custom for examples.
			keymap = {
				preset    = "none",
				["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },
				["<C-e>"]     = { "hide", "fallback" },
				["<C-y>"]     = { "accept", "fallback" },
				["<C-n>"]     = { "select_next", "fallback" },
				["<C-p>"]     = { "select_prev", "fallback" },
				["<C-b>"]     = { "scroll_documentation_up", "fallback" },
				["<C-f>"]     = { "scroll_documentation_down", "fallback" },
				["<Tab>"]     = { "snippet_forward", "fallback" },
				["<S-Tab>"]   = { "snippet_backward", "fallback" },
			},


			-- ── Snippets ────────────────────────────────────────────────────────
			snippets = {
				preset = "luasnip",
				-- Override active/jump so that Tab expands snippets even when
				-- the completion menu is visible (e.g. vimtex's ':' trigger
				-- shows the menu while LuaSnip has an expandable snippet).
				-- The default luasnip preset gates expansion on the menu being
				-- hidden (is_hidden_snippet), which blocks expansion in tex.
				active = function(filter)
					local ls = require("luasnip")
					if filter and filter.direction then
						if filter.direction == 1 then return ls.expand_or_locally_jumpable() end
						return ls.locally_jumpable(filter.direction)
					end
					return ls.expand_or_locally_jumpable()
				end,
				jump = function(direction)
					local ls = require("luasnip")
					if direction == 1 then return ls.expand_or_jump() end
					return ls.locally_jumpable(direction) and ls.jump(direction)
				end,
			},

			-- ── Sources ─────────────────────────────────────────────────────────
			sources = {
				default = { "lsp", "snippets", "path", "buffer", "todos" },

				per_filetype = {
					lua = { "lsp", "snippets", "lazydev", "path", "buffer", "todos" },
					tex = { "lsp", "snippets", "vimtex", "images" },
				},

				min_keyword_length = 2,

				providers = {
					lazydev = {
						name         = "LazyDev",
						module       = "lazydev.integrations.blink",
						score_offset = 100,
					},

					-- ── Step 2: vimtex via blink's built-in complete_func source ──────
					-- Calls vim.bo.omnifunc (= "vimtex#complete#omnifunc") directly.
					-- No blink.compat shim needed.
					-- override.get_trigger_characters: advertise ':' so that typing 'th:'
					-- in \cref{th:...} creates a fresh context instead of hiding the menu.
					-- (blink's keyword checker ignores iskeyword; ':' is not a keyword char
					-- by its hardcoded definition, so without this it calls trigger.hide().)
					vimtex = {
						name         = "vimtex",
						module       = "blink.cmp.sources.complete_func",
						score_offset = 5,
						max_items    = 20,
						opts = {
							complete_func = function() return vim.bo.omnifunc end,
						},
						override = {
							get_trigger_characters = function(_self)
								return { ":" }
							end,
						},
					},

					buffer = {
						min_keyword_length = 4, -- buffer words only after 4+ chars
						max_items          = 5,
						opts = {
							-- Default scans all visible windows; restrict to current buffer.
							get_bufnrs = function()
								return { vim.api.nvim_get_current_buf() }
							end,
						},
					},

					snippets = {
						max_items = 8, -- large LuaSnip set; cap what reaches the renderer
					},

					-- ── Step 3: custom native blink sources ───────────────────────────
					todos = {
						name   = "todos",
						module = "noethervim.sources.todos",
					},
					images = {
						name   = "images",
						module = "noethervim.sources.images",
					},
				},
			},

			-- ── Completion trigger ──────────────────────────────────────────────
			-- show_on_keyword starts false (conservative default).
			-- A config= function below dynamically swaps this boolean per buffer
			-- via autocmds, since blink v1 validates it must be a boolean.
			completion = {
				trigger = {
					show_on_keyword = false,
				},
				-- Blink owns bracket insertion after accept.
				-- Removes the need for the nvim-autopairs cmp confirm hook;
				-- nvim-autopairs itself stays active for its other features.
				accept = { auto_brackets = { enabled = true } },

				documentation = {
					auto_show          = true,
					auto_show_delay_ms = 100,
					window = { border = "rounded" },
				},

				menu = {
					border = "rounded",
					draw = {
						columns = {
							{ "label", "label_description", gap = 1 },
							{ "kind_icon", "kind", gap = 1 },
						},
					},
				},

				-- noselect: don't pre-highlight or auto-insert the first item.
				-- Matches the previous `completeopt = noselect` behaviour.
				list = {
					max_items  = 20, -- default is 200; rank+render 200 items/keystroke is heavy
					selection  = { preselect = false, auto_insert = false },
				},
			},

			-- ── Cmdline ──────────────────────────────────────────────────────────
			-- blink v1: cmdline is a top-level mode config, NOT a sources entry.
			-- Tab/S-Tab: insert_next/prev cycles through items AND inserts the
			-- selected text into the cmdline via setcmdline().
			-- preselect=false: blink's cmdline default (preselect=true) pre-selects
			-- item 1 when the menu auto-shows, so the first Tab would skip to item 2.
			-- With preselect=false, first Tab correctly selects+inserts item 1.
			cmdline = {
				keymap = {
					preset = "cmdline",
					["<Tab>"]   = { "insert_next" },
					["<S-Tab>"] = { "insert_prev" },
				},
				completion = {
					menu = { auto_show = true },
					list = { selection = { preselect = false, auto_insert = true } },
				},
			},

			-- ── Fuzzy ────────────────────────────────────────────────────────────
			fuzzy = {
				-- max_typos > 0 runs a more expensive algorithm.
				-- 0 = exact prefix matching: faster and more predictable.
				max_typos = 0,
			},

			-- ── Signature help ───────────────────────────────────────────────────
			-- Replaces cmp-nvim-lsp-signature-help.
			signature = {
				enabled = true,
				window  = { border = "rounded" },
			},
		},
		-- blink v1 validates show_on_keyword as boolean, so we can't pass a function
		-- in opts. Instead, after setup we swap the boolean per buffer via autocmds.
		config = function(_, opts)
			-- Disable Neovim's built-in wildchar (Tab) so blink fully owns
			-- cmdline completion. Without this, both wildmenu and blink
			-- fight over Tab in cmdline mode.
			vim.o.wildchar = 0
			vim.o.wildcharm = vim.fn.char2nr(vim.api.nvim_replace_termcodes("<C-z>", true, false, true))

			-- Native <C-Space> fallback: blink overrides this with buffer-local
			-- keymaps on InsertEnter; when blink is disabled (]oC toggle), blink
			-- skips the buffer-local keymap and this global mapping fires instead.
			vim.keymap.set("i", "<C-Space>", function()
				vim.api.nvim_feedkeys(vim.keycode("<C-n>"), "n", false)
			end, { desc = "native keyword completion" })

			require("blink.cmp").setup(opts)

			-- Monkey-patch undo_preview: when the cursor has moved since the
			-- preview was applied (user typed/deleted), commit the preview
			-- instead of reverting it.  Without this, the cursor-compensation
			-- in the undo text-edit sweeps up the user's keystrokes and
			-- corrupts the cmdline text.
			local cmp_list    = require("blink.cmp.completion.list")
			local cmp_context = require("blink.cmp.completion.trigger.context")
			local orig_undo   = cmp_list.undo_preview
			cmp_list.undo_preview = function()
				if cmp_list.preview_undo then
					local expected = cmp_list.preview_undo.cursor_after
					local actual   = cmp_context.get_cursor()
					if expected and actual and actual[2] ~= expected[2] then
						cmp_list.preview_undo = nil
						return
					end
				end
				return orig_undo()
			end

			local function set_keyword_trigger()
				local ok_blink, blink_cfg = pcall(require, "blink.cmp.config")
				if not ok_blink then return end

				-- Skip cmdline mode: completions there are handled by sources.cmdline,
				-- not by the show_on_keyword toggle.
				if vim.fn.mode():match("^c") then return end

				-- Skip floating windows and non-normal buffers (e.g. blink's own popup).
				-- Without this, BufEnter on the completion popup would flip show_on_keyword
				-- to true while editing a conservative filetype.
				local win = vim.api.nvim_get_current_win()
				if vim.api.nvim_win_get_config(win).relative ~= "" then return end
				if vim.bo.buftype ~= "" then return end

				local ok_user, user   = pcall(require, "user.config")
				local has_cfg         = ok_user and type(user) == "table"
				local conservative_ft = (has_cfg and user.blink_conservative_filetypes) or { "tex", "latex" }
				local size_limit      = ((has_cfg and user.blink_conservative_size_kb) or 500) * 1024

				for _, ft in ipairs(conservative_ft) do
					if vim.bo.filetype == ft then
						blink_cfg.completion.trigger.show_on_keyword = false
						return
					end
				end
				local size = vim.fn.getfsize(vim.api.nvim_buf_get_name(0))
				if size > size_limit then
					blink_cfg.completion.trigger.show_on_keyword = false
					return
				end
				blink_cfg.completion.trigger.show_on_keyword = true
			end

			local grp = vim.api.nvim_create_augroup("noethervim_blink_keyword", { clear = true })
			vim.api.nvim_create_autocmd({ "BufEnter", "FileType" },
				{ group = grp, callback = set_keyword_trigger })
			-- In cmdline mode, always enable show_on_keyword so typing command names
			-- triggers completions.  (Our conservative show_on_keyword=false for tex
			-- buffers is a buffer-level setting; we don't want it to bleed into ':'.)
			-- On leave, set_keyword_trigger restores the per-buffer value.
			vim.api.nvim_create_autocmd("CmdlineEnter", {
				group = grp,
				callback = function()
					local ok_b, bcfg = pcall(require, "blink.cmp.config")
					if ok_b then bcfg.completion.trigger.show_on_keyword = true end
				end,
			})
			vim.api.nvim_create_autocmd("CmdlineLeave", {
				group = grp,
				callback = set_keyword_trigger,
			})
			vim.schedule(set_keyword_trigger)
		end,
	},
}
