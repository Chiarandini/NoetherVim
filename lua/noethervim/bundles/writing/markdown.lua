-- NoetherVim bundle: Markdown
-- Enable with: { import = "noethervim.bundles.writing.markdown" }
--
-- Provides:
--   render-markdown.nvim     in-editor markdown rendering / concealment
--   markdown-preview.nvim    live browser preview (:MarkdownPreview)
--   markdown-table-mode.nvim smart table editing
--   mdmath.nvim              render math in markdown buffers
--   img-clip.nvim            paste images from clipboard (<localleader>P)
--   marksman LSP             markdown link/heading completion (Mason-installed
--                            only when this bundle is enabled)
--
-- img-clip.nvim: if the latex bundle is also enabled, its full img-clip spec
-- (tex + markdown) takes precedence via lazy.nvim merge. If only the markdown
-- bundle is enabled, this minimal declaration ensures img-clip is installed and
-- loads for markdown buffers.

return {

  -- ── marksman LSP (Mason install scoped to this bundle) ────────────────────
  -- Per-server config lives in lua/noethervim/lsp/marksman.lua; that file is
  -- a no-op when the binary isn't installed, so it can stay always-loaded.
  { "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "marksman" })
    end,
  },

  -- ── img-clip.nvim (markdown image paste) ──────────────────────────────────
  -- Minimal declaration so img-clip loads for markdown even without the latex bundle.
  -- lazy.nvim merges this with the latex bundle's full spec if both are enabled.
  {
    "HakonHarnes/img-clip.nvim",
    ft   = { "markdown" },
    keys = {
      { "<localleader>P", "<cmd>PasteImage<cr>",
        desc = "paste image from clipboard",
        ft   = { "markdown" } },
    },
    opts = {
      filetypes = {
        markdown = {
          url_encode_path = true,
          template        = "![$CURSOR]($FILE_PATH)",
          download_images = false,
        },
      },
    },
  },

  -- ── mdmath: render math in markdown buffers ───────────────────────────────
  {
    "Thiago4532/mdmath.nvim",
    ft = "markdown",
    config = function() require("mdmath").setup() end,
  },

  -- ── Markdown tooling ──────────────────────────────────────────────────────
  {
    "iamcco/markdown-preview.nvim",
    cmd   = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft    = { "markdown" },
    build = "cd app && npx --yes yarn install",
  },
  {
    "Kicamon/markdown-table-mode.nvim",
    ft = "markdown",
    config = function() require("markdown-table-mode").setup() end,
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = "markdown",
    config = function() require("render-markdown").setup({}) end,
  },
}
