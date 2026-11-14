-- https://github.com/Olical/conjure
--
-- 多语言 REPL 客户端：把当前 form / 选区 / 整个 buffer 送进一个常驻进程求值，
-- 结果既可以直接写成代码后面的虚拟文本（inline results），也可以看 log buffer。
-- 「form」的边界靠 tree-sitter（clojure / fennel / racket / scheme / julia …），
-- 没有 tree-sitter 的语言退化成「整段 / 整行」，所以 Rust 这类没有 form 概念的语言
-- 不适合它——那边继续用 <leader>rr（runnables + overseer，真实 cargo 环境）。
--
-- 键位：conjure 默认挂在 <localleader>，本配置里 <localleader> 是默认的 \，已经被
-- \s(保存) \t(翻译) \r(RustOwl) \m(markmap) \l(loclist) \q(quickfix) \c(crates)
-- 占着，混用会互相遮挡。这里整体搬到 <leader>v（未占用的前缀），保持 conjure
-- 自带的 e*(eval) / l*(log) / c*(connect) / g*(goto) 语义：
--   <leader>vee 求值当前 form     <leader>ver 求值外层 form
--   <leader>veb 求值整个 buffer   <leader>ves 求值选区
--   <leader>vef 求值整个文件      <leader>vet 把 buffer 当临时文件求值
--   <leader>vlv log 竖分屏        <leader>vlq 关闭 log
--   <leader>vcs 连接 REPL         <leader>vcq 断开
--   <leader>vgd 跳转定义          <leader>vK 查文档
--
-- 前缀必须在 plugin/conjure.lua 自动启动之前设好：conjure 没有 setup()，配置全靠
-- vim.g 全局变量，而 plugin/ 在我们 config 之前就被 source 了（init 阶段跑，见
-- lua/boot/pack.lua 的 run_init），所以前缀写在 init 里。
return {
	"Olical/conjure",
	init = function()
		vim.g["conjure#mapping#prefix"] = "<leader>v"
		-- 结果以虚拟文本写在求值行末尾，和 REPL 的交互式手感一致
		vim.g["conjure#eval#inline_results"] = true
		-- 默认的 doc_word 是裸 K（config 里写成 `{ "K" }` 表示「不加前缀，直接占这个键」），
		-- 会在 conjure 的 filetype（rust / sql / lua / python …）里抢掉 LSP 的 K（hover）。
		-- 挪到 <leader>vgK，和 def_word(vgd) 一起归在 g 组下。
		vim.g["conjure#mapping#doc_word"] = "gK"
		-- 默认 open_before_first_eval = true：client 一加载就把「started / Welcome to evcxr」
		-- 这类启动日志弹成右上角的 HUD 浮窗，并很快自动关闭——表现就是启动时闪一下。
		-- 关掉它，HUD 只在你第一次求值之后才出现。
		vim.g["conjure#log#hud#open_before_first_eval"] = false
	end,
}
