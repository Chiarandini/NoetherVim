-- Bundle-specific statusline components (VimTeX, PDF size, Overseer, DAP).
-- These components have condition guards so they only render when their
-- respective bundles are active.

local ctx = require("noethervim.plugins.statusline.context")
local icons = require("noethervim.util.icons")
local utils = require("heirline.utils")

local M = {}

-- DAP status
M.DAPMessages = {
  condition = function()
    local plugins = require("lazy.core.config").plugins
    local nvim_dap_plugin = plugins["nvim-dap"]

    if nvim_dap_plugin and nvim_dap_plugin._.loaded then
      local session = require("dap").session()
      return session ~= nil
    end
    return false
  end,
  provider = function()
    return "  " .. require("dap").status() .. " "
  end,
  hl = function() return utils.get_highlight("Debug") end,
}

-- Passive vimtex error count, cached per quickfix list generation.
--
-- Never call vimtex#qf#inquire from statusline code: it is not a query --
-- it re-parses the compile log and REBUILDS the quickfix list (~36
-- `setlocal errorformat` calls + `caddfile`) on every render.  That
-- storms OptionSet/FileType, which redraws plugins (treesitter-context
-- blink), which re-renders the statusline: a self-sustaining loop that
-- persists after the compiler stops, because status stays 3.  The
-- rebuild also aborts in statusline context (textlock), so the count
-- never rendered anyway.  vimtex's own compile callback already ran
-- inquire and filled the list; just read it.
local qf_cache = { id = -1, tick = -1, count = 0 }
local function vimtex_qf_error_count()
  local info = vim.fn.getqflist({ id = 0, changedtick = 1, title = 1 })
  if info.id == qf_cache.id and info.changedtick == qf_cache.tick then
    return qf_cache.count
  end
  local count = 0
  -- vimtex titles its list "VimTeX errors (...)"; ignore foreign lists.
  if (info.title or ""):find("VimTeX", 1, true) then
    for _, item in ipairs(vim.fn.getqflist()) do
      if item.valid == 1 then count = count + 1 end
    end
  end
  qf_cache = { id = info.id, tick = info.changedtick, count = count }
  return count
end

-- VimTeX compiler status.
--
-- Picks the most relevant vimtex state for the current buffer (handling
-- input-only files and subfile parent/child split via util.vimtex_status),
-- then renders the compile state with:
--   • a label when both parent and subfile states are visible
--   • a rough percent based on the cached last-successful PDF size
--   • qf error count after failure
--   • a small ↻ marker when continuous mode (`-pvc`) is active
-- The post-success "compiled in N.Ns" notification goes through fidget
-- (see bundles/languages/latex.lua); the statusline shows a persistent
-- "compiled ✓" until the next compile starts.
M.VimtexCompilerStatus = {
  -- heirline calls condition BEFORE init (statusline.lua:317 vs :340), so
  -- the lookup has to happen in condition or hl/provider see a stale
  -- self.pick from the previous render (or nil on the first render and
  -- the component is silently skipped forever).
  condition = function(self)
    local ok, vstatus = pcall(require, "noethervim.util.vimtex_status")
    if not ok then return false end
    self.vstatus = vstatus
    self.pick    = vstatus.pick(0)
    return self.pick ~= nil
  end,
  flexible = ctx.priority.max,
  hl = function(self)
    local status = tonumber(self.pick.state.compiler and self.pick.state.compiler.status) or 0
    if status == 1 then return { fg = ctx.colors.orange }
    elseif status == 2 then return { fg = ctx.colors.light_green }
    elseif status == 3 then return { fg = ctx.colors.light_red }
    end
    return { fg = ctx.colors.text_gray }
  end,
  provider = function(self)
    local pick     = self.pick
    local state    = pick.state
    local compiler = state.compiler
    local status   = tonumber(compiler and compiler.status) or 0

    -- Role label: only render when both states exist (subfile project),
    -- so single-file documents don't get cluttered.
    local function role_tag()
      if pick.parent_compiling and pick.sub_compiling then return "[parent+sub] " end
      if pick.role == "parent"  then return "[parent] " end
      if pick.role == "sub"     then return "[subfile] " end
      return ""
    end

    local continuous = ""
    if compiler and tonumber(compiler.continuous) == 1 then
      continuous = " ↻"
    end

    if status == 1 then
      -- progress_label returns raw `%`; statusline syntax treats `%` as
      -- a directive prefix so we double it before handing it off.
      local label = self.vstatus.escape_percent(self.vstatus.progress_label(state))
      return role_tag() .. label .. " " .. icons.text .. continuous
    elseif status == 2 then
      return role_tag() .. "compiled " .. icons.checkmark .. continuous
    elseif status == 3 then
      local count = vimtex_qf_error_count()
      if count > 0 then
        return string.format("%scompile error (%d) %s%s", role_tag(), count, icons.error, continuous)
      end
      return role_tag() .. "compile error " .. icons.error .. continuous
    end
    return ""
  end,
}

