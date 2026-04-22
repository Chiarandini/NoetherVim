-- NoetherVim plugin: Oil file explorer
-- Open with: <C-w><C-o> (float) or :Oil (replace buffer)
--
-- Custom keymaps (in addition to Oil defaults — press g? inside Oil):
--   gd          Toggle detail view (permissions, size, mtime)
--   gf          Fuzzy find in current directory
--   gV          Pick destination and open dual-pane float (q closes both)
--   gX          Open directory in system file browser
--   gS          Create symlink in current directory
--   g.          Toggle hidden files
--   g\          Toggle trash
--   Y           Normal: copy file under cursor to system clipboard
--               Visual: yank selected entries (paste in another oil buffer to copy)
--   yp / yd / yn   Yank full path / dir / filename to unnamed register
--   Yp / Yd / Yn   Same, but straight to the system clipboard (+)

local detail = false

-- Yank the entry under the cursor. `mods` is a |fnamemodify()| mods string
-- (e.g. ":h", ":t"), or nil for the full path. `reg` is the target register
-- ("+" for system clipboard, "" for unnamed).
-- We apply fnamemodify to the raw path first, then append a trailing "/" for
-- directories only when showing the full path — otherwise `:h` returns the
-- directory itself instead of its parent, and `:t` returns an empty string.
local function yank_entry(reg, mods)
	return function()
		local oil = require("oil")
		local entry, dir = oil.get_cursor_entry(), oil.get_current_dir()
		if not entry or not dir then return end
		local path = dir .. entry.name
		if mods then
			path = vim.fn.fnamemodify(path, mods)
		elseif entry.type == "directory" then
			path = path .. "/"
		end
		vim.fn.setreg(reg, path)
		if reg == "+" then vim.notify("Copied: " .. path) end
	end
end

