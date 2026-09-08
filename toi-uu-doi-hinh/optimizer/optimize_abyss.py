#!/usr/bin/env python3
"""Gợi ý đội hình Trầm Thủy tối ưu từ data model, lọc theo roster sở hữu.

Chạy:
    python3 optimize_abyss.py                      # dùng roster.json nếu có
    python3 optimize_abyss.py --roster roster.json --floor 12 --top 5
    python3 optimize_abyss.py --full-roster        # bỏ qua roster, so lý thuyết
    python3 optimize_abyss.py --self-test          # kiểm chứng công thức sát thương

Chỉ dùng thư viện chuẩn Python 3.10+, không cần cài gì thêm.
"""

from __future__ import annotations

import argparse
import itertools
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from abyss_optimizer import data as gdata  # noqa: E402
from abyss_optimizer import tuning  # noqa: E402
from abyss_optimizer.build import build_stats  # noqa: E402
from abyss_optimizer.scoring import (  # noqa: E402
    FloorContext,
    GearOption,
    TeamContext,
    amplifying_multiplier,
    build_floor_context,
    capabilities,
    character_damage,
    def_multiplier,
    em_bonus_amplifying,
    enumerate_teams,
    res_multiplier,
)

HERE = Path(__file__).resolve().parent
DEFAULT_ROSTER = HERE / "roster.json"


# ---------------------------------------------------------------------------
# Roster
# ---------------------------------------------------------------------------

def load_roster(path: Path | None) -> dict | None:
    if path is None or not path.exists():
        return None
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def apply_roster(roster: dict | None, characters: list[dict], weapons: list[dict],
                 sets: list[dict]) -> tuple[list[dict], list[dict], list[dict], dict[str, int], dict[str, int]]:
    """Lọc dữ liệu theo những gì thực sự sở hữu."""
    if roster is None:
        return characters, weapons, sets, {}, {}

    owned_chars = {c["id"]: c for c in roster.get("characters", [])}
    owned_weapons = {w["id"]: w for w in roster.get("weapons", [])}
    owned_sets = set(roster.get("artifactSets", []))

    known_char_ids = {c["id"] for c in characters}
    known_weapon_ids = {w["id"] for w in weapons}
    known_set_ids = {s["id"] for s in sets}
    for unknown in sorted(owned_chars.keys() - known_char_ids):
        print(f"  ! roster: không có nhân vật id '{unknown}' trong data model", file=sys.stderr)
    for unknown in sorted(owned_weapons.keys() - known_weapon_ids):
        print(f"  ! roster: không có vũ khí id '{unknown}' trong data model", file=sys.stderr)
    for unknown in sorted(owned_sets - known_set_ids):
        print(f"  ! roster: không có bộ thánh di vật id '{unknown}' trong data model", file=sys.stderr)

    characters = [c for c in characters if c["id"] in owned_chars]
    weapons = [w for w in weapons if w["id"] in owned_weapons]
    if owned_sets:
        sets = [s for s in sets if s["id"] in owned_sets]

    constellations = {cid: int(entry.get("constellation", 0)) for cid, entry in owned_chars.items()}
    refinements = {wid: int(entry.get("refinement", 1)) for wid, entry in owned_weapons.items()}
    return characters, weapons, sets, constellations, refinements


# ---------------------------------------------------------------------------
# Chọn trang bị tốt nhất cho từng nhân vật
# ---------------------------------------------------------------------------

NEUTRAL_FLOOR = FloorContext(floor=0, monster_level=95, res={}, label="chuẩn hoá")


def default_role(character: dict) -> str:
    can_heal, can_shield = capabilities(character)
    if can_heal:
        return "healer"
    if can_shield:
        return "shield"
    return "main-dps"


def solo_damage(character: dict, stats) -> float:
    team = TeamContext(elements=[character["element"]])
    return character_damage(character, stats, on_field=True, floor=NEUTRAL_FLOOR,
                            team=team, party_buffs=(0.0, 0.0, 0.0))


