"""Công thức sát thương + chấm điểm đội hình cho 1 tầng Trầm Thủy.

Triển khai đúng theo `Sources/NSLauncherApp/Resources/Abyss/damage-formula.json` (mục 1.6-1.8, 2)
cho phần công thức lõi; phần rotation/uptime là heuristic (xem `tuning.py`).
"""

from __future__ import annotations

import itertools
import re
from dataclasses import dataclass, field

from . import tuning
from .build import Stats
from .data import (
    ELEMENTS,
    FloorBuff,
    normal_attack_combo,
    parse_floor_buffs,
    parse_res_notes,
    talent_damage_entries,
)

CHARACTER_LEVEL = 90


# ---------------------------------------------------------------------------
# Công thức lõi (damage-formula.json)
# ---------------------------------------------------------------------------

def def_multiplier(char_level: int, monster_level: int, def_reduction: float = 0.0,
                   def_ignore: float = 0.0) -> float:
    k = (1 - def_reduction) * (1 - def_ignore)
    return (char_level + 100) / (k * (monster_level + 100) + (char_level + 100))


def res_multiplier(res: float) -> float:
    if res < 0:
        return 1 - res / 2
    if res < 0.75:
        return 1 - res
    return 1 / (4 * res + 1)


def em_bonus_amplifying(em: float) -> float:
    return 2.78 * em / (em + 1400)


def amplifying_multiplier(coefficient: float, em: float, reaction_bonus: float = 0.0) -> float:
    return coefficient * (1 + em_bonus_amplifying(em) + reaction_bonus)


# ---------------------------------------------------------------------------
# Bối cảnh tầng
# ---------------------------------------------------------------------------

@dataclass
class FloorContext:
    floor: int
    monster_level: int
    res: dict[str, float]                       # kháng trung bình theo nguyên tố
    buffs: list[FloorBuff] = field(default_factory=list)
    shield_elements: list[str] = field(default_factory=list)
    label: str = ""

    def res_for(self, element: str) -> float:
        return self.res.get(element, 0.10)      # mặc định 10% theo damage-formula.json


_SHIELD_HINT = re.compile(r"khiên\s+([A-Za-zÀ-ỹ]+)", re.IGNORECASE)
_COUNTER_ELEMENT = {  # nguyên tố phá khiên tương ứng
    "Cryo": ["Pyro"], "Pyro": ["Hydro"], "Electro": ["Cryo", "Hydro"],
    "Hydro": ["Electro", "Cryo"], "Geo": ["Dendro", "Anemo"], "Anemo": ["Anemo"],
    "Dendro": ["Pyro"],
}


def build_floor_context(cycle: dict, floor_number: int) -> FloorContext:
    floor = next(f for f in cycle["floors"] if f["floor"] == floor_number)

    levels, res_samples, shields = [], {e: [] for e in ELEMENTS}, []
    for chamber in floor["chambers"]:
        if chamber.get("monsterLevel"):
            levels.append(chamber["monsterLevel"])
        for wave in chamber["waves"]:
            for monster in wave["monsters"]:
                for element, delta in parse_res_notes(monster.get("resistanceNotes")).items():
                    if element in res_samples:
                        res_samples[element].append(0.10 + delta)
                mechanics = " ".join(filter(None, [monster.get("mechanics"), monster.get("resistanceNotes")]))
                for match in _SHIELD_HINT.finditer(mechanics or ""):
                    from .data import _norm_element  # noqa: PLC0415  (bảng dịch nội bộ)
                    element = _norm_element(match.group(1))
                    if element and element != "Physical":
                        shields.append(element)

    res = {e: sum(v) / len(v) for e, v in res_samples.items() if v}
    buffs = parse_floor_buffs(floor.get("leyLineDisorder"))
    blessing = cycle.get("blessingOfTheAbyssalMoon") or {}
    buffs += parse_floor_buffs(blessing.get("description"))

    return FloorContext(
        floor=floor_number,
        monster_level=round(sum(levels) / len(levels)) if levels else 90,
        res=res,
        buffs=buffs,
        shield_elements=sorted(set(shields)),
        label=f"Tầng {floor_number}",
    )


# ---------------------------------------------------------------------------
# Bối cảnh đội
# ---------------------------------------------------------------------------

