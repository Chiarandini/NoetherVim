-- NoetherVim plugin: Snacks Dashboard & UI
-- Dashboard, notifications, picker, and miscellaneous UI utilities.
---@module "snacks"

-- Dashboard wordmark. The distribution shipped snacks' NEOVIM art with a
-- dash bolted on either side, so the first thing a new user saw branded
-- their install as plain Neovim -- with no evidence they had installed a
-- distribution at all.
--
-- NOETHER is noethervim-tableaux's; VIM is the tail of snacks' own art, so
-- the letterforms match by construction rather than by redrawing them.
--
-- 83 columns, which is wider than most defaults: `header` picks the narrow
-- wordmark below when the window cannot hold it, since a clipped logo reads
-- worse than a plain one.
local _wordmark = table.concat({
	"███╗   ██╗ ██████╗ ███████╗████████╗██╗  ██╗███████╗██████╗ ██╗   ██╗██╗███╗   ███╗",
	"████╗  ██║██╔═══██╗██╔════╝╚══██╔══╝██║  ██║██╔════╝██╔══██╗██║   ██║██║████╗ ████║",
	"██╔██╗ ██║██║   ██║█████╗     ██║   ███████║█████╗  ██████╔╝██║   ██║██║██╔████╔██║",
	"██║╚██╗██║██║   ██║██╔══╝     ██║   ██╔══██║██╔══╝  ██╔══██╗╚██╗ ██╔╝██║██║╚██╔╝██║",
	"██║ ╚████║╚██████╔╝███████╗   ██║   ██║  ██║███████╗██║  ██║ ╚████╔╝ ██║██║ ╚═╝ ██║",
	"╚═╝  ╚═══╝ ╚═════╝ ╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝  ╚═══╝  ╚═╝╚═╝     ╚═╝",
}, "\n")

local _wordmark_narrow = table.concat({
	"",
	"─── N O E T H E R V I M ───",
	"",
}, "\n")

--- The widest wordmark the window can hold. Snacks centres the block and
--- does not wrap it (`preset.header` is a plain string, read at render), so
--- anything wider than the window loses its right-hand letters -- on this
--- one that would leave "NOETHERV". Resolved once, when the spec loads:
--- the dashboard is a startup surface, and a terminal resized afterwards
--- has already moved past it.
local function _header()
	return vim.o.columns >= 87 and _wordmark or _wordmark_narrow
end

--- Returns file search in git scope
---@param opts table
local find_files_project_dir = function(opts)
	local gitPath = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
	if not gitPath or gitPath:match("^fatal") then
		gitPath = vim.fn.getcwd()
	end
	opts = opts or {}
	opts.cwd = gitPath
	require("snacks").picker.files(opts)
end

--- File yanked for paste in the browse picker (persists across opens).
local _browse_yanked = nil

--- Title for the picker's key-list overlay, which has no other affordance
--- telling you how to get rid of it again.
local help_title = " <F1> or <Esc> to close "

--- Navigate the browse picker into a new directory.
--- Used by the `browse` source defined in opts.picker.sources below.
local function browse_navigate(picker, dir)
	picker:set_cwd(dir)
	picker.input:set("")
	picker.list:set_target()
	picker.title = vim.fn.fnamemodify(dir, ":~")
	picker:find()
	picker:update_titles()
end

--- Open a file from the browse picker in the given split command,
--- or open Oil in that split if the item is a directory.
local function browse_open(cmd)
	return function(picker)
		local item = picker:current()
		if not item then return end
		if item.dir then
			picker:close()
			vim.cmd(cmd)
			require("oil").open(item.file)
		else
			require("snacks.picker.actions").jump(picker, item, { cmd = cmd })
		end
	end
end

