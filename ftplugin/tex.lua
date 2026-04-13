-- NoetherVim ftplugin: tex
-- Buffer-local options for LaTeX files.
-- Keymaps and commands that depend on VimTeX live in the latex bundle.
-- Personal items (ink figures, bibliography shortcuts) belong in user ftplugin.

vim.bo.textwidth  = 110
vim.bo.synmaxcol  = 5000          -- prevent slowdown on long math lines
vim.wo.conceallevel = 2            -- reveal conceal chars (e.g. vimtex math symbols)
-- spell + <C-l> spell-fix are set by the prose autocmd in autocmds.lua
