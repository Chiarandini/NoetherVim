--- The files of yours that change NoetherVim's, and what they changed.

local h = vim.health

-- ── User override system ──────────────────────────────────────────────
local function overrides()
  h.start("User override system")

  local nv = require("noethervim")
  if nv._user_loaded then
    h.ok("User overrides: ACTIVE")
  else
    h.warn("User overrides: DISABLED")
    if vim.env.NOETHERVIM_NO_USER then
      h.info("  NOETHERVIM_NO_USER is set")
    end
    if vim.g.noethervim_no_user then
      h.info("  vim.g.noethervim_no_user is set")
    end
  end

  -- Report which hook files the user layer sourced
  if #nv._user_modules > 0 then
    h.ok("Sourced from lua/user/: " .. table.concat(nv._user_modules, ", "))
  else
    h.info("No hook files in lua/user/ (options, keymaps, autocmds, highlights)")
  end
  -- Directories NoetherVim no longer reads: say where their contents go.
  local udir = require("noethervim.config").user_dir()
  local moved = {
    lsp       = "after/lsp/<server>.lua, returning the settings table",
    overrides = "after/plugin/, which runs after everything NoetherVim does",
  }
  for name, where in pairs(udir and moved or {}) do
    local dir = udir .. "/lua/user/" .. name
    if vim.fn.isdirectory(dir) == 1 and #vim.fn.glob(dir .. "/*.lua", false, true) > 0 then
      h.warn("lua/user/" .. name .. "/ is no longer read; move its files to " .. where)
    end
  end
end

-- ── Override drift ───────────────────────────────────────────────────
local function drift()
  -- An override keeps winning after the file it shadows changes, and nothing
  -- else in the system would say so: an upstream fix simply never arrives,
  -- and the resulting bug reproduces on one machine only.
  --
  -- Only overrides created through `:NoetherVim override` have a recorded
  -- baseline. One written by hand has nothing to compare against, and
  -- reporting it would be noise rather than information.
  do
    h.start("Override drift")
    local init = vim.api.nvim_get_runtime_file("lua/noethervim/init.lua", false)[1]
    local root = init and vim.fn.fnamemodify(init, ":h:h:h")

    if not root then
      h.info("Skipped -- cannot locate the NoetherVim source directory")
    else
      local base    = require("noethervim.inspect.override_base")
      local tracked = vim.tbl_count(base.load())
      local drifted = base.scan(root)

      if tracked == 0 then
        h.info("No overrides are tracked yet (created by `:NoetherVim override`)")
      elseif #drifted == 0 then
        h.ok(("%d tracked override(s), all current"):format(tracked))
      end

      for _, d in ipairs(drifted) do
        local name = vim.fn.fnamemodify(d.user_path, ":t:r")
        if d.current == nil then
          h.warn(("%s overrides %s, which no longer exists upstream"):format(
            vim.fn.fnamemodify(d.user_path, ":~"), d.rel),
            { ("If it moved, `:NoetherVim diff %s` opens it; run `:NoetherVim override` from there "
              .. "to clear this"):format(name) })
        else
          h.warn(("%s changed since you overrode it -- compare with `:NoetherVim diff %s`, "
            .. "then re-run `:NoetherVim override` from it to clear this"):format(d.rel, name))
        end
      end
    end
  end
end

-- ── Plugin configs of yours ──────────────────────────────────────────
local function plugin_configs()
  h.start("Plugin configs")
  local where = require("noethervim.inspect.where")
  local replaced = 0
  local plugins = require("lazy.core.config").plugins
  local plugin_names = vim.tbl_keys(plugins)
  table.sort(plugin_names)
  for _, name in ipairs(plugin_names) do
    local r = where.replaced_config(plugins[name])
    if r then
      replaced = replaced + 1
      -- Often deliberate, so information rather than a warning; it is the
      -- fact a surprising behavior traces back to.
      h.info(("%s: your `config` (%s) replaces NoetherVim's (%s), so NoetherVim's does not run;"
        .. " `opts` changes settings and keeps it (:help noethervim-user-plugins)"):format(name, r.yours, r.distro))
    end
  end
  if replaced == 0 then h.ok("no `config` of yours replaces one of NoetherVim's") end
end

