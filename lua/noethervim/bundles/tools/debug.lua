-- NoetherVim bundle: Debug (DAP)
-- Enable with: { import = "noethervim.bundles.tools.debug" }
--
-- Provides:
--   • nvim-dap + nvim-dap-ui (multi-panel sidebar), virtual text,
--     language adapters (Python, Neovim Lua, JS/TS via vscode-js-debug, Go)
--   • inline snacks pickers: SearchLeader+D* for commands/breakpoints/variables/frames
--     (replaces telescope-dap, see dev-docs/telescope-removal-plan.md §4 phase 3.3)
--
-- Related bundles (enable separately):
--   • test.lua:        neotest test runner
--   • repl.lua:        iron.nvim REPL
--   • task-runner.lua: overseer + compiler.nvim
--
-- Per-project adapter setup (add to ~/.config/<appname>/lua/user/plugins/):
--   require('dap-python').setup('/path/to/python3')
local SearchLeader = require("noethervim.util").search_leader

-- ─── DAP snacks pickers ────────────────────────────────────────────────────
-- Five thin pickers that read from dap state and feed Snacks.picker.
-- Behavioural parity with telescope-dap, minus its treesitter-based variable
-- location enrichment (not critical; restore if requested).

local dap_pickers = {}

---List every function exposed by the `dap` module and run the one selected.
dap_pickers.commands = function()
	local dap = require("dap")
	local items = {}
	for k, v in pairs(dap) do
		if type(v) == "function" then
			table.insert(items, { text = k, _name = k })
		end
	end
	require("snacks").picker({
		title   = "DAP Commands",
		items   = items,
		format  = function(item) return { { item._name } } end,
		confirm = function(picker, item)
			picker:close()
			if item then dap[item._name]() end
		end,
	})
end

---List every dap configuration; dap.run() the one selected.
dap_pickers.configurations = function()
	local dap   = require("dap")
	local items = {}
	for _, configs in pairs(dap.configurations or {}) do
		for _, config in ipairs(configs) do
			table.insert(items, {
				text    = config.type .. ": " .. config.name,
				preview = { text = vim.inspect(config), ft = "lua" },
				_config = config,
			})
		end
	end
	if #items == 0 then
		vim.notify("[dap] no configurations loaded", vim.log.levels.INFO)
		return
	end
	require("snacks").picker({
		title   = "DAP Configurations",
		items   = items,
		format  = function(item) return { { item.text } } end,
		preview = "preview",
		confirm = function(picker, item)
			picker:close()
			if not item then return end
			if item._config.request == "custom" then
				vim.cmd(item._config.command)
			else
				dap.run(item._config)
			end
		end,
	})
end

