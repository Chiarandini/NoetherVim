--- The latex bundle's checks for :checkhealth noethervim: what its
--- `@requires` annotation cannot express. latexmk and pdflatex are covered
--- there; what is left is cross-platform PDF viewer discovery, and whether
--- the treesitter parser can actually be built.
---@param h table vim.health
return function(h)
  -- Silent unless VimTeX is in the spec (the latex bundle), so users without
  -- LaTeX get no noise about viewers and parsers.
  if not require("lazy.core.config").plugins["vimtex"] then return end

  h.start("LaTeX (languages.latex bundle)")

  -- PDF viewer detection. macOS apps live in /Applications and are not
  -- on PATH, so executable() always fails for them -- must fs_stat the
  -- .app bundle directly.
  if vim.fn.has("mac") == 1 then
    local mac_apps = { "Skim.app", "Preview.app" }
    local found
    for _, app in ipairs(mac_apps) do
      if vim.uv.fs_stat("/Applications/" .. app) then found = app; break end
    end
    if found then
      h.ok("PDF viewer (" .. found .. ")")
    else
      h.warn("no PDF viewer found in /Applications -- tried: " .. table.concat(mac_apps, ", "))
    end
  else
    local viewers
    if vim.fn.has("win32") == 1 then
      viewers = { "SumatraPDF", "SumatraPDF.exe" }
    else
      viewers = { "zathura", "okular", "sioyek", "evince" }
    end
    local found
    for _, viewer in ipairs(viewers) do
      if vim.fn.executable(viewer) == 1 then found = viewer; break end
    end
    if found then
      h.ok("PDF viewer (" .. found .. ")")
    else
      h.warn("no PDF viewer found -- tried: " .. table.concat(viewers, ", "))
    end
  end

  -- Treesitter latex parser: nvim-treesitter marks this parser as requiring
  -- tree-sitter generate, but NoetherVim overrides that so only a C compiler
  -- is needed. Check that cc is available and the parser is installed.
  if vim.fn.executable("cc") == 1 then
    h.ok("cc (C compiler -- required for :TSInstall latex)")
  else
    h.error("cc not found -- needed to compile the latex treesitter parser (:TSInstall latex)")
  end
  -- nvim-treesitter's main branch installs parsers to stdpath("data")/site/parser/,
  -- the master branch to lazy/nvim-treesitter/parser/. Use rtp lookup so the
  -- check works regardless of branch / install layout.
  if #vim.api.nvim_get_runtime_file("parser/latex.so", false) > 0 then
    h.ok("latex treesitter parser installed")
  else
    h.warn("latex treesitter parser not installed -- run :TSInstall latex")
  end
end
