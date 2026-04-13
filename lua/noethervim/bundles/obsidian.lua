-- NoetherVim bundle: Obsidian
-- Enable with: { import = "noethervim.bundles.obsidian" }
--
-- Provides: obsidian.nvim — Obsidian vault integration.
-- Recommended: also enable the markdown bundle for rendering, preview,
--              tables, math, and image paste.
--
-- Vault path: configure via user.config module:
--   -- ~/.config/<appname>/lua/user/config.lua
--   return { obsidian_vault = "~/Documents/MyVault/" }
local SearchLeader = require("noethervim.util").search_leader

return {

  -- ── obsidian.nvim ─────────────────────────────────────────────────────────
  {
    "obsidian-nvim/obsidian.nvim",
    version = "*",
    ft = "markdown",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {
      obsidian_vault = "~/obsidian",
    },
    config = function(_, opts)
      local vault = opts.obsidian_vault or "~/obsidian/"

      require("obsidian").setup({
        legacy_commands = false,
        workspaces = {
          { name = "main", path = vault },
        },
        completion = { nvim_cmp = false, blink = true, create_new = true },
        picker = {
          name = "telescope.nvim",
          note_mappings  = { new = "<c-n>", insert_link = "<C-l>" },
          tag_mappings   = { tag_note = "<C-x>", insert_tag = "<C-l>" },
        },
        note_id_func = function(title)
          if title ~= nil then
            return title:gsub(" ", "_"):lower()
          end
          local suffix = ""
          for _ = 1, 4 do
            suffix = suffix .. string.char(math.random(65, 90))
          end
          return tostring(os.time()) .. "-" .. suffix
        end,
        templates = {
          folder = "templates",
          date_format = "%Y-%m-%d-%a",
          time_format = "%H:%M",
        },
        checkbox = {
          order = {
            [" "] = { char = "󰄱", hl_group = "ObsidianTodo"       },
            ["x"] = { char = "",  hl_group = "ObsidianDone"       },
            [">"] = { char = "",  hl_group = "ObsidianRightArrow" },
            ["~"] = { char = "󰰱", hl_group = "ObsidianTilde"      },
            ["!"] = { char = "",  hl_group = "ObsidianImportant"  },
          },
        },
        ui = {
          enable = false,
          ignore_conceal_warn = false,
          update_debounce = 200,
          max_file_length = 5000,
          bullets             = { char = "•",  hl_group = "ObsidianBullet"        },
          external_link_icon  = { char = "",   hl_group = "ObsidianExtLinkIcon"   },
          reference_text      = { hl_group = "ObsidianRefText"                    },
          highlight_text      = { hl_group = "ObsidianHighlightText"              },
          tags                = { hl_group = "ObsidianTag"                        },
          block_ids           = { hl_group = "ObsidianBlockID"                    },
          hl_groups = {
            ObsidianTodo          = { bold = true, fg = "#f78c6c" },
            ObsidianDone          = { bold = true, fg = "#89ddff" },
            ObsidianRightArrow    = { bold = true, fg = "#f78c6c" },
            ObsidianTilde         = { bold = true, fg = "#ff5370" },
            ObsidianImportant     = { bold = true, fg = "#d73128" },
            ObsidianBullet        = { bold = true, fg = "#89ddff" },
            ObsidianRefText       = { underline = true, fg = "#c792ea" },
            ObsidianExtLinkIcon   = { fg = "#c792ea" },
            ObsidianTag           = { italic = true, fg = "#89ddff" },
            ObsidianBlockID       = { italic = true, fg = "#89ddff" },
            ObsidianHighlightText = { bg = "#75662e" },
          },
        },
      })

      -- follow link: jump directly if one link in buffer, else show picker
      local AsyncExecutor = require("obsidian.async").AsyncExecutor
      local log    = require("obsidian.log")
      local search = require("obsidian.search")
      local iter   = vim.iter
      local util   = require("obsidian.util")
      local channel = require("plenary.async.control").channel

      local function default_to_first_link(client)
        local links = {}
        for lnum, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, true)) do
          for match in iter(search.find_refs(line, { include_naked_urls = true, include_file_urls = true })) do
            local m_start, m_end = unpack(match)
            local link = string.sub(line, m_start, m_end)
            if not links[link] then links[link] = lnum end
          end
        end
        local link_keys = vim.tbl_keys(links)
        if #link_keys == 0 then log.err "No links found in buffer"; return end
        if #link_keys == 1 then
          local single_link = link_keys[1]
          client:resolve_link_async(single_link, function(...)
            for res in iter { ... } do
              local icon, icon_hl
              if res.url ~= nil then icon, icon_hl = util.get_icon(res.url) end
              client:follow_link_async({ value = single_link, display = res.name,
                filename = res.path and tostring(res.path) or nil,
                icon = icon, icon_hl = icon_hl, lnum = res.line, col = res.col })
              break
            end
          end)
          return
        end
        local picker = client:picker()
        if not picker then log.err "No picker configured"; return end
        local executor = AsyncExecutor.new()
        executor:map(function(link)
          local tx, rx = channel.oneshot()
          local entries = {}
          client:resolve_link_async(link, function(...)
            for res in iter { ... } do
              local icon, icon_hl
              if res.url ~= nil then icon, icon_hl = util.get_icon(res.url) end
              table.insert(entries, { value = link, display = res.name,
                filename = res.path and tostring(res.path) or nil,
                icon = icon, icon_hl = icon_hl, lnum = res.line, col = res.col })
            end
            tx()
          end)
          rx()
          return unpack(entries)
        end, link_keys, function(results)
          vim.schedule(function()
            local entries = {}
            for res in iter(results) do for r in iter(res) do entries[#entries + 1] = r end end
            table.sort(entries, function(a, b) return links[a.value] < links[b.value] end)
            picker:pick(entries, { prompt_title = "Links",
              callback = function(link) client:follow_link_async(link) end })
          end)
        end)
      end

      local client = require("obsidian").get_client()
      vim.keymap.set("n", "<leader>ol", function() default_to_first_link(client) end, { buffer = 0, desc = "follow link" })
      vim.keymap.set("i", "<c-s>", "<c-o>:Obsidian quick_switch<cr>", { buffer = 0 })
      vim.keymap.set("n", SearchLeader .. "oq", "<cmd>Obsidian quick_switch<cr>", { buffer = 0, desc = "obsidian quick switch" })
    end,
  },
}