-- ── Stranded overrides ───────────────────────────────────────────────
local function stranded()
  -- An override in lua/user/plugins/ supplies `opts` and leaves the rest to
  -- the bundle it extends. Disable or rename that bundle and the override
  -- becomes the only spec for the plugin -- now with no `dependencies`, no
  -- lazy-load trigger and no `config`. lazy.nvim loads it during startup and
  -- runs its default `require(<main>).setup(opts)`, which fails on the first
  -- dependency the bundle used to declare.
  --
  -- The test is that combination, not "declared only here": a new plugin
  -- added in lua/user/plugins/ is declared only there too, and is the normal
  -- way to add one. What marks a spec as stranded is that it configures a
  -- plugin without saying how to load it.
  h.start("Stranded overrides")
  do
    local util = require("noethervim.util")
    local lazy_ok, lazy_plugins = pcall(require, "lazy.core.config")
    local user_dir = vim.fn.stdpath("config") .. "/lua/user/plugins"
    local stranded = {}

    if lazy_ok then
      for name, files in pairs(require("noethervim.inspect.source").plugin_spec_files()) do
        local user_file, live_spec, dormant_bundle
        for _, path in ipairs(files) do
          if path:find(user_dir, 1, true) then
            user_file = path
          else
            -- Every bundle file on disk mentions its plugins whether or not
            -- init.lua imports it, so a shipped-but-disabled bundle is not a
            -- spec that runs. Name it: it is almost always the answer.
            local cat, leaf = path:match("/bundles/([^/]+)/([^/]+)%.lua$")
            if cat and not require("noethervim.health.bundles").active_set()[cat .. "." .. leaf] then
              dormant_bundle = cat .. "." .. leaf
            else
              live_spec = true
            end
          end
        end
        local p = lazy_plugins.plugins[name]
        if user_file and not live_spec and p
            and p.opts and not p.config and not p.dependencies
            and not (p.ft or p.cmd or p.event or p.keys) and p.lazy == false then
          stranded[#stranded + 1] =
            { name = name, file = user_file, bundle = dormant_bundle }
        end
      end
    end

    table.sort(stranded, function(a, b) return a.name < b.name end)
    if not lazy_ok then
      h.info("Skipped (lazy.nvim not initialised)")
    elseif #stranded == 0 then
      h.ok("No overrides left without a spec to extend")
    else
      for _, s in ipairs(stranded) do
        h.warn(("%s: %s sets `opts`, and nothing says how to load it"):format(
          s.name, vim.fn.fnamemodify(s.file, ":~")))
        if s.bundle then
          h.info(("The `%s` bundle declares it, and is not enabled. "):format(s.bundle)
            .. "Enable it in init.lua, or move its `dependencies`, `ft` and "
            .. "`config` into the override.")
        else
          h.info("Give the override the `dependencies`, `ft` and `config` the "
            .. "spec it used to extend supplied, or it loads at startup with none.")
        end
      end
    end
  end
end

-- ── Override conflicts ───────────────────────────────────────────────
local function conflicts()
  -- Diff the keymap snapshots (end of setup, and now) to surface
  -- every core mapping one of your files redefined. Informational only --
  -- redefining a core mapping is a supported pattern, not an error.
  h.start("Override conflicts")
  local nv = require("noethervim")
  if not nv._user_loaded then
    h.info("Skipped (user overrides disabled)")
  elseif not (nv._snapshots and nv._snapshots.keymaps_before) then
    h.info("Snapshots unavailable -- keymap diff cannot be computed")
  else
    local snap   = nv._snapshots_now()
    local before = snap.keymaps_before
    local after  = snap.keymaps_after
    local conflicts = {}
    local yours = require("noethervim.user_layer").is_yours
    for key, after_km in pairs(after) do
      local before_km = before[key]
      if before_km and before_km.desc ~= after_km.desc and yours(after_km.sid) then
        table.insert(conflicts, string.format("[%s] %s  '%s' -> '%s'",
          after_km.mode, after_km.lhs,
          before_km.desc ~= "" and before_km.desc or "(no desc)",
          after_km.desc  ~= "" and after_km.desc  or "(no desc)"))
      end
    end
    if #conflicts == 0 then
      h.ok("No core keymaps overridden by user")
    else
      table.sort(conflicts)
      h.info(("User overrides %d core keymap(s):"):format(#conflicts))
      for _, c in ipairs(conflicts) do h.info("  " .. c) end
    end
  end
end

-- ── Session / option drift ───────────────────────────────────────────
local function session_drift()
  -- Sessions saved while 'sessionoptions' contained `localoptions` can
  -- restore stale buffer-local values that override updated globals
  -- (e.g. spelllang stuck at "en_us" after the distro default moved to
  -- "en", or formatoptions frozen with `t` after the global rewrite).
  -- NoetherVim drops `localoptions` from the default `sessionoptions` to
  -- prevent new sessions from doing this, but pre-existing session files
  -- keep their stale state until re-saved.
  --
  -- We spot-check `spelllang` across loaded buffers: it is rarely set by
  -- ftplugins, so divergence from the global is a strong drift signal.
  -- formatoptions / textwidth are skipped because legitimate ftplugins
  -- routinely set them (python, lua, gitcommit, ...), which would drown
  -- the check in false positives.
  h.start("Session / option drift")
  do
    local global_sl = vim.go.spelllang
    local drift = {}
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf)
        and vim.bo[buf].buflisted
        and vim.bo[buf].buftype == ""
      then
        local local_sl = vim.bo[buf].spelllang
        if local_sl ~= "" and local_sl ~= global_sl then
          local name = vim.api.nvim_buf_get_name(buf)
          if name == "" then name = "[buffer " .. buf .. "]" end
          table.insert(drift, string.format(
            "  %s -- spelllang=%s (global=%s)",
            vim.fn.fnamemodify(name, ":~:."), local_sl, global_sl))
        end
      end
    end
    if #drift == 0 then
      h.ok("No spelllang drift across loaded buffers")
    else
      h.warn(("%d buffer(s) have spelllang differing from global -- "
        .. "likely a stale session restoring `localoptions`:"):format(#drift))
      for _, line in ipairs(drift) do h.info(line) end
      h.info("Fix: save the session again, or delete the stale session file under "
        .. vim.fn.stdpath("state") .. "/sessions/")
    end
  end
end

local M = {}

function M.check()
  overrides()
  drift()
  plugin_configs()
  stranded()
  conflicts()
  session_drift()
end

return M
