-- `import = "noethervim.core"` in init.lua: NoetherVim's own spec, then
-- every core unit, one import per directory under core/ (a category), so a
-- new category loads without editing a list.
--
-- NoetherVim's spec merges over the one in your init.lua. It is a start
-- plugin whatever lazy.nvim's defaults say, and loads first among them, so
-- its defaults, plugin globals and key rows are in place before any other
-- plugin's config runs.
--
-- `opts` holds what units contribute from their own specs (see
-- noethervim.HostOpts): `rows` (distro mappings), `g` (plugin globals),
-- `startup` (registrations that must exist from the start), `gutter` (what
-- clicking a unit's sign does), and `segments` and `busy` (the statusline's).

local config = require("noethervim.config")

-- Loaded while lazy.nvim reads specs, when it never loads a plugin, so a
-- plugin config that writes through it later finds it already loaded
-- instead of pulling NoetherVim in ahead of its turn.
require("noethervim.default")

-- NOETHERVIM_NO_USER: none of your directories on 'runtimepath', so Neovim
-- sources nothing from your plugin/, after/ or ftplugin/ either.
if config.user_off() then config.prune_rtp() end

local specs = { {
  "NoetherVim",
  lazy = false,
  priority = 10000,
  opts_extend = { "rows" },
  -- A function, so it only fills in what is missing: a table here would
  -- replace contributions merged before this fragment.
  opts = function(_, opts)
    opts.rows = opts.rows or {}
    opts.g = opts.g or {}
    opts.startup = opts.startup or {}
    return opts
  end,
  config = function(_, opts) require("noethervim").setup(opts) end,
} }

local dir = vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)) .. "/core"
local categories = {}
for name, kind in vim.fs.dir(dir) do
  if kind == "directory" then table.insert(categories, name) end
end
table.sort(categories)
for _, name in ipairs(categories) do
  table.insert(specs, { import = "noethervim.core." .. name })
end

return specs
