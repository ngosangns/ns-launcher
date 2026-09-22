export type Lang = "vi" | "en";

const STORAGE_KEY = "ns-teyvat-lang";

export function readLang(): Lang {
  try {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (stored === "en" || stored === "vi") return stored;
  } catch {
    /* private mode */
  }
  return "vi";
}

export function writeLang(lang: Lang): void {
  try {
    localStorage.setItem(STORAGE_KEY, lang);
  } catch {
    /* private mode */
  }
}

type Copy = {
  brand: string;
  tagline: string;
  home: string;
  story: string;
  abyss: string;
  storySearch: string;
  storyChapters: string;
  storyEntities: string;
  storyQuests: string;
  storyAppearsIn: string;
  storyRelatedQuests: string;
  storyNoSummary: string;
  storyAlsoKnownAs: string;
  storyEmpty: string;
  storySelect: string;
  storyCopyright: string;
  storyOpenToc: string;
  entityCharacter: string;
  entityArchon: string;
  entityFaction: string;
  entityNation: string;
  entityEvent: string;
  entityConcept: string;
  turningPoint: string;
  openMystery: string;
  note: string;
  abyssCycle: string;
  abyssCharacters: string;
  abyssWeapons: string;
  abyssArtifacts: string;
  abyssResonance: string;
  abyssTeam: string;
  abyssMonsters: string;
  abyssSearchCharacters: string;
  abyssSearchWeapons: string;
  abyssSearchArtifacts: string;
  abyssAll: string;
  abyssOwnedHint: string;
  abyssEmpty: string;
  abyssBlessing: string;
  abyssLeyLine: string;
  abyssRecommendation: string;
  abyssChamber: string;
  abyssWave: string;
  abyssLevel: string;
  abyssHP: string;
  abyssRes: string;
  abyssMechanics: string;
  abyssSpawns: string;
  abyssHPEach: string;
  abyssHPTotal: string;
  abyssHPRatio: string;
  abyssWeakpoint: string;
  abyssCount: string;
  abyssSize: string;
  abyssVariant: string;
  abyssHalf1: string;
  abyssHalf2: string;
  abyssPickTeam: string;
  abyssClearSlot: string;
  abyssTeamHint: string;
  homeStoryLead: string;
  homeAbyssLead: string;
  homeOpen: string;
  formulaTitle: string;
  twoPiece: string;
  fourPiece: string;
  constellations: string;
  passives: string;
  talents: string;
  normalAttack: string;
  skill: string;
  burst: string;
  baseStats: string;
  acquisition: string;
  bestOn: string;
  domain: string;
  roleNotes: string;
  lv90: string;
  lv1: string;
  kitTitle: string;
  refineTable: string;
  taggedCharacters: string;
  lunarBonus: string;
  lunarCap: string;
  currentCycle: string;
  previousCycle: string;
  expired: string;
  abyssRoster: string;
  abyssResults: string;
  abyssFindTeams: string;
  abyssSearching: string;
  abyssImportUID: string;
  abyssUIDPlaceholder: string;
  abyssImport: string;
  abyssUIDHint: string;
  abyssImportFull: string;
  abyssHoyolabHint: string;
  abyssMethodology: string;
  abyssFullChars: string;
  abyssFullWeapons: string;
  abyssOwnedOnly: string;
  abyssSortRarity: string;
  abyssSortName: string;
  abyssSortOwned: string;
  abyssConstellationNote: string;
  abyssExport: string;
  abyssClearCharacters: string;
  abyssClearWeapons: string;
  abyssEmptyRoster: string;
  abyssNoResultsHint: string;
  abyssHalfPlanNotice: string;
  abyssClearApprox: string;
};