-- Yank the selected oil-buffer lines (linewise) so they can be pasted into
-- another oil buffer to copy the files. Skip "../" (id 0) and unsaved new
-- lines (no id) so a stray paste can't try to create ".." or empty entries.
local function yank_selection()
	local oil = require("oil")
	if not oil.get_current_dir() then return end
	local s, e = vim.fn.line("v"), vim.fn.line(".")
	if s > e then s, e = e, s end

	local lines = vim.api.nvim_buf_get_lines(0, s - 1, e, false)
	local kept = {}
	for i, line in ipairs(lines) do
		local entry = oil.get_entry_on_line(0, s + i - 1)
		if entry and entry.id and entry.id ~= 0 then
			table.insert(kept, line)
		end
	end

	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)

	if #kept == 0 then
		vim.notify("Oil: no copiable entries in selection", vim.log.levels.WARN)
		return
	end
	vim.fn.setreg(vim.v.register, table.concat(kept, "\n"), "V")
	local skipped = #lines - #kept
	local msg = string.format("Yanked %d entr%s", #kept, #kept == 1 and "y" or "ies")
	if skipped > 0 then msg = msg .. string.format(" (skipped %d)", skipped) end
	vim.notify(msg)
end

return {
	{
		"stevearc/oil.nvim",
		lazy = false,
		keys = { {'<c-w><c-o>', function() require('oil').open_float() end, desc = "Oil Mode"}, },
		cmd = { "Oil" },
		dependencies = { "nvim-tree/nvim-web-devicons" },
		opts = {
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
			watch_for_changes = false,
			keymaps = {
				["g?"] = { "actions.show_help", mode = "n" },
				["<CR>"] = "actions.select",
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
				["gd"] = {
					desc = "Toggle file detail view",
					callback = function()
						detail = not detail
						if detail then
							require("oil").set_columns({ "icon", "permissions", "size", "mtime" })
						else
							require("oil").set_columns({ "icon" })
						end
					end,
				},
				["gx"] = "actions.open_external",
				["gX"] = {
					desc = "open dir in system file browser",
					callback = function()
						local dir = require("oil").get_current_dir()
						if not dir then return end
						if vim.fn.has("macunix") == 1 then
							vim.fn.jobstart({ "open", dir }, { detach = true })
						elseif vim.fn.has("win32") == 1 then
							vim.fn.jobstart({ "explorer", dir }, { detach = true })
						else
							vim.fn.jobstart({ "xdg-open", dir }, { detach = true })
						end
					end,
				},
				["gf"] = {
					desc = "fuzzy find in current dir",
					callback = function()
						local dir = require("oil").get_current_dir()
						if not dir then return end
						local title
						local git_root = vim.fn.systemlist("git -C " .. vim.fn.shellescape(dir) .. " rev-parse --show-toplevel")[1]
						if git_root and not git_root:match("^fatal") then
							title = dir:sub(#git_root + 2) -- strip root + trailing /
							if title == "" then title = "." end
						else
							title = vim.fn.fnamemodify(dir, ":~")
						end
						require("snacks").picker.files({
							cwd = dir,
							title = title,
							hidden = require("oil.config").view_options.show_hidden,
							ignored = true,
						})
					end,
				},
				["gV"] = {
					desc = "pick destination and split",
					callback = function()
						local oil = require("oil")
						local dir = oil.get_current_dir()
						if not dir then return end
						local is_float = vim.api.nvim_win_get_config(0).relative ~= ""
						if is_float then oil.close() end
						vim.schedule(function()
							require("snacks").picker({
								title = "Split Oil: Pick Destination",
								cwd = dir,
								finder = "proc",
								cmd = "fd",
								args = { "--type", "d", "--hidden", "--exclude", ".git" },
								format = "file",
								show_empty = true,
								transform = function(item)
									item.cwd = dir
									item.file = item.text
									item.dir = true
								end,
								confirm = function(picker)
									local item = picker:current()
									if not item then return end
									picker:close()
									local dest = item.file
									local is_abs = dest:sub(1, 1) == "/" or dest:match("^%a:[/\\]") ~= nil
									if not is_abs then dest = vim.fs.joinpath(dir, dest) end
									vim.schedule(function()
										local total_w = math.floor(vim.o.columns * 0.8)
										local total_h = math.floor(vim.o.lines * 0.7)
										local row     = math.floor((vim.o.lines   - total_h) / 2)
										local col0    = math.floor((vim.o.columns - total_w) / 2)
										local half_w  = math.floor((total_w - 1) / 2)
										-- Left pane: source dir
										local lbuf = vim.api.nvim_create_buf(false, true)
										local lwin = vim.api.nvim_open_win(lbuf, true, {
											relative = "editor", style = "minimal", border = "rounded",
											row = row, col = col0, width = half_w, height = total_h,
										})
										oil.open(dir)
										-- Right pane: destination dir
										local rbuf = vim.api.nvim_create_buf(false, true)
										local rwin = vim.api.nvim_open_win(rbuf, true, {
											relative = "editor", style = "minimal", border = "rounded",
											row = row, col = col0 + half_w + 1, width = half_w, height = total_h,
										})
										oil.open(dest)
										-- q closes both floats
										local function close_both()
											for _, w in ipairs({ lwin, rwin }) do
												if vim.api.nvim_win_is_valid(w) then
													vim.api.nvim_win_close(w, true)
												end
											end
										end
										for _, w in ipairs({ lwin, rwin }) do
											local buf = vim.api.nvim_win_get_buf(w)
											vim.keymap.set("n", "q", close_both, { buf = buf })
										end
									end)
								end,
							})
						end)
					end,
				},
				["g."] = { "actions.toggle_hidden", mode = "n" },
				["g\\"] = { "actions.toggle_trash", mode = "n" },
				["yp"] = { desc = "yank full path",           mode = "n", callback = yank_entry("",  nil)  },
				["yd"] = { desc = "yank parent dir",          mode = "n", callback = yank_entry("",  ":h") },
				["yn"] = { desc = "yank name",                mode = "n", callback = yank_entry("",  ":t") },
				["Yp"] = { desc = "yank full path (+clip)",   mode = "n", callback = yank_entry("+", nil)  },
				["Yd"] = { desc = "yank parent dir (+clip)",  mode = "n", callback = yank_entry("+", ":h") },
				["Yn"] = { desc = "yank name (+clip)",        mode = "n", callback = yank_entry("+", ":t") },
				["Y"]  = {
					desc = "copy (clipboard in normal, oil-yank in visual)",
					mode = { "n", "x" },
					callback = function()
						if vim.fn.mode():match("^[vV\22]") then
							yank_selection()
						else
							require("oil.clipboard").copy_to_system_clipboard()
						end
					end,
				},
				["gS"] = {
					desc = "Create symlink in current directory",
					callback = function()
						local dir = require("oil").get_current_dir()
						if not dir then return end
						local target = vim.fn.input("Symlink target: ")
						if target == "" then return end
						local link_name = vim.fn.input("Symlink name: ")
						if link_name == "" then return end
						vim.fn.system({ "ln", "-s", target, dir .. link_name })
						require("oil.actions").refresh.callback()
					end,
				},
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
				win_options = { winblend = 10 },
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
		},
	},
}
