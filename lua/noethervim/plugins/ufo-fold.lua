-- NoetherVim plugin: Enhanced Folding (UFO)
-- Enhanced folding via nvim-ufo (LSP > treesitter > indent fallback).
-- L peeks folded lines or falls back to LSP hover.
-- zr/zm open/close folds by kind; zR/zM open/close all.

local function peekOrHover()
    local winid = require('ufo').peekFoldedLinesUnderCursor()
    if winid then
        local bufnr = vim.api.nvim_win_get_buf(winid)
        local keys = {'a', 'i', 'o', 'A', 'I', 'O', 'gd', 'gR'}
		for _, k in ipairs(keys) do
            vim.keymap.set('n', k, '<CR>' .. k, {noremap = false, buffer = bufnr})
        end
    else
        vim.lsp.buf.hover()
    end
end


return {
	{
		"kevinhwang91/nvim-ufo",
		keys = {
			{'zr', function() require('ufo').openFoldsExceptKinds() end},
			{'zm', function() require('ufo').closeFoldsWith() end},
			{'zR', function() require('ufo').openAllFolds() end},
			{'zM', function() require('ufo').closeAllFolds() end},
			{'L', peekOrHover},
		},
		dependencies = "kevinhwang91/promise-async",
		event = "BufReadPost",
		opts = {
			provider_selector = function(bufnr, filetype, buftype)
				local ftMap = {
					vim = 'indent',
					python = {'indent'},
					git = '',
					tex = {'lsp', 'indent'},
				}
				if ftMap[filetype] then return ftMap[filetype] end
				-- lsp → treesitter → indent fallback chain
				-- Must return a function (not call it) so ufo treats it as a custom provider.
				return function(bufnr2)
					local function handleFallbackException(err, providerName)
						if type(err) == 'string' and err:match('UfoFallbackException') then
							return require('ufo').getFolds(bufnr2, providerName)
						else
							return require('promise').reject(err)
						end
					end
					return require('ufo').getFolds(bufnr2, 'lsp'):catch(function(err)
						return handleFallbackException(err, 'treesitter')
					end):catch(function(err)
						return handleFallbackException(err, 'indent')
					end)
				end
			end,
			fold_virt_text_handler = function(virtText, lnum, endLnum, width, truncate)
				local newVirtText = {}
				local suffix = (' ' .. require('noethervim.util.icons').downleftarrow .. " %d "):format(endLnum - lnum)
				local sufWidth = vim.fn.strdisplaywidth(suffix)
				local targetWidth = width - sufWidth
				local curWidth = 0
				for _, chunk in ipairs(virtText) do
					local chunkText = chunk[1]
					local chunkWidth = vim.fn.strdisplaywidth(chunkText)
					if targetWidth > curWidth + chunkWidth then
						table.insert(newVirtText, chunk)
					else
						chunkText = truncate(chunkText, targetWidth - curWidth)
						local hlGroup = chunk[2]
						table.insert(newVirtText, { chunkText, hlGroup })
						chunkWidth = vim.fn.strdisplaywidth(chunkText)
						if curWidth + chunkWidth < targetWidth then
							suffix = suffix .. (" "):rep(targetWidth - curWidth - chunkWidth)
						end
						break
					end
					curWidth = curWidth + chunkWidth
				end
				table.insert(newVirtText, { suffix, "MoreMsg" })
				return newVirtText
			end,
		},
		config = function(_, opts)
			require('ufo').setup(opts)
		end,
	},
}
