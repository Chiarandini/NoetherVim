-- Markdown LSP. Provides completion for inline links [text](#heading), anchor
-- links (#heading), wiki-links [[note]] / [[#heading]], plus goto-definition,
-- find-references, rename, and broken-link diagnostics.
--
-- Cross-file completion needs a project root: an empty .marksman.toml at the
-- repo root, or a git repo. Single-file mode covers in-file references.

vim.lsp.config('marksman', {})

vim.lsp.enable('marksman')
