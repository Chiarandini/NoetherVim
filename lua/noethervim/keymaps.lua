-- NoetherVim core keymaps
-- Philosophy:
--   SearchLeader  fuzzy navigation/search (default: <Space>, set vim.g.mapsearchleader)
--   <Leader>      global actions
--   <LocalLeader> filetype-specific actions
--   <C-w>         all window navigation/manipulation
--   [x / ]x       prev/next directional navigation
--   [ox / ]ox     toggle option on/off

-- Every key here is a row (keymaps/rows.lua): mapped once, unless a mapping
-- of yours is already on it. `set = "remaps"` marks a key that changes what
-- one of Vim's or Neovim's own keys does; `keymaps = { remaps = false }` in
-- lua/user/config.lua leaves all of those alone.
local map = require("noethervim.keymaps.rows").map

-- ──────────────────────────────────────────────────────────────
--  Insert mode
-- ──────────────────────────────────────────────────────────────

map("i", "<M-BS>",  "<c-w>",      { desc = "delete word backward" })
map("i", "<D-BS>",  "<c-o>dd",    { desc = "delete line" })
map("i", "<c-w>",   "<nop>",      { set = "remaps", desc = "disable.. too many windows accidentally close" })
map("i", "<C-a>",   "<Esc>ggVG",  { set = "remaps", desc = "select all" })
map("i", "<C-v>",   '<Esc>"*pa',  { set = "remaps", desc = "paste from clipboard" })
map("i", "<C-p>",   "<nop>",      { set = "remaps", desc = "disabled" })
map("i", "<C-s>",   "<nop>",      { set = "remaps", desc = "disabled" })
map("i", "<C-=>",   "<C-r>=",     { desc = "expression register" })

-- ──────────────────────────────────────────────────────────────
--  Normal mode -- general
-- ──────────────────────────────────────────────────────────────

-- Hybrid j/k: visual-line for small hops (natural under wrap), logical +
-- jumplist mark for big hops (>5) so <C-o>/<C-i> recover the jump.
--
-- feedkeys from a plain mapping, NOT `expr`. An expr mapping's return value
-- still has the typed count applied to it, so building the count into the
-- string counted it twice: `3j` returned "3gj" and Vim ran "33gj", moving 33
-- lines. Only counts above 5 escaped, because the `m'` prefix absorbed the
-- pending count before it could reach the motion. The same collision is
-- described on `arrow_or_motion` below, which is why that one uses feedkeys;
-- this is the same fix. Invoking the mapping consumes the count, so what
-- feedkeys queues carries exactly the one we build.
--
-- Inserted at the front of the typeahead (`i`), not appended. Keys already
-- waiting (the rest of a macro, a `:normal` string, typing that outran a
-- busy editor) belong after the motion; appended, they ran first, so a
-- macro `jdd` deleted the line it started on and moved afterwards.
local function vline_move(key)
  return function()
    local n = vim.v.count
    local keys
    if n > 5 then
      keys = "m'" .. n .. key      -- set jump mark, then logical-line move
    elseif n > 0 then
      keys = n .. "g" .. key       -- counted visual-line move
    else
      keys = "g" .. key            -- single visual-line hop
    end
    vim.api.nvim_feedkeys(keys, "ni", false)
  end
end
map("n", "j", vline_move("j"),
  { set = "remaps", desc = "visual-line down (jumplist for >5)" })
map("n", "k", vline_move("k"),
  { set = "remaps", desc = "visual-line up (jumplist for >5)" })

-- Scroll view without moving cursor
map("n", "zv", "zz10<c-e>", { set = "remaps", desc = "scroll view down" })
map("n", "zx", "zz10<c-y>", { set = "remaps", desc = "scroll view up" })

-- s: s does not pollute unnamed register;
map("n", "s",  '"_s',  { set = "remaps", desc = "substitute without register" })

-- S: triggers global substitution
map("n", "S",  ":%s/", { set = "remaps", desc = "global search/replace" })

-- Consistent n/N direction regardless of search direction
map({ "n", "v" }, "n",
  function() return vim.v.searchforward == 1 and "n" or "N" end,
  { set = "remaps", expr = true, silent = true, desc = "search forward" })
