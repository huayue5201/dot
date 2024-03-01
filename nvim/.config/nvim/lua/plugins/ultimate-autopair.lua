-- https://github.com/altermo/ultimate-autopair.nvim

return {
   "altermo/ultimate-autopair.nvim",
   event = { "InsertEnter", "CmdlineEnter" },
   config = function()
      require("ultimate-autopair").setup({
         bs = { -- *ultimate-autopair-map-backspace-config*
            enable = true,
            map = "<bs>", --string or table
            cmap = "<bs>", --string or table
            overjumps = true,
            --(|foo) > bs > |foo
            space = true, --false, true or 'balance'
            --( |foo ) > bs > (|foo)
            --balance:
            --  Will prioritize balanced spaces
            --  ( |foo  ) > bs > ( |foo )
            indent_ignore = true,
            --(\n\t|\n) > bs > (|)
            single_delete = true,
            -- <!--|--> > bs > <!-|
            conf = {},
            --contains extension config
            multi = false,
            --use multiple configs (|ultimate-autopair-map-multi-config|)
         },
         fastwarp = { -- *ultimate-autopair-map-fastwarp-config*
            enable = true,
            enable_normal = true,
            enable_reverse = true,
            hopout = false,
            --{(|)} > fastwarp > {(}|)
            map = "<A-e>", --string or table
            rmap = "<A-E>", --string or table
            cmap = "<A-e>", --string or table
            rcmap = "<A-E>", --string or table
            multiline = true,
            --(|) > fastwarp > (\n|)
            nocursormove = true,
            --makes the cursor not move (|)foo > fastwarp > (|foo)
            --disables multiline feature
            --only activates if prev char is start pair, otherwise fallback to normal
            do_nothing_if_fail = true,
            --add a module so that if fastwarp fails
            --then an `e` will not be inserted
            no_filter_nodes = { "string", "raw_string", "string_literals", "character_literal" },
            --which nodes to skip for tsnode filtering
            faster = false,
            --only enables jump over pair, goto end/next line
            --useful for the situation of:
            --{|}M.foo('bar') > {M.foo('bar')|}
            conf = {},
            --contains extension config
            multi = false,
            --use multiple configs (|ultimate-autopair-map-multi-config|)
         },
         close = { -- *ultimate-autopair-map-close-config*
            enable = true,
            map = "<A-)>", --string or table
            cmap = "<A-)>", --string or table
            conf = {},
            --contains extension config
            multi = false,
            --use multiple configs (|ultimate-autopair-map-multi-config|)
            do_nothing_if_fail = true,
            --add a module so that if close fails
            --then a `)` will not be inserted
         },
         space2 = { -- *ultimate-autopair-map-space2-config*
            enable = true,
            match = [[\k]],
            --what character activate
            conf = {},
            --contains extension config
            multi = false,
            --use multiple configs (|ultimate-autopair-map-multi-config|)
         },
         tabout = { -- 插入模式光标跳出符号
            enable = true,
            map = "<A-tab>", --string or table
            cmap = "<A-tab>", --string or table
            conf = {},
            --contains extension config
            multi = false,
            --use multiple configs (|ultimate-autopair-map-multi-config|)
            hopout = true,
            -- (|) > tabout > ()|
            do_nothing_if_fail = true,
            --add a module so that if close fails
            --then a `\t` will not be inserted
         },
      })
   end,
}
