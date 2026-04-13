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
					virt_text = { { "●", "NonTest" } },
				},
				unvisited = {
					virt_text = { { "..", "GruvboxBlue" } },
				},
			},
		},
		ft_func = function()
			return vim.split(vim.bo.filetype, ".", true)
		end,
		load_ft_func = require("luasnip.extras.filetype_functions").extend_load_ft({
			html = { 'javascript' },
			lua  = { 'vim' },
		}),
		store_selection_keys = "<Tab>",
	}
	ls.setup(vim.tbl_deep_extend("force", defaults, opts))

	require("luasnip.loaders.from_lua").lazy_load({ paths = vim.fn.stdpath("config") .. "/LuaSnip/" })

	vim.api.nvim_create_user_command('LuaSnipEdit', function()
		require("luasnip.loaders.from_lua").edit_snippet_files()
	end, { desc = "edit snippet files" })
	vim.keymap.set('n', SearchLeader .. 'es', '<cmd>LuaSnipEdit<cr>', { desc = 'edit snippets' })

	-- Tab/S-Tab snippet navigation is handled by blink.cmp (snippets.preset = "luasnip").
	-- <c-q> for choice nodes stays as a raw Vimscript expr-map (not in blink's domain).
	vim.cmd([[
imap <silent><expr> <c-q> luasnip#choice_active() ? '<Plug>luasnip-next-choice' : '<c-q>'
smap <silent><expr> <c-q> luasnip#choice_active() ? '<Plug>luasnip-next-choice' : '<c-q>'
	]])
	-- jk expand/jump: personal preference — add to lua/user/ if desired.

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
