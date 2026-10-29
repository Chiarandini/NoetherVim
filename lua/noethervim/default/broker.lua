-- Sourced by setup(), never required. Writes made through
-- noethervim.default run inside this autocmd, so they carry this file's
-- script id: `:verbose set` names NoetherVim, whatever triggered the write.
vim.api.nvim_create_autocmd("User", {
  group = vim.api.nvim_create_augroup("noethervim.default", { clear = true }),
  pattern = "NoetherVimWrite",
  callback = function() require("noethervim.default")._flush() end,
})
