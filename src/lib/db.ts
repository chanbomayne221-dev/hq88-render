// ─────────────────────────────────────────────────────────────────────────
// DB facade: API đồng bộ kiểu better-sqlite3, backend là PostgreSQL (pg).
// Dùng synckit gọi sang worker thread để giữ chữ ký sync.
//
//   db.prepare(sql).run(...args)  →  { changes, lastInsertRowid }
//   db.prepare(sql).get(...args)  →  row | undefined
//   db.prepare(sql).all(...args)  →  row[]
//   db.exec(sqlMultiStatement)    →  void
// ─────────────────────────────────────────────────────────────────────────
import path from "path";
import { createSyncFn } from "synckit";
import { logger } from "./logger";

const workerPath = path.join(__dirname, "db.worker.js");

type Payload =
  | { op: "run"; sql: string; params?: any[] }
  | { op: "get"; sql: string; params?: any[] }
  | { op: "all"; sql: string; params?: any[] }
  | { op: "exec"; sql: string };

const callSync = createSyncFn(workerPath, {
  timeout: Number(process.env.PGSYNC_TIMEOUT_MS || 30000),
}) as (p: Payload) => any;

function prepare(sql: string) {
  return {
    run(...args: any[]) {
      const r = callSync({ op: "run", sql, params: args });
      return { changes: r.changes ?? 0, lastInsertRowid: r.lastInsertRowid };
    },
    get(...args: any[]) {
      const r = callSync({ op: "get", sql, params: args });
      return r.row;
    },
    all(...args: any[]) {
      const r = callSync({ op: "all", sql, params: args });
      return r.rows ?? [];
    },
  };
}

function exec(sql: string) {
  callSync({ op: "exec", sql });
}

export const db = { prepare, exec };

logger.info("PostgreSQL DB facade sẵn sàng (pg + synckit worker)");
