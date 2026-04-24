vim.lsp.config('texlab', {
	settings = {
		texlab = {
			chktex = {
				onOpenAndSave = true,
				onEdit = false,
				-- W1:  command terminated with space (false positive for custom arg-less commands like \qn)
				-- W3:  enclose parenthesis with {} (false positive for math-mode expressions)
				-- W24: delete space before \index{} (false positive for normal index placement)
				additionalArgs = { "-n1", "-n3", "-n24" },
			},
			build = {
				-- VimTeX owns compilation -- disable texlab's build-on-save
				onSave = false,
				forwardSearchAfter = false,
			},
			diagnostics = {
				-- "Undefined reference": all false positives in this setup --
				--   custom env labels (th:/pr:/df:/co:/ex:) are resolved via the .aux file after compilation,
				--   and cross-file chapter refs (cha:) live in other documents texlab cannot reach.
				-- "Unused label": labels defined by custom envs are rarely \ref'd inline.
				-- NOTE: texlab's message is the literal string only -- no label name appended.
				ignoredPatterns = {
					"Unused label",
					"Undefined reference",
				},
			},
		},
	},
})

vim.lsp.enable('texlab')
