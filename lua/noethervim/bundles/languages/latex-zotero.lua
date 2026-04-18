-- NoetherVim bundle: LaTeX-Zotero
-- Enable with: { import = "noethervim.bundles.languages.latex-zotero" }
--
-- Zotero citation picker for LaTeX / Markdown.
-- Requires: Zotero running locally.

return {
  {
    "jmbuhr/telescope-zotero.nvim",
    dependencies = {
      "nvim-telescope/telescope.nvim",
      "kkharji/sqlite.lua",
    },
    ft = { "tex", "latex", "markdown" },
    opts = {},
    config = function(_, opts)
      require("telescope").load_extension("zotero")
      vim.keymap.set("n", "<localleader>z",
        "<cmd>Telescope zotero<cr>",
        { buffer = 0, desc = "Zotero citation picker" })
    end,
  },
}
