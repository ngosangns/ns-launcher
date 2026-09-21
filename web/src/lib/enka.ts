import gameIds from "../../../Sources/NSLauncherApp/Resources/Abyss/game-ids.json";

type GameIDs = {
  characters: Record<string, string>;
  travelerSkillDepots: Record<string, string>;
  weapons: Record<string, string>;
};

const ids = gameIds as GameIDs;

export function isPlausibleUID(uid: string): boolean {
  const trimmed = uid.trim();
  return trimmed.length >= 9 && trimmed.length <= 10 && /^[1-9]\d+$/u.test(trimmed);
}

function characterID(avatarID: number, skillDepotID?: number): string | undefined {
  const mapped = ids.characters[String(avatarID)];
  if (mapped) return mapped;
  if (skillDepotID == null) return undefined;
  return ids.travelerSkillDepots[String(skillDepotID)];
}

export type EnkaImport = {
  nickname: string;
  characters: Array<{ id: string; constellation: number }>;
  weapons: Array<{ id: string; refinement: number }>;
  unmapped: string[];
};

export async function fetchEnkaShowcase(uid: string): Promise<EnkaImport> {
  const trimmed = uid.trim();
  if (!isPlausibleUID(trimmed)) throw new Error("UID không hợp lệ.");
  const response = await fetch(`/api/enka/api/uid/${trimmed}`, {
    headers: { Accept: "application/json", "User-Agent": "NSLauncher-web" },
  });
  if (response.status === 400) throw new Error("UID không hợp lệ.");
  if (response.status === 404) throw new Error("Không tìm thấy người chơi với UID này.");
  if (response.status === 424) throw new Error("Máy chủ game đang bảo trì.");
  if (response.status === 429) throw new Error("Enka.Network đang giới hạn truy cập.");
  if (response.status === 503) throw new Error("Enka.Network hiện không truy cập được.");
  if (!response.ok) throw new Error(`Enka.Network trả về HTTP ${response.status}.`);
  const payload = (await response.json()) as {
    playerInfo?: { nickname?: string };
    avatarInfoList?: Array<{
      avatarId: number;
      skillDepotId?: number;
      talentIdList?: number[];
      equipList?: Array<{
        itemId?: number;
        weapon?: { affixMap?: Record<string, number> };
      }>;
    }>;
  };
  const avatars = payload.avatarInfoList ?? [];
  if (avatars.length === 0) {
    throw new Error(
      'Showcase trống hoặc đang ẩn. Trong game, mở hồ sơ, sửa Showcase nhân vật và bật "Hiển thị chi tiết nhân vật".',
    );
  }
  const characters: EnkaImport["characters"] = [];
  const weapons: EnkaImport["weapons"] = [];
  const unmapped: string[] = [];
  for (const avatar of avatars) {
    const id = characterID(avatar.avatarId, avatar.skillDepotId);
    if (!id) {
      unmapped.push(`avatar ${avatar.avatarId}`);
      continue;
    }
    characters.push({ id, constellation: Math.min(avatar.talentIdList?.length ?? 0, 6) });
    for (const equip of avatar.equipList ?? []) {
      if (!equip.weapon || equip.itemId == null) continue;
      const weaponID = ids.weapons[String(equip.itemId)];
      if (!weaponID) {
        unmapped.push(`weapon ${equip.itemId}`);
        continue;
      }
      const refinement = (Object.values(equip.weapon.affixMap ?? {})[0] ?? 0) + 1;
      if (!weapons.some((item) => item.id === weaponID)) {
        weapons.push({ id: weaponID, refinement: Math.min(Math.max(refinement, 1), 5) });
      }
    }
  }
  if (characters.length === 0) {
    throw new Error("Showcase trống hoặc nhân vật mới hơn dữ liệu đi kèm.");
  }
  return {
    nickname: payload.playerInfo?.nickname ?? "",
    characters,
    weapons,
    unmapped,
  };
}
