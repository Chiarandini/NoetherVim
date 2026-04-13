-- Native blink.cmp source for todo-comment keywords.
-- Triggered when typing "@" on a line that has only whitespace before it.
-- Inserts the language-appropriate comment prefix + keyword, e.g. "-- TODO: ".

local words = {
	"TODO", "HACK", "WARN", "WARNING", "PERF", "OPTIM", "PERFORMANCE", "OPTIMIZE",
	"NOTE", "INFO", "TEST", "TESTING", "PASSED", "FAILED", "FIX", "FIXME", "BUG",
	"FIXIT", "ISSUE",
}

local COMMENT_PREFIX = {
	lua             = "-- ",
	vim             = '" ',
	tex             = "% ",
	python          = "# ",
	typescriptreact = "// ",
	typescript      = "// ",
	javascript      = "// ",
}

local Source = {}

function Source.new(_, _config)
	return setmetatable({}, { __index = Source })
end

function Source:get_trigger_characters()
	return { "@" }
end

function Source:get_completions(context, callback)
	local col  = context.cursor[2]     -- 0-indexed byte column
	local row0 = context.cursor[1] - 1 -- 0-indexed for LSP range

	-- Text on the current line up to (not including) the cursor
	local before = string.sub(context.line, 1, col)

	-- Only activate when line is: optional whitespace + "@" + optional word chars
	local at_pos = before:find("@")
	if not at_pos or not string.sub(before, 1, at_pos - 1):match("^%s*$") then
		callback({ is_incomplete_forward = true, is_incomplete_backward = true, items = {} })
		return
	end

	local at_col0 = at_pos - 1 -- 0-indexed; LSP range start

	local prefix = COMMENT_PREFIX[vim.bo.filetype] or "// "

	local items = {}
	for _, word in ipairs(words) do
		table.insert(items, {
			label      = word,
			filterText = "@" .. word, -- typing @TO still matches @TODO
			kind       = require("blink.cmp.types").CompletionItemKind.Keyword,
			textEdit   = {
				newText = prefix .. word .. ": ",
				range   = {
					start   = { line = row0, character = at_col0 },
					["end"] = { line = row0, character = col },
				},
			},
		})
	end

	callback({ is_incomplete_forward = true, is_incomplete_backward = true, items = items })
end

return Source
