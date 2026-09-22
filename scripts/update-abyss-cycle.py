#!/usr/bin/env python3
"""One entry point for the Spiral Abyss (Trầm Thủy) cycle update flow.

## Why this exists

`Sources/NSLauncherApp/Resources/Abyss/abyss-monsters/` is the fastest-expiring
data in the repo — monsters and the Blessing of the Abyssal Moon change every
two weeks (reset on the 1st and the 16th) — but updating it used to mean
following a checklist spread across three READMEs: hand-write two new files
with matching dates, run two independent sync scripts, hand-run a validation
heredoc copied out of `toi-uu-doi-hinh/data-model/README.md`, then remember to
run `npm test` in `web/`. Nothing enforced the order, and a step skipped
silently (forgetting to sync resistance, say) does not fail loudly.

This script does not replace the one step that has to stay manual — reading
the new cycle's monsters and blessing text off the wiki/TextMap and writing
them into JSON — but it standardizes everything mechanical around it, and
keeps a half-filled cycle out of the files the site serves while it is still
being authored:

    python3 scripts/update-abyss-cycle.py new              # scaffold the next cycle
    # ... fill in monsters / blessing / Ley Line Disorder by hand ...
    python3 scripts/update-abyss-cycle.py sync              # resistance + HP + schema + npm test
    python3 scripts/update-abyss-cycle.py publish           # copy the finished file into abyss-monsters/

## `new`

Reads the newest bundled cycle, computes the next Spiral Abyss period
(the day after its `periodEnd` — a monthly cycle, 16th of one month to the
15th of the next, per `next_period()`'s doc comment), and writes:

- `toi-uu-doi-hinh/quai-vat-la-hoan/<range>.md` — a stub with the standard
  header and a TODO checklist, never overwriting an existing file.
- `~/Library/Application Support/NSLauncher/abyss-cycles/<range>.json` — a
  schema-shaped stub, **not** the published `Resources/Abyss/abyss-monsters/`
  directory. The site and `npm test` only read the published files, so a
  half-filled draft stays off the site until `publish`. Landing the stub
  straight in `abyss-monsters/` would ship an unfinished cycle.

  Floor/chamber/wave numbers and monster levels are copied from the previous
  cycle (those rarely change), but every monster list is emptied and every
  per-cycle text field (blessing, Ley Line Disorder, recommendation) is
  replaced with `"TODO"` — so a field left unfilled is obviously unfilled,
  not silently stale.

  **Whatever fills the monster lists in afterward must keep each monster
  object on one line.** `sync-abyss-monster-resistance.py` and
  `sync-abyss-monster-hp.py` patch this file by line, anchored on a regex
  that expects `"name"` through `"hpRatio"` on a single line (see the
  docstring of the first script) — a monster object pretty-printed across
  several lines (plain `json.dump(..., indent=2)`, say) makes both scripts
  silently match nothing and write nothing, with no error. `new` itself
  never hits this (it only ever writes empty `"monsters": []` lists), but a
  hand-edit or a different tool filling them in for real can.

## `sync [cycle.json]`

Defaults to the newest file in the override directory above, falling back to
the newest bundled cycle if that directory is empty. Runs, in order, and
stops at the first failure:

1. `scripts/sync-abyss-monster-resistance.py <file>`
2. `scripts/sync-abyss-monster-hp.py <file>`
3. JSON Schema validation against `abyss-cycle.schema.json`
4. `npm test` in `web/`

Steps 1-2 need the monster names already in the file (they patch resistance
and HP onto lines that name a monster they can resolve) and network access
(they call `gi.yatta.moe` and the Fandom wiki). Step 4 does not exercise an
override-only file (see `new` above) — it is a regression check that
whatever is already published still loads, not a check of the new cycle's
numbers.

## `publish [cycle.json]`

Once a cycle in the override directory is filled in and synced, copies it
into `Sources/NSLauncherApp/Resources/Abyss/abyss-monsters/` — the step that
actually ships it to the site. Refuses to overwrite an existing file there.
From this point on `npm test` sees the new cycle.
"""

from __future__ import annotations

import datetime
import glob
import json
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RESOURCES = os.path.join(ROOT, "Sources/NSLauncherApp/Resources/Abyss")
BUNDLED_CYCLES = os.path.join(RESOURCES, "abyss-monsters")
OVERRIDE_CYCLES = os.path.expanduser("~/Library/Application Support/NSLauncher/abyss-cycles")
DOC_DIR = os.path.join(ROOT, "toi-uu-doi-hinh/quai-vat-la-hoan")
SCHEMA = os.path.join(ROOT, "toi-uu-doi-hinh/data-model/schema/abyss-cycle.schema.json")

TODO = "TODO"


def bundled_cycles() -> list[str]:
    files = sorted(glob.glob(os.path.join(BUNDLED_CYCLES, "*.json")))
    if not files:
        raise SystemExit(f"no bundled cycle files found under {BUNDLED_CYCLES}")
    return files


