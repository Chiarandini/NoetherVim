--- How to run the current file, and how to run the project around it.
---
--- This used to live in two places that disagreed: `plugins/code-runner.lua`
--- knew java, python, typescript and rust, while `bundles/tools/task-runner.lua`
--- knew a different thirteen and not rust. Adding a language meant remembering
--- both, and nobody did. One table, two consumers.
---
--- Each entry has:
---   `root`     project markers, searched upward from the buffer
---   `file`     how to run this one file
---   `project`  how to run the whole project, when a root was found
---
--- A string is an interpreter: the file path is appended to it. A function
--- receives the context below and returns a complete shell command, or nil
--- when the language cannot do that here.

local M = {}

---@class noethervim.RunContext
---@field file string       shell-escaped absolute path of the buffer
---@field dir  string       shell-escaped directory holding it
---@field stem string       shell-escaped path with the extension removed
---@field name string       bare filename, for task titles
---@field root string|nil   project root when a marker was found (unescaped)

---@class noethervim.RunSpec
---@field root?    string[]  project markers, searched upward from the buffer
---@field file?    string|fun(c: noethervim.RunContext):string|nil
---@field project? string|fun(c: noethervim.RunContext):string|nil

---@type table<string, noethervim.RunSpec>
M.languages = {
	-- Interpreted languages: the command is the interpreter, the file is its
	-- argument, and there is no project-level answer that is true in general.
	python     = { file = "python3 -u" },
	lua        = { file = "lua" },
	ruby       = { file = "ruby" },
	julia      = { file = "julia" },
	perl       = { file = "perl" },
	php        = { file = "php" },
	r          = { file = "Rscript" },
	sh         = { file = "sh" },
	bash       = { file = "bash" },
	zsh        = { file = "zsh" },

	javascript = { root = { "package.json" }, file = "node", project = "npm start --silent" },
	-- `node` rather than `tsx`: Node strips types natively from 22.6 and does
	-- it without a flag from 23, so a TypeScript file runs with the toolchain
	-- already required for JavaScript. Naming `tsx` meant claiming a binary
	-- nothing here installs, and the run failing with "command not found".
	typescript = { root = { "package.json" }, file = "node", project = "npm start --silent" },

	-- `go run .` builds the package in the working directory, which is what a
	-- Go "project run" means; `go run <file>` is the single-file form.
	go = { root = { "go.mod" }, file = "go run", project = "go run ." },

	-- Cargo searches upward for the manifest the same way this does, so the
	-- project command needs no path. Outside a crate, rustc still compiles a
	-- lone file.
	rust = {
		root    = { "Cargo.toml" },
		project = "cargo run",
		file    = function(c)
			if c.root then return "cargo run" end
			return ("rustc %s -o %s && %s"):format(c.file, c.stem, c.stem)
		end,
	},

	-- `java <file>` is the JDK 11+ single-file source launcher: it compiles in
	-- memory and honours the file's own `package` declaration. Compiling with
	-- javac and running `java -cp <dir> <Name>` looks equivalent and is not; it
	-- fails for any class in a package ("wrong name: capfixture/Main"), which
	-- is almost all real Java.
	java = {
		root = { "pom.xml", "build.gradle", "build.gradle.kts" },
		file = function(c) return "java " .. c.file end,
		project = function(c)
			if not c.root then return nil end
			if vim.uv.fs_stat(c.root .. "/pom.xml") then return "mvn -q compile exec:java" end
			return "./gradlew run"
		end,
	},

	c   = { root = { "Makefile", "CMakeLists.txt" }, project = "make",
	        file = function(c) return ("cc %s -o %s && %s"):format(c.file, c.stem, c.stem) end },
	cpp = { root = { "Makefile", "CMakeLists.txt" }, project = "make",
	        file = function(c) return ("c++ %s -o %s && %s"):format(c.file, c.stem, c.stem) end },
}

--- Describe the current buffer for the builders above.
---@param bufnr? integer
---@return noethervim.RunContext
function M.context(bufnr)
	bufnr = bufnr or 0
	local path = vim.api.nvim_buf_get_name(bufnr)
	local dir  = vim.fn.fnamemodify(path, ":p:h")
	local spec = M.languages[vim.bo[bufnr].filetype] or {}

	local root
	if spec.root then
		local found = vim.fs.find(spec.root, { upward = true, path = dir })[1]
		if found then root = vim.fs.dirname(found) end
	end

	return {
		file = vim.fn.shellescape(path),
		dir  = vim.fn.shellescape(dir),
		stem = vim.fn.shellescape(vim.fn.fnamemodify(path, ":p:r")),
		name = vim.fn.fnamemodify(path, ":t"),
		root = root,
	}
end

--- Build the command for one kind of run.
---
--- Returns the command and the directory to run it from, or nil when this
--- filetype has no answer for that kind. The caller decides how to report
--- that; there is no single right message for "cannot run a .txt".
---@param kind "file"|"project"
---@param bufnr? integer
---@return string|nil cmd, string|nil cwd
function M.command(kind, bufnr)
	bufnr = bufnr or 0
	local spec = M.languages[vim.bo[bufnr].filetype]
	if not spec then return nil end

	local entry = spec[kind]
	if not entry then return nil end

	local ctx = M.context(bufnr)

	-- A project run belongs in the project, a file run beside the file.
	-- Spelled out rather than `and/or`: that idiom falls through to the
	-- right-hand branch whenever the middle value is nil, which here would
	-- silently run a project command in a directory that has no project.
	local cwd
	if kind == "project" then
		if not ctx.root then return nil end
		cwd = ctx.root
	else
		cwd = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":p:h")
	end

	if type(entry) == "function" then
		local cmd = entry(ctx)
		if not cmd then return nil end
		return cmd, cwd
	end

	-- String form. For a file run it names an interpreter and wants the path;
	-- for a project run it is already the whole command, and appending the
	-- buffer would turn `cargo run` into `cargo run some/file.rs`.
	if kind == "file" then
		return entry .. " " .. ctx.file, cwd
	end
	return entry, cwd
end

return M
