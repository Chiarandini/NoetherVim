-- NOETHERVIM OPTIONS
-- see :help Noethervim -> Options for explanations of the more contentious choices (ex. autowrite
-- and autowriteall)

-- Enable the Lua bytecode cache (must be first for maximum benefit)
vim.loader.enable()

-- On macOS, Neovim launched outside a login shell may miss Homebrew's bin dirs.
-- Add them early so tools like tree-sitter, node, rg, etc. are always findable.
if vim.fn.has("mac") == 1 then
  for _, p in ipairs({ "/opt/homebrew/bin", "/usr/local/bin" }) do
    if vim.fn.isdirectory(p) == 1 and not vim.env.PATH:find(p, 1, true) then
      vim.env.PATH = p .. ":" .. vim.env.PATH
    end
  end
end

local opt = vim.o

-- Line numbers
opt.number         = true
opt.relativenumber = true

-- Mouse
opt.mouse          = "a"
opt.mousemoveevent = true

-- File handling
opt.autowrite    = true
opt.autowriteall = false
opt.autoread     = true
opt.swapfile     = false

-- Text layout
-- wrap is OFF globally; the writing profile (autocmds.lua) re-enables it
-- for writing filetypes.  The breakindent / linebreak / showbreak settings
-- only take effect when wrap is on, so they're harmless here and active
-- in writing buffers.
opt.textwidth     = 100
opt.wrap          = false
opt.breakindent   = true
opt.linebreak     = true
vim.opt.breakindentopt = "sbr,min:0,shift:1"
vim.opt.showbreak  = "↳"

-- listchars: makes `list = true` (set by the code profile in autocmds.lua)
-- readable.  tab shows as arrow, trailing whitespace as middle dot.
vim.opt.listchars = {
  tab      = "→ ",
  trail    = "·",
  nbsp     = "␣",
  extends  = "›",
  precedes = "‹",
}
-- formatoptions flags (global; writing profile re-adds `t` for writing):
--   c  auto-wrap comments using textwidth
--   r  continue comment leader after <Enter>
--   o  continue comment leader after o/O
--   q  allow formatting comments with gq
--   1  don't break line after a one-letter word
--   j  remove comment leader when joining lines
--   n  recognize numbered lists (uses formatlistpat)
-- `t` (auto-wrap text) is deliberately omitted globally so code files
-- don't get broken mid-line while typing (delegated to formatters)
opt.formatoptions  = "croq1jn"

-- Diff
vim.opt.diffopt:append("vertical")

-- Search
opt.ignorecase = true
opt.infercase  = true
opt.incsearch  = true
opt.smartcase  = true
opt.hlsearch   = true    -- <Esc> clears; [oh/]oh toggles persistently

-- Indentation
opt.tabstop    = 4
opt.shiftwidth = 4
-- autoindent: copy indent from the line above when starting a new line
-- (this is how `O` and `o` keep your code aligned).  The Neovim default
-- is already `true`, but set it explicitly so a stray ftplugin / runtime
-- file flipping it off can be more easily debugged.
-- copyindent + preserveindent: when re-indenting, reuse the existing
-- whitespace structure (tabs vs spaces, mixed leading runs) instead of
-- normalising to shiftwidth.  This is what makes `O` on a deeply-indented
-- line keep its full indent run instead of snapping back to column 0.
opt.autoindent     = true
opt.copyindent     = true
opt.preserveindent = true

-- Splits prefer bottom-right
opt.splitbelow = true
opt.splitright = true

-- Scrolling
opt.scrolloff     = 4
opt.sidescrolloff = 8
vim.opt.smoothscroll = true

-- UI
vim.opt.shortmess:append("T")
opt.visualbell    = true
opt.termguicolors = true
opt.foldcolumn    = "0"
opt.foldlevel     = 99
opt.foldlevelstart = 99
opt.foldenable    = true
vim.opt.fillchars = { fold = " " }

-- Autochdir
opt.autochdir = false

-- Session restoration
-- `localoptions` is intentionally omitted: it captures every buffer-local
-- option at save time, which then overrides updated globals when the
-- session reloads (e.g. spelllang stays "en_us" long after the distro
-- default moved to "en").  NoetherVim's FileType-driven writing/code
-- profiles re-establish the per-buffer values that matter (wrap, spell,
-- list, conceallevel, ...) on every buffer load, so capturing them in
-- sessions is mostly redundant.  Add `localoptions` back in your personal
-- options.lua if you depend on session-restoring buffer-local state.
opt.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal"

-- Undo
opt.undofile   = true
opt.undolevels = 1000
opt.undoreload = 10000

local undodir = vim.fn.stdpath("state") .. "/undo"
vim.fn.mkdir(undodir, "p")
vim.o.undodir = undodir

-- Cache/swap dirs (use stdpath so they work regardless of appname)
-- NOTE: swap file are off  by default (see Noethervim doc for the explanation)
vim.o.dir = vim.fn.stdpath("state") .. "/swap"
vim.fn.mkdir(vim.o.dir, "p")

-- Spell
-- "en" accepts all English regional dialects (US, UK, CA, AU, NZ) so the
-- default doesn't flag "colour"/"color" as wrong for either camp.  Narrow
-- in your personal config if you want strict regional checking, e.g.
-- vim.opt.spelllang = { "en_us" } or { "en_gb" } or { "en_us", "de_de" }.
vim.opt.spelllang = { "en" }
-- Spellfile lives in the user's config dir
vim.o.spellfile = vim.fn.stdpath("config") .. "/spell/en.utf-8.add"

-- History
opt.shada = "'1000,<50,s10,h"

-- Wildignore
vim.opt.wildignore:append({"*/.git/*", "*.swp"})
