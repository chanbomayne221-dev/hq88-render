-- ─────────────────────────────────────────────────────────────────────────
-- HQ88 Telegram Bot – Schema PostgreSQL
-- Tự động chạy lúc bot khởi động (xem src/lib/db.worker.ts)
-- ─────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS users (
  id BIGSERIAL PRIMARY KEY,
  telegram_id BIGINT UNIQUE NOT NULL,
  username TEXT,
  first_name TEXT,
  balance NUMERIC(30,0) NOT NULL DEFAULT 0,
  vip_level BIGINT NOT NULL DEFAULT 0,
  total_bet NUMERIC(30,0) NOT NULL DEFAULT 0,
  today_bet NUMERIC(30,0) NOT NULL DEFAULT 0,
  week_bet NUMERIC(30,0) NOT NULL DEFAULT 0,
  total_deposit NUMERIC(30,0) NOT NULL DEFAULT 0,
  total_withdraw NUMERIC(30,0) NOT NULL DEFAULT 0,
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
ALTER TABLE users ADD COLUMN IF NOT EXISTS referral_today NUMERIC(30,0) NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS referral_today_date TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS referral_total NUMERIC(30,0) NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS first_deposit_done BIGINT NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS wager_required NUMERIC(30,0) NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS redeemed_points NUMERIC(30,0) NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_fake_bot BIGINT NOT NULL DEFAULT 0;

ALTER TABLE users ALTER COLUMN balance TYPE NUMERIC(30,0) USING balance::numeric;
ALTER TABLE users ALTER COLUMN total_bet TYPE NUMERIC(30,0) USING total_bet::numeric;
ALTER TABLE users ALTER COLUMN today_bet TYPE NUMERIC(30,0) USING today_bet::numeric;
ALTER TABLE users ALTER COLUMN week_bet TYPE NUMERIC(30,0) USING week_bet::numeric;
ALTER TABLE users ALTER COLUMN total_deposit TYPE NUMERIC(30,0) USING total_deposit::numeric;
ALTER TABLE users ALTER COLUMN total_withdraw TYPE NUMERIC(30,0) USING total_withdraw::numeric;
ALTER TABLE users ALTER COLUMN referral_today TYPE NUMERIC(30,0) USING referral_today::numeric;
ALTER TABLE users ALTER COLUMN referral_total TYPE NUMERIC(30,0) USING referral_total::numeric;
ALTER TABLE users ALTER COLUMN wager_required TYPE NUMERIC(30,0) USING wager_required::numeric;
ALTER TABLE users ALTER COLUMN redeemed_points TYPE NUMERIC(30,0) USING redeemed_points::numeric;

CREATE TABLE IF NOT EXISTS transactions (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,
  type TEXT NOT NULL,
  amount NUMERIC(30,0) NOT NULL,
  fee NUMERIC(30,0) NOT NULL DEFAULT 0,
  balance_before NUMERIC(30,0) NOT NULL,
  balance_after NUMERIC(30,0) NOT NULL,
  note TEXT,
  ref_user_id BIGINT,
  created_at TEXT NOT NULL DEFAULT to_char(NOW(), 'YYYY-MM-DD HH24:MI:SS')
);
CREATE INDEX IF NOT EXISTS idx_tx_user ON transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_tx_type ON transactions(type);
ALTER TABLE transactions ALTER COLUMN amount TYPE NUMERIC(30,0) USING amount::numeric;
ALTER TABLE transactions ALTER COLUMN fee TYPE NUMERIC(30,0) USING fee::numeric;
ALTER TABLE transactions ALTER COLUMN balance_before TYPE NUMERIC(30,0) USING balance_before::numeric;
ALTER TABLE transactions ALTER COLUMN balance_after TYPE NUMERIC(30,0) USING balance_after::numeric;

CREATE TABLE IF NOT EXISTS giftcodes (
  id BIGSERIAL PRIMARY KEY,
  code TEXT UNIQUE NOT NULL,
  amount NUMERIC(30,0) NOT NULL,
  max_uses BIGINT NOT NULL DEFAULT 1,
  used_count BIGINT NOT NULL DEFAULT 0,
  is_active BIGINT NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT to_char(NOW(), 'YYYY-MM-DD HH24:MI:SS'),
  expires_at TEXT
);
ALTER TABLE giftcodes ALTER COLUMN amount TYPE NUMERIC(30,0) USING amount::numeric;

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
  reward NUMERIC(30,0) NOT NULL,
  streak BIGINT NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT to_char(NOW(), 'YYYY-MM-DD HH24:MI:SS')
);
ALTER TABLE checkins ALTER COLUMN reward TYPE NUMERIC(30,0) USING reward::numeric;

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
  amount NUMERIC(30,0) NOT NULL,
  is_win BIGINT,
  payout NUMERIC(30,0),
  created_at TEXT NOT NULL DEFAULT to_char(NOW(), 'YYYY-MM-DD HH24:MI:SS')
);
CREATE INDEX IF NOT EXISTS idx_gb_session ON game_bets(session_id);
CREATE INDEX IF NOT EXISTS idx_gb_user ON game_bets(user_id);
ALTER TABLE game_bets ALTER COLUMN amount TYPE NUMERIC(30,0) USING amount::numeric;
ALTER TABLE game_bets ALTER COLUMN payout TYPE NUMERIC(30,0) USING payout::numeric;