---List all breakpoints; jump to the selected one, or <C-d> to delete it.
dap_pickers.list_breakpoints = function()
	local breakpoints = require("dap.breakpoints")
	local items = {}
	for bufnr, buf_bps in pairs(breakpoints.get()) do
		local path = vim.api.nvim_buf_get_name(bufnr)
		local rel  = vim.fn.fnamemodify(path, ":.")
		for _, bp in ipairs(buf_bps) do
			local ok, lines = pcall(vim.api.nvim_buf_get_lines, bufnr, bp.line - 1, bp.line, false)
			local line = (ok and lines[1]) or ""
			table.insert(items, {
				text   = string.format("%s:%d %s", rel, bp.line, line),
				file   = path,
				pos    = { bp.line, 0 },
				_bufnr = bufnr,
				_lnum  = bp.line,
				_label = string.format("%s:%d", rel, bp.line),
				_line  = vim.trim(line),
				_cond  = bp.condition,
				_log   = bp.logMessage,
			})
		end
	end
	if #items == 0 then
		vim.notify("[dap] no breakpoints", vim.log.levels.INFO)
		return
	end
	require("snacks").picker({
		title   = "DAP Breakpoints",
		items   = items,
		preview = "file",
		format  = function(item)
			local ret = {}
			ret[#ret + 1] = { item._label, "SnacksPickerFile" }
			if item._cond then
				ret[#ret + 1] = { " [cond: ", "Comment" }
				ret[#ret + 1] = { item._cond, "DiagnosticWarn" }
				ret[#ret + 1] = { "]", "Comment" }
			end
			if item._log then
				ret[#ret + 1] = { " [log: ", "Comment" }
				ret[#ret + 1] = { item._log, "DiagnosticHint" }
				ret[#ret + 1] = { "]", "Comment" }
			end
			if item._line ~= "" then
				ret[#ret + 1] = { "  " .. item._line, "Comment" }
			end
			return ret
		end,
		actions = {
			dap_delete_breakpoint = function(picker)
				local item = picker:current()
				if not item then return end
				breakpoints.remove(item._bufnr, item._lnum)
				-- Match dap.toggle_breakpoint: push the buffer's remaining breakpoints
				-- to any live sessions so the adapter stays in sync.
				local remaining = breakpoints.get(item._bufnr)
				for _, s in pairs(require("dap").sessions()) do
					s:set_breakpoints(remaining)
				end
				picker:close()
				vim.schedule(dap_pickers.list_breakpoints)
			end,
		},
		win = {
			input = { keys = { ["<C-d>"] = { "dap_delete_breakpoint", mode = { "i", "n" }, desc = "delete breakpoint" } } },
			list  = { keys = { ["<C-d>"] = { "dap_delete_breakpoint", desc = "delete breakpoint" } } },
		},
	})
end

---List variables in the current frame's scopes.
dap_pickers.variables = function()
	local session = require("dap").session()
	local frame   = session and session.current_frame
	if not frame then
		vim.notify("[dap] no active frame", vim.log.levels.INFO)
		return
	end
	local items = {}
	for _, scope in pairs(frame.scopes or {}) do
		for _, v in pairs(scope.variables or {}) do
			if v.type ~= "" and v.value ~= "" then
				local line = string.format("%s(%s) = %s", v.name, v.type,
					(v.value or ""):gsub("\n", " "))
				table.insert(items, { text = line, _var = v })
			end
		end
	end
	require("snacks").picker({
		title   = "DAP Variables",
		items   = items,
		format  = function(item) return { { item.text } } end,
	})
end

-- ─── Callstack line highlighting ──────────────────────────────────────────
-- Dim every line on the current stack that isn't the active frame, so the
-- call chain is visible in-buffer. Redrawn on stop and on frame switches
-- (after.scopes fires on any frame change); cleared on continue/exit.

local callstack_ns     = vim.api.nvim_create_namespace("noethervim_dap_callstack")
local callstack_frames = {}

local function callstack_clear_all()
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(bufnr) then
			vim.api.nvim_buf_clear_namespace(bufnr, callstack_ns, 0, -1)
		end
	end
end

local function callstack_current_id()
	local s = require("dap").session()
	return s and s.current_frame and s.current_frame.id or nil
end

local function callstack_draw_in_buf(bufnr, path)
	vim.api.nvim_buf_clear_namespace(bufnr, callstack_ns, 0, -1)
	local current_id = callstack_current_id()
	for _, fr in ipairs(callstack_frames) do
		local fr_path = fr.source and fr.source.path
		if fr_path == path and fr.line and fr.id ~= current_id then
			pcall(vim.api.nvim_buf_set_extmark, bufnr, callstack_ns, fr.line - 1, 0, {
				line_hl_group = "DapCallStackFrame",
				priority      = 10,
			})
		end
	end
end

local function callstack_redraw()
	callstack_clear_all()
	local by_path = {}
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(bufnr) then
			local name = vim.api.nvim_buf_get_name(bufnr)
			if name ~= "" then by_path[name] = bufnr end
		end
	end
	local current_id = callstack_current_id()
	for _, fr in ipairs(callstack_frames) do
		local fr_path = fr.source and fr.source.path
		if fr_path and fr.line and fr.id ~= current_id then
			local bufnr = by_path[fr_path]
			if bufnr then
				pcall(vim.api.nvim_buf_set_extmark, bufnr, callstack_ns, fr.line - 1, 0, {
					line_hl_group = "DapCallStackFrame",
					priority      = 10,
				})
			end
		end
	end
end

---List the current call stack; jump to the selected frame.
dap_pickers.frames = function()
	local session = require("dap").session()
	if not session or not session.stopped_thread_id then
		vim.notify("[dap] cannot move frame — no stopped thread", vim.log.levels.INFO)
		return
	end
	local frames = session.threads[session.stopped_thread_id].frames
	local items  = {}
	for _, fr in ipairs(frames) do
		table.insert(items, {
			text = fr.name,
			file = fr.source and fr.source.path or nil,
			pos  = { fr.line or 1, fr.column or 0 },
			_frame = fr,
		})
	end
	require("snacks").picker({
		title   = "DAP Frames",
		items   = items,
		format  = function(item) return { { item.text } } end,
		confirm = function(picker, item)
			picker:close()
			if item then session:_frame_set(item._frame) end
		end,
	})
end

return {

	-- ── DAP client ────────────────────────────────────────────────────────────
	{ -- Debug Adapter Protocol client
		"mfussenegger/nvim-dap",
		dependencies = {
			{
				"rcarriga/nvim-dap-ui",
				dependencies = { "nvim-neotest/nvim-nio" },
				lazy = true,
				opts = {
					-- Right sidebar holds inspection panels simultaneously.
					-- Bottom tray holds interactive REPL + process console.
					layouts = {
						{
							position = "right",
							size = 50,
							elements = {
								{ id = "scopes",      size = 0.30 },
								{ id = "watches",     size = 0.25 },
								{ id = "stacks",      size = 0.25 },
								{ id = "breakpoints", size = 0.20 },
							},
						},
						{
							position = "bottom",
							size = 10,
							elements = {
								{ id = "repl",    size = 0.5 },
								{ id = "console", size = 0.5 },
							},
						},
					},
					controls = { enabled = true, element = "repl" },
					floating = { border = "rounded" },
				},
			},
			{
				"theHamsta/nvim-dap-virtual-text",
				config = function()
					require("nvim-dap-virtual-text").setup()
				end,
			},
			{ "mfussenegger/nvim-dap-python" },
			{
				"jbyuki/one-small-step-for-vimkind",
				keys = { {
					"<leader>dal",
					function() require("osv").launch({ port = 8086 }) end,
					desc = "DAP: attach Lua",
				} },
			},
			{
				"mxsdev/nvim-dap-vscode-js",
				opts = {
					debugger_path = vim.fn.stdpath("data") .. "/lazy/vscode-js-debug",
					adapters = { "pwa-node", "pwa-chrome", "pwa-msedge", "node-terminal", "pwa-extensionHost" },
				},
			},
			{
				"microsoft/vscode-js-debug",
				version = "1.x",
				build   = "npm i && npm run compile vsDebugServerBundle && mv dist out",
			},
		},
		keys = {
			{ "<F5>",  function() require("dap").continue()                                        end, desc = "DAP: Continue" },
			{ "<F6>",  function() require("dap").restart()                                         end, desc = "DAP: Restart" },
			{ "<F17>", function() require("dap").terminate()                                       end, desc = "DAP: Terminate" }, -- <S-F5>
			{ "<F10>", function() require("dap").step_over()                                       end, desc = "DAP: Step Over" },
			{ "<F11>", function() require("dap").step_into()                                       end, desc = "DAP: Step Into" },
			{ "<F23>", function() require("dap").step_out()                                        end, desc = "DAP: Step Out" }, -- <S-F11>
			{ "<leader>db", function() require("dap").toggle_breakpoint()                          end, desc = "DAP: Toggle Breakpoint" },
			{ "<leader>dc", function()
				require("dap").clear_breakpoints()
				vim.notify("Cleared Breakpoints", 2, { title = "Debugger", icon = require("noethervim.util.icons").debug })
			end, desc = "DAP: Clear Breakpoints" },
			{ "<leader>dR", function() require("dap").run_to_cursor()                              end, desc = "DAP: Run to Cursor" },
			{ "<leader>dj", function() require("dap").focus_frame()                                end, desc = "DAP: Jump to Current Frame" },
			{ "<leader>dr", "<cmd>DapVirtualTextForceRefresh<cr>",                                     desc = "DAP: Refresh Virtual Text" },
			{ "<leader>di", function() require("dap.ui.widgets").hover()                           end, desc = "DAP: Information" },
			{ "<leader>de", function() require("dapui").eval()                                     end, mode = { "n", "v" }, desc = "DAP: Evaluate" },
			{ "<leader>dE", function() require("dapui").eval(vim.fn.input("Expression > "))        end, desc = "DAP: Evaluate Input" },
			{ "<leader>dC", function() require("dap").set_breakpoint(vim.fn.input("[Condition] > ")) end, desc = "DAP: Conditional Breakpoint" },
			{ "<leader>dl", function() require("dap").set_breakpoint(nil, nil, vim.fn.input("Log point message: ")) end, desc = "DAP: Log Breakpoint" },
			{ "<leader>du", function() require("dapui").toggle()                                   end, desc = "DAP: Toggle UI" },
			{ "<c-w><c-d>", function() require("dapui").toggle()                                   end, desc = "DAP: Toggle UI" },
			{ "<leader>dg", function() require("dap").session()                                    end, desc = "DAP: Get Session" },
			{ "<leader>dp", function() require("dap").pause()                                      end, desc = "DAP: Pause" },
			{ "<leader>dq", function() require("dap").close()                                      end, desc = "DAP: Quit" },
			{ "<leader>dw", function() require("dapui").elements.watches.add(vim.fn.expand("<cword>")) end, desc = "DAP: Watch Word" },
			{ "<leader>dt", function() require("dap").disconnect()                                 end, desc = "DAP: Disconnect" },
		},
		config = function()
			local dap   = require("dap")
			local dapui = require("dapui")
			local ic    = require("noethervim.util.icons")

			-- Highlights for the active stopped line (Visual-bright) and for
			-- ancestor callstack frames. The ancestor bg is derived by blending
			-- Normal toward Visual so it sits between "ignore" and "active stop",
			-- and stays distinct from CursorLine when the cursor lands on it.
			-- Re-applied on ColorScheme so theme switches refresh the blend.
			local function hl_bg(name)
				local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
				if ok and hl and hl.bg then return hl.bg end
			end
			local function blend(base, mix, alpha)
				local r1, g1, b1 = math.floor(base / 65536) % 256, math.floor(base / 256) % 256, base % 256
				local r2, g2, b2 = math.floor(mix  / 65536) % 256, math.floor(mix  / 256) % 256, mix  % 256
				return string.format("#%02x%02x%02x",
					math.floor(r1 + (r2 - r1) * alpha + 0.5),
					math.floor(g1 + (g2 - g1) * alpha + 0.5),
					math.floor(b1 + (b2 - b1) * alpha + 0.5))
			end
			local function apply_dap_highlights()
				vim.api.nvim_set_hl(0, "DapStoppedLine", { link = "Visual", default = true })
				local nbg, vbg = hl_bg("Normal"), hl_bg("Visual")
				if nbg and vbg then
					vim.api.nvim_set_hl(0, "DapCallStackFrame", { bg = blend(nbg, vbg, 0.30), default = true })
				else
					vim.api.nvim_set_hl(0, "DapCallStackFrame", { link = "CursorLine", default = true })
				end
			end
			apply_dap_highlights()
			vim.api.nvim_create_autocmd("ColorScheme", {
				group    = vim.api.nvim_create_augroup("noethervim_dap_highlights", { clear = true }),
				callback = apply_dap_highlights,
			})

			-- texthl uses DiagnosticSign* (not Diagnostic*) so colorscheme
			-- attrs meant for virtual text (italic, bg, underline) don't leak
			-- into the signcolumn glyph. Sign groups are normalized to fg-only
			-- in highlights.lua.
			local signs = {
				Stopped             = { ic.dap_stopped,              "DiagnosticSignWarn",  "DapStoppedLine" },
				Breakpoint          = { ic.dap_breakpoint,           "DiagnosticSignError" },
				BreakpointCondition = { ic.dap_breakpoint_condition, "DiagnosticSignWarn"  },
				BreakpointRejected  = { ic.dap_breakpoint_rejected,  "DiagnosticSignError" },
				LogPoint            = { ic.dap_log_point,            "DiagnosticSignInfo"  },
			}
			for name, sign in pairs(signs) do
				vim.fn.sign_define("Dap" .. name, {
					text   = sign[1],
					texthl = sign[2] or "DiagnosticSignInfo",
					linehl = sign[3],
					numhl  = sign[3],
				})
			end

			dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open({}) end
			dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close({}) end
			dap.listeners.before.event_exited["dapui_config"]     = function() dapui.close({}) end

			-- Callstack ghost highlights: fetch the stack on stop, redraw on
			-- frame switches (after.scopes fires whenever current_frame moves),
			-- clear on continue/exit, and paint newly-opened files mid-session.
			dap.listeners.after.event_stopped["noethervim_callstack"] = function(session, body)
				local tid = (body and body.threadId) or session.stopped_thread_id
				if not tid then return end
				session:request("stackTrace", { threadId = tid }, function(err, resp)
					if err or not resp then return end
					callstack_frames = resp.stackFrames or {}
					vim.schedule(callstack_redraw)
				end)
			end
			dap.listeners.after.scopes["noethervim_callstack"] = function()
				if #callstack_frames > 0 then vim.schedule(callstack_redraw) end
			end
			for _, ev in ipairs({ "event_continued", "event_terminated", "event_exited" }) do
				dap.listeners.before[ev]["noethervim_callstack"] = function()
					callstack_frames = {}
					vim.schedule(callstack_clear_all)
				end
			end
			vim.api.nvim_create_autocmd("BufReadPost", {
				group    = vim.api.nvim_create_augroup("noethervim_dap_callstack_bufload", { clear = true }),
				callback = function(args)
					if #callstack_frames == 0 then return end
					local path = vim.api.nvim_buf_get_name(args.buf)
					if path ~= "" then callstack_draw_in_buf(args.buf, path) end
				end,
			})

			dap.configurations = {
				go = {
					{ type = "go", name = "Debug",               request = "launch", program = "${file}" },
					{ type = "go", name = "Debug test (go.mod)", request = "launch", mode = "test", program = "./${relativeFileDirname}" },
					{ type = "go", name = "Attach (Pick)",       mode = "local",  request = "attach", processId = require("dap.utils").pick_process },
					{ type = "go", name = "Attach (remote)",     mode = "remote", request = "attach", port = "9080" },
				},
				javascript = {
					{ type = "pwa-node", name = "Launch", request = "launch", program = "${file}", cwd = vim.fn.getcwd(), sourceMaps = true, protocol = "inspector", console = "integratedTerminal" },
					{ type = "pwa-node", name = "Attach", request = "attach", program = "${file}", cwd = vim.fn.getcwd(), sourceMaps = true, protocol = "inspector", console = "integratedTerminal" },
				},
				lua = {
					{ type = "nlua", request = "attach", name = "Attach to running Neovim instance" },
				},
			}

			-- Lua DAP adapter (one-small-step-for-vimkind)
			dap.adapters.nlua = function(callback, config)
				callback({ type = "server", host = config.host or "127.0.0.1", port = config.port or 8086 })
			end
		end,
	},

	-- ── Snacks pickers over DAP state (keymaps only; see dap_pickers above) ──
	{
		"mfussenegger/nvim-dap",
		dependencies = { "folke/snacks.nvim" },
		keys = {
			{ SearchLeader .. "Dc", function() dap_pickers.commands()         end, desc = "[d]ebug [c]ommands" },
			{ SearchLeader .. "DC", function() dap_pickers.configurations()   end, desc = "[d]ebug [C]onfigurations" },
			{ SearchLeader .. "Db", function() dap_pickers.list_breakpoints() end, desc = "[d]ebug [b]reakpoints" },
			{ SearchLeader .. "Dv", function() dap_pickers.variables()        end, desc = "[d]ebug [v]ariables" },
			{ SearchLeader .. "Df", function() dap_pickers.frames()           end, desc = "[d]ebug [f]rames" },
		},
	},

}
