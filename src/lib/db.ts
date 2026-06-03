import Database from "better-sqlite3";
import fs from "fs";
import path from "path";
import { logger } from "./logger";

// Đường dẫn DB: ưu tiên ENV DB_PATH, mặc định ./data/bot.sqlite
const DB_PATH = process.env.DB_PATH || path.join(process.cwd(), "data", "bot.sqlite");

// Tự tạo thư mục chứa DB nếu chưa có (không crash khi thiếu)
try {
  const dir = path.dirname(DB_PATH);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
    logger.info(`Đã tạo thư mục DB: ${dir}`);
  }
} catch (e) {
  logger.warn("Không tạo được thư mục DB, sẽ thử dùng /tmp", e);
}

let _db: Database.Database;
try {
  _db = new Database(DB_PATH);
} catch (e) {
  // Fallback: nếu volume read-only thì rớt về /tmp
  logger.warn(`Không mở được DB tại ${DB_PATH}, fallback /tmp/bot.sqlite`, e);
  _db = new Database("/tmp/bot.sqlite");
}

_db.pragma("journal_mode = WAL");
_db.pragma("synchronous = NORMAL");
_db.pragma("foreign_keys = ON");

logger.info(`SQLite sẵn sàng: ${DB_PATH}`);

export const db = _db;

// Đóng DB sạch sẽ khi thoát
function closeDb() {
  try { _db.close(); } catch {}
}
process.on("exit", closeDb);
process.on("SIGINT", closeDb);
process.on("SIGTERM", closeDb);
