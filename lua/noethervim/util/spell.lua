--- Spelling helpers: correcting the word you just typed, and adding a word
--- in the forms you will actually go on to write.

local M = {}

-- ── Correcting ───────────────────────────────────────────────────────

--- Replace the nearest misspelling at or before the cursor with Vim's first
--- suggestion, leaving the cursor where it was relative to the text.
---
--- Called from insert mode through a `<Cmd>` mapping, so insert mode is
--- never left. The sequence this replaces --
--- `<c-g>u<Esc>[s1z=`]a<c-g>u` -- left insert mode to do the work, and put
--- the cursor back using the `] change mark. That mark is set from the span
--- that was replaced, not the replacement, so it lands short whenever the
--- suggestion is longer than the typo: correcting `mispelled` to
--- `misspelled` dropped the cursor a column behind where you were typing.
--- Same-length corrections looked fine, which is what made it intermittent.
---
--- Computing the shift directly is exact for any pair of lengths.
--- The nearest bad word at or before the cursor, searching back across lines
--- but not past the paragraph.
---@return integer? row, integer? col, string? word   1-indexed row, 0-indexed col
local function nearest_bad(win)
  local row, col = unpack(vim.api.nvim_win_get_cursor(win))
  local buf = vim.api.nvim_win_get_buf(win)

  --- Last bad word in `text`. `spellbadword` reports the FIRST one, so walk
  --- forward keeping the last -- and search for each occurrence from where
  --- the previous match ended, since the same word may appear more than once
  --- and `find` from the start would keep returning the first.
  local function last_bad_in(text)
    local from, at, bad = 1, nil, nil
    while true do
      local chunk = text:sub(from)
      if chunk == "" then break end
      local word = vim.fn.spellbadword(chunk)[1]
      if word == "" then break end
      local s = chunk:find(word, 1, true)
      if not s then break end
      at, bad = from + s - 1, word
      from = at + #word
    end
    return at, bad
  end

  -- The line the cursor is on, up to the end of the word it sits in. Cutting
  -- at the cursor exactly would hand a half-typed word to the checker, and
  -- half of a correctly spelled word is usually a misspelled one: with the
  -- cursor inside `spelled`, the checker saw `spelle` and duly "fixed" it.
  local cur_line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
  local rest     = cur_line:sub(col + 1):match("^[%w']*") or ""
  local at, bad  = last_bad_in(cur_line:sub(1, col + #rest))
  if bad then return row, at - 1, bad end

  -- Then backwards a line at a time. Bounded by the paragraph, because the
  -- point is the sentence you are writing: the `[s` this replaces searched
  -- the whole file with wraparound, so with nothing nearby it would silently
  -- rewrite a word pages away.
  for r = row - 1, 1, -1 do
    local line = vim.api.nvim_buf_get_lines(buf, r - 1, r, false)[1]
    if not line or line:match("^%s*$") then break end   -- paragraph boundary
    at, bad = last_bad_in(line)
    if bad then return r, at - 1, bad end
  end
end

--- Replace the nearest misspelling at or before the cursor with Vim's first
--- suggestion, leaving the cursor where it was relative to the text.
---
--- Called from insert mode through a `<Cmd>` mapping, so insert mode is never
--- left. The sequence this replaces -- `<c-g>u<Esc>[s1z=`]a<c-g>u` -- left
--- insert mode to do the work and returned via the `] change mark, which is
--- set from the span that was replaced rather than the replacement, so it
--- landed short whenever the suggestion was longer than the typo.
---
--- Only the cursor's own line is length-adjusted; a fix on an earlier line
--- does not move the column you are typing at.
function M.fix_previous()
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(win)
  local row, col = unpack(vim.api.nvim_win_get_cursor(win))

  local brow, bcol, bad = nearest_bad(win)
  if not bad then return end

  local suggestion = vim.fn.spellsuggest(bad, 1)[1]
  if not suggestion or suggestion == bad then return end

  local line = vim.api.nvim_buf_get_lines(buf, brow - 1, brow, false)[1]
  vim.api.nvim_buf_set_lines(buf, brow - 1, brow, false,
    { line:sub(1, bcol) .. suggestion .. line:sub(bcol + 1 + #bad) })

  if brow == row then
    vim.api.nvim_win_set_cursor(win, { row, col + (#suggestion - #bad) })
  else
    vim.api.nvim_win_set_cursor(win, { row, col })
  end
end


-- ── Adding ───────────────────────────────────────────────────────────

--- Add `word` to the spellfile, together with the forms you will go on to
--- write and would otherwise have to add one at a time.
---
--- What Vim already covers, measured rather than assumed:
---
---   added `bialgebra`  ->  Bialgebra, BIALGEBRA good;  bialgebra's BAD
---   added `Grbner`     ->  GRBNER, Grbner's good;      grbner      BAD
---
--- So capitalisation is already handled upward from a lowercase entry, and
--- the possessive is already handled for a capitalised one. The one gap
--- worth closing automatically is the possessive of a lowercase word.
---
--- The lowercase form of a capitalised entry is deliberately NOT added.
--- It would help a common noun first met at the start of a sentence, but it
--- would also stop a proper noun being flagged in lowercase, and most words
--- worth adding by hand are names. Add the lowercase form yourself when you
--- want it; `zg` on it will pick up its possessive too.
---
---@param word string
---@param bang boolean  true for the `!` (session-only) variants
---@return string[] added  every form actually written
function M.add_word(word, bang)
  if not word or word == "" then return {} end
  local cmd = "spellgood"
  -- `!` is the session-only variant; `vim.cmd` takes it as a field.
  local mods_bang = bang and true or false

  local forms, seen = {}, {}
  local function want(w)
    if w == "" or seen[w] then return end
    seen[w] = true
    forms[#forms + 1] = w
  end

  want(word)
  want(word .. "'s")

  local added = {}
  for _, form in ipairs(forms) do
    -- Skip what is already accepted, so the spellfile stays a record of
    -- decisions rather than of everything that was ever typed, and so that
    -- adding the same word twice is a no-op.
    if vim.fn.spellbadword(form)[1] ~= "" then
      -- Passed as an argument list rather than interpolated into a command
      -- string: the possessive carries an apostrophe, and escaping it by
      -- hand is how it stopped reaching the spellfile the first time round.
      vim.cmd({ cmd = cmd, args = { form }, bang = mods_bang, mods = { silent = true } })
      added[#added + 1] = form
    end
  end
  return added
end

--- `zg` / `zG`: add the word under the cursor, with its variants, and say
--- which forms were written -- otherwise the extra entries are invisible and
--- the next capitalised use looks like the feature failed.
---@param bang boolean
function M.add_under_cursor(bang)
  local word = vim.fn.expand("<cword>")
  local added = M.add_word(word, bang)
  if #added == 0 then
    return vim.notify(("%s: already in the spellfile"):format(word),
      vim.log.levels.INFO, { title = "spell" })
  end
  vim.notify(table.concat(added, "  "), vim.log.levels.INFO,
    { title = bang and "spell (this session)" or "spell" })
end

return M