def latest_bundled_cycle_path() -> str:
    return bundled_cycles()[-1]


def latest_working_cycle_path() -> str:
    """The override draft in progress, or the newest bundled cycle if there is none."""
    overrides = sorted(glob.glob(os.path.join(OVERRIDE_CYCLES, "*.json")))
    if overrides:
        return overrides[-1]
    return latest_bundled_cycle_path()


def next_period(prev_end: datetime.date) -> tuple[datetime.date, datetime.date]:
    """The next Spiral Abyss period after one that ended on `prev_end`.

    `TowerScheduleExcelConfigData` (the game's own schedule table) shows every
    entry from 2025-09 onward closing on the 16th of the month, never the
    1st — reset moved from biweekly to monthly at that point, and the whole
    2026 run in this repo is entirely monthly. A period starting on the 16th
    therefore runs to the 15th of the *following* month (2026-09-16 →
    2026-10-15), not to the end of its own month — the earlier version of
    this function computed the latter, which is the pre-2025-09 biweekly
    math and gave the wrong `periodEnd` for every monthly cycle.

    The `start.day == 1` branch is kept only for the historical bundled
    cycles that predate the monthly switch; nothing after 2025-09 should
    ever hit it.
    """
    start = prev_end + datetime.timedelta(days=1)
    if start.day == 16:
        next_month = start.month + 1 if start.month < 12 else 1
        next_year = start.year if start.month < 12 else start.year + 1
        end = datetime.date(next_year, next_month, 15)
    elif start.day == 1:
        end = start.replace(day=15)
    else:
        raise SystemExit(
            f"computed next period start {start.isoformat()} does not land on the 1st or "
            "16th reset day — pass --start/--end explicitly"
        )
    return start, end


def range_slug(start: datetime.date, end: datetime.date) -> str:
    return f"{start.isoformat()}-den-{end.isoformat()}"


def strip_monsters(floors: list[dict]) -> list[dict]:
    stripped = []
    for floor in floors:
        chambers = []
        for chamber in floor["chambers"]:
            waves = [{"wave": wave["wave"], "monsters": []} for wave in chamber["waves"]]
            chambers.append(
                {"chamber": chamber["chamber"], "monsterLevel": chamber["monsterLevel"], "waves": waves}
            )
        entry = {"floor": floor["floor"]}
        if "enemyHPMultiplier" in floor:
            entry["enemyHPMultiplier"] = floor["enemyHPMultiplier"]
        entry["leyLineDisorder"] = TODO
        entry["chambers"] = chambers
        entry["recommendation"] = TODO
        stripped.append(entry)
    return stripped


