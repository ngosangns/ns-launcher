import { createEffect, createMemo, createSignal, For, onCleanup, onMount, Show } from "solid-js";
import {
  artifactSets,
  artifactSetsByID,
  characters,
  charactersByID,
  ELEMENTS,
  NATIONS,
  nationKey,
  WEAPON_TYPES,
  weapons,
  weaponsByID,
  weaponTypeName,
  type Character,
  type ElementName,
  type WeaponType,
} from "../../lib/abyss";
import { formatStatValue } from "../../lib/format";
import { t, type Lang } from "../../lib/i18n";
import { foldVi } from "../../lib/slug";
import { Reveal } from "../../components/Reveal";
import { CatalogTile, Chip, ElementBadge, Portrait, SwapGrid } from "../../components/ui";

function displayName(lang: Lang, en: string, vi?: string): string {
  if (lang === "vi" && vi && vi !== en) return `${en} · ${vi}`;
  return lang === "vi" && vi ? vi : en;
}

export function CharacterCatalog(props: { lang: Lang }) {
  const text = () => t(props.lang);
  const [query, setQuery] = createSignal("");
  const [element, setElement] = createSignal<ElementName | "all">("all");
  const [weapon, setWeapon] = createSignal<WeaponType | "all">("all");
  const [nation, setNation] = createSignal("all");
  const [sort, setSort] = createSignal<"name" | "rarity" | "atk">("name");
  const filtered = createMemo(() => {
    const needle = foldVi(query());
    const mode = sort();
    const locale = props.lang === "vi" ? "vi" : "en";
    const label = (character: (typeof characters)[number]) =>
      displayName(props.lang, character.name, character.nameVI);
    return characters
      .filter((character) => {
        if (element() !== "all" && character.element !== element()) return false;
        if (weapon() !== "all" && character.weaponType !== weapon()) return false;
        if (nation() !== "all" && nationKey(character.nationInGame) !== nation()) return false;
        if (!needle) return true;
        return foldVi(`${character.name} ${character.nameVI ?? ""} ${character.id}`).includes(needle);
      })
      .sort((a, b) => {
        if (mode === "rarity" && a.rarity !== b.rarity) return b.rarity - a.rarity;
        if (mode === "atk" && (a.baseStats.lv90.atk ?? 0) !== (b.baseStats.lv90.atk ?? 0)) {
          return (b.baseStats.lv90.atk ?? 0) - (a.baseStats.lv90.atk ?? 0);
        }
        return label(a).localeCompare(label(b), locale);
      });
  });

  return (
    <>
      <input
        class="search"
        value={query()}
        onInput={(event) => setQuery(event.currentTarget.value)}
        placeholder={text().abyssSearchCharacters}
      />
      <div class="filters">
        <Chip active={element() === "all"} onClick={() => setElement("all")}>
          {text().abyssAll}
        </Chip>
        <For each={ELEMENTS}>
          {(item) => (
            <Chip active={element() === item} label={item} onClick={() => setElement(item)}>
              <ElementBadge element={item} />
            </Chip>
          )}
        </For>
      </div>
      <div class="filters">
        <Chip active={weapon() === "all"} onClick={() => setWeapon("all")}>
          {text().abyssAll}
        </Chip>
        <For each={WEAPON_TYPES}>
          {(item) => (
            <Chip active={weapon() === item} onClick={() => setWeapon(item)}>
              {weaponTypeName(item, props.lang)}
            </Chip>
          )}
        </For>
      </div>
      <div class="filters">
        <Chip active={nation() === "all"} onClick={() => setNation("all")}>
          {text().abyssAll}
        </Chip>
        <For each={NATIONS}>
          {(item) => (
            <Chip active={nation() === item} onClick={() => setNation(item)}>
              {item}
            </Chip>
          )}
        </For>
      </div>
      <div class="filters">
        <Chip active={sort() === "name"} onClick={() => setSort("name")}>
          {text().abyssSortName}
        </Chip>
        <Chip active={sort() === "rarity"} onClick={() => setSort("rarity")}>
          {text().abyssSortRarity}
        </Chip>
        <Chip active={sort() === "atk"} onClick={() => setSort("atk")}>
          {text().abyssSortAtk}
        </Chip>
      </div>
      <Show when={filtered().length === 0}>
        <p class="empty rise-once">{text().abyssEmpty}</p>
      </Show>
      <SwapGrid id={`${element()}|${weapon()}|${nation()}|${sort()}`}>
        <For each={filtered()}>
          {(character) => (
            <CatalogTile
              to={`/abyss/characters/${character.id}`}
              kind="characters"
              id={character.id}
              title={displayName(props.lang, character.name, character.nameVI)}
              rarity={character.rarity}
              subtitle={
                <>
                  <ElementBadge element={character.element} /> · {weaponTypeName(character.weaponType, props.lang)}
                </>
              }
            />
          )}
        </For>
      </SwapGrid>
    </>
  );
}

