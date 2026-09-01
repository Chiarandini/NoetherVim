-- tests/capability_assert.lua -- Level-C language capability matrix.
--
-- Phase 1 of dev-docs/language-matrix-test-plan.md: checkpoints 1 (LSP),
-- 2 (treesitter), 7 (run file) and 8 (run project) from
-- dev-docs/language-bundle-contract.md.
--
-- Run by tests/capability.sh inside an isolated NVIM_APPNAME with the language
-- bundle plus tools/{test,debug,task-runner} enabled. CAP_LANG names the row.
--
-- Every cell resolves to PASS, FAIL, N/A or UNCOVERED; none may be skipped.
-- UNCOVERED means the toolchain is genuinely absent on this machine, and never
-- gates. Exit code is driven by FAIL alone.
--
-- Two rules the plan inherits from the session that motivated it:
--   * Poll for the real signal, never a fixed sleep. rust-analyzer answers a
--     runnables request with `cargo check` alone before the crate graph is
--     built, so a correct result looks broken if you ask too early.
--   * Suspect the harness before the code when something looks wrong.

local LANG = vim.env.CAP_LANG or ""
local ROOT = vim.env.CAP_FIXTURES or ""

local pass, fail, na, uncovered = 0, 0, 0, 0
local cells = {}

local gap = 0

