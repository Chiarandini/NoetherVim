-- NoetherVim plugin: Oil file explorer
-- Open with: <C-w><C-o> (float) or :Oil (replace buffer)
--
-- Most keys below bind oil-extras actions (:h oil-extras-actions); press g?
-- inside Oil for the full list, defaults included.
--   <S-CR>      Apply pending edits. Leaves Oil only from normal mode and
--               only when nothing needed confirming; otherwise stays put
--   <C-p>       Preview the entry under the cursor, following the cursor
--   gd          Toggle detail columns (permissions, size, mtime)
--   gf / gG     Find files / live grep in the current directory
--   gV / g|     Second Oil pane beside this one; <C-h>/<C-l> switch, gV/q leave
--   gX          Open directory in system file browser
--   gS          Create symlink in current directory
--   gz / gZ     Zip / unzip the entry, the visual range or the selection
--   g. / g\     Toggle hidden files / trash
--   gm          Select mode: mark scattered entries, then act on them together
--   Y           Copy file(s) to the system clipboard
--   yp / yd / yn   Yank full path / parent dir / name
--   Yp / Yd / Yn   Same, but straight to the system clipboard (+)
--
-- Columns: only `icon`. Size and mtime come from oil-extras' details, painted
-- as virtual text after the listing renders, so a large directory never sits
-- empty waiting on a stat per entry.

