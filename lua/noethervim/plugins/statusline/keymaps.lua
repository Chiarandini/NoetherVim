-- Statusline toggle keymaps, bound when heirline loads (UIEnter), through
-- noethervim.default so a mapping of yours on the same key stays.

local M = {}

function M.setup()
  local map = require("noethervim.default").map
  map("n", "<c-w>sg", function()
    vim.api.nvim_exec_autocmds("User", { pattern = "HeirlineGitToggle" })
  end, { desc = "statusline git toggle" })

  map("n", "<c-w>sp", function()
    vim.api.nvim_exec_autocmds("User", { pattern = "HeirlinePdfSizeToggle" })
  end, { desc = "statusline pdf-size toggle" })

  map("n", "<c-w>sl", function()
    vim.api.nvim_exec_autocmds("User", { pattern = "HeirlineLspToggle" })
  end, { desc = "statusline lsp toggle" })

  map("n", "<c-w>sf", function()
    vim.api.nvim_exec_autocmds("User", { pattern = "HeirlineProfileToggle" })
  end, { desc = "statusline [f]iletype-profile toggle" })

  map("n", "<c-w>sP", function()
    if vim.g.heirline_directory_show == false then
      vim.api.nvim_exec_autocmds("User", {
        pattern = "HeirlineDirectoryOn",
      })
    else
      vim.api.nvim_exec_autocmds("User", {
        pattern = "HeirlineDirectoryOff",
      })
    end
  end, { desc = "statusline project directory toggle" })

  -- Pressing this again goes to the `standard` preset, not back to whatever
  -- was showing beforehand: a named destination needs nothing remembered.
  map("n", "<c-w>s<c-p>", function()
    vim.api.nvim_exec_autocmds("User", {
      pattern = "HeirlinePresetPdfToggle",
    })
  end, { desc = "statusline pdf-mode toggle" })

  map("n", "<c-w>s<c-s>", function()
    vim.api.nvim_exec_autocmds("User", {
      pattern = "HeirlinePresetStandard",
    })
  end, { desc = "statusline reset to standard" })
end

return M
