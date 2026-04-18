-- NoetherVim bundle: Task Runner
-- Enable with: { import = "noethervim.bundles.tools.task-runner" }
--
-- Provides:
--   overseer.nvim:    task runner  (:OverseerRun, :OverseerToggle)
--   compiler.nvim:    project compiler UI  (:CompilerOpen, :CompilerToggleResults)
--
-- Keymaps:
--   <leader>rf    run current file (filetype-aware, version-manager-aware)
--   <c-w><c-r>   toggle task list

-- Filetype → interpreter command.
-- For commands with subcommands (e.g. "go run"), the first word is resolved
-- through version managers while the rest is preserved.
local runners = {
	python     = "python3",
	lua        = "lua",
	javascript = "node",
	typescript = "tsx",
	go         = "go run",
	sh         = "sh",
	bash       = "bash",
	zsh        = "zsh",
	ruby       = "ruby",
	julia      = "julia",
	perl       = "perl",
	r          = "Rscript",
	php        = "php",
}

-- General-purpose version managers, tried first in order.
-- All support `<manager> which <bin>` and respect per-directory config.
local general_managers = { "mise", "asdf" }

-- Language-specific version managers, keyed by the binary they manage.
-- Tried as a fallback when no general manager resolves the binary.
local lang_managers = {
	python3 = { "pyenv" },
	python  = { "pyenv" },
	ruby    = { "rbenv" },
	node    = { "nodenv" },
	go      = { "goenv" },
}

--- Try `<manager> which <bin>` in a given directory.
---@param manager string  e.g. "mise"
---@param bin string      e.g. "python3"
---@param dir string      directory context for resolution
---@return string|nil     full path to the binary, or nil on failure
local function try_manager(manager, bin, dir)
	if vim.fn.executable(manager) ~= 1 then return nil end
	local result = vim.system({ manager, "which", bin }, { cwd = dir, text = true }):wait()
	if result.code == 0 and result.stdout ~= "" then
		return vim.trim(result.stdout)
	end
	return nil
end

--- Resolve an interpreter for a given directory using available version
--- managers. Tries general-purpose managers first (mise, asdf), then
--- language-specific ones (pyenv, rbenv, nodenv, goenv), and falls back
--- to the unresolved command.
---@param cmd string   e.g. "python3" or "go run"
---@param dir string   directory whose version config should govern the lookup
---@return string      resolved command (full path + any trailing subcommand)
local function resolve_runner(cmd, dir)
	local bin  = cmd:match("^(%S+)")
	local rest = cmd:sub(#bin + 1)

	for _, manager in ipairs(general_managers) do
		local resolved = try_manager(manager, bin, dir)
		if resolved then return resolved .. rest end
	end

	local specific = lang_managers[bin]
	if specific then
		for _, manager in ipairs(specific) do
			local resolved = try_manager(manager, bin, dir)
			if resolved then return resolved .. rest end
		end
	end

	return cmd
end

return {
	{
		"stevearc/overseer.nvim",
		cmd  = { "OverseerRun", "OverseerToggle" },
		keys = {
			{
				"<leader>rf",
				function()
					local ft = vim.bo.filetype
					local cmd = runners[ft]
					if not cmd then
						vim.notify("No runner for filetype: " .. ft, vim.log.levels.WARN)
						return
					end

					local file = vim.fn.shellescape(vim.fn.expand("%:p"))
					local dir  = vim.fn.expand("%:p:h")
					local name = vim.fn.expand("%:t")

					cmd = resolve_runner(cmd, dir)

					require("overseer").new_task({
						name = "Run " .. name,
						cmd  = cmd .. " " .. file,
						cwd  = dir,
						components = {
							"default",
							{ "on_complete_notify", statuses = { "SUCCESS", "FAILURE" } },
							"open_output",
						},
					}):start()
				end,
				desc = "Run this [f]ile",
			},
			{ "<c-w><c-r>", "<cmd>OverseerToggle<cr>", desc = "Task list" },
		},
		opts = {
			task_list = {
				keymaps = {
					-- defaults use <C-j>/<C-k> which conflict with window navigation
					["<C-j>"] = false,
					["<C-k>"] = false,
					["<C-d>"] = "keymap.scroll_output_down",
					["<C-u>"] = "keymap.scroll_output_up",
				},
			},
		},
	},

	{
		"Zeioth/compiler.nvim",
		cmd          = { "CompilerOpen", "CompilerToggleResults", "CompilerRedo" },
		dependencies = { "stevearc/overseer.nvim", "nvim-telescope/telescope.nvim" },
		opts         = {},
	},
}