--- Read one notification's full text in a float. Sized to the message and
--- capped at 60% of the editor, with the border and title carrying the
--- notifier's own per-level colours. Takes a `snacks.notifier.Notif`, whose
--- type is only resolvable when snacks is installed.
local function open_notification(notif)
	local lines = vim.split(notif.msg, "\n", { plain = true })
	local width = math.floor(vim.o.columns * 0.7)

	-- Wrapped lines still cost a row each, so measure the display width
	-- rather than counting newlines.
	local rows = 0
	for _, line in ipairs(lines) do
		rows = rows + math.max(1, math.ceil(vim.fn.strdisplaywidth(line) / width))
	end

	local Level = notif.level:sub(1, 1):upper() .. notif.level:sub(2)
	local title = vim.tbl_filter(function(part) return part ~= "" end, {
		vim.trim(notif.icon),
		(notif.title and notif.title ~= "") and notif.title or Level,
		os.date("%H:%M", notif.added),
	})

	Snacks.win({
		text       = lines,
		-- `ft` only drives treesitter here; `scratch_ft` is the real
		-- filetype, so markdown highlighting costs us no ftplugin.
		ft         = notif.ft or "markdown",
		scratch_ft = "noethervim-notification",
		title      = " " .. table.concat(title, "  ") .. " ",
		title_pos  = "center",
		border     = "rounded",
		enter      = true,
		width      = width,
		height     = math.min(rows, math.floor(vim.o.lines * 0.6)),
		wo = {
			wrap           = true,
			linebreak      = true,
			spell          = false,
			number         = false,
			relativenumber = false,
			signcolumn     = "no",
			conceallevel   = 3,
			winhighlight   = table.concat({
				"Normal:SnacksNormal",
				"NormalNC:SnacksNormalNC",
				"FloatBorder:SnacksNotifierBorder" .. Level,
				"FloatTitle:SnacksNotifierTitle" .. Level,
			}, ","),
		},
	})
end

local SearchLeader = require("noethervim.util").search_leader

