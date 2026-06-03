// ─── Entry point cho Render / Production ────────────────────────────────
// Map các tên ENV phổ biến sang tên mà bot đang dùng (giữ tương thích).
if (process.env.BOT_TOKEN && !process.env.TELEGRAM_BOT_TOKEN) {
  process.env.TELEGRAM_BOT_TOKEN = process.env.BOT_TOKEN;
}
if (process.env.TELEGRAM_TOKEN && !process.env.TELEGRAM_BOT_TOKEN) {
  process.env.TELEGRAM_BOT_TOKEN = process.env.TELEGRAM_TOKEN;
}
if (process.env.ADMIN_ID && !process.env.ADMIN_IDS) {
  process.env.ADMIN_IDS = process.env.ADMIN_ID;
}

import http from "http";
import { startBot } from "./bot";
import { logger } from "./lib/logger";

// ── Chống crash 24/7 ────────────────────────────────────────────────────
process.on("uncaughtException", (err) => {
  logger.error({ err: String(err) }, "uncaughtException");
});
process.on("unhandledRejection", (reason) => {
  logger.error({ reason: String(reason) }, "unhandledRejection");
});

const token = process.env.TELEGRAM_BOT_TOKEN ?? process.env.BOT_TOKEN;
if (!token) {
  logger.error(
    "❌ Thiếu biến môi trường BOT_TOKEN. Hãy đặt trong Render → Environment rồi redeploy."
  );
  process.exit(1);
}

const bot = startBot();
if (!bot) {
  logger.error("Bot không khởi động được.");
  process.exit(1);
}

logger.info("🚀 Bot đang chạy 24/7 bằng polling…");

// ── HTTP health-check server (BẮT BUỘC cho Render web service) ──────────
// Render scan port từ biến PORT. Nếu không bind, service sẽ bị mark "failed".
const PORT = Number(process.env.PORT) || 3000;
const server = http.createServer((req, res) => {
  if (req.url === "/healthz" || req.url === "/" || req.url === "/health") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ ok: true, bot: "HQ88", uptime: process.uptime() }));
    return;
  }
  res.writeHead(404, { "Content-Type": "text/plain" });
  res.end("Not Found");
});
server.listen(PORT, "0.0.0.0", () => {
  logger.info(`🌐 Health-check HTTP server listening on :${PORT}`);
});

// ── Graceful shutdown ───────────────────────────────────────────────────
function shutdown(signal: string) {
  logger.info(`Nhận tín hiệu ${signal}, dừng bot…`);
  try { bot?.stopPolling(); } catch {}
  try { server.close(); } catch {}
  process.exit(0);
}
process.on("SIGINT", () => shutdown("SIGINT"));
process.on("SIGTERM", () => shutdown("SIGTERM"));
