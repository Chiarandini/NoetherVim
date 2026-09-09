-- NoetherVim plugin: LuaSnip Snippet Engine
-- Snippet files live in <config>/LuaSnip/*.lua; edit with SearchLeader+es or :LuaSnipEdit.
-- Tab/S-Tab jumping is handled by blink.cmp; <C-q> cycles choice nodes.
local SearchLeader = require("noethervim.util").search_leader

return {
{
	"L3MON4D3/LuaSnip",
	-- 2.x, not 1.x. The 1.x loader registers a collection twice when a
	-- `lazy_load` runs re-entrantly, which happens whenever a snippet file
	-- requires a module from a plugin that is itself loaded on demand: the
	-- outer load is still iterating the collection list when the inner one
	-- appends to it. Every affected trigger then expands from two snippets
	-- and appears twice in the completion menu. The loaders were rewritten
	-- upstream and 2.x does not do it.
	version = "2.*",
	build = "make install_jsregexp",
	event = "InsertEnter",


config = function(_, opts)
	local ls = require('luasnip')
	local types = require("luasnip.util.types")

	local defaults = {
		-- The four settings that decide how snippets in a buffer connect to
		-- each other. Only the first departs from the stock behavior.
		--
		-- keep_roots: remember every snippet expanded in the buffer, not just
		-- the newest. It changes no jump anywhere; what it buys is <Leader>j,
		-- which cannot reach a snippet the buffer has forgotten.
		--
		-- The other three stay off, because each of them puts jumps on keys
		-- that blink.cmp already owns. link_roots lets <S-Tab> walk backwards
		-- out of the snippet you are in and into an unrelated earlier one.
		-- exit_roots = false leaves a finished snippet active at its last
		-- node, so <S-Tab> re-enters something you thought you were done
		-- with. link_children governs jumping from a node into a snippet
		-- nested inside it; it is left alone because <Leader>j reaches a
		-- nested snippet by position anyway.
		keep_roots = true,
		link_roots = false,
		exit_roots = true,
		link_children = false,
		update_events = "TextChanged,TextChangedI",
		enable_autosnippets = true,
		-- Record the file each snippet came from. It costs a small table per
		-- snippet and buys the only durable way to name one: a trigger is not
		-- unique (`iff` is deliberately two snippets, one for text and one for
		-- maths), so anything that reports or acts on a single snippet needs
		-- its origin. :checkhealth uses it to say which files a repeated
		-- trigger comes from.
		loaders_store_source = true,
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
		cut_selection_keys = "<Tab>",
	}
	ls.setup(vim.tbl_deep_extend("force", defaults, opts))

	-- lazy_paths, not paths: a root that does not exist is dropped at startup
	-- with nothing but a line in the log, and a fresh install has no
	-- <config>/LuaSnip yet, so the first snippet file written there would stay
	-- unregistered until the next restart. lazy_paths watches for the
	-- directory's creation instead. Empty `paths` is what keeps the runtimepath
	-- scan for `luasnippets/` directories switched off; plugins that ship
	-- snippets register their own collections and are already accounted for.
	-- libuv watchers alongside the default BufWritePost ones, so a snippet
	-- edited in one Neovim reaches every other instance running at the time.
	-- Ahead of the loader, not after it: LuaSnip is loaded on InsertEnter, so
	-- the buffer already has a filetype and lazy_load can register its
	-- snippets during this call. Installed afterwards, the listener would miss
	-- that first batch and snippets you had switched off would come back until
	-- the next load.
	require("noethervim.util.snippet_store").install()

	require("luasnip.loaders.from_lua").lazy_load({
		paths = {},
		lazy_paths = { vim.fn.stdpath("config") .. "/LuaSnip" },
		fs_event_providers = { autocmd = true, libuv = true },
	})

	-- Snippet files reach the picker from three places: your own config, plugins
	-- that ship snippets, and `dev` checkouts of those plugins. Ownership comes
	-- from lazy.nvim's registry rather than a path prefix, because a prefix test
	-- gets it wrong in both directions: the dev config symlinks LuaSnip/ into
	-- ~/.config/nvim, so your own files resolve outside stdpath("config"), while
	-- a dev checkout under ~/programming is nowhere near stdpath("data").
	-- fs_realpath, not resolve(): it collapses symlinks *and* normalises case.
	-- Case matters because lazy names a dev directory after the last segment of
	-- the repo string, and a checkout on disk may be spelled differently. A
	-- case-insensitive filesystem happily opens both, but a string compare of
	-- the two fails.
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
		-- Set by `extend` when its offer is the only entry, which is the case
		-- LuaSnip opens without asking. Per invocation, so it cannot leak.
		local unprompted_create = false

		-- Without this the prompt just quietly offers "all", which reads as a bug
		-- when you believe you are in a Rust buffer and the file is named
		-- tmp.rust: Neovim maps .rs, not .rust, so the buffer has no filetype and
		-- there is nothing filetype-specific to edit.
		if vim.bo.filetype == "" then
			vim.notify(
				"LuaSnipEdit: this buffer has no filetype, so only \"all\" snippets apply.\n"
					.. "Set one with :setfiletype <ft> if that is not what you meant.",
				vim.log.levels.WARN
			)
		end


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

		-- Does the reader already have a snippet file for this filetype, as
		-- opposed to only the ones plugins ship? Read from the same registry
		-- LuaSnip's own picker reads, so the answer cannot disagree with it.
		local function has_own_file(ft)
			local ok_data, loader_data = pcall(require, "luasnip.loaders.data")
			if not ok_data then
				return true            -- cannot tell; do not promise a new file
			end
			for _, key in ipairs({ "lua_ft_paths", "snipmate_ft_paths", "vscode_ft_paths" }) do
				for path, _ in pairs((loader_data[key] or {})[ft] or {}) do
					if not owning_plugin(path) then
						return true
					end
				end
			end
			return false
		end

		-- LuaSnip offers the filetypes as bare strings, so the one prompt a reader
		-- always sees says nothing about which of them would write a file. Annotate
		-- that list for the duration of this call only: the wrapper is dropped as
		-- soon as the prompt has been built, leaving the second prompt and every
		-- other caller of vim.ui.select untouched.
		local orig_select = vim.ui.select
		vim.ui.select = function(items, sel_opts, on_choice)
			if type(sel_opts) == "table"
				and type(sel_opts.prompt) == "string"
				and sel_opts.prompt:match("^Select filetype")
			then
				sel_opts = vim.tbl_extend("force", sel_opts, {
					format_item = function(ft)
						return has_own_file(ft) and ft or (ft .. "   (creates a new file)")
					end,
				})
			end
			return orig_select(items, sel_opts, on_choice)
		end

		-- luasnip.loaders, not luasnip.loaders.from_lua: the from_lua variant takes
		-- no arguments and delegates to a lua-only helper that silently discards
		-- opts, so format/edit never ran (nor did LuaSnip's own $CONFIG shortening).
		local ok_edit, edit_err = pcall(require("luasnip.loaders").edit_snippet_files, {
			-- Every path stays listed: reading the snippets a plugin ships is half
			-- of what this picker is for. Label as owner + filename: the filetype
			-- was chosen a prompt ago, so the LuaSnip/<ft>/ segment every entry
			-- shares carries nothing, and the directory reduces to an identity that
			-- lazy already knows. Filenames alone would collide (your preamble.lua
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
			-- nothing to offer. Worse, a filetype where only a plugin ships
			-- snippets skips the second prompt entirely and drops you into a
			-- read-only file with no route to your own. Offer that route.
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
				-- LuaSnip only prompts when a filetype offers more than one file.
				-- With nothing else to offer, this entry becomes the sole choice
				-- and is opened without a prompt, so the `(new)` label is never
				-- seen and a file appears in your config unasked. Remember that,
				-- and confirm at the point of writing instead.
				unprompted_create = #existing == 0
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
				local created = vim.fn.filereadable(file) == 0
				-- Writing into lua/user/ is the reader's business, so it is never
				-- a side effect of browsing. When the picker was skipped they were
				-- never shown the `(new)` label, and this is the first point at
				-- which the choice is put to them.
				if created and unprompted_create then
					-- Yes/No, not Create/Cancel: `&` marks the accelerator, and
					-- both of those words start with C, so one letter answered
					-- for both and neither could be typed.
					local answer = vim.fn.confirm(
						("You have no snippets of your own for this filetype.\n"
							.. "Create %s?"):format(vim.fn.fnamemodify(file, ":~")),
						"&Yes\n&No", 2, "Question")
					if answer ~= 1 then
						return
					end
				end
				if created then
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

		-- Off again immediately. The prompt has already been handed its
		-- formatter, and leaving the wrapper in place would annotate nothing
		-- while adding a frame to every vim.ui.select in the session.
		vim.ui.select = orig_select
		if not ok_edit then
			error(edit_err)
		end
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

	-- Put the cursor back inside a snippet you have already walked out of, so
	-- a tabstop you filled in wrongly can be filled in again without retyping
	-- the snippet. LuaSnip finds the node by position, so the cursor only has
	-- to be somewhere in the snippet's text, and a snippet nested inside
	-- another is reached the same way. Raises when there is nothing there,
	-- which is a routine miss rather than a fault, so it is reported plainly.
	vim.keymap.set('n', '<leader>j', function()
		if not pcall(ls.activate_node) then
			vim.notify("no snippet under the cursor", vim.log.levels.WARN)
		end
	end, { desc = 'jump back into the snippet under the cursor' })

	--- Tear every snippet out of the current buffer.
	---
	--- Unlinking alone is not enough. `unlink_current()` drops one snippet
	--- and hands the cursor to its neighbour, but it leaves LuaSnip's
	--- extmarks behind -- a buffer that has been unlinked down to no active
	--- node still carries marks that keep highlighting text and can confuse
	--- later expansions. Those are the leftovers that need clearing, and
	--- they survive even when there is no current node to unlink at all.
	local function stop_all_snippets()
		local ls = require('luasnip')
		local session = require('luasnip.session')
		local buf = vim.api.nvim_get_current_buf()

		-- Bounded: this is interactive, and a jumplist that somehow never
		-- clears would otherwise hang the editor rather than misbehave.
		local unlinked = 0
		while session.current_nodes[buf] and unlinked < 100 do
			ls.unlink_current()
			unlinked = unlinked + 1
		end
		session.current_nodes[buf] = nil

		local stale = #vim.api.nvim_buf_get_extmarks(buf, session.ns_id, 0, -1, {})
		vim.api.nvim_buf_clear_namespace(buf, session.ns_id, 0, -1)
		return unlinked, stale
	end

	local function stop_all_and_report()
		local unlinked, stale = stop_all_snippets()
		if unlinked == 0 and stale == 0 then
			vim.notify("no snippets to stop", vim.log.levels.WARN)
		else
			vim.notify(
				string.format("stopped %d snippet(s), cleared %d mark(s)", unlinked, stale),
				vim.log.levels.INFO)
		end
	end

	vim.api.nvim_create_user_command('LuaSnipStop', stop_all_and_report,
		{ desc = 'Stop every snippet in the buffer and clear leftover marks' })

	--- Whether this buffer has anything for a stop to act on: a live snippet,
	--- or the extmarks one leaves behind after being unlinked.
	local function has_snippet_state()
		local buf = vim.api.nvim_get_current_buf()
		local session = require('luasnip.session')
		if session.current_nodes[buf] then return true end
		return #vim.api.nvim_buf_get_extmarks(buf, session.ns_id, 0, -1, {}) > 0
	end

	-- Insert-mode <C-u> is Vim's "delete what you have typed on this line",
	-- which is worth more than an unconditional snippet escape hatch: a
	-- snippet is active for a few seconds an hour, and that key is reached for
	-- constantly. So stop snippets only when there are snippets to stop, and
	-- otherwise pass the keystroke through untouched. Same shape as the <C-q>
	-- guard below, which leaves <C-q> alone unless a choice node is active.
	--
	-- Select mode has no comparable native <C-u>, and reaching it at all
	-- almost always means sitting on a tabstop, so there it always stops.
	vim.keymap.set('i', '<c-u>', function()
		if has_snippet_state() then
			stop_all_and_report()
		else
			-- 'i': ahead of anything already in the typeahead, so the
			-- replayed key lands where it was pressed rather than after the
			-- next keystrokes. 'n' so it is not fed back through this mapping.
			vim.api.nvim_feedkeys(
				vim.api.nvim_replace_termcodes('<C-u>', true, false, true), 'ni', false)
		end
	end, { desc = 'stop all snippets, else delete entered text' })

	vim.keymap.set('s', '<c-u>', stop_all_and_report, { desc = 'stop all snippets' })

	-- <Leader>, not <LocalLeader>: stopping snippets is a global action that
	-- happens to act on this buffer, not a filetype action, and LocalLeader
	-- mappings have to be buffer-local. Capital for the stronger of the pair,
	-- next to <Leader>u, which unlinks only the snippet you are in.
	vim.keymap.set('n', '<leader>U', stop_all_and_report,
		{ desc = 'stop all snippets' })

end
}

}
