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
function M.fix_previous()
  local win = vim.api.nvim_get_current_win()
  local row, col = unpack(vim.api.nvim_win_get_cursor(win))
  local line = vim.api.nvim_get_current_line()

  -- Only look behind the cursor: the word being typed is the one to fix,
  -- and a misspelling later on the line is not what <C-l> is reaching for.
  local before = line:sub(1, col)

  -- `spellbadword` reports the FIRST bad word in the string it is given, so
  -- walk forward and keep the last one, which is the nearest behind us.
  local from, bad_at, bad = 1, nil, nil
  while true do
    local chunk = before:sub(from)
    if chunk == "" then break end
    local word = vim.fn.spellbadword(chunk)[1]
    if word == "" then break end
    local s = chunk:find(word, 1, true)
    if not s then break end
    bad_at, bad = from + s - 1, word
    from = bad_at + #word
  end
  if not bad then return end

  local suggestion = vim.fn.spellsuggest(bad, 1)[1]
  if not suggestion or suggestion == bad then return end

  vim.api.nvim_set_current_line(
    line:sub(1, bad_at - 1) .. suggestion .. line:sub(bad_at + #bad))
  vim.api.nvim_win_set_cursor(win, { row, col + (#suggestion - #bad) })
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
--- the possessive is already handled for a capitalised one. The two gaps
--- are the possessive of a lowercase word, and the lowercase form of a word
--- added while capitalised -- which is the common case for a term you first
--- meet at the start of a sentence.
---
--- Adding the lowercase form does mean a genuinely lowercase use stops being
--- flagged, which for a proper noun is a small loss of strictness. It is the
--- lesser cost: being told `bialgebra` is wrong for the rest of the document
--- because you first wrote it after a full stop is the friction this exists
--- to remove.
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

  local lower = word:lower()
  if lower ~= word then
    want(lower)
    want(lower .. "'s")
  end

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
