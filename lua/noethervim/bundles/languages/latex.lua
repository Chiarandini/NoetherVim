-- NoetherVim bundle: LaTeX
-- Enable with: { import = "noethervim.bundles.languages.latex" }
--
-- Provides:
--   • vimtex:                    LaTeX compilation, PDF viewing, inverse search
--   • texlab:                    LaTeX LSP (Mason-installed only when this bundle is enabled)
--   • img-clip.nvim:             drag-and-drop / clipboard image paste (<localleader>P)
--   • snacks-bibtex:             BibTeX citation picker (<c-s-c> in insert mode)
--   • noethervim-tex:            LuaSnip snippets, blink.cmp sources, textobject keymaps
--   • snacks-latex-labels:       label/heading jump (<localleader>w, <localleader>vul/vuh)
--   yP keymap:                  copy compiled PDF to clipboard
--   [P / ]P:                   toggle PDF size in statusline
--   theorem highlighting:       treesitter-based theorem label coloring
--   For Zotero citations, enable the separate latex-zotero bundle.
--
-- PDF viewer: NOT set by the distro -- set vim.g.vimtex_view_method in lua/user/options.lua:
--   vim.g.vimtex_view_method = 'skim'   -- or 'zathura', 'sioyek', etc.


-- ── LaTeX filetype helpers (used by the FileType autocmd below) ────────────
-- These only run when the latex bundle is enabled AND a tex file is opened.
-- Basic buffer-local options (textwidth, synmaxcol) stay in ftplugin/tex.lua.
-- Folding is handled by nvim-ufo + texlab (zc to close, zR/zM to toggle all).