_HEAL_HINT = re.compile(r"hồi máu|heal", re.IGNORECASE)
_SHIELD_HINT_TALENT = re.compile(r"khiên|shield", re.IGNORECASE)
# Hồi máu/khiên chỉ tính là "chống chịu cho đội" khi mô tả nói rõ phạm vi đội.
# Nếu không, đó là tự hồi cho bản thân (Hu Tao đốt máu rồi tự hồi khi bung Nộ)
# — không giúp đội sống sót nên không được tính là healer.
_PARTY_SCOPE = re.compile(
    r"cả đội|toàn đội|đồng đội|trong vùng|đang chiến đấu|party|all characters|nearby",
    re.IGNORECASE,
)


def capabilities(character: dict) -> tuple[bool, bool]:
    """(có thể hồi máu, có thể tạo khiên) — suy từ NHÃN hệ số kỹ năng.

    Chỉ đọc nhãn (vd. "Hồi máu", "Khiên hấp thụ") chứ không đọc phần mô tả,
    vì mô tả của nhiều DPS cũng nhắc tới HP mà không hề hồi máu (Hu Tao đốt
    HP, Chongyun, Xiao...) — đọc mô tả sẽ nhận nhầm họ là healer.
    """
    can_heal = can_shield = False
    for key in ("elementalSkill", "elementalBurst"):
        talent = character[key]
        labels = " ".join(entry.get("label", "") for entry in (talent.get("scaling") or []))
        # Hồi máu: phải hồi cho đội mới tính (xem _PARTY_SCOPE).
        if _HEAL_HINT.search(labels) and _PARTY_SCOPE.search(talent.get("description", "")):
            can_heal = True
        # Khiên: trong Genshin khiên vốn chỉ che nhân vật đang đứng sân, nên
        # không đòi hỏi phạm vi đội — có khiên là có chống chịu.
        if _SHIELD_HINT_TALENT.search(labels):
            can_shield = True
    return can_heal, can_shield


@dataclass
class TeamContext:
    elements: list[str]
    resonances: list[dict] = field(default_factory=list)
    moonsign_level: int = 0
    hexerei: bool = False
    has_heal: bool = False
    has_shield: bool = False
    stellar_jubilee: bool = False

    @property
    def element_set(self) -> set[str]:
        return set(self.elements)


# Định nghĩa trong `tuning.json` để bản Swift đọc chung cùng một danh sách.
STELLAR_JUBILEE_IDS = tuning.STELLAR_JUBILEE_IDS


def build_team_context(members: list[dict], team_bonus: dict) -> TeamContext:
    elements = [c["element"] for c in members]
    ids = {c["id"] for c in members}

    resonances = []
    for resonance in team_bonus["elementalResonance"]:
        if resonance.get("requiresUniqueElements"):
            if len(set(elements)) == 4 and len(elements) == 4:
                resonances.append(resonance)
        else:
            element = resonance["elements"][0]
            if elements.count(element) >= resonance["requiredCount"]:
                resonances.append(resonance)

    moonsign_count = len(ids & set(team_bonus["moonsign"]["characterIds"]))
    hexerei_count = len(ids & set(team_bonus["hexerei"]["characterIds"]))

    heal = shield = False
    for character in members:
        can_heal, can_shield = capabilities(character)
        heal = heal or can_heal
        shield = shield or can_shield

    return TeamContext(
        elements=elements,
        resonances=resonances,
        moonsign_level=min(moonsign_count, 2),
        hexerei=hexerei_count >= team_bonus["hexerei"]["requiredCount"],
        has_heal=heal,
        has_shield=shield,
        stellar_jubilee=bool(ids & STELLAR_JUBILEE_IDS),
    )


_AMPLIFYING = {  # (nguyên tố người kích hoạt, nguyên tố cần có sẵn) -> hệ số
    ("Pyro", "Hydro"): 1.5,
    ("Pyro", "Cryo"): 2.0,
    ("Hydro", "Pyro"): 2.0,
    ("Cryo", "Pyro"): 1.5,
}


def amplifying_for(element: str, team_elements: set[str]) -> float:
    best = 1.0
    for (trigger, target), coefficient in _AMPLIFYING.items():
        if element == trigger and target in team_elements:
            best = max(best, coefficient)
    return best


def _reactions_enabled(team: TeamContext) -> set[str]:
    elements = team.element_set
    found = set()
    if {"Pyro", "Hydro"} <= elements:
        found.add("Vaporize")
    if {"Pyro", "Cryo"} <= elements:
        found.add("Melt")
    if {"Electro", "Cryo"} <= elements:
        found.add("Stellar-Conduct" if team.stellar_jubilee else "Superconduct")
    if {"Anemo", "Cryo"} <= elements and team.stellar_jubilee:
        found.add("Stellar Swirl")
    if {"Electro", "Hydro"} <= elements:
        found.add("Lunar-Charged" if team.moonsign_level >= 1 else "Electro-Charged")
    if {"Electro", "Pyro"} <= elements:
        found.add("Overloaded")
    if {"Geo", "Hydro"} <= elements and team.moonsign_level >= 1:
        found.add("Lunar-Crystallize")
    if {"Dendro", "Hydro"} <= elements:
        found.add("Lunar-Bloom" if team.moonsign_level >= 1 else "Bloom")
    return found