export function CharacterDetail(props: { lang: Lang; id?: string }) {
  const text = () => t(props.lang);
  const [kept, setKept] = createSignal(props.id);
  createEffect(() => {
    const id = props.id;
    if (id) setKept(id);
  });
  const character = () => {
    const id = kept();
    return id ? charactersByID[id] : undefined;
  };
  return (
    <Show when={character()} keyed fallback={<p class="empty">{text().abyssEmpty}</p>}>
      {(item) => (
        <Reveal id={item.id}>
          <article>
            <a class="btn btn-quiet detail-back" href="/abyss/characters">
              <svg
                width="16"
                height="16"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2.2"
                stroke-linecap="round"
                stroke-linejoin="round"
                aria-hidden="true"
              >
                <path d="M14.5 6 8.5 12l6 6" />
              </svg>
              {text().back}
            </a>
            <div class="detail-head">
              <Portrait kind="characters" id={item.id} alt={item.name} large />
              <div>
                <h1 style={{ margin: "0 0 6px", "font-family": "var(--font-story)" }}>
                  {displayName(props.lang, item.name, item.nameVI)}
                </h1>
                <div class="stat-row">
                  <ElementBadge element={item.element} />
                  <span>{weaponTypeName(item.weaponType, props.lang)}</span>
                  <span>{item.nationInGame}</span>
                  {item.releaseDate && <span>{item.releaseDate}</span>}
                  <For each={item.tags}>{(tag) => <span class="pill">{tag}</span>}</For>
                </div>
              </div>
            </div>
            <div class="section-title">{text().baseStats}</div>
            <div class="stat-row">
              <span>
                {text().lv1}: HP {item.baseStats.lv1.hp != null ? Math.round(item.baseStats.lv1.hp) : "—"} · ATK{" "}
                {item.baseStats.lv1.atk != null ? Math.round(item.baseStats.lv1.atk) : "—"} · DEF{" "}
                {item.baseStats.lv1.def != null ? Math.round(item.baseStats.lv1.def) : "—"}
              </span>
            </div>
            <div class="stat-row">
              <span>
                {text().lv90}: HP {item.baseStats.lv90.hp != null ? Math.round(item.baseStats.lv90.hp) : "—"} · ATK{" "}
                {item.baseStats.lv90.atk != null ? Math.round(item.baseStats.lv90.atk) : "—"} · DEF{" "}
                {item.baseStats.lv90.def != null ? Math.round(item.baseStats.lv90.def) : "—"}
              </span>
              {item.baseStats.lv90.ascensionStatType && (
                <span>
                  {item.baseStats.lv90.ascensionStatType}{" "}
                  {formatStatValue(item.baseStats.lv90.ascensionStatType, item.baseStats.lv90.ascensionStatValue)}
                </span>
              )}
            </div>
            {item.kit && <KitSection kit={item.kit} title={text().kitTitle} />}
            {item.abyssRoleNotes && (
              <>
                <div class="section-title">{text().roleNotes}</div>
                <p class="prose">{item.abyssRoleNotes}</p>
              </>
            )}
            <TalentBlock title={text().normalAttack} talent={item.normalAttack} />
            <TalentBlock title={text().skill} talent={item.elementalSkill} />
            <TalentBlock title={text().burst} talent={item.elementalBurst} />
            <For each={item.additionalTalents ?? []}>
              {(talent) => <TalentBlock title={talent.name ?? text().talents} talent={talent} />}
            </For>
            <div class="section-title">{text().passives}</div>
            <For each={item.passives}>
              {(passive) => (
                <p class="prose">
                  <strong>
                    {passive.unlock} · {passive.name}.
                  </strong>{" "}
                  {passive.description}
                </p>
              )}
            </For>
            <div class="section-title">{text().constellations}</div>
            <For each={item.constellations}>
              {(entry) => (
                <div class="constellation">
                  <div class="lv">{entry.level}</div>
                  <div>
                    <strong>{entry.name}</strong>
                    <p class="prose" style={{ margin: "4px 0 0" }}>
                      {entry.description}
                    </p>
                  </div>
                </div>
              )}
            </For>
          </article>
        </Reveal>
      )}
    </Show>
  );
}