map({ "n", "v" }, "N",
  function() return vim.v.searchforward == 1 and "N" or "n" end,
  { set = "remaps", expr = true, silent = true, desc = "search backward" })

-- ; as :
map("n", ";", ":", { set = "remaps", desc = "command-line" })

-- <C-g> shows extended file info
map("n", "<c-g>", "g<c-g>", { set = "remaps", desc = "file info" })

-- ──────────────────────────────────────────────────────────────
--  Normal mode -- window / tab management  (<C-w> namespace)
-- ──────────────────────────────────────────────────────────────

-- <c-h/j/k/l>: shorthand for <c-w>h/j/k/l window navigation
-- `<cmd>wincmd`, not `<c-w>h`. These are equivalent today: the rhs is not
-- remapped, so `<c-w>l` reaches the builtin without consulting the Lazy
-- family that shares its prefix (`<c-w>ll`, `<c-w>li`, ...). The command
-- form is kept because it states the intent outright and stays correct if a
-- plugin ever remaps `<c-w>`, not because the key form was misbehaving --
-- the delay that prompted this turned out to be in the Oil dual-pane
-- bindings, not here.
map("n", "<c-h>", "<cmd>wincmd h<cr>", { set = "remaps", desc = "window left" })
map("n", "<c-j>", "<cmd>wincmd j<cr>", { set = "remaps", desc = "window down" })
map("n", "<c-k>", "<cmd>wincmd k<cr>", { set = "remaps", desc = "window up" })
map("n", "<c-l>", "<cmd>wincmd l<cr>", { set = "remaps", desc = "window right" })

map("n", "<c-w><a-h>", "<cmd>tabm -<cr>", { desc = "move tab left" })
map("n", "<c-w><a-l>", "<cmd>tabm +<cr>", { desc = "move tab right" })
map("n", "<c-w><c-q>", "<cmd>copen<cr>",  { set = "remaps", desc = "open quickfix" })
-- Undo tree: mbbill/undotree. Selecting a node shows the diff in a
-- side pane WITHOUT applying it; press <CR> to actually move the
-- buffer to that state. This is the non-destructive counterpart to
-- Neovim's builtin nvim.undotree, which applies state on every
-- CursorMoved.
map("n", "<c-w><c-u>", "<cmd>UndotreeToggle<cr>", { desc = "toggle undo tree", owner = "undotree" })

-- Toggle a 12-line terminal along the bottom, reusing the same terminal
-- buffer every time rather than stacking a new one per press. This
-- shadows Vim's builtin <C-w>t (go to the top window); `1<C-w>w` does
-- that instead.
local term_buf
map("n", "<c-w>t", function()
  local wins = vim.api.nvim_tabpage_list_wins(0)
  for _, win in ipairs(wins) do
    if vim.api.nvim_win_get_buf(win) == term_buf then
      if #wins > 1 then vim.api.nvim_win_close(win, false) end
      return
    end
  end
  vim.cmd("botright split")
  vim.api.nvim_win_set_height(0, 12)
  vim.wo.winfixheight = true
  if term_buf and vim.api.nvim_buf_is_valid(term_buf) then
    vim.api.nvim_win_set_buf(0, term_buf)
  else
    vim.cmd.term()
    term_buf = vim.api.nvim_get_current_buf()
  end
end, { set = "remaps", desc = "toggle terminal" })

-- <Esc><Esc> leaves terminal mode. A single <Esc> still reaches the
-- program, and autocmds.lua shortens 'timeoutlen' while terminal mode is
-- active so it is not held back for the full default second.
map("t", "<esc><esc>", "<c-\\><c-n>", { desc = "exit terminal mode" })

-- Toggle the quickfix window. A one-shot action rather than a search, so it
-- lives under <Leader> and not in the SearchLeader namespace.
map("n", "<leader>q", function()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.fn.getwinvar(win, "&buftype") == "quickfix" then
      vim.cmd("cclose")
      return
    end
  end
  vim.cmd("copen")
end, { desc = "[q]uickfix toggle" })
-- <c-w>u: set in commands.lua (show unsaved buffers)

