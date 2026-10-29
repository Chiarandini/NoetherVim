-- Statusline toggle keymaps, as rows heirline's spec contributes. They only
-- fire User events, which do nothing until heirline has loaded.

local M = {}

---@return noethervim.Row[]
function M.rows()
  local rows = {}
  local function map(_, lhs, rhs, opts)
    table.insert(rows, vim.tbl_extend("force", opts, { lhs, rhs }))
  end
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
  return rows
end

return M
