"""Đọc data model JSON và parse các chuỗi text thành số dùng được.

Data model (`Sources/NSLauncherApp/Resources/Abyss/`) được transcribe từ Markdown nên nhiều
trường là text tự nhiên ("172.53% DEF", "kháng Anemo +20%"). Module này chịu
trách nhiệm bóc số ra, và **đếm lại những chỗ không parse được** để người
dùng biết phần nào của dữ liệu chưa được thuật toán dùng tới.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

ELEMENTS = ["Anemo", "Geo", "Electro", "Dendro", "Hydro", "Pyro", "Cryo"]

# Dữ liệu nằm trong thư mục tài nguyên của app (được `Package.swift` đóng gói
# qua `.copy("Resources/Abyss")`), không nằm trong `toi-uu-doi-hinh/` nữa:
# SwiftPM chỉ đóng gói được tài nguyên nằm trong thư mục target, và giữ hai bản
# sao thì chúng sẽ lệch nhau. Bản Markdown cho người đọc vẫn ở `toi-uu-doi-hinh/`.
DATA_ROOT = Path(__file__).resolve().parents[3] / "Sources" / "NSLauncherApp" / "Resources" / "Abyss"

# Nhãn scaling KHÔNG phải sát thương -> bỏ qua khi ước lượng damage.
_NON_DAMAGE_LABEL = re.compile(
    r"hồi máu|heal|khiên|shield|absorption|hấp thụ|thời lượng|duration|"
    r"^cd$|hồi chiêu|cooldown|năng lượng|energy|tốc đánh|atk spd|spd|"
    r"bond of life|kháng|res\b|stamina|thể lực|tầm|bán kính|số lần|"
    r"atk bonus|def bonus|hp bonus|em bonus|buff|giảm|tăng crit|crit rate|crit dmg",
    re.IGNORECASE,
)

# "172.53% DEF" / "45.4%/77.9% MaxHP" / "118%+128% ATK" / "~504% ATK"
_PERCENT = re.compile(r"(\d+(?:[.,]\d+)?)\s*%")


@dataclass
class ParseStats:
    """Đếm những gì parse được / không parse được, để báo cáo minh bạch."""

    scaling_ok: int = 0
    scaling_skipped: int = 0
    artifact_bonus_ok: int = 0
    artifact_bonus_unmapped: list[str] = field(default_factory=list)
    # Mục trong tuning.json talentPartyBuff mà nhãn/nhân vật không còn tồn tại.
    talent_party_buff_unresolved: list[str] = field(default_factory=list)
    # Phần damage-formula.json không đọc được (đã fallback về số cũ).
    damage_formula_unread: list[str] = field(default_factory=list)
    res_notes_unparsed: list[str] = field(default_factory=list)
    leyline_unparsed: list[str] = field(default_factory=list)


PARSE = ParseStats()


def _load(rel: str) -> Any:
    with open(DATA_ROOT / rel, encoding="utf-8") as fh:
        return json.load(fh)


def load_characters() -> list[dict]:
    out: list[dict] = []
    for path in sorted((DATA_ROOT / "characters").glob("*.json")):
        with open(path, encoding="utf-8") as fh:
            out.extend(json.load(fh))
    return out


def load_weapons() -> list[dict]:
    out: list[dict] = []
    for path in sorted((DATA_ROOT / "weapons").glob("*.json")):
        with open(path, encoding="utf-8") as fh:
            out.extend(json.load(fh))
    return out


def load_artifact_sets() -> list[dict]:
    return _load("artifact-sets.json")


def load_team_bonus() -> dict:
    return _load("team-bonus.json")


def load_damage_formula() -> dict:
    return _load("damage-formula.json")


def load_abyss_cycles() -> list[dict]:
    out = []
    for path in sorted((DATA_ROOT / "abyss-monsters").glob("*.json")):
        with open(path, encoding="utf-8") as fh:
            out.append(json.load(fh))
    return out


def latest_abyss_cycle() -> dict:
    cycles = load_abyss_cycles()
    if not cycles:
        raise FileNotFoundError(f"Không tìm thấy chu kỳ Trầm Thủy nào trong {DATA_ROOT / 'abyss-monsters'}")
    return max(cycles, key=lambda c: c["periodStart"])


# ---------------------------------------------------------------------------
# Parse hệ số kỹ năng
# ---------------------------------------------------------------------------

def parse_scaling_value(text: str) -> tuple[float, str] | None:
    """'172.53% DEF' -> (1.7253, 'DEF').  Trả None nếu không phải sát thương.

    Quy ước:
    - Bỏ phần trong ngoặc ("(cấp 13: 204%)") vì đó là biến thể cung mệnh.
    - "a%+b%" = các đòn liên tiếp -> cộng lại.
    - "a% / b%" = biến thể loại trừ nhau (Press/Hold, thấp/cao) -> lấy max.
    - Không ghi trục scale -> mặc định ATK (đúng quy ước Genshin).
    """
    if not text:
        return None
    cleaned = re.sub(r"\([^)]*\)", " ", text)  # bỏ chú thích trong ngoặc
    cleaned = cleaned.replace("~", " ")

    basis = "ATK"
    upper = cleaned.upper()
    if "MAXHP" in upper.replace(" ", "") or "MAX HP" in upper or re.search(r"\bHP\b", upper):
        basis = "HP"
    if re.search(r"\bDEF\b", upper):
        basis = "DEF"
    if "EM" in upper.split() or "ELEMENTAL MASTERY" in upper:
        basis = "EM"

    # Tách các nhánh loại trừ nhau bằng "/" rồi lấy nhánh mạnh nhất.
    best = 0.0
    for branch in re.split(r"(?<!\d)\s*/\s*|(?<=%)\s*/\s*", cleaned):
        percents = [float(m.replace(",", ".")) for m in _PERCENT.findall(branch)]
        if not percents:
            continue
        best = max(best, sum(percents))  # "a%+b%" trong cùng nhánh -> cộng
    if best <= 0:
        return None
    return best / 100.0, basis


def talent_damage_entries(talent: dict, level_key: str = "lv10") -> list[tuple[float, str]]:
    """Lấy các mốc sát thương của 1 kỹ năng (bỏ heal/khiên/CD/năng lượng)."""
    out = []
    for entry in talent.get("scaling") or []:
        label = entry.get("label", "")
        if _NON_DAMAGE_LABEL.search(label):
            PARSE.scaling_skipped += 1
            continue
        values = entry.get("values") or {}
        raw = values.get(level_key) or values.get("lv10") or values.get("lv1")
        parsed = parse_scaling_value(raw or "")
        if parsed is None:
            PARSE.scaling_skipped += 1
            continue
        PARSE.scaling_ok += 1
        out.append(parsed)
    return out


_COMBO_HIT = re.compile(r"^(?:\d+-hit|đòn\s*\d+)", re.IGNORECASE)


def normal_attack_combo(character: dict, level_key: str = "lv10") -> list[tuple[float, str]]:
    """Chỉ lấy các đòn trong chuỗi đánh thường (bỏ trọng kích/nhảy)."""
    out = []
    for hit in character["normalAttack"].get("hits") or []:
        if not _COMBO_HIT.match(hit.get("label", "").strip()):
            continue
        values = hit.get("values") or {}
        raw = values.get(level_key) or values.get("lv10") or values.get("lv1")
        parsed = parse_scaling_value(raw or "")
        if parsed:
            out.append(parsed)
    return out


_BASIS_CACHE: dict[str, str] = {}


def scaling_basis(character: dict) -> str:
    """Nhân vật này scale chủ yếu theo ATK / DEF / HP?"""
    cached = _BASIS_CACHE.get(character["id"])
    if cached is not None:
        return cached
    counts = {"ATK": 0, "DEF": 0, "HP": 0, "EM": 0}
    for key in ("elementalSkill", "elementalBurst"):
        for _mult, basis in talent_damage_entries(character[key]):
            counts[basis] += 1
    non_atk = {k: v for k, v in counts.items() if k != "ATK"}
    if non_atk and max(non_atk.values()) > counts["ATK"]:
        basis = max(non_atk, key=non_atk.get)
    else:
        basis = "ATK"
    _BASIS_CACHE[character["id"]] = basis
    return basis


# ---------------------------------------------------------------------------
# Parse kháng nguyên tố của quái
# ---------------------------------------------------------------------------

_RES_PATTERNS = [
    # "kháng Anemo +20%", "kháng Dendro/Geo +20~30%"
    re.compile(r"kháng\s+([A-Za-zÀ-ỹ/ ]+?)\s*([+-−])\s*(\d+(?:\.\d+)?)", re.IGNORECASE),
    # "pyro_res -20%", "pyro_res −220%"
    re.compile(r"([a-z]+)_res\s*([+-−])?\s*(\d+(?:\.\d+)?)", re.IGNORECASE),
]

_VN_ELEMENT = {
    "băng": "Cryo", "hoả": "Pyro", "hỏa": "Pyro", "lôi": "Electro", "điện": "Electro",
    "thuỷ": "Hydro", "thủy": "Hydro", "phong": "Anemo", "nham": "Geo", "thảo": "Dendro",
    "vật lý": "Physical",
}


def _norm_element(token: str) -> str | None:
    token = token.strip().lower()
    for element in ELEMENTS:
        if element.lower() == token:
            return element
    if token in _VN_ELEMENT:
        return _VN_ELEMENT[token]
    return None


def parse_res_notes(note: str | None) -> dict[str, float]:
    """'kháng Anemo +20%' -> {'Anemo': 0.20};  'pyro_res -20%' -> {'Pyro': -0.20}."""
    if not note:
        return {}
    found: dict[str, float] = {}
    for pattern in _RES_PATTERNS:
        for match in pattern.finditer(note):
            raw_elements, sign, value = match.group(1), match.group(2), match.group(3)
            delta = float(value) / 100.0
            if sign in ("-", "−"):
                delta = -delta
            for token in re.split(r"[/,]", raw_elements):
                element = _norm_element(token)
                if element:
                    found[element] = delta
    if not found and re.search(r"kháng|res", note, re.IGNORECASE):
        PARSE.res_notes_unparsed.append(note)
    return found


# ---------------------------------------------------------------------------
# Parse Ley Line Disorder / Blessing
# ---------------------------------------------------------------------------

_REACTION_KEYWORDS = {
    "stellar swirl": "Stellar Swirl",
    "stellar-conduct": "Stellar-Conduct",
    "superconduct": "Superconduct",
    "siêu dẫn": "Superconduct",
    "lunar-charged": "Lunar-Charged",
    "lunar-bloom": "Lunar-Bloom",
    "lunar-crystallize": "Lunar-Crystallize",
    "overloaded": "Overloaded",
    "vaporize": "Vaporize",
    "bốc hơi": "Vaporize",
    "melt": "Melt",
    "tan chảy": "Melt",
}


@dataclass
class FloorBuff:
    """Một vế buff của Ley Line Disorder / Uyên Nguyệt Chúc Phúc."""

    bonus: float                  # +0.50 = +50% sát thương
    elements: list[str] = field(default_factory=list)   # buff theo nguyên tố
    reactions: list[str] = field(default_factory=list)  # buff theo phản ứng
    normal_attack_only: bool = False
    raw: str = ""


# --- Hằng số công thức, đọc từ damage-formula.json ---------------------------
#
# Trước đây các số này nằm hard-code trong scoring.py và damage-formula.json chỉ
# được đọc để... không làm gì. Hai nguồn sự thật, không gì buộc chúng khớp nhau.

_EM_CURVE = re.compile(r"([0-9.]+)\s*\*\s*EM\s*/\s*\(\s*EM\s*\+\s*([0-9.]+)\s*\)", re.I)

CHARACTER_LEVEL = 90


def _em_curve(text: str, fallback: tuple[float, float]) -> tuple[float, float]:
    m = _EM_CURVE.search(text or "")
    if not m:
        PARSE.damage_formula_unread.append(text or "(trống)")
        return fallback
    return float(m.group(1)), float(m.group(2))


def load_damage_formula() -> dict:
    with open(DATA_ROOT / "damage-formula.json", encoding="utf-8") as fh:
        return json.load(fh)


_DF = load_damage_formula()
AMPLIFYING_EM = _em_curve(_DF["amplifying"]["emBonusFormula"], (2.78, 1400.0))
TRANSFORMATIVE_EM = _em_curve(_DF["transformative"]["emBonusFormula"], (16.0, 2000.0))
CATALYZE_EM = _em_curve(_DF["catalyze"]["emBonusFormula"], (5.0, 1200.0))

# Tên trong data -> (nguyên tố kích hoạt, nguyên tố đã có trên địch)
_AMPLIFYING_PAIRS = {
    "meltPyroTrigger": ("Pyro", "Cryo"),
    "meltCryoTrigger": ("Cryo", "Pyro"),
    "vaporizeHydroTrigger": ("Hydro", "Pyro"),
    "vaporizePyroTrigger": ("Pyro", "Hydro"),
}
AMPLIFYING_COEFFICIENTS = {
    _AMPLIFYING_PAIRS[k]: v
    for k, v in _DF["amplifying"]["coefficients"].items()
    if k in _AMPLIFYING_PAIRS
}
TRANSFORMATIVE_COEFFICIENTS: dict[str, float] = dict(_DF["transformative"]["coefficients"])
TRANSFORMATIVE_LEVEL_MULTIPLIER: float = (
    _DF["transformative"]["levelMultiplier"].get(str(CHARACTER_LEVEL), {}).get("character", 0.0)
)
DEFAULT_MONSTER_RES: float = _DF["resMultiplier"]["defaultMonsterResAllElements"]


# --- Cung mệnh ---------------------------------------------------------------

# Data viết cung mệnh nâng cấp chiêu theo hai kiểu — "Tăng cấp X thêm 3" và
# "X +3 cấp" — chỉ khớp kiểu đầu là mất một phần ba, trong đó có C3/C5 Xingqiu.
_TALENT_LEVEL_BOOST = re.compile(r"tăng cấp|\+\s*3\s*cấp|cấp\s*\+\s*3|thêm 3 cấp", re.I)
_NORMAL_ATTACK_BOOST = re.compile(r"đòn thường|normal attack", re.I)
_BURST_WORD = re.compile(r"\bburst\b|bùng nổ|\bnộ\b", re.I)
_SKILL_WORD = re.compile(r"kỹ năng|\bskill\b", re.I)


def boosted_talent(description: str, character: dict) -> str | None:
    """Cung mệnh này nâng chiêu nào thêm 3 cấp: "skill", "burst", hay không nâng.

    Đếm xem có bao nhiêu TỪ trong TÊN từng chiêu xuất hiện trong mô tả, rồi lấy
    chiêu thắng; chỉ khi hoà mới rơi xuống từ khoá chung ("Tăng cấp kỹ năng thêm
    3"). Đếm chứ không chỉ tìm-thấy-là-được, vì có những nhân vật hai chiêu trùng
    tiền tố — Skirk "Havoc: Warp" với "Havoc: Ruin", Candace hai chiêu "Sacred
    Rite" — mà luật khớp-đầu-tiên sẽ chọn sai một nửa số lần.
    """
    if not _TALENT_LEVEL_BOOST.search(description or ""):
        return None
    if _NORMAL_ATTACK_BOOST.search(description):
        return None
    lowered = description.lower()

    def score(name: str | None) -> int:
        if not name:
            return 0
        words = {w.lower() for w in re.split(r"[^A-Za-zÀ-ỹ]+", name) if len(w) >= 4}
        return sum(1 for w in words if w in lowered)

    skill = score((character.get("elementalSkill") or {}).get("name"))
    burst = score((character.get("elementalBurst") or {}).get("name"))
    if skill > burst:
        return "skill"
    if burst > skill:
        return "burst"
    if _BURST_WORD.search(description):
        return "burst"
    if _SKILL_WORD.search(description):
        return "skill"
    return None


def talent_levels(character: dict, constellation: int) -> tuple[str, str]:
    """(khoá cấp cho skill, khoá cấp cho burst) theo số cung mệnh đang có."""
    if constellation <= 0:
        return "lv10", "lv10"
    skill, burst = "lv10", "lv10"
    for entry in character.get("constellations") or []:
        if entry.get("level", 99) > constellation:
            continue
        slot = boosted_talent(entry.get("description") or "", character)
        if slot == "skill":
            skill = "lv13"
        elif slot == "burst":
            burst = "lv13"
    return skill, burst


_CHARGED_HIT = re.compile(r"đòn nặng|trọng kích|charged|aimed|ngắm bắn|bắn nhắm", re.IGNORECASE)


def charged_attack(character: dict, level_key: str = "lv10") -> tuple[float, str] | None:
    """Đòn nặng của nhân vật, hoặc None nếu parser không nhận ra dòng nào.

    Lấy dòng MẠNH NHẤT chứ không cộng các dòng lại. Đòn nặng là MỘT hành động và
    nhân vật dùng cái tốt nhất, nhưng data không nói dòng nào là thay thế nhau và
    dòng nào là tuần tự: "Aimed Shot" với "Aimed Shot sạc đầy" của cung là hai
    cách bắn cùng một mũi tên, còn đòn xoay và đòn kết thúc của claymore thì nối
    tiếp nhau. Cộng lại sẽ nhân đôi mọi cung trong data; lấy max chỉ thiếu một ít
    ở vài claymore — cách sai an toàn hơn.
    """
    best: tuple[float, str] | None = None
    for hit in (character.get("normalAttack") or {}).get("hits") or []:
        label = (hit.get("label") or "").strip()
        if not _CHARGED_HIT.search(label):
            continue
        values = hit.get("values") or {}
        raw = values.get(level_key) or values.get("lv10") or values.get("lv1") or ""
        parsed = parse_scaling_value(raw)
        if parsed is None:
            continue
        if best is None or parsed[0] > best[0]:
            best = parsed
    return best


def talent_percentage(talent: dict, label: str, index: int = 0,
                      level_key: str = "lv10") -> float | None:
    """% thứ `index` trên dòng scaling có nhãn ĐÚNG BẰNG `label`.

    Chỉ bảng `talentPartyBuff` trong tuning.json dùng hàm này. Các dòng đó cố ý
    KHÔNG phải dòng sát thương nên `talent_damage_entries` bỏ chúng — nhưng con
    số thì có thật và nằm trong data nhân vật, tức là chỗ nên đọc, thay vì chép
    tay vào tuning.json nơi mà một lần sửa hệ số chiêu sẽ không bao giờ tới.

    Ngoặc đơn bị bóc trước, y như `scaling_value`, để biến thể cung mệnh
    ("(cấp 14: 126%)") không bị nhầm thành vế thứ hai của dòng 2 phần.
    """
    entry = next((r for r in (talent.get("scaling") or []) if r.get("label") == label), None)
    if entry is None:
        return None
    values = entry.get("values") or {}
    raw = values.get(level_key) or values.get("lv10") or values.get("lv1") or ""
    cleaned = re.sub(r"\([^)]*\)", " ", raw)  # bỏ chú thích trong ngoặc
    found = [float(m.replace(",", ".")) for m in _PERCENT.findall(cleaned)]
    if not 0 <= index < len(found):
        return None
    return found[index] / 100.0


def parse_floor_buffs(text: str | None) -> list[FloorBuff]:
    """Bóc các vế '+X% sát thương <cái gì>' trong mô tả tiếng Việt."""
    if not text:
        return []
    buffs: list[FloorBuff] = []
    # Tách theo câu/mệnh đề để mỗi vế gắn đúng con số của nó.
    for clause in re.split(r"[;.]|(?<=%)\s*,\s*", text):
        percents = _PERCENT.findall(clause)
        if not percents:
            continue
        bonus = float(percents[0].replace(",", ".")) / 100.0
        lowered = clause.lower()
        reactions = [name for key, name in _REACTION_KEYWORDS.items() if key in lowered]
        elements = [e for e in ELEMENTS if e.lower() in lowered]
        normal_only = bool(re.search(r"thường công|normal attack|đòn thường", lowered))
        if not reactions and not elements and not normal_only:
            continue
        buffs.append(FloorBuff(bonus=bonus, elements=elements, reactions=reactions,
                               normal_attack_only=normal_only, raw=clause.strip()))
    if not buffs and _PERCENT.search(text):
        PARSE.leyline_unparsed.append(text)
    return buffs
