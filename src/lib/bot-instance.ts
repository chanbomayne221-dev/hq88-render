import type TelegramBot from "node-telegram-bot-api";

let _bot: TelegramBot | null = null;

export function setBotInstance(bot: TelegramBot) { _bot = bot; }
export function getBotInstance(): TelegramBot | null { return _bot; }
