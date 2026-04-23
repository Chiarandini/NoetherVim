-- NoetherVim plugin: Telescope
--  ╔══════════════════════════════════════════════════════════╗
--  ║                     Telescope Setup                      ║
--  ╚══════════════════════════════════════════════════════════╝
-- Hints: Do <c-/> to see more options in any Telescope picker.
--
-- Override any value in opts via a user plugin spec:
--   { "nvim-telescope/telescope.nvim", opts = { defaults = { layout_strategy = "vertical" } } }

local function get_open_command()
  if vim.fn.has("macunix") == 1 then return "open"
  elseif vim.fn.has("win32") == 1 then return "start"
  else return "xdg-open"
  end
end

return {
	{
		"nvim-telescope/telescope.nvim",
		version      = false,
		dependencies = {
			{ "nvim-lua/plenary.nvim" },
			{ "nvim-lua/popup.nvim" },
			-- Note: Chiarandini/telescope-cached-headings.nvim is now pulled
			-- in by lua/noethervim/plugins/cached-headings.lua (the snacks
			-- picker shares that plugin's cache/parser/utils modules).
		},
		cmd = "Telescope",

		-- ── Overridable data ─────────────────────────────────────────
		-- All static configuration lives here so users can override
		-- individual values via lazy.nvim spec merging.
		-- Note: defaults.mappings and per-picker mappings reference
		-- telescope.actions (unavailable at spec-parse time) and are
		-- injected by config() below.  User mapping overrides in opts
		-- take precedence — see the vim.tbl_deep_extend("keep") calls.
		opts = {
			defaults = {
				layout_strategy      = "horizontal",
				selection_caret      = " ",
				entry_prefix         = " ",
				path_display         = { "smart" },
				file_ignore_patterns = { ".git/" },
			},
			pickers = {
				colorscheme = { enable_preview = true },
			},
			extensions = {
				-- cached_headings opts have moved to
				-- lua/noethervim/plugins/cached-headings.lua (snacks backend).
				-- latex_labels config consumed by telescope-latex-references
				-- when the latex bundle is enabled.
				latex_labels = {
					cache_strategy    = "global",
					recursive         = true,
					auto_update       = true,
					enable_smart_jump = true,
					smart_jump_window = 200,
					root_file         = "",
					subfile_toggle_key = "<C-g>",
					transformations = {
						thm = "th:", prop = "pr:", defn = "df:", lem = "lm:",
						cor = "co:", example = "ex:", exercise = "x:", titledBox = "box:",
					},
					copy_transform = {
						["df:"] = "\\cref{%s}", ["lm:"] = "\\cref{%s}",
						["th:"] = "\\cref{%s}", ["co:"] = "\\cref{%s}",
						["pr:"] = "\\cref{%s}", ["box:"] = "\\cref{%s}",
						["ex:"] = "example~\\ref{%s}", ["eq:"] = "equation~\\eqref{%s}",
					},
					patterns = {
						{ pattern = "\\begin{(%w+)}{(.-)}{(.-)}", type = "environment" },
						{ pattern = "\\label{(.-)}", type = "standard" },
					},
				},
				-- bibtex config consumed by telescope-bibtex (latex bundle).
				bibtex = {
					depth                  = 1,
					custom_formats         = {},
					format                 = "",
					global_files           = {},
					search_keys            = { "author", "year", "title" },
					citation_format        = "{{author}} ({{year}}), {{title}}.",
					citation_trim_firstname = true,
					citation_max_auth      = 2,
					context                = true,
					context_fallback       = true,
					wrap                   = false,
				},
				},
		},

		config = function(_, opts)
			local telescope      = require("telescope")
			local actions        = require("telescope.actions")
			local action_state   = require("telescope.actions.state")
			-- ── Custom action functions ──────────────────────────────────
			local function change_directory(prompt_bufnr)
				local selection = action_state.get_selected_entry()
				local dir = vim.fn.fnamemodify(selection.path, ":p:h")
				actions.close(prompt_bufnr)
				vim.cmd(string.format("cd %s", dir))
				print("changed directory to " .. dir)
			end

			local function yank_path(prompt_bufnr)
				local selection = action_state.get_selected_entry()
				local dir = vim.fn.fnamemodify(selection.path, ":p:h")
				vim.fn.setreg("*", dir)
				print("copied path to clipboard")
				actions.close(prompt_bufnr)
			end

			local function yank_entry(prompt_bufnr)
				local selection = action_state.get_selected_entry()
				vim.print(selection)
				local symbol_name = selection.symbol_name
				vim.fn.setreg('"', symbol_name)
				vim.notify("yanked symbol " .. symbol_name, 2,
					{ title = "Telescope", icon = require("noethervim.util.icons").loup })
				actions.close(prompt_bufnr)
			end

			local function delete_buffer(prompt_bufnr)
				local selection = action_state.get_selected_entry()
				vim.cmd("bdelete" .. selection.bufnr .. "")
				print("buffer " .. selection.bufnr .. " (" .. selection.filename .. ") deleted")
			end

			local function select_and_delete_buffer(prompt_bufnr)
				vim.cmd("bdelete " .. prompt_bufnr)
				actions.select_default(prompt_bufnr)
			end

			local function execute_file(prompt_bufnr)
				local selection = action_state.get_selected_entry()
				local open_cmd = get_open_command()
				vim.fn.jobstart({ open_cmd, selection.path }, { detach = true })
				actions.close(prompt_bufnr)
			end

			-- ── Inject action-based mappings into opts ───────────────────
			-- "keep" means user-provided values in opts take precedence;
			-- core defaults fill in any keys the user didn't specify.

			opts.defaults.mappings = vim.tbl_deep_extend("keep", opts.defaults.mappings or {}, {
				i = {
					["<C-n>"]   = actions.cycle_history_next,
					["<C-p>"]   = actions.cycle_history_prev,
					["<C-j>"]   = actions.move_selection_next,
					["<C-k>"]   = actions.move_selection_previous,
					["<C-b>"]   = actions.results_scrolling_up,
					["<C-f>"]   = actions.results_scrolling_down,
					["<C-c>"]   = actions.close,
					["<Down>"]  = actions.move_selection_next,
					["<Up>"]    = actions.move_selection_previous,
					["<CR>"]    = actions.select_default,
					["<C-x>"]   = execute_file,
					["<C-v>"]   = actions.select_vertical,
					["<C-t>"]   = actions.select_tab,
					["<c-y>"]   = yank_entry,
					["<Tab>"]   = actions.close,
					["<S-Tab>"] = actions.close,
					["<C-q>"]   = actions.send_to_qflist + actions.open_qflist,
					["<M-q>"]   = actions.send_selected_to_qflist + actions.open_qflist,
					["<C-l>"]   = actions.complete_tag,
					["<C-h>"]   = actions.which_key,
					["<esc>"]   = actions.close,
				},
				n = {
					["<esc>"]    = actions.close,
					["<CR>"]     = actions.select_default,
					["<C-x>"]    = actions.select_horizontal,
					["<C-v>"]    = actions.select_vertical,
					["<C-t>"]    = actions.select_tab,
					["<C-b>"]    = actions.results_scrolling_up,
					["<C-f>"]    = actions.results_scrolling_down,
					["<Tab>"]    = actions.close,
					["<S-Tab>"]  = actions.close,
					["<C-q>"]    = actions.send_to_qflist + actions.open_qflist,
					["<M-q>"]    = actions.send_selected_to_qflist + actions.open_qflist,
					["j"]        = actions.move_selection_next,
					["k"]        = actions.move_selection_previous,
					["H"]        = actions.move_to_top,
					["M"]        = actions.move_to_middle,
					["L"]        = actions.move_to_bottom,
					["q"]        = actions.close,
					["dd"]       = actions.delete_buffer,
					["s"]        = actions.select_horizontal,
					["v"]        = actions.select_vertical,
					["t"]        = actions.select_tab,
					["<Down>"]   = actions.move_selection_next,
					["<Up>"]     = actions.move_selection_previous,
					["gg"]       = actions.move_to_top,
					["G"]        = actions.move_to_bottom,
					["<C-u>"]    = actions.preview_scrolling_up,
					["<C-d>"]    = actions.preview_scrolling_down,
					["<PageUp>"] = actions.results_scrolling_up,
					["<PageDown>"] = actions.results_scrolling_down,
					["?"]        = actions.which_key,
				},
			})

			-- Per-picker action mappings
			opts.pickers.old_files = vim.tbl_deep_extend("keep", opts.pickers.old_files or {}, {
				mappings = { i = {
					["<CR>"]   = select_and_delete_buffer,
					["<c-d>"]  = change_directory,
					["<c-y>"]  = yank_path,
				}},
			})
			opts.pickers.find_files = vim.tbl_deep_extend("keep", opts.pickers.find_files or {}, {
				mappings = { i = {
					["<c-d>"] = change_directory,
					["<c-y>"] = yank_path,
				}},
			})
			opts.pickers.buffers = vim.tbl_deep_extend("keep", opts.pickers.buffers or {}, {
				mappings = { i = { ["<c-d>"] = delete_buffer } },
			})

			-- ── Setup & extensions ───────────────────────────────────────
			telescope.setup(opts)
		end,
	},
}