local function tex_shift_enter()
  local row, col  = unpack(vim.api.nvim_win_get_cursor(0))
  local line       = vim.api.nvim_get_current_line()
  local ws         = string.match(line, "^%s*") or ""

  local envs = {
    { names = { "cases", "gather*", "matrix", "pmatrix" }, pre = "\\\\", text = "" },
    { names = { "align", "align*" },                       pre = "\\\\", text = "&= " },
    {
      names = { "itemize", "enumerate" },
      text  = "\\item ",
      adjust_ws = function(l, w)
        return l:match("\\item") and (w:sub(1) or "") or w
      end,
    },
  }

  for _, env in ipairs(envs) do
    for _, name in ipairs(env.names) do
      local inside = vim.fn["vimtex#env#is_inside"](name)
      if inside[1] > 0 and inside[2] > 0 then
        local pre     = env.pre or ""
        local text    = env.text or ""
        local cur_ws  = env.adjust_ws and env.adjust_ws(line, ws) or ws
        local new_line = cur_ws .. text
        vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, { pre, new_line })
        vim.api.nvim_win_set_cursor(0, { row + 1, #new_line + 1 })
        return
      end
    end
  end
end

local SearchLeader = require("noethervim.util").search_leader

return {

  -- ── texlab LSP (Mason install scoped to this bundle) ──────────────────────
  -- Per-server config lives in lua/noethervim/lsp/texlab.lua; that file is a
  -- no-op when the binary isn't installed, so it can stay always-loaded.
  { "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "texlab" })
    end,
  },

  -- ── treesitter: latex parser + theorem highlighting ───────────────────────
  -- Uses opts (merged by lazy) and init (runs before load, just registers
  -- an autocmd).  NEVER define `config` here -- lazy overwrites the core
  -- treesitter config function, breaking ensure_installed / auto_install.
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = { "latex" },
    },
    init = function()
      local ns = vim.api.nvim_create_namespace("noethervim_latex_highlights")

      local function highlight_theorem_tags(bufnr)
        local parser = vim.treesitter.get_parser(bufnr, "latex")
        if not parser then return end
        vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
        local tree = parser:parse()[1]
        if not tree then return end
        local query = vim.treesitter.query.get("latex", "highlights")
        if not query then return end
        for id, node in query:iter_captures(tree:root(), bufnr) do
          if query.captures[id] == "texTheoremTag" then
            local r1, c1, r2, c2 = node:range()
            vim.api.nvim_buf_set_extmark(bufnr, ns, r1, c1, {
              end_row  = r2,
              end_col  = c2,
              hl_group = "texRefArg",
              spell    = false,
            })
          end
        end
      end

      vim.api.nvim_create_autocmd({ "BufRead", "BufWritePost" }, {
        group    = vim.api.nvim_create_augroup("noethervim_latex_hl", { clear = true }),
        pattern  = "*.tex",
        callback = function(args) highlight_theorem_tags(args.buf) end,
      })
    end,
  },

  -- ── vimtex ────────────────────────────────────────────────────────────────
  -- lazy = false: required for inverse search -- vimtex must be loaded at startup
  -- so that headless nvim can respond to InverseSearch from the PDF viewer.
  {
    "lervag/vimtex",
    lazy = false,
    -- LaTeX globals -- must be set before vimtex loads.
    init = function()
      vim.g.tex_conceal = "abdgm"
      vim.g.tex_flavor  = "latex"
    end,
    config = function()
      -- ':' is part of LaTeX label names (th:foo, pr:bar, …).
      -- Adding it to iskeyword lets blink.cmp treat "th:foo" as one keyword,
      -- so the completion menu stays open after typing ':'.
      vim.api.nvim_create_autocmd("FileType", {
        pattern  = { "tex", "latex" },
        callback = function() vim.opt_local.iskeyword:append(":") end,
      })

      vim.cmd([=[
let g:vimtex_fold_enabled = 0
let g:vimtex_format_enabled = 1
let g:tex_indent_brace = 0
let g:vimtex_quickfix_open_on_warning = 0
let g:tex_conceal_frac = 1
let g:vimtex_quickfix_ignore_filters = [
\ 'Underfull \\hbox',
\ 'Overfull \\hbox',
\ 'LaTeX Warning: .\+ float specifier changed to',
\ 'LaTeX hooks Warning',
\ 'Package siunitx Warning: Detected the "physics" package:',
\ 'Package hyperref Warning: Token not allowed in a PDF string',
\]
let g:vimtex_compiler_latexmk = {
    \ 'aux_dir' : '',
    \ 'out_dir' : '',
    \ 'callback' : 1,
    \ 'continuous' : 0,
    \ 'executable' : 'latexmk',
    \ 'hooks' : [],
    \ 'options' : [
    \   '-verbose',
    \   '-file-line-error',
    \   '-synctex=1',
    \   '-interaction=nonstopmode',
    \ ],
    \}
let g:vimtex_compiler_latexmk_engines = {
    \ '_'                : '-lualatex',
    \}
]=])
      vim.api.nvim_create_autocmd("BufWritePost", {
        pattern  = "*.tex",
        callback = function()
          local vimtex = vim.b.vimtex
          if vimtex and vimtex.compiler then
            local status = vimtex.compiler.status
            if status == 2 or status == 3 then
              vim.cmd("VimtexCompile")
            end
          end
        end,
        desc = "Auto-compile on save ONLY if VimTeX compiler was started",
      })

      -- yP: copy compiled PDF to clipboard
      vim.keymap.set("n", "yP", function()
        require("noethervim.util.copy_pdf").copy_pdf_to_clipboard()
        vim.notify("yanked pdf")
      end, { desc = "yank PDF to clipboard" })

      -- PDF-size indicator in statusline
      vim.keymap.set("n", "[P", '<cmd>let g:TogglePdfSizeInStatusline=1<cr><cmd>lua vim.cmd("echom \\"pdf size in statusline\\"")<cr>', { desc = "pdf size in statusline" })
      vim.keymap.set("n", "]P", '<cmd>let g:TogglePdfSizeInStatusline=0<cr><cmd>lua vim.cmd("echom \\"no pdf size in statusline\\"")<cr>', { desc = "no pdf size in statusline" })

      -- Buffer-local keymaps for tex files (only active when latex bundle is enabled)
      vim.api.nvim_create_autocmd("FileType", {
        group    = vim.api.nvim_create_augroup("noethervim_latex_ftkeys", { clear = true }),
        pattern  = { "tex", "latex" },
        callback = function(ev)
          local o = function(desc) return { silent = true, buffer = ev.buf, desc = desc } end

          -- :PDF -- open compiled PDF
          vim.api.nvim_buf_create_user_command(ev.buf, "PDF", function()
            local pdf = vim.fn.expand("%:t:r") .. ".pdf"
            if vim.fn.has("macunix") == 1 then
              vim.fn.jobstart({ "open", pdf }, { detach = true })
            elseif vim.fn.has("win32") == 1 then
              vim.fn.jobstart({ "cmd.exe", "/c", "start", "", pdf }, { detach = true })
            else
              vim.fn.jobstart({ "xdg-open", pdf }, { detach = true })
            end
          end, { desc = "open compiled PDF" })

          vim.keymap.set("n", "<localleader>vw", "<Cmd>VimtexCountWords<CR>", o("vimtex word count"))
          vim.keymap.set("i", "<s-cr>", tex_shift_enter, o("smart newline"))

          -- Accent spell-check (noethervim-tex).  zG / zW / z= mirror
          -- vim's built-in zg / zw / z= but operate on the LaTeX-encoded
          -- token under the cursor: decode to Unicode, then add to
          -- spellfile, mark wrong, or open suggestions accordingly.
          local plug_opts = function(desc)
            return { silent = true, buffer = ev.buf, desc = desc, remap = true }
          end
          vim.keymap.set("n", "zG", "<Plug>(noethervim-tex-accent-add)",
            plug_opts("spell: add accented word"))
          vim.keymap.set("n", "zW", "<Plug>(noethervim-tex-accent-mark-wrong)",
            plug_opts("spell: mark accented word wrong"))
          vim.keymap.set("n", "z=", "<Plug>(noethervim-tex-accent-suggest)",
            plug_opts("spell: suggest accented form"))
        end,
      })
    end,
  },


  -- ── img-clip.nvim ─────────────────────────────────────────────────────────
  -- Drag-and-drop or clipboard image paste into LaTeX and Markdown.
  -- The markdown bundle also declares this plugin for ft=markdown -- lazy merges both.
  {
    "HakonHarnes/img-clip.nvim",
    ft   = { "tex", "markdown" },
    keys = {
      { "<localleader>P", "<cmd>PasteImage<cr>",
        desc = "paste image from clipboard",
        ft   = { "tex", "markdown" } },
    },
    opts = {
      default = {
        dir_path               = "images",
        extension              = "png",
        file_name              = "%Y-%m-%d-%H-%M-%S",
        use_absolute_path      = false,
        relative_to_current_file = false,
        template               = "$FILE_PATH",
        url_encode_path        = false,
        relative_template_path = true,
        use_cursor_in_template = true,
        insert_mode_after_paste = true,
        prompt_for_file_name   = true,
        show_dir_path_in_prompt = false,
        max_base64_size        = 10,
        embed_image_as_base64  = false,
        process_cmd            = "",
        copy_images            = false,
        download_images        = true,
        drag_and_drop          = { enabled = true, insert_mode = false },
      },
      filetypes = {
        markdown = {
          url_encode_path = true,
          template        = "![$CURSOR]($FILE_PATH)",
          download_images = false,
        },
        html = {
          template = '<img src="$FILE_PATH" alt="$CURSOR">',
        },
        tex = {
          relative_template_path = true,
          template = [[
\begin{figure}[H]
  \centering
  \includegraphics[width=0.8\textwidth]{$FILE_PATH}
  \caption{$CURSOR}
  \label{fig:$LABEL}
\end{figure}
          ]],
        },
      },
    },
  },

  -- ── snacks-bibtex ─────────────────────────────────────────────────────────
  -- BibTeX citation picker on snacks.picker. Replaces telescope-bibtex
  -- (see dev-docs/telescope-removal-plan.md §4 phase 3.2). Same <c-s-c>
  -- keymap; context-aware .bib discovery scans the current buffer's
  -- bibliography directives before falling back to the cwd.
  {
    "Chiarandini/snacks-bibtex.nvim",
    dependencies = { "folke/snacks.nvim" },
    ft   = { "tex", "plaintex", "latex", "markdown", "quarto", "typst", "org", "rmd" },
    keys = {
      { "<c-s-c>", "<cmd>SnacksBibtex<cr>",
        mode = "i", desc = "citation from bibtex" },
    },
    opts = {
      search_keys       = { "author", "year", "title" },
      citation_format   = "{{author}} ({{year}}), {{title}}.",
      context           = true,
      context_fallback  = true,
    },
    config = function(_, opts)
      require("snacks_bibtex").setup(opts)
    end,
  },

  -- telescope-media-files: dropped 2026-04-23 (see
  -- dev-docs/telescope-removal-plan.md §3.2). Snacks.picker has first-class
  -- image preview; the media-files extension's niche (PDF preview via
  -- ueberzug) is not widely used by the target audience and the plugin's
  -- Linux-only dependency chain makes it awkward on macOS. Reinstate via
  -- user/plugins/ if needed.

  -- ── noethervim-tex ────────────────────────────────────────────────────────
  -- Spell-file shipping (en.utf-8.add math vocab + accents.utf-8.add for
  -- LaTeX-accented proper nouns) is handled inside noethervim-tex's own
  -- plugin/noethervim_tex.lua at plugin load -- this bundle no longer
  -- needs to mkspell or append to spellfile.  The accent spell-check
  -- diagnostics layer also lives there; configure via opts.accent_spell.
  {
    "Chiarandini/NoetherVim-Tex",
    event = "VeryLazy",
    dependencies = { "L3MON4D3/LuaSnip" },
    opts = {
      -- preamble_folder     = vim.fn.stdpath("config") .. "/preamble/",
      -- extra_snippet_paths = {},
      -- textobjects         = true,
      -- accent_spell        = { enabled = true, severity = vim.diagnostic.severity.INFO },
    },
    config = function(self, opts)
      require("noethervim-tex").setup(opts)

      -- Transitional fallback: older noethervim-tex versions don't
      -- ship plugin/noethervim_tex.lua, so vim.g.loaded_noethervim_tex
      -- is unset and we register the math vocab spellfile here.  The
      -- new plugin/ file sets the flag and handles both .add files
      -- itself, in which case this branch is skipped.  Remove this
      -- block once the upstream noethervim-tex pin is bumped.
      if vim.g.loaded_noethervim_tex ~= 1 then
        local spell_add = self.dir .. "/spell/en.utf-8.add"
        if vim.uv.fs_stat(spell_add) then
          local spl = spell_add .. ".spl"
          if not vim.uv.fs_stat(spl) then
            pcall(vim.cmd, "silent mkspell! " .. vim.fn.fnameescape(spell_add))
          end
          vim.opt.spellfile:append(spell_add)
        end
      end
    end,
  },

  -- Register the preambles blink.cmp source (provided by noethervim-tex).
  {
    "saghen/blink.cmp",
    opts = {
      sources = {
        per_filetype = {
          tex = { "lsp", "snippets", "vimtex", "images", "preambles" },
        },
        providers = {
          preambles = {
            name   = "preambles",
            module = "noethervim-tex.sources.preambles",
          },
        },
      },
    },
  },

  -- ── Oil: open .tex file in current dir (gt) ─────────────────────────────
  -- LaTeX-specific Oil keymap -- opens the .tex file in the current Oil
  -- directory, or shows a picker if there are multiple.
  {
    "stevearc/oil.nvim",
    opts = {
      keymaps = {
        ["gt"] = {
          desc = "open .tex file in current dir",
          callback = function()
            local dir = require("oil").get_current_dir()
            if not dir then return end
            local files = vim.fn.glob(dir .. "*.tex", false, true)
            if #files == 0 then
              vim.notify("No .tex files in " .. dir, vim.log.levels.WARN)
              return
            end
            local is_float = vim.api.nvim_win_get_config(0).relative ~= ""
            local function open_file(path)
              if is_float then
                require("oil").close()
                vim.schedule(function() vim.cmd("edit " .. vim.fn.fnameescape(path)) end)
              else
                vim.cmd("edit " .. vim.fn.fnameescape(path))
              end
            end
            if #files == 1 then
              open_file(files[1])
            else
              vim.ui.select(files, {
                prompt = "Select .tex file:",
                format_item = function(f) return vim.fn.fnamemodify(f, ":t") end,
              }, function(choice)
                if choice then open_file(choice) end
              end)
            end
          end,
        },
      },
    },
  },

  -- ── snacks-latex-labels ───────────────────────────────────────────────────
  -- All business logic (label cache, project scanner, latex helpers) lives
  -- in latex-nav-core -- telescope-latex-references is no longer a dependency.
  -- The plugin owns its own user commands (`:SnacksLatexLabels`,
  -- `:SnacksLatexLabelsExport`, `:LatexLabels {update|inspect|wipe}`); see the
  -- upstream readme for the full surface.
  {
    "Chiarandini/snacks-latex-labels.nvim",
    dependencies = {
      "folke/snacks.nvim",
      "Chiarandini/latex-nav-core.nvim",
    },
    ft   = { "tex", "latex" },
    cmd  = { "LatexLabels", "SnacksLatexLabels", "SnacksLatexLabelsExport" },
    opts = {
      cache_strategy    = "global",
      recursive         = true,
      auto_update       = true,
      notify_on_update  = true,
      enable_smart_jump = true,
      smart_jump_window = 200,
      root_file         = "",
      subfile_toggle_key = "<C-g>",
      transformations = {
        thm = "th:", prop = "pr:", defn = "df:", lem = "lm:",
        cor = "co:", example = "ex:", exercise = "x:", titledBox = "box:",
      },
      copy_transform = {
        ["df:"] = "\\cref{%s}", ["lm:"] = "\\cref{%s}",
        ["th:"] = "\\cref{%s}", ["co:"] = "\\cref{%s}",
        ["pr:"] = "\\cref{%s}", ["box:"] = "\\cref{%s}",
        ["ex:"] = "example~\\ref{%s}", ["eq:"] = "equation~\\eqref{%s}",
      },
      patterns = {
        { pattern = "\\begin{(%w+)}{(.-)}{(.-)}", type = "environment" },
        { pattern = "\\label{(.-)}", type = "standard" },
      },
    },
    config = function(_, opts)
      require("snacks_latex_labels").setup(opts)

      vim.keymap.set("n", "<localleader>w",   "<cmd>SnacksLatexLabels<cr>",     { buf = 0, desc = "latex labels" })
      vim.keymap.set("n", "<localleader>vul", "<cmd>LatexLabels update<cr>",    { buf = 0, desc = "update latex labels" })
      vim.keymap.set("n", "<localleader>vuh", "<cmd>CachedHeadings update<cr>", { buf = 0, desc = "update headings cache" })

      -- ── gd: goto label definition ────────────────────────────────────────
      -- Extracts the label under the cursor (e.g. "th:bezoutIdentity" from
      -- \cref{th:bezoutIdentity}), looks it up in the latex_labels cache, and
      -- jumps to the defining line.  Falls back to vim.lsp.buf.definition()
      -- when the cursor is not on a prefixed label.
      -- Cache strategy is hardcoded to "global" (the telescope-latex-references
      -- default); update if you override cache_strategy in telescope setup.
      local function label_at_cursor()
        local line = vim.api.nvim_get_current_line()
        local col  = vim.api.nvim_win_get_cursor(0)[2] + 1  -- 1-indexed
        -- Walk every "prefix:name" token in the line; return the one under cursor.
        local pos = 1
        while true do
          local s, e, label = line:find("(%a+:%a[%a%d%-_%.]*)", pos)
          if not s then break end
          if col >= s and col <= e then return label end
          pos = e + 1
        end
        return nil
      end

      -- Jump to a found entry: open its file if needed, go to line, center.
      local function jump_to_entry(e, utils)
        local target = utils.verify_or_find_label(e.filename, e.line, e.id, 200) or e.line
        local cur    = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p")
        if cur ~= e.filename then
          vim.cmd("edit " .. vim.fn.fnameescape(e.filename))
        end
        vim.api.nvim_win_set_cursor(0, { target, 0 })
        vim.cmd("normal! zz")
      end

      local function setup_gd(bufnr)
        vim.keymap.set("n", "gd", function()
          local label = label_at_cursor()
          if not label then vim.lsp.buf.definition(); return end

          local cache = require("latex_nav_core.latex_labels.cache")
          local utils = require("latex_nav_core.latex")

          -- 1. Search the current project's cache first.
          local root = utils.get_root_file()
          if root then
            local entries = cache.read_cache(cache.get_cache_path(root, "global"))
            if entries then
              for _, e in ipairs(entries) do
                if e.id == label then jump_to_entry(e, utils); return end
              end
            end
          end

          -- 2. Label not in current project -- search all other cached files.
          --    Covers cross-file references once those files have been indexed.
          local cache_dir = vim.fn.stdpath("data") .. "/cached_labels"
          local all_files = vim.fn.glob(cache_dir .. "/*.labels", false, true)
          local current_cache = root and cache.get_cache_path(root, "global") or ""
          for _, path in ipairs(all_files) do
            if path ~= current_cache then
              local entries = cache.read_cache(path)
              if entries then
                for _, e in ipairs(entries) do
                  if e.id == label then jump_to_entry(e, utils); return end
                end
              end
            end
          end

          -- 3. Nowhere to jump -- label not yet written or indexed.
          vim.notify("[gd] '" .. label .. "' not found in any cache -- run :LatexLabels update", vim.log.levels.WARN)
        end, { buffer = bufnr, desc = "goto label definition (LaTeX)" })
      end

      -- Wire gd for buffers opened after this plugin loads.
      vim.api.nvim_create_autocmd("FileType", {
        pattern  = { "tex", "latex" },
        callback = function(args) setup_gd(args.buf) end,
      })
      -- The FileType event already fired for the buffer that triggered this
      -- plugin load, so wire it up for the current buffer immediately too.
      local ft = vim.bo.filetype
      if ft == "tex" or ft == "latex" then
        setup_gd(vim.api.nvim_get_current_buf())
      end
      -- Re-register after texlab attaches: the LspAttach handler in lsp.lua fires
      -- after FileType and overwrites gd with vim.lsp.buf.definition.
      -- Since this autocmd is registered later it runs second and wins.
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if client and client.name == "texlab" then
            setup_gd(args.buf)
          end
        end,
      })
    end,
  },

}