def cmd_new(args: list[str]) -> int:
    start_arg = None
    end_arg = None
    rest = list(args)
    while rest:
        flag = rest.pop(0)
        if flag == "--start":
            start_arg = rest.pop(0)
        elif flag == "--end":
            end_arg = rest.pop(0)
        else:
            raise SystemExit(f"unknown argument: {flag}")

    prev_path = latest_bundled_cycle_path()
    with open(prev_path, encoding="utf-8") as handle:
        prev = json.load(handle)
    prev_end = datetime.date.fromisoformat(prev["periodEnd"])

    if start_arg:
        start = datetime.date.fromisoformat(start_arg)
        end = datetime.date.fromisoformat(end_arg) if end_arg else next_period(start - datetime.timedelta(days=1))[1]
    else:
        start, end = next_period(prev_end)

    slug = range_slug(start, end)
    json_path = os.path.join(OVERRIDE_CYCLES, f"{slug}.json")
    md_path = os.path.join(DOC_DIR, f"{slug}.md")
    for path in (json_path, md_path):
        if os.path.exists(path):
            raise SystemExit(f"refusing to overwrite existing file: {path}")

    cycle = {
        "sourceFile": TODO,
        "dataFetchDate": datetime.date.today().isoformat(),
        "periodStart": start.isoformat(),
        "periodEnd": end.isoformat(),
        "gameVersion": prev.get("gameVersion", TODO),
        "blessingOfTheAbyssalMoon": {
            "name": TODO,
            "nameVI": TODO,
            "description": TODO,
            "timeStart": f"{start.isoformat()} 04:00:00",
            "timeEnd": f"{(end + datetime.timedelta(days=1)).isoformat()} 03:59:59",
            "relatedMechanic": None,
        },
        "floors": strip_monsters(prev["floors"]),
    }
    os.makedirs(OVERRIDE_CYCLES, exist_ok=True)
    with open(json_path, "w", encoding="utf-8") as handle:
        json.dump(cycle, handle, ensure_ascii=False, indent=2)
        handle.write("\n")

    md = f"""# Quái thú Trầm Thủy — {start.isoformat()} đến {end.isoformat()}

> **Ngày lấy dữ liệu:** {datetime.date.today().isoformat()}
> **Nguồn:** TODO — Fandom `Spiral Abyss/Floors/{start.isoformat()}`, và
> `TowerScheduleExcelConfigData`/`TowerFloorExcelConfigData` + `TextMap{{EN,VI}}`
> cho câu chữ Uyên Nguyệt Chúc Phúc / Ley Line Disorder (xem README của
> `Sources/NSLauncherApp/Resources/Abyss/` — không tự dịch, không lấy từ wiki
> cho hai trường này).

## TODO trước khi chạy `sync`

- [ ] Uyên Nguyệt Chúc Phúc (name/nameVI/description) trong file JSON.
- [ ] Ley Line Disorder từng tầng 9–12 (và từng nửa nếu khác nhau).
- [ ] Danh sách quái mỗi wave: tên đúng như game/wiki, kích thước, nguyên tố,
      weakpoint, mechanics, hpRatio nếu biết.
- [ ] `recommendation` từng tầng (định hướng đội hình, không cần đội cụ thể).
- [ ] `gameVersion` nếu bản game đổi so với chu kỳ trước.
- [ ] Cơ chế mới của bản này (nếu có) — thêm một mục riêng bên dưới, theo
      mẫu chu kỳ trước.

File JSON nằm ở `~/Library/Application Support/NSLauncher/abyss-cycles/` —
web không đọc thư mục này, nên chu kỳ dở dang không lên site và `npm test`
không thấy.

Sau khi điền xong danh sách quái ở trên (tên quái là bắt buộc — hai script
sync khớp theo tên), chạy:

```bash
python3 scripts/update-abyss-cycle.py sync       # resistance + HP + schema + npm test
python3 scripts/update-abyss-cycle.py publish     # copy vào abyss-monsters/ khi đã ưng ý
```
"""
    with open(md_path, "w", encoding="utf-8") as handle:
        handle.write(md)

    print(f"wrote {json_path}")
    print(f"wrote {os.path.relpath(md_path, ROOT)}")
    print("next: fill in the TODOs (monsters, blessing, Ley Line Disorder), then run")
    print("      python3 scripts/update-abyss-cycle.py sync")
    return 0


def run_step(description: str, command: list[str]) -> None:
    print(f"== {description} ==", flush=True)
    result = subprocess.run(command, cwd=ROOT)
    if result.returncode != 0:
        raise SystemExit(f"failed: {description} (exit {result.returncode})")


def validate_cycle(path: str) -> None:
    import jsonschema

    with open(SCHEMA, encoding="utf-8") as handle:
        schema = json.load(handle)
    with open(path, encoding="utf-8") as handle:
        doc = json.load(handle)
    jsonschema.validate(doc, schema)
    print(f"schema OK: {path}", flush=True)


def cmd_sync(args: list[str]) -> int:
    path = os.path.abspath(args[0]) if args else latest_working_cycle_path()
    if not os.path.exists(path):
        raise SystemExit(f"no such cycle file: {path}")

    run_step(
        "resistance sync (scripts/sync-abyss-monster-resistance.py)",
        [sys.executable, os.path.join(ROOT, "scripts/sync-abyss-monster-resistance.py"), path],
    )
    run_step(
        "HP sync (scripts/sync-abyss-monster-hp.py)",
        [sys.executable, os.path.join(ROOT, "scripts/sync-abyss-monster-hp.py"), path],
    )
    print("== schema validation ==", flush=True)
    validate_cycle(path)
    run_step("npm test (web/)", ["npm", "test", "--prefix", os.path.join(ROOT, "web")])
    print("all steps passed")
    if os.path.commonpath([path, OVERRIDE_CYCLES]) == OVERRIDE_CYCLES:
        print("note: npm test never sees this override-only file — it only checks the published data still loads")
    return 0


def cmd_publish(args: list[str]) -> int:
    path = os.path.abspath(args[0]) if args else latest_working_cycle_path()
    if not os.path.exists(path):
        raise SystemExit(f"no such cycle file: {path}")

    dest = os.path.join(BUNDLED_CYCLES, os.path.basename(path))
    if os.path.exists(dest):
        raise SystemExit(f"refusing to overwrite existing bundled file: {dest}")
    if os.path.abspath(path) == os.path.abspath(dest):
        raise SystemExit(f"{path} is already the bundled file")

    shutil.copyfile(path, dest)
    print(f"published {dest}")
    print("the site and npm test now see this cycle")
    return 0


def main(argv: list[str]) -> int:
    if not argv or argv[0] not in ("new", "sync", "publish"):
        print(__doc__)
        return 0 if argv and argv[0] in ("-h", "--help") else 1
    if argv[0] == "new":
        return cmd_new(argv[1:])
    if argv[0] == "sync":
        return cmd_sync(argv[1:])
    return cmd_publish(argv[1:])


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
