"""Dựng chỉ số (build) cho 1 nhân vật: nhân vật + vũ khí + thánh di vật."""

from __future__ import annotations

import re
from dataclasses import dataclass, field

from . import tuning
from . import data as gdata
from .data import PARSE, ELEMENTS, scaling_basis

ROLES = ["main-dps", "sub-dps", "support", "shield", "healer"]


@dataclass
class Stats:
    base_atk: float = 0.0     # ATK gốc nhân vật + ATK gốc vũ khí
    base_hp: float = 0.0
    base_def: float = 0.0
    atk_pct: float = 0.0
    hp_pct: float = 0.0
    def_pct: float = 0.0
    flat_atk: float = 0.0
    flat_hp: float = 0.0
    flat_def: float = 0.0
    em: float = 0.0
    er: float = 1.0           # 100% cơ bản
    crit_rate: float = 0.05   # 5% cơ bản
    crit_dmg: float = 0.50    # 50% cơ bản
    healing_bonus: float = 0.0
    # % sát thương theo loại
    dmg_elemental: dict[str, float] = field(default_factory=dict)
    dmg_all: float = 0.0
    dmg_normal: float = 0.0
    dmg_charged: float = 0.0
    dmg_skill: float = 0.0
    dmg_burst: float = 0.0
    # buff cấp đội (áp cho cả 4 người)
    party_atk_pct: float = 0.0
    party_em: float = 0.0
    party_dmg: float = 0.0
    # ATK phẳng phát cho cả đội. Kênh riêng với party_atk_pct vì các buff chiếm
    # chỗ này (Bennett, Kujou Sara) là một phần ATK CƠ BẢN CỦA NGƯỜI BUFF phát ra
    # dưới dạng số phẳng; gộp vào % sẽ nhân theo ATK cơ bản của người nhận —
    # một đại lượng khác và sai.
    party_flat_atk: float = 0.0
    # DMG Bonus theo nguyên tố phát cho cả đội. Khác party_dmg (áp cho mọi
    # nguyên tố): buff chỉ nâng Anemo không được nâng luôn damage của người Pyro.
    party_elemental_dmg: dict[str, float] = field(default_factory=dict)

    @property
    def atk(self) -> float:
        return self.base_atk * (1 + self.atk_pct) + self.flat_atk

    @property
    def hp(self) -> float:
        return self.base_hp * (1 + self.hp_pct) + self.flat_hp

    @property
    def defense(self) -> float:
        return self.base_def * (1 + self.def_pct) + self.flat_def

    def stat_for_basis(self, basis: str) -> float:
        return {"ATK": self.atk, "HP": self.hp, "DEF": self.defense, "EM": self.em}[basis]

    def crit_multiplier(self) -> float:
        """Kỳ vọng: 1 + CR×CD (CR chặn ở 100%)."""
        return 1 + min(max(self.crit_rate, 0.0), 1.0) * self.crit_dmg

    def elemental_bonus(self, element: str) -> float:
        return self.dmg_elemental.get(element, 0.0)


# ---------------------------------------------------------------------------
# Quy đổi tên chỉ số (text) -> trường trong Stats
# ---------------------------------------------------------------------------