WEAPON_ALTERNATIVES = 6


def pick_gear(character: dict, weapons: list[dict], sets: list[dict],
              refinements: dict[str, int]) -> list[GearOption]:
    """Xếp hạng các phương án trang bị của 1 nhân vật, tốt nhất trước.

    Trả về nhiều phương án (không chỉ 1) để khi ghép đội còn đường lùi nếu 2
    người cùng muốn 1 vũ khí — mỗi vũ khí chỉ có 1 bản.

    Chọn 2 giai đoạn (vũ khí trước, thánh di vật sau) thay vì thử mọi cặp:
    hai nguồn chỉ số này gần như cộng tuyến tính nên kết quả chênh không đáng
    kể, nhưng nhanh hơn nhiều.
    """
    role = default_role(character)
    usable = [w for w in weapons if w["type"] == character["weaponType"]]
    if not usable:
        stats = build_stats(character, None, sets[:1], role)
        return [GearOption(stats, None, sets[:1], role, solo_damage(character, stats))]
    if not sets:
        options = []
        for weapon in usable:
            stats = build_stats(character, weapon, [], role, refinements.get(weapon["id"], 1))
            options.append(GearOption(stats, weapon, [], role, solo_damage(character, stats)))
        options.sort(key=lambda o: o.solo_score, reverse=True)
        return options[:WEAPON_ALTERNATIVES]

    # 1) xếp hạng vũ khí với 1 bộ thánh di vật cố định làm mốc so sánh
    baseline = sets[0]
    ranked_weapons = []
    for weapon in usable:
        stats = build_stats(character, weapon, [baseline], role, refinements.get(weapon["id"], 1))
        ranked_weapons.append((solo_damage(character, stats), weapon))
    ranked_weapons.sort(key=lambda item: item[0], reverse=True)
    ranked_weapons = ranked_weapons[:WEAPON_ALTERNATIVES]

    # 2) tìm bộ thánh di vật tốt nhất cho vũ khí số 1, dùng lại cho các vũ khí sau
    top_weapon = ranked_weapons[0][1]
    refinement = refinements.get(top_weapon["id"], 1)
    scored_sets = []
    best_sets, best_score = [baseline], float("-inf")
    for artifact_set in sets:
        stats = build_stats(character, top_weapon, [artifact_set], role, refinement)
        score = solo_damage(character, stats)
        scored_sets.append((score, artifact_set))
        if score > best_score:
            best_sets, best_score = [artifact_set], score
    scored_sets.sort(key=lambda item: item[0], reverse=True)
    for (_s1, set_a), (_s2, set_b) in itertools.combinations(scored_sets[:8], 2):
        stats = build_stats(character, top_weapon, [set_a, set_b], role, refinement)
        score = solo_damage(character, stats)
        if score > best_score:
            best_sets, best_score = [set_a, set_b], score

    options = []
    for _score, weapon in ranked_weapons:
        stats = build_stats(character, weapon, best_sets, role, refinements.get(weapon["id"], 1))
        options.append(GearOption(stats, weapon, best_sets, role, solo_damage(character, stats)))
    options.sort(key=lambda o: o.solo_score, reverse=True)
    return options


# ---------------------------------------------------------------------------
# Báo cáo
# ---------------------------------------------------------------------------

