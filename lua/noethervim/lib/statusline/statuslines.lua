--- Which statusline each kind of window gets, and the order they are tried in.
---
--- This is the assembly step. The component modules alongside this file each
--- build one piece -- the mode chip, the git counters, the ruler -- and this
--- decides which pieces make up the bar for a normal buffer, a help page, a
--- terminal, the dashboard, and so on. `init.lua` next door is the lazy.nvim
--- spec; it resolves colours and requires the components, then calls this.
---
--- Taken as arguments rather than required here on purpose. `heirline.utils
--- .surround()` captures its delimiter strings when a component module is
--- required, so the modules cannot load until the edge style is resolved --
--- which is why the whole chain lives inside the spec's `config()` and why
--- this file is a function rather than a table.
---
---@return table  a heirline statusline tree, `fallthrough = false`
return function(conditions, ctx, edges, vimode, filename, git, lsp, ruler, misc,
                insert_aware_bg, CircleComponent, MainComponent)
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

-- Either an edge-style endcap (slant/pointy/bubbly) OR the classic
-- `|` separator (round/straight). The endcap sits inside StatusComponent
-- but explicitly sets its own bg so that the `fg = StatusComponent bg /
-- bg = MainComponent bg` carve-out reads correctly: heirline merges
-- parent bg into children only when the child does not set bg.
local StatusOpening = {
  fallthrough = false,
  {
    condition = function()
      return ctx.edges and ctx.edges.mid_left and ctx.edges.mid_left ~= ""
    end,
    flexible = ctx.priority.mid,
    {
      provider = function() return ctx.edges.mid_left end,
      hl = function()
        local mode = vim.fn.mode(1):sub(1, 1)
        local mc_bg = (mode == "i") and ctx.colors.default_blue or ctx.colors.default_gray
        local sc_bg = (mode == "i") and ctx.colors.default_blue or ctx.colors.light_gray
        return { fg = sc_bg, bg = mc_bg }
      end,
    },
    { provider = "" },
  },
  misc.Separator,
}

local StatusComponent = {
  hl = function()
    local mode = vim.fn.mode(1):sub(1, 1)
    if mode == "i" then
      return { fg = ctx.colors.text_gray, bg = ctx.colors.default_blue }
    end
    return { fg = ctx.colors.text_gray, bg = ctx.colors.light_gray }
  end,
  StatusOpening,
  misc.Lazy,
  ruler.FileSize,
  ruler.Percentage,
  misc.Space,
}

-- Optional opening endcap rendered immediately before ruler.Pos. Its
-- foreground is the active mode color (so the glyph "fills in" the
-- mode block) and its background mirrors StatusComponent's bg so
-- the glyph carves out of the surrounding section cleanly. Skipped
-- entirely when the chosen edge style omits end_left (e.g. "round",
-- "straight"), preserving the historical flush right edge.
local RulerEndcap = {
  condition = function() return ctx.edges and ctx.edges.end_left ~= nil end,
  provider = function() return ctx.edges.end_left end,
  hl = function()
    local mode = vim.fn.mode(1):sub(1, 1)
    local bg = (mode == "i") and ctx.colors.default_blue or ctx.colors.light_gray
    local fg = ctx.mode_colors[mode] or ctx.colors.default_gray
    return { fg = fg, bg = bg }
  end,
}

-- ── Statuslines ─────────────────────────────────────────

local DefaultStatusline = {
  hl = insert_aware_bg,
  CircleComponent,
  { provider = " ", hl = { force = true } },
  vimode.ViMode,
  misc.HiddenModified,
  misc.Jumpable,
  MainComponent,
  StatusComponent,
  RulerEndcap,
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
  RulerEndcap,
  ruler.Pos,
}

local InactiveStatusline = {
  condition = conditions.is_not_active,
  filename.FileName,
  misc.Align,
}

-- Quickfix and location lists. Ahead of SpecialStatusline, which used
-- to swallow them and render nothing at all: neither the help-filename
-- nor the filetype component has anything to say about a `quickfix`
-- buffer, so the bar came out blank.
local QuickfixStatusline = {
  condition = function()
    return conditions.buffer_matches({ buftype = { "quickfix" } })
  end,
  hl = function() return { bg = ctx.colors.default_gray } end,
  { condition = conditions.is_active, vimode.ViMode },
  misc.QuickfixInfo,
  misc.Align,
  misc.QCloseHint,
  ruler.Pos,
}

-- Help pages, checkhealth reports, and the rest of the read-only
-- buffers. They are usually long and always transient, so the bar
-- answers the two questions that raises -- where am I, and how do I
-- leave -- rather than repeating a filetype the content makes obvious.
local SpecialStatusline = {
  condition = function()
    -- :DiffOrig's disk-side scratch is nofile but conceptually a file;
    -- let it fall through to DefaultStatusline so it renders normally.
    if vim.b.noethervim_diff_scratch then return false end
    return conditions.buffer_matches({
      buftype = { "nofile", "prompt", "help" },
      filetype = { "^git.*", "fugitive" },
    }) and vim.bo.filetype ~= ""
  end,
  hl = function() return { bg = ctx.colors.default_gray } end,
  { condition = conditions.is_active, vimode.ViMode },
  misc.Space,
  misc.SpecialName,
  misc.Align,
  misc.QCloseHint,
  misc.FileType,
  misc.Space,
  ruler.Percentage,
  misc.Space,
  ruler.Pos,
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

-- The dashboard has no statusline. Snacks hides the bar entirely with
-- `laststatus = 0` while its dashboard is up, but restores that the
-- first time another window opens -- open `:help` from the dashboard,
-- close it again, and the bar is back with the dashboard still on
-- screen. Whatever laststatus says, there is nothing worth reporting
-- about a menu, so render an empty bar rather than letting the
-- read-only branch below claim it for its `nofile` buftype.
local DashboardStatusline = {
  condition = function()
    local ft = vim.bo.filetype
    return ft == "snacks_dashboard" or ft == "alpha"
  end,
  provider = "%=",
  hl = function() return { fg = ctx.colors.text_gray, bg = ctx.colors.bg } end,
}

local StatusLines = {
  -- the first statusline with no condition, or which condition returns
  -- true is used. Think of it as a switch case with breaks.
  fallthrough = false,

  DashboardStatusline,
  QuickfixStatusline,
  SpecialStatusline,
  TerminalStatusline,
  InactiveStatusline,
  OilStatusLine,
  DefaultStatusline,
}

  return StatusLines
end
