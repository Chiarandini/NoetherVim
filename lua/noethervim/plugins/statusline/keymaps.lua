-- Statusline toggle keymaps.

local M = {}

function M.setup()
  vim.keymap.set("n", "<c-w>sg", function()
    vim.api.nvim_exec_autocmds("User", { pattern = "HeirlineGitToggle" })
  end, { desc = "statusline git toggle" })

  vim.keymap.set("n", "<c-w>sp", function()
    vim.api.nvim_exec_autocmds("User", { pattern = "HeirlinePdfSizeToggle" })
  end, { desc = "statusline pdf-size toggle" })

  vim.keymap.set("n", "<c-w>sl", function()
    vim.api.nvim_exec_autocmds("User", { pattern = "HeirlineLspToggle" })
  end, { desc = "statusline toggle Lsp" })

  vim.keymap.set("n", "<c-w>sP", function()
    if vim.g.heirline_directory_show == false then
      vim.api.nvim_exec_autocmds("User", {
        pattern = "HeirlineDirectoryOn",
      })
    else
      vim.api.nvim_exec_autocmds("User", {
        pattern = "HeirlineDirectoryOff",
      })
    end
  end, { desc = "Pwd In Statusline" })

  vim.keymap.set("n", "<c-w>s<c-p>", function()
    vim.api.nvim_exec_autocmds("User", {
      pattern = "HeirlinePDFModeOn",
    })
  end, { desc = "Pwd In Statusline" })
end

return M