const vi: Copy = {
  brand: "Ký Sự Teyvat",
  tagline: "Cốt truyện và La Hoàn, viết lại bằng tiếng Việt",
  home: "Trang chủ",
  story: "Cốt truyện",
  abyss: "La Hoàn",
  storySearch: "Tìm nhân vật, chương, nhiệm vụ…",
  storyChapters: "Cốt truyện",
  storyEntities: "Nhân vật & sự kiện",
  storyQuests: "Nhiệm vụ",
  storyAppearsIn: "Xuất hiện trong",
  storyRelatedQuests: "Liên quan trong nhiệm vụ",
  storyNoSummary: "Chưa có tóm tắt.",
  storyAlsoKnownAs: "Còn được gọi là",
  storyEmpty: "Không tìm thấy kết quả.",
  storySelect: "Chọn một chương, nhân vật, hoặc nhiệm vụ ở bên trái.",
  storyCopyright:
    "Genshin Impact cùng nhân vật, địa danh và cốt truyện gốc thuộc bản quyền HoYoverse. Đây là bản diễn giải cá nhân, phi lợi nhuận để tham khảo — không phải bản dịch hay tái bản nội dung trong game.",
  storyOpenToc: "Mục lục",
  entityCharacter: "Nhân vật",
  entityArchon: "Archon",
  entityFaction: "Phe phái",
  entityNation: "Quốc gia",
  entityEvent: "Sự kiện",
  entityConcept: "Khái niệm",
  turningPoint: "Bước ngoặt",
  openMystery: "Bí ẩn còn bỏ ngỏ",
  note: "Ghi chú",
  abyssCycle: "Chu kỳ",
  abyssCharacters: "Nhân vật",
  abyssWeapons: "Vũ khí",
  abyssArtifacts: "Thánh di vật",
  abyssResonance: "Cộng hưởng",
  abyssTeam: "Đội hình",
  abyssMonsters: "Quái",
  abyssSearchCharacters: "Tìm nhân vật",
  abyssSearchWeapons: "Tìm vũ khí",
  abyssSearchArtifacts: "Tìm thánh di vật",
  abyssAll: "Tất cả",
  abyssOwnedHint: "Chạm để chọn vào đội",
  abyssEmpty: "Không có mục nào khớp.",
  abyssBlessing: "Uyên Nguyệt Chúc Phúc",
  abyssLeyLine: "Ley Line Disorder",
  abyssRecommendation: "Gợi ý",
  abyssChamber: "Chặng",
  abyssWave: "Đợt",
  abyssLevel: "Cấp",
  abyssHP: "HP",
  abyssRes: "Kháng",
  abyssMechanics: "Cơ chế",
  abyssSpawns: "Số con",
  abyssHPEach: "HP mỗi con",
  abyssHPTotal: "Tổng HP",
  abyssHPRatio: "Hệ số HP",
  abyssWeakpoint: "Điểm yếu",
  abyssCount: "Số lượng",
  abyssSize: "Kích thước",
  abyssVariant: "Biến thể",
  abyssHalf1: "Nửa 1",
  abyssHalf2: "Nửa 2",
  abyssPickTeam: "Chọn nhân vật cho mỗi nửa tầng 12",
  abyssClearSlot: "Bỏ",
  abyssTeamHint:
    "Công cụ tìm đội hình theo mô hình sát thương nằm trong NS Launcher trên macOS. Trang này đọc chu kỳ hiện tại, cộng hưởng, và độ khớp Ley Line — không mô phỏng DPS.",
  homeStoryLead:
    "Chín chương từ Mondstadt tới Snezhnaya, danh mục nhiệm vụ, và hồ sơ nhân vật liên kết với nhau.",
  homeAbyssLead:
    "Roster, nhập UID, tìm đội hình tầng 12, chu kỳ quái, catalog nhân vật/vũ khí/thánh di vật và cộng hưởng.",
  homeOpen: "Mở",
  formulaTitle: "Công thức sát thương",
  twoPiece: "2 món",
  fourPiece: "4 món",
  constellations: "Cung mệnh",
  passives: "Nội tại",
  talents: "Thiên phú",
  normalAttack: "Đòn thường",
  skill: "Kỹ năng nguyên tố",
  burst: "Kỹ năng nộ",
  baseStats: "Chỉ số cơ bản",
  acquisition: "Cách nhận",
  bestOn: "Phù hợp",
  domain: "Bí cảnh",
  roleNotes: "Ghi chú La Hoàn",
  lv90: "Cấp 90",
  lv1: "Cấp 1",
  kitTitle: "Kit (cách chơi)",
  refineTable: "Tinh luyện",
  taggedCharacters: "Nhân vật",
  lunarBonus: "Tăng sát thương Lunar theo chỉ số",
  lunarCap: "Trần buff",
  currentCycle: "Chu kỳ hiện tại",
  previousCycle: "Chu kỳ trước",
  expired: "Đã hết hạn",
  abyssRoster: "Roster của tôi",
  abyssResults: "Đội hình gợi ý",
  abyssFindTeams: "Tìm đội hình",
  abyssSearching: "Đang tìm...",
  abyssImportUID: "Nhập từ UID",
  abyssUIDPlaceholder: "UID (9-10 chữ số)",
  abyssImport: "Nhập",
  abyssUIDHint:
    'Qua Enka.Network — không cần đăng nhập. Tối đa 8 nhân vật; cần bật "Hiển thị chi tiết nhân vật" trong game. Chạy qua `npm run dev` để proxy Enka.',
  abyssImportFull: "Nhập toàn bộ roster",
  abyssHoyolabHint:
    "Dán ltuid_v2/ltoken_v2 từ cookie hoyolab.com. Cần bật Character Details. Chỉ hoạt động khi chạy Vite (có proxy).",
  abyssMethodology:
    "Điểm là thang xếp hạng theo Ley Line, cộng hưởng và vai trò — không phải mô phỏng DPS của NS Launcher trên macOS.",
  abyssFullChars: "So sánh toàn bộ nhân vật",
  abyssFullWeapons: "So sánh toàn bộ vũ khí",
  abyssOwnedOnly: "Chỉ đồ đang có",
  abyssSortRarity: "Số sao",
  abyssSortName: "Tên",
  abyssSortOwned: "Đang sở hữu",
  abyssConstellationNote: "Cung mệnh được lưu nhưng chưa tính vào điểm.",
  abyssExport: "Xuất",
  abyssClearCharacters: "Xoá hết nhân vật",
  abyssClearWeapons: "Xoá hết vũ khí",
  abyssEmptyRoster: "Roster còn trống. Đánh dấu nhân vật và vũ khí bạn đang có, hoặc nhập từ UID/file.",
  abyssNoResultsHint: 'Bấm "Tìm đội hình" để bắt đầu.',
  abyssHalfPlanNotice: "Tầng 12 là hai lượt đánh. Mỗi phương án gồm một đội cho mỗi nửa, không ai đứng cả hai.",
  abyssClearApprox: "≈ để dọn",
};

