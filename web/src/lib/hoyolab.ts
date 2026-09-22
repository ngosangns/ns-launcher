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
  uid: string;
  nickname: string;
  otherUids: string[];
  characters: Array<{ id: string; constellation: number }>;
  weapons: Array<{ id: string; refinement: number }>;
  unmapped: string[];
};

export type HoyolabRole = {
  game_uid: string;
  region: string;
  level: number;
  nickname: string;
};

export function parseHoyolabCredential(ltuid: string, ltoken: string): { ltuid: string; ltoken: string } {
  const blob = `${ltuid}\n${ltoken}`;
  const uid = /ltuid_v2=(\d+)/u.exec(blob)?.[1];
  const token = /ltoken_v2=([^;\s]+)/u.exec(blob)?.[1];
  return { ltuid: (uid ?? ltuid).trim(), ltoken: (token ?? ltoken).trim() };
}

export function pickGameRole(roles: HoyolabRole[], uid = ""): HoyolabRole {
  if (roles.length === 0) throw new Error("Tài khoản HoYoLAB chưa gắn Genshin.");
  const wanted = uid.trim();
  if (isPlausibleUID(wanted)) {
    const match = roles.find((role) => role.game_uid === wanted);
    if (!match) throw new Error("UID này không nằm trong tài khoản HoYoLAB.");
    return match;
  }
  return roles.slice().sort((a, b) => b.level - a.level || a.game_uid.localeCompare(b.game_uid))[0];
}

function hoyolabHeaders(ltuid: string, ltoken: string): HeadersInit {
  const timestamp = Math.floor(Date.now() / 1000);
  const random = Array.from({ length: 6 }, () =>
    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"[Math.floor(Math.random() * 52)],
  ).join("");
  return {
    Accept: "application/json",
    "Content-Type": "application/json",
    "X-Ltuid": ltuid,
    "X-Ltoken": ltoken,
    "x-rpc-app_version": "1.5.0",
    "x-rpc-client_type": "5",
    "x-rpc-language": "en-us",
    ds: computeDynamicSecret(timestamp, random),
  };
}

async function hoyolabJson(path: string, ltuid: string, ltoken: string, init?: RequestInit): Promise<{
  retcode: number;
  message: string;
  data?: unknown;
}> {
  const response = await fetch(`/api/hoyolab/${path}`, {
    ...init,
    headers: { ...hoyolabHeaders(ltuid, ltoken), ...(init?.headers ?? {}) },
  });
  if (!response.ok) throw new Error(`HoYoLAB trả về HTTP ${response.status}.`);
  const payload = (await response.json()) as { retcode: number; message: string; data?: unknown };
  if (payload.retcode === -100 || payload.retcode === 10001) {
    throw new Error("Cặp ltuid_v2/ltoken_v2 bị từ chối — session có thể đã hết hạn.");
  }
  if (payload.retcode === 10102) {
    throw new Error('Cần bật "Character Details" trong cài đặt quyền riêng tư HoYoLAB.');
  }
  if (payload.retcode === 10101) throw new Error("HoYoLAB đang giới hạn truy cập.");
  if (payload.retcode === 1009) throw new Error("Không tìm thấy người chơi với UID này.");
  if (payload.retcode !== 0) throw new Error(`HoYoLAB lỗi ${payload.retcode}: ${payload.message}`);
  return payload;
}

export async function fetchHoyolabRoster(
  uid: string,
  ltuid: string,
  ltoken: string,
): Promise<HoyolabImport> {
  const credential = parseHoyolabCredential(ltuid, ltoken);
  if (!/^\d+$/u.test(credential.ltuid) || credential.ltoken.length < 8) {
    throw new Error("Thiếu ltuid_v2 hoặc ltoken_v2.");
  }
  const rolesPayload = await hoyolabJson(
    "binding/api/getUserGameRolesByCookie?game_biz=hk4e_global",
    credential.ltuid,
    credential.ltoken,
  );
  const roles = ((rolesPayload.data as { list?: HoyolabRole[] } | undefined)?.list ?? []).map((role) => ({
    game_uid: String(role.game_uid),
    region: role.region,
    level: role.level ?? 0,
    nickname: role.nickname ?? "",
  }));
  const role = pickGameRole(roles, uid);
  const server = role.region || serverCode(role.game_uid);
  if (!server) throw new Error("UID không hợp lệ.");
  const payload = await hoyolabJson(
    "event/game_record/genshin/api/character/list",
    credential.ltuid,
    credential.ltoken,
    { method: "POST", body: JSON.stringify({ role_id: role.game_uid, server }) },
  );
  const list =
    (
      payload.data as {
        list?: Array<{
          id: number;
          element?: string;
          actived_constellation_num: number;
          weapon?: { id: number; affix_level?: number };
        }>;
      }
    )?.list ?? [];
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
  return {
    uid: role.game_uid,
    nickname: role.nickname,
    otherUids: roles.filter((item) => item.game_uid !== role.game_uid).map((item) => item.game_uid),
    characters,
    weapons,
    unmapped,
  };
}
