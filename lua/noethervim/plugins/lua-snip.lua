-- NoetherVim plugin: LuaSnip Snippet Engine
-- Snippet files live in <config>/LuaSnip/*.lua; edit with SearchLeader+es or :LuaSnipEdit.
-- Tab/S-Tab jumping is handled by blink.cmp; <C-q> cycles choice nodes.
local SearchLeader = require("noethervim.util").search_leader

return {
{
	"L3MON4D3/LuaSnip",
	version = "1.*",
	build = "make install_jsregexp",
	event = "InsertEnter",


config = function(_, opts)
	local ls = require('luasnip')
	local types = require("luasnip.util.types")

	local defaults = {
		history = false,
		updateevents = "TextChanged,TextChangedI",
		enable_autosnippets = true,
		ext_opts = {
			[types.choiceNode] = {
				active = {
					virt_text = { { " « (cycle: <C-q>, fuzzy: <c-s-q>)", "GruvboxGreenBold" } },
				},
			},
			[types.insertNode] = {
				active = {
					virt_text = { { "●", "NonText" } },
				},
				unvisited = {
					virt_text = { { "..", "GruvboxBlue" } },
				},
			},
		},
		ft_func = function()
			-- trimempty: an unset 'filetype' splits to { "" }, which shows up as a
			-- blank row in the :LuaSnipEdit filetype prompt and names nothing.
			return vim.split(vim.bo.filetype, ".", { plain = true, trimempty = true })
		end,
		load_ft_func = require("luasnip.extras.filetype_functions").extend_load_ft({
			html = { 'javascript' },
			lua  = { 'vim' },
		}),
		store_selection_keys = "<Tab>",
	}
	ls.setup(vim.tbl_deep_extend("force", defaults, opts))

	require("luasnip.loaders.from_lua").lazy_load({ paths = vim.fn.stdpath("config") .. "/LuaSnip/" })

	-- Snippet files reach the picker from three places: your own config, plugins
	-- that ship snippets, and `dev` checkouts of those plugins.  Ownership comes
	-- from lazy.nvim's registry rather than a path prefix, because a prefix test
	-- gets it wrong in both directions: the dev config symlinks LuaSnip/ into
	-- ~/.config/nvim, so your own files resolve outside stdpath("config"), while
	-- a dev checkout under ~/programming is nowhere near stdpath("data").
	-- fs_realpath, not resolve(): it collapses symlinks *and* normalises case.
	-- Case matters because lazy names a dev directory after the repo string
	-- ("Chiarandini/NoetherVim-Tex" -> .../NoetherVim-Tex) while the checkout on
	-- disk may be spelled differently (.../noethervim-tex).  A case-insensitive
	-- filesystem happily opens both, but a string compare of the two fails.
	local function canonical(path)
		return vim.uv.fs_realpath(path) or vim.fs.normalize(path)
	end

	local function lazy_plugins()
		local ok, lazy_config = pcall(require, "lazy.core.config")
		if not ok then
			return {}
		end
		local plugins = {}
		for name, plugin in pairs(lazy_config.plugins) do
			if plugin.dir then
				table.insert(plugins, { name = name, dir = canonical(plugin.dir) })
			end
		end
		return plugins
	end

	vim.api.nvim_create_user_command('LuaSnipEdit', function()
		local plugins   = lazy_plugins()
		local cfg       = vim.fn.stdpath("config")
		local shown_cfg = vim.fn.fnamemodify(cfg, ":~")

		--- Name of the plugin that owns `path`, or nil when the file is yours.
		local function owning_plugin(path)
			local target = canonical(path)
			for _, plugin in ipairs(plugins) do
				if target == plugin.dir or vim.startswith(target, plugin.dir .. "/") then
					return plugin.name
				end
			end
			return nil
		end

		-- luasnip.loaders, not luasnip.loaders.from_lua: the from_lua variant takes
		-- no arguments and delegates to a lua-only helper that silently discards
		-- opts, so format/edit never ran (nor did LuaSnip's own $CONFIG shortening).
		require("luasnip.loaders").edit_snippet_files({
			-- Every path stays listed: reading the snippets a plugin ships is half
			-- of what this picker is for.  Label as owner + filename: the filetype
			-- was chosen a prompt ago, so the LuaSnip/<ft>/ segment every entry
			-- shares carries nothing, and the directory reduces to an identity that
			-- lazy already knows.  Filenames alone would collide (your preamble.lua
			-- and the one a plugin ships), hence the owner.
			format = function(path, _)
				local owner = owning_plugin(path)
				if not owner then
					-- Yours: name the tree it came from, which is whatever sits above
					-- LuaSnip/, so an extra_snippet_paths entry reads honestly too.
					local root = path:match("^(.*)/LuaSnip/") or vim.fn.fnamemodify(path, ":h")
					owner = vim.fn.fnamemodify(root, ":~")
				end
				return ("%-16s · %s"):format(owner, vim.fn.fnamemodify(path, ":t"))
			end,
			-- Without this, a filetype you have no snippets for is a dead end:
			-- LuaSnip asks which filetype, then returns silently because it has
			-- nothing to offer.  Worse, a filetype where only a plugin ships
			-- snippets skips the second prompt entirely and drops you into a
			-- read-only file with no route to your own.  Offer that route.
			extend = function(ft, existing)
				-- Belt and braces against a filetype that cannot name a file: an
				-- empty one would propose creating a file called ".lua".
				if type(ft) ~= "string" or not ft:match("^[%w_%-]+$") then
					return {}
				end
				for _, path in ipairs(existing) do
					if not owning_plugin(path) then
						return {}          -- you already have one; nothing to add
					end
				end
				local target = cfg .. "/LuaSnip/" .. ft .. ".lua"
				return { { ("%-16s · %s (new)"):format(shown_cfg, ft .. ".lua"), target } }
			end,
			-- Writing is what needs guarding, not opening: a snippet saved into a
			-- plugin's tree is lost on the next :Lazy update, and in a dev checkout
			-- it dirties that repo and then loads twice alongside your own copy.
			-- 'readonly' still yields to :w!, which is what you want when you are
			-- deliberately editing a plugin you maintain.
			edit = function(file)
				-- A brand new snippet file has to return a table; an empty buffer
				-- would make LuaSnip error the next time it loads the filetype.
				if vim.fn.filereadable(file) == 0 then
					vim.fn.mkdir(vim.fn.fnamemodify(file, ":h"), "p")
					vim.fn.writefile({
						"-- " .. vim.fn.fnamemodify(file, ":t:r") .. " snippets",
						"local ls = require(\"luasnip\")",
						"local s = ls.snippet",
						"local t = ls.text_node",
						"local i = ls.insert_node",
						"local fmta = require(\"luasnip.extras.fmt\").fmta",
						"",
						"return {",
						"}",
					}, file)
				end
				vim.cmd("edit " .. vim.fn.fnameescape(file))
				vim.bo.readonly = owning_plugin(file) ~= nil
			end,
		})
	end, { desc = "edit snippet files (plugin-owned ones read-only)" })
	vim.keymap.set('n', SearchLeader .. 'es', '<cmd>LuaSnipEdit<cr>', { desc = 'edit snippets' })

	-- Tab/S-Tab snippet navigation is handled by blink.cmp (snippets.preset = "luasnip").
	-- <c-q> for choice nodes stays as a raw Vimscript expr-map (not in blink's domain).
	vim.cmd([[
imap <silent><expr> <c-q> luasnip#choice_active() ? '<Plug>luasnip-next-choice' : '<c-q>'
smap <silent><expr> <c-q> luasnip#choice_active() ? '<Plug>luasnip-next-choice' : '<c-q>'
	]])
	-- jk expand/jump: personal preference -- add to lua/user/ if desired.

	vim.keymap.set('n', '<leader>u', require('luasnip').unlink_current, { desc = 'unlink current snippet' })
	vim.keymap.set('i', '<c-u>', function()
		local ls = require('luasnip')
		if ls.session.current_nodes[vim.api.nvim_get_current_buf()] then
			ls.unlink_current()
		else
			vim.notify("no active snippets", vim.log.levels.WARN)
		end
	end, { desc = 'unlink current snippet' })

	vim.keymap.set('n', '<localleader>u', function()
		local ls = require('luasnip')
		local buf = vim.api.nvim_get_current_buf()
		local count = 0
		while ls.session.current_nodes[buf] do
			ls.unlink_current()
			count = count + 1
		end
		if count > 0 then
			vim.notify("unlinked " .. count .. " snippet(s)", vim.log.levels.INFO)
		else
			vim.notify("no active snippets", vim.log.levels.WARN)
		end
	end, { desc = 'unlink all active snippets' })

	vim.cmd([[
function SourceSnippets()
	for f in split(glob(stdpath('config') . '/LuaSnip/*.lua'), '\n')
		exe 'source' f
	endfor
	echom 'snippets sourced'
endfunction
	]])
end
}

}
