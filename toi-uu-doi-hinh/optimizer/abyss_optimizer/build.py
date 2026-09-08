"""Dựng chỉ số (build) cho 1 nhân vật: nhân vật + vũ khí + thánh di vật."""

from __future__ import annotations

import re
from dataclasses import dataclass, field

from . import tuning
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

    rules: list[tuple[str, str]] = [
        ("crit rate", "crit_rate"),
        ("crit dmg", "crit_dmg"),
        ("elemental mastery", "em"),
        ("energy recharge", "er"),
        ("healing bonus", "healing_bonus"),
        ("healing effectiveness", "healing_bonus"),
        ("normal/charged/plunging attack dmg", "dmg_normal"),
        ("normal/charged attack dmg", "dmg_normal"),
        ("normal attack dmg", "dmg_normal"),
        ("charged attack dmg", "dmg_charged"),
        ("plunging attack dmg", "dmg_normal"),
        ("elemental skill and burst dmg", "dmg_skill"),
        ("elemental skill dmg", "dmg_skill"),
        ("elemental burst dmg", "dmg_burst"),
        ("physical dmg", "dmg_all"),
        ("max hp", "hp_pct"),
        ("atk%", "atk_pct"),
        ("hp%", "hp_pct"),
        ("def%", "def_pct"),
    ]
    for needle, attr in rules:
        if needle in key:
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
        if abs(value) > 3:  # % của một đòn đánh, không phải buff chỉ số
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

    if len(sets) == 1:  # 4 món 1 bộ -> ăn cả 2pc lẫn 4pc
        _artifact_bonus(stats, sets[0]["twoPiece"]["bonuses"])
        _artifact_bonus(stats, sets[0]["fourPiece"]["bonuses"])
        approx = tuning.SET_EFFECT_APPROX.get(sets[0]["id"])
        if approx:
            _, value, scope, requirement = approx
            if _set_requirement_met(character, requirement):
                attr = {"all": "dmg_all", "normal": "dmg_normal", "charged": "dmg_charged",
                        "skill": "dmg_skill", "burst": "dmg_burst"}[scope]
                setattr(stats, attr, getattr(stats, attr) + value)
    else:  # 2 + 2
        for artifact_set in sets:
            _artifact_bonus(stats, artifact_set["twoPiece"]["bonuses"])

    return stats
