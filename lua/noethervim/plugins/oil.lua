-- NoetherVim plugin: Oil file explorer
-- Open with: <C-w><C-o> (float) or :Oil (replace buffer)
--
-- Custom keymaps (in addition to Oil defaults — press g? inside Oil):
--   gd          Toggle detail view (permissions, size, mtime)
--   gf          Fuzzy find in current directory
--   gV          Pick destination and open dual-pane float (q closes both)
--   gX          Open directory in system file browser
--   gS          Create symlink in current directory
--   gz          Zip entry under cursor (normal) or selected entries (visual)
--   gZ          Unzip .zip entry (normal) or selected .zip entries (visual)
--   g.          Toggle hidden files
--   g\          Toggle trash
--   Y           Copy file(s) to the system clipboard. Normal yanks the
--               entry under the cursor; visual yanks every selected entry,
--               skipping "../" and unsaved lines.
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

-- Copy the visual-selection entries to the macOS system clipboard as proper
-- Finder file references. Oil's upstream copy_to_system_clipboard refuses
-- multi-file visual mode on macOS because its AppleScript hardcodes
-- `first item of args`; even if we bypass that with writeObjects: over
-- NSURLs, Finder's Cmd+V only pastes the first item because it reads
-- public.file-url from pasteboardItem 0 and stops. Declaring
-- NSFilenamesPboardType as the primary flavor and setting it to a path-list
-- property list routes Finder down the multi-file paste branch. Linux uses
-- Oil's upstream (xclip/wl-copy with text/uri-list) instead.
local mac_clipboard_jxa = [[
function run(argv) {
  ObjC.import("AppKit");
  var pb = $.NSPasteboard.generalPasteboard;
  pb.clearContents;
  pb.declareTypesOwner($.NSArray.arrayWithObject("NSFilenamesPboardType"), $.nil);
  var paths = $.NSMutableArray.alloc.init;
  for (var i = 0; i < argv.length; i++) {
    paths.addObject(argv[i]);
  }
  pb.setPropertyListForType(paths, "NSFilenamesPboardType");
}
]]

