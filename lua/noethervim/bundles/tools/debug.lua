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

---Populate the quickfix list with breakpoints and open it in Snacks.
dap_pickers.list_breakpoints = function()
	require("dap").list_breakpoints(false)
	require("snacks").picker.qflist({ title = "DAP Breakpoints" })
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

			-- Define a highlight for the line the debugger is currently stopped on.
			-- Linked to Visual so it tracks the active colorscheme, and re-applied on
			-- ColorScheme events so theme switches don't blank it out.
			local function apply_dap_stopped_line()
				vim.api.nvim_set_hl(0, "DapStoppedLine", { link = "Visual", default = true })
			end
			apply_dap_stopped_line()
			vim.api.nvim_create_autocmd("ColorScheme", {
				group    = vim.api.nvim_create_augroup("noethervim_dap_highlights", { clear = true }),
				callback = apply_dap_stopped_line,
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
