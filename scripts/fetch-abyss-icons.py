#!/usr/bin/env python3
"""Fetches Resources/Abyss/icons/{characters,weapons,artifact-sets,monsters}/<slug>.png.

Character and weapon portraits are matched by name against gi.yatta.moe — the
same source the rest of the Abyss data was transcribed from — and saved under
our own slug names. Nothing at runtime needs to know Yatta's internal icon
codenames; Swift just opens icons/characters/<id>.png, the same way
`characters/<id>` and `weapons/<id>` already work for the rest of the data.

Artifact sets are matched by numeric game id through `game-ids.json` instead
of by name (the same table `sync-abyss-artifact-text.py` uses), since Yatta's
`reliquary` endpoint carries an `icon` field directly on each set and a name
match would be one more way to silently pick the wrong set. Their icon files
live under a different Yatta asset path (`assets/UI/reliquary/`) than avatar
and weapon icons.

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
RELIQUARY_ASSET_HOST = "https://gi.yatta.moe/assets/UI/reliquary"
MONSTER_ASSET_HOST = "https://gi.yatta.moe/assets/UI/monster"
USER_AGENT = "ns-launcher/icons (github.com/ngosangns/ns-launcher)"

# These local legends are not in Yatta's monster catalog yet. The files are
# the official 256px enemy portraits from the Genshin Impact Wiki CDN.
WIKI_MONSTER_ICONS = {
    "Battle-Hardened Domovoy Sculptor": "https://static.wikia.nocookie.net/gensin-impact/images/1/17/Churin_Icon.png/revision/latest?format=original",
    "Battle-Hardened Lightkeeper": "https://static.wikia.nocookie.net/gensin-impact/images/f/f0/Sigurd_%28Local_Legend%29_Icon.png/revision/latest?format=original",
}

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


def download(icon_name: str, destination: str, asset_host: str = ASSET_HOST) -> bool:
    """Saves one PNG. Cleans up a partial file rather than leaving a 0-byte
    or HTML-error-page file that would later decode as a broken image."""
    result = subprocess.run(
        ["curl", "-sSL", "--max-time", "30", "-A", USER_AGENT,
         "-o", destination, f"{asset_host}/{icon_name}.png"],
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


def fetch_artifact_sets(force: bool) -> tuple[int, int, list[str]]:
    subdir = "artifact-sets"
    os.makedirs(os.path.join(ICONS, subdir), exist_ok=True)

    sets = load_records("artifact-sets.json", "artifactSets")
    with open(os.path.join(DATA, "game-ids.json"), encoding="utf-8") as handle:
        game_id_by_slug = {slug: game_id for game_id, slug in json.load(handle)["artifactSets"].items()}
    reliquary_sets = fetch_json(f"{YATTA}/reliquary")["data"]["items"]

    fetched, skipped, missing = 0, 0, []
    for record in sets:
        slug = record["id"]
        destination = os.path.join(ICONS, subdir, f"{slug}.png")
        if os.path.exists(destination) and not force:
            skipped += 1
            continue

        game_id = game_id_by_slug.get(slug)
        icon = reliquary_sets.get(game_id, {}).get("icon") if game_id else None
        if icon and download(icon, destination, asset_host=RELIQUARY_ASSET_HOST):
            fetched += 1
        else:
            missing.append(slug)

    return fetched, skipped, missing


def iter_cycle_monsters() -> list[dict]:
    monsters: list[dict] = []
    for path in sorted(glob.glob(os.path.join(DATA, "abyss-monsters", "*.json"))):
        payload = json.load(open(path, encoding="utf-8"))
        for floor in payload.get("floors", []):
            for chamber in floor.get("chambers", []):
                for wave in chamber.get("waves", []):
                    monsters.extend(wave.get("monsters", []))
    return monsters


def fetch_monsters(force: bool) -> tuple[int, int, list[str]]:
    """Saves icons/monsters/<gameId>.png, keyed the same way the cycle JSON is."""
    subdir = "monsters"
    os.makedirs(os.path.join(ICONS, subdir), exist_ok=True)
    catalog = fetch_json(f"{YATTA}/monster")["data"]["items"]
    by_id = {int(item["id"]): item.get("icon") for item in catalog.values() if item.get("icon")}
    by_name = {normalize(item["name"]): item.get("icon") for item in catalog.values() if item.get("icon")}

    fetched, skipped, missing = 0, 0, []
    seen: set[str] = set()
    for monster in iter_cycle_monsters():
        game_id = monster.get("gameId")
        slug = str(game_id) if game_id else normalize(monster.get("name") or "")
        if not slug or slug in seen:
            continue
        seen.add(slug)
        destination = os.path.join(ICONS, subdir, f"{slug}.png")
        if os.path.exists(destination) and not force:
            skipped += 1
            continue
        icon = None
        if game_id:
            icon = by_id.get(int(game_id))
        if not icon:
            for candidate in monster_name_candidates(monster):
                icon = by_name.get(normalize(candidate))
                if icon:
                    break
        wiki = WIKI_MONSTER_ICONS.get(monster.get("name") or "")
        if wiki and download_url(wiki, destination):
            fetched += 1
        elif icon and download(icon, destination, asset_host=MONSTER_ASSET_HOST):
            fetched += 1
        else:
            missing.append(f"{monster.get('name')} ({slug})")
    return fetched, skipped, missing


def monster_name_candidates(monster: dict) -> list[str]:
    """Base-form names to try when a rotation title is a prefix/variant."""
    names: list[str] = []
    raw = monster.get("name") or ""
    page = (monster.get("hp") or {}).get("page") or ""
    for value in (raw, page):
        if not value:
            continue
        names.append(value)
        stripped = re.sub(r"^(?:Battle-Hardened|Veteran)\s+", "", value)
        stripped = re.sub(r"\s+-\s+(?:Ousia|Pneuma)$", "", stripped)
        stripped = re.sub(r"\s*\([^)]*\)\s*$", "", stripped)
        names.append(stripped)
    # Preserve order, drop empties/dupes.
    seen: set[str] = set()
    out: list[str] = []
    for name in names:
        if name and name not in seen:
            seen.add(name)
            out.append(name)
    return out


# Official element emblems and the game wordmark, from the Genshin Impact Wiki
# CDN (the same files genshin-db cites). Saved under our icon tree so the site
# does not hotlink.
ELEMENT_ICON_URLS = {
    "Pyro": "https://static.wikia.nocookie.net/gensin-impact/images/e/e8/Element_Pyro.png",
    "Hydro": "https://static.wikia.nocookie.net/gensin-impact/images/3/35/Element_Hydro.png",
    "Anemo": "https://static.wikia.nocookie.net/gensin-impact/images/a/a4/Element_Anemo.png",
    "Electro": "https://static.wikia.nocookie.net/gensin-impact/images/7/73/Element_Electro.png",
    "Dendro": "https://static.wikia.nocookie.net/gensin-impact/images/f/f4/Element_Dendro.png",
    "Cryo": "https://static.wikia.nocookie.net/gensin-impact/images/8/88/Element_Cryo.png",
    "Geo": "https://static.wikia.nocookie.net/gensin-impact/images/4/4a/Element_Geo.png",
    # Physical has no base-game emblem; the TCG card icon is the official one.
    "Physical": "https://static.wikia.nocookie.net/gensin-impact/images/d/d8/Element_Physical_TCG.png",
}
LOGO_URL = "https://static.wikia.nocookie.net/gensin-impact/images/2/2a/Genshin-Impact-Logo.png/revision/latest"


def download_url(url: str, destination: str) -> bool:
    result = subprocess.run(
        ["curl", "-sSL", "--max-time", "30", "-A", USER_AGENT, "-H", "Accept: image/png", "-o", destination, url],
        capture_output=True,
        text=True,
    )
    ok = result.returncode == 0 and os.path.exists(destination) and os.path.getsize(destination) > 100
    if not ok and os.path.exists(destination):
        os.remove(destination)
    return ok


def knock_out_white(path: str) -> None:
    """The wiki wordmark is on a white plate. Drop near-white pixels so it sits on the dark bar."""
    from PIL import Image

    image = Image.open(path).convert("RGBA")
    pixels = [
        (red, green, blue, 0 if min(red, green, blue) >= 236 else alpha)
        for red, green, blue, alpha in image.getdata()
    ]
    image.putdata(pixels)
    image.thumbnail((720, 280), Image.Resampling.LANCZOS)
    image.save(path, "PNG", optimize=True)


def fetch_marks(force: bool) -> list[str]:
    missing: list[str] = []
    element_dir = os.path.join(ICONS, "elements")
    os.makedirs(element_dir, exist_ok=True)
    for name, url in ELEMENT_ICON_URLS.items():
        destination = os.path.join(element_dir, f"{name}.png")
        if os.path.exists(destination) and not force:
            continue
        if not download_url(url, destination):
            missing.append(name)
    logo_dir = os.path.join(ICONS, "brand")
    os.makedirs(logo_dir, exist_ok=True)
    logo = os.path.join(logo_dir, "genshin-logo.png")
    if force or not os.path.exists(logo):
        if download_url(LOGO_URL, logo):
            knock_out_white(logo)
        else:
            missing.append("logo")
    print(f"marks: elements {len(ELEMENT_ICON_URLS) - sum(1 for n in ELEMENT_ICON_URLS if n in missing)}, logo {'ok' if 'logo' not in missing else 'missing'}")
    return missing


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

    s_fetched, s_skipped, s_missing = fetch_artifact_sets(args.force)
    print(f"artifact sets: fetched {s_fetched}, already had {s_skipped}, missing {len(s_missing)}")
    if s_missing:
        print(f"  missing: {', '.join(s_missing)}")

    m_fetched, m_skipped, m_missing = fetch_monsters(args.force)
    print(f"monsters: fetched {m_fetched}, already had {m_skipped}, missing {len(m_missing)}")
    if m_missing:
        print(f"  missing: {', '.join(m_missing)}")

    marks_missing = fetch_marks(args.force)
    if marks_missing:
        print(f"  missing marks: {', '.join(marks_missing)}")

    return 1 if (c_missing or w_missing or s_missing or m_missing or marks_missing) else 0


if __name__ == "__main__":
    raise SystemExit(main())