function KitSection(props: { kit: NonNullable<Character["kit"]>; title: string }) {
  const kit = () => props.kit;
  const hasBody = () =>
    (kit().conversions?.length ?? 0) > 0 ||
    (kit().buffs?.length ?? 0) > 0 ||
    Boolean(kit().energy) ||
    Boolean(kit().hits?.note) ||
    (kit().reactionBaseDamageBonus?.length ?? 0) > 0 ||
    Boolean(kit().attack?.note);
  return (
    <Show when={hasBody()}>
      <div class="section-title">{props.title}</div>
      <For each={kit().conversions ?? []}>
        {(item) => (
          <p class="prose">
            <strong>
              {item.talent} · {item.label}
              {item.uptime != null ? ` · uptime ${item.uptime}` : ""}.
            </strong>{" "}
            {item.note}
          </p>
        )}
      </For>
      <For each={kit().buffs ?? []}>
        {(item) => (
          <p class="prose">
            <strong>
              {item.scope} · {item.label ?? item.stat}
              {item.uptime != null ? ` · uptime ${item.uptime}` : ""}.
            </strong>{" "}
            {item.note}
          </p>
        )}
      </For>
      <Show when={kit().energy}>
        {(energy) => (
          <p class="prose">
            <strong>Energy.</strong>{" "}
            {[
              energy().particlesPerCast != null ? `${energy().particlesPerCast} hạt/E` : null,
              energy().eventsPerCast != null ? `${energy().eventsPerCast} lần/cast` : null,
              energy().skillCastsPerRotation != null ? `${energy().skillCastsPerRotation} E/rotation` : null,
              energy().collectedBy ? `nhặt: ${energy().collectedBy}` : null,
            ]
              .filter(Boolean)
              .join(" · ")}
            {energy().note ? ` — ${energy().note}` : ""}
          </p>
        )}
      </Show>
      <For each={kit().reactionBaseDamageBonus ?? []}>
        {(item) => (
          <p class="prose">
            <strong>Reaction base DMG +{Math.round(item.value * 100)}%.</strong> {item.reactions.join(", ")}
          </p>
        )}
      </For>
      <Show when={kit().attack?.note}>
        <p class="prose">{kit().attack?.note}</p>
      </Show>
      <Show when={kit().hits?.note}>
        <p class="meta">{kit().hits?.note}</p>
      </Show>
    </Show>
  );
}

function TalentBlock(props: { title: string; talent: Character["normalAttack"] }) {
  const rows = () => {
    const talent = props.talent;
    if (!talent) return [];
    return (talent.hits && talent.hits.length > 0 ? talent.hits : talent.scaling) ?? [];
  };
  return (
    <Show when={props.talent}>
      {(talent) => (
        <>
          <div class="section-title">{props.title}</div>
          {talent().name && <h3 style={{ margin: "0 0 6px" }}>{talent().name}</h3>}
          {talent().description && <p class="prose">{talent().description}</p>}
          <p class="meta">
            {talent().cooldown ? `CD ${talent().cooldown}` : ""}
            {talent().energyCost != null ? ` · Energy ${talent().energyCost}` : ""}
          </p>
          <Show when={rows().length > 0}>
            <div class="md-table-wrap">
              <table class="md-table">
                <thead>
                  <tr>
                    <th>Hit</th>
                    <th>Lv.1</th>
                    <th>Max</th>
                  </tr>
                </thead>
                <tbody>
                  <For each={rows()}>
                    {(hit) => {
                      const keys = Object.keys(hit.values);
                      const first = keys[0];
                      const last = keys[keys.length - 1];
                      return (
                        <tr>
                          <td>{hit.label}</td>
                          <td>{first ? hit.values[first] : "—"}</td>
                          <td>{last ? hit.values[last] : "—"}</td>
                        </tr>
                      );
                    }}
                  </For>
                </tbody>
              </table>
            </div>
          </Show>
        </>
      )}
    </Show>
  );
}

