// Logger tối giản, in JSON-ish ra stdout/stderr.
type Level = "debug" | "info" | "warn" | "error";

const LEVELS: Record<Level, number> = { debug: 10, info: 20, warn: 30, error: 40 };
const CURRENT: number = LEVELS[(process.env.LOG_LEVEL as Level) ?? "info"] ?? LEVELS.info;

function emit(level: Level, args: unknown[]) {
  if (LEVELS[level] < CURRENT) return;
  const time = new Date().toISOString();
  const prefix = `[${time}] ${level.toUpperCase()}`;
  let meta = "";
  let msg = "";
  for (const a of args) {
    if (typeof a === "string") msg += (msg ? " " : "") + a;
    else {
      try { meta += " " + JSON.stringify(a); } catch { meta += " [unserializable]"; }
    }
  }
  const line = `${prefix} ${msg}${meta}`;
  if (level === "error" || level === "warn") console.error(line);
  else console.log(line);
}

export const logger = {
  debug: (...args: unknown[]) => emit("debug", args),
  info:  (...args: unknown[]) => emit("info", args),
  warn:  (...args: unknown[]) => emit("warn", args),
  error: (...args: unknown[]) => emit("error", args),
};
