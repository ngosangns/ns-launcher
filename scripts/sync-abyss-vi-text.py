#!/usr/bin/env python3
"""Replaces Vietnamese game text in the Abyss catalogs with the official
localisation from gi.yatta.moe/api/v2/vi.

Character and weapon prose in these files was paraphrased. The game already
ships Vietnamese names, talent text, constellation text, and weapon passives,
so those fields are copied from Yatta and nothing is translated here. Numbers
the combat model reads (hit tables, passive effect values, kits) are left
alone. Traveler variants have no Yatta avatar entry, so their text is not
rewritten.

    python3 scripts/sync-abyss-vi-text.py

Network access required.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
from concurrent.futures import ThreadPoolExecutor

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(REPO, "Sources", "NSLauncherApp", "Resources", "Abyss")
YATTA = "https://gi.yatta.moe/api/v2/vi"
COLOR = re.compile(r"</?color(?:=[^>]*)?>", re.IGNORECASE)


def fetch(url: str) -> dict | None:
    result = subprocess.run(
        ["curl", "-sS", "--max-time", "40", "-A", "ns-launcher/vi-text (github.com/ngosangns/ns-launcher)", url],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0 or not result.stdout.strip():
        return None
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError:
        return None
    data = payload.get("data") if isinstance(payload, dict) else None
    return data if isinstance(data, dict) else None


def clean(text: str) -> str:
    return COLOR.sub("", text.replace("\\n", "\n")).strip()


def ordered(data: dict) -> list[dict]:
    return [data[key] for key in sorted(data, key=lambda item: int(item))]


def apply_talent(target: dict, source: dict | None) -> None:
    if not source:
        return
    name = clean(source.get("name") or "")
    description = clean(source.get("description") or "")
    if name:
        target["name"] = name
    if description:
        target["description"] = description


def apply_character(record: dict, data: dict) -> None:
    name = clean(data.get("name") or "")
    if name:
        record["nameVI"] = name
    talents = ordered(data.get("talent") or {})
    normals = [item for item in talents if item.get("type") == 0]
    bursts = [item for item in talents if item.get("type") == 1]
    passives = [item for item in talents if item.get("type") == 2]
    if normals:
        apply_talent(record["normalAttack"], normals[0])
    if len(normals) > 1:
        apply_talent(record["elementalSkill"], normals[1])
    elif bursts and "elementalSkill" in record:
        pass
    if bursts:
        apply_talent(record["elementalBurst"], bursts[0])
    existing = record.get("passives") or []
    for index, source in enumerate(passives):
        if index < len(existing):
            existing[index]["name"] = clean(source.get("name") or existing[index].get("name") or "")
            description = clean(source.get("description") or "")
            if description:
                existing[index]["description"] = description
        else:
            existing.append(
                {
                    "name": clean(source.get("name") or ""),
                    "unlock": "Passive",
                    "description": clean(source.get("description") or ""),
                }
            )
    record["passives"] = existing
    constellations = ordered(data.get("constellation") or {})
    existing_cons = record.get("constellations") or []
    for index, source in enumerate(constellations):
        description = clean(source.get("description") or "")
        name = clean(source.get("name") or "")
        if index < len(existing_cons):
            if name:
                existing_cons[index]["name"] = name
            if description:
                existing_cons[index]["description"] = description
        else:
            existing_cons.append({"level": index + 1, "name": name, "description": description})
    record["constellations"] = existing_cons


def apply_weapon(record: dict, data: dict) -> None:
    name = clean(data.get("name") or "")
    if name:
        record["nameVI"] = name
    affixes = list((data.get("affix") or {}).values())
    if not affixes:
        return
    affix = affixes[0]
    passive = record.setdefault("passive", {"name": None, "description": "", "effects": []})
    affix_name = clean(affix.get("name") or "")
    if affix_name:
        passive["name"] = affix_name
    upgrade = affix.get("upgrade") or {}
    text = upgrade.get("0") if isinstance(upgrade, dict) else None
    if isinstance(text, str) and text.strip():
        passive["description"] = clean(text)


def write_json(path: str, payload) -> None:
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, ensure_ascii=False, indent=2)
        handle.write("\n")


def sync_characters(id_to_slug: dict[str, str]) -> tuple[int, list[str]]:
    slug_to_id = {slug: game_id for game_id, slug in id_to_slug.items() if not slug.startswith("traveler-")}
    files = [
        os.path.join(DATA, "characters", name)
        for name in os.listdir(os.path.join(DATA, "characters"))
        if name.endswith(".json")
    ]
    updated = 0
    missing: list[str] = []

    def load(slug: str, game_id: str) -> tuple[str, dict | None]:
        return slug, fetch(f"{YATTA}/avatar/{game_id}")

    with ThreadPoolExecutor(max_workers=6) as pool:
        fetched = dict(pool.map(lambda item: load(*item), slug_to_id.items()))

    for path in files:
        with open(path, encoding="utf-8") as handle:
            records = json.load(handle)
        for record in records:
            game_id = slug_to_id.get(record["id"])
            if not game_id:
                continue
            data = fetched.get(record["id"])
            if not data:
                missing.append(record["id"])
                continue
            apply_character(record, data)
            updated += 1
        write_json(path, records)
    return updated, missing


def sync_weapons(id_to_slug: dict[str, str]) -> tuple[int, list[str]]:
    slug_to_id = {slug: game_id for game_id, slug in id_to_slug.items()}
    files = [
        os.path.join(DATA, "weapons", name)
        for name in os.listdir(os.path.join(DATA, "weapons"))
        if name.endswith(".json")
    ]
    records_by_file: dict[str, list] = {}
    wanted: list[tuple[str, str]] = []
    for path in files:
        with open(path, encoding="utf-8") as handle:
            records_by_file[path] = json.load(handle)
        for record in records_by_file[path]:
            game_id = slug_to_id.get(record["id"])
            if game_id:
                wanted.append((record["id"], game_id))

    def load(item: tuple[str, str]) -> tuple[str, dict | None]:
        return item[0], fetch(f"{YATTA}/weapon/{item[1]}")

    with ThreadPoolExecutor(max_workers=6) as pool:
        fetched = dict(pool.map(load, wanted))

    updated = 0
    missing: list[str] = []
    for path, records in records_by_file.items():
        for record in records:
            if record["id"] not in slug_to_id:
                continue
            data = fetched.get(record["id"])
            if not data:
                missing.append(record["id"])
                continue
            apply_weapon(record, data)
            updated += 1
        write_json(path, records)
    return updated, missing


def sync_monsters() -> tuple[int, list[str]]:
    folder = os.path.join(DATA, "abyss-monsters")
    files = [os.path.join(folder, name) for name in os.listdir(folder) if name.endswith(".json")]
    payloads = []
    ids: set[str] = set()
    for path in files:
        with open(path, encoding="utf-8") as handle:
            payload = json.load(handle)
        payloads.append((path, payload))
        for floor in payload.get("floors") or []:
            for chamber in floor.get("chambers") or []:
                for wave in chamber.get("waves") or []:
                    for monster in wave.get("monsters") or []:
                        if monster.get("gameId") is not None:
                            ids.add(str(monster["gameId"]))

    def load(game_id: str) -> tuple[str, str | None]:
        data = fetch(f"{YATTA}/monster/{game_id}")
        name = clean(data.get("name") or "") if data else ""
        return game_id, name or None

    with ThreadPoolExecutor(max_workers=6) as pool:
        names = dict(pool.map(load, ids))

    updated = 0
    missing = [game_id for game_id, name in names.items() if not name]
    for path, payload in payloads:
        for floor in payload.get("floors") or []:
            for chamber in floor.get("chambers") or []:
                for wave in chamber.get("waves") or []:
                    for monster in wave.get("monsters") or []:
                        game_id = monster.get("gameId")
                        if game_id is None:
                            continue
                        name = names.get(str(game_id))
                        if not name:
                            continue
                        monster["nameVI"] = name
                        updated += 1
        write_json(path, payload)
    return updated, missing


def main() -> int:
    with open(os.path.join(DATA, "game-ids.json"), encoding="utf-8") as handle:
        game_ids = json.load(handle)
    characters, missing_characters = sync_characters(game_ids["characters"])
    weapons, missing_weapons = sync_weapons(game_ids["weapons"])
    monsters, missing_monsters = sync_monsters()
    print(f"characters: {characters} updated, {len(missing_characters)} missing")
    if missing_characters:
        print("  " + ", ".join(missing_characters))
    print(f"weapons: {weapons} updated, {len(missing_weapons)} missing")
    if missing_weapons:
        print("  " + ", ".join(missing_weapons))
    print(f"monster names: {monsters} set, {len(missing_monsters)} ids without a Vietnamese name")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
