-- NoetherVim plugin: Cached Headings (snacks)
--
-- Headings picker for tex / markdown / org files. Uses Snacks.picker as the
-- UI; cache/parser/latex helpers all come from latex-nav-core. The
-- telescope-cached-headings plugin is no longer a dependency. The
-- `:CachedHeadings*` user commands are registered inline here.

local SearchLeader = require("noethervim.util").search_leader

local function register_cached_headings_commands(config)
	local function update_cache_for_buf(bufnr)
		local cache    = require("latex_nav_core.cached_headings.cache")
		local parser   = require("latex_nav_core.cached_headings.parser")
		local filepath = vim.api.nvim_buf_get_name(bufnr)
		local filetype = vim.bo[bufnr].filetype
		if filepath == "" then
			vim.notify("[cached_headings] No file associated with current buffer.", vim.log.levels.WARN)
			return
		end
		local allowed = false
		for _, ft in ipairs(config.allowed_filetypes or { "tex", "markdown", "org" }) do
			if ft == filetype then allowed = true; break end
		end
		if not allowed then
			vim.notify(
				string.format("[cached_headings] Filetype '%s' is not supported.", filetype),
				vim.log.levels.WARN
			)
			return
		end
		local entries, deps = parser.scan_file(filepath, filetype, {
			include_starred        = config.include_starred,
			scan_includes          = config.scan_includes,
			recursive_limit        = config.recursive_limit,
			ignore_include_pattern = config.ignore_include_pattern,
		})
		local cache_path = cache.get_cache_path(filepath, config.cache_strategy or "global")
		local ok, err    = cache.write_cache(cache_path, entries, deps)
		if ok then
			if config.notify_on_update ~= false then
				vim.notify(
					string.format("[cached_headings] Cache updated (%d headings).", #entries),
					vim.log.levels.INFO
				)
			end
		else
			vim.notify("[cached_headings] Failed to write cache: " .. (err or "unknown"),
				vim.log.levels.ERROR)
		end
	end

	vim.api.nvim_create_user_command("CachedHeadingsUpdate", function()
		update_cache_for_buf(vim.api.nvim_get_current_buf())
	end, { desc = "Regenerate cached-headings cache for current file" })

	vim.api.nvim_create_user_command("CachedHeadingsWipeAll", function()
		local cache = require("latex_nav_core.cached_headings.cache")
		local count, err = cache.wipe_all_caches(config.cache_strategy or "global")
		if err then
			vim.notify("[cached_headings] " .. err, vim.log.levels.WARN)
		else
			vim.notify(string.format("[cached_headings] Wiped %d cache file(s).", count),
				vim.log.levels.INFO)
		end
	end, { desc = "Delete all cached-headings cache files" })

	if config.auto_update then
		vim.api.nvim_create_autocmd("BufWritePost", {
			group   = vim.api.nvim_create_augroup("CachedHeadingsAutoUpdate", { clear = true }),
			pattern = "*",
			desc    = "cached-headings: auto-regenerate cache on save",
			callback = function(ev)
				local ft = vim.bo[ev.buf].filetype
				for _, f in ipairs(config.allowed_filetypes or { "tex", "markdown", "org" }) do
					if ft == f then update_cache_for_buf(ev.buf); break end
				end
			end,
		})
	end
end

return {
	{
		"Chiarandini/snacks-cached-headings.nvim",
		dependencies = {
			"folke/snacks.nvim",
			"Chiarandini/latex-nav-core.nvim",
		},
		cmd  = { "SnacksCachedHeadings", "CachedHeadingsUpdate", "CachedHeadingsWipeAll" },
		keys = {
			{ SearchLeader .. "t", "<cmd>SnacksCachedHeadings<cr>", desc = "headings" },
		},
		opts = {
			scan_includes   = true,
			include_starred = true,
			recursive_limit = 3,
			auto_update     = true,
			allowed_filetypes = { "tex", "markdown", "org" },
			cache_strategy    = "global",
			notify_on_update  = true,
		},
		config = function(_, opts)
			require("snacks_cached_headings").setup(opts)
			register_cached_headings_commands(opts)
		end,
	},
}