return {
	{
		"stevearc/oil.nvim",
		-- ── Lazy-load oil on demand instead of `lazy = false`. ─────────────
		-- `init` runs at spec-resolution time (during lazy.setup), BEFORE
		-- runtime plugins like netrw load. We:
		--   1. Disable netrw early (same effect as oil's setup would have
		--      had, just hoisted up so it's in place before netrw's plugin
		--      file is sourced). Stays scoped to oil's spec: disable oil and
		--      netrw is back.
		--   2. Register a one-shot BufAdd that pulls oil in the moment a
		--      directory buffer is created. This covers `nvim .`, `:e dir/`,
		--      session-restored directory buffers, anything. After the first
		--      hit we delete the augroup -- oil's own BufAdd takes over from
		--      then on.
		--
		-- Load triggers (besides the directory shim above):
		--   * `cmd = "Oil"`           -- `:Oil` from anywhere
		--   * `keys = <c-w><c-o>`     -- float open from anywhere
		init = function()
			vim.g.loaded_netrw       = 1
			vim.g.loaded_netrwPlugin = 1

			-- Future directory buffers (`:e somedir/`, session restore, etc.)
			-- get caught by this BufAdd autocmd, which loads oil on demand.
			local group = vim.api.nvim_create_augroup("noethervim_oil_lazy", { clear = true })
			vim.api.nvim_create_autocmd("BufAdd", {
				group   = group,
				nested  = true,
				callback = function(args)
					local name = vim.api.nvim_buf_get_name(args.buf)
					if name ~= "" and vim.fn.isdirectory(name) == 1 then
						require("oil")  -- triggers lazy load + oil.setup

						-- oil.setup() hijacks the *current* buffer into an
						-- oil:// buffer, but the buffer that tripped us here
						-- (args.buf) is often NOT current yet: `:e .` from a
						-- non-reusable buffer (the dashboard, or any open file)
						-- creates a NEW directory buffer while the old one is
						-- still current, so setup's hijack checks the wrong
						-- buffer -- and oil's own BufAdd handler can't retro-fire
						-- for a buffer whose BufAdd is already in flight. That
						-- directory buffer would then reach its BufReadCmd still
						-- named `/path` (not `oil://`), match oil's BufReadCmd
						-- pattern nowhere, and sit blank *forever* -- the
						-- intermittent "`:e .` opens an empty buffer" bug. So we
						-- hijack args.buf ourselves (the same rename oil's own
						-- maybe_hijack_directory_buffer does) unless setup
						-- already renamed it. Its upcoming BufReadCmd then
						-- matches `oil://*` and renders as normal.
						if vim.api.nvim_buf_is_valid(args.buf)
							and not vim.api.nvim_buf_get_name(args.buf):find("://", 1, true)
						then
							pcall(function()
								local ocfg  = require("oil.config")
								local ofs   = require("oil.fs")
								local outil = require("oil.util")
								outil.rename_buffer(
									args.buf,
									outil.addslash(
										ocfg.adapter_to_scheme.files
											.. ofs.os_to_posix_path(vim.fn.fnamemodify(name, ":p"))
									)
								)
							end)
						end

						pcall(vim.api.nvim_del_augroup_by_id, group)
					end
				end,
			})

			-- `nvim .` case: argv buffer is created during argv processing,
			-- BEFORE init.lua sources, so the BufAdd autocmd above never sees
			-- it. Check the current buffer ourselves -- if it's a directory,
			-- load oil now (during lazy.setup, before BufRead fires) so oil
			-- can rename the buffer to `oil:///path/` in time for its
			-- BufReadCmd to take over.
			local cur = vim.api.nvim_buf_get_name(0)
			if cur ~= "" and vim.fn.isdirectory(cur) == 1 then
				local oil = require("oil")
				pcall(vim.api.nvim_del_augroup_by_id, group)

				-- ── Paint Oil FIRST, before the post-VimEnter load wave ──────
				-- Oil's directory listing is rendered from an async libuv
				-- scandir callback. Just `require("oil")` here loads the *code*
				-- but the *render* is still an async callback -- and the moment
				-- VimEnter fires, lazy pulls in the whole VeryLazy/BufRead wave
				-- (treesitter, LSP, blink.cmp, gitsigns, which-key, ...). That
				-- ~50-plugin wave hogs the main thread for a few hundred ms, so
				-- Oil's scandir callback is serviced LAST and the listing only
				-- paints ~250-400ms after launch -- the long-standing "Oil
				-- isn't instant on `nvim .`" gripe.
				--
				-- So we open oil on the dir right here and pump the event loop
				-- (vim.wait) until its first render fires. The scan is serviced
				-- immediately, during startup, and the wave streams in behind
				-- an already-visible listing. Net: same total startup work,
				-- just reordered so the thing you're staring at comes first.
				-- Drops time-to-paint from ~300ms to ~80ms here.
				--
				-- pcall-guarded so a failure can never break startup; the
				-- BufReadCmd path still renders oil even if open() is skipped.
				local painted = false
				local au = vim.api.nvim_create_autocmd("User", {
					pattern  = "OilEnter",
					once     = true,
					callback = function() painted = true end,
				})
				pcall(oil.open, cur)
				vim.wait(1000, function() return painted end, 5)
				pcall(vim.api.nvim_del_autocmd, au)
			end
		end,
		cmd  = { "Oil" },
		specs = { { "NoetherVim", optional = true, opts = require("noethervim.keymaps.rows").contribute("oil.nvim", {
			{ "<c-w><c-o>", function() require("oil").open_float() end, desc = "Oil Mode" },
		}) } },
		dependencies = { "nvim-tree/nvim-web-devicons", "Chiarandini/oil-extras.nvim" },
		-- A function, so the oil-extras actions are read once the dependency
		-- has loaded rather than while lazy is still reading specs.
		opts = function()
			local x = require("oil_extras.actions")
			return {
				default_file_explorer = true,
				columns = { "icon" },
				buf_options = {
					buflisted = false,
					bufhidden = "hide",
				},
				win_options = {
					wrap = false,
					signcolumn = "no",
					cursorcolumn = true,
					cursorline = true,
					foldcolumn = "0",
					spell = false,
					list = false,
					conceallevel = 3,
					concealcursor = "nvic",
				},
				delete_to_trash = true,
				skip_confirm_for_simple_edits = false,
				prompt_save_on_select_new_entry = true,
				cleanup_delay_ms = 2000,
				lsp_file_methods = {
					enabled = true,
					timeout_ms = 1000,
					autosave_changes = false,
				},
				constrain_cursor = "editable",
				watch_for_changes = true,
				keymaps = {
					["g?"] = { "actions.show_help", mode = "n" },
					["<CR>"] = "actions.select",
					-- The finishing variant of the plain key, the shape <S-CR> already has
					-- in the quickfix window and the browse picker. Buffer-local, so it
					-- shadows smart-enter's global insert <S-CR> only inside Oil, where
					-- that key has nothing to offer.
					["<S-CR>"] = x.save_and_leave,
					["<C-s>"] = { "actions.select", opts = { vertical = true } },
					["<C-h>"] = {},
					["<C-l>"] = {},
					["<C-s-r>"] = "actions.refresh",
					["<C-t>"] = { "actions.select", opts = { tab = true } },
					["<C-p>"] = "actions.preview",
					["<C-c>"] = { "actions.close", mode = "n" },
					["-"] = { "actions.parent", mode = "n" },
					["_"] = { "actions.open_cwd", mode = "n" },
					["`"] = { "actions.cd", mode = "n" },
					["~"] = { "actions.cd", opts = { scope = "tab" }, mode = "n" },
					["gs"] = { "actions.change_sort", mode = "n" },
					["gd"] = x.toggle_details,
					["gx"] = "actions.open_external",
					["gX"] = x.open_dir_external,
					["gf"] = x.find_files,
					["gG"] = x.grep,
					-- Two keys for one action, deliberately. `gV` sits with the other
					-- `g`-prefixed Oil additions; `g|` echoes the `|` this distribution
					-- uses for a vertical split, and says "second pane" where `V` only
					-- says "vertical".
					["gV"] = x.dual_pane,
					["g|"] = x.dual_pane,
					-- `m` for mark. Off SearchLeader on purpose: the mode changes what
					-- `y` and `d` mean, and SearchLeader is side-effect free.
					["gm"] = x.select,
					["g."] = { "actions.toggle_hidden", mode = "n" },
					["g\\"] = { "actions.toggle_trash", mode = "n" },
					["yp"] = { x.yank_path, mode = "n", desc = "yank full path" },
					["yd"] = { x.yank_path, mode = "n", desc = "yank parent dir", opts = { modify = ":h" } },
					["yn"] = { x.yank_path, mode = "n", desc = "yank name", opts = { modify = ":t" } },
					["Yp"] = { x.yank_path, mode = "n", desc = "yank full path (+clip)", opts = { register = "+" } },
					["Yd"] = { x.yank_path, mode = "n", desc = "yank parent dir (+clip)", opts = { modify = ":h", register = "+" } },
					["Yn"] = { x.yank_path, mode = "n", desc = "yank name (+clip)", opts = { modify = ":t", register = "+" } },
					["Y"] = x.copy_to_clipboard,
					["gz"] = x.zip,
					["gZ"] = x.unzip,
					["gS"] = x.symlink,
				},
				use_default_keymaps = true,
				view_options = {
					show_hidden = true,
					is_hidden_file = function(name)
						return name:match("^%.") ~= nil
					end,
					natural_order = "fast",
					case_insensitive = false,
					sort = {
						{ "type", "asc" },
						{ "name", "asc" },
					},
				},
				extra_scp_args = {},
				git = {
					add = function() return false end,
					mv = function() return false end,
					rm = function() return false end,
				},
				float = {
					padding = 2,
					max_width = 0,
					max_height = 0,
					border = "rounded",
					-- IMPORTANT: oil's float opens a NEW window and applies only
					-- `float.win_options` to it (see oil.nvim/init.lua:269) -- the
					-- outer `win_options` table is NOT carried over. So anything
					-- the float must inherit goes here too. Without conceallevel
					-- the float renders oil's `^/\d+ ` entry-id prefixes (which
					-- are concealed by oil's syntax file) as raw text.
					win_options = {
						winblend       = 10,
						conceallevel   = 3,
						concealcursor  = "nvic",
					},
					preview_split = "auto",
					override = function(conf) return conf end,
				},
				preview_win = {
					update_on_cursor_moved = true,
					preview_method = "fast_scratch",
				},
				confirmation = {
					max_width = 0.9,
					min_width = { 40, 0.4 },
					max_height = 0.9,
					min_height = { 5, 0.1 },
					border = "rounded",
				},
				progress = {
					max_width = 0.9,
					min_width = { 40, 0.4 },
					max_height = { 10, 0.9 },
					min_height = { 5, 0.1 },
					border = "rounded",
					minimized_border = "none",
				},
				ssh = { border = "rounded" },
				keymaps_help = { border = "rounded" },
			}
		end,
	},
	{ "Chiarandini/oil-extras.nvim", lazy = true, opts = {} },
}
