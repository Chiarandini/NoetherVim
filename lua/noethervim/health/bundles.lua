--- The bundles that are on, and what each needs installed.

local h = vim.health

--- The bundles that are on, as a set of `<category>.<name>`.
--- lazy.core.config.spec.modules is the authoritative list of what was
--- imported during lazy.setup(). Per-plugin spec._.module / spec._.imported
--- do not exist; reading them returns nil for every plugin.
---@return table<string, true>
local function active_set()
  local set = {}
  local ok_lazy_cfg, lazy_cfg = pcall(require, "lazy.core.config")
  if ok_lazy_cfg and lazy_cfg.spec and lazy_cfg.spec.modules then
    for _, mod in ipairs(lazy_cfg.spec.modules) do
      local bundle = mod:match("^noethervim%.bundles%.(.+)$")
      if bundle then set[bundle] = true end
    end
  end
  return set
end

local active_bundles

--- Probe one `@requires` entry from a bundle's annotation header.
---
--- `note` requirements cannot be probed from Neovim -- a shared library a
--- plugin links against, "the REPL binary for your language", a vault path.
--- They are reported as info so they stay visible without pretending to a
--- pass/fail they cannot deliver.
---@param bundle string  `<category>.<name>`
---@param r noethervim.BundleRequirement
local function check_requirement(bundle, r)
  local detail = r.why and (r.label .. " -- " .. r.why) or r.label
  local hint = r.install and ("  [" .. r.install .. "]") or ""

  if r.kind == "note" then
    return h.info(("%s: %s%s"):format(bundle, detail, hint))
  end

  local present
  if r.kind == "exe" then
    present = vim.fn.executable(r.value) == 1
  elseif r.kind == "env" then
    present = (vim.env[r.value] or "") ~= ""
  elseif r.kind == "app" then
    -- GUI applications are not on PATH on macOS, so fs_stat the bundle.
    -- Elsewhere they usually are, so fall back to a normal probe.
    if vim.fn.has("mac") == 1 then
      present = vim.uv.fs_stat("/Applications/" .. r.value .. ".app") ~= nil
    else
      present = vim.fn.executable(r.value:lower()) == 1
    end
  end

  if present then
    h.ok(("%s: %s"):format(bundle, detail))
  elseif r.optional then
    h.warn(("%s: %s not found (optional)%s"):format(bundle, detail, hint))
  else
    h.error(("%s: %s not found%s"):format(bundle, detail, hint))
  end
end

-- ── Bundles ──────────────────────────────────────────────────────────
local function active()
  h.start("Active bundles")
  if next(active_bundles) then
    local names = vim.tbl_keys(active_bundles)
    table.sort(names)
    for _, name in ipairs(names) do
      h.ok("noethervim.bundles." .. name)
    end
  else
    h.info("No bundles enabled")
  end
end

-- ── Bundle requirements ─────────────────────────────────────────────
local function requirements()
  -- Read from each active bundle's `@requires` annotation, which is the
  -- single source of truth shared with `:NoetherVim bundles` and the docs
  -- site. Adding a requirement means editing that bundle's header; nothing
  -- is listed here.
  do
    local init = vim.api.nvim_get_runtime_file("lua/noethervim/init.lua", false)[1]
    local root = init and vim.fn.fnamemodify(init, ":h:h:h")
    local keys = vim.tbl_keys(active_bundles)
    table.sort(keys)

    if root and #keys > 0 then
      h.start("Bundle requirements")
      local bundle_meta = require("noethervim.catalog.meta")
      local bundles_dir = root .. "/lua/noethervim/bundles"
      local found_any = false

      for _, key in ipairs(keys) do
        local meta = bundle_meta.get(bundles_dir, key)
        if meta then
          for _, err in ipairs(meta.errors) do h.error(err) end
          for _, req in ipairs(meta.requires) do
            found_any = true
            check_requirement(key, req)
          end
        end
      end

      if not found_any then
        h.ok("no external requirements for the active bundles")
      end
    end
  end
end

local M = {}

M.active_set = active_set

function M.check()
  active_bundles = active_set()
  active()
  requirements()
end

return M