export function WeaponCatalog(props: { lang: Lang }) {
  const text = () => t(props.lang);
  const [query, setQuery] = createSignal("");
  const [type, setType] = createSignal<WeaponType | "all">("all");
  const [rarity, setRarity] = createSignal<number | "all">("all");
  const [sort, setSort] = createSignal<"name" | "rarity" | "atk">("name");
  const filtered = createMemo(() => {
    const needle = foldVi(query());
    const mode = sort();
    const locale = props.lang === "vi" ? "vi" : "en";
    const label = (weapon: (typeof weapons)[number]) =>
      props.lang === "vi" ? weapon.nameVI ?? weapon.name : weapon.name;
    return weapons
      .filter((weapon) => {
        if (type() !== "all" && weapon.type !== type()) return false;
        if (rarity() !== "all" && weapon.rarity !== rarity()) return false;
        if (!needle) return true;
        return foldVi(`${weapon.name} ${weapon.nameVI ?? ""} ${weapon.id}`).includes(needle);
      })
      .sort((a, b) => {
        if (mode === "rarity" && a.rarity !== b.rarity) return b.rarity - a.rarity;
        if (mode === "atk" && (a.atkLv90 ?? 0) !== (b.atkLv90 ?? 0)) return (b.atkLv90 ?? 0) - (a.atkLv90 ?? 0);
        return label(a).localeCompare(label(b), locale);
      });
  });
  const preview = createCatalogPreview(() => filtered().map((weapon) => weapon.id));

  return (
    <div ref={preview.bindRoot}>
      <input
        class="search"
        value={query()}
        onInput={(event) => setQuery(event.currentTarget.value)}
        placeholder={text().abyssSearchWeapons}
      />
      <div class="filters">
        <Chip active={type() === "all"} onClick={() => setType("all")}>
          {text().abyssAll}
        </Chip>
        <For each={WEAPON_TYPES}>
          {(item) => (
            <Chip active={type() === item} onClick={() => setType(item)}>
              {weaponTypeName(item, props.lang)}
            </Chip>
          )}
        </For>
      </div>
      <div class="filters">
        <Chip active={rarity() === "all"} onClick={() => setRarity("all")}>
          {text().abyssAll}
        </Chip>
        <For each={[5, 4, 3]}>
          {(stars) => (
            <Chip active={rarity() === stars} onClick={() => setRarity(stars)}>
              {stars}★
            </Chip>
          )}
        </For>
      </div>
      <div class="filters">
        <Chip active={sort() === "name"} onClick={() => setSort("name")}>
          {text().abyssSortName}
        </Chip>
        <Chip active={sort() === "rarity"} onClick={() => setSort("rarity")}>
          {text().abyssSortRarity}
        </Chip>
        <Chip active={sort() === "atk"} onClick={() => setSort("atk")}>
          {text().abyssSortAtk}
        </Chip>
      </div>
      <Show when={filtered().length === 0}>
        <p class="empty rise-once">{text().abyssEmpty}</p>
      </Show>
      <SwapGrid id={`${type()}|${rarity()}|${sort()}`}>
        <For each={filtered()}>
          {(weapon) => {
            const trigger = preview.triggers(weapon.id);
            return (
              <button
                type="button"
                class="tile"
                classList={{ "is-preview": preview.openId() === weapon.id }}
                data-preview={weapon.id}
                data-rarity={weapon.rarity}
                aria-expanded={preview.openId() === weapon.id ? "true" : "false"}
                aria-controls="weapon-preview"
                onPointerEnter={trigger.onPointerEnter}
                onPointerLeave={trigger.onPointerLeave}
                onFocus={trigger.onFocus}
                onBlur={trigger.onBlur}
                onClick={trigger.onClick}
              >
                <span class="accent-bar" />
                <Portrait kind="weapons" id={weapon.id} alt="" />
                <span class="tile-copy">
                  <strong>{props.lang === "vi" ? weapon.nameVI ?? weapon.name : weapon.name}</strong>
                  <span class="meta">
                    {weaponTypeName(weapon.type, props.lang)}
                    {weapon.subStat.type ? ` · ${weapon.subStat.type}` : ""}
                  </span>
                </span>
              </button>
            );
          }}
        </For>
      </SwapGrid>
      <div
        id="weapon-preview"
        popover="manual"
        class="catalog-popover"
        ref={preview.bindPopover}
        aria-labelledby="weapon-preview-title"
        onPointerEnter={preview.hold}
        onPointerLeave={preview.release}
      >
        <Show when={preview.openId()} keyed>
          {(id) => <WeaponPreviewBody lang={props.lang} id={id} />}
        </Show>
      </div>
    </div>
  );
}

export function WeaponPreviewBody(props: { lang: Lang; id: string }) {
  const text = () => t(props.lang);
  const item = () => weaponsByID[props.id];
  return (
    <Show when={item()}>
      {(weapon) => (
        <article>
          <header class="catalog-preview-head">
            <Portrait kind="weapons" id={weapon().id} alt="" />
            <div>
              <h2 id="weapon-preview-title">
                {props.lang === "vi" ? weapon().nameVI ?? weapon().name : weapon().name}
              </h2>
              <p class="meta">
                {otherName(props.lang, weapon().name, weapon().nameVI)
                  ? `${otherName(props.lang, weapon().name, weapon().nameVI)} · `
                  : ""}
                {weaponTypeName(weapon().type, props.lang)}
              </p>
              <p class="meta">
                ATK {text().lv1} {weapon().atkLv1 ?? "—"} · {text().lv90} {weapon().atkLv90 ?? "—"}
                {weapon().subStat.type
                  ? ` · ${weapon().subStat.type} ${formatStatValue(weapon().subStat.type, weapon().subStat.valueLv90)}`
                  : ""}
              </p>
            </div>
          </header>
          <Show when={weapon().passive}>
            {(passive) => (
              <>
                <h3>{passive().name ?? text().passives}</h3>
                <p>{passive().description}</p>
                <Show when={passive().effects.length > 0}>
                  <div class="md-table-wrap">
                    <table class="md-table">
                      <thead>
                        <tr>
                          <th>{text().refineTable}</th>
                          <th>R1</th>
                          <th>R2</th>
                          <th>R3</th>
                          <th>R4</th>
                          <th>R5</th>
                        </tr>
                      </thead>
                      <tbody>
                        <For each={passive().effects}>
                          {(effect) => (
                            <tr>
                              <td>{effect.stat}</td>
                              <td>{refineCell(effect.stat, effect.r1)}</td>
                              <td>{refineCell(effect.stat, effect.r2)}</td>
                              <td>{refineCell(effect.stat, effect.r3)}</td>
                              <td>{refineCell(effect.stat, effect.r4)}</td>
                              <td>{refineCell(effect.stat, effect.r5)}</td>
                            </tr>
                          )}
                        </For>
                      </tbody>
                    </table>
                  </div>
                </Show>
              </>
            )}
          </Show>
          <h3>{text().acquisition}</h3>
          <p>{weapon().acquisition}</p>
          <Show when={weapon().bestCharacters.length > 0}>
            <h3>{text().bestOn}</h3>
            <p>{weapon().bestCharacters.join(", ")}</p>
          </Show>
        </article>
      )}
    </Show>
  );
}

