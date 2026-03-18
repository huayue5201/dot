-- https://github.com/Punity122333/hexinspector.nvim

return {
	"Punity122333/hexinspector.nvim",
	cmd = { "HexEdit", "HexInspect" },
	keys = {
		{
			"<leader>zx",
			function()
				require("hexinspector").open()
			end,
			desc = "Hex Editor",
		},
		{
			"<leader>zX",
			function()
				vim.ui.input({ prompt = "File path: ", default = vim.fn.expand("%:p") }, function(input)
					if input and input ~= "" then
						require("hexinspector").open(input)
					end
				end)
			end,
			desc = "Hex Editor (Pick File)",
		},
	},
	config = function()
		require("hexinspector").setup({
			vertex_templates = {
				{
					name = "Pos+Tangent (28B)",
					stride = 28,
					fields = {
						{ name = "Pos", type = "float3", offset = 0 },
						{ name = "Tan", type = "float3", offset = 12 },
						{ name = "Sign", type = "float1", offset = 24 },
					},
				},
			},
		})
	end,
}