return {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false,
	-- Type provided by snacks.nvim itself; visible to lazydev users, not to
	-- standalone --check (snacks path is install-location-specific).
	---@diagnostic disable-next-line: undefined-doc-name
	---@type snacks.Config
	opts = {
		-- ── Dashboard ─────────────────────────────────────────────────
		-- Disable by setting `vim.g.noethervim_dashboard = false` in init.lua
		-- (before lazy.setup). See :help noethervim-dashboard.
		dashboard = {
			enabled = vim.g.noethervim_dashboard ~= false,
			preset = {
				header = _header(),
				keys = {
					{ icon = " ", key = "i", desc = "New File (insert)",  action = ":ene | startinsert" },
					{ icon = " ", key = "e", desc = "New File (normal)",  action = ":ene" },
					{ icon = " ", key = "f", desc = "Find File",          action = ":lua Snacks.picker.files()" },
					{ icon = " ", key = "o", desc = "Old Files",          action = ":lua Snacks.picker.recent()" },
					{ icon = " ", key = "r", desc = "Restore Session",    action = ":lua require('persistence').load({ last = true })" },
					{ icon = " ", key = "s", desc = "Sessions",           action = ":lua require('mini.sessions').select()" },
					{ icon = " ", key = "c", desc = "Config",             action = ":e $MYVIMRC" },
					{ icon = " ", key = "q", desc = "Quit",               action = ":qa" },
				},
			},
			sections = {
				{ section = "header" },
				{ section = "keys", gap = 1, padding = 1 },
				{ section = "noether_footer", padding = 1 },
			},
		},
		-- ── Explorer / Pickers ─────���──────────────────────────────────
		explorer = {
			enabled = true,
			replace_netrw = false,
		},
		gitbrowse = { enabled = true },
		indent = { enabled = true },
		input = { enabled = true },
		picker = {
			enabled = true,
			layout = "default",
			sources = {
				explorer = {
					layout = { layout = { position = "right" } },
				},
				-- ── Browse: file browser source ─────────────────────────
				-- Replaces telescope-file-browser. Fuzzy-search one
				-- directory at a time; <CR> enters dirs or opens files.
				-- Override any setting in a user spec via:
				--   opts.picker.sources.browse
				--
				-- Keys (insert):
				--   <C-h> go up    <C-v> vsplit  <C-s> split  <C-t> tab
				--   <C-a> create   <C-r> rename  <C-d> delete
				--   <C-y> yank file (for paste)  <C-p> yank path
				--   <S-CR> create file from search text and open it
				-- Keys (normal / list):
				--   <BS> go up  a create  r rename  d delete  c copy
				--   y yank file   p paste yanked    Y yank path
				-- Dirs open in Oil when split/vsplit/tab is used.
				browse = {
					layout = "ivy",
					format = "file",

					finder = function(_, ctx)
						local dir = ctx:cwd()
						local items = {}
						local handle = vim.uv.fs_scandir(dir)
						if not handle then return items end
						while true do
							local name, type = vim.uv.fs_scandir_next(handle)
							if not name then break end
							if name:sub(1, 1) ~= "." then
								items[#items + 1] = {
									text = name,
									file = vim.fs.joinpath(dir, name),
									dir  = (type == "directory"),
								}
							end
						end
						table.sort(items, function(a, b)
							if a.dir ~= b.dir then return a.dir end
							return a.text < b.text
						end)
						return items
					end,

					confirm = function(picker, item, action)
						if not item then return end
						if item.dir then
							browse_navigate(picker, item.file)
						else
							require("snacks.picker.actions").jump(picker, item, action)
						end
					end,

					actions = {
						browse_parent = function(picker)
							local parent = vim.fs.dirname(picker:cwd())
							if parent ~= picker:cwd() then browse_navigate(picker, parent) end
						end,
						browse_vsplit  = browse_open("vsplit"),
						browse_split   = browse_open("split"),
						browse_tab     = browse_open("tabnew"),
						browse_create_open = function(picker)
							local text = vim.api.nvim_buf_get_lines(picker.input.win.buf, 0, 1, false)[1] or ""
							if text == "" then return end
							local path = vim.fs.joinpath(picker:cwd(), text)
							vim.fn.mkdir(vim.fs.dirname(path), "p")
							local fd = vim.uv.fs_open(path, "w", 420)
							if fd then vim.uv.fs_close(fd) end
							picker:close()
							vim.cmd.edit(vim.fn.fnameescape(path))
						end,
						browse_create = function(picker)
							vim.ui.input({ prompt = "New (end with / for dir): " }, function(name)
								if not name or name == "" then return end
								local path = vim.fs.joinpath(picker:cwd(), name)
								if name:sub(-1) == "/" then
									vim.fn.mkdir(path, "p")
								else
									vim.fn.mkdir(vim.fs.dirname(path), "p")
									local fd = vim.uv.fs_open(path, "w", 420)
									if fd then vim.uv.fs_close(fd) end
								end
								picker:find()
							end)
						end,
						browse_delete = function(picker)
							local item = picker:current()
							if not item or not item.file then return end
							vim.ui.input({ prompt = "Delete " .. vim.fn.fnamemodify(item.file, ":t") .. "? [y/N] " }, function(a)
								if a ~= "y" then return end
								vim.fn.delete(item.file, item.dir and "rf" or "")
								picker:find()
							end)
						end,
						browse_rename = function(picker)
							local item = picker:current()
							if not item or not item.file then return end
							vim.ui.input({ prompt = "Rename: ", default = vim.fn.fnamemodify(item.file, ":t") }, function(name)
								if not name or name == "" then return end
								vim.uv.fs_rename(item.file, vim.fs.joinpath(picker:cwd(), name))
								picker:find()
							end)
						end,
						browse_copy = function(picker)
							local item = picker:current()
							if not item or not item.file then return end
							vim.ui.input({ prompt = "Copy to: ", default = vim.fn.fnamemodify(item.file, ":t") }, function(name)
								if not name or name == "" then return end
								vim.uv.fs_copyfile(item.file, vim.fs.joinpath(picker:cwd(), name))
								picker:find()
							end)
						end,
						browse_yank_file = function(picker)
							local item = picker:current()
							if not item or not item.file then return end
							_browse_yanked = item.file
							vim.notify(vim.fn.fnamemodify(item.file, ":t"), vim.log.levels.INFO, { title = "Yanked file" })
						end,
						browse_paste = function(picker)
							if not _browse_yanked then
								return vim.notify("Nothing yanked", vim.log.levels.WARN, { title = "Browse" })
							end
							local name = vim.fn.fnamemodify(_browse_yanked, ":t")
							local dest = vim.fs.joinpath(picker:cwd(), name)
							if vim.uv.fs_stat(dest) then
								return vim.notify(name .. " already exists", vim.log.levels.WARN, { title = "Browse" })
							end
							vim.uv.fs_copyfile(_browse_yanked, dest)
							vim.notify(name, vim.log.levels.INFO, { title = "Pasted" })
							picker:find()
						end,
						browse_yank_path = function(picker)
							local item = picker:current()
							if not item or not item.file then return end
							vim.fn.setreg("+", item.file)
							vim.notify(vim.fn.fnamemodify(item.file, ":~"), vim.log.levels.INFO, { title = "Yanked path" })
						end,
					},

					win = {
						input = {
							keys = {
								["<C-h>"] = { "browse_parent", mode = { "i" },      desc = "parent dir" },
								["<C-v>"] = { "browse_vsplit", mode = { "i" },      desc = "vsplit" },
								["<C-s>"] = { "browse_split",  mode = { "i" },      desc = "split" },
								["<C-t>"] = { "browse_tab",    mode = { "i" },      desc = "tab" },
								["<C-a>"] = { "browse_create", mode = { "i" },      desc = "create" },
								["<C-r>"] = { "browse_rename", mode = { "i" },      desc = "rename" },
								["<C-d>"] = { "browse_delete",      mode = { "i" },      desc = "delete" },
								["<S-CR>"] = { "browse_create_open", mode = { "i" },      desc = "create & open" },
								["<C-y>"] = { "browse_yank_file",    mode = { "i" },      desc = "yank file" },
								["<C-p>"] = { "browse_yank_path",   mode = { "i" },      desc = "yank path" },
							},
						},
						list = {
							keys = {
								["<BS>"]  = { "browse_parent", desc = "parent dir" },
								["<C-v>"] = { "browse_vsplit", desc = "vsplit" },
								["<C-s>"] = { "browse_split",  desc = "split" },
								["<C-t>"] = { "browse_tab",    desc = "tab" },
								["a"]     = { "browse_create",  desc = "create" },
								["r"]     = { "browse_rename",  desc = "rename" },
								["d"]     = { "browse_delete",  desc = "delete" },
								["c"]     = { "browse_copy",    desc = "copy" },
								["y"]     = { "browse_yank_file", desc = "yank file" },
								["p"]     = { "browse_paste",     desc = "paste file" },
								["Y"]     = { "browse_yank_path", desc = "yank path" },
							},
						},
					},
				},
				-- ── Notifications ───────────────────────────────────────
				-- snacks' <CR> only closes the picker, so anything longer
				-- than the preview pane is gone the moment you act on it.
				-- Open the message in a float instead.
				notifications = {
					confirm = function(picker, item)
						picker:close()
						if not item then return end
						vim.schedule(function() open_notification(item.item) end)
					end,
				},
			},
			-- <c-o> on any file in any picker opens Oil in that file's parent dir.
			-- If a floating Oil window is already open, navigates it there instead of
			-- opening a new buffer -- keeps the float as the "active" Oil pane.
			actions = {
				-- The help overlay is not focusable, so <Esc> is still handled by the
				-- input window and would close the whole picker out from under it.
				dismiss_help = function(picker)
					for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
						if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "snacks_win_help" then
							return vim.api.nvim_win_close(win, true)
						end
					end
					picker:close()
				end,
				-- The overlay's dismiss keys are not written down anywhere else, and
				-- its "top" border can carry a title but not a footer.
				help_input = function(picker)
					picker.input.win:toggle_help({ win = { title = help_title, title_pos = "center" } })
				end,
				help_list = function(picker)
					picker.list.win:toggle_help({ win = { title = help_title, title_pos = "center" } })
				end,
				open_oil_dir = function(picker)
					local item = picker:current()
					if not item then return end
					local path = item.file or item.dir
					if not path then return end
					local dir = vim.fn.fnamemodify(path, ":h")
					picker:close()
					-- Find an existing floating Oil window to reuse
					local oil_float_win = nil
					for _, winid in ipairs(vim.api.nvim_list_wins()) do
						local cfg = vim.api.nvim_win_get_config(winid)
						if cfg.relative ~= "" then
							local buf = vim.api.nvim_win_get_buf(winid)
							if vim.bo[buf].filetype == "oil" then
								oil_float_win = winid
								break
							end
						end
					end
					if oil_float_win then
						vim.api.nvim_set_current_win(oil_float_win)
					end
					require("oil").open(dir)
				end,
			},
			win = {
				input = {
					keys = {
						["<c-o>"] = { "open_oil_dir", mode = { "i", "n" }, desc = "open Oil in file dir" },
						["<esc>"] = { "dismiss_help",  mode = { "i", "n" }, desc = "close help, else picker" },
						["<f1>"]  = { "help_input", mode = { "i", "n" }, desc = "toggle picker keys" },
					},
				},
				list = {
					keys = {
						["<esc>"] = { "dismiss_help",      desc = "close help, else picker" },
						["<f1>"]  = { "help_list",  desc = "toggle picker keys" },
					},
				},
			},
		},
		lsp = {
			progress = { enabled = true },
		},
		notifier = { enabled = true },
		notify   = { enabled = true },
		quickfile = { enabled = true },
		animate   = { enabled = true },
		scope     = { enabled = true },
		-- ── Scroll animation ───────────��──────────────────────────────
		scroll = {
			enabled = false, -- scroll animation can jitter on fast repeated keystrokes
			animate = {
				duration = { step = 15, total = 50 },
				easing = "linear",
			},
			animate_repeat = {
				delay = 100,
				duration = { step = 5, total = 25 },
				easing = "linear",
			},
			filter = function(buf)
				return vim.g.snacks_scroll ~= false
					and vim.b[buf].snacks_scroll ~= false
					and vim.bo[buf].buftype ~= "terminal"
			end,
		},
	},
	keys = {

		-- ── Window / UI panels ────────────────────────────────────────────
		{ "<c-w><c-e>", function() Snacks.explorer() end, desc = "file explorer (snacks)" },
		{
			"<c-w><c-p>",
			function() Snacks.picker() end,
			desc = "Open snacks picker",
		},
		{
			"<c-w><c-b>",
			function() Snacks.scratch() end,
			desc = "Toggle Scratch Buffer",
			mode = { "n", "i", "t" },
		},
		{
			SearchLeader .. "<c-b>",
			function() Snacks.scratch.select() end,
			desc = "Select Scratch Buffer",
		},

		-- ── Global actions ────────────────────────────────────────────────
		{
			"<leader>N",
			function()
				Snacks.win({
					file = vim.api.nvim_get_runtime_file("doc/news.txt", false)[1],
					width = 0.6,
					height = 0.6,
					wo = {
						spell = false,
						wrap = false,
						signcolumn = "yes",
						statuscolumn = " ",
						conceallevel = 3,
					},
				})
			end,
			desc = "Neovim News",
		},

		-- ── Fuzzy navigation (SearchLeader) ────────────────────────────────
		-- Convention: keys ending in `p` are project-scoped variants.

		-- File browser: fuzzy search + directory traversal (<BS> to go up, a/r/d/c for file ops)
		{ SearchLeader .. "<space>", function()
			Snacks.picker.browse({ title = vim.fn.fnamemodify(vim.uv.cwd(), ":~") })
		end, desc = "file browser" },
		-- Recent files
		{ SearchLeader .. "fo", function() Snacks.picker.recent({ title = "Recent Files" })        end, desc = "[f]ind r[e]cent" },
		-- Notifications
		{ SearchLeader .. "fn", function() Snacks.picker.notifications({ title = "Notifications" }) end, desc = "[f]ind [n]otifications" },
		-- Project files (git root)
		{
			SearchLeader .. "fp",
			function()
				local root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
				if not root or root:match("^fatal") then
					root = vim.fn.getcwd()
				end
				local name = vim.fn.fnamemodify(root, ":t")
				find_files_project_dir({
					title = "Project Files (" .. name .. ")",
				})
			end,
			desc = "[f]ind [p]roject files",
		},
		-- Find files
		{
			SearchLeader .. "ff",
			function() Snacks.picker.files() end,
			desc = "[f]ind [f]iles",
		},
		-- Current buffer fuzzy find
		{ SearchLeader .. "/",  function() Snacks.picker.lines({ title = "Buffer Lines" })    end, desc = "fuzzy search current buffer" },
		-- Command history (in cmdline)
		{ "<c-s-f>",   function() Snacks.picker.command_history() end, mode = { "c" }, desc = "command history" },
		-- find [b]uffer
		{ SearchLeader .. "fb", function() Snacks.picker.buffers({ title = "Buffers" })  end, desc = "[f]ind [b]uffer" },
		-- find [m]ark
		{ SearchLeader .. "fm", function() Snacks.picker.marks({ title = "Marks" })    end, desc = "[f]ind [m]ark" },
		-- find [h]elp
		{ SearchLeader .. "fh", function() Snacks.picker.help({ title = "Help Tags" })     end, desc = "[f]ind [h]elp tags" },
		-- find [c]ommands
		{ SearchLeader .. "fc", function() Snacks.picker.commands({ title = "Commands" }) end, desc = "[f]ind [c]ommands" },
		-- find [k]eymaps
		{ SearchLeader .. "fk", function() Snacks.picker.keymaps({ title = "Keymaps" })  end, desc = "[f]ind [k]eymaps" },
		-- find [u]ndo history
		{ SearchLeader .. "fu", function() Snacks.picker.undo({ title = "Undo History" }) end, desc = "[f]ind [u]ndo" },
		-- find [t]odo's
		{ SearchLeader .. "ft", function() Snacks.picker.todo_comments({ title = "Todo Comments" }) end, desc = "[f]ind [t]odo's" },
		-- [C]olorscheme
		{ SearchLeader .. "C",  function() Snacks.picker.colorschemes({ title = require("noethervim.util.colorscheme").picker_title() }) end, desc = "[C]olorscheme" },
		-- [R]esume last picker
		{ SearchLeader .. "r",  function() Snacks.picker.resume()   end, desc = "[R]esume" },

		-- ── Grep ──────────────────────────────────────────────────────────
		-- SearchLeader+go (grep obsidian) lives in lua/user/plugins/
		{ SearchLeader .. "gC", function() Snacks.picker.grep({ cwd = vim.fn.stdpath("config"),               title = "Grep Configuration" }) end, desc = "[g]rep [C]onfiguration" },
		{ SearchLeader .. "gc", function() Snacks.picker.grep({ cwd = vim.fn.stdpath("config") .. "/lua/",    title = "Grep Config Lua" }) end, desc = "[g]rep [c]onfig lua" },
		{ SearchLeader .. "gs", function() Snacks.picker.grep({ cwd = vim.fn.stdpath("config") .. "/LuaSnip/", title = "Grep Snippets" }) end, desc = "[g]rep [s]nippets" },
		{ SearchLeader .. "gg", function() Snacks.picker.grep({ title = "Grep" }) end, desc = "grep current directory" },
		{
			SearchLeader .. "gp",
			function()
				local root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
				if not root or root:match("^fatal") then
					root = vim.fn.getcwd()
				end
				local name = vim.fn.fnamemodify(root, ":t")
				Snacks.picker.grep({ cwd = root, title = "Grep Project (" .. name .. ")" })
			end,
			desc = "[g]rep [p]roject",
		},

		-- ── LSP ──────────────────────────────────────────────────────────
		{ SearchLeader .. "lr", function() Snacks.picker.lsp_references({ title = "LSP References" })         end, desc = "[l]sp [r]eferences" },
		{ SearchLeader .. "ld", function() Snacks.picker.lsp_definitions({ title = "LSP Definitions" })        end, desc = "[l]sp [d]efinitions" },
		{ SearchLeader .. "lo", function() Snacks.picker.lsp_symbols({ title = "LSP Symbols" })            end, desc = "[l]sp [o]utline" },
		{ SearchLeader .. "lp", function() Snacks.picker.lsp_workspace_symbols({ title = "LSP Workspace Symbols" })  end, desc = "[l]sp [p]roject symbols" },

		-- ── Git ──────────────────────────────────────────────────────────
		{ SearchLeader .. "fG", function() Snacks.picker.git_status({ title = "Git Changes" })    end, desc = "[f]ind [G]it changes" },
		{ SearchLeader .. "Gc", function() Snacks.picker.git_log({ title = "Git Commits" })       end, desc = "[G]it [c]ommits" },
		{ SearchLeader .. "Gf", function() Snacks.picker.git_files({ title = "Git Files" })     end, desc = "[G]it [f]iles" },
		{ SearchLeader .. "GS", function() Snacks.picker.git_stash({ title = "Git Stash" })     end, desc = "[G]it [S]tash" },
		{ SearchLeader .. "Gs", function() Snacks.picker.git_status({ title = "Git Status" })    end, desc = "[G]it [s]tatus" },
		{ SearchLeader .. "Gb", function() Snacks.picker.git_log_file({ title = "Git Buffer Commits" })  end, desc = "[G]it [b]uffer commits" },

		-- ── Diagnostics ───────────────────────────────────────────────────
		{ SearchLeader .. "dd", function() Snacks.picker.diagnostics_buffer({ title = "Diagnostics (Buffer)" }) end,                                          desc = "[d]iagnostics (buffer)" },
		{ SearchLeader .. "dp", function() Snacks.picker.diagnostics({ title = "Diagnostics (Project)" }) end,                                                 desc = "[d]iagnostics [p]roject" },
		-- ── Config navigation (SearchLeader+c = user config) ──────────────
		-- All SearchLeader+c* targets stdpath("config") so they always open the
		-- current user's own config files, regardless of NVIM_APPNAME.
		-- Personal/filetype-specific shortcuts belong in lua/user/plugins/.
		-- `p` reserved for project scope; use `L` for Lazy plugin list.
		{ SearchLeader .. "cL", function() Snacks.picker.lazy({ title = "Lazy Plugins" }) end,                                                             desc = "[L]azy plugins" },
		{ SearchLeader .. "cu", function()
			local dir = vim.fn.stdpath("config") .. "/lua/user/"
			if not vim.uv.fs_stat(dir) then return vim.notify("No user config yet -- create lua/user/ in your config dir", vim.log.levels.WARN) end
			Snacks.picker.files({ cwd = dir, title = "User Settings" })
		end, desc = "[u]ser settings" },
		{ SearchLeader .. "cc", function()
			local dir = vim.fn.stdpath("config") .. "/lua/"
			if not vim.uv.fs_stat(dir) then return vim.notify("No lua/ dir yet -- see :help noethervim-user-config", vim.log.levels.WARN) end
			Snacks.picker.files({ cwd = dir, title = "User Lua Files" })
		end, desc = "[c]onfig lua" },
		-- document / project navigation keymaps are personal -- add yours in lua/user/plugins/
	},
	config = function(_, opts)
		require("snacks").setup(opts)
		-- Register a custom footer section that mirrors M.sections.startup but adds version.
		-- Must run after snacks is set up so require("snacks.dashboard") resolves.
		local dash = require("snacks.dashboard")

		dash.sections.noether_footer = function()
			-- Set the footer highlight at render time so it's guaranteed to
			-- exist before the extmark references it.
			vim.api.nvim_set_hl(0, "NoetherVimDashFooter", { link = "DiagnosticInfo" })
			local stats = (dash.lazy_stats and dash.lazy_stats.startuptime > 0 and dash.lazy_stats)
				or require("lazy").stats()
			local v = vim.version()
			local ms = math.floor(stats.startuptime * 100 + 0.5) / 100
			return {
				align = "center",
				text = {
					{
						string.format(" v%d.%d.%d   󰂖  %d/%d plugins   %sms",
							v.major, v.minor, v.patch,
							stats.loaded, stats.count, ms),
						hl = "NoetherVimDashFooter",
					},
				},
			}
		end

		-- Workaround for snacks.nvim #2724: the dashboard registers one handler
		-- on both BufDelete and BufWipeout that calls nvim_del_augroup_by_id.
		-- When the bufhidden=wipe dashboard buffer is replaced (e.g. selecting
		-- a file from Snacks.picker.recent()), both events fire in sequence and
		-- the second call errors with E367. We hook the User SnacksDashboardOpened
		-- event (fired after dashboard:init registers the buggy autocmd) and
		-- replace it with a pcall'd version. FileType won't work here because
		-- snacks sets `eventignore=all` while setting the buffer's filetype.
		-- Remove once PR #2725 merges.
		vim.api.nvim_create_autocmd("User", {
			pattern = "SnacksDashboardOpened",
			callback = function()
				for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
					if vim.bo[bufnr].filetype == "snacks_dashboard" then
						for _, ac in ipairs(vim.api.nvim_get_autocmds({
							event = { "BufDelete", "BufWipeout" },
							buffer = bufnr,
						})) do
							pcall(vim.api.nvim_del_autocmd, ac.id)
						end
						local augroup = vim.api.nvim_create_augroup("snacks_dashboard", { clear = false })
						vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
							buffer = bufnr,
							callback = function()
								vim.api.nvim_exec_autocmds("User", {
									pattern = "SnacksDashboardClosed",
									modeline = false,
								})
								pcall(vim.api.nvim_del_augroup_by_id, augroup)
							end,
						})
					end
				end
			end,
		})
	end,
}
