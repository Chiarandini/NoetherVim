---@bundle zotero
---@desc cite from a local Zotero library
---@about A citation picker that reads your local Zotero database directly,
---       for LaTeX, Markdown, Quarto, Typst, Org and AsciiDoc. Zotero must be
---       running. For LaTeX it complements the latex bundle rather than
---       replacing it.
---@requires app=Zotero label="Zotero"
---          why="the citation picker reads its local database"
---          install="https://www.zotero.org/"
---@requires exe=sqlite3 label="sqlite3"
---          why="sqlite.lua opens the Zotero database through it"
---          install="preinstalled on macOS and most Linux distributions"
-- NoetherVim bundle: Zotero
-- Enable with: { import = "noethervim.bundles.writing.zotero" }
--
-- Zotero citation picker for LaTeX / Markdown / Quarto / Typst / Org /
-- AsciiDoc. Requires: Zotero running locally.

return {
  {
    "Chiarandini/snacks-zotero.nvim",
    dependencies = {
      "folke/snacks.nvim",
      "kkharji/sqlite.lua",
    },
    ft = { "tex", "plaintex", "markdown", "quarto", "typst", "org", "asciidoc" },
    specs = { { "NoetherVim", optional = true, opts = require("noethervim.keymaps.rows").contribute("snacks-zotero.nvim", {
      { "<localleader>z", "<cmd>SnacksZotero<cr>", desc = "Zotero citation picker",
        ft = { "tex", "plaintex", "markdown", "quarto", "typst", "org", "asciidoc" } },
    }) } },
    opts = {
      -- Refuse to append entries that biber/biblatex would reject (raw
      -- non-ASCII like the ' ¿? ' year placeholder, malformed years, etc.).
      validate_bib_entry = true,
    },
    config = function(_, opts)
      require("snacks_zotero").setup(opts)
    end,
  },
}
