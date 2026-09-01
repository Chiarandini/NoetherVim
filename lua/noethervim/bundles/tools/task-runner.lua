---@bundle task-runner
---@desc run builds and project tasks from the editor
---@about overseer.nvim runs and tracks tasks, compiler.nvim wraps it in a
---       project compiler UI, and <leader>rf and <leader>rp run the current
---       file or the project around it, respecting filetype, project markers
---       and version managers.
---@requires note="your project build tool"
---          why="overseer and compiler.nvim shell out to it"
---          install="make, cargo, latexmk, npm, ... whatever the project uses"
-- NoetherVim bundle: Task Runner
-- Enable with: { import = "noethervim.bundles.tools.task-runner" }
--
-- Provides:
--   overseer.nvim:    task runner  (:OverseerRun, :OverseerToggle)
--   compiler.nvim:    project compiler UI  (:CompilerOpen, :CompilerToggleResults)
--
-- Keymaps:
--   <leader>rf    run the current file
--   <leader>rp    run the project around it (cargo, go.mod, npm, Maven, make)
--   <c-w><c-r>   toggle task list

-- What each language runs comes from `noethervim.util.run`, shared with core's
-- code_runner so a language is taught once. What is local to this bundle is
-- running it through overseer, and resolving the interpreter through whichever
-- version manager governs the directory.
local run = require("noethervim.util.run")

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

--- Run the current file, or the project around it, as an overseer task.
---
--- The version-manager pass applies only to the interpreter forms, where the
--- command begins with a bare binary name we might resolve to a per-directory
--- install. A build tool invoked through its own project (`cargo run`,
--- `./gradlew run`, `make`) already resolves itself, and rewriting its first
--- word would be wrong.
---@param kind "file"|"project"
local function start_task(kind)
	local cmd, cwd = run.command(kind, 0)
	if not cmd or not cwd then
		local ft = vim.bo.filetype
		if kind == "project" then
			vim.notify(("No project to run for %s here (looked for %s)"):format(
				ft ~= "" and ft or "this buffer",
				table.concat((run.languages[ft] or {}).root or { "a project marker" }, ", ")),
				vim.log.levels.WARN)
		else
			vim.notify("No runner for filetype: " .. (ft ~= "" and ft or "(none)"), vim.log.levels.WARN)
		end
		return
	end

	local spec = run.languages[vim.bo.filetype] or {}
	if type(spec[kind]) == "string" then
		local bin = cmd:match("^(%S+)")
		cmd = resolve_runner(bin, cwd) .. cmd:sub(#bin + 1)
	end

	require("overseer").new_task({
		name = (kind == "project" and "Run project: " or "Run ") .. vim.fn.fnamemodify(cwd, ":t"),
		cmd  = cmd,
		cwd  = cwd,
		components = {
			"default",
			{ "on_complete_notify", statuses = { "SUCCESS", "FAILURE" } },
			"open_output",
		},
	}):start()
end

return {
	{
		"stevearc/overseer.nvim",
		cmd  = { "OverseerRun", "OverseerToggle" },
		keys = {
			{ "<leader>rf", function() start_task("file") end,    desc = "Run this [f]ile" },
			{ "<leader>rp", function() start_task("project") end, desc = "Run this [p]roject" },
			{ "<c-w><c-r>", "<cmd>OverseerToggle<cr>",            desc = "Task list" },
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

	-- compiler.nvim: we use a small Chiarandini/compiler.nvim fork that rebases
	-- the upstream PR #77 ("native nvim `vim.ui.select` support"). Upstream
	-- hard-requires telescope for its picker; PR #77 adds a vim.ui.select
	-- fallback that snacks intercepts, so :CompilerOpen works telescope-free.
	-- When upstream merges PR #77, switch back to "Zeioth/compiler.nvim".
	{
		"Chiarandini/compiler.nvim",
		cmd          = { "CompilerOpen", "CompilerToggleResults", "CompilerRedo" },
		dependencies = { "stevearc/overseer.nvim" },
		opts         = {},
	},
}
