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
opt.textwidth     = 90
opt.wrap          = true
opt.breakindent   = true
opt.linebreak     = true
vim.opt.breakindentopt = "sbr,min:0,shift:1"
vim.opt.showbreak  = "↳"
-- formatoptions flags:
--   t  auto-wrap text using textwidth
--   c  auto-wrap comments using textwidth
--   r  continue comment leader after <Enter>
--   o  continue comment leader after o/O
--   q  allow formatting comments with gq
--   1  don't break line after a one-letter word
--   j  remove comment leader when joining lines
--   n  recognize numbered lists (uses formatlistpat)
opt.formatoptions  = "tcroq1jn"

-- Diff
vim.opt.diffopt:append("vertical")

-- Search
opt.ignorecase = true
opt.infercase  = true
opt.incsearch  = true
opt.smartcase  = true
opt.hlsearch   = false   -- off by default; toggle with [oh

-- Indentation
opt.tabstop    = 4
opt.shiftwidth = 4

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
vim.cmd("set fillchars=fold:\\ ")

-- Autochdir
opt.autochdir = false

-- Session restoration
opt.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"

-- Undo
opt.undofile   = true
opt.undolevels = 1000
opt.undoreload = 10000

local undodir = vim.fn.stdpath("state") .. "/undo"
vim.fn.mkdir(undodir, "p")
vim.o.undodir = undodir

-- Cache/swap dirs (use stdpath so they work regardless of appname)
vim.o.dir = vim.fn.stdpath("state") .. "/swap"
vim.fn.mkdir(vim.o.dir, "p")

-- Spell
vim.opt.spelllang = { "en_us" }
-- Spellfile lives in the user's config dir
vim.o.spellfile = vim.fn.stdpath("config") .. "/spell/en.utf-8.add"

-- History
opt.shada = "'1000,<50,s10,h"

-- Wildignore
vim.opt.wildignore:append({"*/.git/*", "*.swp"})

-- Fallback colorscheme applied before plugins load (overwritten by the real theme)
vim.cmd.colorscheme("slate")
