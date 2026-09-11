-- tests/capability_cwd.lua -- checkpoint 5b, the working-directory pin.
--
-- Run by tests/capability.sh in its own Neovim, from the directory holding the
-- language's test file rather than from the fixture root. Writes one line,
-- `STATE|detail`, to $CAP_CWD_RESULT; capability_assert.lua reads it back and
-- records the cell in position, so the matrix stays one report.
--
-- Why a separate process. neotest resolves its adapters once, from Neovim's
-- cwd, when the client is first used (neotest/client/init.lua, `_update_adapters
-- (vim.loop.cwd())`). Changing directory afterwards does not cleanly re-root it:
-- measured, a `:cd` to the project root registers the adapter and still returns
-- no results. So the condition has to be set before the client exists, which
-- means before anything else in a run has touched neotest.
--
-- What this is for. `capability.sh` cd's into the fixture, and its own comment
-- calls that "what a user actually does". For a user with 'autochdir' it is
-- exactly what does not happen: cwd follows the buffer, so it is the file's
-- directory and never the project root. The symptom is `<Leader>tf` answering
-- "No tests found" with nothing wrong with the file.
--
-- Red when: the same file that produces results from the fixture root produces
-- none from its own directory.

local out = {}
local function finish(state, detail)
	vim.fn.writefile({ state .. "|" .. (detail or "") }, vim.env.CAP_CWD_RESULT)
	vim.cmd("qa!")
end

local function poll(ms, fn)
	local waited = 0
	while waited < ms do
		if fn() then return true end
		vim.wait(200, function() return false end, 50)
		waited = waited + 200
	end
	return fn() and true or false
end

local test_path = vim.env.CAP_TEST_FILE
if not test_path or test_path == "" then
	finish("N/A", "no test file for this language")
	return
end

vim.cmd("edit! " .. vim.fn.fnameescape(test_path))
local buf = vim.api.nvim_get_current_buf()

local ok_nt, neotest = pcall(require, "neotest")
if not ok_nt then
	finish("FAIL", "neotest not loadable")
	return
end

-- By path, not nearest: this mirrors <Leader>tf, which is the key the reported
-- failure came through, and it removes cursor position as a variable.
neotest.run.run(test_path)

-- 120s, not the 300s checkpoint 5 allows. Both outcomes here resolve early: a
-- working cwd reports within seconds of the build, and a broken one registers
-- no adapter at all and can never improve. A larger budget only delays a known
-- negative, and phase 1b runs inside the harness's own per-language timeout.
local counts
local done = poll(120000, function()
	for _, id in ipairs(neotest.state.adapter_ids()) do
		local c = neotest.state.status_counts(id, { buffer = buf })
		if c and c.total > 0 and c.running == 0 and (c.passed + c.failed) > 0 then
			counts = c
			return true
		end
	end
	return false
end)

if done and counts then
	finish("PASS", ("%d passed, %d failed from %s")
		:format(counts.passed, counts.failed, vim.fn.fnamemodify(vim.fn.getcwd(), ":t")))
else
	-- Naming the adapter count separates the two failure shapes: no adapter
	-- claimed this cwd at all, versus an adapter that claimed it and resolved
	-- nothing. The first is the cwd pin; the second would be a different bug.
	out = neotest.state.adapter_ids()
	finish("FAIL", ("no results with cwd=%s (%d adapters registered)")
		:format(vim.fn.fnamemodify(vim.fn.getcwd(), ":."), #out))
end
