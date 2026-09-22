-- https://codecompanion.olimorris.dev/installation

return {
	"olimorris/codecompanion.nvim",
	dependencies = {
		"ravitemer/mcphub.nvim",
		"franco-ruggeri/codecompanion-spinner.nvim",
	},
	config = function()
		require("codecompanion").setup({
			interactions = {
				chat = {
					adapter = {
						-- name = "piacp",
						name = "deepseek",
						model = "deepseek-v4-flash",
					},
					sessions = {
						enabled = true,
						autosave = true,
						continuous_save = true,
						save_dir = vim.fs.joinpath(vim.fn.stdpath("data"), "codecompanion", "sessions"),
					},
				},
				inline = {
					adapter = {
						name = "deepseek",
						-- model = "deepseek-v4-flash",
					},
				},
				cli = {
					agent = "pi",
					agents = {
						pi = {
							cmd = "pi",
							args = {},
							description = "pi coding agent",
						},
					},
				},
			},
			adapters = {
				http = {
					opts = {
						show_presets = true,
						show_model_choices = true,
					},
					deepseek = function()
						return require("codecompanion.adapters").extend("deepseek", {
							name = "deepseek",
							env = {
								api_key = function()
									return os.getenv("DEEPSEEK_API_KEY")
								end,
							},
							schema = {
								model = {
									default = "deepseek-v4-flash",
								},
							},
						})
					end,
				},
				acp = {
					piacp = function()
						local helpers = require("codecompanion.adapters.acp.helpers")
						return {
							name = "piacp",
							formatted_name = "pi coding agent",
							type = "acp",
							roles = {
								llm = "assistant",
								user = "user",
							},
							commands = {
								default = {
									"npx",
									"-y",
									"pi-acp",
								},
							},
							defaults = {
								mcpServers = {},
								timeout = 20000,
							},
							parameters = {
								protocolVersion = 1,
								clientCapabilities = {
									fs = { readTextFile = true, writeTextFile = true },
								},
								clientInfo = {
									name = "CodeCompanion.nvim",
									version = "1.0.0",
								},
							},
							handlers = {
								setup = function(self)
									return true
								end,
								auth = function(self)
									return true
								end,
								form_messages = function(self, messages, capabilities)
									return helpers.form_messages(self, messages, capabilities)
								end,
								on_exit = function(self, code) end,
							},
						}
					end,
				},
			},
			extensions = {
				spinner = {},
				mcphub = {
					callback = "mcphub.extensions.codecompanion",
					opts = {
						make_vars = true,
						make_slash_commands = true,
						show_result_in_chat = true,
					},
				},
			},
			display = {
				diff = {
					enabled = true,

					-- At or below this diff size, always display the diff in the chat buffer
					threshold_for_chat = 6,

					word_highlights = {
						additions = true,
						deletions = true,
					},
				},
			},
			opts = { language = "Chinese" },
		})

		-- [C]odeCompanion [A]dd
		vim.keymap.set({ "n", "v" }, "<c-.>", function()
			require("codecompanion").toggle()
		end, { desc = "codecompanion toggle" })

		vim.keymap.set({ "n", "v" }, "<leader>ai", "<cmd>CodeCompanionCLI Ask<cr>", { noremap = true, silent = true })

		vim.keymap.set(
			{ "n", "v" },
			"<Leader>ac",
			"<cmd>CodeCompanionChat Toggle<cr>",
			{ noremap = true, silent = true }
		)

		vim.keymap.set({ "n", "v" }, "<Leader>aC", "<cmd>CodeCompanionCLI<cr>", { noremap = true, silent = true })

		vim.keymap.set(
			{ "n", "v" },
			"<Leader>ar",
			"<cmd>CodeCompanionCodeReview<cr>",
			{ noremap = true, silent = true }
		)

		vim.keymap.set("v", "ga", "<cmd>CodeCompanionChat Add<cr>", { noremap = true, silent = true })

		-- Expand 'cc' into 'CodeCompanion' in the command line
		vim.cmd([[cab cc CodeCompanion]])
	end,
}
