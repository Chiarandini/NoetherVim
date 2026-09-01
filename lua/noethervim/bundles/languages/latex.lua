---@bundle latex
---@desc LaTeX compilation, PDF viewing and math editing
---@about VimTeX for compilation, PDF viewing and inverse search, with texlab
---       as the language server. On top of that: snippets, textobjects and a
---       math spell dictionary from noethervim-tex, label and heading
---       pickers, BibTeX citations, and clipboard image paste. Set
---       vim.g.vimtex_view_method to choose a PDF viewer.
---@requires exe=latexmk label="latexmk"
---          why="compiling documents through VimTeX"
---          install="ships with TeX Live and MacTeX"
---@requires exe=pdflatex label="pdflatex"
---          why="the engine latexmk drives by default"
---          install="ships with TeX Live and MacTeX" optional=true
---@requires exe=pngpaste label="pngpaste"
---          why="pasting images from the clipboard on macOS"
---          install="brew install pngpaste" optional=true
-- NoetherVim bundle: LaTeX
-- Enable with: { import = "noethervim.bundles.languages.latex" }
--
-- Provides:
--   • vimtex:                    LaTeX compilation, PDF viewing, inverse search
--   • texlab:                    LaTeX LSP (Mason-installed only when this bundle is enabled)
--   • img-clip.nvim:             drag-and-drop / clipboard image paste (<localleader>P)
--   • snacks-bibtex:             BibTeX citation picker (<c-s-c> in insert mode)
--   • noethervim-tex:            LuaSnip snippets, blink.cmp sources, structure
--                                motions, theorem-tag colouring,
--                                PDF-follows-cursor (<LocalLeader>lf)
--   • snacks-latex-labels:       label/heading jump (<localleader>w, <localleader>vul/vuh)
--   • smart-enter.nvim:          <S-CR> continues environments (\\ rows, &= in align, \item)
--   the PDF as a file:          yP copies it, Oil's gP opens one from a
--                               directory, :PDF opens this document's in the
--                               system viewer. <LocalLeader>lv is the other
--                               half, the live view, and it is what syncs.
--   <c-w>sp:                    toggle PDF size in statusline
--   gd / <C-]>:                 jump to the label under the cursor (\cref, \ref,
--                               \eqref, ...) via the label cache; <C-]> pushes the
--                               tag stack so <C-t> returns. Works across subfiles
--                               and nested sub-books.
--   label completion docs:      hovering a label completion shows its
--                               part/chapter/section and LaTeX source.
--   subfile compilation:        subfile projects compile the current subfile by
--                               default; :VimtexToggleMain switches to the full
--                               project (g:vimtex_subfile_start_local = 1).
--   For Zotero citations, enable the separate writing/zotero bundle.
--
-- PDF viewer: NOT set by the distro -- set vim.g.vimtex_view_method in lua/user/options.lua:
--   vim.g.vimtex_view_method = 'skim'   -- or 'zathura', 'sioyek', etc.


local SearchLeader = require("noethervim.util").search_leader

