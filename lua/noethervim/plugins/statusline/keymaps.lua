-- Statusline toggle keymaps, as rows heirline's spec contributes. They flip
-- a block's visibility by id in noethervim.statusline and redraw. The PDF
-- size key comes with the latex bundle, which owns that segment.

local M = {}

---@return noethervim.Row[]
function M.rows()
  local function flip(id)
    return function()
      require("noethervim.statusline").toggle(id)
      vim.cmd.redrawstatus()
    end
  end
  local function preset(fn)
    return function()
      fn(require("noethervim.statusline"))
      vim.cmd.redrawstatus()
    end
  end
  return {
    { "<c-w>sg", flip("git"),       desc = "statusline git toggle" },
    { "<c-w>sl", flip("lsp"),       desc = "statusline lsp toggle" },
    { "<c-w>sf", flip("profile"),   desc = "statusline [f]iletype-profile toggle" },
    { "<c-w>sP", flip("directory"), desc = "statusline project directory toggle" },
    -- Pressing this again goes to the `standard` preset, not back to
    -- whatever was showing beforehand: a named destination needs nothing
    -- remembered.
    { "<c-w>s<c-p>", preset(function(sl) sl.toggle_preset("pdf") end), desc = "statusline pdf-mode toggle" },
    { "<c-w>s<c-s>", preset(function(sl) sl.apply_preset("standard") end), desc = "statusline reset to standard" },
  }
end

return M
