-- https://github.com/chrisgrieser/nvim-various-textobjs

return {
	"chrisgrieser/nvim-various-textobjs",
	event = "VeryLazy",
	opts = {
		keymaps = {
			useDefaults = true,
		},
	},
	config = function()
		-- default config
		require("various-textobjs").setup({
			keymaps = {
				-- See overview table in README for the defaults. (Note that lazy-loading
				-- this plugin, the default keymaps cannot be set up. If you set this to
				-- `true`, you thus need to add `lazy = false` to your lazy.nvim config.)
				useDefaults = false,

				-- disable only some default keymaps, for example { "ai", "!" }
				-- (only relevant when you set `useDefaults = true`)
				---@type string[]
				disabledDefaults = {},
			},

			forwardLooking = {
				-- Number of lines to seek forwards for a text object. See the overview
				-- table in the README for which text object uses which value.
				small = 5,
				big = 15,
			},
			behavior = {
				-- save position in jumplist when using text objects
				jumplist = true,
			},

			-- extra configuration for specific text objects
			textobjs = {
				indentation = {
					-- `false`: only indentation decreases delimit the text object
					-- `true`: indentation decreases as well as blank lines serve as delimiter
					blanksAreDelimiter = false,
				},
				subword = {
					-- When deleting the start of a camelCased word, the result should
					-- still be camelCased and not PascalCased (see #113).
					noCamelToPascalCase = true,
				},
				diagnostic = {
					wrap = true,
				},
				url = {
					patterns = { [[%l%l%l+://[^%s)%]}"'`>]+]] },
				},
			},

			notify = {
				icon = "󰠱", -- only used with notification plugins like `nvim-notify`
				whenObjectNotFound = true,
			},

			debug = false, -- debugging messages when using some text objects
		})
		vim.keymap.set("n", "gx", function()
			require("various-textobjs").url() -- select URL

			local foundURL = vim.fn.mode() == "v" -- only switches to visual mode when textobj found
			if not foundURL then
				return
			end

			local url = vim.fn.getregion(vim.fn.getpos("."), vim.fn.getpos("v"), { type = "v" })[1]
			vim.ui.open(url) -- requires nvim 0.10
			vim.cmd.normal({ "v", bang = true }) -- leave visual mode
		end, { desc = "URL Opener" })

		vim.keymap.set("n", "gf", function()
			require("various-textobjs").filepath("outer") -- select filepath

			local foundPath = vim.fn.mode() == "v" -- only switches to visual mode when textobj found
			if not foundPath then
				return
			end

			local path = vim.fn.getregion(vim.fn.getpos("."), vim.fn.getpos("v"), { type = "v" })[1]

			local exists = vim.uv.fs_stat(vim.fs.normalize(path)) ~= nil
			if exists then
				vim.ui.open(path)
			else
				vim.notify("Path does not exist.", vim.log.levels.WARN)
			end
		end, { desc = "URL Opener" })
	end,
}
