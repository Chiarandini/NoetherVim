# Notable keybindings

The [keybinding philosophy](../README.md#keybinding-philosophy) covers how the
keyspace is organised, and `:help noethervim-keymaps` lists every binding the
distribution sets. This page is neither. It is the handful of individual
choices that are worth an argument: what each one displaced, why the trade was
worth making, and the ten lines you need to take it with you.

Every snippet here is standalone. None of it depends on NoetherVim, and none of
it depends on a plugin unless the entry says so.

## `j` and `k` know the difference between a hop and a jump

Wrapped lines force a choice. Map `j` to `gj` and short movements inside a
wrapped paragraph behave the way the screen looks, but `10j` now counts screen
rows instead of lines, and none of it enters the jumplist, so `<C-o>` cannot
take you back. Leave `j` alone and every wrapped paragraph becomes a single
unnavigable line.

The split is by count. A bare press or a small count moves by visual line. A
count above five sets a jumplist mark first and then moves by logical line,
because a movement that large is a jump, and jumps should be undoable.

```lua
local function vline_move(key)
  local n = vim.v.count
  if n > 5 then
    return "m'" .. n .. key      -- set jump mark, then logical-line move
  elseif n > 0 then
    return n .. "g" .. key       -- counted visual-line move
  else
    return "g" .. key            -- single visual-line hop
  end
end

vim.keymap.set("n", "j", function() return vline_move("j") end, { expr = true })
vim.keymap.set("n", "k", function() return vline_move("k") end, { expr = true })
```

The threshold of five is arbitrary and worth tuning. Set it to whatever number
of lines you can cross without losing your place.

## `n` always goes forward

After `/pattern`, `n` goes down. After `?pattern`, `n` goes up. This is
consistent behaviour and it is still the wrong default, because by the time you
press `n` you have usually forgotten which key opened the search. The direction
of the key should be a property of the key, not of a decision you made two
seconds ago.

```lua
vim.keymap.set({ "n", "v" }, "n",
  function() return vim.v.searchforward == 1 and "n" or "N" end,
  { expr = true, silent = true })
vim.keymap.set({ "n", "v" }, "N",
  function() return vim.v.searchforward == 1 and "N" or "n" end,
  { expr = true, silent = true })
```

`?` is still worth using: it starts the search upward. It just no longer
inverts the two keys you press afterwards.

## `Z` is a grid, not a list of initials

Vim ships `ZZ` (write and quit) and `ZQ` (quit, discarding changes). Two keys
that read as arbitrary until you notice they are the two corners of a table
nobody finished.

Rows are how much you are willing to lose. Columns are what you are closing.

|                        | this window | everything      | this buffer |
|------------------------|-------------|-----------------|-------------|
| force, discard changes | `ZQ` `:q!`  | `ZW` `:qa!`     | `ZE` `:bd!` |
| refuse if dirty        | `ZA` `:q`   | `ZS` `:qa`      | `ZD` `:bd`  |
| save first             | `ZZ` `:x`   | `ZX` `:wa\|qa!` | `ZC` `:w\|bd` |

Filling in the other seven costs nothing, and the shape is what makes it
learnable: you do not recall the letter, you recall the cell.

```lua
vim.keymap.set("n", "ZA", "<cmd>q<cr>")
vim.keymap.set("n", "ZS", "<cmd>qa<cr>")
vim.keymap.set("n", "ZW", "<cmd>qa!<cr>")
vim.keymap.set("n", "ZX", "<cmd>wa<bar>qa!<cr>")
vim.keymap.set("n", "ZD", "<cmd>bdelete<cr>")
vim.keymap.set("n", "ZE", "<cmd>bdelete!<cr>")
vim.keymap.set("n", "ZC", "<cmd>write<bar>bdelete<cr>")
```

`ZX` is the one that earns its place: save every buffer that can be saved, then
force out past the ones that cannot. `ZW` is the panic key.

## Arrow keys resize the window they are in

The arrow keys duplicate `hjkl` and are far enough from home row that nobody
uses them for motion. That makes them four free keys, plus four more with
shift.

The part worth copying is not "arrows resize" but the direction rule. Vim's own
`:resize` grows the current window by preferring its right or bottom border and
silently flipping to the other side when the window is against the screen edge,
which makes arrow bindings feel inverted in exactly the case where you notice.
Instead, bind the arrow to the direction the border moves: `<Right>` pushes the
right edge rightward, `<S-Right>` pulls the left edge rightward. Every
operation is a no-op when there is no neighbour on the moving edge, rather than
secretly resizing the opposite side.

```lua
local function neighbor(dir)
  local cur, nbr = vim.fn.winnr(), vim.fn.winnr("1" .. dir)
  return nbr ~= cur and vim.fn.win_getid(nbr) or nil
end

vim.keymap.set("n", "<Right>", function()
  if neighbor("l") then vim.fn.win_move_separator(0, 2) end
end)
vim.keymap.set("n", "<Left>", function()
  local w = neighbor("h")
  if w then vim.fn.win_move_separator(w, -2) end
end)
vim.keymap.set("n", "<Down>", function()
  if neighbor("j") then vim.fn.win_move_statusline(0, 2) end
end)
vim.keymap.set("n", "<Up>", function()
  local w = neighbor("k")
  if w then vim.fn.win_move_statusline(w, -2) end
end)
```

`win_move_separator()` and `win_move_statusline()` treat the resize as a drag
of the border between two windows, which is why the neighbour check is
required: on the bottom-most window, `win_move_statusline()` will happily eat
rows from `'cmdheight'`.

NoetherVim adds one more branch. When the tab has a single non-floating window,
or the cursor is inside a float, there is nothing to resize, so the arrows fall
through to `hjkl` motion instead of doing nothing. A key that is dead in the
common case does not survive as muscle memory.

## `<Esc>` means stop showing me things

`<Esc>` already means "get out of this mode". Extending it to "get rid of
whatever is on screen" costs nothing, because in normal mode it otherwise does
nothing at all.

Search highlighting, notification toasts, and LSP hover floats each ship their
own dismissal, and remembering three of them is two too many.

```lua
vim.keymap.set({ "n", "v" }, "<Esc>", function()
  vim.cmd.stopinsert()
  vim.cmd.noh()

  -- vim.lsp.util sets this on the source buffer to the float's winid
  local float = vim.b.lsp_floating_preview
  if float and vim.api.nvim_win_is_valid(float) then
    pcall(vim.api.nvim_win_close, float, true)
  end

  if package.loaded["snacks"] then require("snacks").notifier.hide() end
  if package.loaded["notify"] then require("notify").dismiss() end
end, { silent = true })
```

The rule that keeps this from becoming a junk drawer: `<Esc>` may dismiss
things, and may not change the buffer. Everything it closes has to be
recoverable by doing the thing again.

## The unnamed register is not the clipboard

Setting `clipboard=unnamedplus` makes every yank reach the system clipboard,
and also makes `x`, `dd`, `c` and every delete-shaped operation reach it. Copy
something in the browser, delete a line in Neovim to make room for it, and the
paste is gone.

Neovim's default is already correct (`'clipboard'` is empty). The work is
building explicit bridges so that reaching the clipboard on purpose is one key
rather than a three-key register prefix, and stopping transient edits from
clobbering the unnamed register too.

```lua
-- Transient edits should not cost you the register
vim.keymap.set("n", "s", '"_s')     -- substitute char, keep the register
vim.keymap.set("v", "p", '"_dP')    -- paste over a selection, keep the register

-- Explicit bridges, in both directions
vim.keymap.set({ "n", "v" }, "<Leader>y", '"*y')
vim.keymap.set("n", "<Leader>Y", '"*yy')
vim.keymap.set("n", "<Leader>p", '"*p')
vim.keymap.set("n", "<Leader>P", '"*P')
vim.keymap.set("v", "Y", '"*y')
vim.keymap.set("v", "P", '"_d"*P')  -- clipboard in, both registers intact
```

Visual `p` is the one people notice first. Selecting a word and pasting over it
normally swaps the paste into the unnamed register, so pasting the same text
over a second word does something different than it did the first time.

## `;` opens the command line

`:` is on the shifted layer of a key you press dozens of times an hour. `;`
repeats the last `f` / `t` motion, which is genuinely useful and which most
people replace with `f` again anyway.

```lua
vim.keymap.set({ "n", "v" }, ";", ":")
```

Whether this is worth it depends entirely on how much you lean on `f{char}`
with `;` to repeat. If you do, keep `;` and remap `:` from somewhere else. If
you do not, this is the highest-frequency keystroke saving available in Vim,
and the habit sticks within a day.

## The smaller ones

**`gC` inverts comments line by line (visual).** The builtin `gc` operator
picks one direction for the whole range based on the majority state, so a
half-commented block becomes fully commented or fully uncommented. `gC` toggles
each line independently, which is what you want when you are swapping which
lines in a block are live.

**`|`, `_` and `+` for splits.** The keys are shaped like the thing they make:
`|` splits vertically, `_` splits horizontally, `+` opens a tab. They displace
"go to screen column", "down N-1 lines to first non-blank", and "down one line
to first non-blank", none of which anyone will miss. NoetherVim opens a scratch
buffer in the new split rather than duplicating the current one.

**`-` counts the word under the cursor.** Highlights every instance of the word
under the cursor and reports the count, without moving the cursor. `*` moves;
this does not, which makes it usable as a question rather than a motion.

**`[f` and `]f` walk the directory.** Previous and next file in the current
directory, alphabetically, wrapping at the ends. Worth more than it sounds for
numbered files: chapters, dated notes, migrations.

**`il` is the inner-line text object.** From the first non-blank character to
the last, so `dil` clears a line's content without touching its indentation and
`cil` retypes it in place. Vim ships no text object for this.

**`zv` and `zx` scroll the view, not the cursor.** Ten lines of scroll with the
cursor held in place, for reading past the bottom of the window without losing
where you were.

**`<C-w>t` reuses one terminal.** A twelve-line terminal along the bottom that
toggles rather than stacking a new buffer per press, so the shell you started
five minutes ago is still there. `<Esc><Esc>` leaves terminal mode. The detail
that makes it usable: `'timeoutlen'` is global and defaults to a full second,
which would hold a single `<Esc>` back for that long before passing it to
whatever is running. NoetherVim drops it to 150ms on `TermEnter` and restores
it on `TermLeave`.

**Case encodes the destination in Oil.** `yp` / `yd` / `yn` yank the full path,
the parent directory and the bare filename; `Yp` / `Yd` / `Yn` do the same into
the system clipboard. One sub-scheme, learned once.

**`yc` and `yC` replace `yss` and `ySS`.** nvim-surround's line-wise mappings
are the only ones in the plugin that double a letter, which makes them slow to
type and hard to recall. `yc` is `yss` and `yC` is `ySS`.

**Command-line `<C-o>` captures output.** Jumps to the start of the line,
prefixes it with `Redir`, and returns to the end, so `:hi<C-o><CR>` sends the
output to a scratch buffer instead of a paged wall you cannot search. The
keymap is one line (`"<c-b>Redir <c-e>"`); the work is the `:Redir` command
behind it, which NoetherVim defines to cover both `:commands` and `!shell`.
`<C-l>` inserts the current file's directory, and `<C-y>` copies the command
line itself to the clipboard.

**Select mode accepts typing.** In select mode (which is what you land in after
a snippet placeholder), letters replace the selection instead of running
commands, `<Esc>` twice returns to normal, and `<C-a>` jumps past the end of
what was selected.

## Everything else

`:help noethervim-keymaps` is the full list, including the prefix namespaces
and a table of every Vim default the distribution shadows. Inside a running
Neovim, `<Space>?` shows the same thing read from live state, and `<CR>` on any
line jumps to where that keymap is defined.
