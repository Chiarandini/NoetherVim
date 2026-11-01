--- :NoetherVim bundles: every bundle, enabled or not, with <C-y>/<C-x> to
--- enable or disable one and <C-o> to override it.
---@diagnostic disable: undefined-doc-name

local Snacks = require("snacks")
local ui = require("noethervim.inspect.ui")
local effective_root = ui.effective_root
local confirm_readonly = ui.confirm_readonly
local hint_footer = ui.hint_footer

local M = {}

-- ── Bundle catalog ──────────────────────────────────────────────
-- Bundle descriptions come from each bundle file's `@desc` annotation, via
-- util.bundle_meta. The filesystem layout (bundles/<category>/<name>.lua)
-- remains authoritative for which bundles exist and their category.
--
-- Parsed rather than listed here so there is one authored copy: the same
-- annotation feeds :checkhealth and the docs site. A bundle whose header
-- lacks @desc shows "(no description)".

-- Display order and readable labels for filesystem category names. Any
-- category present on disk but missing from bundle_meta.CATEGORIES renders
-- as its raw name at the end of the list.
local cat_order, cat_label = {}, {}
for i, cat in ipairs(require("noethervim.catalog.meta").CATEGORIES) do
  cat_order[cat.key], cat_label[cat.key] = i, cat.short
end

function M.bundles()
  local root = effective_root()
  if not root then return vim.notify("NoetherVim: cannot locate source directory", vim.log.levels.ERROR) end

  -- Detect which bundles are enabled via lazy.nvim's imported modules.
  -- Import keys look like "noethervim.bundles.<category>.<name>"; key on
  -- "<category>.<name>" so same-named bundles in two categories stay apart.
  local enabled = {}
  local ok, lazy_cfg = pcall(require, "lazy.core.config")
  if ok and lazy_cfg.spec then
    for _, mod in ipairs(lazy_cfg.spec.modules) do
      local key = mod:match("^noethervim%.bundles%.(.+)$")
      if key then enabled[key] = true end
    end
  end

  local icons = require("noethervim.util.icons")
  local bundle_meta = require("noethervim.catalog.meta")
  local items = {}
  for _, meta in ipairs(bundle_meta.scan(root .. "/lua/noethervim/bundles")) do
    local entry = { name = meta.name, category = meta.category, path = meta.path }
    local is_enabled = enabled[entry.category .. "." .. entry.name] or false
    local desc = meta.desc or "(no description)"
    local label = cat_label[entry.category] or entry.category
    table.insert(items, {
      text = label .. " " .. entry.name .. " " .. desc .. (is_enabled and " enabled" or ""),
      file = entry.path,
      cat_order = cat_order[entry.category] or 99,
      cat_text = "[" .. label .. "]",
      bundle_name = entry.name,
      category = entry.category,
      desc = desc,
      enabled = is_enabled,
    })
  end

  table.sort(items, function(a, b)
    if a.cat_order ~= b.cat_order then return a.cat_order < b.cat_order end
    return a.bundle_name < b.bundle_name
  end)

  Snacks.picker({
    title   = "NoetherVim Bundles",
    items   = items,
    preview = "file",
    confirm = confirm_readonly,
    format  = function(item)
      local ret = {} ---@type snacks.picker.Highlight[]
      ret[#ret + 1] = { string.format("%-14s", item.cat_text), "SnacksPickerLabel" }
      ret[#ret + 1] = { string.format("%-18s", item.bundle_name) }
      if item.enabled then
        ret[#ret + 1] = { icons.checkmark .. " ", "DiagnosticOk" }
      else
        ret[#ret + 1] = { "  " }
      end
      ret[#ret + 1] = { item.desc, "Comment" }
      return ret
    end,
    actions = {
      enable_bundle = function(picker)
        local item = picker:current()
        if not item or not item.bundle_name or not item.category then return end
        picker:close()
        require("noethervim.catalog.toggle").enable(item.category, item.bundle_name)
      end,
      disable_bundle = function(picker)
        local item = picker:current()
        if not item or not item.bundle_name or not item.category then return end
        picker:close()
        require("noethervim.catalog.toggle").disable(item.category, item.bundle_name)
      end,
      -- Seeding an override is the step that follows reading a bundle, so the
      -- affordance belongs where that decision gets made. `:NoetherVim
      -- override` maps from the current buffer, hence the edit first.
      override_bundle = function(picker)
        local item = picker:current()
        if not item or not item.file then return end
        picker:close()
        vim.cmd("edit " .. vim.fn.fnameescape(item.file))
        require("noethervim.inspect.override").override()
      end,
    },
    win = {
      input = {
        footer     = hint_footer({ { "<cr>", "open" }, { "<c-o>", "override" }, { "<c-y>", "enable" } }),
        footer_pos = "center",
        keys = {
          ["<CR>"]  = { "confirm",         mode = { "i", "n" }, desc = "open bundle source (readonly)" },
          ["<C-y>"] = { "enable_bundle",   mode = { "i", "n" }, desc = "enable bundle"  },
          ["<C-x>"] = { "disable_bundle",  mode = { "i", "n" }, desc = "disable bundle" },
          ["<C-o>"] = { "override_bundle", mode = { "i", "n" }, desc = "seed a user override for this bundle" },
        },
      },
      list = {
        keys = {
          ["<CR>"]  = { "confirm",         desc = "open bundle source (readonly)" },
          ["<C-y>"] = { "enable_bundle",   desc = "enable bundle"  },
          ["<C-x>"] = { "disable_bundle",  desc = "disable bundle" },
          ["<C-o>"] = { "override_bundle", desc = "seed a user override for this bundle" },
        },
      },
    },
  })
end

return M