export function CharacterPreviewBody(props: { lang: Lang; id: string }) {
  const text = () => t(props.lang);
  const item = () => charactersByID[props.id];
  const stat = (value: number | null | undefined) => (value == null ? "—" : String(Math.round(value)));
  return (
    <Show when={item()}>
      {(character) => (
        <article>
          <header class="catalog-preview-head">
            <Portrait kind="characters" id={character().id} alt="" />
            <div>
              <h2 id="character-preview-title">
                {displayName(props.lang, character().name, character().nameVI)}
              </h2>
              <p class="meta">
                <ElementBadge element={character().element} />
                {` ${weaponTypeName(character().weaponType, props.lang)} · ${character().nationInGame}`}
              </p>
            </div>
          </header>
          <h3>{text().baseStats}</h3>
          <p>
            {text().lv90}: HP {stat(character().baseStats.lv90.hp)} · ATK {stat(character().baseStats.lv90.atk)} · DEF{" "}
            {stat(character().baseStats.lv90.def)}
            {character().baseStats.lv90.ascensionStatType
              ? ` · ${character().baseStats.lv90.ascensionStatType} ${formatStatValue(
                  character().baseStats.lv90.ascensionStatType,
                  character().baseStats.lv90.ascensionStatValue,
                )}`
              : ""}
          </p>
          <Show when={character().abyssRoleNotes}>
            <h3>{text().roleNotes}</h3>
            <p>{character().abyssRoleNotes}</p>
          </Show>
          <Show when={character().normalAttack}>
            <h3>{character().normalAttack?.name ?? text().normalAttack}</h3>
            <p>{character().normalAttack?.description}</p>
          </Show>
          <Show when={character().elementalSkill}>
            <h3>{character().elementalSkill?.name ?? text().skill}</h3>
            <p>{character().elementalSkill?.description}</p>
          </Show>
          <Show when={character().elementalBurst}>
            <h3>{character().elementalBurst?.name ?? text().burst}</h3>
            <p>{character().elementalBurst?.description}</p>
          </Show>
          <Show when={character().passives.length > 0}>
            <h3>{text().passives}</h3>
            <For each={character().passives}>
              {(passive) => (
                <p>
                  <strong>
                    {passive.unlock} · {passive.name}.
                  </strong>{" "}
                  {passive.description}
                </p>
              )}
            </For>
          </Show>
          <Show when={character().constellations.length > 0}>
            <h3>{text().constellations}</h3>
            <For each={character().constellations}>
              {(entry) => (
                <p>
                  <strong>
                    C{entry.level} · {entry.name}.
                  </strong>{" "}
                  {entry.description}
                </p>
              )}
            </For>
          </Show>
        </article>
      )}
    </Show>
  );
}

export function WeaponDetail(props: { lang: Lang; id?: string }) {
  const text = () => t(props.lang);
  const [kept, setKept] = createSignal(props.id);
  createEffect(() => {
    const id = props.id;
    if (id) setKept(id);
  });
  const weapon = () => {
    const id = kept();
    return id ? weaponsByID[id] : undefined;
  };
  return (
    <Show when={weapon()} keyed fallback={<p class="empty">{text().abyssEmpty}</p>}>
      {(item) => (
        <Reveal id={item.id}>
          <article>
            <p class="meta">
              <a href="/abyss/weapons">{text().back}</a>
            </p>
            <div class="detail-head">
              <Portrait kind="weapons" id={item.id} alt={item.name} large />
              <div>
                <h1 style={{ margin: "0 0 6px", "font-family": "var(--font-story)" }}>
                  {displayName(props.lang, item.name, item.nameVI)}
                </h1>
                <div class="stat-row">
                  <span>{weaponTypeName(item.type, props.lang)}</span>
                  <span>
                    ATK {text().lv1} {item.atkLv1 ?? "—"} · {text().lv90} {item.atkLv90 ?? "—"}
                  </span>
                  {item.subStat.type && (
                    <span>
                      {item.subStat.type} {formatStatValue(item.subStat.type, item.subStat.valueLv90)}
                    </span>
                  )}
                </div>
              </div>
            </div>
            {item.passive && (
              <>
                <div class="section-title">{item.passive.name ?? "Passive"}</div>
                <p class="prose">{item.passive.description}</p>
                {item.passive.effects.length > 0 && (
                  <div class="md-table-wrap">
                    <table class="md-table">
                      <thead>
                        <tr>
                          <th>{text().refineTable}</th>
                          <th>R1</th>
                          <th>R2</th>
                          <th>R3</th>
                          <th>R4</th>
                          <th>R5</th>
                        </tr>
                      </thead>
                      <tbody>
                        <For each={item.passive.effects}>
                          {(effect) => (
                            <tr>
                              <td>{effect.stat}</td>
                              <td>{effect.r1 ?? "—"}</td>
                              <td>{effect.r2 ?? "—"}</td>
                              <td>{effect.r3 ?? "—"}</td>
                              <td>{effect.r4 ?? "—"}</td>
                              <td>{effect.r5 ?? "—"}</td>
                            </tr>
                          )}
                        </For>
                      </tbody>
                    </table>
                  </div>
                )}
              </>
            )}
            <div class="section-title">{text().acquisition}</div>
            <p class="prose">{item.acquisition}</p>
            {item.bestCharacters.length > 0 && (
              <>
                <div class="section-title">{text().bestOn}</div>
                <p class="prose">{item.bestCharacters.join(", ")}</p>
              </>
            )}
          </article>
        </Reveal>
      )}
    </Show>
  );
}

