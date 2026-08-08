-- Quickfix / location list window.
--
-- Two flows, and a key each. You are either walking the list, looking at one
-- result after another, or you have found the one you wanted and are done
-- with the list. `<CR>` serves the first and `<S-CR>` the second, which is
-- the shape `<S-CR>` already has in the browse picker: the finishing variant
-- of the plain key.
--
-- nvim-bqf owns this buffer's `<CR>` and `o`, registering them when it loads,
-- which is after this file. Reuse its handler rather than mapping over it:
-- `open(false)` jumps and leaves the list up, `open(true)` jumps and closes
-- it. Both flows already existed; only the second lacked a key worth
-- reaching for, `o` being neither obvious nor paired with anything.

local function jump_and_close()
  local ok, handler = pcall(require, "bqf.qfwin.handler")
  if ok then
    return handler.open(true)
  end
  -- Without bqf the built-in <CR> jumps and leaves the list open, so close
  -- whichever kind of list this is afterwards.
  local loclist = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1].loclist == 1
  vim.cmd("normal! \r")
  vim.cmd(loclist and "lclose" or "cclose")
end

local function map(lhs, rhs, desc)
  vim.keymap.set("n", lhs, rhs, { buffer = 0, silent = true, desc = desc })
end

map("<s-cr>", jump_and_close, "jump to entry and close the list")
map("q", "<cmd>q<cr>", "close the list")

-- Step through entries without leaving the list. bqf claims <C-n>/<C-p> for
-- next/previous *file*, the coarser move; these are line at a time.
map("<c-j>", "j", "next entry")
map("<c-n>", "j", "next entry")
map("<c-p>", "k", "previous entry")
