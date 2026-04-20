-- NoetherVim plugin: Heirline Statusline
-- Component modules live alongside this file; this assembles them
-- and passes the final tree to heirline.setup().
return {
  {
    'rebelot/heirline.nvim',
    event = 'UIEnter',
    config = function()
      local conditions = require("heirline.conditions")
      local utils = require("heirline.utils")

      -- ── Shared context ───────────────────────────────────────

      local ctx = require("noethervim.plugins.statusline.context")
      local nv_sl = require("noethervim.statusline")

      -- Populate the shared colors table (mutated in-place so all modules
      -- that close over ctx.colors stay up-to-date).
      local resolved = vim.tbl_extend("force",
        require("noethervim.util.palette").resolve(),
        nv_sl.get_colors())
      for k, v in pairs(resolved) do ctx.colors[k] = v end
      local mc = ctx.make_mode_colors(ctx.colors)
      for k, v in pairs(mc) do ctx.mode_colors[k] = v end

      -- Global toggle state.
      vim.g.heirline_pdfsize_show = false
      vim.g.heirline_git_show = true
      vim.g.heirline_directory_show = false
      vim.g.heirline_lsp_show = true
      vim.g.heirline_proj_relative_dir_show = false
      vim.g.toggle_name_or_project_relative = true

      -- ── Component modules ────────────────────────────────────

      local vimode    = require("noethervim.plugins.statusline.vimode")
      local filename  = require("noethervim.plugins.statusline.filename")
      local diag      = require("noethervim.plugins.statusline.diagnostics")
      local git       = require("noethervim.plugins.statusline.git")
      local lsp       = require("noethervim.plugins.statusline.lsp")
      local ruler     = require("noethervim.plugins.statusline.ruler")
      local misc      = require("noethervim.plugins.statusline.misc")
      local bundle    = require("noethervim.plugins.statusline.bundle_extras")
      local tabline   = require("noethervim.plugins.statusline.tabline")
      local winbar    = require("noethervim.plugins.statusline.winbar")

      -- ── Assembly ─────────────────────────────────────────────

      local function insert_aware_bg()
        local mode = vim.fn.mode(1):sub(1, 1)
        if mode == "i" then
          return { bg = ctx.colors.default_blue }
        end
        return { bg = ctx.colors.default_gray }
      end

      local CircleComponent = utils.surround(ctx.semiCircles, function()
        local mode = vim.fn.mode(1):sub(1, 1)
        if mode == "i" then
          return ctx.colors.medium_blue
        end
        return ctx.colors.light_gray
      end, {
        fallthrough = false,
        misc.MacroRec,
        filename.ReadOnlyFlag,
        filename.ScratchFlag,
        filename.ChangeFlag,
        {
          flexible = ctx.priority.high,
          { provider = "  " },
          { provider = "" },
        },
      })

      local MainComponent = {
        hl = insert_aware_bg,

        misc.Space,
        diag.Diagnostics,
        misc.Space,
        misc.Busy,
        filename.FileNameBlock,
        misc.Align,
        bundle.PdfFileSize,
        misc.Space,
        bundle.VimtexCompilerStatus,
        bundle.DAPMessages,
        lsp.LSPActive,
        misc.Space,
        git.GitBlock,
      }
      for _, c in ipairs(nv_sl.get_extra_right()) do
        table.insert(MainComponent, c)
      end

      local OilComponent = {
        hl = insert_aware_bg,

        misc.Space,
        filename.OilBuffer,
        misc.Align,
        misc.Space,
        lsp.LSPActive,
        misc.Space,
        git.GitBlock,
      }

      local StatusComponent = {
        hl = function()
          local mode = vim.fn.mode(1):sub(1, 1)
          if mode == "i" then
            return { fg = ctx.colors.text_gray, bg = ctx.colors.default_blue }
          end
          return { fg = ctx.colors.text_gray, bg = ctx.colors.light_gray }
        end,
        misc.Separator,
        misc.Lazy,
        ruler.FileSize,
        ruler.Percentage,
        misc.Space,
      }

      -- ── Statuslines ─────────────────────────────────────────

      local DefaultStatusline = {
        hl = insert_aware_bg,
        CircleComponent,
        { provider = " ", hl = { force = true } },
        vimode.ViMode,
        misc.Jumpable,
        MainComponent,
        StatusComponent,
        ruler.Pos,
      }

      local OilStatusLine = {
        condition = function()
          return vim.bo.filetype == "oil"
        end,
        hl = insert_aware_bg,
        CircleComponent,
        { provider = " ", hl = { force = true } },
        vimode.ViMode,
        misc.Jumpable,
        OilComponent,
        StatusComponent,
        ruler.Pos,
      }

      local InactiveStatusline = {
        condition = conditions.is_not_active,
        filename.FileName,
        misc.Align,
      }

      local SpecialStatusline = {
        condition = function()
          return conditions.buffer_matches({
            buftype = { "nofile", "prompt", "help", "quickfix" },
            filetype = { "^git.*", "fugitive" },
          }) and vim.bo.filetype ~= ""
        end,
        hl = function() return { bg = ctx.colors.default_gray } end,
        misc.HelpFileName,
        misc.Align,
        misc.FileType,
      }

      local TerminalStatusline = {
        condition = function()
          return conditions.buffer_matches({ buftype = { "terminal" } })
        end,
        { condition = conditions.is_active, vimode.ViMode },
        { provider = " ",                   hl = function() return { bg = ctx.colors.default_gray } end },
        misc.TerminalName,
        { provider = "%=", hl = function() return { bg = ctx.colors.default_gray } end },
        misc.FileType,
      }

      local AlphaStatusline = {
        condition = function()
          return vim.bo.filetype == "alpha"
        end,
        provider = "%=",
        hl = function() return { fg = ctx.colors.text_gray, bg = ctx.colors.bg } end,
      }

      local StatusLines = {
        -- the first statusline with no condition, or which condition returns
        -- true is used. Think of it as a switch case with breaks.
        fallthrough = false,

        AlphaStatusline,
        SpecialStatusline,
        TerminalStatusline,
        InactiveStatusline,
        OilStatusLine,
        DefaultStatusline,
      }

      -- ── Setup ────────────────────────────────────────────────

      local heirline = require("heirline")
      heirline.setup({
        statusline = StatusLines,
        -- winbar = winbar.Dropbar,
        tabline = tabline.TabPages,
      })

      -- Error boundary: a crash inside any component propagates up through
      -- heirline's _eval and would otherwise surface as a full-screen
      -- traceback that replaces the statusline. Wrap the eval entry points
      -- in pcall so we degrade to a marker instead of exploding, write
      -- the error to |:messages| (throttled to avoid feedback loops), and
      -- enter a per-eval cooldown before auto-retrying so transient bad
      -- state has time to settle. Override the delay via
      -- `vim.g.heirline_recovery_ms` (default 1000).
      local last_err, last_err_time = nil, 0
      local cooldown_until = {}
      local function report_heirline_error(err)
        local now = (vim.uv or vim.loop).now()
        if err == last_err and (now - last_err_time) < 5000 then return end
        last_err, last_err_time = err, now
        -- Write to |:messages| so the trace is recoverable. We can't
        -- use |:silent| (it suppresses the history write) and we can't
        -- use ErrorMsg highlight (it triggers the hit-enter prompt).
        -- Plain echomsg only briefly flashes at the cmdline and gets
        -- painted over by the next redraw. Newlines are flattened
        -- because echomsg can't handle literal multi-line strings.
        vim.schedule(function()
          local msg = ("heirline: %s"):format(tostring(err)):gsub("\n", " | ")
          pcall(vim.cmd, "echomsg " .. vim.fn.string(msg))
        end)
      end
      for _, name in ipairs({ "eval_statusline", "eval_winbar", "eval_tabline", "eval_statuscolumn" }) do
        local orig = heirline[name]
        if type(orig) == "function" then
          heirline[name] = function(...)
            local now = (vim.uv or vim.loop).now()
            if (cooldown_until[name] or 0) > now then
              return "%#ErrorMsg# statusline recovering... %*"
            end
            local ok, result = pcall(orig, ...)
            if ok then return result end
            report_heirline_error(result)
            local delay = tonumber(vim.g.heirline_recovery_ms) or 1000
            cooldown_until[name] = now + delay
            -- Kick off a redraw past the cooldown so the retry happens
            -- even if no other event triggers one.
            vim.defer_fn(function() pcall(vim.cmd.redrawstatus) end, delay + 50)
            return "%#ErrorMsg# statusline recovering... %*"
          end
        end
      end

      -- Re-derive palette when the colorscheme changes at runtime.
      -- Runs synchronously so colors are updated before the next render.
      vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("noethervim_heirline_colors", { clear = true }),
        callback = function()
          local new = vim.tbl_extend("force",
            require("noethervim.util.palette").resolve(),
            nv_sl.get_colors())
          for k, v in pairs(new) do ctx.colors[k] = v end
          local new_mc = ctx.make_mode_colors(ctx.colors)
          for k, v in pairs(new_mc) do ctx.mode_colors[k] = v end
          require("heirline").reset_highlights()
        end,
      })

      -- Toggle keymaps.
      require("noethervim.plugins.statusline.keymaps").setup()
    end
  }
}