# ---------------------------------------------------------------------------
# Sát thương 1 nhân vật trong 1 rotation
# ---------------------------------------------------------------------------

def _floor_bonus(floor: FloorContext, element: str, reactions: set[str],
                 is_normal_attack: bool) -> float:
    """Tổng % cộng thêm từ Ley Line Disorder + Uyên Nguyệt Chúc Phúc."""
    bonus = 0.0
    for buff in floor.buffs:
        if buff.reactions and not (set(buff.reactions) & reactions):
            continue
        if buff.elements and element not in buff.elements:
            continue
        if buff.normal_attack_only and not is_normal_attack:
            continue
        if not buff.reactions and not buff.elements and not buff.normal_attack_only:
            continue
        bonus += buff.bonus
    return bonus


_PROFILE_CACHE: dict[str, list[tuple[float, str, str]]] = {}


def damage_profile(character: dict) -> list[tuple[float, str, str]]:
    """(hệ số, trục scale, loại đòn) của 1 nhân vật — parse 1 lần rồi cache."""
    cached = _PROFILE_CACHE.get(character["id"])
    if cached is not None:
        return cached
    profile: list[tuple[float, str, str]] = []
    for multiplier, basis in talent_damage_entries(character["elementalSkill"]):
        profile.append((multiplier, basis, "skill"))
    for multiplier, basis in talent_damage_entries(character["elementalBurst"]):
        profile.append((multiplier, basis, "burst"))
    for multiplier, basis in normal_attack_combo(character):
        profile.append((multiplier, basis, "normal"))
    _PROFILE_CACHE[character["id"]] = profile
    return profile


def character_damage(character: dict, stats: Stats, *, on_field: bool,
                     floor: FloorContext, team: TeamContext,
                     party_buffs: tuple[float, float, float]) -> float:
    """Sát thương ước lượng của 1 nhân vật trong 1 rotation."""
    element = character["element"]
    party_atk_pct, party_em, party_dmg = party_buffs
    reactions = _reactions_enabled(team)

    effective = Stats(**{**stats.__dict__})
    effective.atk_pct += party_atk_pct
    effective.em += party_em
    effective.dmg_all += party_dmg

    res_mult = res_multiplier(floor.res_for(element))
    def_mult = def_multiplier(CHARACTER_LEVEL, floor.monster_level)
    crit_mult = effective.crit_multiplier()

    amp = amplifying_for(element, team.element_set)
    if amp > 1.0:
        amp_mult = amplifying_multiplier(amp, effective.em)
        amp_factor = 1 + tuning.AMPLIFYING_UPTIME * (amp_mult - 1)
    else:
        amp_factor = 1.0

    def hit_damage(multiplier: float, basis: str, category: str) -> float:
        base = multiplier * effective.stat_for_basis(basis)
        bonus = (effective.dmg_all + effective.elemental_bonus(element)
                 + getattr(effective, f"dmg_{category}", 0.0)
                 + _floor_bonus(floor, element, reactions, category == "normal"))
        return base * (1 + bonus) * def_mult * res_mult * crit_mult * amp_factor

    profile = damage_profile(character)
    ability = sum(hit_damage(m, b, cat) for m, b, cat in profile if cat != "normal")
    if not on_field:
        return ability * tuning.OFFFIELD_UPTIME

    combo = sum(hit_damage(m, b, "normal") for m, b, cat in profile if cat == "normal")
    return ability + combo * tuning.NORMAL_COMBOS_PER_ROTATION


# ---------------------------------------------------------------------------
# Chấm điểm đội
# ---------------------------------------------------------------------------

@dataclass
class GearOption:
    """Một phương án trang bị của 1 nhân vật (1 vũ khí + bộ thánh di vật hợp nhất)."""

    stats: Stats
    weapon: dict | None
    sets: list[dict]
    role: str
    solo_score: float


@dataclass
class TeamResult:
    member_ids: list[str]
    on_field_id: str
    score: float
    per_character: dict[str, float]
    context: TeamContext
    assignment: dict[str, GearOption] = field(default_factory=dict)
    notes: list[str] = field(default_factory=list)


