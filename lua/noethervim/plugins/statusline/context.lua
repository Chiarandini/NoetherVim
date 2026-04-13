-- Shared state and helpers for the heirline statusline.
-- Colors and mode_colors are populated by init.lua and mutated in-place
-- on ColorScheme changes, so all references across modules stay valid.

local M = {}

M.semiCircles = { "", "" }

M.priority = {
  max = 4,
  high = 3,
  mid = 2,
  low = 1,
  none = 0,
}

M.lspColor = {
  lua = "#718ECF",
  tex = "#8CAC60",
  typescriptreact = "#0C79B3",
  javascript = "#0C79B3",
  python = "#FFD141",
}

M.mode_names = {
  n = "N", no = "N?", nov = "N?", noV = "N?", ["no\22"] = "N?",
  niI = "Ni", niR = "Nr", niV = "Nv", nt = "Nt",
  v = "V", vs = "Vs", V = "V_", Vs = "Vs",
  ["\22"] = "^V", ["\22s"] = "^V",
  s = "S", S = "S_", ["\19"] = "^S",
  i = "I", ic = "Ic", ix = "Ix",
  R = "R", Rc = "Rc", Rx = "Rx", Rv = "Rv", Rvc = "Rv", Rvx = "Rv",
  c = "C", cv = "Ex",
  r = "...", rm = "M", ["r?"] = "?", ["!"] = "!", t = "T",
}

-- Populated by init.lua before any component is rendered.
M.colors = {}
M.mode_colors = {}

function M.make_mode_colors(colors)
  return {
    -- Base modes
    n = colors.green,
    i = colors.light_blue,
    v = colors.visual_orange,
    V = colors.visual_orange,
    s = colors.light_orange,
    S = colors.light_orange,
    R = colors.red,
    c = colors.command_line,
    t = colors.terminal_blue,

    -- Normal mode variations
    no = colors.light_orange,
    nov = colors.light_orange,
    noV = colors.light_orange,
    ["no\22"] = colors.light_orange,
    niI = colors.normal_insert_green,
    niR = colors.normal_insert_green,
    niV = colors.normal_insert_green,
    nt = colors.normal_terminal_green,

    -- Visual mode variations
    vs = colors.visual_select_orange,
    Vs = colors.visual_select_orange,
    ["\22"] = colors.cyan,
    ["\22s"] = colors.cyan,

    -- Select block
    ["\19"] = colors.select_block_orange,

    -- Insert mode variations
    ic = colors.insert_completion_blue,
    ix = colors.insert_completion_blue,

    -- Replace mode variations
    r = colors.red,
    Rv = colors.replace_variation_red,
    Rc = colors.replace_variation_red,
    Rx = colors.replace_variation_red,
    Rvc = colors.replace_variation_red,
    Rvx = colors.replace_variation_red,

    -- Command mode variations
    cv = colors.command_ex_line,

    -- Other
    rm = colors.yellow,
    ["r?"] = colors.light_orange,
    ["!"] = colors.yellow,
  }
end

-- Cache git root lookups by directory path: finddir(".git/..") is a
-- synchronous filesystem walk that fires on every statusline redraw.
local _git_root_cache = {}
function M.cached_git_root(path)
  if _git_root_cache[path] == nil then
    _git_root_cache[path] = vim.fn.finddir(".git/..", path .. ";")
  end
  return _git_root_cache[path]
end

return M
