-- https://github.com/MunifTanjim/nougat.nvim/blame/main/examples/slanty.lua

return {
	"MunifTanjim/nougat.nvim",
	event = "VeryLazy",
	config = function()
		-- 导入必要的库
		local nougat = require("nougat") -- 引入 nougat 库
		local core = require("nougat.core") -- 引入 nougat 核心库
		local Bar = require("nougat.bar") -- 引入 Bar 类
		local Item = require("nougat.item") -- 引入 Item 类
		local sep = require("nougat.separator") -- 引入分隔符模块
		local nut = { -- nut 对象，包含了不同类型的信息处理模块
			buf = { -- 缓冲区相关模块
				diagnostic_count = require("nougat.nut.buf.diagnostic_count").create, -- 创建诊断计数器模块
				filename = require("nougat.nut.buf.filename").create, -- 创建文件名模块
				filestatus = require("nougat.nut.buf.filestatus").create, -- 创建文件状态模块
				filetype = require("nougat.nut.buf.filetype").create, -- 创建文件类型模块
			},
			git = { -- Git 相关模块
				branch = require("nougat.nut.git.branch").create, -- 创建分支模块
				status = require("nougat.nut.git.status"), -- Git 状态模块
			},
			tab = { -- 标签页相关模块
				tablist = { -- 标签页列表模块
					tabs = require("nougat.nut.tab.tablist").create, -- 创建标签页列表模块
					close = require("nougat.nut.tab.tablist.close").create, -- 创建标签页关闭按钮模块
					icon = require("nougat.nut.tab.tablist.icon").create, -- 创建标签页图标模块
					label = require("nougat.nut.tab.tablist.label").create, -- 创建标签页标签模块
					modified = require("nougat.nut.tab.tablist.modified").create, -- 创建标签页修改标识模块
				},
			},
			mode = require("nougat.nut.mode").create, -- 创建模式模块
			spacer = require("nougat.nut.spacer").create, -- 创建间隔模块
			truncation_point = require("nougat.nut.truncation_point").create, -- 创建截断点模块
		}

		-- 获取颜色配置
		local color = require("nougat.color").get() -- 获取颜色配置

		-- 设置模式
		local mode = nut.mode({ -- 创建模式对象
			prefix = " ", -- 前缀
			suffix = " ", -- 后缀
			sep_right = sep.right_chevron_solid(true), -- 右侧分隔符
		})

		-- 设置状态栏
		local stl = Bar("statusline") -- 创建状态栏对象
		stl:add_item(mode) -- 添加模式
		stl:add_item(nut.git.branch({ -- 添加 Git 分支信息
			hl = { bg = color.magenta, fg = color.bg }, -- 高亮配置
			prefix = "  ", -- 前缀
			suffix = " ", -- 后缀
			sep_right = sep.right_chevron_solid(true), -- 右侧分隔符
		}))
		stl:add_item(nut.git.status.create({ -- 添加 Git 状态信息
			hl = { bg = color.bg1 }, -- 高亮配置
			content = { -- 内容
				nut.git.status.count("added", { -- 添加已添加文件数
					hl = { fg = color.green }, -- 高亮配置
					prefix = " +", -- 前缀
				}),
				nut.git.status.count("changed", { -- 添加已更改文件数
					hl = { fg = color.blue }, -- 高亮配置
					prefix = " ~", -- 前缀
				}),
				nut.git.status.count("removed", { -- 添加已删除文件数
					hl = { fg = color.red }, -- 高亮配置
					prefix = " -", -- 前缀
				}),
			},
			suffix = " ", -- 后缀
			sep_right = sep.right_chevron_solid(true), -- 右侧分隔符
		}))
		local filename = stl:add_item(nut.buf.filename({ -- 添加文件名模块
			hl = { bg = color.bg3 }, -- 高亮配置
			prefix = " ", -- 前缀
			suffix = " ", -- 后缀
		}))
		local filestatus = stl:add_item(nut.buf.filestatus({ -- 添加文件状态模块
			hl = { bg = color.bg3 }, -- 高亮配置
			suffix = " ", -- 后缀
			sep_right = sep.right_chevron_solid(true), -- 右侧分隔符
			config = { -- 配置
				modified = "󰏫", -- 修改标识
				nomodifiable = "󰏯", -- 不可编辑标识
				readonly = "", -- 只读标识
				sep = " ", -- 分隔符
			},
		}))
		stl:add_item(nut.spacer()) -- 添加间隔
		stl:add_item(nut.truncation_point()) -- 添加截断点
		stl:add_item(nut.buf.diagnostic_count({ -- 添加诊断计数器模块（错误）
			hidden = false, -- 是否隐藏
			hl = { bg = color.red, fg = color.bg }, -- 高亮配置
			sep_left = sep.left_chevron_solid(true), -- 左侧分隔符
			prefix = " ", -- 前缀
			suffix = " ", -- 后缀
			config = { -- 配置
				severity = vim.diagnostic.severity.ERROR, -- 错误级别
			},
		}))
		stl:add_item(nut.buf.diagnostic_count({ -- 添加诊断计数器模块（警告）
			hidden = false, -- 是否隐藏
			hl = { bg = color.yellow, fg = color.bg }, -- 高亮配置
			sep_left = sep.left_chevron_solid(true), -- 左侧分隔符
			prefix = " ", -- 前缀
			suffix = " ", -- 后缀
			config = { -- 配置
				severity = vim.diagnostic.severity.WARN, -- 警告级别
			},
		}))
		stl:add_item(nut.buf.diagnostic_count({ -- 添加诊断计数器模块（信息）
			hidden = false, -- 是否隐藏
			hl = { bg = color.blue, fg = color.bg }, -- 高亮配置
			sep_left = sep.left_chevron_solid(true), -- 左侧分隔符
			prefix = " ", -- 前缀
			suffix = " ", -- 后缀
			config = { -- 配置
				severity = vim.diagnostic.severity.INFO, -- 信息级别
			},
		}))
		stl:add_item(nut.buf.diagnostic_count({ -- 添加诊断计数器模块（提示）
			hl = { bg = color.green, fg = color.bg }, -- 高亮配置
			sep_left = sep.left_chevron_solid(true), -- 左侧分隔符
			prefix = " ", -- 前缀
			suffix = " ", -- 后缀
			config = { -- 配置
				severity = vim.diagnostic.severity.HINT, -- 提示级别
			},
		}))
		stl:add_item(nut.buf.filetype({ -- 添加文件类型模块
			hl = { bg = color.bg1 }, -- 高亮配置
			sep_left = sep.left_chevron_solid(true), -- 左侧分隔符
			prefix = " ", -- 前缀
			suffix = " ", -- 后缀
		}))
		stl:add_item(Item({ -- 添加自定义项
			hl = { bg = color.bg2, fg = color.blue }, -- 高亮配置
			sep_left = sep.left_chevron_solid(true), -- 左侧分隔符
			prefix = "  ", -- 前缀
			content = core.group({ -- 内容
				core.code("l"), -- 当前行
				":", -- 冒号
				core.code("c"), -- 当前列
			}),
			suffix = " ", -- 后缀
		}))
		stl:add_item(Item({ -- 添加自定义项
			hl = { bg = color.blue, fg = color.bg }, -- 高亮配置
			sep_left = sep.left_chevron_solid(true), -- 左侧分隔符
			prefix = " ", -- 前缀
			content = core.code("P"), -- 当前页码
			suffix = " ", -- 后缀
		}))

		local stl_inactive = Bar("statusline") -- 创建非活动状态栏对象
		stl_inactive:add_item(mode) -- 添加模式
		stl_inactive:add_item(filename) -- 添加文件名
		stl_inactive:add_item(filestatus) -- 添加文件状态
		stl_inactive:add_item(nut.spacer()) -- 添加间隔

		-- 设置状态栏
		nougat.set_statusline(function(ctx)
			return ctx.is_focused and stl or stl_inactive -- 根据焦点状态返回相应的状态栏对象
		end)

		local tal = Bar("tabline") -- 创建标签栏对象

		tal:add_item(nut.tab.tablist.tabs({ -- 添加标签页列表
			active_tab = { -- 活动标签页
				hl = { bg = color.bg, fg = color.blue }, -- 高亮配置
				prefix = " ", -- 前缀
				suffix = " ", -- 后缀
				content = { -- 内容
					nut.tab.tablist.icon({ suffix = " " }), -- 标签页图标
					nut.tab.tablist.label({}), -- 标签页标签
					nut.tab.tablist.modified({ prefix = " ", config = { text = "●" } }), -- 标签页修改标识
					nut.tab.tablist.close({ prefix = " ", config = { text = "󰅖" } }), -- 标签页关闭按钮
				},
				sep_right = sep.right_chevron_solid(true), -- 右侧分隔符
			},
			inactive_tab = { -- 非活动标签页
				hl = { bg = color.bg2, fg = color.fg2 }, -- 高亮配置
				prefix = " ", -- 前缀
				suffix = " ", -- 后缀
				content = { -- 内容
					nut.tab.tablist.icon({ suffix = " " }), -- 标签页图标
					nut.tab.tablist.label({}), -- 标签页标签
					nut.tab.tablist.modified({ prefix = " ", config = { text = "●" } }), -- 标签页修改标识
					nut.tab.tablist.close({ prefix = " ", config = { text = "󰅖" } }), -- 标签页关闭按钮
				},
				sep_right = sep.right_chevron_solid(true), -- 右侧分隔符
			},
		}))

		-- 设置标签栏
		nougat.set_tabline(tal)
	end,
}
