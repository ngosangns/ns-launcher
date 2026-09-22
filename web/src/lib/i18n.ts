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
  back: string;
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
  abyssRoster: string;
  abyssResults: string;
  abyssInfo: string;
  abyssFindTeams: string;
  abyssSearching: string;
  abyssImport: string;
  abyssImportFull: string;
  abyssHoyolabHint: string;
  abyssMethodology: string;
  abyssFallbackNote: string;
  abyssShockwave: string;
  abyssOnField: string;
  abyssFullChars: string;
  abyssFullWeapons: string;
  abyssOwnedOnly: string;
  abyssSort: string;
  abyssSortRarity: string;
  abyssSortName: string;
  abyssSortOwned: string;
  abyssSortAtk: string;
  abyssConstellationNote: string;
  abyssExport: string;
  abyssClearCharacters: string;
  abyssClearWeapons: string;

  abyssNoResultsHint: string;
  abyssHalfPlanNotice: string;
  abyssClearApprox: string;
};

const vi: Copy = {
  brand: "Ký Sự Teyvat",
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
  back: "Quay lại",
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
  abyssChamber: "Phòng",
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
    "Tìm đội hình bằng một vòng đánh 20 giây: hồi chiêu, năng lượng, đòn đánh và phản ứng trên một mục tiêu. Thời gian dọn là HP nửa tầng chia cho sát thương mỗi giây.",
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
  abyssRoster: "Roster của tôi",
  abyssResults: "Đội hình gợi ý",
  abyssInfo: "Chi tiết",
  abyssFindTeams: "Tìm đội hình",
  abyssSearching: "Đang tìm...",
  abyssImport: "Nhập",
  abyssImportFull: "Nhập từ token",
  abyssHoyolabHint:
    "Dán ltuid_v2 và ltoken_v2. Nếu tài khoản có nhiều UID, lấy UID cấp cao nhất. Cần bật Character Details.",
  abyssMethodology:
    "Điểm là sát thương mỗi giây của một vòng đánh 20 giây: hồi chiêu, năng lượng, đòn và phản ứng trên một mục tiêu. Thời gian dọn bằng HP nửa tầng chia cho điểm đó. Quái nhiều con được tính bằng tổng HP.",
  abyssFallbackNote: "Chưa có kit chiêu, mỗi dòng talent tính một lần",
  abyssShockwave: "Sóng xung kích",
  abyssOnField: "đứng sân",
  abyssFullChars: "So sánh toàn bộ nhân vật",
  abyssFullWeapons: "So sánh toàn bộ vũ khí",
  abyssOwnedOnly: "Chỉ đồ đang có",
  abyssSort: "Sắp xếp",
  abyssSortRarity: "Số sao",
  abyssSortName: "Tên",
  abyssSortOwned: "Đang sở hữu",
  abyssSortAtk: "Tấn công",
  abyssConstellationNote: "Cung mệnh được lưu nhưng chưa tính vào điểm.",
  abyssExport: "Xuất",
  abyssClearCharacters: "Xoá hết nhân vật",
  abyssClearWeapons: "Xoá hết vũ khí",

  abyssNoResultsHint: 'Bấm "Tìm đội hình" để bắt đầu.',
  abyssHalfPlanNotice: "Tầng 12 là hai lượt đánh. Mỗi phương án gồm một đội cho mỗi nửa, không ai đứng cả hai.",
  abyssClearApprox: "≈ để dọn",
};

const en: Copy = {
  brand: "Teyvat Chronicle",
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
  back: "Back",
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
    "Team search simulates a 20-second rotation: cooldowns, energy, hits and reactions on one target. Clear time is that half's HP divided by damage per second.",
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
  abyssRoster: "My roster",
  abyssResults: "Suggested teams",
  abyssInfo: "Details",
  abyssFindTeams: "Find teams",
  abyssSearching: "Searching...",
  abyssImport: "Import",
  abyssImportFull: "Import from token",
  abyssHoyolabHint:
    "Paste ltuid_v2 and ltoken_v2. If the account has several UIDs, the highest-level one is used. Character Details must be on.",
  abyssMethodology:
    "The score is damage per second over a 20-second rotation: cooldowns, energy, hits and reactions on one target. Clear time is that half's HP divided by the score. Several enemies count as their combined HP.",
  abyssFallbackNote: "No attack kit yet, so each talent line is counted once",
  abyssShockwave: "Shockwave",
  abyssOnField: "on field",
  abyssFullChars: "Compare across all characters",
  abyssFullWeapons: "Compare across all weapons",
  abyssOwnedOnly: "Owned only",
  abyssSort: "Sort",
  abyssSortRarity: "Stars",
  abyssSortName: "Name",
  abyssSortOwned: "Owned",
  abyssSortAtk: "ATK",
  abyssConstellationNote: "C-level is saved but does not affect scoring yet.",
  abyssExport: "Export",
  abyssClearCharacters: "Clear characters",
  abyssClearWeapons: "Clear weapons",

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
