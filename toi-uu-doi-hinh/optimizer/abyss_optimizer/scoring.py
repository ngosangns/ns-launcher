"""Công thức sát thương + chấm điểm đội hình cho 1 tầng Trầm Thủy.

Triển khai đúng theo `Sources/NSLauncherApp/Resources/Abyss/damage-formula.json` (mục 1.6-1.8, 2)
cho phần công thức lõi; phần rotation/uptime là heuristic (xem `tuning.py`).
"""

from __future__ import annotations

import itertools
import re
from dataclasses import dataclass, field

from . import tuning
from .build import Stats, party_buff_of
from .data import (
    AMPLIFYING_COEFFICIENTS,
    AMPLIFYING_EM,
    CHARACTER_LEVEL as _DATA_CHARACTER_LEVEL,
    ELEMENTS,
    TRANSFORMATIVE_COEFFICIENTS,
    TRANSFORMATIVE_EM,
    TRANSFORMATIVE_LEVEL_MULTIPLIER,
    charged_attack,
    load_artifact_sets,
    talent_levels,
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


def em_bonus_transformative(em: float) -> float:
    """Đóng góp của EM vào phản ứng transformative — bão hoà nhanh hơn amplifying."""
    a, b = TRANSFORMATIVE_EM
    return a * em / (em + b)


def em_bonus_amplifying(em: float) -> float:
    a, b = AMPLIFYING_EM
    return a * em / (em + b)


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

    # Chúc phúc La Hoàn (Uyên Nguyệt Chúc Phúc) áp cho MỌI tầng suốt cả chu kỳ.
    # Đọc cả `relatedMechanic` chứ không chỉ `description`: phần mô tả thường
    # chỉ kể cơ chế bằng lời, còn các con số buff thật ("+20% sát thương
    # Cryo/Electro" cho nhân vật đứng trong vùng) nằm ở ghi chú cơ chế. Chỉ
    # parse description thì chúc phúc không đóng góp gì — mô hình lặng lẽ chấm
    # điểm như thể chu kỳ này không có chúc phúc nào.
    blessing = cycle.get("blessingOfTheAbyssalMoon") or {}
    blessing_buffs = parse_floor_buffs(blessing.get("description"))
    blessing_buffs += parse_floor_buffs(blessing.get("relatedMechanic"))
    # Hai trường hay trùng câu chữ; đếm 2 lần là nhân đôi buff.
    seen: set[str] = set()
    for buff in blessing_buffs:
        if buff.raw in seen:
            continue
        seen.add(buff.raw)
        buffs.append(buff)

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


# (nguyên tố người kích hoạt, nguyên tố cần có sẵn) -> hệ số, đọc từ
# damage-formula.json thay vì chép tay ở đây.
_AMPLIFYING = AMPLIFYING_COEFFICIENTS


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


def _transformative_reactions(team: TeamContext) -> set[str]:
    """Phản ứng transformative đội này kích được — khác `_reactions_enabled`.

    Hai khác biệt, đều cố ý. Không áp nâng cấp Lunar ở đây: damage-formula.json
    định giá nhóm Lunar/Stellar ở khối riêng với luật gộp riêng, nên Bloom của
    đội Moonsign vẫn được tính là Bloom thay vì bị bỏ vì đổi tên. Và các phản
    ứng hai bước được suy ra: Hyperbloom với Burgeon cần sẵn một hạt Bloom nên
    đòi ba nguyên tố chứ không phải hai.

    Không có Shatter: nó cần địch đang đóng băng và một đòn cùn, hai điều mà
    danh sách nguyên tố không nói được.
    """
    elements = team.element_set
    found: set[str] = set()
    if {"Electro", "Cryo"} <= elements:
        found.add("superconduct")
    if {"Electro", "Hydro"} <= elements:
        found.add("electroCharged")
    if {"Electro", "Pyro"} <= elements:
        found.add("overloaded")
    if {"Dendro", "Pyro"} <= elements:
        found.add("burning")
    if {"Dendro", "Hydro"} <= elements:
        found.add("bloom")
        if "Electro" in elements:
            found.add("hyperbloom")
        if "Pyro" in elements:
            found.add("burgeon")
    if "Anemo" in elements and (elements & {"Pyro", "Hydro", "Electro", "Cryo"}):
        found.add("swirl")
    return found


# Phản ứng transformative tính kháng theo nguyên tố nào. Swirl là None vì nó
# mang nguyên tố bị cuốn, do đội quyết định.
_TRANSFORMATIVE_ELEMENT = {
    "burning": "Pyro", "overloaded": "Pyro", "superconduct": "Cryo",
    "electroCharged": "Electro", "bloom": "Dendro", "hyperbloom": "Dendro",
    "burgeon": "Dendro",
}


def transformative_base(team: TeamContext, floor: FloorContext) -> tuple[str, float] | None:
    """Phản ứng transformative MẠNH NHẤT đội mở ra, đã tính kháng của tầng.

    Một phản ứng, không phải tổng mọi phản ứng. Đội Dendro/Hydro/Electro/Pyro về
    lý thuyết mở ra Bloom, Hyperbloom, Burgeon, Burning, Overloaded và
    Electro-Charged cùng lúc, nhưng một rotation chỉ có ngần ấy lần áp nguyên tố
    và chúng tranh nhau cùng một aura. Lấy cái mạnh nhất là cách đọc thận trọng;
    cộng hết lại sẽ biến "đội 4 nguyên tố trộn lẫn" thành đáp án cho mọi tầng.

    Trả về (tên phản ứng, hệ số × levelMultiplier × resMultiplier) — tức mọi thứ
    trừ EM của người kích hoạt, phần duy nhất mà đổi thánh di vật lay chuyển được.
    """
    best: tuple[str, float] | None = None
    # sorted() vì Hyperbloom và Burgeon dùng chung hệ số lẫn kháng: sát thương
    # như nhau, nhưng tên phản ứng được chọn không nên phụ thuộc thứ tự hash.
    for reaction in sorted(_transformative_reactions(team)):
        coefficient = TRANSFORMATIVE_COEFFICIENTS.get(reaction)
        if coefficient is None:
            continue
        element = _TRANSFORMATIVE_ELEMENT.get(reaction)
        if element is not None:
            res = floor.res_for(element)
        else:
            candidates = [floor.res_for(e) for e in team.element_set - {"Anemo", "Geo"}]
            res = min(candidates) if candidates else 0.10
        base = coefficient * TRANSFORMATIVE_LEVEL_MULTIPLIER * res_multiplier(res)
        if best is None or base > best[1]:
            best = (reaction, base)
    return best


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


_PROFILE_CACHE: dict[tuple[str, str, str], list[tuple[float, str, str]]] = {}


def damage_profile(character: dict, constellation: int = 0) -> list[tuple[float, str, str]]:
    """(hệ số, trục scale, loại đòn) của 1 nhân vật — parse 1 lần rồi cache.

    C3 và C5 mỗi cái nâng một chiêu thêm 3 cấp, tức đọc cột `lv13` mà data đã có
    sẵn cho những nhân vật đã transcribe tới đó. Nhân vật không có cột lv13 thì
    parser tự lùi về lv10, nên hỏi cấp nào cũng an toàn.
    """
    skill_key, burst_key = talent_levels(character, constellation)
    cache_key = (character["id"], skill_key, burst_key)
    cached = _PROFILE_CACHE.get(cache_key)
    if cached is not None:
        return cached
    profile: list[tuple[float, str, str]] = []
    for multiplier, basis in talent_damage_entries(character["elementalSkill"], skill_key):
        profile.append((multiplier, basis, "skill"))
    for multiplier, basis in talent_damage_entries(character["elementalBurst"], burst_key):
        profile.append((multiplier, basis, "burst"))
    for multiplier, basis in normal_attack_combo(character):
        profile.append((multiplier, basis, "normal"))
    charged = charged_attack(character)
    if charged is not None:
        profile.append((charged[0], charged[1], "charged"))
    _PROFILE_CACHE[cache_key] = profile
    return profile


@dataclass
class PartyBuffs:
    """Buff áp cho cả 4 người: cộng hưởng + những gì mỗi người phát ra."""

    atk_pct: float = 0.0
    flat_atk: float = 0.0
    em: float = 0.0
    dmg: float = 0.0
    elemental_dmg: dict[str, float] = field(default_factory=dict)


def character_damage(character: dict, stats: Stats, *, on_field: bool,
                     floor: FloorContext, team: TeamContext,
                     party_buffs: PartyBuffs, constellation: int = 0) -> float:
    """Sát thương ước lượng của 1 nhân vật trong 1 rotation."""
    element = character["element"]
    reactions = _reactions_enabled(team)

    effective = Stats(**{**stats.__dict__})
    effective.atk_pct += party_buffs.atk_pct
    effective.flat_atk += party_buffs.flat_atk
    effective.em += party_buffs.em
    effective.dmg_all += party_buffs.dmg
    for _element, _value in party_buffs.elemental_dmg.items():
        effective.dmg_elemental[_element] = effective.dmg_elemental.get(_element, 0.0) + _value

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

    profile = damage_profile(character, constellation)
    # Đòn thường và đòn nặng đều CHỈ xảy ra khi đứng sân, nhưng số lần trong một
    # rotation khác nhau nên phải nhân bằng hai hằng số khác nhau.
    ability = sum(hit_damage(m, b, cat) for m, b, cat in profile
                  if cat not in ("normal", "charged"))
    if not on_field:
        return ability * tuning.OFFFIELD_UPTIME

    combo = sum(hit_damage(m, b, "normal") for m, b, cat in profile if cat == "normal")
    charged = sum(hit_damage(m, b, "charged") for m, b, cat in profile if cat == "charged")
    return (ability
            + combo * tuning.NORMAL_COMBOS_PER_ROTATION
            + charged * tuning.CHARGED_ATTACKS_PER_ROTATION)


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


def _set_party_buff_table() -> dict[str, tuple[tuple[float, float, float], tuple[float, float, float]]]:
    """Mỗi bộ tặng gì cho CẢ ĐỘI khi mặc 4 món và khi mặc 2 món.

    Cần vì các buff này không cộng dồn với chính nó — xem `score_team`.
    """
    table: dict[str, tuple[tuple[float, float, float], tuple[float, float, float]]] = {}
    for artifact_set in load_artifact_sets():
        two = party_buff_of(artifact_set["twoPiece"].get("bonuses") or [])
        four = tuple(a + b for a, b in
                     zip(two, party_buff_of(artifact_set["fourPiece"].get("bonuses") or [])))
        # Xấp xỉ viết tay chạm cả đội cũng là buff phe, cũng không cộng dồn với
        # chính nó. Chỉ bản 4 món mang nó: `build_stats` chỉ áp xấp xỉ khi cả 4
        # món cùng một bộ. Bảng này khoá theo bộ nên mục có `party` không được
        # mang `requirement` — test phía Swift chốt điều đó.
        approx = tuning.SET_EFFECT_APPROX.get(artifact_set["id"])
        if approx and approx[4]:
            four = (four[0], four[1], four[2] + approx[1])
        if any(two) or any(four):
            table[artifact_set["id"]] = (four, two)  # (mặc 4 món, mặc 2 món)
    return table


_SET_PARTY_BUFF = _set_party_buff_table()


def score_team(members: list[dict], options: dict[str, list[GearOption]],
               floor: FloorContext, team_bonus: dict,
               constellations: dict[str, int] | None = None) -> TeamResult:
    team = build_team_context(members, team_bonus)
    _atk, _em, _dmg = _resonance_stats(team)
    party = PartyBuffs(atk_pct=_atk, em=_em, dmg=_dmg)
    assignment = assign_gear(members, options)

    # Buff cấp đội đến từ vũ khí/thánh di vật/chiêu của từng người.
    #
    # Buff phe của một BỘ thánh di vật chỉ tính MỘT lần, dù mấy người cùng mặc:
    # trong game chúng không cộng dồn với chính nó, và khác biệt này không hàn
    # lâm — cộng thẳng thì thuật toán tối ưu điểm đội sẽ phát hiện ra rằng cho 3
    # người cùng mặc Tenacity of the Millelith "tặng" +60% ATK toàn đội, rồi gợi
    # ý đúng như vậy. Phần còn lại của mô hình (passive vũ khí, chiêu) vẫn cộng
    # dồn; đó là chồng lấn nhỏ hơn và hiếm hơn nhiều.
    counted_sets: set[str] = set()
    for character in members:
        option = assignment[character["id"]]
        stats = option.stats
        party.atk_pct += stats.party_atk_pct
        party.flat_atk += stats.party_flat_atk
        party.em += stats.party_em
        party.dmg += stats.party_dmg
        for _element, _value in stats.party_elemental_dmg.items():
            party.elemental_dmg[_element] = party.elemental_dmg.get(_element, 0.0) + _value

        # Những gì bộ đồ đã góp vào tổng ở trên, trừ lại các bản sao từ người
        # thứ hai trở đi.
        worn = [s["id"] for s in option.sets]
        for set_id in worn:
            granted = _SET_PARTY_BUFF.get(set_id)
            if granted is None:
                continue
            atk, em, dmg = granted[0] if len(worn) == 1 else granted[1]
            if set_id in counted_sets:
                party.atk_pct -= atk
                party.em -= em
                party.dmg -= dmg
            else:
                counted_sets.add(set_id)

    cons = constellations or {}

    # Sát thương transformative thuộc về CẢ ĐỘI, không thuộc về một đòn nào: nó
    # bỏ qua hoàn toàn ATK/DMG Bonus/CRIT/DEF địch và chỉ phụ thuộc EM của người
    # kích hoạt. Đội luôn kích bằng EM cao nhất của mình — đó là lý do một
    # support không tự gây sát thương vẫn có thể là người đóng góp nhiều nhất
    # trong đội Bloom.
    reaction_damage = 0.0
    trigger_id: str | None = None
    transformative = transformative_base(team, floor)
    if transformative is not None:
        best_em = None
        for character in members:
            em = assignment[character["id"]].stats.em + party.em
            if best_em is None or em > best_em:
                best_em, trigger_id = em, character["id"]
        reaction_damage = (tuning.TRANSFORMATIVE_REACTIONS_PER_ROTATION
                           * transformative[1]
                           * (1 + em_bonus_transformative(max(best_em or 0.0, 0.0))))

    best: TeamResult | None = None
    for on_field in members:
        per_character = {
            character["id"]: character_damage(
                character, assignment[character["id"]].stats,
                on_field=(character["id"] == on_field["id"]),
                floor=floor, team=team,
                party_buffs=party,
                constellation=cons.get(character["id"], 0),
            )
            for character in members
        }
        if trigger_id is not None:
            per_character[trigger_id] = per_character.get(trigger_id, 0.0) + reaction_damage
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
                    team_bonus: dict, top_n: int = 10,
                    constellations: dict[str, int] | None = None) -> list[TeamResult]:
    results = [score_team(list(combo), options, floor, team_bonus, constellations)
               for combo in itertools.combinations(pool, 4)]
    results.sort(key=lambda r: r.score, reverse=True)
    return results[:top_n]
