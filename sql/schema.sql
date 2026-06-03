-- ─────────────────────────────────────────────────────────────────────────
-- HQ88 Telegram Bot – Schema PostgreSQL
-- Tự động chạy lúc bot khởi động (xem src/lib/db.worker.ts)
-- ─────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS users (
  id BIGSERIAL PRIMARY KEY,
  telegram_id BIGINT UNIQUE NOT NULL,
  username TEXT,
  first_name TEXT,
  balance BIGINT NOT NULL DEFAULT 0,
  vip_level BIGINT NOT NULL DEFAULT 0,
  total_bet BIGINT NOT NULL DEFAULT 0,
  today_bet BIGINT NOT NULL DEFAULT 0,
  week_bet BIGINT NOT NULL DEFAULT 0,
  total_deposit BIGINT NOT NULL DEFAULT 0,
  total_withdraw BIGINT NOT NULL DEFAULT 0,
  win_streak BIGINT NOT NULL DEFAULT 0,
  lose_streak BIGINT NOT NULL DEFAULT 0,
  max_win_streak BIGINT NOT NULL DEFAULT 0,
  max_lose_streak BIGINT NOT NULL DEFAULT 0,
  bank_name TEXT,
  bank_account TEXT,
  bank_owner TEXT,
  withdraw_fee_pct DOUBLE PRECISION NOT NULL DEFAULT 0.5,
  is_blocked BIGINT NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT to_char(NOW(), 'YYYY-MM-DD HH24:MI:SS'),
  last_checkin TEXT,
  daily_gift_date TEXT,
  daily_gift_claimed BIGINT NOT NULL DEFAULT 0
);

-- Cột mở rộng (idempotent)
ALTER TABLE users ADD COLUMN IF NOT EXISTS referrer_id BIGINT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS referral_today BIGINT NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS referral_today_date TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS referral_total BIGINT NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS first_deposit_done BIGINT NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS wager_required BIGINT NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS redeemed_points BIGINT NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_fake_bot BIGINT NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS transactions (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,
  type TEXT NOT NULL,
  amount BIGINT NOT NULL,
  fee BIGINT NOT NULL DEFAULT 0,
  balance_before BIGINT NOT NULL,
  balance_after BIGINT NOT NULL,
  note TEXT,
  ref_user_id BIGINT,
  created_at TEXT NOT NULL DEFAULT to_char(NOW(), 'YYYY-MM-DD HH24:MI:SS')
);
CREATE INDEX IF NOT EXISTS idx_tx_user ON transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_tx_type ON transactions(type);

CREATE TABLE IF NOT EXISTS giftcodes (
  id BIGSERIAL PRIMARY KEY,
  code TEXT UNIQUE NOT NULL,
  amount BIGINT NOT NULL,
  max_uses BIGINT NOT NULL DEFAULT 1,
  used_count BIGINT NOT NULL DEFAULT 0,
  is_active BIGINT NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT to_char(NOW(), 'YYYY-MM-DD HH24:MI:SS'),
  expires_at TEXT
);

CREATE TABLE IF NOT EXISTS giftcode_usages (
  id BIGSERIAL PRIMARY KEY,
  giftcode_id BIGINT NOT NULL,
  user_id BIGINT NOT NULL,
  used_at TEXT NOT NULL DEFAULT to_char(NOW(), 'YYYY-MM-DD HH24:MI:SS'),
  UNIQUE(giftcode_id, user_id)
);

CREATE TABLE IF NOT EXISTS checkins (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,
  reward BIGINT NOT NULL,
  streak BIGINT NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT to_char(NOW(), 'YYYY-MM-DD HH24:MI:SS')
);

CREATE TABLE IF NOT EXISTS game_sessions (
  id BIGSERIAL PRIMARY KEY,
  chat_id BIGINT NOT NULL,
  session_number BIGINT NOT NULL,
  dice1 BIGINT,
  dice2 BIGINT,
  dice3 BIGINT,
  total BIGINT,
  result_tai BIGINT,
  result_chan BIGINT,
  is_triple BIGINT NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'betting',
  created_at TEXT NOT NULL DEFAULT to_char(NOW(), 'YYYY-MM-DD HH24:MI:SS'),
  ended_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_gs_chat ON game_sessions(chat_id);

CREATE TABLE IF NOT EXISTS game_bets (
  id BIGSERIAL PRIMARY KEY,
  session_id BIGINT NOT NULL,
  user_id BIGINT NOT NULL,
  bet_type TEXT NOT NULL,
  amount BIGINT NOT NULL,
  is_win BIGINT,
  payout BIGINT,
  created_at TEXT NOT NULL DEFAULT to_char(NOW(), 'YYYY-MM-DD HH24:MI:SS')
);
CREATE INDEX IF NOT EXISTS idx_gb_session ON game_bets(session_id);
CREATE INDEX IF NOT EXISTS idx_gb_user ON game_bets(user_id);

CREATE TABLE IF NOT EXISTS group_game_enabled (
  chat_id BIGINT PRIMARY KEY,
  enabled_at TEXT NOT NULL DEFAULT to_char(NOW(), 'YYYY-MM-DD HH24:MI:SS')
);

CREATE TABLE IF NOT EXISTS jackpot_pool (
  id BIGINT PRIMARY KEY CHECK (id = 1),
  amount BIGINT NOT NULL DEFAULT 0
);
INSERT INTO jackpot_pool (id, amount) VALUES (1, 0) ON CONFLICT (id) DO NOTHING;

CREATE TABLE IF NOT EXISTS pending_deposits (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,
  telegram_id BIGINT NOT NULL,
  group_chat_id BIGINT,
  amount BIGINT NOT NULL,
  note TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TEXT NOT NULL DEFAULT to_char(NOW(), 'YYYY-MM-DD HH24:MI:SS'),
  handled_at TEXT
);

CREATE TABLE IF NOT EXISTS pending_withdrawals (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,
  telegram_id BIGINT NOT NULL,
  amount BIGINT NOT NULL,
  fee BIGINT NOT NULL DEFAULT 0,
  net BIGINT NOT NULL DEFAULT 0,
  bank_name TEXT,
  bank_account TEXT,
  bank_owner TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TEXT NOT NULL DEFAULT to_char(NOW(), 'YYYY-MM-DD HH24:MI:SS'),
  handled_at TEXT
);

CREATE TABLE IF NOT EXISTS daily_cashbacks (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,
  date TEXT NOT NULL,
  total_bet BIGINT NOT NULL,
  cashback BIGINT NOT NULL,
  claimed BIGINT NOT NULL DEFAULT 0,
  claimed_at TEXT,
  UNIQUE(user_id, date)
);

CREATE TABLE IF NOT EXISTS bot_settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS fake_bots (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  telegram_id BIGINT UNIQUE NOT NULL,
  min_bet BIGINT NOT NULL DEFAULT 10000,
  max_bet BIGINT NOT NULL DEFAULT 100000,
  bet_types TEXT NOT NULL DEFAULT 'tai,xiu',
  delay_min BIGINT NOT NULL DEFAULT 5,
  delay_max BIGINT NOT NULL DEFAULT 35,
  balance_refill BIGINT NOT NULL DEFAULT 50000000,
  enabled BIGINT NOT NULL DEFAULT 1,
  vip_icon TEXT DEFAULT ''
);
UPDATE fake_bots SET vip_icon = '🏵️' WHERE vip_icon IS NULL OR vip_icon = '';