def report(results, floor: FloorContext, index: dict, cycle: dict) -> None:
    print()
    print("=" * 78)
    blessing = (cycle.get("blessingOfTheAbyssalMoon") or {}).get("name", "—")
    print(f"{floor.label}  |  quái cấp ~{floor.monster_level}  |  Uyên Nguyệt Chúc Phúc: {blessing}")
    if floor.buffs:
        for buff in floor.buffs:
            print(f"  buff nhận diện được: +{buff.bonus:.0%} — {buff.raw[:90]}")
    if floor.shield_elements:
        print(f"  khiên nguyên tố trong tầng: {', '.join(floor.shield_elements)}")
    weak = {e: r for e, r in floor.res.items() if r < 0.10}
    if weak:
        print("  điểm yếu nguyên tố: " + ", ".join(f"{e} (kháng {r:.0%})" for e, r in sorted(weak.items())))
    print("=" * 78)

    for rank, result in enumerate(results, 1):
        names = []
        for cid in result.member_ids:
            character = index[cid]
            marker = " ★" if cid == result.on_field_id else ""
            names.append(f"{character['name']}({character['element'][:2]}){marker}")
        print(f"\n#{rank}  điểm {result.score:,.0f}   {'  '.join(names)}")
        print("     ★ = nhân vật đứng sân chính (on-field)")
        raw_total = sum(result.per_character.values()) or 1.0
        ordered = sorted(result.member_ids, key=lambda c: result.per_character[c], reverse=True)
        for cid in ordered:
            option = result.assignment[cid]
            role = option.role
            if role == "main-dps" and cid != result.on_field_id:
                role = "sub-dps"
            weapon_name = option.weapon["name"] if option.weapon else "(không có vũ khí phù hợp)"
            set_names = " + ".join(s["name"] for s in option.sets) or "(không có)"
            share = result.per_character[cid] / raw_total
            print(f"     - {index[cid]['name']:<22} {role:<9} {weapon_name:<28} {set_names:<28} {share:5.1%} DMG")
        used = [option.weapon["name"] for option in result.assignment.values() if option.weapon]
        doubled = sorted({name for name in used if used.count(name) > 1})
        if doubled:
            print(f"     ! roster không đủ vũ khí: {', '.join(doubled)} đang được xếp cho nhiều người "
                  f"(thực tế mỗi vũ khí chỉ dùng được cho 1 nhân vật)")
        for note in result.notes:
            print(f"     · {note}")


def run_self_test() -> int:
    """Đối chiếu công thức với ví dụ mẫu trong damage-formula.json."""
    example = gdata.load_damage_formula()["workedExample"]
    inputs = example["inputs"]
    expected = float(example["result"]["value"])

    dm = def_multiplier(inputs["characterLevel"], inputs["monsterLevel"],
                        def_reduction=inputs["defReductionFromKleeC2"])
    res = inputs["resHydroBase"] - inputs["resHydroReductionFromSucroseSwirl"]
    rm = res_multiplier(res)
    amp = amplifying_multiplier(2.0, inputs["elementalMastery"])
    total = (inputs["atk"] * inputs["skillMultiplierStellarisPhantasmLv6"]
             * (1 + inputs["hydroDmgBonus"] + inputs["klee_c2_reactionDmgBonus"])
             * dm * rm * amp * (1 + inputs["critDmg"]))

    print("Đối chiếu công thức với ví dụ chính thức (Mona/Sucrose/Klee):")
    print(f"  DEF Multiplier      = {dm:.5f}   (kỳ vọng 0.55783)")
    print(f"  RES Multiplier      = {rm:.5f}   (kỳ vọng 1.15)")
    print(f"  %EM Bonus           = {em_bonus_amplifying(inputs['elementalMastery']):.5f}   (kỳ vọng 0.26903)")
    print(f"  Amplifying Mult     = {amp:.5f}   (kỳ vọng 2.53806)")
    print(f"  Sát thương cuối     = {total:,.2f}   (kỳ vọng {expected:,.2f})")
    ok = abs(total - expected) / expected < 0.001
    print("  =>", "KHỚP" if ok else "LỆCH")
    return 0 if ok else 1


