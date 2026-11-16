-- NoetherVim plugin: nvim-surround

-- Which pair `cs` and `ds` act on.
--
-- nvim-surround finds a pair with `:normal g@a[`, which mini.ai's `a`
-- answers: the pair around the cursor within 50 lines, else the next one
-- within 50. When that fails, nvim-surround searches back to the top of the
-- buffer. So a `cs[` typed for `cs{` rewrote brackets a screen or more away,
-- and deep inside a block over 100 lines long `cs{` took a nested pair for
-- the block's own.
--
-- Here the pair around the cursor wins however far apart its two halves are
-- (up to ENCLOSING lines each way). Without one, the nearest pair within
-- `surround.reach` lines (lua/user/config.lua, default 15), and otherwise
-- nothing. Quotes stay on the cursor line, as Vim's quote objects do and
-- nvim-surround documents: across lines an apostrophe in prose pairs with a
-- quote far off. Any other character has no nesting to say which pair is
-- around the cursor, so both its halves must be within reach: `cs9` typed
-- for `cs(` cannot pair two 9s a screen apart, while a `$...$` wrapped over
-- a few lines still counts. With mini.ai switched off, nvim-surround's own
-- search is held to the same reach.

-- mini.ai scans 500 lines each way in a few milliseconds.
local ENCLOSING = 500

---@return integer
local function reach()
	local n = vim.tbl_get(require("noethervim.config").get(), "surround", "reach")
	return type(n) == "number" and math.max(0, math.floor(n)) or 15
end

--- True when `sel` is around the cursor line or within `lines` of it.
local function near(sel, lines)
	local row = vim.fn.line(".")
	return sel.first_pos[1] - lines <= row and row <= sel.last_pos[1] + lines
end

--- mini.ai's `a<id>` region as an nvim-surround selection. `quiet` holds
--- back mini.ai's "not found" message, for a look that is not the last.
local function ai_find(ai, id, opts, quiet)
	local silent = ai.config.silent
	ai.config.silent = quiet or silent
	local ok, r = pcall(ai.find_textobject, "a", id, opts)
	ai.config.silent = silent
	if not ok then error(r, 0) end
	if r and r.to then
		return { first_pos = { r.from.line, r.from.col }, last_pos = { r.to.line, r.to.col } }
	end
end

--- `find` for the pair mini.ai and Vim call `id`; `line_only` for quotes.
local function pair(id, line_only)
	return function()
		local around, lines = ENCLOSING, reach()
		if line_only then around, lines = 0, 0 end
		local ok, ai = pcall(require, "mini.ai")
		if not ok then
			local sel = require("nvim-surround.config").get_selection({ motion = "a" .. id })
			return sel and near(sel, lines) and sel or nil
		end
		return ai_find(ai, id, { search_method = "cover", n_lines = around }, true)
			or ai_find(ai, id, { search_method = "nearest", n_lines = lines })
	end
end

local surrounds = {
	t = { find = pair("t") },
	T = { find = pair("t") },
	-- nvim-surround's own find for a character it has no surround for.
	invalid_key_behavior = {
		find = function(char)
			if not char or char:find("%c") then return nil end
			local sel = require("nvim-surround.config").get_selection({
				pattern = vim.pesc(char) .. ".-" .. vim.pesc(char),
			})
			local row, lines = vim.fn.line("."), reach()
			if sel and sel.first_pos[1] >= row - lines and sel.last_pos[1] <= row + lines then
				return sel
			end
		end,
	},
}
for c in ("()[]{}<>"):gmatch(".") do surrounds[c] = { find = pair(c) } end
for c in ("\"'`"):gmatch(".") do surrounds[c] = { find = pair(c, true) } end

return {
	{ -- https://github.com/kylechui/nvim-surround/blob/main/lua/nvim-surround/config.lua
		"kylechui/nvim-surround",
		version = "*",
		event = "VeryLazy",
		opts = { surrounds = surrounds },
		specs = {
			{ "NoetherVim", optional = true, opts = require("noethervim.keymaps.rows").contribute("nvim-surround", {
				{ "<C-g>s", "<Plug>(nvim-surround-insert)",          mode = "i", desc = "surround the cursor" },
				{ "<C-g>S", "<Plug>(nvim-surround-insert-line)",     mode = "i", desc = "surround the cursor, on new lines" },
				{ "ys",     "<Plug>(nvim-surround-normal)",          desc = "surround a motion" },
				{ "yS",     "<Plug>(nvim-surround-normal-line)",     desc = "surround a motion, on new lines" },
				{ "yc",     "<Plug>(nvim-surround-normal-cur)",      desc = "surround the current line" },
				{ "yC",     "<Plug>(nvim-surround-normal-cur-line)", desc = "surround the current line, on new lines" },
				{ "ds",     "<Plug>(nvim-surround-delete)",          desc = "delete a surrounding pair" },
				{ "cs",     "<Plug>(nvim-surround-change)",          desc = "change a surrounding pair" },
				{ "cS",     "<Plug>(nvim-surround-change-line)",     desc = "change a surrounding pair, on new lines" },
				{ "S",      "<Plug>(nvim-surround-visual)",          mode = "x", desc = "surround the selection", set = "remaps" },
				{ "gS",     "<Plug>(nvim-surround-visual-line)",     mode = "x", desc = "surround the selection, on new lines" },
			}, { g = { nvim_surround_no_mappings = true } }) },
		},
	},
}