-- PDF file size.
--
-- Resolves the PDF through the picked vimtex state (so it works in input
-- files and respects `out_dir` / custom `-jobname`).  Reports a "stale"
-- hint when the source tex is newer than the PDF and no compile is
-- running.
-- Filetypes where a PDF readout is meaningful.  Limiting to TeX-family
-- buffers prevents "no pdf" from leaking into python/lua/etc. just because
-- vim.g.heirline_pdfsize_show happens to be true (e.g. the toggle was
-- flipped on while editing a previous tex file).
local pdfsize_filetypes = {
  tex = true, latex = true, plaintex = true, bib = true,
  context = true, markdown = true, typst = true,
}

M.PdfFileSize = {
  condition = function(self)
    if not vim.g.heirline_pdfsize_show then return false end
    if not pdfsize_filetypes[vim.bo.filetype] then return false end
    local ok, vstatus = pcall(require, "noethervim.util.vimtex_status")
    self.vstatus = ok and vstatus or nil
    self.pick    = ok and vstatus.pick(0) or nil
    return true
  end,
  provider = function(self)
    local pdf
    if self.pick and self.vstatus then
      pdf = self.vstatus.pdf_path(self.pick.state)
    end
    if not pdf or pdf == "" then
      pdf = tostring(vim.fn.expand("%:p:r")) .. ".pdf"
    end
    local stat = vim.uv.fs_stat(pdf)
    if not stat or stat.size <= 0 then
      return "no pdf"
    end
    local size_kb = stat.size / 1024
    local size_str
    if size_kb >= 1024 then
      size_str = string.format("%.1f MB", size_kb / 1024)
    else
      size_str = string.format("%.0f KB", size_kb)
    end
    -- Stale hint: tex newer than pdf, no compile running.
    local stale = ""
    local status = self.pick
        and tonumber(self.pick.state.compiler and self.pick.state.compiler.status)
        or 0
    if status ~= 1 then
      local tex_path = self.pick and self.pick.state.tex
      local tex_stat = tex_path and vim.uv.fs_stat(tex_path)
      if tex_stat and tex_stat.mtime.sec > stat.mtime.sec then
        stale = " (stale)"
      end
    end
    return "pdf: " .. size_str .. stale
  end,
  hl = function() return { fg = ctx.colors.text_gray } end,
}

-- Overseer task status
M.Overseer = {
  condition = function()
    local ok, _ = pcall(require, "overseer")
    if ok then
      return true
    end
  end,
  init = function(self)
    self.overseer = require("overseer")
    self.tasks = self.overseer.task_list
    self.STATUS = self.overseer.constants.STATUS
  end,
  static = {
    symbols = {
      ["FAILURE"] = "  ",
      ["CANCELED"] = "  ",
      ["SUCCESS"] = "  ",
      ["RUNNING"] = " 省",
    },
    colors = {
      ["FAILURE"] = "red",
      ["CANCELED"] = "gray",
      ["SUCCESS"] = "green",
      ["RUNNING"] = "yellow",
    },
  },
  {
    condition = function(self)
      return #self.tasks.list_tasks() > 0
    end,
    {
      provider = function(self)
        local tasks_by_status =
            self.overseer.util.tbl_group_by(self.tasks.list_tasks({ unique = true }), "status")

        for _, status in ipairs(self.STATUS.values) do
          local status_tasks = tasks_by_status[status]
          if self.symbols[status] and status_tasks then
            self.color = self.colors[status]
            return self.symbols[status]
          end
        end
      end,
      hl = function(self)
        return { fg = self.color }
      end,
    },
  },
}

return M
