# HQ88 VUA TRÒ CHƠI – Telegram Bot (Render 24/7)

Bot Telegram chạy **polling** (không cần webhook), deploy 1-click lên [Render](https://render.com).

Toàn bộ logic / commands / game / database / admin panel **giữ nguyên 100%** so với bản Railway. Chỉ thay đổi phần cấu hình deploy.

---

## 🚀 Deploy lên Render (1-click)

### Cách 1 — Blueprint (khuyến nghị, dùng `render.yaml`)

1. Push repo này lên GitHub.
2. Vào [dashboard.render.com](https://dashboard.render.com) → **New → Blueprint**.
3. Chọn repo vừa push → Render tự đọc `render.yaml`.
4. Điền 2 biến môi trường:
   - `BOT_TOKEN` – token từ [@BotFather](https://t.me/BotFather)
   - `ADMIN_ID` – ID Telegram admin (nhiều ID cách bằng dấu phẩy: `123,456`)
5. Bấm **Apply** → Render tự build + deploy + mount disk 1 GB vào `/var/data`.

### Cách 2 — Tạo Web Service thủ công

1. **New → Web Service** → chọn repo.
2. **Runtime:** Node.
3. **Build Command:** `npm install && npm run build`
4. **Start Command:** `npm start`
5. **Environment Variables:** thêm `BOT_TOKEN`, `ADMIN_ID`, `DB_PATH=/var/data/bot.sqlite`.
6. **Disks → Add Disk:** Name `bot-data`, Mount Path `/var/data`, Size 1 GB.
7. Deploy.

> ⚠️ **Free plan KHÔNG có persistent disk.** Nếu dùng free, DB sẽ reset mỗi lần deploy. Dùng plan **Starter ($7/tháng)** trở lên để giữ dữ liệu.

---

## 🔐 Environment Variables

| Tên          | Bắt buộc | Mặc định               | Ghi chú |
|--------------|----------|------------------------|---------|
| `BOT_TOKEN`  | ✅       | —                      | Token bot từ @BotFather. Cũng nhận `TELEGRAM_BOT_TOKEN`. |
| `ADMIN_ID`   | ✅       | —                      | ID Telegram admin. Nhiều ID: `123,456`. |
| `DB_PATH`    | ❌       | `./data/bot.sqlite`    | Trên Render đặt `/var/data/bot.sqlite`. |
| `PORT`       | ❌       | `3000`                 | Render tự inject; không cần set tay. |
| `LOG_LEVEL`  | ❌       | `info`                 | `debug` / `info` / `warn` / `error`. |

---

## 🖥️ Chạy local

```bash
cp .env.example .env      # điền BOT_TOKEN, ADMIN_ID
npm install
npm run build
npm start
```

Bot sẽ:
- Kết nối Telegram bằng polling
- Mở HTTP health-check tại `http://localhost:3000/healthz`

---

## 📂 Cấu trúc

```
src/
  index.ts          # entry – ENV mapping, start polling + HTTP health-check
  bot.ts            # toàn bộ logic bot (giữ nguyên)
  lib/
    db.ts           # SQLite, tự tạo file & thư mục, fallback /tmp
    logger.ts       # logger đơn giản
    bot-instance.ts # share instance bot
assets/             # ảnh QR nạp tiền
data/               # SQLite (local) – Render dùng /var/data
render.yaml         # Render Blueprint
package.json
tsconfig.json
.env.example
```

---

## 🛡️ 24/7 & chống crash

- `uncaughtException` / `unhandledRejection` được log thay vì kill process.
- Render tự động **restart on failure** (mặc định).
- Polling tự reconnect khi mạng Telegram lỗi.
- Graceful shutdown SIGINT / SIGTERM.
- Health-check `GET /healthz` để Render biết service còn sống.

---

## 🔄 So với bản Railway cũ

| Item                      | Railway              | Render                          |
|---------------------------|----------------------|---------------------------------|
| Config file               | `railway.json`, `nixpacks.toml`, `Procfile` | `render.yaml` |
| Persistent storage        | Volume → `/app/data` | Disk → `/var/data`              |
| Port binding              | Không bắt buộc       | **Bắt buộc** (web service)      |
| Health check              | —                    | `GET /healthz`                  |
| Build                     | Nixpacks auto        | `npm install && npm run build`  |

Không có thay đổi nào ảnh hưởng tới logic bot, database schema, lệnh, game, hay dữ liệu người dùng.
