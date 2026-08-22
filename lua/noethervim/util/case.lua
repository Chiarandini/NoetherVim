--- Capitalization operators: `gz` (sentence case) and `gZ` (Title Case).
---
--- Vim ships three case operators -- `gu`, `gU`, `g~` -- and no way to raise
--- only the leading letter. The usual workaround, `guiw~`, leans on the fact
--- that an operator leaves the cursor at the start of what it changed, so the
--- `~` lands on the first character. It has two problems: `gu` flattens the
--- rest of the word on the way through, so `LaTeX` comes back as `Latex`, and
--- the pair does not repeat with `.`.
---
--- Both operators here are conservative. They change the case of one leading
--- character per unit and leave every other character exactly as typed, which
--- keeps proper nouns, acronyms and CamelCase intact -- the things that turn
--- up constantly in the prose these get used on.
---
--- Registered in keymaps.lua as an `operatorfunc`, so `gziw`, `gzip`, `gz3w`
--- and `gz$` all work and all repeat with `.`.

local M = {}

--- Words that stay lowercase inside a Title Cased run, unless they land in
--- first or last position. Replace wholesale from `lua/user/` to change the
--- house style; set it to `{}` to capitalize every word unconditionally.
---
--- Built from a list rather than written as a table literal because `and`,
--- `or`, `for`, `in` and `if` are Lua keywords and would each need bracket
--- syntax, which makes the list unreadable for no gain.
M.minor_words = {}
for _, w in ipairs({
  "a", "an", "the",
  "and", "as", "at", "but", "by", "for", "if", "in", "nor", "of", "on",
  "or", "per", "so", "than", "that", "to", "up", "via", "with", "yet",
  "from", "into", "onto", "over",
}) do
  M.minor_words[w] = true
end

-- ── Character helpers ────────────────────────────────────────────────

