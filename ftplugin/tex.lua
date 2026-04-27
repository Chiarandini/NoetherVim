-- NoetherVim ftplugin: tex
-- Buffer-local options for LaTeX files.
-- Keymaps and commands that depend on VimTeX live in the latex bundle.
-- Personal items (ink figures, bibliography shortcuts) belong in user ftplugin.
-- wrap / linebreak / spell / conceallevel / <C-l> spell-fix come from
-- the writing profile in autocmds.lua.

vim.bo.textwidth  = 110
vim.bo.synmaxcol  = 5000          -- prevent slowdown on long math lines
