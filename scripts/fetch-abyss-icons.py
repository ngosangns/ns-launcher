#!/usr/bin/env python3
"""Fetches Resources/Abyss/icons/{characters,weapons}/<slug>.png.

Character and weapon portraits are matched by name against gi.yatta.moe — the
same source the rest of the Abyss data was transcribed from — and saved under
our own slug names. Nothing at runtime needs to know Yatta's internal icon
codenames; Swift just opens icons/characters/<id>.png, the same way
`characters/<id>` and `weapons/<id>` already work for the rest of the data.

Run it after adding characters or weapons:

    python3 scripts/fetch-abyss-icons.py

Network access required. A file that already exists is left alone, so re-runs
after adding a handful of new characters only fetch the new ones; pass
--force to refetch everything.
"""

from __future__ import annotations

import argparse
import glob
import json
import os
import re
import subprocess
import unicodedata

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(REPO, "Sources", "NSLauncherApp", "Resources", "Abyss")
ICONS = os.path.join(DATA, "icons")

YATTA = "https://gi.yatta.moe/api/v2/en"
ASSET_HOST = "https://gi.yatta.moe/assets/UI"
USER_AGENT = "ns-launcher/icons (github.com/ngosangns/ns-launcher)"

# The Traveler's portrait icon does not vary by element — only by which twin
# is picked — and Yatta has no per-element art to match against. Aether (the
# boy) is used for every traveler-* slug; this is an arbitrary but consistent
# choice made once here, not a claim that one twin is "the" Traveler.
TRAVELER_ICON = "UI_AvatarIcon_PlayerBoy"


def fetch_json(url: str) -> dict:
    result = subprocess.run(
        ["curl", "-sSL", "--max-time", "60", "-A", USER_AGENT, url],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise SystemExit(f"curl failed for {url}: {result.stderr.strip()}")
    return json.loads(result.stdout)


def download(icon_name: str, destination: str) -> bool:
    """Saves one PNG. Cleans up a partial file rather than leaving a 0-byte
    or HTML-error-page file that would later decode as a broken image."""
    result = subprocess.run(
        ["curl", "-sSL", "--max-time", "30", "-A", USER_AGENT,
         "-o", destination, f"{ASSET_HOST}/{icon_name}.png"],
        capture_output=True,
        text=True,
    )
    ok = result.returncode == 0 and os.path.exists(destination) and os.path.getsize(destination) > 100
    if not ok and os.path.exists(destination):
        os.remove(destination)
    return ok


def normalize(name: str) -> str:
    """Folds a display name the same way generate-abyss-game-ids.py does, so
    the two scripts agree on what counts as a match."""
    name = re.sub(r"\s*\([^)]*\)\s*$", "", name or "")
    name = unicodedata.normalize("NFKD", name)
    name = "".join(c for c in name if not unicodedata.combining(c))
    return re.sub(r"[^a-z0-9]+", "", name.lower().replace("’", "'"))


def load_records(pattern: str, key: str) -> list[dict]:
    records: list[dict] = []
    for path in sorted(glob.glob(os.path.join(DATA, pattern))):
        payload = json.load(open(path, encoding="utf-8"))
        records += payload[key] if isinstance(payload, dict) and key in payload else payload
    return records


def fetch_for(records: list[dict], icon_by_name: dict[str, str], subdir: str,
              force: bool) -> tuple[int, int, list[str]]:
    os.makedirs(os.path.join(ICONS, subdir), exist_ok=True)
    fetched, skipped, missing = 0, 0, []

    for record in records:
        slug = record["id"]
        destination = os.path.join(ICONS, subdir, f"{slug}.png")
        if os.path.exists(destination) and not force:
            skipped += 1
            continue

        icon = TRAVELER_ICON if slug.startswith("traveler-") else icon_by_name.get(normalize(record["name"]))
        if icon and download(icon, destination):
            fetched += 1
        else:
            missing.append(slug)

    return fetched, skipped, missing


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--force", action="store_true", help="refetch files that already exist")
    args = parser.parse_args()

    characters = load_records("characters/*.json", "characters")
    weapons = load_records("weapons/*.json", "weapons")

    # "traveler" is excluded here the same way generate-abyss-game-ids.py
    # excludes it: every Traveler variant shares that one display name, so
    # matching on it would be ambiguous. TRAVELER_ICON handles them instead.
    avatar_icons = {
        normalize(item["name"]): item["icon"]
        for item in fetch_json(f"{YATTA}/avatar")["data"]["items"].values()
        if normalize(item["name"]) != "traveler"
    }
    weapon_icons = {
        normalize(item["name"]): item["icon"]
        for item in fetch_json(f"{YATTA}/weapon")["data"]["items"].values()
    }

    c_fetched, c_skipped, c_missing = fetch_for(characters, avatar_icons, "characters", args.force)
    print(f"characters: fetched {c_fetched}, already had {c_skipped}, missing {len(c_missing)}")
    if c_missing:
        print(f"  missing: {', '.join(c_missing)}")

    w_fetched, w_skipped, w_missing = fetch_for(weapons, weapon_icons, "weapons", args.force)
    print(f"weapons: fetched {w_fetched}, already had {w_skipped}, missing {len(w_missing)}")
    if w_missing:
        print(f"  missing: {', '.join(w_missing)}")

    return 1 if (c_missing or w_missing) else 0


if __name__ == "__main__":
    raise SystemExit(main())