--- Does `ch` carry case? `vim.fn.toupper` is multibyte-aware where Lua's
--- `string.upper` is not, so this recognises `é` as a letter and `7`, `\`
--- or `{` as not.
local function is_cased(ch)
  return vim.fn.toupper(ch) ~= vim.fn.tolower(ch)
end

--- The whole UTF-8 character starting at byte `i`, plus its byte length.
--- Only ever called on a lead byte, so the continuation-byte range does not
--- need handling.
local function char_at(text, i)
  local b = text:byte(i)
  if not b then return nil end
  local len = b < 0x80 and 1 or (b < 0xE0 and 2 or (b < 0xF0 and 3 or 4))
  return text:sub(i, i + len - 1), len
end

--- Byte index, character and byte length of the first character in `text`
--- that carries case. Leading whitespace, quotes, digits and punctuation are
--- stepped over, so `"(the cat)"` capitalizes `t`.
---
--- With `skip_macros` (set in tex buffers) a leading control sequence is
--- handled rather than walked into, because the first cased byte of
--- `\emph{the cat}` belongs to the macro name and raising it would rename
--- the command to `\Emph`.
---
--- Returns nil when there is nothing to change.
local function first_cased(text, skip_macros)
  local i = 1
  while i <= #text do
    if skip_macros and text:sub(i, i) == "\\" then
      local _, stop = text:find("^\\%a+", i)
      if stop then
        -- `\emph{the cat}`: the prose lives inside the group, so step over
        -- the macro name and its opening brace. `\LaTeX is great` has no
        -- group, which makes the macro itself the first word -- it already
        -- renders however it renders, so there is nothing to raise.
        if text:sub(stop + 1, stop + 1) ~= "{" then return nil end
        i = stop + 2
      else
        -- An accent macro (`\'e`, `\^o`, `\"u`). The letter it decorates is
        -- the character we want; uppercasing it keeps the accent.
        i = i + 2
      end
    else
      local ch, len = char_at(text, i)
      if not ch then return nil end
      if is_cased(ch) then return i, ch, len end
      i = i + len
    end
  end
  return nil
end

--- Apply `case_fn` (`vim.fn.toupper` or `vim.fn.tolower`) to the first cased
--- character of `text`, leaving the rest byte-for-byte alone.
local function recase_first(text, case_fn, skip_macros)
  local i, ch, len = first_cased(text, skip_macros)
  if not i then return text end
  return text:sub(1, i - 1) .. case_fn(ch) .. text:sub(i + len)
end

-- ── Transforms ───────────────────────────────────────────────────────

--- Sentence case: raise the first cased character of the whole run.
---   `the cat sat by Toronto` -> `The cat sat by Toronto`
function M.sentence(text, skip_macros)
  return recase_first(text, vim.fn.toupper, skip_macros)
end

--- Title Case: raise the first cased character of every whitespace-separated
--- word, and lower it again for a minor word that is neither first nor last.
---   `the cat sat by the window` -> `The Cat Sat by the Window`
---
--- Words are collected before any of them is rewritten, because "last word"
--- is not knowable while rewriting in place. Whitespace between words is
--- copied through verbatim so newlines and alignment survive a linewise or
--- multi-line motion.
function M.title(text, skip_macros)
  local spans, init = {}, 1
  while true do
    local s, e = text:find("%S+", init)
    if not s then break end
    spans[#spans + 1] = { s, e }
    init = e + 1
  end

  local out, cursor = {}, 1
  for n, span in ipairs(spans) do
    local s, e = span[1], span[2]
    local word = text:sub(s, e)
    -- Compare on the letters alone so trailing punctuation does not stop
    -- `of,` from being recognised as minor.
    local core  = (word:gsub("%A", "")):lower()
    local minor = M.minor_words[core] and n > 1 and n < #spans

    out[#out + 1] = text:sub(cursor, s - 1)
    out[#out + 1] = recase_first(word, minor and vim.fn.tolower or vim.fn.toupper, skip_macros)
    cursor = e + 1
  end
  out[#out + 1] = text:sub(cursor)

  return table.concat(out)
end

-- ── Operator plumbing ────────────────────────────────────────────────

local CTRL_V = "\22"

--- Register type `getregionpos` wants, keyed by the motion type
--- `operatorfunc` is handed.
local REGTYPE = { char = "v", line = "V", block = CTRL_V }

--- Filetypes where a leading `\command` should be stepped over rather than
--- treated as the first word.
local MACRO_FILETYPES = { tex = true, latex = true, plaintex = true, context = true }

--- Rewrite the region between marks `m1` and `m2` through `transform`.
---
--- Everything goes through the buffer API rather than a yank/put pair, and
--- that is load-bearing rather than stylistic: `p` is itself a change, so an
--- operator that ended by putting would leave *the put* as the last change
--- and `.` would repeat a paste instead of the operator. Editing through
--- `nvim_buf_set_text` leaves the redo register to `g@`, which is what makes
--- dot-repeat work. It also spares the unnamed register.
---
--- `getregionpos` does the column arithmetic that made the register route
--- tempting in the first place. It reports each line's span as 1-based byte
--- columns whose end lands on the *last byte* of the last character, so
--- `[start - 1, end)` is the 0-based half-open range the API wants, multibyte
--- included, for all three region types.
local function replace(transform, m1, m2, regtype)
  local buf  = vim.api.nvim_get_current_buf()
  local skip = MACRO_FILETYPES[vim.bo.filetype] or false

  local ok, spans = pcall(vim.fn.getregionpos,
    vim.fn.getpos(m1), vim.fn.getpos(m2), { type = regtype })
  if not ok or type(spans) ~= "table" or #spans == 0 then return end

  local segs = {}
  for i, span in ipairs(spans) do
    local row  = span[1][2] - 1
    local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
    if not line then return end
    -- An empty line comes back as column 0 on both ends, and `$` in Visual
    -- mode can report a column past the end, so both edges get clamped.
    local sc = math.min(math.max(span[1][3] - 1, 0), #line)
    local ec = math.min(math.max(span[2][3], sc), #line)
    segs[i] = { row = row, sc = sc, ec = ec, text = line:sub(sc + 1, ec) }
  end

  local new = {}
  if regtype == CTRL_V then
    -- A blockwise region is a column of independent runs, so each row gets
    -- its own leading capital -- the whole point of selecting a block.
    for i, seg in ipairs(segs) do new[i] = transform(seg.text, skip) end
  else
    -- Charwise and linewise are one run of text that happens to be broken
    -- over lines, so the transform sees it whole and "first word" means the
    -- first word of the region, not of every line. Both transforms copy
    -- whitespace through verbatim, so the newlines survive to split on.
    new = vim.split(transform(table.concat(vim.tbl_map(function(s) return s.text end, segs), "\n"), skip), "\n")
    -- A transform that changed the line count would desynchronise the spans
    -- from the buffer. Neither of ours can, but bailing beats corrupting.
    if #new ~= #segs then return end
  end

  -- Bottom-up: a replacement can differ in byte length from what it replaced,
  -- and later spans were measured against the buffer as it stands now.
  for i = #segs, 1, -1 do
    local seg = segs[i]
    if new[i] ~= seg.text then
      vim.api.nvim_buf_set_text(buf, seg.row, seg.sc, seg.row, seg.ec, { new[i] })
    end
  end
end

--- `operatorfunc` entry points. Neovim calls these with the motion type once
--- `g@` has consumed a motion; dot-repeat comes with that for free.
function M.opfunc_sentence(motion) replace(M.sentence, "'[", "']", REGTYPE[motion]) end
function M.opfunc_title(motion)    replace(M.title,    "'[", "']", REGTYPE[motion]) end

--- Expression-mapping body for the normal-mode operators. Setting
--- `operatorfunc` here rather than once at load time keeps `gz` and `gZ` from
--- fighting over the single global slot.
---@param kind "sentence"|"title"
function M.operator(kind)
  vim.go.operatorfunc = "v:lua.require'noethervim.util.case'.opfunc_" .. kind
  return "g@"
end

--- Visual-mode body. Reached through a `:<C-u>` mapping, which leaves Visual
--- mode and so has already set `< / `> by the time this runs. `visualmode()`
--- reports which of the three the selection was.
---@param kind "sentence"|"title"
function M.visual(kind)
  local regtype = vim.fn.visualmode()
  replace(kind == "title" and M.title or M.sentence, "'<", "'>",
    regtype == "" and "v" or regtype)
end

return M