return {

  -- ── smart-enter.nvim: LaTeX environment continuation ──────────────────────
  -- The plugin and its global <S-CR> come from core (plugins/editing.lua).
  -- This only adds the tex/latex rules, merged into core's opts by lazy:
  -- "\\" in math rows, "\\" then "&= " in align, "\item " in lists.
  {
    "Chiarandini/smart-enter.nvim",
    opts = {
      filetypes = {
        tex   = { preset = "latex" },
        latex = { preset = "latex" },
      },
    },
  },

  -- ── texlab LSP (Mason install scoped to this bundle) ──────────────────────
  -- Per-server config lives in lua/noethervim/lsp/texlab.lua; that file is a
  -- no-op when the binary isn't installed, so it can stay always-loaded.
  { "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "texlab" })
    end,
  },

  -- ── bibclean (Mason install scoped to this bundle) ────────────────────────
  -- Core claims `bib` in `formatters_by_ft` and leaves the binary to whoever
  -- owns the subject, which is this bundle: a `.bib` file is not something a
  -- user without LaTeX opens, so core fetching its formatter on every install
  -- was a cost nobody else could spend.
  --
  -- `opts`, never `config` -- lazy keeps only the last config function, so
  -- defining one here would replace core's and take its formatter list with
  -- it. Same reason the treesitter block below says so.
  { "stevearc/conform.nvim",
    opts = function(_, opts)
      -- latexindent ships with TeX Live, which this bundle already requires,
      -- so the filetype is claimed without adding a Mason install. bibclean is
      -- the exception: core claims `bib` and leaves the binary to whoever
      -- actually opens a .bib file.
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters_by_ft.tex = { "latexindent" }
      opts.mason_install = opts.mason_install or {}
      vim.list_extend(opts.mason_install, { "bibclean" })
    end,
  },

  -- ── treesitter: latex parser ──────────────────────────────────────────────
  -- `opts` only, merged by lazy. NEVER define `config` here -- lazy overwrites
  -- the core treesitter config function, breaking ensure_installed /
  -- auto_install.
  --
  -- Theorem-tag colouring used to live here and now belongs to noethervim-tex
  -- (`theorem_highlight`), which already owns the latex queries and can offer
  -- it to readers who use the plugin without this distribution.
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = { "latex" },
    },
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
      -- ':' is part of LaTeX label names (th:foo, pr:bar, …), so word motions
      -- should step over one whole label: `w`, `e`, `b`, `iw` and `*` all
      -- treat "th:foo" as a single word here.
      --
      -- This is not what keeps the completion menu open after ':'. blink
      -- swaps 'iskeyword' for a hardcoded charset while it decides what
      -- counts as a keyword, so a buffer's setting cannot reach it; the
      -- vimtex provider advertises ':' as a trigger character instead, in
      -- plugins/cmp.lua.
      vim.api.nvim_create_autocmd("FileType", {
        pattern  = { "tex", "latex" },
        callback = function() vim.opt_local.iskeyword:append(":") end,
      })

      -- VimTeX settings. Lua rather than a vimscript blob, and only the
      -- values that differ from VimTeX's own defaults -- the block this
      -- replaces restated several of them, which reads as a decision and is
      -- not one.
      --
      -- Deleted as no-ops, each checked against vimtex/autoload/options.vim:
      --   vimtex_fold_enabled = 0      already VimTeX's default
      --   tex_conceal_frac = 1         no such option exists, in VimTeX or Vim
      --   the latexmk aux_dir/out_dir/callback/executable/hooks/options keys,
      --                                all identical to VimTeX's defaults
      vim.g.vimtex_format_enabled = 1          -- VimTeX default 0; gq reflows prose
      vim.g.tex_indent_brace = 0               -- built-in tex indent, not VimTeX

      -- Warnings do not steal focus by opening the quickfix window; they are
      -- still listed, and `<LocalLeader>le` opens the list on demand.
      vim.g.vimtex_quickfix_open_on_warning = 0

      -- Filters for messages that are noise in every document -- a package
      -- announcing a known-harmless interaction, or a hook warning you cannot
      -- act on.
      --
      -- `Underfull \\hbox` and `Overfull \\hbox` were in this list and have
      -- been removed. They are not noise: they are the compiler reporting a
      -- line it could not set within the margins, which is a real typesetting
      -- defect and one of the few things LaTeX will tell you about your
      -- output rather than your source. Filtering them meant a document could
      -- be visibly wrong with a clean quickfix list.
      vim.g.vimtex_quickfix_ignore_filters = {
        [[LaTeX Warning: .\+ float specifier changed to]],
        [[LaTeX hooks Warning]],
        [[Package siunitx Warning: Detected the "physics" package:]],
        [[Package hyperref Warning: Token not allowed in a PDF string]],
      }

      -- Two deliberate departures from VimTeX, both worth knowing about:
      --
      -- `continuous = 0` compiles once per `<LocalLeader>ll` instead of
      -- leaving a latexmk process watching the file. VimTeX's default is 1.
      -- One-shot keeps a large project from rebuilding on every keystroke-
      -- triggered write, at the cost of having to ask for each build.
      --
      -- `_ = -lualatex` compiles everything with LuaLaTeX rather than letting
      -- VimTeX pick from the document. LuaLaTeX handles fontspec and unicode
      -- maths that pdflatex cannot, and is slower for documents that need
      -- neither.
      --
      -- Override either in `user/plugins/`; they are ordinary `vim.g` values.
      vim.g.vimtex_compiler_latexmk = { continuous = 0 }
      vim.g.vimtex_compiler_latexmk_engines = { ["_"] = "-lualatex" }
      -- Subfile projects (subfiles.cls) start in local mode: compiling from
      -- a chapter builds that chapter's standalone PDF, not the whole book.
      -- :VimtexToggleMain switches the buffer to the full project (and back).
      vim.g.vimtex_subfile_start_local = 1
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

      -- ── VimTeX compile lifecycle hooks (deferred until a tex file opens) ──
      -- vimtex itself loads at startup (lazy = false) for inverse-search
      -- support, but the lifecycle plumbing here (vimtex_status, the yP
      -- keymap, the User VimtexEvent* listeners) only matters once you
      -- actually open a .tex file. Deferring saves ~12ms off `nvim .`
      -- startup because vimtex_status is a heavy module.
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "tex", "latex" },
        once    = true,
        callback = function()
          -- yP: copy compiled PDF to clipboard
          vim.keymap.set("n", "yP", function()
            require("noethervim.util.copy_pdf").copy_pdf_to_clipboard()
            vim.notify("yanked pdf")
          end, { desc = "yank PDF to clipboard" })

          -- The heirline statusline listens for `b:vimtex.compiler.status`
          -- transitions, but vimtex doesn't emit BufEnter-style events on
          -- transition. Forwarding its User events into a redrawstatus +
          -- baseline cache update keeps the statusline crisp and lets the
          -- next compile show a rough completion percentage.
          local vstatus  = require("noethervim.util.vimtex_status")
          local vt_group = vim.api.nvim_create_augroup("noethervim_vimtex_status", { clear = true })

          ---@type table<string, integer>  state.tex -> compile start (ms)
          local compile_start = {}

          local function current_state_pair()
            local pick = vstatus.pick(0)
            return pick and pick.state or nil
          end

          vim.api.nvim_create_autocmd("User", {
            group   = vt_group,
            pattern = "VimtexEventCompileStarted",
            callback = function()
              local state = current_state_pair()
              if state and type(state.tex) == "string" then
                compile_start[state.tex] = (vim.uv or vim.loop).now()
              end
              vstatus.invalidate()
              -- bang = refresh every window's statusline, not just the
              -- current one. vimtex emits these in the parent's buffer
              -- context; the user is often focused elsewhere (subfile
              -- buffer, PDF viewer split) when a compile lands.
              pcall(vim.cmd.redrawstatus, { bang = true })
            end,
          })

          vim.api.nvim_create_autocmd("User", {
            group   = vt_group,
            pattern = { "VimtexEventCompiling", "VimtexEventCompileStopped", "VimtexEventCompileFailed" },
            callback = function()
              vstatus.invalidate()
              -- bang = refresh every window's statusline, not just the
              -- current one. vimtex emits these in the parent's buffer
              -- context; the user is often focused elsewhere (subfile
              -- buffer, PDF viewer split) when a compile lands.
              pcall(vim.cmd.redrawstatus, { bang = true })
            end,
          })

          vim.api.nvim_create_autocmd("User", {
            group   = vt_group,
            pattern = "VimtexEventCompileSuccess",
            callback = function()
              local state = current_state_pair()
              if state and type(state.tex) == "string" then
                local started = compile_start[state.tex]
                local elapsed = started and ((vim.uv or vim.loop).now() - started) or 0
                compile_start[state.tex] = nil
                vstatus.record_success(state, elapsed)

                -- Push the compile time through fidget if it's available
                -- (loaded on LspAttach -- texlab covers tex buffers). Fall
                -- back to vim.notify so the duration still surfaces when
                -- fidget hasn't loaded yet.
                local secs = string.format("%.1fs", elapsed / 1000)
                local name = vim.fn.fnamemodify(state.tex, ":t")
                local msg  = string.format("vimtex: %s compiled in %s", name, secs)
                -- group = "vimtex" makes fidget label the bubble "vimtex"
                -- instead of the default unnamed-group title "Notification".
                local ok, fidget = pcall(require, "fidget")
                if ok and type(fidget.notify) == "function" then
                  fidget.notify(msg, vim.log.levels.INFO, { group = "vimtex" })
                else
                  vim.notify(msg, vim.log.levels.INFO)
                end
              end
              vstatus.invalidate()
              -- bang = refresh every window's statusline, not just the
              -- current one. vimtex emits these in the parent's buffer
              -- context; the user is often focused elsewhere (subfile
              -- buffer, PDF viewer split) when a compile lands.
              pcall(vim.cmd.redrawstatus, { bang = true })
            end,
          })

          vim.api.nvim_create_autocmd("User", {
            group   = vt_group,
            pattern = "VimtexEventInitPost",
            callback = function() vstatus.invalidate() end,
          })

          -- Manually fire VimtexEventInitPost-equivalent: the current
          -- buffer just opened, so refresh the statusline once. Bang
          -- to match the event handlers above.
          vstatus.invalidate()
          pcall(vim.cmd.redrawstatus, { bang = true })
        end,
      })

      -- Buffer-local keymaps for tex files (only active when latex bundle is enabled)
      vim.api.nvim_create_autocmd("FileType", {
        group    = vim.api.nvim_create_augroup("noethervim_latex_ftkeys", { clear = true }),
        pattern  = { "tex", "latex" },
        callback = function(ev)
          local o = function(desc) return { silent = true, buffer = ev.buf, desc = desc } end

          -- :PDF -- hand the compiled PDF to the system viewer.
          --
          -- There are two families here and this is the artifact one: `yP`
          -- copies the PDF, Oil's `gP` opens one from a directory, and this
          -- opens the current document's. They treat the PDF as a file and
          -- need no viewer configured. VimTeX's `<LocalLeader>lv` is the
          -- other family, the live view, and it is the one that syncs to the
          -- cursor.
          --
          -- The path comes from vimtex, which knows the main file and the
          -- out_dir. The basename this used to build (`%:t:r`) resolved
          -- against the cwd, so it missed whenever the cwd was not the
          -- document's directory, whenever out_dir was set, and for an
          -- \input child, which has no PDF of its own.
          vim.api.nvim_buf_create_user_command(ev.buf, "PDF", function()
            local pdf
            if vim.fn.exists("b:vimtex") == 1 then
              local ok, out = pcall(vim.fn.eval, "b:vimtex.compiler.get_file('pdf')")
              if ok and type(out) == "string" and out ~= "" then pdf = out end
            end
            pdf = pdf or (vim.fn.expand("%:p:r") .. ".pdf")

            if vim.fn.filereadable(pdf) == 0 then
              vim.notify(("no compiled PDF at %s (:VimtexCompile builds it)"):format(pdf),
                vim.log.levels.WARN)
              return
            end

            if vim.fn.has("macunix") == 1 then
              vim.fn.jobstart({ "open", pdf }, { detach = true })
            elseif vim.fn.has("win32") == 1 then
              vim.fn.jobstart({ "cmd.exe", "/c", "start", "", pdf }, { detach = true })
            else
              vim.fn.jobstart({ "xdg-open", pdf }, { detach = true })
            end
          end, { desc = "open compiled PDF in the system viewer" })

          vim.keymap.set("n", "<localleader>vw", "<Cmd>VimtexCountWords<CR>", o("vimtex word count"))

          -- Accent spell-check (noethervim-tex). Override the
          -- built-in zg / zw / z= so they understand LaTeX accent
          -- macros: when the cursor sits on  K\"ahler  these operate
          -- on the decoded Unicode form  Kähler  and re-encode back
          -- to LaTeX after picking a suggestion. When there's no
          -- accent token under cursor the implementation falls
          -- through to vim's built-in zg / zw / z= via  :normal! ,
          -- so plain words still work as expected.
          local plug_opts = function(desc)
            return { silent = true, buffer = ev.buf, desc = desc, remap = true }
          end
          vim.keymap.set("n", "zg", "<Plug>(noethervim-tex-accent-add)",
            plug_opts("spell: add (latex-aware)"))
          vim.keymap.set("n", "zw", "<Plug>(noethervim-tex-accent-mark-wrong)",
            plug_opts("spell: mark wrong (latex-aware)"))
          -- z= : on a LaTeX accent token (K\"ahler) open the custom
          -- latex-aware picker that re-encodes the chosen suggestion back to
          -- its accent macro. On a plain word, fall through to which-key's
          -- spelling popup -- the global z= behaviour this buffer-local map
          -- would otherwise shadow.
          vim.keymap.set("n", "z=", function()
            local accent = require("noethervim-tex.accent_spell")
            if accent.token_under_cursor() then
              accent.suggest()
            else
              require("which-key").show({ keys = "z=" })
            end
          end, o("spell: suggest (which-key / latex-aware)"))

          -- Stopping: vimtex's stop() is a no-op unless a compile is
          -- mid-run, which with single-shot latexmk (continuous = 0) it
          -- almost never is, so the BufWritePost auto-compile above would
          -- keep re-firing forever. Wrap the stop entry points to mark the
          -- project stopped (status 0, vimtex's stopped-state); the
          -- auto-compile stands down and the next manual compile re-arms
          -- it. Both the commands and the <plug> mappings need wrapping:
          -- <localleader>lk maps to <plug>(vimtex-stop), which calls
          -- vimtex#compiler#stop() directly, bypassing :VimtexStop.
          local function statusline_refresh()
            pcall(function() require("noethervim.util.vimtex_status").invalidate() end)
            pcall(vim.cmd.redrawstatus, { bang = true })
          end

          local function stop_project()
            if vim.fn.exists("b:vimtex") == 0 then return end
            if vim.api.nvim_eval("b:vimtex.compiler.is_running()") == 1 then
              vim.fn["vimtex#compiler#stop"]()
            else
              vim.notify("vimtex: on-save auto-compile disarmed")
            end
            vim.cmd("let b:vimtex.compiler.status = 0")
            statusline_refresh()
          end

          local function stop_all_projects()
            vim.fn["vimtex#compiler#stop_all"]()
            vim.cmd([[
              for st in vimtex#state#list_all()
                let st.compiler.status = 0
              endfor
              unlet! st
            ]])
            statusline_refresh()
            vim.notify("vimtex: all projects stopped, on-save auto-compile disarmed")
          end

          vim.api.nvim_buf_create_user_command(ev.buf, "VimtexStop", stop_project,
            { desc = "stop compilation and on-save auto-compile" })
          vim.api.nvim_buf_create_user_command(ev.buf, "VimtexStopAll", stop_all_projects,
            { desc = "stop all compilation and on-save auto-compile" })
          vim.keymap.set("n", "<plug>(vimtex-stop)", stop_project, { buffer = ev.buf })
          vim.keymap.set("n", "<plug>(vimtex-stop-all)", stop_all_projects, { buffer = ev.buf })

          -- ── Forward search is only as current as the last compile ──────
          -- SyncTeX maps source lines as they were when the PDF was built.
          -- With `continuous = 0` above, nothing rebuilds unless asked, so a
          -- PDF can sit hours behind the buffer; the viewer then lands where
          -- the cursor's line number used to be. That is silent, and it looks
          -- exactly like a broken viewer configuration.
          --
          -- Say so before syncing anyway, and name the key that fixes it.
          -- Resolved from the live keymap table rather than written as `\ll`,
          -- so a rebind is reflected.
          local function compile_key()
            local best
            local maps = vim.api.nvim_buf_get_keymap(ev.buf, "n")
            vim.list_extend(maps, vim.api.nvim_get_keymap("n"))
            for _, km in ipairs(maps) do
              if (km.rhs or ""):find("vimtex%-compile%)") then
                if not best or #km.lhs < #best then best = km.lhs end
              end
            end
            return best and vim.fn.keytrans(
              vim.api.nvim_replace_termcodes(best, true, true, true))
          end

          --- Why forward search may miss, or nil when it should be accurate.
          ---
          --- The file to compare against is the SyncTeX map rather than the
          --- PDF. They come apart: a run can refresh the PDF and leave the
          --- `.synctex.gz` from an earlier one, and forward search reads the
          --- map. Fall back to the PDF only when there is no map to check.
          local function sync_drift()
            -- A build in flight is about to make all of this current. Saying
            -- the PDF is behind during the seconds a compile takes is how a
            -- warning becomes noise, because the on-save auto-compile means
            -- the normal editing loop passes through this state every time.
            local running_ok, running = pcall(vim.fn.eval, "b:vimtex.compiler.is_running()")
            if running_ok and running == 1 then return nil end

            if vim.bo[ev.buf].modified then
              return "this buffer has unsaved changes"
            end

            local function output(ext)
              local ok, path = pcall(vim.fn.eval,
                ("b:vimtex.compiler.get_file('%s')"):format(ext))
              if not ok or type(path) ~= "string" or path == "" then return nil end
              local stat = vim.uv.fs_stat(path)
              return stat and { path = path, mtime = stat.mtime.sec } or nil
            end

            local map = output("synctex.gz")
            local built = map or output("pdf")
            -- Nothing compiled at all is vimtex's message to give, not ours.
            if not built then return nil end

            local src = vim.api.nvim_buf_get_name(ev.buf)
            local edited = src ~= "" and vim.uv.fs_stat(src) or nil
            if not edited or edited.mtime.sec <= built.mtime then return nil end

            local mins = math.floor((edited.mtime.sec - built.mtime) / 60)
            local age = mins < 1 and "less than a minute"
              or mins < 60 and (mins .. (mins == 1 and " minute" or " minutes"))
              or (math.floor(mins / 60) .. (mins < 120 and " hour" or " hours"))
            return (map and "the SyncTeX data is " or "the PDF is ")
              .. age .. " behind this file"
          end

          -- Overriding the command covers the key too: vimtex defines
          -- `<plug>(vimtex-view)` as `:VimtexView<cr>`, and the command is
          -- resolved when the mapping runs.
          vim.api.nvim_buf_create_user_command(ev.buf, "VimtexView", function(a)
            local drift = sync_drift()
            if drift then
              local key = compile_key()
              vim.notify(
                ("forward search may be off: %s%s"):format(
                  drift, key and (" (" .. key .. " rebuilds it)") or ""),
                vim.log.levels.WARN, { title = "vimtex" })
            end
            vim.fn["vimtex#view#view"](a.args or "")
          end, {
            nargs = "?",
            complete = "file",
            desc = "view the PDF, saying so when it is behind the buffer",
          })
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
  -- BibTeX citation picker on snacks.picker. <c-s-c> in insert mode;
  -- context-aware .bib discovery scans the current buffer's bibliography
  -- directives before falling back to the cwd.
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

  -- ── noethervim-tex ────────────────────────────────────────────────────────
  -- Spell-file shipping (en.utf-8.add math vocab + accents.utf-8.add for
  -- LaTeX-accented proper nouns) is handled inside noethervim-tex's own
  -- plugin/noethervim_tex.lua at plugin load -- this bundle no longer
  -- needs to mkspell or append to spellfile. The accent spell-check
  -- diagnostics layer also lives there; configure via opts.accent_spell.
  {
    "Chiarandini/NoetherVim-tex",
    event = "VeryLazy",
    dependencies = { "L3MON4D3/LuaSnip" },
    opts = {
      -- Snippet sets beyond the ones that work in any LaTeX document. Both
      -- default off: `conventions` is the theorem family in the two-argument
      -- `\begin{defn}{Name}{label}` form, which needs declarations your
      -- preamble may not have, and `acronyms` is prose shorthand (wlog,
      -- tfae, ...) that is one writer's vocabulary rather than a default.
      -- See https://nathanaelsrawley.com/noethervim/guides/latex-setup/
      -- snippets            = { conventions = false, acronyms = false },
      --
      -- Where `@` looks for preamble fragments, searched in order. A relative
      -- entry is found by walking up from the document and is referenced with
      -- \input; an absolute one is your library and is inserted inline.
      -- preamble            = { folders = { "preamble", vim.fn.stdpath("config") .. "/preamble/" } },
      -- extra_snippet_paths = {},
      -- textobjects         = true,
      -- accent_spell        = { enabled = true, severity = vim.diagnostic.severity.INFO },
      -- follow              = { event = "moved", debounce = 150 },  -- false to skip entirely
    },
    config = function(_, opts)
      require("noethervim-tex").setup(opts)

      -- PDF-follows-cursor, off until asked for per buffer. `<localleader>lf`
      -- sits in vimtex's own `<localleader>l` command namespace, next to `ll`
      -- compile and `lv` view, because that is what it is -- a third thing to
      -- do with the viewer.
      -- The plugin already owns the toggle and its message as
      -- :VimtexFollowToggle; this only gives it a buffer-local key, so the
      -- wording does not exist in two places to drift apart.
      local function bind_follow(buf)
        vim.keymap.set("n", "<localleader>lf", "<cmd>VimtexFollowToggle<cr>",
          { buffer = buf, desc = "[l]atex PDF [f]ollow toggle" })
      end

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("noethervim_tex_follow_keys", { clear = true }),
        pattern = { "tex", "plaintex", "latex" },
        callback = function(ev) bind_follow(ev.buf) end,
      })

      -- This spec is `VeryLazy`, so FileType has already fired for the tex
      -- file that was opened to trigger it. Bind those too, or the key is
      -- missing in exactly the buffer that caused the plugin to load.
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        local ft = vim.bo[buf].filetype
        if ft == "tex" or ft == "plaintex" or ft == "latex" then bind_follow(buf) end
      end

    end,
  },

  -- Register the preambles blink.cmp source (provided by noethervim-tex)
  -- and enrich vimtex's label completions with documentation: hovering a
  -- label item in \cref{...} / \ref{...} shows the part/chapter/section it
  -- lives under and its LaTeX source (theorem statement, titled box, ...)
  -- in the documentation window. Labels missing from the cache resolve to
  -- no documentation -- exactly the previous behaviour.
  {
    "saghen/blink.cmp",
    opts = {
      sources = {
        per_filetype = {
          tex = { "lsp", "snippets", "vimtex", "figures", "preambles" },
        },
        providers = {
          preambles = {
            name   = "preambles",
            module = "noethervim-tex.sources.preambles",
          },
          -- Completes figure filenames inside \incfig{}, \includegraphics{}
          -- and \import{}{}. The list previously named a provider "images"
          -- that was never defined, so the entry did nothing.
          figures = {
            name   = "figures",
            module = "noethervim-tex.sources.figures",
          },
          vimtex = {
            override = {
              resolve = function(_source, item, callback)
                local labels = require("noethervim.util.latex_labels")
                local label  = item.textEdit and item.textEdit.newText or item.label
                local entry  = label and labels.find_entry(label)
                local doc    = entry and labels.documentation(entry)
                callback(doc and { documentation = { kind = "markdown", value = doc } } or nil)
              end,
            },
          },
        },
      },
    },
  },

  -- ── Oil: open .tex (gt) / .pdf (gP) in current dir ──────────────────────
  -- LaTeX-specific Oil keymaps -- open the .tex (gt) or .pdf (gP) file in the
  -- current Oil directory, or show a picker if there are multiple.
  --
  -- `gt` is `noethervim.util.oil_pick` narrowed to .tex, so it inherits that
  -- picker's two keys: <CR> opens the file exactly as <CR> on the Oil line
  -- would, <S-CR> only lands the Oil cursor on it. Opening goes through
  -- oil.select(), which is what keeps the float case -- close the float,
  -- edit in the window behind it -- out of this file.
  {
    "stevearc/oil.nvim",
    opts = {
      keymaps = {
        ["gt"] = {
          desc = "open .tex file in current dir",
          callback = function()
            local dir = require("oil").get_current_dir()
            if not dir then return end
            require("noethervim.util.oil_pick").pick({
              filter      = function(entry) return entry.name:match("%.tex$") ~= nil end,
              title       = "Select .tex file",
              empty       = "No .tex files in " .. dir,
              auto_select = true,
            })
          end,
        },
        -- gP: twin of gt, but for the compiled PDF. Hands the file to the
        -- system viewer (Skim, per the user's VimTeX setup) via the same
        -- detached `open`/`xdg-open` idiom as :PDF above. Unlike gt we stay
        -- in nvim, so Oil is left open -- no float-close, no :edit.
        ["gP"] = {
          desc = "open .pdf file in current dir",
          callback = function()
            local dir = require("oil").get_current_dir()
            if not dir then return end
            local files = vim.fn.glob(dir .. "*.pdf", false, true)
            if #files == 0 then
              vim.notify("No .pdf files in " .. dir, vim.log.levels.WARN)
              return
            end
            local function open_pdf(path)
              if vim.fn.has("macunix") == 1 then
                vim.fn.jobstart({ "open", path }, { detach = true })
              elseif vim.fn.has("win32") == 1 then
                vim.fn.jobstart({ "cmd.exe", "/c", "start", "", path }, { detach = true })
              else
                vim.fn.jobstart({ "xdg-open", path }, { detach = true })
              end
            end
            if #files == 1 then
              open_pdf(files[1])
            else
              vim.ui.select(files, {
                prompt = "Select .pdf file:",
                format_item = function(f) return vim.fn.fnamemodify(f, ":t") end,
              }, function(choice)
                if choice then open_pdf(choice) end
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
		keys = {
			{ SearchLeader .. "w", "<cmd>SnacksLatexLabels<cr>", desc = "labels" },
		},
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
        -- cleveref names the counter itself: \cref{eq:foo} renders as
        -- "eq. (1)", parentheses included, so \eqref would be redundant.
        ["ex:"] = "example~\\ref{%s}", ["eq:"] = "\\cref{%s}",
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

      -- ── gd / <C-]>: goto label definition ────────────────────────────────
      -- Label extraction and cache lookup live in noethervim.util.latex_labels.
      -- gd jumps directly (LSP fallback when not on a prefixed label);
      -- 'tagfunc' routes <C-]>, <C-w>] and :tag through the same lookup while
      -- pushing the tag stack, so <C-t> jumps back. Both search the current
      -- project's cache first (subfile chains resolve to their top-level
      -- root), then every other cached project.
      local labels = require("noethervim.util.latex_labels")

      local function setup_nav(bufnr)
        vim.bo[bufnr].tagfunc = "v:lua.require'noethervim.util.latex_labels'.tagfunc"

        vim.keymap.set("n", "gd", function()
          local label = labels.label_at_cursor()
          if not label then vim.lsp.buf.definition(); return end
          local entry = labels.find_entry(label)
          if not entry then
            -- Nowhere to jump -- label not yet written or indexed.
            vim.notify("[gd] '" .. label .. "' not found in any cache -- run :LatexLabels update", vim.log.levels.WARN)
            return
          end
          local cur = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p")
          if cur ~= entry.filename then
            vim.cmd("edit " .. vim.fn.fnameescape(entry.filename))
          end
          vim.api.nvim_win_set_cursor(0, { entry.line, 0 })
          vim.cmd("normal! zz")
        end, { buffer = bufnr, desc = "goto label definition (LaTeX)" })
      end

      -- Wire navigation for buffers opened after this plugin loads.
      vim.api.nvim_create_autocmd("FileType", {
        pattern  = { "tex", "latex" },
        callback = function(args) setup_nav(args.buf) end,
      })
      -- The FileType event already fired for the buffer that triggered this
      -- plugin load, so wire it up for the current buffer immediately too.
      local ft = vim.bo.filetype
      if ft == "tex" or ft == "latex" then
        setup_nav(vim.api.nvim_get_current_buf())
      end
      -- Re-register after texlab attaches: the LspAttach handler in lsp.lua fires
      -- after FileType and overwrites gd with vim.lsp.buf.definition.
      -- Since this autocmd is registered later it runs second and wins.
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if client and client.name == "texlab" then
            setup_nav(args.buf)
          end
        end,
      })
    end,
  },

}
