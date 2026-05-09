-- NoetherVim bundle: LaTeX-Zotero
-- Enable with: { import = "noethervim.bundles.languages.latex-zotero" }
--
-- Zotero citation picker for LaTeX / Markdown / Quarto / Typst / Org.
-- Requires: Zotero running locally.

return {
  {
    "Chiarandini/snacks-zotero.nvim",
    dependencies = {
      "folke/snacks.nvim",
      "kkharji/sqlite.lua",
    },
    ft = { "tex", "plaintex", "latex", "markdown", "quarto", "typst", "org", "asciidoc" },
    opts = {
      -- Refuse to append entries that biber/biblatex would reject (raw
      -- non-ASCII like the ' ¿? ' year placeholder, malformed years, etc.).
      validate_bib_entry = true,
    },
    config = function(_, opts)
      require("snacks_zotero").setup(opts)
      vim.keymap.set("n", "<localleader>z",
        "<cmd>SnacksZotero<cr>",
        { buffer = 0, desc = "Zotero citation picker" })
    end,
  },
}