const PREVIEW_GAP = 8;
const PREVIEW_MARGIN = 12;
const PREVIEW_CAP = 360;

export function finePointer(): boolean {
  return window.matchMedia("(hover: hover) and (pointer: fine)").matches;
}

function eventTarget(event: Event): HTMLElement | undefined {
  const current = event.currentTarget;
  return current instanceof HTMLElement ? current : undefined;
}

function refineCell(stat: string, value: number | string | null): string {
  if (value == null || value === "") return "—";
  if (typeof value === "string") return value;
  return formatStatValue(stat, value);
}

function otherName(lang: Lang, name: string, nameVI?: string): string {
  if (!nameVI || nameVI === name) return "";
  return lang === "vi" ? name : nameVI;
}

function placeCatalogPreview(pop: HTMLElement, target: HTMLElement) {
  const anchor = target.getBoundingClientRect();
  const spaceBelow = Math.max(0, window.innerHeight - PREVIEW_MARGIN - anchor.bottom - PREVIEW_GAP);
  const spaceAbove = Math.max(0, anchor.top - PREVIEW_GAP - PREVIEW_MARGIN);
  const placeBelow = spaceBelow >= spaceAbove;
  const available = placeBelow ? spaceBelow : spaceAbove;
  const maxHeight = Math.min(PREVIEW_CAP, Math.max(available, 160), window.innerHeight - PREVIEW_MARGIN * 2);
  pop.style.maxHeight = `${Math.floor(maxHeight)}px`;
  pop.style.right = "auto";
  pop.style.bottom = "auto";
  const box = pop.getBoundingClientRect();
  let left = anchor.left;
  const maxLeft = window.innerWidth - PREVIEW_MARGIN - box.width;
  if (left > maxLeft) left = Math.max(PREVIEW_MARGIN, maxLeft);
  if (left < PREVIEW_MARGIN) left = PREVIEW_MARGIN;
  const top = placeBelow ? anchor.bottom + PREVIEW_GAP : Math.max(PREVIEW_MARGIN, anchor.top - PREVIEW_GAP - box.height);
  pop.style.left = `${Math.round(left)}px`;
  pop.style.top = `${Math.round(top)}px`;
}

