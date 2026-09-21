import { useMemo, useRef, useState } from "react";
import { Link } from "react-router-dom";
import {
  artifactSetsByID,
  characters,
  charactersByID,
  currentCycle,
  ELEMENTS,
  weapons,
  weaponsByID,
  type Character,
  type ElementName,
  type Weapon,
  type WeaponType,
  WEAPON_TYPES,
} from "../../lib/abyss";
import { formatDateRange, formatHP } from "../../lib/format";
import { fetchEnkaShowcase } from "../../lib/enka";
import { fetchHoyolabRoster } from "../../lib/hoyolab";
import { t, type Lang } from "../../lib/i18n";
import {
  exportRoster,
  loadRoster,
  mergeImported,
  parseRoster,
  saveRoster,
  setConstellation,
  setRefinement,
  toggleCharacter,
  toggleWeapon,
  type Roster,
} from "../../lib/roster";
import { clearSeconds, findTeams, type PlannedPlan, type PlannerOutput } from "../../lib/planner";
import { foldVi } from "../../lib/slug";
import { CatalogTile, Chip, ElementBadge, Portrait, Stars } from "../../components/ui";

function clock(seconds: number): string {
  const total = Math.max(0, Math.round(seconds));
  return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, "0")}`;
}

export function PlannerPage({ lang }: { lang: Lang }) {
  const copy = t(lang);
  const [roster, setRoster] = useState<Roster>(loadRoster);
  const [section, setSection] = useState<"roster" | "results">("roster");
  const [tab, setTab] = useState<"characters" | "weapons">("characters");
  const [query, setQuery] = useState("");
  const [element, setElement] = useState<ElementName | "all">("all");
  const [weaponType, setWeaponType] = useState<WeaponType | "all">("all");
  const [ownedOnly, setOwnedOnly] = useState(false);
  const [sort, setSort] = useState<"name" | "rarity" | "owned">("rarity");
  const [fullCharacters, setFullCharacters] = useState(false);
  const [fullWeapons, setFullWeapons] = useState(false);
  const [uid, setUid] = useState("");
  const [ltuid, setLtuid] = useState("");
  const [ltoken, setLtoken] = useState("");
  const [status, setStatus] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [output, setOutput] = useState<PlannerOutput | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);
  const cycle = currentCycle();
  const blessing = cycle.blessingOfTheAbyssalMoon;
  const needle = foldVi(query);
  const ownedChars = new Set(roster.characters.map((item) => item.id));
  const ownedWeapons = new Set(roster.weapons.map((item) => item.id));

  const update = (next: Roster) => {
    setRoster(next);
    saveRoster(next);
  };

  const visibleCharacters = useMemo(() => {
    return characters
      .filter((character) => {
        if (element !== "all" && character.element !== element) return false;
        if (ownedOnly && !ownedChars.has(character.id)) return false;
        if (needle && !foldVi(`${character.name} ${character.nameVI ?? ""}`).includes(needle)) return false;
        return true;
      })
      .sort((a, b) => compareRoster(a, b, ownedChars.has(a.id), ownedChars.has(b.id), sort));
  }, [element, ownedOnly, needle, sort, ownedChars]);

  const visibleWeapons = useMemo(() => {
    return weapons
      .filter((weapon) => {
        if (weaponType !== "all" && weapon.type !== weaponType) return false;
        if (ownedOnly && !ownedWeapons.has(weapon.id)) return false;
        if (needle && !foldVi(`${weapon.name} ${weapon.nameVI ?? ""}`).includes(needle)) return false;
        return true;
      })
      .sort((a, b) => compareRoster(a, b, ownedWeapons.has(a.id), ownedWeapons.has(b.id), sort));
  }, [weaponType, ownedOnly, needle, sort, ownedWeapons]);

  const search = () => {
    setBusy(true);
    setStatus(null);
    window.setTimeout(() => {
      const result = findTeams(roster, { fullCharacters, fullWeapons });
      setOutput(result);
      setSection("results");
      setBusy(false);
      if (result.plans.length === 0) {
        setStatus(copy.abyssNoResultsHint);
      }
    }, 30);
  };

  const importUID = async () => {
    setBusy(true);
    setStatus(null);
    try {
      const imported = await fetchEnkaShowcase(uid);
      update(mergeImported(roster, imported));
      setStatus(
        `${imported.nickname || uid} — ${imported.characters.length} ${copy.abyssCharacters.toLowerCase()}`,
      );
    } catch (error) {
      setStatus(error instanceof Error ? error.message : String(error));
    } finally {
      setBusy(false);
    }
  };

  const importHoyolab = async () => {
    setBusy(true);
    setStatus(null);
    try {
      const imported = await fetchHoyolabRoster(uid, ltuid, ltoken);
      update(mergeImported(roster, imported));
      setStatus(`${imported.characters.length} ${copy.abyssCharacters.toLowerCase()}`);
    } catch (error) {
      setStatus(error instanceof Error ? error.message : String(error));
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="split">
      <aside className="sidebar">
        <div className="group-label">{copy.abyssBlessing}</div>
        <p className="prose" style={{ margin: 0 }}>
          <strong>{lang === "vi" ? blessing.nameVI ?? blessing.name : blessing.name}</strong>
        </p>
        <p className="meta">{formatDateRange(cycle.periodStart, cycle.periodEnd, lang)}</p>
        <p className="notice">{blessing.description}</p>

        <div className="group-label">{copy.abyssImportUID}</div>
        <input className="search" value={uid} onChange={(e) => setUid(e.target.value)} placeholder={copy.abyssUIDPlaceholder} />
        <button type="button" className="btn btn-quiet" disabled={busy} onClick={() => void importUID()}>
          {copy.abyssImport}
        </button>
        <p className="notice">{copy.abyssUIDHint}</p>

        <div className="group-label">{copy.abyssImportFull}</div>
        <input className="search" value={ltuid} onChange={(e) => setLtuid(e.target.value)} placeholder="ltuid_v2" />
        <input className="search" value={ltoken} onChange={(e) => setLtoken(e.target.value)} placeholder="ltoken_v2" />
        <button type="button" className="btn btn-quiet" disabled={busy} onClick={() => void importHoyolab()}>
          {copy.abyssImport}
        </button>
        <p className="notice">{copy.abyssHoyolabHint}</p>
        {status && <p className="meta">{status}</p>}
        <p className="notice">{copy.abyssMethodology}</p>

        <label className="meta" style={{ display: "flex", gap: 8, alignItems: "center" }}>
          <input type="checkbox" checked={fullCharacters} onChange={(e) => setFullCharacters(e.target.checked)} />
          {copy.abyssFullChars}
        </label>
        <label className="meta" style={{ display: "flex", gap: 8, alignItems: "center" }}>
          <input type="checkbox" checked={fullWeapons} onChange={(e) => setFullWeapons(e.target.checked)} />
          {copy.abyssFullWeapons}
        </label>
        <button type="button" className="btn btn-primary" disabled={busy} onClick={search}>
          {busy ? copy.abyssSearching : copy.abyssFindTeams}
        </button>
      </aside>

      <div className="detail" style={{ maxWidth: "none" }}>
        <div className="abyss-nav tabs">
          <button type="button" className={`tab ${section === "roster" ? "active" : ""}`} onClick={() => setSection("roster")}>
            {copy.abyssRoster}
          </button>
          <button type="button" className={`tab ${section === "results" ? "active" : ""}`} onClick={() => setSection("results")}>
            {copy.abyssResults}
          </button>
        </div>

        {section === "roster" ? (
          <>
            <div className="abyss-nav tabs">
              <button type="button" className={`tab ${tab === "characters" ? "active" : ""}`} onClick={() => setTab("characters")}>
                {copy.abyssCharacters}
              </button>
              <button type="button" className={`tab ${tab === "weapons" ? "active" : ""}`} onClick={() => setTab("weapons")}>
                {copy.abyssWeapons}
              </button>
              <span className="meta" style={{ marginLeft: "auto", alignSelf: "center" }}>
                {tab === "characters"
                  ? `${roster.characters.length} ${copy.abyssCharacters.toLowerCase()}`
                  : `${roster.weapons.length} ${copy.abyssWeapons.toLowerCase()}`}
              </span>
            </div>
            <div className="filters">
              <input className="search" value={query} onChange={(e) => setQuery(e.target.value)} placeholder={tab === "characters" ? copy.abyssSearchCharacters : copy.abyssSearchWeapons} />
            </div>
            <div className="filters">
              {tab === "characters"
                ? ELEMENTS.map((item) => (
                    <Chip key={item} active={element === item} onClick={() => setElement(element === item ? "all" : item)}>
                      {item}
                    </Chip>
                  ))
                : WEAPON_TYPES.map((item) => (
                    <Chip key={item} active={weaponType === item} onClick={() => setWeaponType(weaponType === item ? "all" : item)}>
                      {item}
                    </Chip>
                  ))}
              <Chip active={ownedOnly} onClick={() => setOwnedOnly(!ownedOnly)}>
                {copy.abyssOwnedOnly}
              </Chip>
              <Chip active={sort === "rarity"} onClick={() => setSort("rarity")}>
                {copy.abyssSortRarity}
              </Chip>
              <Chip active={sort === "name"} onClick={() => setSort("name")}>
                {copy.abyssSortName}
              </Chip>
              <Chip active={sort === "owned"} onClick={() => setSort("owned")}>
                {copy.abyssSortOwned}
              </Chip>
            </div>
            <p className="notice">{copy.abyssConstellationNote}</p>
            <div className="filters">
              <button type="button" className="btn btn-quiet" onClick={() => fileRef.current?.click()}>
                {copy.abyssImport}
              </button>
              <button
                type="button"
                className="btn btn-quiet"
                onClick={() => {
                  const blob = new Blob([exportRoster(roster)], { type: "application/json" });
                  const url = URL.createObjectURL(blob);
                  const a = document.createElement("a");
                  a.href = url;
                  a.download = "abyss-roster.json";
                  a.click();
                  URL.revokeObjectURL(url);
                }}
              >
                {copy.abyssExport}
              </button>
              <button
                type="button"
                className="btn btn-quiet"
                onClick={() =>
                  update(tab === "characters" ? { ...roster, characters: [] } : { ...roster, weapons: [] })
                }
              >
                {tab === "characters" ? copy.abyssClearCharacters : copy.abyssClearWeapons}
              </button>
              <input
                ref={fileRef}
                type="file"
                accept="application/json"
                hidden
                onChange={(event) => {
                  const file = event.target.files?.[0];
                  if (!file) return;
                  void file.text().then((text) => {
                    try {
                      update(parseRoster(JSON.parse(text)));
                    } catch {
                      setStatus("File roster không đọc được.");
                    }
                  });
                  event.target.value = "";
                }}
              />
            </div>
            {roster.characters.length === 0 && roster.weapons.length === 0 && (
              <p className="empty">{copy.abyssEmptyRoster}</p>
            )}
            <div className="catalog">
              {tab === "characters"
                ? visibleCharacters.map((character) => {
                    const owned = roster.characters.find((item) => item.id === character.id);
                    return (
                      <div key={character.id}>
                        <CatalogTile
                          kind="characters"
                          id={character.id}
                          title={lang === "vi" ? character.nameVI ?? character.name : character.name}
                          accent={character.element}
                          selected={Boolean(owned)}
                          onClick={() => update(toggleCharacter(roster, character.id))}
                          subtitle={
                            <>
                              <Stars n={character.rarity} /> {character.element}
                            </>
                          }
                        />
                        {owned && (
                          <div className="meta" style={{ padding: "4px 8px" }}>
                            C{owned.constellation}{" "}
                            <button type="button" className="chip" onClick={() => update(setConstellation(roster, character.id, owned.constellation - 1))}>
                              −
                            </button>
                            <button type="button" className="chip" onClick={() => update(setConstellation(roster, character.id, owned.constellation + 1))}>
                              +
                            </button>
                          </div>
                        )}
                      </div>
                    );
                  })
                : visibleWeapons.map((weapon) => {
                    const owned = roster.weapons.find((item) => item.id === weapon.id);
                    return (
                      <div key={weapon.id}>
                        <CatalogTile
                          kind="weapons"
                          id={weapon.id}
                          title={lang === "vi" ? weapon.nameVI ?? weapon.name : weapon.name}
                          selected={Boolean(owned)}
                          onClick={() => update(toggleWeapon(roster, weapon.id))}
                          subtitle={
                            <>
                              <Stars n={weapon.rarity} /> {weapon.type}
                            </>
                          }
                        />
                        {owned && (
                          <div className="meta" style={{ padding: "4px 8px" }}>
                            R{owned.refinement}{" "}
                            <button type="button" className="chip" onClick={() => update(setRefinement(roster, weapon.id, owned.refinement - 1))}>
                              −
                            </button>
                            <button type="button" className="chip" onClick={() => update(setRefinement(roster, weapon.id, owned.refinement + 1))}>
                              +
                            </button>
                          </div>
                        )}
                      </div>
                    );
                  })}
            </div>
          </>
        ) : (
          <Results lang={lang} output={output} />
        )}
      </div>
    </div>
  );
}

function compareRoster(
  a: Character | Weapon,
  b: Character | Weapon,
  aOwned: boolean,
  bOwned: boolean,
  sort: "name" | "rarity" | "owned",
): number {
  if (sort === "owned" && aOwned !== bOwned) return aOwned ? -1 : 1;
  if (sort === "rarity" && a.rarity !== b.rarity) return b.rarity - a.rarity;
  return a.name.localeCompare(b.name, "en");
}

function Results({ lang, output }: { lang: Lang; output: PlannerOutput | null }) {
  const copy = t(lang);
  if (!output) return <p className="empty">{copy.abyssNoResultsHint}</p>;
  if (output.plans.length === 0) return <p className="empty">{copy.abyssEmpty}</p>;
  return (
    <>
      <p className="notice">{copy.abyssHalfPlanNotice}</p>
      {output.recommendation && (
        <aside className="callout turning">
          <span className="callout-bar" />
          <div className="callout-body">{output.recommendation}</div>
        </aside>
      )}
      {output.plans.map((plan, index) => (
        <PlanCard key={index} rank={index + 1} plan={plan} lang={lang} half1={output.half1Text} half2={output.half2Text} />
      ))}
    </>
  );
}

function PlanCard({
  rank,
  plan,
  lang,
  half1,
  half2,
}: {
  rank: number;
  plan: PlannedPlan;
  lang: Lang;
  half1?: string;
  half2?: string;
}) {
  const copy = t(lang);
  const totalHP =
    plan.firstHalfHP != null && plan.secondHalfHP != null ? plan.firstHalfHP + plan.secondHalfHP : null;
  const time = clearSeconds(totalHP, plan.score);
  return (
    <section className="panel" style={{ marginBottom: 16 }}>
      <div className="floor-head">
        <strong>#{rank}</strong>
        <span className="meta">
          {time != null ? `${copy.abyssClearApprox} ${clock(time)}` : ""} · {Math.round(plan.score)}/s
        </span>
      </div>
      <div className="team-halves">
        <HalfTeam title={copy.abyssHalf1} hint={half1} team={plan.half1} hp={plan.firstHalfHP} lang={lang} />
        <HalfTeam title={copy.abyssHalf2} hint={half2} team={plan.half2} hp={plan.secondHalfHP} lang={lang} />
      </div>
    </section>
  );
}

function HalfTeam({
  title,
  hint,
  team,
  hp,
  lang,
}: {
  title: string;
  hint?: string;
  team: PlannedPlan["half1"];
  hp: number | null;
  lang: Lang;
}) {
  const copy = t(lang);
  const time = clearSeconds(hp, team.score);
  return (
    <div>
      <h3>{title}</h3>
      {hint && <p className="meta">{hint}</p>}
      <p className="meta">
        {time != null ? `${copy.abyssClearApprox} ${clock(time)}` : ""}
        {hp != null ? ` · HP ${formatHP(hp)}` : ""} · {Math.round(team.score)}/s
      </p>
      <div className="catalog">
        {team.members.map((member) => {
          const character = charactersByID[member.characterId];
          const weapon = member.weaponId ? weaponsByID[member.weaponId] : undefined;
          const set = member.artifactSetId ? artifactSetsByID[member.artifactSetId] : undefined;
          if (!character) return null;
          return (
            <Link key={member.characterId} to={`/abyss/characters/${character.id}`} className="tile">
              <Portrait kind="characters" id={character.id} alt={character.name} />
              <span className="tile-copy">
                <strong>{lang === "vi" ? character.nameVI ?? character.name : character.name}</strong>
                <span className="meta">
                  <ElementBadge element={character.element} /> {member.role}
                  {weapon ? ` · ${lang === "vi" ? weapon.nameVI ?? weapon.name : weapon.name}` : ""}
                  {set ? ` · ${lang === "vi" ? set.nameVI ?? set.name : set.name}` : ""}
                </span>
              </span>
            </Link>
          );
        })}
      </div>
      {team.notes.length > 0 && <p className="meta">{team.notes.join(" · ")}</p>}
    </div>
  );
}