-- Resize splits with arrow keys. Arrow direction is always direction of
-- motion: plain <Arrow> pushes the near edge outward (grow); <S-Arrow>
-- pulls the far edge inward (shrink). All eight are silent no-ops when
-- there is no neighbor on the moving edge. See util/smart_resize.lua.
--
-- Plain arrows also fall back to hjkl cursor motion when the current
-- window has nothing to resize against (single non-floating window in
-- the tab, or we're inside a floating window). Counts pass through, so
-- e.g. `5<Down>` still jumps 5 lines via the j remap.
local sr = require("noethervim.util.smart_resize")
-- nvim_feedkeys (not :normal) — :normal leaves the count pending, which
-- then collides with the count baked into vline_move's expr return
-- ("5gj"), making the j/k remap fire with a doubled count (1<Down> → 11
-- lines, 2<Down> → 21 lines). Feedkeys queues the keys after our
-- callback returns, with no pending count from our side. At the front of
-- the typeahead (`i`), for the reason given on vline_move above.
local function arrow_or_motion(motion, resize_fn)
  return function()
    if sr.is_solo() then
      local count = vim.v.count
      local keys = (count > 0 and tostring(count) or "") .. motion
      vim.api.nvim_feedkeys(keys, "mi", false)
    else
      resize_fn()
    end
  end
end
map("n", "<up>",      arrow_or_motion("k", sr.grow_up),    { set = "remaps", desc = "grow up / move up (solo)" })
map("n", "<down>",    arrow_or_motion("j", sr.grow_down),  { set = "remaps", desc = "grow down / move down (solo)" })
map("n", "<left>",    arrow_or_motion("h", sr.grow_left),  { set = "remaps", desc = "grow left / move left (solo)" })
map("n", "<right>",   arrow_or_motion("l", sr.grow_right), { set = "remaps", desc = "grow right / move right (solo)" })
map("n", "<S-up>",    function() sr.shrink_down()  end, { set = "remaps", desc = "pull bottom edge up" })
map("n", "<S-down>",  function() sr.shrink_up()    end, { set = "remaps", desc = "pull top edge down" })
map("n", "<S-left>",  function() sr.shrink_right() end, { set = "remaps", desc = "pull right edge left" })
map("n", "<S-right>", function() sr.shrink_left()  end, { set = "remaps", desc = "pull left edge right" })

-- Quick splits, all three opening an empty scratch buffer rather than a
-- second view of the current one (save with `:w <name>` to keep it).
--
-- `:vnew` / `:new` / `:tabnew` open the split and the empty buffer in one
-- step; splitting first and then `:enew` would put the current buffer in the
-- new window for a moment and fire its autocmds twice.
--
-- The buffer is wiped when it stops being displayed, so an untouched scratch
-- leaves nothing behind in the buffer list. Typed-in text is not at risk:
-- Neovim refuses to abandon a modified buffer (E37) before the wipe can
-- happen.
local function scratch(cmd)
  return function()
    vim.cmd(cmd)
    vim.bo.bufhidden = "wipe"
    vim.bo.swapfile = false
  end
end
map("n", "|", scratch("vnew"),   { set = "remaps", desc = "vertical split scratch" })
map("n", "+", scratch("tabnew"), { set = "remaps", desc = "new tab scratch" })
map("n", "_", scratch("new"),    { set = "remaps", desc = "horizontal split scratch" })

-- ──────────────────────────────────────────────────────────────
--  Normal mode -- closing things  (Z prefix)
-- ──────────────────────────────────────────────────────────────

-- A grid, not a list of initials. Vim's own ZZ (write and leave) and ZQ
-- (force out) are the bottom and top of the first column; the rest of the
-- table extends that ladder.
--
--                 Z A Q         X S W          C D E
--               this window   everything    this buffer
--   top     force, discard    ZQ  :q! ZW  :qa! ZE  :bd!
--   home    refuse if dirty   ZA  :q        ZS  :qa         ZD  :bd
--   bottom  save first        ZZ  :x        ZX  :wa|qa! ZC  :w|bd

map("n", "ZA", "<cmd>q<cr>",            { desc = "close window" })
map("n", "ZS", "<cmd>qa<cr>",           { desc = "quit all" })
map("n", "ZW", "<cmd>qa!<cr>",          { desc = "quit all! (kill nvim)" })
map("n", "ZX", "<cmd>wa<bar>qa!<cr>",   { desc = "save what you can, then force-quit" })
map("n", "ZD", "<cmd>bdelete<cr>",      { desc = "delete buffer" })
map("n", "ZE", "<cmd>bdelete!<cr>",     { desc = "delete buffer force" })
map("n", "ZC", "<cmd>write<bar>bdelete<cr>", { desc = "save and delete buffer" })
map("n", "ZR", function()
  for _, buf in pairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf)
      and vim.api.nvim_buf_get_name(buf) == ""
      and vim.bo[buf].buftype == "" then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
end, { desc = "delete scratch buffers" })

