--- Install the Mason packages a bundle declared it needs.
---
--- `nvim-lspconfig`'s `ensure_installed` already does this for language
--- servers, by way of mason-lspconfig. Nothing did it for the other three
--- toolchain layers, so a bundle could name `black` in `formatters_by_ft` or
--- register a `codelldb` debug adapter and the reader would still be one
--- manual `:MasonInstall` away from the feature existing, with only
--- `:checkhealth` to say so. conform grew a private `mason_install` list for
--- exactly this problem; this is that list extracted, so conform, nvim-lint and
--- nvim-dap share one implementation and one opt-out.
---
--- Enabling a bundle is the opt-in. That is the same bargain `ensure_installed`
--- already strikes for language servers: ask for the Go bundle and you have
--- asked for the Go toolchain the editor drives.
---
--- Set `vim.g.noethervim_auto_install = false` to decline. For a toolchain
--- managed outside the editor (nix, system packages, a project-local venv), a
--- second copy under Mason is noise at best and a version skew at worst.

local M = {}

--- Queue Mason installs for any of `tools` that are missing.
---
--- Asynchronous and best-effort by design: this runs from a plugin `config`,
--- and neither a missing Mason nor an unknown package name is worth an error
--- on the path that opens a file. `:checkhealth noethervim` is where a tool
--- that never arrived gets reported.
---@param tools string[]|nil  Mason package names
function M.ensure(tools)
	if vim.g.noethervim_auto_install == false then return end
	if not tools or #tools == 0 then return end

	local ok, registry = pcall(require, "mason-registry")
	if not ok then return end

	-- Two language bundles can name the same package: codelldb backs both
	-- Rust and C/C++. Installing it twice in one pass races Mason against
	-- itself over the same directory.
	local seen, wanted = {}, {}
	for _, tool in ipairs(tools) do
		if not seen[tool] then
			seen[tool] = true
			wanted[#wanted + 1] = tool
		end
	end

	registry.refresh(function()
		for _, tool in ipairs(wanted) do
			local found, pkg = pcall(registry.get_package, tool)
			if found and not pkg:is_installed() then
				pkg:install()
			end
		end
	end)
end

return M
