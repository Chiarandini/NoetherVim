-- NoetherVim plugin: vim-visual-multi (multiple cursors)

-- vim-visual-multi's leader, two backslashes.
local VM = [[\\]]

return {
	--<c-n> in visual mode for multiple cursors
	-- Tutorial: vim -Nu path/to/visual-multi/tutorialrc
	--
	-- VM maps its start keys globally and maps them again each time a
	-- session ends. With its defaults off and <C-n> emptied, it maps none,
	-- and the start keys are rows. <S-Left>/<S-Right> stay free for split
	-- resizing (keymaps.lua).
	{
		"mg979/vim-visual-multi",
		event = "BufReadPost",
		specs = {
			{ "NoetherVim", optional = true, opts = require("noethervim.keymaps.rows").contribute("vim-visual-multi", {
				{ "<C-n>",    "<Plug>(VM-Find-Under)",         nowait = true, desc = "multi-cursor: add the word under the cursor", set = "remaps" },
				{ "<C-n>",    "<Plug>(VM-Find-Subword-Under)", nowait = true, mode = "x", desc = "multi-cursor: add the selection", set = "remaps" },
				{ "<C-Down>", "<Plug>(VM-Add-Cursor-Down)",    nowait = true, desc = "multi-cursor: add a cursor below" },
				{ "<C-Up>",   "<Plug>(VM-Add-Cursor-Up)",      nowait = true, desc = "multi-cursor: add a cursor above" },
				{ VM .. "gS",  "<Plug>(VM-Reselect-Last)",      nowait = true, desc = "multi-cursor: reselect the last cursors" },
				{ VM .. "\\",  "<Plug>(VM-Add-Cursor-At-Pos)",  nowait = true, desc = "multi-cursor: add a cursor here" },
				{ VM .. "/",   "<Plug>(VM-Start-Regex-Search)", nowait = true, desc = "multi-cursor: add cursors by regex" },
				{ VM .. "A",   "<Plug>(VM-Select-All)",         nowait = true, desc = "multi-cursor: add every match of the word" },
				{ VM .. "/",   "<Plug>(VM-Visual-Regex)",       nowait = true, mode = "x", desc = "multi-cursor: add cursors by regex in the selection" },
				{ VM .. "A",   "<Plug>(VM-Visual-All)",         nowait = true, mode = "x", desc = "multi-cursor: add every match of the selection" },
				{ VM .. "a",   "<Plug>(VM-Visual-Add)",         nowait = true, mode = "x", desc = "multi-cursor: add the selection as a region" },
				{ VM .. "f",   "<Plug>(VM-Visual-Find)",        nowait = true, mode = "x", desc = "multi-cursor: find in the selection" },
				{ VM .. "c",   "<Plug>(VM-Visual-Cursors)",     nowait = true, mode = "x", desc = "multi-cursor: a cursor on each selected line" },
			}, {
				g = {
					VM_default_mappings = 0,
					VM_maps = { ["Find Under"] = "", ["Find Subword Under"] = "" },
				},
				-- A session maps its keys on `[`, `]` and `,` for the buffer,
				-- and VM leaves a key alone that already has a buffer mapping:
				-- which-key's triggers. which-key steps aside for the session,
				-- as it does while a macro records, and is rebuilt after it.
				startup = { ["vim-visual-multi.which-key"] = function()
					local function which_key(fn)
						if not package.loaded["which-key"] then return end
						local ok, Buf = pcall(require, "which-key.buf")
						if ok then pcall(fn, Buf, vim.api.nvim_get_current_buf()) end
					end
					local group = vim.api.nvim_create_augroup("noethervim.vm_which_key", { clear = true })
					vim.api.nvim_create_autocmd("User", {
						group = group, pattern = "visual_multi_start",
						callback = function() which_key(function(Buf, buf) Buf.clear({ buf = buf }) end) end,
					})
					vim.api.nvim_create_autocmd("User", {
						group = group, pattern = "visual_multi_exit",
						callback = function()
							which_key(function(Buf, buf)
								Buf.clear({ buf = buf })
								Buf.get({ buf = buf })
							end)
						end,
					})
				end },
			}) },
		},
	},
}