-- ──────────────────────────────────────────────────────────────
--  Normal mode -- cursor / search utilities
-- ──────────────────────────────────────────────────────────────

-- Highlight all instances of word under cursor (count + jump to next occurrence)
map("n", "-",
  ":let save_cursor=getcurpos()|let @/ = '\\<'.expand('<cword>').'\\>'|set hlsearch<CR>" ..
  "w?<CR>:%s///gn<CR>:call setpos('.', save_cursor)<CR>",
  { set = "remaps", silent = true, desc = "highlight word under cursor" })

-- Path/file utilities (cp, cm, gp) removed from core -- they shadow Vim's
-- c+p / c+m / g+p operator sequences. See templates/user/keymaps.example.lua
-- or add them to your lua/user/keymaps.lua

-- gz / gZ: the case operators Vim is missing. `gu`, `gU` and `g~` cover
-- lower, upper and toggle; neither raises just the leading letter.
--   gz  Title Case    -- `gziw`, `gzip`, `gz$`, or `gz` on a selection
--   gZ  sentence case -- same motions, only the first letter of the region
-- Both leave every character after the first as typed, so `PDE`, `LaTeX` and
-- `Toronto` survive. Implementation and the minor-word list: util/case.lua.
--
-- Title Case takes the unshifted key because it is the one with no short
-- manual equivalent. Raising a single leading letter is already two keys --
-- `~` on the character, or `guiw~` for a word -- while Title Casing a run by
-- hand is one `~` per word, so that is where an operator actually earns its
-- place.
--
-- `gs` was the other candidate and is taken (LSP signature help, lsp.lua);
-- `gC` is taken too (visual per-line comment invert). There is deliberately
-- no `gzz` line-wise double: mapping an operator and its doubled form makes
-- every `gz` wait out `timeoutlen` first, which is the same annoyance
-- `gc`/`gcc` is known for. Use `gzV` -- or `gzip`.
do
  local case = function(kind)
    return function() return require("noethervim.util.case").operator(kind) end
  end

  map("n", "gz", case("title"),    { expr = true, desc = "Title Case operator" })
  map("n", "gZ", case("sentence"), { expr = true, desc = "[Z] sentence case operator" })

  -- `:<C-u>` rather than a plain Lua callback: entering the command line from
  -- Visual mode is what sets `< and `>, and the operator needs them set
  -- before it can reselect the region.
  map("x", "gz", ":<C-u>lua require('noethervim.util.case').visual('title')<CR>",
    { silent = true, desc = "Title Case selection" })
  map("x", "gZ", ":<C-u>lua require('noethervim.util.case').visual('sentence')<CR>",
    { silent = true, desc = "[Z] sentence case selection" })
end

