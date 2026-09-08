"""Đọc data model JSON và parse các chuỗi text thành số dùng được.

Data model (`../data-model/data/`) được transcribe từ Markdown nên nhiều
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

DATA_ROOT = Path(__file__).resolve().parents[2] / "data-model" / "data"

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