def _apply_named_stat(stats: Stats, name: str, value: float, *, conditional: bool = False) -> bool:
    """Cộng `value` vào đúng trường theo tên chỉ số dạng text. True nếu map được."""
    if conditional:
        value *= tuning.CONDITIONAL_UPTIME
    key = name.lower()

    # Chỉ số PHẲNG: data model ghi "Max HP: 1000", "DEF: 100" (không phải %).
    # Mọi buff % trong dữ liệu đều < 3.0, nên ngưỡng này tách được an toàn.
    # (Elemental Mastery vốn luôn là số phẳng nên xử lý riêng ở bảng dưới.)
    if abs(value) > 3 and "elemental mastery" not in key:
        if "hp" in key:
            stats.flat_hp += value
            return True
        if "atk" in key:
            stats.flat_atk += value
            return True
        if "def" in key:
            stats.flat_def += value
            return True

    for element in ELEMENTS:
        if key.startswith(element.lower()) and "dmg" in key:
            stats.dmg_elemental[element] = stats.dmg_elemental.get(element, 0.0) + value
            return True

    if "party" in key or "toàn đội" in key or "cả đội" in key:
        if "atk" in key:
            stats.party_atk_pct += value
        elif "elemental mastery" in key or key.endswith(" em"):
            stats.party_em += value
        else:
            stats.party_dmg += value
        return True

    # Một nhãn có thể chạm 2 ô: "Normal/Charged Attack DMG" nâng thật cả hai, và
    # chúng là hai ô riêng vì game coi đòn thường với đòn nặng là hai hành động
    # khác nhau. Trả về 1 ô đồng nghĩa nửa "charged" của 5 bộ bị âm thầm bỏ.
    rules: list[tuple[str, list[str]]] = [
        ("crit rate", ["crit_rate"]),
        ("crit dmg", ["crit_dmg"]),
        ("elemental mastery", ["em"]),
        ("energy recharge", ["er"]),
        ("healing bonus", ["healing_bonus"]),
        ("healing effectiveness", ["healing_bonus"]),
        ("normal/charged/plunging attack dmg", ["dmg_normal", "dmg_charged"]),
        ("normal/charged attack dmg", ["dmg_normal", "dmg_charged"]),
        ("normal attack dmg", ["dmg_normal"]),
        ("charged attack dmg", ["dmg_charged"]),
        ("plunging attack dmg", ["dmg_normal"]),
        ("elemental skill and burst dmg", ["dmg_skill"]),
        ("elemental skill dmg", ["dmg_skill"]),
        ("elemental burst dmg", ["dmg_burst"]),
        ("physical dmg", ["dmg_all"]),
        ("max hp", ["hp_pct"]),
        ("atk%", ["atk_pct"]),
        ("hp%", ["hp_pct"]),
        ("def%", ["def_pct"]),
    ]
    for needle, attrs in rules:
        if needle in key:
            for attr in attrs:
                setattr(stats, attr, getattr(stats, attr) + value)
            return True

    # Tên trần: "ATK" / "HP" / "DEF" (thánh di vật ghi kiểu này = %)
    if re.fullmatch(r"atk|self atk", key):
        stats.atk_pct += value
        return True
    if re.fullmatch(r"hp", key):
        stats.hp_pct += value
        return True
    if re.fullmatch(r"def", key):
        stats.def_pct += value
        return True
    if "dmg" in key:  # các buff sát thương chung chung còn lại
        stats.dmg_all += value
        return True
    return False


def party_buff_of(bonuses: list[dict]) -> tuple[float, float, float]:
    """Phần một nhóm bonus góp cho CẢ ĐỘI: (ATK%, EM, DMG%).

    Dùng để khử trùng lặp trong `scoring.score_team`: buff phe của một bộ chỉ
    tính một lần dù mấy người cùng mặc. Đi qua đúng `_apply_named_stat` chứ
    không viết lại luật routing, nên không thể lệch khỏi phần cộng vào.
    """
    probe = Stats()
    for bonus in bonuses:
        name = bonus.get("stat", "")
        _apply_named_stat(probe, name, float(bonus.get("value", 0.0)),
                          conditional="(" in name)
    return probe.party_atk_pct, probe.party_em, probe.party_dmg


def _artifact_bonus(stats: Stats, bonuses: list[dict]) -> None:
    for bonus in bonuses:
        name = bonus.get("stat", "")
        conditional = "(" in name  # "CRIT Rate (when HP below 70%)"
        if _apply_named_stat(stats, name, float(bonus.get("value", 0.0)), conditional=conditional):
            PARSE.artifact_bonus_ok += 1
        else:
            PARSE.artifact_bonus_unmapped.append(name)


# Tên hiệu ứng mô tả MỘT ĐÒN SÁT THƯƠNG THÊM (không phải buff chỉ số) —
# vd. "AoE DMG (% ATK)", "HP Restore (% ATK)". Cộng chúng vào %DMG Bonus là sai.
_NOT_A_STAT_BUFF = re.compile(
    r"\(\s*%|cooldown|chance|restore|\bspd\b|particle|energy|reset|duration",
    re.IGNORECASE,
)

