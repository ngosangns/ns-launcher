#!/usr/bin/env python3
"""Writes Resources/Abyss/frames.json: how long each character's attack string,
charged attack, skill and burst take, from gcsim's frame data.

## Why this exists

Until this file every on-field character made six normal-attack strings and
two charged attacks per rotation, however long those take. The gcsim
benchmark (`AbyssBenchmarkTests`, docs/redesign.md §7.6) measured what that
costs: normal-attack carries with long strings were over-rated (Diluc,
Eula, Yoimiya, Hu Tao) and charged-attack carries under-rated (Neuvillette,
Tighnari, Sethos). The game files the project reads carry no animation
lengths; gcsim (github.com/genshinsim/gcsim, MIT) does, counted frame by
frame by its contributors and credited in each character's config.yml.

## What is read

In each character's Go package, at a pinned commit:

- `attackFrames[i] = frames.InitNormalCancelSlice(hitmark, D)` with an optional
  `attackFrames[i][action.ActionAttack] = N`: hit i hands over to the next
  normal attack after N frames, or D when no cancel is given. The string's
  length is the sum.
- `chargeFrames` (or `aimedFrames[1]`, a bow's fully-charged shot): frames
  from the charged attack to the next normal attack.
- `skillFrames` / `skillPressFrames` and `burstFrames`: frames until the
  character can swap out (`ActionSwap`), or the full animation.

Named constants are resolved from the package. A value the patterns do not
recognise is left null and reported — the Swift side stands in the median of
every character that resolved and names the gap in diagnostics. Nothing is
estimated here.

## Usage

    python3 scripts/sync-abyss-frames.py

Network access required (the GitHub tree API once, then the character
sources from raw.githubusercontent.com).
"""

from __future__ import annotations

import collections
import concurrent.futures
import datetime
import json
import os
import re
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(REPO, "Sources", "NSLauncherApp", "Resources", "Abyss")
OUTPUT = os.path.join(DATA, "frames.json")
COMMIT = "a086a05f8bbd7cac08aee3500a952ec30cd3017f"
RAW = f"https://raw.githubusercontent.com/genshinsim/gcsim/{COMMIT}/"
TREE = f"https://api.github.com/repos/genshinsim/gcsim/git/trees/{COMMIT}?recursive=1"
UA = "ns-launcher/frames (github.com/ngosangns/ns-launcher)"


def fetch(url: str) -> str:
    result = subprocess.run(["curl", "-sSL", "--fail", "--max-time", "60", "-A", UA, url],
                            capture_output=True, text=True)
    if result.returncode != 0:
        raise SystemExit(f"curl failed for {url}: {result.stderr.strip()}")
    return result.stdout


def constants(source: str) -> dict[str, int]:
    found: dict[str, int] = {}
    for match in re.finditer(r"\b(\w+)\s*=\s*(\d+)\b", source):
        found.setdefault(match.group(1), int(match.group(2)))
    return found


def value(expression: str, names: dict[str, int]) -> int | None:
    expression = expression.strip()
    if re.fullmatch(r"\d+", expression):
        return int(expression)
    return names.get(expression)


def slice_frames(source: str, name: str, names: dict[str, int]) -> dict[int, dict[str, int | None]]:
    out: dict[int, dict[str, int | None]] = {}
    init = (r"\b" + name + r"\[(\d+)\]\s*=\s*frames\.Init(?:NormalCancel|Abil)Slice\("
            r"(?:[^,()]+(?:\[[^\]]*\])*\s*,\s*)?(\w+)\)")
    for match in re.finditer(init, source):
        out.setdefault(int(match.group(1)), {})["default"] = value(match.group(2), names)
    for match in re.finditer(r"\b" + name + r"\[(\d+)\]\[action\.(\w+)\]\s*=\s*([\w\[\]]+)", source):
        out.setdefault(int(match.group(1)), {})[match.group(2)] = value(match.group(3), names)
    return out


def single_frames(source: str, name: str, names: dict[str, int]) -> dict[str, int | None]:
    match = re.search(r"\b" + name + r"\s*=\s*frames\.InitAbilSlice\((\w+)\)", source)
    if match:
        out: dict[str, int | None] = {"default": value(match.group(1), names)}
        for cancel in re.finditer(r"\b" + name + r"\[action\.(\w+)\]\s*=\s*([\w\[\]]+)", source):
            out[cancel.group(1)] = value(cancel.group(2), names)
        return out
    return slice_frames(source, name, names).get(0, {})


def first_frames(source: str, candidates: list[str], names: dict[str, int]) -> dict[str, int | None]:
    for name in candidates:
        found = single_frames(source, name, names)
        if found.get("default"):
            return found
    return {}