# ---------------------------------------------------------------------------

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--roster", type=Path, default=DEFAULT_ROSTER,
                        help="file roster JSON (mặc định: roster.json cạnh script)")
    parser.add_argument("--full-roster", action="store_true",
                        help="bỏ qua roster, tính trên toàn bộ nhân vật/vũ khí/thánh di vật")
    parser.add_argument("--floor", type=int, action="append",
                        help="chỉ tính tầng này (lặp lại được); mặc định: tất cả các tầng có dữ liệu")
    parser.add_argument("--top", type=int, default=5, help="số đội hình hiển thị mỗi tầng")
    parser.add_argument("--pool-size", type=int, default=40,
                        help="số nhân vật mạnh nhất giữ lại trước khi ghép đội (chống bùng nổ tổ hợp)")
    parser.add_argument("--self-test", action="store_true",
                        help="chỉ chạy kiểm chứng công thức sát thương rồi thoát")
    args = parser.parse_args()

    if args.self_test:
        return run_self_test()

    characters = gdata.load_characters()
    weapons = gdata.load_weapons()
    team_bonus = gdata.load_team_bonus()
    cycle = gdata.latest_abyss_cycle()

    # Giả định build trong tuning.py là thánh di vật 5★ cấp 20, nên chỉ xét
    # các bộ có phiên bản 5★ (bỏ các bộ tối đa 3★/4★ không thể lên tới mốc đó).
    sets = [s for s in gdata.load_artifact_sets() if "5" in (s.get("rarity") or "")]

    roster = None if args.full_roster else load_roster(args.roster)
    if roster is None and not args.full_roster:
        print(f"Không thấy {args.roster} → chạy ở chế độ toàn bộ roster (so sánh lý thuyết).")
        print("Tạo roster.json từ roster.example.json để lọc theo những gì bạn thực sự có.\n")
    characters, weapons, sets, _cons, refinements = apply_roster(roster, characters, weapons, sets)

    if len(characters) < 4:
        print(f"Cần ít nhất 4 nhân vật, roster hiện có {len(characters)}.", file=sys.stderr)
        return 1

    from abyss_optimizer import build as gbuild
    gbuild.MOONSIGN_IDS = set(team_bonus["moonsign"]["characterIds"])

    print(f"Chu kỳ Trầm Thủy: {cycle['periodStart']} → {cycle['periodEnd']} (bản {cycle['gameVersion']})")
    print(f"Ứng viên: {len(characters)} nhân vật, {len(weapons)} vũ khí, {len(sets)} bộ thánh di vật")

    gear = {c["id"]: pick_gear(c, weapons, sets, refinements) for c in characters}
    index = {c["id"]: c for c in characters}

    pool = sorted(characters, key=lambda c: gear[c["id"]][0].solo_score, reverse=True)
    if len(pool) > args.pool_size:
        print(f"Giới hạn còn {args.pool_size} nhân vật mạnh nhất để ghép đội "
              f"(đổi bằng --pool-size).")
        pool = pool[:args.pool_size]

    floors = args.floor or [f["floor"] for f in cycle["floors"]]
    for floor_number in floors:
        try:
            floor = build_floor_context(cycle, floor_number)
        except StopIteration:
            print(f"Không có dữ liệu tầng {floor_number} trong chu kỳ này.", file=sys.stderr)
            continue
        results = enumerate_teams(pool, gear, floor, team_bonus, top_n=args.top)
        report(results, floor, index, cycle)

    parse = gdata.PARSE
    print()
    print("-" * 78)
    print(f"Parse: {parse.scaling_ok} mốc sát thương dùng được, "
          f"{parse.scaling_skipped} mốc bị bỏ (heal/khiên/CD/không parse được).")
    if parse.artifact_bonus_unmapped:
        unique = sorted(set(parse.artifact_bonus_unmapped))
        print(f"Hiệu ứng thánh di vật chưa quy đổi được ({len(unique)}): {', '.join(unique[:5])}"
              + (" ..." if len(unique) > 5 else ""))
    if parse.res_notes_unparsed:
        print(f"Ghi chú kháng chưa parse được: {len(set(parse.res_notes_unparsed))} dòng")
    print("Kết quả là ƯỚC LƯỢNG xếp hạng, không phải mô phỏng chính xác — xem README mục 'Giới hạn'.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
