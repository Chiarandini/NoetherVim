-- tests/capability_provision.lua -- warm the isolated env before grading.
--
-- Run by tests/capability.sh with the fixture already open, so that
-- nvim-lspconfig (lazy-loaded on BufReadPre) has actually loaded and
-- mason-lspconfig's `ensure_installed` has fired. Without opening a real file
-- of the language, no server is ever requested and a later "no LSP attached"
-- reads as a bundle defect rather than an unprovisioned harness. That is the
-- coverage-honesty rule from full-toolchain-sweep-plan.md: a failure must never
-- be a hidden missing tool.
--
-- Mason 2 exposes no "what is installing" query, so rather than guess at an
-- API, wait for the installed-package set to stop growing: the queue is drained
-- when nothing new has landed for QUIET_MS.

local BUDGET_MS = tonumber(vim.env.CAP_PROVISION_BUDGET or "") or 600000
local QUIET_MS  = 15000

-- conform loads on BufWritePre and nvim-dap on a keypress, so simply opening a
-- fixture leaves both unloaded and their `mason_install` lists unread: the
-- formatter and the debug adapter would then be missing for reasons that have
-- nothing to do with the bundle. Force them in before waiting.
pcall(function()
	require("lazy").load({ plugins = { "conform.nvim", "nvim-lint", "nvim-dap" } })
end)

local ok, registry = pcall(require, "mason-registry")
if not ok then
	io.stderr:write("provision: mason-registry unavailable; nothing to wait for\n")
	vim.cmd("qa!")
	return
end

-- mason-lspconfig skips `ensure_installed` outright when Neovim is headless
-- (mason-lspconfig/init.lua: `if not platform.is_headless and ...`), so a
-- headless harness can never provision a language server the way a real
-- session does. Do it here instead, by the same route its feature module
-- takes: map the lspconfig server name to a Mason package and install it.
--
-- This provisions the harness; it does not test the distro. Whether a real
-- session installs the server is a question only an interactive run can
-- answer, and it is recorded as such in the plan.
do
	local ok_lazy, lazy_cfg = pcall(require, "lazy.core.config")
	local ok_map, mappings  = pcall(require, "mason-lspconfig.mappings")
	if ok_lazy and ok_map then
		local plugin = lazy_cfg.plugins["nvim-lspconfig"]
		local opts = plugin and require("lazy.core.plugin").values(plugin, "opts") or {}
		local to_package = mappings.get_mason_map().lspconfig_to_package
		for _, server in ipairs(opts.ensure_installed or {}) do
			local pkg_name = to_package[server]
			if pkg_name and registry.has_package(pkg_name) then
				local pkg = registry.get_package(pkg_name)
				if not pkg:is_installed() then
					io.stderr:write(("provision: installing %s (%s)\n"):format(server, pkg_name))
					pkg:install()
				end
			else
				io.stderr:write(("provision: no Mason package for server %q\n"):format(server))
			end
		end
	end
end

local function installed()
	local names = registry.get_installed_package_names()
	table.sort(names)
	return names
end

local last, last_change, waited = table.concat(installed(), ","), 0, 0
while waited < BUDGET_MS do
	vim.wait(1000, function() return false end, 100)
	waited = waited + 1000

	local now = table.concat(installed(), ",")
	if now ~= last then
		last, last_change = now, waited
	elseif waited - last_change >= QUIET_MS then
		break
	end
end

io.stderr:write(("provision: %ds, installed: %s\n")
	:format(waited / 1000, table.concat(installed(), " ")))
vim.cmd("qa!")