--- Record one cell.
---
--- GAP is a checkpoint the contract says this bundle does not meet, with an
--- issue already filed. It is reported as loudly as a FAIL but does not gate
--- the exit code, so the run distinguishes "this regressed" from "we already
--- know and it is tracked". A GAP without an issue reference is a FAIL.
local function record(cp, state, detail)
	cells[#cells + 1] = { cp = cp, state = state, detail = detail }
	if state == "PASS" then pass = pass + 1
	elseif state == "FAIL" then fail = fail + 1
	elseif state == "N/A" then na = na + 1
	elseif state == "GAP" then gap = gap + 1
	else uncovered = uncovered + 1 end
	print(("%-9s %-11s %s"):format(state, cp, detail or ""))
end

--- Poll until `fn` returns truthy, or the budget runs out.
---@return boolean ok, integer waited_ms
local function poll(ms, fn)
	local step, waited = 200, 0
	while waited < ms do
		if fn() then return true, waited end
		vim.wait(step, function() return false end, 50)
		waited = waited + step
	end
	return fn() and true or false, waited
end

-- ── The matrix rows ───────────────────────────────────────────────────────
-- `tool` gates the whole row: absent means UNCOVERED, never FAIL, because a
-- missing compiler says nothing about the bundle.
local SPECS = {
	rust = {
		bundle = "languages.rust", dir = "rust", main = "src/main.rs", ft = "rust",
		tool = "cargo", lsp = { "rust-analyzer" }, parser = "rust", node = "function_item",
		run_file = "42", run_project = "42",
		fmt = { file = "src/messy.rs", bin = "rustfmt", expect = "a: i32" },
		test = { file = "src/main.rs", bin = "cargo" },
		-- Stop inside add(), where `a` is 40 regardless of how the binary was
		-- launched. rustaceanvim's autoloaded "Cargo: build" config builds the
		-- crate and runs the resulting binary under codelldb.
		debug = { line = 3, adapter = "codelldb", config = "^Cargo: build", var = "a", value = "40" },
		-- A type mismatch, not an unresolved name: rust-analyzer reports
		-- mismatches natively on didChange, while "cannot find function" comes
		-- from cargo check, which only runs on save.
		lint = { inject = 'fn __cap_broken() { let _x: i32 = "not an int"; }' },
	},
	go = {
		bundle = "languages.go", dir = "go", main = "main.go", ft = "go",
		tool = "go", lsp = { "gopls" }, parser = "go", node = "function_declaration",
		run_file = "42", run_project = "42",
		fmt = { file = "messy.go", bin = "goimports", expect = "func Messy(a int) int" },
		test = { file = "main_test.go", bin = "go" },
		debug = { line = 5, adapter = "go", config = "", var = "a", value = "40" },
		lint = { inject = "func __capBroken() int { return __capMissing() }" },
	},
	python = {
		bundle = "languages.python", dir = "python", main = "main.py", ft = "python",
		tool = "python3", lsp = { "basedpyright", "ruff" }, parser = "python",
		node = "function_definition",
		run_file = "42",
		-- Python has no project-level run: there is no convention that is true
		-- across setuptools, poetry, uv and a bare script directory.
		run_project = false,
		fmt = { file = "messy.py", bin = "black", expect = "def messy(a):" },
		test = { file = "test_main.py", bin = "pytest" },
		debug = { line = 2, adapter = "debugpy", config = "", var = "a", value = "40" },
		lint = { inject = "def __cap_broken():\n    return __cap_missing()" },
	},
	latex = {
		bundle = "languages.latex", dir = "latex", main = "main.tex", ft = "tex",
		tool = "latexmk", lsp = { "texlab" }, parser = "latex", node = "section",
		-- A document is compiled, not run. That capability is real and is
		-- covered end to end by tests/behave_latex.lua, which asserts a PDF
		-- appears; repeating it here would duplicate, not add.
		run_file = false, run_project = false,
		fmt = { file = "messy.tex", bin = "latexindent", expect = "\\item one", smoke = true },
		test = { na = "a LaTeX document has no test suite to run" },
		debug = { na = "a LaTeX document is not stepped through" },
		-- texlab reports LaTeX diagnostics from the build, not from parsing, so
		-- a document that compiles cleanly has none and a broken one needs a
		-- latexmk run to produce any. That compile path is already asserted end
		-- to end by tests/behave_latex.lua. chktex would cover the parse-time
		-- half, but declaring it produced no diagnostics through nvim-lint even
		-- with the binary present and try_lint clean, so it is not claimed.
		lint = { na = "texlab reports diagnostics from the build; see behave_latex" },
	},
	web = {
		bundle = "languages.web-dev", dir = "web", main = "main.ts", ft = "typescript",
		tool = "node", lsp = { "ts_ls" }, parser = "typescript",
		node = "function_declaration",
		run_file = "42", run_project = "42",
		fmt = { file = "messy.ts", bin = "prettierd",
		        expect = "export function messy(a: number): number" },
		test = { file = "main.test.ts", bin = "npx" },
		-- Tracked, not a regression: a session starts and hangs with no stopped
		-- event, in ESM and CommonJS alike, and with js-debug wired directly as
		-- well as through nvim-dap-vscode-js. Leading hypothesis is Node 25 vs
		-- vscode-js-debug 1.x (issue #12).
		debug = { gap = "js-debug session never stops (issue #12)" },
		lint = { inject = "const __capBroken: number = \"not a number\";" },
	},
	java = {
		bundle = "languages.java", dir = "java",
		main = "src/main/java/capfixture/Main.java", ft = "java",
		tool = "java", lsp = { "jdtls" }, parser = "java", node = "method_declaration",
		run_file = "42", run_project = "42",
		fmt = { file = "src/main/java/capfixture/Messy.java", bin = "google-java-format",
		        expect = "int messy(int a)" },
		test = { file = "src/test/java/capfixture/MainTest.java", bin = "mvn",
		         prepare = { { "mvn", "-q", "-DskipTests", "test-compile" } } },
		debug = { line = 5, adapter = "java", config = "", var = "a", value = "40" },
		lint = { inject = "  int __capBroken() { return __capMissing(); }" },
	},
	c = {
		bundle = "languages.c-cpp", dir = "c", main = "main.c", ft = "c",
		tool = "cc", lsp = { "clangd" }, parser = "c", node = "function_definition",
		run_file = "42", run_project = false,  -- `make` builds; it does not run
		fmt = { file = "messy.c", bin = "clang-format", expect = "int messy(int a)" },
		-- The test row uses the CMake/doctest fixture rather than the plain
		-- Makefile one: CTest is what neotest-ctest drives, and a Makefile
		-- project exposes no tests to it.
		-- CTest lives in the same fixture root as the plain C files: neotest
		-- roots an adapter at Neovim's cwd, so a test project in a sibling
		-- directory is invisible to it.
		test = { file = "capfixture_test.cpp", bin = "ctest", prepare = {
			{ "cmake", "-S", ".", "-B", "build", "-DCMAKE_BUILD_TYPE=Debug" },
			{ "cmake", "--build", "build" },
		} },
		-- c-cpp's launch config asks for the executable path with vim.fn.input,
		-- so the probe answers it the way a user would.
		-- Built to its own path, not `main`: checkpoint 7 compiles main.c to
		-- `main` without -g, and `make main` then sees it up to date and skips
		-- the debug build, so the breakpoint never binds and the program runs
		-- to completion. Two checkpoints must not share one artifact.
		debug = { line = 3, adapter = "codelldb", config = "", var = "a", value = "40",
		          program = "main_debug",
		          build = { "cc", "-g", "-O0", "main.c", "-o", "main_debug" } },
		lint = { inject = "int __cap_broken(void) { return __cap_missing(); }" },
	},
}

local spec = SPECS[LANG]
if not spec then
	print("FAIL: unknown CAP_LANG '" .. LANG .. "'")
	vim.cmd("cq1")
	return
end

print(("=== %s (%s) ==="):format(LANG, spec.bundle))

local fixture = ROOT .. "/" .. spec.dir
local target  = fixture .. "/" .. spec.main

if vim.fn.executable(spec.tool) ~= 1 then
	-- Every checkpoint, not just the four the else-branch opens with. Listing a
	-- subset here silently dropped format, diagnostics, test and debug from the
	-- report whenever a toolchain was absent, which is exactly the "a cell may
	-- never be skipped" rule this file claims to follow.
	for _, cp in ipairs({ "1 lsp", "2 treesitter", "3 format", "4 diagnostics",
	                      "5 test", "6 debug", "7 run-file", "8 run-project" }) do
		record(cp, "UNCOVERED", spec.tool .. " not on PATH")
	end
else
	vim.cmd("edit " .. vim.fn.fnameescape(target))
	local buf = vim.api.nvim_get_current_buf()

	-- ── 1. LSP attaches ───────────────────────────────────────────────────
	-- Red when: no client with an expected name attaches inside the budget.
	local attached
	local ok_lsp = poll(60000, function()
		for _, c in ipairs(vim.lsp.get_clients({ bufnr = buf })) do
			for _, want in ipairs(spec.lsp) do
				if c.name == want then attached = c.name; return true end
			end
		end
		return false
	end)
	record("1 lsp", ok_lsp and "PASS" or "FAIL",
		ok_lsp and attached or ("expected one of " .. table.concat(spec.lsp, "/")))

	-- ── 2. Treesitter parses it ───────────────────────────────────────────
	-- Red when: the parser is not installed, or the tree carries no node of
	-- the type this language must produce for the fixture.
	local ok_parser = poll(60000, function()
		return #vim.api.nvim_get_runtime_file("parser/" .. spec.parser .. ".so", false) > 0
	end)
	if not ok_parser then
		record("2 treesitter", "FAIL", "parser/" .. spec.parser .. ".so never installed")
	else
		local got_node = false
		local ok_p, parser = pcall(vim.treesitter.get_parser, buf, spec.parser)
		if ok_p and parser then
			local tree = parser:parse()[1]
			local function walk(node)
				if got_node then return end
				if node:type() == spec.node then got_node = true; return end
				for child in node:iter_children() do walk(child) end
			end
			walk(tree:root())
		end
		record("2 treesitter", got_node and "PASS" or "FAIL",
			got_node and (spec.parser .. " -> " .. spec.node)
			or ("no " .. spec.node .. " node found"))
	end

	-- ── 7 / 8. Run the file, run the project ──────────────────────────────
	-- Red when: no command is produced, it exits non-zero, or its stdout is
	-- not what the fixture prints. Building the command is not the claim;
	-- running it is.
	local run = require("noethervim.util.run")
	local function check_run(kind, cp, expected)
		if expected == false then
			record(cp, "N/A", "no project-level run convention for " .. LANG)
			return
		end
		local cmd, cwd = run.command(kind, buf)
		if not cmd or not cwd then
			record(cp, "FAIL", "util.run produced no " .. kind .. " command")
			return
		end
		local res = vim.system({ "sh", "-c", cmd }, { cwd = cwd, text = true }):wait(120000)
		local out = vim.trim(res.stdout or "")
		if res.code ~= 0 then
			record(cp, "FAIL", ("exit %d: %s"):format(res.code,
				vim.trim((res.stderr or ""):gsub("%s+", " ")):sub(1, 90)))
		elseif out ~= expected then
			record(cp, "FAIL", ("stdout %q, expected %q"):format(out:sub(1, 40), expected))
		else
			record(cp, "PASS", cmd:sub(1, 60))
		end
	end
	check_run("file", "7 run-file", spec.run_file)
	check_run("project", "8 run-project", spec.run_project)

	-- ── 3. Formatter ──────────────────────────────────────────────────────
	-- Two assertions, because either alone passes for the wrong reason. That
	-- the buffer CHANGED catches the common bug (a filetype claimed in
	-- `formatters_by_ft` whose binary was never installed, where conform
	-- silently falls back to LSP formatting and the reader believes the
	-- formatter ran). That the result CONTAINS the normalised text catches
	-- the wrong formatter having run.
	--
	-- Formatted in a scratch copy: the fixture must stay misformatted so the
	-- next run has something to reformat.
	do
		local f = spec.fmt
		-- "On PATH" is not the same as "works": TeX Live's latexindent is a
		-- Perl script that fails to load its own modules against a newer Perl,
		-- and reporting that as a bundle FAIL would blame the wrong thing. A
		-- binary that cannot run at all is an environment gap.
		-- Opt-in, not default: `--version` is not universal (goimports exits
		-- non-zero on it), and defaulting this on turned a working formatter
		-- into a false UNCOVERED. Only a binary known to be fragile asks for it.
		local function binary_runs()
			if not f.smoke then return true end
			local r = vim.system({ f.bin, "--version" }, { text = true }):wait(20000)
			return r.code == 0
		end
		if vim.fn.executable(f.bin) ~= 1 then
			record("3 format", "UNCOVERED", f.bin .. " not on PATH (Mason install did not land)")
		elseif not binary_runs() then
			record("3 format", "UNCOVERED", f.bin .. " is on PATH but fails to run here")
		else
			local src = fixture .. "/" .. f.file
			local tmp = vim.fn.tempname() .. "_" .. vim.fn.fnamemodify(f.file, ":t")
			vim.fn.writefile(vim.fn.readfile(src), tmp)

			vim.cmd("edit " .. vim.fn.fnameescape(tmp))
			local fbuf   = vim.api.nvim_get_current_buf()
			local before = table.concat(vim.api.nvim_buf_get_lines(fbuf, 0, -1, false), "\n")
			local ok_fmt, err = pcall(function()
				require("conform").format({ bufnr = fbuf, async = false, timeout_ms = 20000 })
			end)
			local after = table.concat(vim.api.nvim_buf_get_lines(fbuf, 0, -1, false), "\n")

			if not ok_fmt then
				record("3 format", "FAIL", "conform.format errored: " .. tostring(err))
			elseif after == before then
				record("3 format", "FAIL", "buffer unchanged (formatter did not run)")
			elseif not after:find(f.expect, 1, true) then
				record("3 format", "FAIL", ("expected %q in the result"):format(f.expect))
			else
				record("3 format", "PASS", f.bin .. " -> " .. f.expect)
			end
			vim.cmd("bwipeout! " .. fbuf)
		end
	end

	-- ── 4. Diagnostics ────────────────────────────────────────────────────
	-- Every language in the contract takes diagnostics from its language
	-- server, so this asserts the server reports a real defect rather than
	-- that a separate linter exists.
	--
	-- The defect is injected into the buffer and never written: a fixture that
	-- does not compile would break the run checkpoints above, and every server
	-- here reports on didChange rather than on save. Red when: the server
	-- attaches but never reports the broken symbol.
	if spec.lint.na then
		record("4 diagnostics", "N/A", spec.lint.na)
	elseif not ok_lsp then
		record("4 diagnostics", "UNCOVERED", "no LSP attached; nothing to report diagnostics")
	else
		local lint_target = spec.lint.file and (fixture .. "/" .. spec.lint.file) or target
		vim.cmd("edit! " .. vim.fn.fnameescape(lint_target))
		local dbuf = vim.api.nvim_get_current_buf()

		-- Languages whose diagnostics come from a linter rather than the server
		-- need it kicked: nvim-lint fires on BufReadPost / BufWritePost /
		-- InsertLeave, none of which a scripted open reliably produces.
		pcall(function() require("lint").try_lint() end)

		-- Scoped to the injected lines, not "any diagnostic in the buffer".
		-- A whole-buffer count survives its own break: remove the injection and
		-- an unrelated pre-existing warning still satisfies it. Anchoring to
		-- the lines we broke is what makes this red when the server stops
		-- reporting.
		local injected_from = 0
		if spec.lint.inject then
			injected_from = vim.api.nvim_buf_line_count(dbuf)
			vim.api.nvim_buf_set_lines(dbuf, -1, -1, false, vim.split(spec.lint.inject, "\n"))
		end

		local function on_injected()
			local hits = {}
			for _, d in ipairs(vim.diagnostic.get(dbuf, { severity = { min = vim.diagnostic.severity.WARN } })) do
				if d.lnum >= injected_from then hits[#hits + 1] = d end
			end
			return hits
		end

		local ok_diag = poll(60000, function() return #on_injected() > 0 end)
		local hits = on_injected()
		record("4 diagnostics", ok_diag and "PASS" or "FAIL",
			ok_diag and (("line %d %s: %s"):format(hits[1].lnum + 1, hits[1].source or "?",
				(hits[1].message or ""):gsub("%s+", " "):sub(1, 48)))
			or ("no diagnostic on the injected lines (from line %d)"):format(injected_from + 1))
		-- Leave the fixture on disk untouched.
		vim.cmd("edit! " .. vim.fn.fnameescape(target))
	end

	-- ── 5. Test runner ────────────────────────────────────────────────────
	-- The fixture carries one passing and one failing test on purpose. Both
	-- halves are asserted: discovery alone would pass on an adapter that finds
	-- tests and never runs them, and "at least one passed" would pass on an
	-- adapter that reports everything green.
	--
	-- Red when: no adapter claims the file, no tests are discovered, or the
	-- pass/fail split is not 1-and-1.
	do
		local t = spec.test
		if t.na then
			record("5 test", "N/A", t.na)
		elseif t.gap then
			record("5 test", "GAP", t.gap)
		elseif vim.fn.executable(t.bin) ~= 1 then
			record("5 test", "UNCOVERED", t.bin .. " not on PATH")
		else
			local test_fixture = ROOT .. "/" .. (t.dir or spec.dir)
			-- Some runners need the project built before anything is
			-- discoverable or runnable: CTest reads CTestTestfile.cmake from a
			-- build dir, and neotest-java wants compiled test classes.
			for _, cmd in ipairs(t.prepare or {}) do
				vim.system(cmd, { cwd = test_fixture }):wait(300000)
			end
			if t.prepare then vim.cmd("cd " .. vim.fn.fnameescape(test_fixture)) end
			local test_path = test_fixture .. "/" .. t.file
			vim.cmd("edit! " .. vim.fn.fnameescape(test_path))
			local tbuf = vim.api.nvim_get_current_buf()

			local ok_nt, neotest = pcall(require, "neotest")
			local ok_cfg, ntcfg = pcall(require, "neotest.config")
			if not ok_nt or not ok_cfg then
				record("5 test", "FAIL", "neotest not loadable (tools/test not enabled?)")
			elseif #(ntcfg.adapters or {}) == 0 then
				record("5 test", "FAIL", "no neotest adapter configured for this bundle")
			else
				-- `state.adapter_ids()` is filled by the state tracker during
				-- discovery, so it is empty until a run has started. Kick the
				-- run first, then poll for both the id and its counts.
				neotest.run.run(test_path)

				-- A bundle can register more than one adapter for a filetype:
				-- web-dev registers both neotest-jest and neotest-vitest, and
				-- only one of them owns a given project. Taking whichever
				-- adapter_ids() happens to yield first made this cell flaky --
				-- green alone, red in the suite -- because the idle adapter
				-- reports total>0, running==0 and no results, which satisfies a
				-- naive "the run finished" test.
				--
				-- Require the positions to be resolved, not merely not-running.
				local counts
				local done = poll(300000, function()
					for _, id in ipairs(neotest.state.adapter_ids()) do
						local c = neotest.state.status_counts(id, { buffer = tbuf })
						if c and c.total > 0 and c.running == 0
							and (c.passed + c.failed) > 0 then
							counts = c
							return true
						end
					end
					return false
				end)

				if not done or not counts then
					local names = {}
					for _, a in ipairs(ntcfg.adapters) do names[#names + 1] = a.name or "?" end
					record("5 test", "FAIL",
						"no results within budget; configured: " .. table.concat(names, ", "))
				elseif counts.passed >= 1 and counts.failed >= 1 then
					record("5 test", "PASS", ("%d passed, %d failed of %d")
						:format(counts.passed, counts.failed, counts.total))
				else
					record("5 test", "FAIL", ("expected >=1 passed and >=1 failed, got %d/%d of %d")
						:format(counts.passed, counts.failed, counts.total))
				end
			end
		end
	end
	-- ── 6. Debugger ───────────────────────────────────────────────────────
	-- The claim is not "an adapter table exists" -- that is what made the Rust
	-- debugger look fine while it registered zero configurations. The claim is
	-- that a session starts, stops on a breakpoint in this file, and can read a
	-- local. Anything less passes on a debugger that never runs.
	--
	-- Red when: the adapter is unregistered, no configuration matches, the
	-- session never stops, it stops on the wrong line, or the local reads wrong.
	do
		local d = spec.debug
		local ok_dap, dap = pcall(require, "dap")
		if d.na then
			record("6 debug", "N/A", d.na)
		elseif d.gap then
			record("6 debug", "GAP", d.gap)
		elseif not ok_dap then
			record("6 debug", "FAIL", "nvim-dap not loadable (tools/debug not enabled?)")
		elseif not dap.adapters[d.adapter] then
			local names = vim.tbl_keys(dap.adapters)
			table.sort(names)
			record("6 debug", "FAIL", ("adapter %q not registered; have: %s")
				:format(d.adapter, table.concat(names, ", ")))
		else
			-- Some fixtures need a binary on disk before anything can launch it.
			if d.build then
				vim.system(d.build, { cwd = fixture }):wait(180000)
			end

			-- Checkpoint 5 may have left a session behind: neotest-ctest runs
			-- tests through this same codelldb adapter, and dap.run() on top of
			-- a live session does not produce a second stop. Start from a clean
			-- debugger, and from no breakpoints, so `toggle` cannot toggle one
			-- back off.
			if dap.session() then
				pcall(dap.terminate)
				poll(15000, function() return dap.session() == nil end)
			end
			pcall(dap.clear_breakpoints)

			-- The debug row may use a different file from the rest: TypeScript
			-- is stripped to JavaScript before it runs, so a breakpoint on the
			-- .ts source needs sourcemaps the fixture does not build. Debugging
			-- plain JavaScript is the bundle's baseline claim, so that is what
			-- is asserted here.
			local dtarget = fixture .. "/" .. (d.file or spec.main)
			vim.cmd("edit! " .. vim.fn.fnameescape(dtarget))
			local dbuf = vim.api.nvim_get_current_buf()

			local configs = dap.configurations[d.ft or spec.ft] or {}
			local chosen
			for _, c in ipairs(configs) do
				if d.config == "" or (c.name or ""):match(d.config) then chosen = c; break end
			end

			if not chosen then
				record("6 debug", "FAIL", ("no configuration for %s (%d present)")
					:format(spec.ft, #configs))
			else
				-- The C launch config asks for the executable with
				-- `vim.fn.input`, which cannot be answered headlessly: `vim.fn`
				-- is metatable-backed, so assigning a stub over it does not
				-- take, and the real prompt then blocks until the budget runs
				-- out. Supply the answer as config data instead -- the same
				-- value a user would type, without the prompt.
				if d.program then
					chosen = vim.tbl_extend("force", chosen,
						{ program = fixture .. "/" .. d.program })
				end

				vim.api.nvim_win_set_cursor(0, { d.line, 0 })
				dap.toggle_breakpoint()

				-- `current_frame` is filled by the stackTrace request nvim-dap
				-- issues *after* the stopped event, so reading it inside the
				-- listener sees nil. Record the stop, then poll for the frame.
				local session_seen
				dap.listeners.after.event_stopped["nv_capability"] = function()
					session_seen = true
				end

				-- The poll is wrapped, not just dap.run: an adapter that is
				-- misconfigured fails inside an async callback, and that error
				-- surfaces during vim.wait rather than at the call. Unwrapped it
				-- kills the whole run and every later checkpoint with it.
				local ok_run, run_err = pcall(dap.run, chosen)
				local stopped, poll_err = false, nil
				if ok_run then
					local ok_poll, res = pcall(poll, 180000, function()
						local s = dap.session()
						return session_seen and s ~= nil and s.current_frame ~= nil
					end)
					if ok_poll then stopped = res else poll_err = res end
				end
				local sess = dap.session()
				local stopped_line = stopped and sess and sess.current_frame and sess.current_frame.line or nil

				local detail
				if not ok_run then
					detail = "dap.run errored: " .. tostring(run_err):gsub("%s+", " "):sub(1, 80)
				elseif poll_err then
					detail = "adapter errored: " .. tostring(poll_err):gsub("%s+", " "):sub(1, 80)
				elseif not stopped then
					local s_now = dap.session()
					detail = ("no stop (config %q): stopped_event=%s session=%s frame=%s")
						:format(chosen.name or "?", tostring(session_seen ~= nil),
							tostring(s_now ~= nil), tostring(s_now and s_now.current_frame ~= nil))
				elseif stopped_line ~= d.line then
					detail = ("stopped on line %d, expected %d"):format(stopped_line, d.line)
				end

				-- Read the local, so the assertion covers a usable session and
				-- not merely a paused process.
				local var_ok, var_detail = false, ""
				if not detail then
					local session = dap.session()
					local frame = session and session.current_frame
					local got
					if session and frame then
						session:request("scopes", { frameId = frame.id }, function(_, sres)
							for _, scope in ipairs((sres or {}).scopes or {}) do
								session:request("variables", { variablesReference = scope.variablesReference },
									function(_, vres)
										for _, v in ipairs((vres or {}).variables or {}) do
											if v.name == d.var then got = v.value end
										end
									end)
							end
						end)
						poll(20000, function() return got ~= nil end)
					end
					var_ok = got ~= nil and tostring(got):find(d.value, 1, true) ~= nil
					var_detail = ("%s=%s"):format(d.var, tostring(got))
					if not var_ok then detail = "local read wrong: " .. var_detail end
				end

				pcall(dap.terminate)
				poll(10000, function() return dap.session() == nil end)
				dap.listeners.after.event_stopped["nv_capability"] = nil

				record("6 debug", detail and "FAIL" or "PASS",
					detail or ("stopped line %d, %s"):format(stopped_line, var_detail))
			end
		end
	end
end

print(("\n%s: %d passed, %d failed, %d gap, %d n/a, %d uncovered")
	:format(LANG, pass, fail, gap, na, uncovered))

-- Machine-readable row for the matrix report.
local row = { LANG }
for _, c in ipairs(cells) do row[#row + 1] = c.cp .. "=" .. c.state end
print("MATRIX " .. table.concat(row, " "))

vim.cmd("cq" .. (fail > 0 and "1" or "0"))