export function createCatalogPreview(listed: () => string[]) {
  const [openId, setOpenId] = createSignal<string | null>(null);
  let rootEl: HTMLElement | undefined;
  let popoverEl: HTMLDivElement | undefined;
  let anchorEl: HTMLElement | undefined;
  let openTimer = 0;
  let closeTimer = 0;

  const closePreview = () => {
    window.clearTimeout(openTimer);
    window.clearTimeout(closeTimer);
    anchorEl = undefined;
    setOpenId(null);
    if (popoverEl?.matches(":popover-open")) popoverEl.hidePopover();
  };

  const openPreview = (id: string, target: HTMLElement) => {
    window.clearTimeout(openTimer);
    window.clearTimeout(closeTimer);
    anchorEl = target;
    setOpenId(id);
    const pop = popoverEl;
    if (!pop) return;
    if (!pop.matches(":popover-open")) pop.showPopover();
    placeCatalogPreview(pop, target);
  };

  const scheduleOpen = (id: string, target: HTMLElement) => {
    window.clearTimeout(closeTimer);
    window.clearTimeout(openTimer);
    anchorEl = target;
    if (popoverEl?.matches(":popover-open")) {
      openPreview(id, target);
      return;
    }
    openTimer = window.setTimeout(() => openPreview(id, target), 90);
  };

  const scheduleClose = () => {
    window.clearTimeout(openTimer);
    closeTimer = window.setTimeout(() => {
      const active = document.activeElement;
      if (anchorEl?.matches(":focus-visible")) return;
      if (active instanceof Node && popoverEl?.contains(active)) return;
      closePreview();
    }, 160);
  };

  createEffect(() => {
    const id = openId();
    if (!id) return;
    if (!listed().includes(id)) closePreview();
  });

  onMount(() => {
    const pane = rootEl?.closest(".stage-pane");
    const onScroll = (event: Event) => {
      const pop = popoverEl;
      const anchor = anchorEl;
      if (!pop?.matches(":popover-open") || !anchor) return;
      if (event.target instanceof Node && pop.contains(event.target)) return;
      const paneBox = pane?.getBoundingClientRect();
      const anchorBox = anchor.getBoundingClientRect();
      const visible =
        !paneBox ||
        (anchorBox.bottom > paneBox.top &&
          anchorBox.top < paneBox.bottom &&
          anchorBox.right > paneBox.left &&
          anchorBox.left < paneBox.right);
      if (!visible) {
        closePreview();
        return;
      }
      placeCatalogPreview(pop, anchor);
    };
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") closePreview();
    };
    const onPointerDown = (event: PointerEvent) => {
      if (!popoverEl?.matches(":popover-open")) return;
      const target = event.target;
      if (!(target instanceof Node)) return;
      if (popoverEl.contains(target)) return;
      if (target instanceof Element && target.closest(".catalog .tile")) return;
      closePreview();
    };
    const host = rootEl?.closest(".keep-alive");
    let observer: MutationObserver | undefined;
    if (pane || host) {
      observer = new MutationObserver(() => {
        if (pane?.getAttribute("aria-hidden") === "true" || host?.hasAttribute("hidden")) closePreview();
      });
      if (pane) observer.observe(pane, { attributes: true, attributeFilter: ["aria-hidden"] });
      if (host) observer.observe(host, { attributes: true, attributeFilter: ["hidden"] });
    }
    document.addEventListener("scroll", onScroll, true);
    window.addEventListener("resize", onScroll);
    document.addEventListener("keydown", onKey);
    document.addEventListener("pointerdown", onPointerDown);
    onCleanup(() => {
      observer?.disconnect();
      document.removeEventListener("scroll", onScroll, true);
      window.removeEventListener("resize", onScroll);
      document.removeEventListener("keydown", onKey);
      document.removeEventListener("pointerdown", onPointerDown);
      window.clearTimeout(openTimer);
      window.clearTimeout(closeTimer);
      if (popoverEl?.matches(":popover-open")) popoverEl.hidePopover();
    });
  });

  return {
    openId,
    bindRoot: (element: HTMLElement) => {
      rootEl = element;
    },
    bindPopover: (element: HTMLDivElement) => {
      popoverEl = element;
    },
    hold: () => {
      window.clearTimeout(closeTimer);
    },
    release: () => {
      if (!finePointer()) return;
      scheduleClose();
    },
    triggers: (id: string) => ({
      onPointerEnter: (event: PointerEvent) => {
        if (!finePointer() || event.pointerType === "touch") return;
        const target = eventTarget(event);
        if (target) scheduleOpen(id, target);
      },
      onPointerLeave: (event: PointerEvent) => {
        if (!finePointer() || event.pointerType === "touch") return;
        scheduleClose();
      },
      onFocus: (event: FocusEvent) => {
        const button = eventTarget(event);
        if (!button) return;
        requestAnimationFrame(() => {
          if (!button.isConnected || !button.matches(":focus-visible")) return;
          openPreview(id, button);
        });
      },
      onBlur: (event: FocusEvent) => {
        const next = event.relatedTarget;
        if (next instanceof Node && popoverEl?.contains(next)) return;
        scheduleClose();
      },
      onClick: (event: MouseEvent) => {
        if (finePointer()) return;
        const target = eventTarget(event);
        if (!target) return;
        if (openId() === id) closePreview();
        else openPreview(id, target);
      },
    }),
  };
}

function pieceText(lang: Lang, piece: { description: string; descriptionVI?: string }): string {
  return lang === "vi" ? piece.descriptionVI ?? piece.description : piece.description;
}

function ArtifactPreviewBody(props: { lang: Lang; id: string }) {
  const text = () => t(props.lang);
  const item = () => artifactSetsByID[props.id];
  return (
    <Show when={item()}>
      {(set) => (
        <article>
          <header class="catalog-preview-head">
            <Portrait kind="artifact-sets" id={set().id} alt="" />
            <div>
              <h2 id="artifact-preview-title">
                {props.lang === "vi" ? set().nameVI ?? set().name : set().name}
              </h2>
              <p class="meta">
                {props.lang === "vi" && set().nameVI && set().nameVI !== set().name ? `${set().name} · ` : ""}
                {props.lang !== "vi" && set().nameVI && set().nameVI !== set().name ? `${set().nameVI} · ` : ""}
                {set().rarity}
                {set().region ? ` · ${set().region}` : ""}
              </p>
            </div>
          </header>
          <h3>{text().twoPiece}</h3>
          <p>{pieceText(props.lang, set().twoPiece)}</p>
          <h3>{text().fourPiece}</h3>
          <p>{pieceText(props.lang, set().fourPiece)}</p>
          <Show when={set().domain}>
            <h3>{text().domain}</h3>
            <p>{set().domain}</p>
          </Show>
          <Show when={set().bestCharacters.length > 0}>
            <h3>{text().bestOn}</h3>
            <p>{set().bestCharacters.join(", ")}</p>
          </Show>
        </article>
      )}
    </Show>
  );
}