_WEAPON_EFFECT_RULES = [
    (re.compile(r"crit\s*rate", re.I), "crit_rate"),
    (re.compile(r"crit\s*dmg", re.I), "crit_dmg"),
    (re.compile(r"elemental\s*mastery|^em\b", re.I), "em"),
    (re.compile(r"energy\s*recharge", re.I), "er"),
    (re.compile(r"normal", re.I), "dmg_normal"),
    (re.compile(r"charged", re.I), "dmg_charged"),
    (re.compile(r"skill", re.I), "dmg_skill"),
    (re.compile(r"burst", re.I), "dmg_burst"),
    (re.compile(r"\batk\b", re.I), "atk_pct"),
    (re.compile(r"\bhp\b", re.I), "hp_pct"),
    (re.compile(r"\bdef\b", re.I), "def_pct"),
    (re.compile(r"dmg", re.I), "dmg_all"),
]


def _weapon_passive(stats: Stats, weapon: dict, refinement: int) -> None:
    passive = weapon.get("passive")
    if not passive:
        return
    key = f"r{max(1, min(5, refinement))}"
    for effect in passive.get("effects") or []:
        value = effect.get(key)
        if not isinstance(value, (int, float)):
            continue
        name = effect.get("stat", "")
        # Chỉ nhận các dòng thật sự là buff chỉ số ("... Buff"/"... Bonus"),
        # bỏ các dòng mô tả đòn sát thương thêm hoặc thông số phụ trợ.
        if not re.search(r"buff|bonus", name, re.I) or _NOT_A_STAT_BUFF.search(name):
            continue
        # >3 là % sát thương của một đòn, không phải buff chỉ số — TRỪ Elemental
        # Mastery, vốn là số phẳng hàng chục/hàng trăm nên LUÔN >3.
        # `_apply_named_stat` đã có ngoại lệ này cho thánh di vật từ đầu; nhánh
        # vũ khí thì không, và đã âm thầm bỏ mọi passive EM trong data.
        if abs(value) > 3 and not re.search(r"elemental\s*mastery|^em\b", name, re.I):
            continue
        if re.search(r"per stack|per seal|per .*stack", name, re.I):
            value *= tuning.ASSUMED_STACKS
        if "(" in name:  # buff có điều kiện ghi trong ngoặc
            value *= tuning.CONDITIONAL_UPTIME
        is_party = bool(re.search(r"team|party|toàn đội", name, re.I))
        for pattern, attr in _WEAPON_EFFECT_RULES:
            if pattern.search(name):
                if is_party and attr == "atk_pct":
                    stats.party_atk_pct += value
                else:
                    setattr(stats, attr, getattr(stats, attr) + value)
                break


def _substats(stats: Stats, role: str, basis: str) -> None:
    priority = dict(tuning.SUBSTAT_PRIORITY.get(role, tuning.SUBSTAT_PRIORITY["sub-dps"]))
    for src, dst in tuning.SCALING_BASIS_SWAP.get(basis, {}).items():
        if src in priority:
            priority[dst] = priority.pop(src) + priority.get(dst, 0.0)
    for stat_key, share in priority.items():
        rolls = tuning.SUBSTAT_ROLL_BUDGET * share
        value = rolls * tuning.SUBSTAT_ROLL_VALUE[stat_key]
        attr = {"crit_rate": "crit_rate", "crit_dmg": "crit_dmg", "atk_pct": "atk_pct",
                "hp_pct": "hp_pct", "def_pct": "def_pct", "em": "em", "er": "er",
                "flat_atk": "flat_atk", "flat_hp": "flat_hp", "flat_def": "flat_def"}[stat_key]
        setattr(stats, attr, getattr(stats, attr) + value)


def _artifact_main_stats(stats: Stats, role: str, basis: str, element: str) -> None:
    main = tuning.ARTIFACT_MAIN_STATS
    stats.flat_hp += main["flat_hp"]
    stats.flat_atk += main["flat_atk"]

    # Sands
    if role in ("support", "shield"):
        stats.er += main["er"]
    elif role == "healer":
        stats.hp_pct += main["hp_pct"]
    elif basis == "DEF":
        stats.def_pct += main["def_pct"]
    elif basis == "HP":
        stats.hp_pct += main["hp_pct"]
    elif basis == "EM":
        stats.em += main["em"]
    else:
        stats.atk_pct += main["atk_pct"]

    # Goblet
    stats.dmg_elemental[element] = stats.dmg_elemental.get(element, 0.0) + main["elemental_dmg"]

    # Circlet
    if role == "healer":
        stats.healing_bonus += main["healing_bonus"]
    else:
        stats.crit_dmg += main["crit_dmg"]


