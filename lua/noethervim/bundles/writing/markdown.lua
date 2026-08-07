---@bundle markdown
---@desc rendering, preview, tables, math and image paste
---@about In-editor rendering and concealment, a live browser preview, smart
---       table editing, inline math, and clipboard image paste.
---@requires exe=node label="Node.js"
---          why="markdown-preview builds its viewer with it, and mdmath renders through it"
---          install="https://nodejs.org/" optional=true
---@requires note="a terminal with the kitty graphics protocol"
---          why="inline math rendering by mdmath"
---          install="kitty, WezTerm, or Ghostty" optional=true
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
    -- Fetch the prebuilt binary rather than build the node app. mkdp runs
    -- app/bin/markdown-preview-<platform> when it exists and only falls back
    -- to `node app/index.js`, which needs app/node_modules. Building those
    -- needs node and yarn on PATH at build time, and node here comes from
    -- mise, so any shell that has not sourced the user's init lacks it; the
    -- build then fails quietly and the plugin dies on a missing tslib. The
    -- binary is self-contained, and install() no-ops once its version matches
    -- package.json, so re-running the build is cheap.
    --
    -- The runtimepath line is what makes that callable. lazy.nvim runs `build`
    -- straight after fetching, with the plugin still off the runtimepath --
    -- it is `ft`-loaded and nothing has triggered it yet -- so Vim cannot
    -- find autoload/mkdp/util.vim and the call dies with E117. lazy adds the
    -- directory again when the plugin really loads; a duplicate entry costs
    -- nothing.
    build = function(plugin)
      vim.opt.runtimepath:append(plugin.dir)
      vim.fn["mkdp#util#install"]()
    end,
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
