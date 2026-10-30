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
--- Replace the nearest misspelling before the cursor with Vim's first
--- suggestion, leaving the cursor where it was relative to the text.
---
--- Finding the word is delegated to Vim's own `[s`. Spell checking is
--- syntax-aware and asking `spellbadword()` about a plain Lua string throws
--- that away: in a tex buffer `spellbadword([[\textbf{x}]])` answers
--- "textbf" while the buffer answers "". A string-based search walked into
--- every LaTeX command and "corrected" it.
---
--- Only `bad` counts. `spellbadword()` returns a kind alongside the word,
--- and three of the four are not spelling errors -- `caps` is "should start
--- with a capital", `rare` and `local` are usage notes. Ignoring the kind
--- meant the first word of a sentence came back as `{ "all", "caps" }` and
--- got rewritten to "al": correct text, silently corrupted.
---
--- Not bounded to the paragraph. An earlier attempt stopped at a blank line
--- on the theory that anything further back was not what you were writing;
--- in practice the typo you want is often the last one you left behind, two
--- paragraphs up. `[s` wraps the whole file, so the one thing rejected is a
--- match that lands at or after the cursor, which means it wrapped and there
--- is nothing behind you.
---
--- Called from insert mode through a `<Cmd>` mapping, so insert mode is
--- never left. The `<Esc>[s1z=`]a` sequence this replaces returned via the
--- `] change mark, which is set from the replaced span rather than the
--- replacement and so landed short whenever the suggestion was longer.
function M.fix_previous()
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(win)
  local row, col = unpack(vim.api.nvim_win_get_cursor(win))

  local brow, bcol, bad
  vim.api.nvim_win_call(win, function()
    if not pcall(vim.cmd, "silent! normal! [s") then return end
    local pos = vim.api.nvim_win_get_cursor(win)
    -- Landed at or after where we started: `[s` wrapped, so nothing behind.
    if pos[1] > row or (pos[1] == row and pos[2] >= col) then return end
    local word, kind = unpack(vim.fn.spellbadword())
    if word == "" or kind ~= "bad" then return end
    brow, bcol, bad = pos[1], pos[2], word
  end)

  -- Whatever happened above, the cursor belongs where the typing is.
  vim.api.nvim_win_set_cursor(win, { row, col })
  if not bad then return end

  local suggestion = vim.fn.spellsuggest(bad, 1)[1]
  if not suggestion or suggestion == bad then return end

  local line = vim.api.nvim_buf_get_lines(buf, brow - 1, brow, false)[1]
  vim.api.nvim_buf_set_lines(buf, brow - 1, brow, false,
    { line:sub(1, bcol) .. suggestion .. line:sub(bcol + 1 + #bad) })

  -- Only a fix on the cursor's own line shifts the column being typed at.
  local shift = (brow == row) and (#suggestion - #bad) or 0
  vim.api.nvim_win_set_cursor(win, { row, math.max(0, col + shift) })
end


-- ── Adding ───────────────────────────────────────────────────────────

--- Every form worth writing when `word` is added: the word itself, plus the
--- forms you will go on to write and would otherwise have to add one at a
--- time.
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
--- Pure, and public, so a config writing the same word into more than one
--- dictionary can ask for the rule once and apply its own filtering per
--- target. `spellbadword()` cannot serve that: it answers for the loaded
--- dictionaries as a whole, so the first write makes every later target
--- look already satisfied.
---
---@param word string
---@return string[] forms
function M.variants(word)
  if not word or word == "" then return {} end

  local forms, seen = {}, {}
  local function want(w)
    if w == "" or seen[w] then return end
    seen[w] = true
    forms[#forms + 1] = w
  end

  want(word)
  want(word .. "'s")
  return forms
end

--- Add `word` to the spellfile in each of its |M.variants|.
---
---@param word string
---@param bang boolean  true for the `!` (session-only) variants
---@return string[] added  every form actually written
function M.add_word(word, bang)
  if not word or word == "" then return {} end
  local cmd = "spellgood"
  -- `!` is the session-only variant; `vim.cmd` takes it as a field.
  local mods_bang = bang and true or false

  local added = {}
  for _, form in ipairs(M.variants(word)) do
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
