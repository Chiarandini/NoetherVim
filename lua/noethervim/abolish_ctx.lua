local M = {}

local fts = require("noethervim.util.filetypes")

function M.in_spell_region(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if vim.b[bufnr].noethervim_abolish_force then return true end

  local ft = vim.bo[bufnr].filetype
  if fts.writing[ft] then return true end
  if fts.non_code[ft] then return false end

  local pos = vim.api.nvim_win_get_cursor(0)
  local row = pos[1] - 1
  local col = math.max(pos[2] - 1, 0)

  local ok_parser, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok_parser or not parser then return false end
  pcall(parser.parse, parser, { row, row + 1 })

  local ok, captures = pcall(vim.treesitter.get_captures_at_pos, bufnr, row, col)
  if not ok or not captures then return false end
  for _, cap in ipairs(captures) do
    if cap.capture == "spell" or cap.capture == "comment" then
      return true
    end
  end
  return false
end

return M
