---@bundle markdown
---@desc rendering, preview, tables, math and image paste
---@about In-editor rendering and concealment, a live browser preview, smart
---       table editing, inline math, and clipboard image paste.
---@requires exe=node label="Node.js"
---          why="markdown-preview builds its viewer with it"
---          install="https://nodejs.org/" optional=true
---@requires note="a terminal with the kitty graphics protocol"
---          why="inline math rendering by Snacks.image"
---          install="kitty, WezTerm, or Ghostty" optional=true
---@requires exe=pdflatex label="pdflatex"
---          why="Snacks.image typesets each equation before displaying it"
---          install="MacTeX or TeX Live; `tectonic` also works" optional=true
---@requires exe=magick label="ImageMagick"
---          why="converts the typeset equation into a displayable image"
---          install="https://imagemagick.org" optional=true
-- NoetherVim bundle: Markdown
-- Enable with: { import = "noethervim.bundles.writing.markdown" }
--
-- Provides:
--   render-markdown.nvim     in-editor markdown rendering / concealment
--   markdown-preview.nvim    live browser preview (:MarkdownPreview)
--   markdown-table-mode.nvim smart table editing
--   Snacks.image             render math and images inline in the buffer
--   img-clip.nvim            paste images from clipboard (<localleader>P)
--   marksman LSP             markdown link/heading completion (Mason-installed
--                            only when this bundle is enabled)
--
-- img-clip.nvim: if the latex bundle is also enabled, its full img-clip spec
-- (tex + markdown) takes precedence via lazy.nvim merge. If only the markdown
-- bundle is enabled, this minimal declaration ensures img-clip is installed and
-- loads for markdown buffers.


-- Inline math rendering, through the Snacks.image this bundle enables.
--
-- `[om` renders math in the current buffer, which is how a tex or typst
-- buffer opts in: the bundle claims markdown and leaves other filetypes to
-- their own devices. `]om` stops math rendering everywhere, for a document
-- where typesetting each equation costs more than reading the source does.
--
-- Off is global because Snacks tracks no per-buffer switch for it, and the
-- flag the discovery pass reads (`math.enabled`) is one value for the
-- session. Clearing the extmarks takes the images off the screen at once;
-- the next pass over each buffer drops the placements behind them.
local function image_math(on)
  local snacks = require("snacks")
  snacks.image.config.math.enabled = on
  if not on then
    local ns = vim.api.nvim_create_namespace("snacks.image")
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) then
        vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
      end
    end
  elseif vim.b.noethervim_image_scoped or not vim.b.snacks_image_attached then
    vim.b.noethervim_image_scoped = nil
    vim.b.snacks_image_attached = nil
    -- A real buffer number, not 0: Snacks names the buffer's augroup after
    -- whatever it is handed, so 0 would build a group nothing else can find.
    require("snacks.image.doc").attach(vim.api.nvim_get_current_buf())
  else
    -- Already attached, so nothing is scheduled to redraw it. WinScrolled is
    -- what the inline renderer listens on that costs nothing to fake.
    vim.api.nvim_exec_autocmds("WinScrolled", { modeline = false })
  end
  require("noethervim.toggles").notify("inline math " .. (on and "enabled" or "disabled"))
end

return {

  -- ── marksman LSP (Mason install scoped to this bundle) ────────────────────
  -- marksman is in core's enable list (plugins/lsp.lua), idle until its
  -- binary is installed. Cross-file completion needs a project root: an
  -- empty .marksman.toml at the repo root, or a git repo.
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
    specs = { { "NoetherVim", optional = true, opts = require("noethervim.keymaps.rows").contribute("img-clip.nvim", {
      { "<localleader>P", "<cmd>PasteImage<cr>",
        desc = "paste image from clipboard",
        ft   = { "markdown" } },
    }) } },
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

  -- ── Snacks.image: inline math and images ──────────────────────────────────
  -- Equations are typeset by pdflatex (or tectonic), converted by ImageMagick
  -- and drawn over the source text with the kitty graphics protocol. Renders
  -- are cached under stdpath("cache"), so only an equation's first render pays
  -- for the LaTeX run. Snacks itself is a core dependency and its `image`
  -- module is off by default, so enabling it belongs with this bundle.
  --
  -- Moving the cursor onto an equation's line reveals the source again, unless
  -- 'concealcursor' covers the current mode.
  --
  -- `image` is not filetype-scoped: enabling it renders math and images in
  -- every language Snacks ships a query for, tex and typst among them. This
  -- bundle's subject is markdown, so it claims markdown and leaves the rest
  -- alone; `[om` opts a single buffer back in.
  --
  -- The gate is `b:snacks_image_attached`, the flag Snacks' own attach checks
  -- before it does anything. Setting it on FileType gets there first, because
  -- Snacks schedules its attach rather than running it inline. The language,
  -- not the filetype, decides: that is what Snacks matches on, so `quarto`
  -- and `rmd` are claimed alongside `markdown` without naming them.
  {
    "folke/snacks.nvim",
    opts = {
      image = { enabled = true },
    },
    specs = { { "NoetherVim", optional = true, opts = require("noethervim.keymaps.rows").contribute("snacks.nvim", {
      { "[om", function() image_math(true) end, desc = "enable inline math" },
      { "]om", function() image_math(false) end, desc = "disable inline math" },
    }) }, { "NoetherVim", optional = true, opts = { startup = {
      ["markdown.image-scope"] = function()
        vim.api.nvim_create_autocmd("FileType", {
          group = vim.api.nvim_create_augroup("noethervim_markdown_image_scope", { clear = true }),
          callback = function(ev)
            local lang = vim.treesitter.language.get_lang(vim.bo[ev.buf].filetype)
            if lang ~= "markdown" then
              vim.b[ev.buf].snacks_image_attached = true
              -- Second marker so `[om` can tell "held back here" from "already
              -- rendering", which the Snacks flag alone reads the same way.
              vim.b[ev.buf].noethervim_image_scoped = true
            end
          end,
        })
      end,
    } } } },
  },

  -- ── treesitter: latex parser ──────────────────────────────────────────────
  -- Math inside markdown is a `latex_block` that injects the latex grammar;
  -- without the parser Snacks.image sees no equations. The latex bundle asks
  -- for the same parser, and lazy merges the two lists.
  -- NEVER define `config` here -- lazy overwrites the core treesitter config
  -- function, breaking ensure_installed / auto_install.
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = { "latex" },
    },
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
    config = function(_, opts) require("markdown-table-mode").setup(opts) end,
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = "markdown",
    -- render-markdown sets 'conceallevel' itself whenever it renders. A
    -- global conceallevel of yours is kept while rendering too.
    opts = function(_, opts)
      if require("noethervim.default").claimed("conceallevel") then
        opts.win_options = vim.tbl_deep_extend("keep", opts.win_options or {},
          { conceallevel = { rendered = vim.o.conceallevel } })
      end
      return opts
    end,
    config = function(_, opts) require("render-markdown").setup(opts) end,
  },
}