MOONSIGN_IDS: set[str] = set()  # nạp từ team-bonus.json khi khởi động


def _set_requirement_met(character: dict, requirement: str | None) -> bool:
    if requirement is None:
        return True
    if requirement == "natlan":
        return character.get("nationInGame") == "Natlan"
    if requirement == "moonsign":
        return character["id"] in MOONSIGN_IDS
    if requirement == "stellar":
        return character["element"] in ("Cryo", "Electro", "Anemo")
    return True


def _talent_party_buffs(stats: Stats, character: dict) -> None:
    """Buff cả đội đến từ chiêu của chính nhân vật này.

    Gọi SAU vũ khí, vì `flat-atk-from-base-atk` là một phần ATK cơ bản của người
    buff, mà ATK cơ bản = nhân vật + vũ khí — Bennett cầm thương mạnh hơn thì
    buff cho đội cũng mạnh hơn thật.

    Kết quả rơi vào các trường `party_*`, thứ mà scorer phát cho cả 4 người.
    Không có gì ở đây đụng vào chỉ số riêng của người buff; đó là cái ngăn buff
    bị tính một lần cho bản thân rồi một lần nữa cho cả đội.
    """
    element = character["element"]
    for entry in tuning.TALENT_PARTY_BUFF:
        if entry["characterId"] != character["id"]:
            continue
        talent = character["elementalSkill"] if entry["talent"] == "skill" else character["elementalBurst"]
        value = gdata.talent_percentage(talent, entry["label"], entry.get("valueIndex", 0))
        if value is None:
            gdata.PARSE.talent_party_buff_unresolved.append(f"{entry['characterId']}: {entry['label']}")
            continue
        value *= entry["uptime"]
        if entry["kind"] == "flat-atk-from-base-atk":
            stats.party_flat_atk += value * stats.base_atk
        elif entry["kind"] == "elemental-dmg":
            stats.party_elemental_dmg[element] = stats.party_elemental_dmg.get(element, 0.0) + value


def build_stats(character: dict, weapon: dict | None, sets: list[dict], role: str,
                refinement: int = 1) -> Stats:
    """Ghép chỉ số cuối cùng ở cấp 90, thánh di vật 5★ cấp 20."""
    lv90 = character["baseStats"]["lv90"]
    stats = Stats(
        base_atk=float(lv90.get("atk") or 0.0),
        base_hp=float(lv90.get("hp") or 0.0),
        base_def=float(lv90.get("def") or 0.0),
    )
    basis = scaling_basis(character)
    element = character["element"]

    # Chỉ số đột phá của nhân vật
    asc_type, asc_value = lv90.get("ascensionStatType"), lv90.get("ascensionStatValue")
    if asc_type and isinstance(asc_value, (int, float)):
        _apply_named_stat(stats, asc_type, float(asc_value))

    if weapon:
        stats.base_atk += float(weapon.get("atkLv90") or 0.0)
        sub = weapon.get("subStat") or {}
        if sub.get("type") and isinstance(sub.get("valueLv90"), (int, float)):
            _apply_named_stat(stats, sub["type"], float(sub["valueLv90"]))
        _weapon_passive(stats, weapon, refinement)

    _artifact_main_stats(stats, role, basis, element)
    _substats(stats, role, basis)
    _talent_party_buffs(stats, character)

    if len(sets) == 1:  # 4 món 1 bộ -> ăn cả 2pc lẫn 4pc
        _artifact_bonus(stats, sets[0]["twoPiece"]["bonuses"])
        _artifact_bonus(stats, sets[0]["fourPiece"]["bonuses"])
        approx = tuning.SET_EFFECT_APPROX.get(sets[0]["id"])
        if approx:
            _, value, scope, requirement, party = approx
            if _set_requirement_met(character, requirement):
                attr = "party_dmg" if party else {
                    "all": "dmg_all", "normal": "dmg_normal", "charged": "dmg_charged",
                    "skill": "dmg_skill", "burst": "dmg_burst"}[scope]
                setattr(stats, attr, getattr(stats, attr) + value)
    else:  # 2 + 2
        for artifact_set in sets:
            _artifact_bonus(stats, artifact_set["twoPiece"]["bonuses"])

    return stats
