-- NoetherVim bundle: LaTeX-Zotero
-- Enable with: { import = "noethervim.bundles.languages.latex-zotero" }
--
-- Zotero citation picker for LaTeX / Markdown / Quarto / Typst / Org.
-- Requires: Zotero running locally.
--
-- Backend: snacks.picker. The legacy telescope-zotero spec was retained here
-- as an `enabled = false` rollback path through 2026-04; removed once the
-- snacks backend proved stable (see dev-docs/telescope-removal-plan.md §5).

return {
  {
    "Chiarandini/snacks-zotero.nvim",
    dependencies = {
      "folke/snacks.nvim",
      "kkharji/sqlite.lua",
    },
    ft = { "tex", "plaintex", "latex", "markdown", "quarto", "typst", "org", "asciidoc" },
    opts = {},
    config = function(_, opts)
      require("snacks_zotero").setup(opts)
      vim.keymap.set("n", "<localleader>z",
        "<cmd>SnacksZotero<cr>",
        { buffer = 0, desc = "Zotero citation picker" })
    end,
  },
}
