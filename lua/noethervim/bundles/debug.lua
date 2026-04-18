-- NoetherVim bundle: Debug (DAP)
-- Enable with: { import = "noethervim.bundles.debug" }
--
-- Provides:
--   • nvim-dap + nvim-dap-ui (multi-panel sidebar), virtual text,
--     language adapters (Python, Neovim Lua, JS/TS via vscode-js-debug, Go)
--   • telescope-dap:   SearchLeader+D* pickers for commands/breakpoints/variables/frames
--
-- Related bundles (enable separately):
--   • test.lua:        neotest test runner
--   • repl.lua:        iron.nvim REPL
--   • task-runner.lua: overseer + compiler.nvim
--
-- Per-project adapter setup (add to ~/.config/<appname>/lua/user/plugins/):
--   require('dap-python').setup('/path/to/python3')
local SearchLeader = require("noethervim.util").search_leader

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

	-- ── telescope-dap ─────────────────────────────────────────────────────────
	{
		"nvim-telescope/telescope-dap.nvim",
		dependencies = { "nvim-telescope/telescope.nvim", "mfussenegger/nvim-dap" },
		opts = {},
		config = function(_, opts)
			require("telescope").load_extension("dap")
		end,
		keys = {
			{ SearchLeader .. "Dc", function() require("telescope").extensions.dap.commands()         end, desc = "[d]ebug [c]ommands" },
			{ SearchLeader .. "DC", function() require("telescope").extensions.dap.configurations()   end, desc = "[d]ebug [C]onfigurations" },
			{ SearchLeader .. "Db", function() require("telescope").extensions.dap.list_breakpoints() end, desc = "[d]ebug [b]reakpoints" },
			{ SearchLeader .. "Dv", function() require("telescope").extensions.dap.variables()        end, desc = "[d]ebug [v]ariables" },
			{ SearchLeader .. "Df", function() require("telescope").extensions.dap.frames()           end, desc = "[d]ebug [f]rames" },
		},
	},

}