local function mac_copy_visual_selection()
	local oil = require("oil")
	local dir = oil.get_current_dir()
	if not dir then return end

	local paths = {}
	local s, e = vim.fn.line("v"), vim.fn.line(".")
	if s > e then s, e = e, s end
	for lnum = s, e do
		local entry = oil.get_entry_on_line(0, lnum)
		if entry and entry.id and entry.id ~= 0 then
			table.insert(paths, dir .. entry.name)
		end
	end
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)

	if #paths == 0 then
		vim.notify("Oil: no files to copy", vim.log.levels.WARN)
		return
	end

	local cmd = { "osascript", "-l", "JavaScript", "-e", mac_clipboard_jxa }
	for _, p in ipairs(paths) do table.insert(cmd, p) end

	vim.system(cmd, { text = true }, function(out)
		vim.schedule(function()
			if out.code ~= 0 then
				vim.notify("Clipboard copy failed: " .. (out.stderr or ""), vim.log.levels.ERROR)
			else
				vim.notify(string.format("Copied %d file%s to clipboard",
					#paths, #paths == 1 and "" or "s"))
			end
		end)
	end)
end

-- Collect entry basenames from the current oil buffer. In visual mode, returns
-- every selected entry (skipping "../" and unsaved lines); in normal mode,
-- returns just the entry under the cursor. Returns (dir, names).
local function collect_entries()
	local oil = require("oil")
	local dir = oil.get_current_dir()
	if not dir then return nil, {} end
	local names = {}
	if vim.fn.mode():match("^[vV\22]") then
		local s, e = vim.fn.line("v"), vim.fn.line(".")
		if s > e then s, e = e, s end
		for line = s, e do
			local entry = oil.get_entry_on_line(0, line)
			if entry and entry.id and entry.id ~= 0 then
				table.insert(names, entry.name)
			end
		end
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
	else
		local entry = oil.get_cursor_entry()
		if entry and entry.id and entry.id ~= 0 then
			table.insert(names, entry.name)
		end
	end
	return dir, names
end

-- Zip entries under cursor / in visual selection to a .zip in the current oil
-- directory. Uses `zip -r` on macOS/Linux and PowerShell's Compress-Archive on
-- Windows; both are stock on their respective platforms.
local function zip_entries()
	local dir, names = collect_entries()
	if not dir then return end
	if #names == 0 then
		vim.notify("Oil: nothing to zip", vim.log.levels.WARN)
		return
	end

	local is_windows = vim.fn.has("win32") == 1
	local tool = is_windows and "powershell" or "zip"
	if vim.fn.executable(tool) == 0 then
		vim.notify(
			string.format("Oil: '%s' not found in PATH — cannot create zip", tool),
			vim.log.levels.ERROR
		)
		return
	end

	-- Defer prompt so the queued <Esc> (visual-mode exit) processes first.
	vim.schedule(function()
		local base = #names == 1 and names[1]:gsub("/$", "") or "archive"
		local archive = vim.fn.input({ prompt = "Archive name: ", default = base .. ".zip", cancelreturn = "" })
		if archive == "" then return end
		if not archive:lower():match("%.zip$") then archive = archive .. ".zip" end

		local cmd
		if is_windows then
			local quoted = {}
			for _, n in ipairs(names) do
				table.insert(quoted, "'" .. n:gsub("'", "''") .. "'")
			end
			local ps = string.format(
				"Compress-Archive -Path %s -DestinationPath '%s' -Force",
				table.concat(quoted, ","),
				archive:gsub("'", "''")
			)
			cmd = { "powershell", "-NoProfile", "-NonInteractive", "-Command", ps }
		else
			cmd = { "zip", "-rq", archive }
			for _, n in ipairs(names) do table.insert(cmd, n) end
		end

		vim.fn.jobstart(cmd, {
			cwd = dir,
			on_exit = function(_, code)
				vim.schedule(function()
					if code == 0 then
						vim.notify(string.format(
							"Zipped %d entr%s → %s",
							#names, #names == 1 and "y" or "ies", archive
						))
						require("oil.actions").refresh.callback()
					else
						vim.notify("Oil: zip failed (exit " .. code .. ")", vim.log.levels.ERROR)
					end
				end)
			end,
		})
	end)
end

-- Unzip selected .zip entries into a destination directory. Uses `unzip -oq`
-- on macOS/Linux and PowerShell's Expand-Archive on Windows; both overwrite
-- existing files silently. Non-zip entries in the selection are skipped.
local function unzip_entries()
	local dir, all_names = collect_entries()
	if not dir then return end

	local zips, skipped = {}, 0
	for _, n in ipairs(all_names) do
		if n:lower():match("%.zip$") then
			table.insert(zips, n)
		else
			skipped = skipped + 1
		end
	end

	if #zips == 0 then
		vim.notify("Oil: no .zip entries to extract", vim.log.levels.WARN)
		return
	end

	local is_windows = vim.fn.has("win32") == 1
	local tool = is_windows and "powershell" or "unzip"
	if vim.fn.executable(tool) == 0 then
		vim.notify(
			string.format("Oil: '%s' not found in PATH — cannot extract zip", tool),
			vim.log.levels.ERROR
		)
		return
	end

	-- Defer prompt so the queued <Esc> (visual-mode exit) processes first.
	vim.schedule(function()
		local dest = vim.fn.input({ prompt = "Extract to: ", default = ".", completion = "dir", cancelreturn = "" })
		if dest == "" then return end

		local pending, failed = #zips, 0
		local function finish()
			pending = pending - 1
			if pending > 0 then return end
			vim.schedule(function()
				if failed == 0 then
					local msg = string.format(
						"Extracted %d archive%s → %s",
						#zips, #zips == 1 and "" or "s", dest
					)
					if skipped > 0 then msg = msg .. string.format(" (skipped %d non-zip)", skipped) end
					vim.notify(msg)
				else
					vim.notify(
						string.format("Oil: %d of %d extractions failed", failed, #zips),
						vim.log.levels.ERROR
					)
				end
				require("oil.actions").refresh.callback()
			end)
		end

		for _, zip in ipairs(zips) do
			local cmd
			if is_windows then
				cmd = {
					"powershell", "-NoProfile", "-NonInteractive", "-Command",
					string.format(
						"Expand-Archive -Path '%s' -DestinationPath '%s' -Force",
						zip:gsub("'", "''"), dest:gsub("'", "''")
					),
				}
			else
				cmd = { "unzip", "-oq", zip, "-d", dest }
			end
			vim.fn.jobstart(cmd, {
				cwd = dir,
				on_exit = function(_, code)
					if code ~= 0 then failed = failed + 1 end
					finish()
				end,
			})
		end
	end)
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
					desc = "copy file(s) to system clipboard",
					mode = { "n", "x" },
					callback = function()
						local is_visual = vim.fn.mode():match("^[vV\22]")
						if is_visual and vim.fn.has("macunix") == 1 then
							mac_copy_visual_selection()
						else
							require("oil.clipboard").copy_to_system_clipboard()
						end
					end,
				},
				["gz"] = {
					desc = "zip entry (normal) or selection (visual)",
					mode = { "n", "x" },
					callback = zip_entries,
				},
				["gZ"] = {
					desc = "unzip .zip entry (normal) or selection (visual)",
					mode = { "n", "x" },
					callback = unzip_entries,
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