export function ArtifactCatalog(props: { lang: Lang }) {
  const text = () => t(props.lang);
  const [query, setQuery] = createSignal("");
  const filtered = createMemo(() => {
    const needle = foldVi(query());
    return artifactSets.filter((set) => {
      if (!needle) return true;
      return foldVi(`${set.name} ${set.nameVI ?? ""} ${set.id}`).includes(needle);
    });
  });
  const preview = createCatalogPreview(() => filtered().map((set) => set.id));
  return (
    <>
      <input
        class="search"
        value={query()}
        onInput={(event) => setQuery(event.currentTarget.value)}
        placeholder={text().abyssSearchArtifacts}
      />
      <Show when={filtered().length === 0}>
        <p class="empty rise-once">{text().abyssEmpty}</p>
      </Show>
      <div class="catalog swap" ref={preview.bindRoot}>
        <For each={filtered()}>
          {(set) => {
            const trigger = preview.triggers(set.id);
            return (
              <button
                type="button"
                class="tile"
                classList={{ "is-preview": preview.openId() === set.id }}
                data-preview={set.id}
                aria-expanded={preview.openId() === set.id ? "true" : "false"}
                aria-controls="artifact-preview"
                onPointerEnter={trigger.onPointerEnter}
                onPointerLeave={trigger.onPointerLeave}
                onFocus={trigger.onFocus}
                onBlur={trigger.onBlur}
                onClick={trigger.onClick}
              >
                <span class="accent-bar" />
                <Portrait kind="artifact-sets" id={set.id} alt="" />
                <span class="tile-copy">
                  <strong>{props.lang === "vi" ? set.nameVI ?? set.name : set.name}</strong>
                  <span class="meta">{set.region ?? set.rarity}</span>
                </span>
              </button>
            );
          }}
        </For>
      </div>
      <div
        id="artifact-preview"
        popover="manual"
        class="catalog-popover"
        ref={preview.bindPopover}
        aria-labelledby="artifact-preview-title"
        onPointerEnter={preview.hold}
        onPointerLeave={preview.release}
      >
        <Show when={preview.openId()} keyed>
          {(id) => <ArtifactPreviewBody lang={props.lang} id={id} />}
        </Show>
      </div>
    </>
  );
}

export function ArtifactDetail(props: { lang: Lang; id?: string }) {
  const text = () => t(props.lang);
  const [kept, setKept] = createSignal(props.id);
  createEffect(() => {
    const id = props.id;
    if (id) setKept(id);
  });
  const set = () => {
    const id = kept();
    return id ? artifactSetsByID[id] : undefined;
  };
  return (
    <Show when={set()} keyed fallback={<p class="empty">{text().abyssEmpty}</p>}>
      {(item) => (
          <Reveal id={item.id}>
            <article>
              <p class="meta">
                <a href="/abyss/artifacts">{text().abyssArtifacts}</a>
              </p>
              <div class="detail-head">
                <Portrait kind="artifact-sets" id={item.id} alt={item.name} large />
                <div>
                  <h1 style={{ margin: "0 0 6px", "font-family": "var(--font-story)" }}>
                    {displayName(props.lang, item.name, item.nameVI)}
                  </h1>
                  <p class="meta">
                    {item.rarity}
                    {item.region ? ` · ${item.region}` : ""}
                  </p>
                </div>
              </div>
              <div class="section-title">{text().twoPiece}</div>
              <p class="prose">
                {props.lang === "vi" ? item.twoPiece.descriptionVI ?? item.twoPiece.description : item.twoPiece.description}
              </p>
              <div class="section-title">{text().fourPiece}</div>
              <p class="prose">
                {props.lang === "vi" ? item.fourPiece.descriptionVI ?? item.fourPiece.description : item.fourPiece.description}
              </p>
              {item.domain && (
                <>
                  <div class="section-title">{text().domain}</div>
                  <p class="prose">{item.domain}</p>
                </>
              )}
              {item.bestCharacters.length > 0 && (
                <>
                  <div class="section-title">{text().bestOn}</div>
                  <p class="prose">{item.bestCharacters.join(", ")}</p>
                </>
              )}
            </article>
          </Reveal>
      )}
    </Show>
  );
}
