import { createMemo, createSignal, For, Show } from "solid-js";
import {
  artifactSetsByID,
  characters,
  charactersByID,
  currentCycle,
  ELEMENTS,
  floor12 as floor12Of,
  weapons,
  weaponsByID,
  type Character,
  type ElementName,
  type Weapon,
  type WeaponType,
  WEAPON_TYPES,
  weaponTypeName,
} from "../../lib/abyss";
import { formatDateRange, formatHP } from "../../lib/format";
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
import { clearSeconds, findTeams, type PlannedPlan, type PlannedTeam, type PlannerOutput } from "../../lib/planner";
import { foldVi } from "../../lib/slug";
import { navigate } from "../../router";
import { KeepAlive } from "../../components/KeepAlive";
import { Segmented } from "../../components/Segmented";
import { Chip, ElementBadge, Portrait } from "../../components/ui";
import {
  CharacterPreviewBody,
  WeaponPreviewBody,
  createCatalogPreview,
} from "./CatalogPages";
import { FloorMonsters } from "./MonsterList";

function clock(seconds: number): string {
  const total = Math.max(0, Math.round(seconds));
  return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, "0")}`;
}

const REACTION_LABELS: Record<string, { vi: string; en: string }> = {
  vaporize: { vi: "Bốc Hơi", en: "Vaporize" },
  melt: { vi: "Tan Chảy", en: "Melt" },
  swirl: { vi: "Khuếch Tán", en: "Swirl" },
  "stellar-swirl": { vi: "Tinh-Khuếch Tán", en: "Stellar Swirl" },
  "electro-charged": { vi: "Điện Cảm", en: "Electro-Charged" },
  "lunar-charged": { vi: "Nguyệt-Điện Cảm", en: "Lunar-Charged" },
  overload: { vi: "Quá Tải", en: "Overloaded" },
  superconduct: { vi: "Siêu Dẫn", en: "Superconduct" },
  bloom: { vi: "Sum Suê", en: "Bloom" },
  hyperbloom: { vi: "Nở Rộ", en: "Hyperbloom" },
  burgeon: { vi: "Bung Tỏa", en: "Burgeon" },
  burning: { vi: "Thiêu Đốt", en: "Burning" },
  aggravate: { vi: "Tăng Cường", en: "Aggravate" },
  spread: { vi: "Lan Tràn", en: "Spread" },
};

function reactionLabel(id: string, lang: Lang): string {
  return REACTION_LABELS[id]?.[lang] ?? id;
}

function formatRotation(team: PlannedTeam, lang: Lang, onField: string): string {
  const nameOf = (id: string) => {
    const character = charactersByID[id];
    return lang === "vi" ? character?.nameVI ?? character?.name ?? id : character?.name ?? id;
  };
  const casts = team.rotation.map((step) => `${nameOf(step.characterId)} ${step.casts.join(" ")}`);
  return [...casts, `${nameOf(team.onFieldId)} ${onField}`].join(" · ");
}

export function PlannerPage(props: { lang: Lang; section: string }) {
  const text = () => t(props.lang);
  const [roster, setRoster] = createSignal<Roster>(loadRoster());
  const charactersView = () => props.section === "characters";
  const [query, setQuery] = createSignal("");
  const [element, setElement] = createSignal<ElementName | "all">("all");
  const [weaponType, setWeaponType] = createSignal<WeaponType | "all">("all");
  const [ownedOnly, setOwnedOnly] = createSignal(false);
  const [sort, setSort] = createSignal<"name" | "rarity" | "owned">("rarity");
  const [fullCharacters, setFullCharacters] = createSignal(false);
  const [fullWeapons, setFullWeapons] = createSignal(false);
  const [ltuid, setLtuid] = createSignal("");
  const [ltoken, setLtoken] = createSignal("");
  const [status, setStatus] = createSignal<string | null>(null);
  const [busy, setBusy] = createSignal(false);
  const [output, setOutput] = createSignal<PlannerOutput | null>(null);
  let fileRef: HTMLInputElement | undefined;
  const cycle = currentCycle();
  const blessing = cycle.blessingOfTheAbyssalMoon;
  const floor12 = floor12Of(cycle);

  const update = (next: Roster) => {
    setRoster(next);
    saveRoster(next);
  };

  const visibleCharacters = createMemo(() => {
    const owned = new Set(roster().characters.map((item) => item.id));
    const needle = foldVi(query());
    return characters
      .filter((character) => {
        if (element() !== "all" && character.element !== element()) return false;
        if (ownedOnly() && !owned.has(character.id)) return false;
        if (needle && !foldVi(`${character.name} ${character.nameVI ?? ""}`).includes(needle)) return false;
        return true;
      })
      .sort((a, b) => compareRoster(a, b, owned.has(a.id), owned.has(b.id), sort()));
  });

  const visibleWeapons = createMemo(() => {
    const owned = new Set(roster().weapons.map((item) => item.id));
    const needle = foldVi(query());
    return weapons
      .filter((weapon) => {
        if (weaponType() !== "all" && weapon.type !== weaponType()) return false;
        if (ownedOnly() && !owned.has(weapon.id)) return false;
        if (needle && !foldVi(`${weapon.name} ${weapon.nameVI ?? ""}`).includes(needle)) return false;
        return true;
      })
      .sort((a, b) => compareRoster(a, b, owned.has(a.id), owned.has(b.id), sort()));
  });

  const characterPreview = createCatalogPreview(() => visibleCharacters().map((character) => character.id));
  const weaponPreview = createCatalogPreview(() => visibleWeapons().map((weapon) => weapon.id));

  const search = () => {
    const hint = text().abyssNoResultsHint;
    const current = roster();
    const fullC = fullCharacters();
    const fullW = fullWeapons();
    setBusy(true);
    setStatus(null);
    window.setTimeout(() => {
      const result = findTeams(current, { fullCharacters: fullC, fullWeapons: fullW });
      setOutput(result);
      setBusy(false);
      if (result.plans.length === 0) setStatus(hint);
      navigate("/abyss/team");
    }, 30);
  };

  const importHoyolab = async () => {
    const label = text();
    const current = roster();
    setBusy(true);
    setStatus(null);
    try {
      const imported = await fetchHoyolabRoster("", ltuid(), ltoken());
      update(mergeImported(current, imported));
      const others = imported.otherUids.length > 0 ? ` · UID khác: ${imported.otherUids.join(", ")}` : "";
      setStatus(
        `${imported.nickname || imported.uid} (${imported.uid}) — ${imported.characters.length} ${label.abyssCharacters.toLowerCase()}${others}`,
      );
    } catch (error) {
      setStatus(error instanceof Error ? error.message : String(error));
    } finally {
      setBusy(false);
    }
  };

  const exportFile = () => {
    const blob = new Blob([exportRoster(roster())], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement("a");
    anchor.href = url;
    anchor.download = "abyss-roster.json";
    anchor.click();
    URL.revokeObjectURL(url);
  };

  return (
    <div class="split">
      <aside class="sidebar">
        <div class="group-label">{text().abyssBlessing}</div>
        <p class="prose" style={{ margin: "0" }}>
          <strong>{props.lang === "vi" ? blessing.nameVI ?? blessing.name : blessing.name}</strong>
        </p>
        <p class="meta">{formatDateRange(cycle.periodStart, cycle.periodEnd, props.lang)}</p>
        <p class="notice">{blessing.description}</p>

        <div class="group-label">{text().abyssImportFull}</div>
        <input class="search" value={ltuid()} onInput={(event) => setLtuid(event.currentTarget.value)} placeholder="ltuid_v2" />
        <input class="search" value={ltoken()} onInput={(event) => setLtoken(event.currentTarget.value)} placeholder="ltoken_v2" />
        <button type="button" class="btn btn-quiet" classList={{ "is-busy": busy() }} disabled={busy()} onClick={() => void importHoyolab()}>
          {text().abyssImport}
        </button>
        <p class="notice">{text().abyssHoyolabHint}</p>
        <Show when={status()} keyed>
          {(message) => <p class="meta rise-once">{message}</p>}
        </Show>
        <p class="notice">{text().abyssMethodology}</p>

        <label class="meta" style={{ display: "flex", gap: "8px", "align-items": "center" }}>
          <input type="checkbox" checked={fullCharacters()} onChange={(event) => setFullCharacters(event.currentTarget.checked)} />
          {text().abyssFullChars}
        </label>
        <label class="meta" style={{ display: "flex", gap: "8px", "align-items": "center" }}>
          <input type="checkbox" checked={fullWeapons()} onChange={(event) => setFullWeapons(event.currentTarget.checked)} />
          {text().abyssFullWeapons}
        </label>
        <button type="button" class="btn btn-primary" classList={{ "is-busy": busy() }} disabled={busy()} onClick={search}>
          {busy() ? text().abyssSearching : text().abyssFindTeams}
        </button>
      </aside>

      <div class="detail" style={{ "max-width": "none" }}>
        <KeepAlive active={props.section === "characters" || props.section === "weapons"}>
          <p class="meta" style={{ "margin-top": "0" }}>
            {charactersView()
              ? `${roster().characters.length} ${text().abyssCharacters.toLowerCase()}`
              : `${roster().weapons.length} ${text().abyssWeapons.toLowerCase()}`}
          </p>
          <div class="filters">
            <input
              class="search"
              value={query()}
              onInput={(event) => setQuery(event.currentTarget.value)}
              placeholder={charactersView() ? text().abyssSearchCharacters : text().abyssSearchWeapons}
            />
          </div>
          <div class="filters facets">
            <Show
              when={charactersView()}
              fallback={
                <For each={WEAPON_TYPES}>
                  {(item) => (
                    <Chip active={weaponType() === item} onClick={() => setWeaponType(weaponType() === item ? "all" : item)}>
                      {weaponTypeName(item, props.lang)}
                    </Chip>
                  )}
                </For>
              }
            >
              <For each={ELEMENTS}>
                {(item) => (
                  <Chip active={element() === item} label={item} onClick={() => setElement(element() === item ? "all" : item)}>
                    <ElementBadge element={item} size={18} />
                  </Chip>
                )}
              </For>
            </Show>
            <div class="spacer" />
            <Chip active={ownedOnly()} onClick={() => setOwnedOnly(!ownedOnly())}>
              {text().abyssOwnedOnly}
            </Chip>
          </div>
          <div class="filters tools">
            <Segmented class="tabs sort-tabs" label={text().abyssSort}>
              <button type="button" class="tab" classList={{ active: sort() === "rarity" }} onClick={() => setSort("rarity")}>
                {text().abyssSortRarity}
              </button>
              <button type="button" class="tab" classList={{ active: sort() === "name" }} onClick={() => setSort("name")}>
                {text().abyssSortName}
              </button>
              <button type="button" class="tab" classList={{ active: sort() === "owned" }} onClick={() => setSort("owned")}>
                {text().abyssSortOwned}
              </button>
            </Segmented>
            <div class="filter-actions">
              <button type="button" class="btn btn-quiet" onClick={() => fileRef?.click()}>
                {text().abyssImport}
              </button>
              <button type="button" class="btn btn-quiet" onClick={exportFile}>
                {text().abyssExport}
              </button>
              <button
                type="button"
                class="btn btn-quiet"
                onClick={() =>
                  update(charactersView() ? { ...roster(), characters: [] } : { ...roster(), weapons: [] })
                }
              >
                {charactersView() ? text().abyssClearCharacters : text().abyssClearWeapons}
              </button>
              <input
                ref={fileRef}
                type="file"
                accept="application/json"
                hidden
                onChange={(event) => {
                  const file = event.currentTarget.files?.[0];
                  if (!file) return;
                  void file.text().then((body) => {
                    try {
                      update(parseRoster(JSON.parse(body)));
                    } catch {
                      setStatus("File roster không đọc được.");
                    }
                  });
                  event.currentTarget.value = "";
                }}
              />
            </div>
          </div>
          <p class="notice">{text().abyssConstellationNote}</p>

          <KeepAlive active={props.section === "characters"}>
            <div class="catalog" ref={characterPreview.bindRoot}>
              <For each={visibleCharacters()}>
                {(character) => {
                  const owned = () => roster().characters.find((item) => item.id === character.id);
                  const trigger = characterPreview.triggers(character.id);
                  return (
                    <div
                      class="tile roster-tile"
                      classList={{ selected: Boolean(owned()), "is-preview": characterPreview.openId() === character.id }}
                      data-rarity={character.rarity}
                    >
                      <button
                        type="button"
                        class="tile-main"
                        onClick={() => update(toggleCharacter(roster(), character.id))}
                      >
                        <Portrait kind="characters" id={character.id} alt="" />
                        <span class="tile-copy">
                          <strong>{props.lang === "vi" ? character.nameVI ?? character.name : character.name}</strong>
                        </span>
                      </button>
                      <div class="roster-foot">
                        <span class="meta">
                          <ElementBadge element={character.element} size={16} /> ·{" "}
                          {weaponTypeName(character.weaponType, props.lang)}
                        </span>
                        <Show when={owned()}>
                          {(row) => (
                            <LevelStepper
                              label={`C${row().constellation}`}
                              onDecrease={() =>
                                update(setConstellation(roster(), character.id, row().constellation - 1))
                              }
                              onIncrease={() =>
                                update(setConstellation(roster(), character.id, row().constellation + 1))
                              }
                            />
                          )}
                        </Show>
                      </div>
                      <InfoButton label={text().abyssInfo} trigger={trigger} />
                    </div>
                  );
                }}
              </For>
            </div>
            <div
              id="character-preview"
              popover="manual"
              class="catalog-popover"
              ref={characterPreview.bindPopover}
              aria-labelledby="character-preview-title"
              onPointerEnter={characterPreview.hold}
              onPointerLeave={characterPreview.release}
            >
              <Show when={characterPreview.openId()} keyed>
                {(id) => <CharacterPreviewBody lang={props.lang} id={id} />}
              </Show>
            </div>
          </KeepAlive>
          <KeepAlive active={props.section === "weapons"}>
            <div class="catalog" ref={weaponPreview.bindRoot}>
              <For each={visibleWeapons()}>
                {(weapon) => {
                  const owned = () => roster().weapons.find((item) => item.id === weapon.id);
                  const trigger = weaponPreview.triggers(weapon.id);
                  return (
                    <div
                      class="tile roster-tile"
                      classList={{ selected: Boolean(owned()), "is-preview": weaponPreview.openId() === weapon.id }}
                      data-rarity={weapon.rarity}
                    >
                      <button type="button" class="tile-main" onClick={() => update(toggleWeapon(roster(), weapon.id))}>
                        <Portrait kind="weapons" id={weapon.id} alt="" />
                        <span class="tile-copy">
                          <strong>{props.lang === "vi" ? weapon.nameVI ?? weapon.name : weapon.name}</strong>
                        </span>
                      </button>
                      <div class="roster-foot">
                        <span class="meta">{weaponTypeName(weapon.type, props.lang)}</span>
                        <Show when={owned()}>
                          {(row) => (
                            <LevelStepper
                              label={`R${row().refinement}`}
                              onDecrease={() => update(setRefinement(roster(), weapon.id, row().refinement - 1))}
                              onIncrease={() => update(setRefinement(roster(), weapon.id, row().refinement + 1))}
                            />
                          )}
                        </Show>
                      </div>
                      <InfoButton label={text().abyssInfo} trigger={trigger} />
                    </div>
                  );
                }}
              </For>
            </div>
            <div
              id="weapon-roster-preview"
              popover="manual"
              class="catalog-popover"
              ref={weaponPreview.bindPopover}
              aria-labelledby="weapon-preview-title"
              onPointerEnter={weaponPreview.hold}
              onPointerLeave={weaponPreview.release}
            >
              <Show when={weaponPreview.openId()} keyed>
                {(id) => <WeaponPreviewBody lang={props.lang} id={id} />}
              </Show>
            </div>
          </KeepAlive>
        </KeepAlive>
        <KeepAlive active={props.section === "monsters"}>
          <Show when={floor12}>
            <FloorMonsters floor={floor12!} lang={props.lang} defaultOpen />
          </Show>
        </KeepAlive>
        <KeepAlive active={props.section === "team"}>
          <Results lang={props.lang} output={output()} />
        </KeepAlive>
      </div>
    </div>
  );
}

function LevelStepper(props: { label: string; onDecrease: () => void; onIncrease: () => void }) {
  return (
    <div class="stepper">
      <button type="button" class="chip" aria-label="−" onClick={() => props.onDecrease()}>
        −
      </button>
      <span class="stepper-value">{props.label}</span>
      <button type="button" class="chip" aria-label="+" onClick={() => props.onIncrease()}>
        +
      </button>
    </div>
  );
}

function InfoButton(props: {
  label: string;
  trigger: {
    onPointerEnter: (event: PointerEvent) => void;
    onPointerLeave: (event: PointerEvent) => void;
    onFocus: (event: FocusEvent) => void;
    onBlur: (event: FocusEvent) => void;
    onClick: (event: MouseEvent) => void;
  };
}) {
  return (
    <button
      type="button"
      class="tile-info"
      aria-label={props.label}
      onPointerEnter={props.trigger.onPointerEnter}
      onPointerLeave={props.trigger.onPointerLeave}
      onFocus={props.trigger.onFocus}
      onBlur={props.trigger.onBlur}
      onClick={props.trigger.onClick}
    >
      <svg width="16" height="16" viewBox="0 0 24 24" aria-hidden="true">
        <circle cx="12" cy="12" r="9" fill="none" stroke="currentColor" stroke-width="1.8" />
        <path d="M12 11v6" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" />
        <circle cx="12" cy="7.5" r="1.1" fill="currentColor" />
      </svg>
    </button>
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

function Results(props: { lang: Lang; output: PlannerOutput | null }) {
  const text = () => t(props.lang);
  return (
    <Show when={props.output} fallback={<p class="empty">{text().abyssNoResultsHint}</p>}>
      {(output) => (
        <Show when={output().plans.length > 0} fallback={<p class="empty">{text().abyssEmpty}</p>}>
          <p class="notice">{text().abyssHalfPlanNotice}</p>
          <Show when={output().recommendation}>
            <aside class="callout turning">
              <span class="callout-bar" />
              <div class="callout-body">{output().recommendation}</div>
            </aside>
          </Show>
          <For each={output().plans}>
            {(plan, index) => (
              <PlanCard
                rank={index() + 1}
                plan={plan}
                lang={props.lang}
                half1={output().half1Text}
                half2={output().half2Text}
              />
            )}
          </For>
        </Show>
      )}
    </Show>
  );
}

function PlanCard(props: {
  rank: number;
  plan: PlannedPlan;
  lang: Lang;
  half1?: string;
  half2?: string;
}) {
  const text = () => t(props.lang);
  const totalHP = () =>
    props.plan.firstHalfHP != null && props.plan.secondHalfHP != null
      ? props.plan.firstHalfHP + props.plan.secondHalfHP
      : null;
  const time = () => clearSeconds(totalHP(), props.plan.score);
  return (
    <section
      class="panel plan-card"
      style={{ "margin-bottom": "16px", "animation-delay": `${Math.min(props.rank - 1, 8) * 55}ms` }}
    >
      <div class="floor-head">
        <strong>#{props.rank}</strong>
        <span class="meta">
          {time() != null ? `${text().abyssClearApprox} ${clock(time()!)}` : ""} · {Math.round(props.plan.score)}/s
        </span>
      </div>
      <div class="team-halves">
        <HalfTeam title={text().abyssHalf1} hint={props.half1} team={props.plan.half1} hp={props.plan.firstHalfHP} lang={props.lang} />
        <HalfTeam title={text().abyssHalf2} hint={props.half2} team={props.plan.half2} hp={props.plan.secondHalfHP} lang={props.lang} />
      </div>
    </section>
  );
}

function HalfTeam(props: {
  title: string;
  hint?: string;
  team: PlannedPlan["half1"];
  hp: number | null;
  lang: Lang;
}) {
  const text = () => t(props.lang);
  const time = () => clearSeconds(props.hp, props.team.score);
  return (
    <div>
      <h3>{props.title}</h3>
      <Show when={props.hint}>
        <p class="meta">{props.hint}</p>
      </Show>
      <p class="meta">
        {time() != null ? `${text().abyssClearApprox} ${clock(time()!)}` : ""}
        {props.hp != null ? ` · HP ${formatHP(props.hp)}` : ""} · {Math.round(props.team.score)}/s
      </p>
      <Show when={props.team.rotation.length > 0}>
        <p class="meta">{formatRotation(props.team, props.lang, text().abyssOnField)}</p>
      </Show>
      <Show when={props.team.reactions.length > 0}>
        <p class="meta">
          {props.team.reactions
            .slice(0, 4)
            .map((reaction) => `${reactionLabel(reaction.id, props.lang)} ${reaction.count}`)
            .join(" · ")}
          {props.team.shockwaves > 0 ? ` · ${text().abyssShockwave} × ${props.team.shockwaves}` : ""}
        </p>
      </Show>
      <Show when={props.team.fallbackIds.length > 0}>
        <p class="meta">
          {props.team.fallbackIds
            .map((id) => {
              const character = charactersByID[id];
              return props.lang === "vi" ? character?.nameVI ?? character?.name ?? id : character?.name ?? id;
            })
            .join(", ")}
          {` — ${text().abyssFallbackNote}`}
        </p>
      </Show>
      <div class="catalog">
        <For each={props.team.members}>
          {(member) => {
            const character = charactersByID[member.characterId];
            const weapon = member.weaponId ? weaponsByID[member.weaponId] : undefined;
            const set = member.artifactSetId ? artifactSetsByID[member.artifactSetId] : undefined;
            if (!character) return null;
            return (
              <a href={`/abyss/characters/${character.id}`} class="tile" data-rarity={character.rarity}>
                <Portrait kind="characters" id={character.id} alt={character.name} />
                <span class="tile-copy">
                  <strong>{props.lang === "vi" ? character.nameVI ?? character.name : character.name}</strong>
                  <span class="meta">
                    <ElementBadge element={character.element} /> {member.role}
                    {weapon ? ` · ${props.lang === "vi" ? weapon.nameVI ?? weapon.name : weapon.name}` : ""}
                    {set ? ` · ${props.lang === "vi" ? set.nameVI ?? set.name : set.name}` : ""}
                  </span>
                </span>
              </a>
            );
          }}
        </For>
      </div>
      <Show when={props.team.notes.length > 0}>
        <p class="meta">{props.team.notes.join(" · ")}</p>
      </Show>
    </div>
  );
}