const en: Copy = {
  brand: "Teyvat Chronicle",
  tagline: "Story and Spiral Abyss, retold in Vietnamese",
  home: "Home",
  story: "Story",
  abyss: "Abyss",
  storySearch: "Search characters, chapters, quests…",
  storyChapters: "Story",
  storyEntities: "Characters & events",
  storyQuests: "Quests",
  storyAppearsIn: "Appears in",
  storyRelatedQuests: "Related quests",
  storyNoSummary: "No summary yet.",
  storyAlsoKnownAs: "Also known as",
  storyEmpty: "No results.",
  storySelect: "Pick a chapter, character, or quest on the left.",
  storyCopyright:
    "Genshin Impact and its characters, locations, and original story are property of HoYoverse. This is a personal, non-commercial retelling for reference — not a translation or reproduction of in-game text.",
  storyOpenToc: "Contents",
  entityCharacter: "Character",
  entityArchon: "Archon",
  entityFaction: "Faction",
  entityNation: "Nation",
  entityEvent: "Event",
  entityConcept: "Concept",
  turningPoint: "Turning point",
  openMystery: "Open mystery",
  note: "Note",
  abyssCycle: "Cycle",
  abyssCharacters: "Characters",
  abyssWeapons: "Weapons",
  abyssArtifacts: "Artifacts",
  abyssResonance: "Resonance",
  abyssTeam: "Teams",
  abyssMonsters: "Monsters",
  abyssSearchCharacters: "Search characters",
  abyssSearchWeapons: "Search weapons",
  abyssSearchArtifacts: "Search artifacts",
  abyssAll: "All",
  abyssOwnedHint: "Tap to add to a team",
  abyssEmpty: "Nothing matches.",
  abyssBlessing: "Blessing of the Abyssal Moon",
  abyssLeyLine: "Ley Line Disorder",
  abyssRecommendation: "Recommendation",
  abyssChamber: "Chamber",
  abyssWave: "Wave",
  abyssLevel: "Lv.",
  abyssHP: "HP",
  abyssRes: "RES",
  abyssMechanics: "Mechanics",
  abyssSpawns: "Spawns",
  abyssHPEach: "HP each",
  abyssHPTotal: "Total HP",
  abyssHPRatio: "HP ratio",
  abyssWeakpoint: "Weak point",
  abyssCount: "Count",
  abyssSize: "Size",
  abyssVariant: "Variant",
  abyssHalf1: "First half",
  abyssHalf2: "Second half",
  abyssPickTeam: "Pick characters for each floor-12 half",
  abyssClearSlot: "Clear",
  abyssTeamHint:
    "The damage-model team finder lives in the macOS NS Launcher. This page reads the current cycle, resonances, and Ley Line fit — it does not simulate DPS.",
  homeStoryLead:
    "Nine chapters from Mondstadt to Snezhnaya, a quest catalogue, and a linked character glossary.",
  homeAbyssLead:
    "Roster, UID import, floor-12 team search, the current cycle, character/weapon/artifact catalogs, and resonance.",
  homeOpen: "Open",
  formulaTitle: "Damage formula",
  twoPiece: "2-piece",
  fourPiece: "4-piece",
  constellations: "Constellations",
  passives: "Passives",
  talents: "Talents",
  normalAttack: "Normal Attack",
  skill: "Elemental Skill",
  burst: "Elemental Burst",
  baseStats: "Base stats",
  acquisition: "How to obtain",
  bestOn: "Best on",
  domain: "Domain",
  roleNotes: "Abyss notes",
  lv90: "Lv. 90",
  lv1: "Lv. 1",
  kitTitle: "Kit (how it's played)",
  refineTable: "Refinement",
  taggedCharacters: "Characters",
  lunarBonus: "Lunar reaction bonus by stat",
  lunarCap: "Bonus cap",
  currentCycle: "Current cycle",
  previousCycle: "Previous cycle",
  expired: "Expired",
  abyssRoster: "My roster",
  abyssResults: "Suggested teams",
  abyssFindTeams: "Find teams",
  abyssSearching: "Searching...",
  abyssImportUID: "Import from UID",
  abyssUIDPlaceholder: "UID (9-10 digits)",
  abyssImport: "Import",
  abyssUIDHint:
    'Via Enka.Network — no login. Up to 8 characters; needs "Show Character Details" in game. Use `npm run dev` so the Enka proxy is available.',
  abyssImportFull: "Import full roster",
  abyssHoyolabHint:
    "Paste ltuid_v2/ltoken_v2 from hoyolab.com cookies. Needs Character Details on. Works when served through Vite (proxy).",
  abyssMethodology:
    "Scores rank teams by Ley Line fit, resonance and role — they are not the macOS NS Launcher damage simulation.",
  abyssFullChars: "Compare across all characters",
  abyssFullWeapons: "Compare across all weapons",
  abyssOwnedOnly: "Owned only",
  abyssSortRarity: "Stars",
  abyssSortName: "Name",
  abyssSortOwned: "Owned",
  abyssConstellationNote: "C-level is saved but does not affect scoring yet.",
  abyssExport: "Export",
  abyssClearCharacters: "Clear characters",
  abyssClearWeapons: "Clear weapons",
  abyssEmptyRoster: "Nothing in your roster yet. Mark what you own, or import from UID/file.",
  abyssNoResultsHint: 'Press "Find teams" to search.',
  abyssHalfPlanNotice: "Floor 12 is two fights. Each plan is a team for each half, with nobody in both.",
  abyssClearApprox: "≈ to clear",
};

const ALL: Record<Lang, Copy> = { vi, en };

export function t(lang: Lang): Copy {
  return ALL[lang];
}

export function entityKindLabel(lang: Lang, kind: string): string {
  const copy = t(lang);
  switch (kind) {
    case "character":
      return copy.entityCharacter;
    case "archon":
      return copy.entityArchon;
    case "faction":
      return copy.entityFaction;
    case "nation":
      return copy.entityNation;
    case "event":
      return copy.entityEvent;
    case "concept":
      return copy.entityConcept;
    default:
      return kind;
  }
}