def read_character(files: dict[str, str]) -> dict:
    names = constants("\n".join(files.values()))
    attack = slice_frames(files.get("attack.go", ""), "attackFrames", names)
    combo = None
    if attack and all(entry.get("default") for entry in attack.values()):
        combo = [attack[i].get("ActionAttack") or attack[i]["default"] for i in sorted(attack)]
        if None in combo:
            combo = None
    charge = first_frames(files.get("charge.go", ""), ["chargeFrames", "chargeFinalFrames"], names)
    charged = (charge.get("ActionAttack") or charge.get("default")) if charge else None
    aimed = slice_frames(files.get("aimed.go", ""), "aimedFrames", names)
    if charged is None and aimed:
        index = 1 if 1 in aimed else max(aimed)
        charged = aimed[index].get("ActionAttack") or aimed[index].get("default")
    skill = first_frames(files.get("skill.go", ""), ["skillFrames", "skillPressFrames", "skillTapFrames"], names)
    burst = first_frames(files.get("burst.go", ""), ["burstFrames"], names)
    return collections.OrderedDict([
        ("comboFrames", combo),
        ("chargedFrames", charged),
        ("skillFrames", (skill.get("ActionSwap") or skill.get("default")) if skill else None),
        ("burstFrames", (burst.get("ActionSwap") or burst.get("default")) if burst else None),
    ])


def main() -> int:
    with open(os.path.join(DATA, "game-ids.json"), encoding="utf-8") as handle:
        slug_by_id = json.load(handle)["characters"]
    character_dm = json.loads(fetch(RAW + "ui/packages/db/src/Data/character.dm.json"))
    character_dm = character_dm.get("data", character_dm)
    slug_by_key = {key: slug_by_id[str(entry["id"])] for key, entry in character_dm.items()
                   if str(entry["id"]) in slug_by_id}

    paths = [item["path"] for item in json.loads(fetch(TREE))["tree"]]
    by_dir: dict[str, list[str]] = collections.defaultdict(list)
    for path in paths:
        match = re.fullmatch(r"internal/characters/([^/]+)/([^/]+\.go)", path)
        if match and not match.group(2).endswith("_test.go"):
            by_dir[match.group(1)].append(path)

    def load(directory: str) -> tuple[str, str | None, dict[str, str]]:
        sources = {os.path.basename(p): fetch(RAW + p) for p in by_dir[directory]}
        key = next((name[3:-6] for name in sources if name.startswith("zz_") and name.endswith(".dm.go")), None)
        return directory, key, sources

    with concurrent.futures.ThreadPoolExecutor(8) as pool:
        loaded = list(pool.map(load, sorted(by_dir)))

    characters: dict[str, dict] = {}
    unresolved: list[str] = []
    for directory, key, sources in loaded:
        slug = slug_by_key.get(key or "")
        if slug is None:
            continue
        record = read_character({k: v for k, v in sources.items() if not k.startswith("zz_")})
        record["gcsim"] = f"internal/characters/{directory}"
        record.move_to_end("gcsim", last=False)
        characters[slug] = record
        unresolved += [f"{slug}: {field}" for field, v in record.items() if v is None]

    output = collections.OrderedDict([
        ("_doc", "Độ dài chuỗi đòn thường, đòn nặng, kỹ năng và nộ của từng nhân vật, tính bằng frame (60/giây), đọc "
                 "từ frame data của gcsim (github.com/genshinsim/gcsim, MIT — số frame do cộng đồng đếm, ghi công ở "
                 "config.yml của từng nhân vật). SINH TỰ ĐỘNG bằng scripts/sync-abyss-frames.py — đừng sửa tay. "
                 "comboFrames[i] = frame từ đòn i tới đòn thường kế tiếp; chargedFrames = từ đòn nặng tới đòn thường kế "
                 "tiếp (cung: mũi sạc đầy); skillFrames/burstFrames = tới lúc đổi người được. null = mẫu code không nhận "
                 "ra; Swift dùng trung vị và báo ở diagnostics.framesEstimated."),
        ("source", f"gcsim@{COMMIT[:7]} internal/characters/*/{{attack,charge,aimed,skill,burst}}.go"),
        ("fetchedOn", datetime.date.today().isoformat()),
        ("unresolved", sorted(unresolved)),
        ("characters", dict(sorted(characters.items()))),
    ])
    with open(OUTPUT, "w", encoding="utf-8") as handle:
        json.dump(output, handle, ensure_ascii=False, indent=1)
        handle.write("\n")
    print(f"wrote {len(characters)} characters; {len(unresolved)} unresolved fields")
    return 0


if __name__ == "__main__":
    sys.exit(main())
