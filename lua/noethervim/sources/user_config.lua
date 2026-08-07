-- Native blink.cmp source for the fixed-vocabulary fields in
-- `lua/user/config.lua`.
--
-- Those fields take one of a known set of strings, and the set is not
-- guessable: `colorscheme` grows when the ui.colorscheme bundle is enabled,
-- and shrinks again when it is not. Reading it off a doc page is a worse
-- answer than offering it where the value is typed.
--
-- Every field here resolves its values at request time from something that
-- already knows them -- `getcompletion` for colorschemes, the statusline
-- registry for edge styles -- so this file cannot drift out of step with
-- what the distribution actually accepts. Fields whose values would have to
-- be copied from `types.lua` are deliberately absent; a second copy of a
-- list is how the first one goes stale.

---@type table<string, fun(): string[]>
local fields = {
  colorscheme = function()
    return vim.fn.getcompletion("", "color")
  end,
  edge_style = function()
    return require("noethervim.statusline").list_edge_styles()
  end,
}

local Source = {}

function Source.new(_, _config)
  return setmetatable({}, { __index = Source })
end

function Source:enabled()
  local name = vim.api.nvim_buf_get_name(0)
  return name:match("lua/user/config%.lua$") ~= nil
      or name:match("config%.example%.lua$") ~= nil
end

function Source:get_trigger_characters()
  return { '"', "'" }
end

function Source:get_completions(context, callback)
  local function empty()
    callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = {} })
  end

  local col  = context.cursor[2]     -- 0-indexed byte column
  local row0 = context.cursor[1] - 1 -- 0-indexed for the LSP range
  local before = context.line:sub(1, col)

  -- `<field> = "<partial>` with the cursor still inside the quotes. The
  -- opening quote is captured so the replacement can start just after it.
  local field, quote_pos = before:match("([%w_]+)%s*=%s*[\"']()")
  if not field or not fields[field] then return empty() end
  -- A closing quote between the opening one and the cursor means the value
  -- is already finished and we are somewhere else on the line.
  if before:sub(quote_pos):find("[\"']") then return empty() end

  local ok, values = pcall(fields[field])
  if not ok then return empty() end

  local items = {}
  for _, value in ipairs(values) do
    items[#items + 1] = {
      label    = value,
      kind     = require("blink.cmp.types").CompletionItemKind.EnumMember,
      textEdit = {
        newText = value,
        range   = {
          start   = { line = row0, character = quote_pos - 1 },
          ["end"] = { line = row0, character = col },
        },
      },
    }
  end

  callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = items })
end

return Source
