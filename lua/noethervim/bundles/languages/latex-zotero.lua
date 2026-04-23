-- NoetherVim bundle: LaTeX-Zotero
-- Enable with: { import = "noethervim.bundles.languages.latex-zotero" }
--
-- Zotero citation picker for LaTeX / Markdown / Quarto / Typst / Org.
-- Requires: Zotero running locally.
--
-- Backend: snacks.picker (as of 2026-04 — part of the Telescope deprecation
-- effort described in dev-docs/architecture.md §6.1). The former
-- telescope-zotero spec is retained below but disabled via `enabled = false`
-- so lazy.nvim does not install it (note: `cond = false` would still clone
-- the upstream repo — we want no install footprint).

return {
  -- Active: Snacks-native citation picker.
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

  -- Disabled: legacy Telescope backend. Kept for quick rollback.
  -- To re-enable: flip `enabled = true` (and uncomment the dev override in
  -- user/plugins/personal-zotero.lua if you want your local fork instead).
  {
    "jmbuhr/telescope-zotero.nvim",
    enabled = false,
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
