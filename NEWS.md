# News

Breaking and behavior changes, newest first, each with what to do about it.
During the alpha, changes land without deprecation periods; this file is
where they are listed.

## 2026-10-29

- **Your settings survive plugin loads:** a plugin's configuration no longer
  overwrites an option, global mapping or command you set. `timeoutlen`
  survives which-key loading, `wildchar` blink.cmp, `winwidth` windows.nvim,
  a `<leader>j` of yours LuaSnip. Nothing to do; `:NoetherVim where <key>`
  shows a NoetherVim mapping that stepped aside for yours.
- **Options at the top of `init.lua` are kept:** NoetherVim's defaults no
  longer replace an option set before `lazy.setup()`.
- **`NOETHERVIM_NO_USER=1` hides your whole config:** besides `lua/user/`,
  Neovim no longer sources your `plugin/`, `after/` and `ftplugin/` files,
  and your LuaSnip snippets, preamble library and spellfile are not read.
- **Bundle plugins take your `opts`:** `opts` from a spec of yours now reach
  render-markdown, markdown-table-mode, betterTerm, nvim-luapad,
  distant.nvim, nvim-dap-virtual-text, nvim-dap-python and obsidian.nvim.
  For obsidian.nvim, `workspaces` in its `opts` wins over `obsidian_vault`;
  for drop.nvim, `themes` in its `opts` is now kept.
