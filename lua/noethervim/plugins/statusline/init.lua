-- NoetherVim plugin: Heirline statusline -- the lazy.nvim spec.
--
-- Where things are, because three files answer to "statusline":
--
--   plugins/statusline/init.lua        THIS FILE. The plugin spec. Resolves
--                                      colours and edge style, requires the
--                                      component modules in the order their
--                                      construction demands, and calls
--                                      heirline.setup().
--   plugins/statusline/statuslines.lua Which bar each kind of window gets --
--                                      normal, help, terminal, quickfix,
--                                      dashboard -- and the order they are
--                                      tried in. The assembly step.
--   plugins/statusline/<name>.lua      One component each: the mode chip, the
--                                      git counters, the ruler, the filename
--                                      block. context.lua holds the colours
--                                      and helpers they share.
--   plugins/statusline/segments.lua   Heirline's side of the segments units
--                                      and you declare: one component each,
--                                      laid out by id among the core blocks.
--   noethervim/statusline.lua          NOT part of the build. The data any
--                                      statusline reads: segments, busy
--                                      entries, visibility by id, presets,
--                                      and your `statusline` settings.
return {
  {
    'rebelot/heirline.nvim',
    event = 'UIEnter',
    specs = {
      { "NoetherVim", optional = true, opts = require("noethervim.keymaps.rows").contribute(
        "heirline.nvim", require("noethervim.plugins.statusline.keymaps").rows()) },
      { "which-key.nvim", optional = true, opts = require("noethervim.util").labels({
        { "<c-w>s", icon = { icon = require("noethervim.util").icons.plus, color = "red" }, group = "Statusline" },
      }) },
    },
    config = function()
      local conditions = require("heirline.conditions")
      local utils = require("heirline.utils")

      -- ── Shared context ───────────────────────────────────────

      local ctx = require("noethervim.plugins.statusline.context")
      local nv_sl = require("noethervim.statusline")

      -- Populate the shared colors table (mutated in-place so all modules
      -- that close over ctx.colors stay up-to-date).
      local resolved = vim.tbl_extend("force",
        require("noethervim.theme").palette(),
        nv_sl.get_colors())
      for k, v in pairs(resolved) do ctx.colors[k] = v end
      local mc = ctx.make_mode_colors(ctx.colors)
      for k, v in pairs(mc) do ctx.mode_colors[k] = v end

      -- User-configurable edge style. Mutate semiCircles in place BEFORE
      -- component modules are required: heirline.utils.surround() captures
      -- the delimiter strings at component-build time (during require), so
      -- mutating later would leave the bubbles rendered with stale glyphs.
      local edges = nv_sl.get_edges()
      ctx.semiCircles[1] = edges.start_left
      ctx.semiCircles[2] = edges.start_right
      ctx.edges = edges

      -- ── Component modules ────────────────────────────────────

      local vimode    = require("noethervim.plugins.statusline.vimode")
      local filename  = require("noethervim.plugins.statusline.filename")
      local diag      = require("noethervim.plugins.statusline.diagnostics")
      local git       = require("noethervim.plugins.statusline.git")
      local lsp       = require("noethervim.plugins.statusline.lsp")
      local ruler     = require("noethervim.plugins.statusline.ruler")
      local misc      = require("noethervim.plugins.statusline.misc")
      local segments  = require("noethervim.plugins.statusline.segments")
      local tabline   = require("noethervim.plugins.statusline.tabline")
      local winbar    = require("noethervim.plugins.statusline.winbar")

      -- ── Assembly ─────────────────────────────────────────────

      -- Mode-aware bottom-statusline background. See ctx.mode_bg /
      -- ctx.with_mode_bg in context.lua for the helpers components can
      -- call directly when they need to embed this bg in their own hl
      -- (heirline's parent->child bg merge isn't always reliable when
      -- the child's hl is computed by a function).
      local function insert_aware_bg()
        return { bg = ctx.mode_bg() }
      end

      local CircleComponent = utils.surround(ctx.semiCircles, ctx.flag_bg, {
        fallthrough = false,
        misc.MacroRec,
        filename.MissingFileFlag,
        filename.NewFileFlag,
        filename.ReadOnlyFlag,
        filename.ScratchFlag,
        filename.ChangeFlag,
        {
          flexible = ctx.priority.high,
          { provider = "  " },
          { provider = "" },
        },
      })

      -- The core blocks by id (noethervim.statusline's CORE), with the
      -- segments units and you declared placed among them.
      local MainComponent = { hl = insert_aware_bg }
      vim.list_extend(MainComponent, segments.side("left", {
        { "diagnostics", { misc.Space, diag.Diagnostics, misc.Space } },
        { "busy",        { misc.Busy } },
        { "filename",    { filename.FileNameBlock } },
      }))
      table.insert(MainComponent, misc.Align)
      vim.list_extend(MainComponent, segments.side("right", {
        { "lsp",     { lsp.LSPActive, misc.Space } },
        { "git",     { git.GitBlock } },
        { "profile", { misc.FiletypeProfile } },
      }))

      -- Which window gets which bar: see statuslines.lua next door. Passed
      -- the already-required components, because their require order is
      -- load-bearing (see the note above `edges`).
      local StatusLines = require("noethervim.plugins.statusline.statuslines")(
        conditions, ctx, edges, vimode, filename, git, lsp, ruler, misc,
        insert_aware_bg, CircleComponent, MainComponent)


      -- ── Setup ────────────────────────────────────────────────

      -- A statusline, tabline or winbar you set yourself is not handed to
      -- heirline (noethervim.default reads who set each option), nor one
      -- `bars` in lua/user/config.lua switches off.
      local claimed = require("noethervim.default").claimed
      local function bar(name, component)
        if claimed(name) or not nv_sl.bar(name) then return nil end
        return component
      end

      local heirline = require("heirline")
      heirline.setup({
        statusline = bar("statusline", StatusLines),
        winbar = bar("winbar", winbar.DiffLabel),
        tabline = bar("tabline", tabline.TabPages),
        opts = {
          -- The DiffLabel winbar is meaningful only on diff windows (its
          -- `condition` is `vim.wo.diff`), which are normal splits. Heirline
          -- still sets the winbar option on every window; on a normal window
          -- an empty (non-diff) winbar collapses, but a floating window keeps
          -- the reserved row as a blank slot (the gap above blink.cmp's
          -- completion menu), and a one-row window has no row to give at all
          -- and fails with "Not enough room" (the message windows of
          -- `vim._core.ui2` are one row each). So skip every window that is
          -- not a plain split. Asking the window rather than the buffer keeps
          -- the scratch side of |:DiffOrig|, which is a `nofile` buffer in a
          -- real split, labelled.
          --
          -- Heirline hands the callback a buffer and iterates windows without
          -- entering them, so the window under decision is the current one
          -- only when the current one is holding that buffer.
          disable_winbar_cb = function(args)
            local cur  = vim.api.nvim_get_current_win()
            local wins = { cur }
            if args and args.buf and vim.api.nvim_win_get_buf(cur) ~= args.buf then
              wins = vim.fn.win_findbuf(args.buf)
            end
            for _, win in ipairs(wins) do
              if vim.api.nvim_win_get_config(win).relative ~= "" then return true end
            end
            return false
          end,
        },
      })

      -- Error boundary: a crash inside any component propagates up through
      -- heirline's _eval and would otherwise surface as a full-screen
      -- traceback that replaces the statusline. Wrap the eval entry points
      -- in pcall so we degrade to a marker instead of exploding, write
      -- the error to |:messages| (throttled to avoid feedback loops), and
      -- enter a cooldown before auto-retrying so transient bad state has
      -- time to settle. Override the delay via `vim.g.heirline_recovery_ms`
      -- (default 1000).
      --
      -- The cooldown is per window, because heirline renders each window's
      -- bar separately and the bad state is usually one buffer's; keyed on
      -- the surface alone, one failing window would blank every other bar.
      -- The tabline is drawn once for the whole screen, so it has one key.
      local last_err, last_err_time = nil, 0
      local cooldown_until = {}
      local function report_heirline_error(surface, err)
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
          local msg = ("heirline %s: %s"):format(surface, tostring(err)):gsub("\n", " | ")
          pcall(vim.cmd, "echomsg " .. vim.fn.string(msg))
        end)
      end
      -- How to redraw each surface once its cooldown ends. The broken window
      -- need not be the current one, which a bare `:redrawstatus` skips.
      local redraw = {
        statusline = "redrawstatus!",
        winbar     = "redrawstatus!",
        tabline    = "redrawtabline",
      }
      for surface, redraw_cmd in pairs(redraw) do
        local name = "eval_" .. surface
        local orig = heirline[name]
        local marker = ("%%#ErrorMsg# %s error, see :messages %%*"):format(surface)
        heirline[name] = function(...)
          -- Each window's bar is evaluated with that window current.
          local key = surface == "tabline" and surface
            or surface .. vim.api.nvim_get_current_win()
          local now = (vim.uv or vim.loop).now()
          if (cooldown_until[key] or 0) > now then return marker end
          local ok, result = pcall(orig, ...)
          if ok then return result end
          report_heirline_error(surface, result)
          local delay = tonumber(vim.g.heirline_recovery_ms) or 1000
          cooldown_until[key] = now + delay
          -- Kick off a redraw past the cooldown so the retry happens
          -- even if no other event triggers one.
          vim.defer_fn(function() pcall(vim.cmd, redraw_cmd) end, delay + 50)
          return marker
        end
      end

      -- The directory blocks read the window's working directory, so they go
      -- stale on any change to it. DirChanged covers all four sources: `:cd`,
      -- `:tcd`, `:lcd`, and 'autochdir' (which reports scope "window").
      vim.api.nvim_create_autocmd("DirChanged", {
        group    = vim.api.nvim_create_augroup("noethervim_heirline_cwd", { clear = true }),
        callback = function() vim.cmd.redrawstatus() end,
      })

      -- Re-derive palette when the colorscheme changes at runtime.
      -- Runs synchronously so colors are updated before the next render.
      vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("noethervim_heirline_colors", { clear = true }),
        callback = function()
          local new = vim.tbl_extend("force",
            require("noethervim.theme").palette(),
            nv_sl.get_colors())
          for k, v in pairs(new) do ctx.colors[k] = v end
          local new_mc = ctx.make_mode_colors(ctx.colors)
          for k, v in pairs(new_mc) do ctx.mode_colors[k] = v end
          require("heirline").reset_highlights()
        end,
      })
    end
  }
}
