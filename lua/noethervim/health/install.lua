--- The init.lua NoetherVim starts from, and what lazy.nvim made of the spec.

local h = vim.health

-- ── Template version ─────────────────────────────────────────────────
local function template()
  h.start("Template version")
  local lazy_cfg = require("lazy.core.config")
  -- noethervim.core imports one module per category; lazy records those.
  local core = vim.iter(lazy_cfg.spec.modules):any(function(m) return vim.startswith(m, "noethervim.core.") end)
  if not core then
    h.error("NoetherVim's core is not imported, so none of its plugins are loaded", {
      'In init.lua, set `import = "noethervim.core"` on the NoetherVim spec '
        .. '(template v3 and older import "noethervim.plugins"); see NEWS.md',
    })
  else
    -- A plugin NoetherVim replaces with another is switched off by the unit
    -- that replaces it, so disabling that unit brings Neovim's back. In
    -- disabled_plugins as well, it stays off either way.
    local replaced_by = { netrwPlugin = "oil.nvim", matchit = "vim-matchup", matchparen = "vim-matchup" }
    for _, name in ipairs(lazy_cfg.options.performance.rtp.disabled_plugins or {}) do
      local by = replaced_by[name]
      if by and lazy_cfg.plugins[by] then
        h.info(("`%s` in disabled_plugins is redundant: %s switches it off, and back on when you disable %s")
          :format(name, by, by))
      elseif by then
        h.warn(("`%s` is in disabled_plugins and %s is off, so nothing replaces it"):format(name, by),
          { ("Remove `%s` from performance.rtp.disabled_plugins in init.lua"):format(name) })
      end
    end
  end

  local user_init = vim.fn.stdpath("config") .. "/init.lua"
  local upstream_init = vim.api.nvim_get_runtime_file("init.lua.example", false)[1]

  local function read_template_version(path)
    if not path or not vim.uv.fs_stat(path) then return nil end
    local f = io.open(path, "r")
    if not f then return nil end
    local line = f:read("*l")
    f:close()
    if not line then return nil end
    return line:match("noethervim%-template%-version:%s*(%d+)")
  end

  local user_version     = read_template_version(user_init)
  local upstream_version = read_template_version(upstream_init)

  -- In dev mode init.lua may be a wrapper around another config rather than
  -- a copy of the template; one without a version marker is not compared.
  if vim.g.noethervim_dev and not user_version then
    h.info("Skipped (vim.g.noethervim_dev set and init.lua has no template marker)")
  elseif not upstream_version then
    -- Upstream has no marker -- version 1 (pre-release).
    -- Any user template (with or without a marker) is current.
    h.ok("Template version: current")
  elseif not user_version then
    -- Upstream added a version marker but user still has the old template.
    h.warn(string.format(
      "Your init.lua has no template version marker, but v%s is available. " ..
      "See init.lua.example for new features.",
      upstream_version
    ))
  elseif tonumber(user_version) < tonumber(upstream_version) then
    h.warn(string.format(
      "Your init.lua is based on template v%s, but v%s is available. " ..
      "See init.lua.example for new features.",
      user_version, upstream_version
    ))
  else
    h.ok("Template version: " .. user_version .. " (up to date)")
  end
end

-- ── Spec errors ──────────────────────────────────────────────────────
local function spec_errors()
  -- lazy.core.config.spec.notifs collects every ERROR/WARN emitted while
  -- resolving the spec. The stock init.lua.example installs
  -- `util.buffer_notify()` before lazy.setup so these surface as snacks
  -- toasts after VimEnter instead of the cmdline ErrorMsg that would
  -- otherwise fire the hit-enter prompt on the dashboard. Toasts are
  -- transient, so mirror the same list here -- stale imports stay
  -- visible in :checkhealth long after the toast has scrolled away.
  h.start("Spec errors")
  local ok_lazy_cfg, lazy_cfg = pcall(require, "lazy.core.config")
  if not ok_lazy_cfg or not lazy_cfg.spec then
    h.info("Skipped (lazy.nvim not initialised)")
  else
    local errors = {}
    for _, n in ipairs(lazy_cfg.spec.notifs or {}) do
      if n.level == vim.log.levels.ERROR then
        errors[#errors + 1] = n.msg
      end
    end
    if #errors == 0 then
      h.ok("No spec errors")
    else
      -- A missing module whose leaf name still matches a shipped bundle was
      -- renamed rather than deleted, and the new path is the fix. Saying so
      -- turns the error from a search into an edit.
      local by_leaf = {}
      local init_path = vim.api.nvim_get_runtime_file("lua/noethervim/init.lua", false)[1]
      local tree = init_path and vim.fn.fnamemodify(init_path, ":h:h:h")
      if tree then
        for _, entry in ipairs(require("noethervim.util").scan_bundles(
              tree .. "/lua/noethervim/bundles")) do
          by_leaf[entry.name] = entry.category .. "." .. entry.name
        end
      end
      for _, msg in ipairs(errors) do
        h.error(msg)
        local module = msg:match('No specs found for module "([^"]+)"')
        local leaf = module and module:match("([^.]+)$")
        local moved = leaf and by_leaf[leaf]
        if moved and module ~= "noethervim.bundles." .. moved then
          h.info(("`%s` still ships, as `noethervim.bundles.%s`. "):format(leaf, moved)
            .. "Update the import in init.lua.")
        end
      end
      h.info("Most common cause: a bundle imported in init.lua was "
        .. "removed or renamed upstream. Remove the stale import.")
    end
  end
end

local M = {}

function M.check()
  template()
  spec_errors()
end

return M
