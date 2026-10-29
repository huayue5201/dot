/**
 * Neovim Context Bridge (pi extension)
 *
 * 让 pi 读取"活着的 nvim"的上下文：未保存 buffer、光标位置、visual 选区、
 * LSP 诊断、quickfix。数据来自 nvim 侧的 lua/local/ai/pi_bridge.lua（dotfiles 里），
 * 它把 RPC socket 登记在 ~/.cache/nvim/pi-ctx/<pid>.json。
 *
 * 绑定实例：`/nvim-pin`（手动选）。未 pin 时若只有一个候选会自动绑定。
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { execFile } from "node:child_process";
import { mkdir, readdir, readFile, unlink, writeFile } from "node:fs/promises";
import * as net from "node:net";
import * as os from "node:os";
import * as path from "node:path";

type Instance = {
	pid: number;
	sock: string;
	cwd: string;
	name?: string;
	file?: string;
	ts: number;
};

const CACHE_ROOT = process.env.XDG_CACHE_HOME || path.join(os.homedir(), ".cache");
const REG_DIR = path.join(CACHE_ROOT, "nvim", "pi-ctx");
/** nvim 侧 lua/local/ai/init.lua 往里写问题；本扩展在此监听 */
const ASK_DIR = path.join(CACHE_ROOT, "pi-agent", "ask");
const PID = process.pid;
const ASK_SOCK = path.join(ASK_DIR, `${PID}.sock`);
const ASK_REG = path.join(ASK_DIR, `${PID}.json`);
/**
 * 这个 pi 是被 ACP/RPC 客户端（codecompanion 经 pi-acp 用 `pi --mode rpc` 拉起）托管的吗？
 * 是的话会话归那个客户端所有：往这里 sendUserMessage，回复只会流向它，
 * 不会出现在 nvim 里 —— 登记时标出来，让 nvim 侧默认跳过（backends/init.lua 的 avoid）。
 */
const EMBEDDED = process.argv.some((a, i, argv) => a === "--mode" && argv[i + 1] === "rpc");

type AskPayload = {
	/** nvim 侧已经渲染好的整条消息（新协议，优先使用） */
	text?: string;
	/** 旧协议：问题正文 + 锚点，由本扩展拼装 */
	prompt?: string;
	anchor?: {
		cwd?: string;
		tab?: number;
		path?: string;
		line?: number;
		col?: number;
		filetype?: string;
		modified?: boolean;
		visual?: { start_line: number; end_line: number; lines: string[] };
	};
};

/** nvim 发来的 {问题 + 锚点} 拼成一条用户消息 */
function renderAsk(payload: AskPayload): string {
	const a = payload.anchor ?? {};
	const question = (payload.prompt ?? "").trim();
	const head: string[] = [question || "(空问题)"];

	const where = [
		a.path ? `${a.path}:${a.line ?? 1}` : "<无文件名>",
		a.tab ? `tab ${a.tab}` : null,
		a.modified ? "未保存" : null,
	].filter(Boolean);

	head.push("", `<nvim-context ${where.join(" · ")}>`);
	if (a.cwd) head.push(`cwd: ${a.cwd}`);
	if (a.visual) {
		const fence = a.filetype && a.filetype !== "" ? a.filetype : "";
		head.push(`selection ${a.visual.start_line}-${a.visual.end_line}:`);
		head.push(`\`\`\`${fence}`);
		head.push(...(a.visual.lines ?? []));
		head.push("\`\`\`");
	}
	head.push("</nvim-context>");
	return head.join("\n");
}

async function instances(): Promise<Instance[]> {
	let names: string[];
	try {
		names = await readdir(REG_DIR);
	} catch {
		return [];
	}
	const out: Instance[] = [];
	for (const name of names) {
		if (!name.endsWith(".json")) continue;
		try {
			const entry = JSON.parse(await readFile(path.join(REG_DIR, name), "utf8"));
			if (typeof entry?.sock === "string") out.push(entry as Instance);
		} catch {
			// 半写入 / 残留文件，忽略
		}
	}
	return out.sort((a, b) => (b.ts ?? 0) - (a.ts ?? 0));
}

