// ─────────────────────────────────────────────────────────────────────────
// Worker chạy trong thread riêng. Mainthread dùng synckit để gọi sync.
// Giữ nguyên API kiểu better-sqlite3 (prepare/run/get/all + exec).
// ─────────────────────────────────────────────────────────────────────────
import { runAsWorker } from "synckit";
import { Pool, types } from "pg";
import fs from "fs";
import path from "path";

// Trả BIGINT về number (đủ cho mọi giá trị trong bot)
types.setTypeParser(20, (v: string | null) => (v == null ? null : parseInt(v, 10)) as any);
// NUMERIC về number
types.setTypeParser(1700, (v: string | null) => (v == null ? null : parseFloat(v)) as any);

const connectionString =
  process.env.DATABASE_URL ||
  process.env.POSTGRES_URL ||
  "";

if (!connectionString) {
  // Không throw ngay – để main thread nhận lỗi rõ ràng khi gọi
  console.error("[db.worker] Thiếu DATABASE_URL");
}

const needSsl =
  /sslmode=require/i.test(connectionString) ||
  process.env.PGSSL === "true" ||
  process.env.DATABASE_SSL === "true" ||
  /render\.com|amazonaws\.com|neon\.tech|supabase\.co|supabase\.com/i.test(connectionString);

const pool = new Pool({
  connectionString,
  max: Number(process.env.PGPOOL_MAX || 5),
  ssl: needSsl ? { rejectUnauthorized: false } : undefined,
});

let schemaReady: Promise<void> | null = null;
async function ensureSchema() {
  if (!schemaReady) {
    schemaReady = (async () => {
      const schemaPath = path.join(__dirname, "..", "..", "sql", "schema.sql");
      const altPath = path.join(process.cwd(), "sql", "schema.sql");
      const file = fs.existsSync(schemaPath) ? schemaPath : altPath;
      const sql = fs.readFileSync(file, "utf8");
      const client = await pool.connect();
      try {
        await client.query(sql);
      } finally {
        client.release();
      }
    })();
  }
  return schemaReady;
}

// ─── SQLite → PostgreSQL: dịch SQL ───────────────────────────────────────
function preprocessSql(sql: string): string {
  let s = sql;

  // SQLite DDL → PostgreSQL DDL
  // INTEGER PRIMARY KEY AUTOINCREMENT  →  SERIAL PRIMARY KEY
  s = s.replace(/\bINTEGER\s+PRIMARY\s+KEY\s+AUTOINCREMENT\b/gi, "SERIAL PRIMARY KEY");
  // INTEGER PRIMARY KEY (không có AUTOINCREMENT) → SERIAL PRIMARY KEY
  s = s.replace(/\bINTEGER\s+PRIMARY\s+KEY\b(?!\s+AUTOINCREMENT)/gi, "SERIAL PRIMARY KEY");
  // Xoá AUTOINCREMENT lẻ (an toàn nếu còn sót)
  s = s.replace(/\bAUTOINCREMENT\b/gi, "");
  // SQLite types → PG types
  s = s.replace(/\bDATETIME\b/gi, "TIMESTAMP");
  s = s.replace(/\bBLOB\b/gi, "BYTEA");
  // CURRENT_TIMESTAMP giữ nguyên (PG hỗ trợ)

  const wasIgnore = /INSERT\s+OR\s+IGNORE/i.test(s);
  s = s.replace(/INSERT\s+OR\s+IGNORE\s+INTO/gi, "INSERT INTO");

  // INSERT OR REPLACE → INSERT ... ON CONFLICT DO UPDATE (best-effort, để app tự viết rõ)
  s = s.replace(/INSERT\s+OR\s+REPLACE\s+INTO/gi, "INSERT INTO");

  // datetime('now','+N hours')
  s = s.replace(
    /datetime\(\s*'now'\s*,\s*'\s*([+-]?\d+)\s*hours?\s*'\s*\)/gi,
    (_m, h) => `to_char(NOW() + INTERVAL '${h} hours', 'YYYY-MM-DD HH24:MI:SS')`
  );
  // datetime('now')
  s = s.replace(/datetime\(\s*'now'\s*\)/gi, "to_char(NOW(), 'YYYY-MM-DD HH24:MI:SS')");
  // date('now')
  s = s.replace(/\bdate\(\s*'now'\s*\)/gi, "to_char(CURRENT_DATE, 'YYYY-MM-DD')");
  // date(<col>) – cắt 10 ký tự đầu
  s = s.replace(/\bdate\(\s*([a-zA-Z_][a-zA-Z0-9_.]*)\s*\)/g, "substr($1, 1, 10)");

  // Append ON CONFLICT DO NOTHING cho INSERT OR IGNORE (nếu chưa có)
  if (wasIgnore && !/ON\s+CONFLICT/i.test(s)) {
    // Chèn trước RETURNING nếu có
    if (/RETURNING/i.test(s)) {
      s = s.replace(/RETURNING/i, "ON CONFLICT DO NOTHING RETURNING");
    } else {
      s = s.trimEnd().replace(/;?$/, "") + " ON CONFLICT DO NOTHING";
    }
  }

  // ? → $1, $2, ... (bỏ qua trong chuỗi 'xxx')
  let i = 0;
  let out = "";
  let inStr = false;
  for (let k = 0; k < s.length; k++) {
    const c = s[k];
    if (c === "'") {
      inStr = !inStr;
      out += c;
    } else if (c === "?" && !inStr) {
      out += "$" + ++i;
    } else {
      out += c;
    }
  }
  return out;
}

function normalizeParams(args: any[]): any[] {
  // Hỗ trợ cả prepare(...).run(a,b,c) lẫn .run([a,b,c])
  if (args.length === 1 && Array.isArray(args[0])) return args[0];
  return args;
}

type Op = "run" | "get" | "all" | "exec";

async function handle(payload: { op: Op; sql: string; params?: any[] }) {
  await ensureSchema();
  const { op } = payload;
  if (op === "exec") {
    const client = await pool.connect();
    try {
      await client.query(preprocessSql(payload.sql));
    } finally {
      client.release();
    }
    return { ok: true };
  }
  const sql = preprocessSql(payload.sql);
  const params = normalizeParams(payload.params || []);
  const res = await pool.query(sql, params);
  if (op === "run") {
    const first = res.rows[0] as any;
    const lastInsertRowid =
      first && (first.id ?? Object.values(first)[0]) !== undefined
        ? (first.id ?? Object.values(first)[0])
        : undefined;
    return { changes: res.rowCount ?? 0, lastInsertRowid };
  }
  if (op === "get") return { row: res.rows[0] ?? undefined };
  return { rows: res.rows };
}

runAsWorker(handle);