def assign_gear(members: list[dict], options: dict[str, list[GearOption]]) -> dict[str, GearOption]:
    """Chia vũ khí cho 4 người, mỗi vũ khí chỉ 1 người dùng.

    Người có điểm solo cao nhất được ưu tiên chọn trước; người sau lấy phương
    án tốt nhất còn lại. (Mỗi vũ khí giả định chỉ sở hữu 1 bản — thánh di vật
    thì không giới hạn vì bộ nào cũng farm thêm được.)
    """
    order = sorted(members, key=lambda c: options[c["id"]][0].solo_score, reverse=True)
    taken: set[str] = set()
    chosen: dict[str, GearOption] = {}
    for character in order:
        for option in options[character["id"]]:
            weapon_id = option.weapon["id"] if option.weapon else None
            if weapon_id is None or weapon_id not in taken:
                chosen[character["id"]] = option
                if weapon_id:
                    taken.add(weapon_id)
                break
        else:  # hết phương án -> dùng phương án tốt nhất dù trùng vũ khí
            chosen[character["id"]] = options[character["id"]][0]
    return chosen


def _resonance_stats(team: TeamContext) -> tuple[float, float, float]:
    """Cộng hưởng nguyên tố -> (atk%, em, dmg%) áp cho cả đội."""
    atk_pct = em = dmg = 0.0
    for resonance in team.resonances:
        for bonus in resonance.get("bonuses") or []:
            stat, value = bonus["stat"].lower(), float(bonus["value"])
            if stat == "atk":
                atk_pct += value
            elif "elemental mastery" in stat:
                em += value
            elif "dmg bonus" in stat and "khi có khiên" in stat:
                dmg += value * tuning.CONDITIONAL_UPTIME
    return atk_pct, em, dmg


def score_team(members: list[dict], options: dict[str, list[GearOption]],
               floor: FloorContext, team_bonus: dict) -> TeamResult:
    team = build_team_context(members, team_bonus)
    party_atk, party_em, party_dmg = _resonance_stats(team)
    assignment = assign_gear(members, options)

    # buff cấp đội đến từ vũ khí/thánh di vật của từng người
    for character in members:
        stats = assignment[character["id"]].stats
        party_atk += stats.party_atk_pct
        party_em += stats.party_em
        party_dmg += stats.party_dmg

    best: TeamResult | None = None
    for on_field in members:
        per_character = {
            character["id"]: character_damage(
                character, assignment[character["id"]].stats,
                on_field=(character["id"] == on_field["id"]),
                floor=floor, team=team,
                party_buffs=(party_atk, party_em, party_dmg),
            )
            for character in members
        }
        score = sum(per_character.values())
        notes: list[str] = []

        if not (team.has_heal or team.has_shield):
            score *= tuning.NO_SUSTAIN_PENALTY
            notes.append("không có heal/khiên → bị phạt điểm sinh tồn")
        if floor.shield_elements:
            counters = {c for element in floor.shield_elements
                        for c in _COUNTER_ELEMENT.get(element, [])}
            if counters & team.element_set:
                score *= tuning.SHIELD_BREAK_BONUS
                notes.append(f"phá được khiên {'/'.join(floor.shield_elements)}")
        if any(floor.res_for(e) < 0.10 for e in team.element_set):
            score *= tuning.WEAKNESS_EXPLOIT_BONUS
            weak = [e for e in team.element_set if floor.res_for(e) < 0.10]
            notes.append(f"khai thác điểm yếu nguyên tố: {'/'.join(sorted(weak))}")
        if team.moonsign_level >= 2:
            notes.append("Moonsign: Ascendant Gleam")
        if team.hexerei:
            notes.append("Hexerei: Secret Rite")
        for resonance in team.resonances:
            notes.append(f"Cộng hưởng: {resonance['name']}")

        result = TeamResult(
            member_ids=[c["id"] for c in members],
            on_field_id=on_field["id"],
            score=score,
            per_character=per_character,
            context=team,
            assignment=assignment,
            notes=notes,
        )
        if best is None or result.score > best.score:
            best = result
    assert best is not None
    return best


def enumerate_teams(pool: list[dict], options: dict, floor: FloorContext,
                    team_bonus: dict, top_n: int = 10) -> list[TeamResult]:
    results = [score_team(list(combo), options, floor, team_bonus)
               for combo in itertools.combinations(pool, 4)]
    results.sort(key=lambda r: r.score, reverse=True)
    return results[:top_n]