CREATE TABLE IF NOT EXISTS group_game_enabled (
  chat_id BIGINT PRIMARY KEY,
  enabled_at TEXT NOT NULL DEFAULT to_char(NOW(), 'YYYY-MM-DD HH24:MI:SS')
);

CREATE TABLE IF NOT EXISTS jackpot_pool (
  id BIGINT PRIMARY KEY CHECK (id = 1),
  amount NUMERIC(30,0) NOT NULL DEFAULT 0
);
INSERT INTO jackpot_pool (id, amount) VALUES (1, 0) ON CONFLICT (id) DO NOTHING;
ALTER TABLE jackpot_pool ALTER COLUMN amount TYPE NUMERIC(30,0) USING amount::numeric;

CREATE TABLE IF NOT EXISTS pending_deposits (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,
  telegram_id BIGINT NOT NULL,
  group_chat_id BIGINT,
  amount NUMERIC(30,0) NOT NULL,
  note TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TEXT NOT NULL DEFAULT to_char(NOW(), 'YYYY-MM-DD HH24:MI:SS'),
  handled_at TEXT
);
ALTER TABLE pending_deposits ALTER COLUMN amount TYPE NUMERIC(30,0) USING amount::numeric;

CREATE TABLE IF NOT EXISTS pending_withdrawals (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,
  telegram_id BIGINT NOT NULL,
  amount NUMERIC(30,0) NOT NULL,
  fee NUMERIC(30,0) NOT NULL DEFAULT 0,
  net NUMERIC(30,0) NOT NULL DEFAULT 0,
  bank_name TEXT,
  bank_account TEXT,
  bank_owner TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TEXT NOT NULL DEFAULT to_char(NOW(), 'YYYY-MM-DD HH24:MI:SS'),
  handled_at TEXT
);
ALTER TABLE pending_withdrawals ALTER COLUMN amount TYPE NUMERIC(30,0) USING amount::numeric;
ALTER TABLE pending_withdrawals ALTER COLUMN fee TYPE NUMERIC(30,0) USING fee::numeric;
ALTER TABLE pending_withdrawals ALTER COLUMN net TYPE NUMERIC(30,0) USING net::numeric;

CREATE TABLE IF NOT EXISTS daily_cashbacks (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,
  date TEXT NOT NULL,
  total_bet NUMERIC(30,0) NOT NULL,
  cashback NUMERIC(30,0) NOT NULL,
  claimed BIGINT NOT NULL DEFAULT 0,
  claimed_at TEXT,
  UNIQUE(user_id, date)
);
ALTER TABLE daily_cashbacks ALTER COLUMN total_bet TYPE NUMERIC(30,0) USING total_bet::numeric;
ALTER TABLE daily_cashbacks ALTER COLUMN cashback TYPE NUMERIC(30,0) USING cashback::numeric;

CREATE TABLE IF NOT EXISTS bot_settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS fake_bots (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  telegram_id BIGINT UNIQUE NOT NULL,
  min_bet NUMERIC(30,0) NOT NULL DEFAULT 10000,
  max_bet NUMERIC(30,0) NOT NULL DEFAULT 100000,
  bet_types TEXT NOT NULL DEFAULT 'tai,xiu',
  delay_min BIGINT NOT NULL DEFAULT 5,
  delay_max BIGINT NOT NULL DEFAULT 35,
  balance_refill NUMERIC(30,0) NOT NULL DEFAULT 50000000,
  enabled BIGINT NOT NULL DEFAULT 1,
  vip_icon TEXT DEFAULT ''
);
ALTER TABLE fake_bots ALTER COLUMN min_bet TYPE NUMERIC(30,0) USING min_bet::numeric;
ALTER TABLE fake_bots ALTER COLUMN max_bet TYPE NUMERIC(30,0) USING max_bet::numeric;
ALTER TABLE fake_bots ALTER COLUMN balance_refill TYPE NUMERIC(30,0) USING balance_refill::numeric;
UPDATE fake_bots SET vip_icon = '🏵️' WHERE vip_icon IS NULL OR vip_icon = '';
