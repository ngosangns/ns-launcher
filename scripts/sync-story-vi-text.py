#!/usr/bin/env python3
"""Rewrites quest headings and act names in the Story quest files with the
official Vietnamese localisation from gi.yatta.moe/api/v2/vi.

Archon Quest acts (### Act N — Title) become ### Màn N — <VI title>, and
character story chapters (### <Latin> Chapter — <Name>) become
### <VI chapter> — <VI name>. Act names inside the story-quest tables are
replaced the same way. Chapter-level (##) headings are left alone: the game
has no separate VI chapter title, and the sidebar icon mapping keys off them.

Hangout Events are not covered — Yatta does not expose hangout quests.

    python3 scripts/sync-story-vi-text.py

Network access required. Idempotent: already-translated lines no longer
match the English routes and are skipped.
"""

from __future__ import annotations

import json
import os
import re
import subprocess

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
QUESTS = os.path.join(REPO, "Sources", "NSLauncherApp", "Resources", "Story", "quests")
YATTA = "https://gi.yatta.moe/api/v2/vi"

ARCHON_FILE = "01-archon-quests.md"
STORY_FILE = "02-story-quests.md"

# English act titles whose Yatta route differs.
ROUTE_ALIASES = {
    "Bough Keeper: Dainsleif": "Dainsleif",
    # Our file used the version title; the act's real EN route is this.
    "Truth Amongst the Pages of Purana": "Of Myriad Paths, Flux, and Dissolution",
}

ACT_TOKEN = re.compile(r"(Màn\s+\d+|Mở Đầu|Phần Đệm|Giới Thiệu)\s*$")
ARCHON_HEADING = re.compile(r"^### (?:Act [IVX]+|Prelude|Prologue|Interlude)(?: - Prelude)?\s+—\s+(.+)$")
STORY_HEADING = re.compile(r"^### (.+)$")
TABLE_ACT = re.compile(r"^(\|\s*[IVX]+\s*\|\s*)([^|]+?)(\s*\|.*)$")
VERSION_SUFFIX = re.compile(r"\s*\((v[^)]*)\)\s*$")


def fetch(url: str) -> dict | None:
    result = subprocess.run(
        ["curl", "-sS", "--max-time", "60", "-A", "ns-launcher/vi-text (github.com/ngosangns/ns-launcher)", url],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0 or not result.stdout.strip():
        return None
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError:
        return None
    return payload.get("data") if isinstance(payload, dict) else None


def act_label(chapter_num: str) -> str | None:
    match = ACT_TOKEN.search(chapter_num)
    return re.sub(r"\s+", " ", match.group(1)) if match else None


def chapter_name(chapter_num: str) -> str:
    return ACT_TOKEN.sub("", chapter_num).rstrip(" -").strip()


def load_quests() -> dict[str, dict]:
    data = fetch(f"{YATTA}/quest")
    if not data or not isinstance(data.get("items"), dict):
        raise SystemExit("failed to fetch quest list from Yatta")
    by_route: dict[str, dict] = {}
    for quest in data["items"].values():
        route = quest.get("route")
        if isinstance(route, str) and route and route not in by_route:
            by_route[route] = quest
    return by_route


def rewrite_archon(lines: list[str], by_route: dict[str, dict]) -> tuple[list[str], list[str]]:
    missing: list[str] = []
    out: list[str] = []
    for line in lines:
        match = ARCHON_HEADING.match(line)
        if not match:
            out.append(line)
            continue
        title = match.group(1).strip()
        quest = by_route.get(ROUTE_ALIASES.get(title, title))
        label = quest and act_label(quest.get("chapterNum") or "")
        chapter_title = quest and quest.get("chapterTitle")
        if not quest or not label or not chapter_title:
            missing.append(title)
            out.append(line)
            continue
        out.append(f"### {label} — {chapter_title}")
    return out, missing


def rewrite_story(lines: list[str], by_route: dict[str, dict]) -> tuple[list[str], list[str]]:
    missing: list[str] = []
    out: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        heading = STORY_HEADING.match(line)
        if not heading:
            row = TABLE_ACT.match(line)
            if row:
                cell = row.group(2).strip()
                version = VERSION_SUFFIX.search(cell)
                route = VERSION_SUFFIX.sub("", cell).strip()
                quest = by_route.get(ROUTE_ALIASES.get(route, route))
                if quest and quest.get("chapterTitle"):
                    suffix = f" ({version.group(1)})" if version else ""
                    line = f"{row.group(1)}{quest['chapterTitle']}{suffix}{row.group(3)}"
            out.append(line)
            i += 1
            continue

        # Collect act routes from the table rows inside this section.
        routes: list[str] = []
        j = i + 1
        while j < len(lines) and not lines[j].startswith("### ") and not lines[j].startswith("## "):
            row = TABLE_ACT.match(lines[j])
            if row:
                cell = VERSION_SUFFIX.sub("", row.group(2).strip()).strip()
                routes.append(cell)
            j += 1
        quests = [by_route[ROUTE_ALIASES.get(r, r)] for r in routes if ROUTE_ALIASES.get(r, r) in by_route]

        segments = [part.strip() for part in heading.group(1).split(" — ")]
        if not quests:
            missing.append(heading.group(1))
            out.append(line)
            i += 1
            continue
        chapter = chapter_name(quests[0].get("chapterNum") or "")
        if len(segments) >= 3:
            # Tribal chronicle: <chapter> — <tribe> — <character>
            tribe = quests[0].get("chapterImageTitle") or segments[-2]
            out.append(f"### {chapter} — {tribe} — {segments[-1]}")
        else:
            name = quests[0].get("chapterImageTitle") or segments[-1]
            out.append(f"### {chapter} — {name}")
        i += 1
    return out, missing


def main() -> None:
    by_route = load_quests()
    for filename, rewriter in ((ARCHON_FILE, rewrite_archon), (STORY_FILE, rewrite_story)):
        path = os.path.join(QUESTS, filename)
        with open(path, encoding="utf-8") as handle:
            lines = handle.read().splitlines()
        out, missing = rewriter(lines, by_route)
        with open(path, "w", encoding="utf-8") as handle:
            handle.write("\n".join(out) + "\n")
        changed = sum(1 for a, b in zip(lines, out) if a != b)
        print(f"{filename}: {changed} lines rewritten")
        for title in missing:
            print(f"  unmatched: {title}")


if __name__ == "__main__":
    main()