/** 调 nvim 侧 local.ai.pi_bridge.handle(base64(json))；socket 死了就抛错 */
function rpc<T = any>(sock: string, request: Record<string, unknown>): Promise<T> {
	const b64 = Buffer.from(JSON.stringify(request), "utf8").toString("base64");
	const expr = `v:lua.require("local.ai.pi_bridge").handle("${b64}")`;
	return new Promise<T>((resolve, reject) => {
		execFile(
			"nvim",
			["--server", sock, "--remote-expr", expr],
			{ timeout: 8000, maxBuffer: 32 * 1024 * 1024 },
			(err, stdout, stderr) => {
				if (err) {
					const msg = String(stderr || err.message || "").trim();
					reject(new Error(msg || "nvim rpc failed"));
					return;
				}
				try {
					resolve(JSON.parse(stdout.trim()) as T);
				} catch {
					reject(new Error(`unexpected nvim reply: ${stdout.slice(0, 300)}`));
				}
			},
		);
	});
}

function label(i: Instance): string {
	const f = i.file ? ` (${i.file})` : "";
	return `pid ${i.pid} · ${i.cwd}${f}`;
}

export default function nvimContextExtension(pi: ExtensionAPI) {
	let pinned: Instance | undefined;

	// ---- 反向通道：nvim 浮窗 (`<leader>aq`) 把「问题 + 锚点」发进来 ----
	let inbox: net.Server | undefined;
	let busy = false;

	async function handleAsk(line: string, socket: net.Socket): Promise<void> {
		let payload: AskPayload;
		try {
			payload = JSON.parse(line) as AskPayload;
		} catch {
			socket.write(JSON.stringify({ ok: false, error: "bad json" }) + "\n");
			return;
		}
		try {
			// 新协议：nvim 已渲染好整条消息；旧协议回落 renderAsk
			const text = typeof payload.text === "string" ? payload.text : renderAsk(payload);
			// busy 时当跟进消息排队，避免打断当前工具链
			await pi.sendUserMessage(text, busy ? { deliverAs: "followUp" } : undefined);
			socket.write(JSON.stringify({ ok: true }) + "\n");
		} catch (e) {
			socket.write(JSON.stringify({ ok: false, error: e instanceof Error ? e.message : String(e) }) + "\n");
		}
	}

	async function startInbox(): Promise<void> {
		await mkdir(ASK_DIR, { recursive: true });
		// 清理已死实例的登记文件
		for (const name of await readdir(ASK_DIR).catch(() => [] as string[])) {
			if (!name.endsWith(".json")) continue;
			const file = path.join(ASK_DIR, name);
			try {
				const entry = JSON.parse(await readFile(file, "utf8"));
				if (typeof entry?.pid === "number") process.kill(entry.pid, 0);
			} catch {
				await unlink(file).catch(() => {});
			}
		}
		await unlink(ASK_SOCK).catch(() => {});
		inbox = net.createServer((socket) => {
			let buffer = "";
			socket.setEncoding("utf8");
			socket.on("error", () => {});
			socket.on("data", (chunk: string) => {
				buffer += chunk;
				let idx: number;
				while ((idx = buffer.indexOf("\n")) >= 0) {
					const line = buffer.slice(0, idx);
					buffer = buffer.slice(idx + 1);
					if (line.trim()) void handleAsk(line, socket);
				}
			});
		});
		await new Promise<void>((resolve, reject) => {
			inbox!.once("error", reject);
			inbox!.listen(ASK_SOCK, () => resolve());
		});
		await writeFile(
			ASK_REG,
			JSON.stringify({
				pid: PID,
				sock: ASK_SOCK,
				cwd: process.cwd(),
				ts: Math.floor(Date.now() / 1000),
				embedded: EMBEDDED,
			}),
		);
	}

	async function stopInbox(): Promise<void> {
		inbox?.close();
		inbox = undefined;
		await unlink(ASK_REG).catch(() => {});
		await unlink(ASK_SOCK).catch(() => {});
	}

	pi.on("session_start", async () => {
		try {
			await startInbox();
		} catch (e) {
			// socket 起不来不该阻断 session
			console.error(`[nvim-context] inbox failed: ${e instanceof Error ? e.message : String(e)}`);
		}
	});
	pi.on("session_shutdown", async () => {
		await stopInbox();
	});
	pi.on("agent_start", () => {
		busy = true;
	});
	pi.on("agent_settled", () => {
		busy = false;
	});

	async function pickInteractive(ctx: any): Promise<Instance | undefined> {
		const list = await instances();
		if (list.length === 0) {
			ctx.ui.notify(`没有发现活着的 nvim（${REG_DIR} 为空）`, "warning");
			return undefined;
		}
		const items = list.map(label);
		const choice = await ctx.ui.select("选择 nvim 实例", items);
		if (!choice) return undefined;
		const idx = items.indexOf(choice);
		return idx >= 0 ? list[idx] : undefined;
	}

	/** 未 pin 时的兜底：cwd 匹配优先，多个歧义就报错 */
	async function resolve(): Promise<Instance | undefined> {
		if (pinned) return pinned;
		const list = await instances();
		const cwd = process.cwd();
		const exact = list.filter((i) => i.cwd === cwd);
		if (exact.length === 1) {
			pinned = exact[0];
			return pinned;
		}
		const related = list.filter((i) => cwd.startsWith(i.cwd) || i.cwd.startsWith(cwd));
		if (related.length === 1) {
			pinned = related[0];
			return pinned;
		}
		if (list.length === 1) {
			pinned = list[0];
			return pinned;
		}
		return undefined;
	}

	async function needInstance(): Promise<{ instance?: Instance; error?: string }> {
		const found = await resolve();
		if (found) return { instance: found };
		const list = await instances();
		if (list.length === 0) {
			return {
				error: `没有发现活着的 nvim 实例（登记目录 ${REG_DIR}）。请先在 nvim 里打开文件（启动时会自动开 RPC socket）。`,
			};
		}
		return {
			error: [
				"有多个 nvim 实例，无法确定读哪一个。请先用 /nvim-pin 选择：",
				...list.map((i) => `- ${label(i)}`),
			].join("\n"),
		};
	}

	function formatLines(lines: string[], from: number): string {
		const width = String(from + lines.length - 1).length;
		return lines
			.map((l, i) => `${String(from + i).padStart(width, " ")}  ${l}`)
			.join("\n");
	}

	const params = Type.Object({
		action: Type.Union(
			[
				Type.Literal("state"),
				Type.Literal("buffer"),
				Type.Literal("diagnostics"),
				Type.Literal("quickfix"),
				Type.Literal("list"),
			],
			{ description: "state=光标/选区/最近文件, buffer=代码内容, diagnostics=LSP, quickfix=列表, list=所有 nvim 实例" },
		),
		path: Type.Optional(Type.String({ description: "buffer 动作的文件路径（相对 nvim cwd 或绝对）；省略=当前 buffer" })),
		from: Type.Optional(Type.Number({ description: "buffer 动作起始行（1-based）" })),
		to: Type.Optional(Type.Number({ description: "buffer 动作结束行（含）" })),
	});

	pi.registerTool({
		name: "nvim",
		label: "Neovim Context",
		description:
			"Read context from the user's live Neovim instance: current cursor/visual selection, buffer contents (including unsaved changes), LSP diagnostics, and the quickfix list. Prefer this over read/bash when the user refers to what they are looking at in their editor.",
		promptSnippet: "Read the live Neovim editor state (unsaved buffers, cursor, visual selection, diagnostics, quickfix)",
		promptGuidelines: [
			"Call nvim with action=state first when the user says things like \"this function\", \"my selection\", \"what I'm looking at\" — it reveals the file, cursor line, and visual selection.",
		],
		parameters: params,
		async execute(_toolCallId, p) {
			if (p.action === "list") {
				const list = await instances();
				return {
					content: [
						{
							type: "text",
							text:
								list.length === 0
									? `没有发现活着的 nvim（${REG_DIR}）`
									: list.map((i) => `${pinned?.pid === i.pid ? "* " : "- "}${label(i)}`).join("\n"),
						},
					],
					details: { instances: list, pinned: pinned?.pid },
				};
			}

			const { instance, error } = await needInstance();
			if (!instance) {
				return { content: [{ type: "text", text: error! }], details: { error: error! }, isError: true };
			}

			const req: Record<string, unknown> = { action: p.action };
			if (p.path) req.path = p.path;
			if (p.from) req.from = p.from;
			if (p.to) req.to = p.to;

			let res: any;
			try {
				res = await rpc(instance.sock, req);
			} catch (e) {
				const msg = e instanceof Error ? e.message : String(e);
				if (pinned?.pid === instance.pid) pinned = undefined;
				return {
					content: [
						{
							type: "text",
							text: `nvim RPC 失败（${instance.sock}）：${msg}\n该实例可能已退出，或 nvim 侧没有加载 lua/local/ai/pi_bridge.lua。`,
						},
					],
					details: { error: msg },
					isError: true,
				};
			}

			if (res?.ok === false) {
				return { content: [{ type: "text", text: `nvim: ${res.error}` }], details: res, isError: true };
			}

			let text: string;
			if (p.action === "buffer") {
				const head = `${res.path}${res.modified ? " [未保存修改]" : ""} 行 ${res.from}-${res.to}/${res.total_lines ?? "?"}${
					res.truncated ? " (已截断)" : ""
				}`;
				text = `${head}\n${formatLines(res.lines ?? [], res.from ?? 1)}`;
			} else if (p.action === "state") {
				const bits: string[] = [];
				if (res.cwd && path.resolve(res.cwd) !== path.resolve(process.cwd())) {
					bits.push(
						`⚠️ nvim 当前项目 ${res.cwd} ≠ pi cwd ${process.cwd()} — 改文件请用绝对路径（或先向用户确认是哪个项目）`,
					);
				}
				bits.push(`cwd: ${res.cwd}`);
				bits.push(`file: ${res.path ?? "<none>"}${res.modified ? " [未保存]" : ""}`);
				bits.push(`cursor: ${res.cursor?.line}:${res.cursor?.col}  mode: ${res.mode}`);
				if (res.visual) {
					bits.push(`visual (${res.visual.kind}): ${res.visual.start_line}-${res.visual.end_line}`);
					bits.push(formatLines(res.visual.lines ?? [], res.visual.start_line));
				}
				bits.push(`diagnostics: ${res.diagnostic_count}`);
				if (res.quickfix?.size) bits.push(`quickfix: ${res.quickfix.size} 项${res.quickfix.title ? ` (${res.quickfix.title})` : ""}`);
				if (res.buffers?.length) {
					bits.push(`最近 buffer: ${res.buffers.map((b: any) => b.path).join(", ")}`);
				}
				if (res.tabs?.length > 1) {
					bits.push(
						"打开的 tab: " +
							res.tabs
								.map((t: any) => `${t.index}${t.active ? "*" : ""} ${t.cwd ?? "?"}${t.file ? ` (${t.file})` : ""}`)
								.join(" | "),
					);
				}
				text = bits.join("\n");
			} else if (p.action === "diagnostics") {
				if (res.clean) text = "没有诊断信息。";
				else
					text = res.files
						.map(
							(f: any) =>
								`${f.path}\n` +
								f.items
									.map((d: any) => `  ${d.line}:${d.col} ${d.severity} ${d.message}${d.source ? ` (${d.source})` : ""}`)
									.join("\n"),
						)
						.join("\n");
			} else {
				text = res.size
					? `${res.title || "quickfix"} (${res.size})\n` +
						res.items.map((i: any) => `${i.path ?? "<no file>"}:${i.line}:${i.col} ${i.text}`).join("\n")
					: "quickfix 为空。";
			}

			return { content: [{ type: "text", text }], details: { ...res, sock: instance.sock, pid: instance.pid } };
		},
	});

	pi.registerCommand("nvim-pin", {
		description: "绑定一个活着的 nvim 实例（不给参数时弹出选择列表）",
		handler: async (args, ctx) => {
			const query = (args ?? "").trim();
			const list = await instances();
			if (list.length === 0) {
				ctx.ui.notify(`没有发现活着的 nvim（${REG_DIR} 为空）`, "warning");
				return;
			}
			if (!query) {
				const picked = await pickInteractive(ctx);
				if (!picked) return;
				pinned = picked;
				ctx.ui.notify(`已绑定 ${label(picked)}`, "info");
				return;
			}
			const hit = list.find(
				(i) => String(i.pid) === query || i.cwd.includes(query) || (i.name ?? "").includes(query) || i.sock.includes(query),
			);
			if (!hit) {
				ctx.ui.notify(`没有匹配 "${query}" 的实例。候选：\n${list.map(label).join("\n")}`, "warning");
				return;
			}
			pinned = hit;
			ctx.ui.notify(`已绑定 ${label(hit)}`, "info");
		},
	});

	pi.registerCommand("nvim-status", {
		description: "查看当前绑定的 nvim 实例",
		handler: async (_args, ctx) => {
			const list = await instances();
			const head = pinned ? `已绑定: ${label(pinned)}` : "未绑定（只有一个候选时会自动绑定）";
			ctx.ui.notify([head, "", `可用实例 (${list.length}):`, ...list.map((i) => `- ${label(i)}`)].join("\n"), "info");
		},
	});
}
