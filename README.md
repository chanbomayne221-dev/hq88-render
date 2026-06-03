# HQ88 Telegram Bot – PostgreSQL Edition

Bot Telegram (polling), backend **PostgreSQL** (Supabase / Render Postgres / Neon ...). Tương thích deploy 1-click trên Render.

## 1. Cài đặt local

```bash
npm install
cp .env.example .env
# Điền BOT_TOKEN, ADMIN_ID, DATABASE_URL vào .env
npm run build
npm start
```

Schema được tự động tạo từ `sql/schema.sql` ngay khi bot khởi động (idempotent – chạy nhiều lần an toàn).

## 2. Biến môi trường

| Biến | Bắt buộc | Ghi chú |
|---|---|---|
| `BOT_TOKEN` | ✅ | Lấy từ @BotFather |
| `ADMIN_ID` | ✅ | ID Telegram admin, nhiều ID ngăn cách bởi `,` |
| `DATABASE_URL` | ✅ | `postgresql://user:pass@host:5432/db?sslmode=require` |
| `DATABASE_SSL` | – | `true` để ép SSL nếu connection string không có |
| `PGPOOL_MAX` | – | Mặc định 5 |
| `PGSYNC_TIMEOUT_MS` | – | Timeout mỗi query (ms), mặc định 30000 |
| `PORT` | – | Cổng health-check (Render tự set) |
| `LOG_LEVEL` | – | `debug` / `info` / `warn` / `error` |

### Supabase
1. Vào project Supabase → **Project Settings → Database → Connection string → URI**.
2. Copy URI dạng `postgresql://postgres:<password>@db.<ref>.supabase.co:5432/postgres`.
3. Thêm `?sslmode=require` ở cuối.
4. Dán vào `DATABASE_URL`.

## 3. Deploy lên Render

1. Tạo Web Service từ repo này (Render sẽ đọc `render.yaml`).
2. Trong tab **Environment**, set: `BOT_TOKEN`, `ADMIN_ID`, `DATABASE_URL`.
3. Deploy. Health-check tại `/healthz`.

Không cần persistent disk vì dữ liệu nằm hoàn toàn trên PostgreSQL.

## 4. Kiến trúc DB

- `src/lib/db.ts` – Facade **đồng bộ** kiểu `better-sqlite3` (`db.prepare(sql).run/get/all`, `db.exec(sql)`).
- `src/lib/db.worker.ts` – Worker thread thật sự chạy `pg.Pool`; main thread gọi qua [`synckit`](https://github.com/un-ts/synckit) để giữ API đồng bộ.
- `sql/schema.sql` – Toàn bộ schema PostgreSQL, tự chạy 1 lần lúc query đầu tiên.

Phần preprocess SQL trong `db.worker.ts` tự dịch các cú pháp SQLite còn sót lại trong `bot.ts`:
- `?` → `$1, $2, ...`
- `datetime('now')` → `to_char(NOW(), 'YYYY-MM-DD HH24:MI:SS')`
- `date('now')` → `to_char(CURRENT_DATE, 'YYYY-MM-DD')`
- `date(col)` → `substr(col, 1, 10)`
- `INSERT OR IGNORE ...` → `INSERT ... ON CONFLICT DO NOTHING`

## 5. Bot không còn dùng SQLite

- `better-sqlite3` đã bị gỡ khỏi `dependencies`.
- Không còn file `data/bot.sqlite`, không còn `DB_PATH`.
- Mọi state đều persist trên PostgreSQL.
