import gameIds from "../../../Sources/NSLauncherApp/Resources/Abyss/game-ids.json";
import { isPlausibleUID } from "./enka";
import { md5 } from "./md5";

type GameIDs = {
  characters: Record<string, string>;
  weapons: Record<string, string>;
};

const ids = gameIds as GameIDs;
const SALT = "6s25p5ox5y14umn1p61aqyyvbvvl3lrt";
const TRAVELER_AVATARS = new Set([10000005, 10000007]);
const TRAVELER_ELEMENTS: Record<string, string> = {
  Wind: "anemo",
  Rock: "geo",
  Electric: "electro",
  Grass: "dendro",
  Water: "hydro",
  Fire: "pyro",
  Ice: "cryo",
};

export function computeDynamicSecret(timestamp: number, random: string, salt = SALT): string {
  const signed = `salt=${salt}&t=${timestamp}&r=${random}`;
  return `${timestamp},${random},${md5(signed)}`;
}

export function serverCode(uid: string): string | null {
  if (uid.length === 9) {
    switch (uid[0]) {
      case "6":
        return "os_usa";
      case "7":
        return "os_euro";
      case "8":
        return "os_asia";
      case "9":
        return "os_cht";
      default:
        return null;
    }
  }
  if (uid.length === 10 && uid.startsWith("18")) return "os_asia";
  return null;
}

function characterID(avatarID: number, element?: string): string | undefined {
  const mapped = ids.characters[String(avatarID)];
  if (mapped) return mapped;
  if (!TRAVELER_AVATARS.has(avatarID) || !element) return undefined;
  const slug = TRAVELER_ELEMENTS[element];
  return slug ? `traveler-${slug}` : undefined;
}

export type HoyolabImport = {
  characters: Array<{ id: string; constellation: number }>;
  weapons: Array<{ id: string; refinement: number }>;
  unmapped: string[];
};

export async function fetchHoyolabRoster(
  uid: string,
  ltuid: string,
  ltoken: string,
): Promise<HoyolabImport> {
  const trimmed = uid.trim();
  if (!isPlausibleUID(trimmed)) throw new Error("UID không hợp lệ.");
  const server = serverCode(trimmed);
  if (!server) throw new Error("UID không hợp lệ.");
  const timestamp = Math.floor(Date.now() / 1000);
  const random = Array.from({ length: 6 }, () =>
    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"[Math.floor(Math.random() * 52)],
  ).join("");
  const response = await fetch("/api/hoyolab/event/game_record/genshin/api/character/list", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
      "X-Ltuid": ltuid.trim(),
      "X-Ltoken": ltoken.trim(),
      "x-rpc-app_version": "1.5.0",
      "x-rpc-client_type": "5",
      "x-rpc-language": "en-us",
      ds: computeDynamicSecret(timestamp, random),
    },
    body: JSON.stringify({ role_id: trimmed, server }),
  });
  if (!response.ok) throw new Error(`HoYoLAB trả về HTTP ${response.status}.`);
  const payload = (await response.json()) as {
    retcode: number;
    message: string;
    data?: {
      list?: Array<{
        id: number;
        element?: string;
        actived_constellation_num: number;
        weapon?: { id: number; affix_level?: number };
      }>;
    };
  };
  if (payload.retcode === -100 || payload.retcode === 10001) {
    throw new Error("Cặp ltuid_v2/ltoken_v2 bị từ chối — session có thể đã hết hạn.");
  }
  if (payload.retcode === 10102) {
    throw new Error('Cần bật "Character Details" trong cài đặt quyền riêng tư HoYoLAB.');
  }
  if (payload.retcode === 10101) throw new Error("HoYoLAB đang giới hạn truy cập.");
  if (payload.retcode === 1009) throw new Error("Không tìm thấy người chơi với UID này.");
  if (payload.retcode !== 0) throw new Error(`HoYoLAB lỗi ${payload.retcode}: ${payload.message}`);
  const list = payload.data?.list ?? [];
  const characters: HoyolabImport["characters"] = [];
  const weapons: HoyolabImport["weapons"] = [];
  const unmapped: string[] = [];
  for (const row of list) {
    const id = characterID(row.id, row.element);
    if (!id) {
      unmapped.push(`character ${row.id}`);
      continue;
    }
    characters.push({
      id,
      constellation: Math.min(Math.max(row.actived_constellation_num ?? 0, 0), 6),
    });
    if (row.weapon) {
      const weaponID = ids.weapons[String(row.weapon.id)];
      if (!weaponID) unmapped.push(`weapon ${row.weapon.id}`);
      else if (!weapons.some((item) => item.id === weaponID)) {
        weapons.push({
          id: weaponID,
          refinement: Math.min(Math.max(row.weapon.affix_level ?? 1, 1), 5),
        });
      }
    }
  }
  return { characters, weapons, unmapped };
}
