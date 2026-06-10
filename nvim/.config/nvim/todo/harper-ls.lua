-- https://writewithharper.com/docs/integrations/neovim

return {
	cmd = { "harper-ls", "--stdio" }, -- 或者使用完整路径
	filetypes = { "markdown", "text", "tex", "rust", "lua", "python", "javascript", "typescript" },
	root_markers = { ".git" },
	single_file_support = true,
	settings = {
		["harper-ls"] = {
			userDictPath = "",
			workspaceDictPath = "",
			fileDictPath = "",
			linters = {
				SpellCheck = true,
				SpelledNumbers = false,
				AnA = true,
				SentenceCapitalization = true,
				UnclosedQuotes = true,
				WrongQuotes = false,
				LongSentences = true,
				RepeatedWords = true,
				Spaces = true,
				Matcher = true,
				CorrectNumberSuffix = true,
			},
			codeActions = {
				ForceStable = false,
			},
			markdown = {
				IgnoreLinkTitle = false,
			},
			diagnosticSeverity = "hint",
			isolateEnglish = false,
			dialect = "American",
			maxFileLength = 120000,
			ignoredLintsPath = "",
			excludePatterns = {},
		},
	},
}