-- ]f / [f: next/previous file in the same directory (alphabetical order)
do
  local function navigate_file(dir)
    local current = vim.fn.expand("%:p")
    local folder  = vim.fn.expand("%:p:h")
    local files   = vim.tbl_filter(
      function(f) return vim.fn.filereadable(f) == 1 end,
      vim.fn.glob(folder .. "/*", false, true)
    )
    table.sort(files)
    for i, f in ipairs(files) do
      if f == current then
        local target = files[((i - 1 + dir) % #files) + 1]
        vim.cmd("edit " .. vim.fn.fnameescape(target))
        return
      end
    end
  end
  map("n", "]f", function() navigate_file( 1) end, { set = "remaps", desc = "next file in directory" })
  map("n", "[f", function() navigate_file(-1) end, { set = "remaps", desc = "prev file in directory" })
end

-- ──────────────────────────────────────────────────────────────
--  Normal mode -- disable overlapping ghost keys
-- ──────────────────────────────────────────────────────────────

-- Prevent ys/yS from interfering with ySS/yss
map("n", "yS",  "", { desc = "disabled (use ySS)" })
map("n", "ys",  "", { desc = "disabled (use yss)" })
map("n", "yss", "", { desc = "disabled" })

-- Toggle comment (Neovim 0.10+ builtin gc/gcc)
map("n", "<C-/>", "gcc", { remap = true, desc = "toggle comment" })
map("v", "<C-/>", "gc",  { remap = true, desc = "toggle comment" })
map("i", "<C-/>", "<Esc>gcc", { remap = true, desc = "toggle comment" })

-- Comment-yank-paste: comment original lines, paste uncommented copy below
local function comment_yank_paste()
  local win = vim.api.nvim_get_current_win()
  local cur = vim.api.nvim_win_get_cursor(win)
  local vstart = vim.fn.getpos("v")[2]
  local current_line = vim.fn.line(".")
  local set_cur = vim.api.nvim_win_set_cursor
  if vstart == current_line then
    vim.cmd.yank()
    vim.cmd("normal gcc")
    vim.cmd.put()
    set_cur(win, { cur[1] + 1, cur[2] })
  else
    if vstart < current_line then
      vim.cmd(":" .. vstart .. "," .. current_line .. "y")
      vim.cmd.put()
      set_cur(win, { vim.fn.line("."), cur[2] })
    else
      vim.cmd(":" .. current_line .. "," .. vstart .. "y")
      set_cur(win, { vstart, cur[2] })
      vim.cmd.put()
      set_cur(win, { vim.fn.line("."), cur[2] })
    end
    vim.cmd("normal! gvgc")
  end
end
map({ "n", "v", "x" }, "<C-S-r>", comment_yank_paste, { desc = "comment and paste text" })

-- gC (visual): per-line comment toggle.
-- Vim's builtin `gc` operator picks one direction for the whole range
-- (comment-everything-or-uncomment-everything based on the majority
-- state). `gC` runs the toggle line-by-line so a mixed selection ends
-- up with each line in the *opposite* state -- handy when you want to
-- swap which lines in a block are active vs. commented.
--
-- Implementation notes:
--   * Visual-mode mappings exit visual mode before the RHS runs, so we
--     read the range from the `'<` / `'>` marks (which Vim sets on the
--     way out), not from `v` / `.`.
--   * `<cmd>` keymap form prevents the leading `:` from leaving artifacts
--     in the cmdline, and because it doesn't exit visual we capture the
--     range cleanly.
--   * The toggle uses Neovim's built-in `gcc` operator (Nvim 0.10+).
local function invert_comment_visual()
  local start_line = vim.fn.line("'<")
  local end_line   = vim.fn.line("'>")
  if start_line == 0 or end_line == 0 or start_line > end_line then
    vim.notify("no visual range for gC", vim.log.levels.WARN)
    return
  end
  local commentstring = vim.bo.commentstring or ""
  local prefix = commentstring:gsub("%%s.*", ""):gsub("^%s+", ""):gsub("%s+$", "")
  if prefix == "" then
    vim.notify("no commentstring for filetype " .. vim.bo.filetype, vim.log.levels.WARN)
    return
  end
  -- Save and restore the cursor so the user lands where they started.
  local saved_pos = vim.api.nvim_win_get_cursor(0)
  for lnum = start_line, end_line do
    local line = vim.fn.getline(lnum)
    if line:match("%S") then
      vim.api.nvim_win_set_cursor(0, { lnum, 0 })
      -- gcc is the line-comment operator; without `!` it follows the
      -- builtin comment plugin if present.
      vim.cmd("normal gcc")
    end
  end
  pcall(vim.api.nvim_win_set_cursor, 0, saved_pos)
end
map({ "v", "x" }, "gC", function()
  -- Exit visual first so '< / '> are populated, then run.
  vim.api.nvim_feedkeys(
    vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
  invert_comment_visual()
end, { silent = true, desc = "invert comment per-line" })

-- ──────────────────────────────────────────────────────────────
--  Visual mode
-- ──────────────────────────────────────────────────────────────

map("v", "<", "<gv",  { set = "remaps", desc = "indent left (keep selection)" })
map("v", ">", ">gv",  { set = "remaps", desc = "indent right (keep selection)" })
map("v", "K", "JVgq", { set = "remaps", desc = "join and reflow" })
map("v", "j", "gj", { set = "remaps", desc = "visual-line down" })
map("v", "k", "gk", { set = "remaps", desc = "visual-line up" })
map("v", ";", ":",    { set = "remaps", desc = "command-line" })

-- Paste over a selection without the replaced text landing in a register.
--
-- Neovim's own visual `P` already does exactly this, so `p` is aliased to it
-- rather than reimplemented. The `"_dP` idiom this replaces was written for
-- Vim before `v_P` existed, and it is wrong at the end of a line: `"_d` on
-- the last word leaves the cursor on the character before it, so `P` pasted
-- one column early -- `alpha beta gamma` became `alpha betaX ` instead of
-- `alpha beta X`.
map("v", "p", "P", { set = "remaps", desc = "paste over (keep register)" })

-- Inner-line text object: il = between first non-blank and last non-blank char
map("x", "il", "g_o^",          { desc = "inner line (keeps indent)" })
map("o", "il", ":normal vil<CR>", { desc = "inner line (keeps indent)" })
-- al: the whole line, charwise, stopping before the line break. `V` and `yy`
-- are linewise, so their register pastes as a new line; this yanks a line to
-- drop inside another one, and `dal` empties a line without removing it.
--
-- Both ends are set by column instead of with `$`, which sets 'curswant' to
-- MAXCOL. A charwise operator reads MAXCOL as "through the end of the line"
-- and takes the newline with it, which would make `dal` close the line up and
-- `yal` carry a line break into whatever it pastes into. No motion reaches the
-- last character without setting it.
--
-- An empty line holds nothing but the line break, so the operator is cancelled
-- there rather than joining the next line up.
do
  local function around_line()
    local win  = vim.api.nvim_get_current_win()
    local lnum = vim.api.nvim_win_get_cursor(win)[1]
    local len  = #vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, true)[1]
    if len == 0 then return end
    vim.api.nvim_win_set_cursor(win, { lnum, 0 })
    vim.cmd("normal! o")
    vim.api.nvim_win_set_cursor(win, { lnum, len - 1 })
  end

  map("x", "al", around_line, { desc = "around line (no line break)" })
  map("o", "al", function()
    return vim.api.nvim_get_current_line() == "" and "<Esc>" or ":normal val<CR>"
  end, { expr = true, desc = "around line (no line break)" })
end

-- Move block of text (respects indentation)
map("v", "<down>", ":m '>+1<CR>gv=gv", { set = "remaps", desc = "move block down" })
map("v", "<up>",   ":m '<-2<CR>gv=gv", { set = "remaps", desc = "move block up" })

-- ──────────────────────────────────────────────────────────────
--  Clipboard bridges  (unnamed register != system clipboard)
-- ──────────────────────────────────────────────────────────────
-- NoetherVim leaves the unnamed register alone so transient edits
-- (ddp, xp, ciwp, ...) don't pollute the OS clipboard. Reach for
-- these explicit bridges when you want the system clipboard:
--
--   <leader>y / <leader>Y       yank (motion / line) to clipboard
--   <leader>p / <leader>P       paste (after / before) from clipboard
--   visual Y / P                shorthand yank / paste to clipboard
--   insert <C-v>                paste clipboard (see caveat below)
--   cmdline <C-y>               yank cmdline text to clipboard
--   cmdline <C-r>*              insert clipboard (Vim built-in)
--
-- Insert <C-v> shadows Vim's "insert next char literally" default.
-- Substitutes: <C-q> (literal-insert in most terminals), <C-r>+, or
-- the cmdline where <C-v>{char} is unshadowed (useful with :verbose).

-- Composable operators (operator-pending in normal, acts on selection in visual).
-- Normal-mode p/P get the plain `"*p`/`"*P`; visual-mode p/P use a different
-- sequence (immediately below) that preserves both registers, so the
-- {n,v} table on those lines would otherwise be a write that we then
-- immediately overwrite.
map({ "n", "v" }, "<leader>y", '"*y', { desc = "yank to clipboard" })
map("n",          "<leader>p", '"*p', { desc = "paste from clipboard" })
map("n",          "<leader>P", '"*P', { desc = "paste before from clipboard" })
map("n",          "<leader>Y", '"*yy', { desc = "yank line to clipboard" })

-- Visual paste variants: keep BOTH the unnamed register and the clipboard
-- pristine. `"*P` over a selection, for the same reason as `p` above -- the
-- register prefix composes with `v_P`, so this needs no delete step and gets
-- end-of-line right.
map("v", "<leader>p", '"*P', { desc = "paste clipboard (keep registers)" })
map("v", "<leader>P", '"*P', { desc = "paste clipboard (keep registers)" })

-- Visual quick shortcuts (post-selection)
map("v", "Y", '"*y', { set = "remaps", desc = "yank to clipboard" })
map("v", "P", '"*P', { set = "remaps", desc = "paste clipboard (keep registers)" })

-- ──────────────────────────────────────────────────────────────
--  Select mode
-- ──────────────────────────────────────────────────────────────

-- Alphanumeric keys in select mode replace the selection (natural text editing)
for _, key in ipairs({ "c", "g", "j", "k", "T" }) do
  map("s", key, key)
end
-- Escape once → visual; twice → normal
map("s", "<esc>", "<esc><esc>",  { set = "remaps", desc = "escape to normal" })
-- Jump to end of previous selection
map("s", "<c-a>", "<esc>`>a",  { desc = "jump past selection" })

-- ──────────────────────────────────────────────────────────────
--  Command-line mode
-- ──────────────────────────────────────────────────────────────

map("c", "<C-l>",   '<C-r>=expand("%:p:h")<CR>', { set = "remaps", desc = "insert cwd" })
map("c", "<c-y>", function()
  local text = vim.fn.getcmdline()
  vim.fn.setreg("*", text)
  local preview = #text > 60 and (text:sub(1, 57) .. "...") or text
  vim.notify(preview, vim.log.levels.INFO, { title = "yanked to clipboard" })
end, { set = "remaps", desc = "yank cmdline to clipboard" })
map("c", "<m-bs>",  "<c-w>",                    { desc = "delete word" })
-- Redirect command output to a scratch buffer
map("c", "<c-o>",   "<c-b>Redir <c-e>",         { desc = "redirect output to buffer" })

-- ──────────────────────────────────────────────────────────────
--  All modes -- <Esc> cleanup
-- ──────────────────────────────────────────────────────────────

map({ "n", "v" }, "<Esc>", function()  -- clear highlights, dismiss notifications
  vim.cmd.stopinsert()
  if vim.fn.mode():match("^[vV\22]") then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
  end
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
  vim.cmd.noh()
  -- Dismiss LSP hover/diagnostic floats spawned via util.open_floating_preview
  -- (K, gl, vim.lsp.buf.hover, etc.). vim.lsp.util sets b:lsp_floating_preview
  -- on the source buffer to the float's winid.
  local lsp_float = vim.b.lsp_floating_preview
  if lsp_float and vim.api.nvim_win_is_valid(lsp_float) then
    pcall(vim.api.nvim_win_close, lsp_float, true)
  end
  -- Dismiss DAP inspection floats (dapui.eval = `dapui_hover`,
  -- dap.ui.widgets.hover/preview = `dap-float`) when the cursor isn't inside
  -- one, so focusing into the float to scroll/expand keeps it open.
  local cur_win = vim.api.nvim_get_current_win()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if win ~= cur_win and vim.api.nvim_win_get_config(win).relative ~= "" then
      local ok, ft = pcall(vim.api.nvim_get_option_value, "filetype",
        { buf = vim.api.nvim_win_get_buf(win) })
      if ok and (ft == "dapui_hover" or ft == "dap-float") then
        pcall(vim.api.nvim_win_close, win, true)
      end
    end
  end
  if package.loaded["notify"]  then require("notify").dismiss() end
  if package.loaded["snacks"]  then require("snacks").notifier.hide() end
  if package.loaded["nvim-dap-virtual-text"] then
    require("nvim-dap-virtual-text").refresh()
  end
  vim.cmd("echo ''")
  -- `:noh` above clears v:hlsearch, which the statusline's search counter
  -- reads. Nothing else here moves the cursor or changes the mode, so on a
  -- buffer you are only reading -- help, checkhealth, quickfix -- no redraw
  -- follows on its own and the stale `3/12` sits there until something
  -- unrelated forces one.
  vim.cmd.redrawstatus()
end, { set = "remaps", silent = true })

-- ──────────────────────────────────────────────────────────────
--  Mouse
-- ──────────────────────────────────────────────────────────────

map({ "n", "v" }, "<RightMouse>", function()
  vim.cmd.exec('"normal! \\<RightMouse>"')
  local ok, menu = pcall(require, "menu")
  if ok then
    local options = vim.bo.ft == "snacks_layout_box" and "nvimtree" or "default"
    menu.open(options, { mouse = true })
  end
end, { set = "remaps", desc = "context menu" })

-- ──────────────────────────────────────────────────────────────
--  Inspection (SearchLeader+c prefix)
-- ──────────────────────────────────────────────────────────────
-- Registered here rather than alongside the pickers in inspect.lua, which
-- only runs at VeryLazy: a key made after your files could not be removed
-- from them with vim.keymap.del.
--
-- The bodies require noethervim.inspect on first press, not at load time,
-- so registering early costs nothing at startup.
--
-- SearchLeader+cL (lazy plugins), +cu (user settings) and +cc (config lua)
-- are defined in snacks.lua, in the same namespace.

local SearchLeader = require("noethervim.util").search_leader

--- Call `name` on noethervim.inspect, loading the module on first use.
local function inspect(name)
  return function() require("noethervim.inspect")[name]() end
end

map("n", SearchLeader .. "cf", inspect("files"),         { desc = "NoetherVim [f]iles" })
map("n", SearchLeader .. "cg", inspect("grep"),          { desc = "NoetherVim [g]rep" })
map("n", SearchLeader .. "cb", inspect("bundles"),       { desc = "NoetherVim [b]undles" })
map("n", SearchLeader .. "cs", inspect("snippets"),      { desc = "NoetherVim [s]nippets" })
map("n", SearchLeader .. "ct", inspect("templates"),     { desc = "NoetherVim [t]emplates" })
map("n", SearchLeader .. "ck", inspect("diff_keymaps"),  { desc = "diff [k]eymaps" })
map("n", SearchLeader .. "co", inspect("diff_options"),  { desc = "diff [o]ptions" })
map("n", SearchLeader .. "ca", inspect("diff_autocmds"), { desc = "diff [a]utocmds" })
map("n", SearchLeader .. "cd", inspect("diff_file"),     { desc = "[d]iff file" })

map("n", SearchLeader .. "?", function()
  require("noethervim.guide").open()
end, { desc = "keymap guide" })

map("n", "<leader>i", "<cmd>edit $MYVIMRC<cr>", { desc = "open [i]nit.lua" })

-- Creating and opening an override file is an action on the current buffer,
-- not a search, so it sits under <Leader> rather than SearchLeader+c.
map("n", "<leader>e", inspect("override"), { desc = "[e]dit override" })
