import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
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
  type Character,
  type ElementName,
  type WeaponType,
} from "../../lib/abyss";
import { formatStatValue } from "../../lib/format";
import { t, type Lang } from "../../lib/i18n";
import { foldVi } from "../../lib/slug";
import { Reveal } from "../../components/Reveal";
import { CatalogTile, Chip, ElementBadge, Portrait, Stars } from "../../components/ui";

function displayName(lang: Lang, en: string, vi?: string): string {
  if (lang === "vi" && vi && vi !== en) return `${en} · ${vi}`;
  return lang === "vi" && vi ? vi : en;
}

export function CharacterCatalog({ lang }: { lang: Lang }) {
  const copy = t(lang);
  const [query, setQuery] = useState("");
  const [element, setElement] = useState<ElementName | "all">("all");
  const [weapon, setWeapon] = useState<WeaponType | "all">("all");
  const [nation, setNation] = useState("all");
  const needle = foldVi(query);

  const filtered = useMemo(() => {
    return characters.filter((character) => {
      if (element !== "all" && character.element !== element) return false;
      if (weapon !== "all" && character.weaponType !== weapon) return false;
      if (nation !== "all" && nationKey(character.nationInGame) !== nation) return false;
      if (!needle) return true;
      return foldVi(`${character.name} ${character.nameVI ?? ""} ${character.id}`).includes(needle);
    });
  }, [element, weapon, nation, needle]);

  return (
    <>
      <input
        className="search"
        value={query}
        onChange={(event) => setQuery(event.target.value)}
        placeholder={copy.abyssSearchCharacters}
      />
      <div className="filters">
        <Chip active={element === "all"} onClick={() => setElement("all")}>
          {copy.abyssAll}
        </Chip>
        {ELEMENTS.map((item) => (
          <Chip key={item} active={element === item} onClick={() => setElement(item)}>
            {item}
          </Chip>
        ))}
      </div>
      <div className="filters">
        <Chip active={weapon === "all"} onClick={() => setWeapon("all")}>
          {copy.abyssAll}
        </Chip>
        {WEAPON_TYPES.map((item) => (
          <Chip key={item} active={weapon === item} onClick={() => setWeapon(item)}>
            {item}
          </Chip>
        ))}
      </div>
      <div className="filters">
        <Chip active={nation === "all"} onClick={() => setNation("all")}>
          {copy.abyssAll}
        </Chip>
        {NATIONS.map((item) => (
          <Chip key={item} active={nation === item} onClick={() => setNation(item)}>
            {item}
          </Chip>
        ))}
      </div>
      {filtered.length === 0 && <p className="empty rise-once">{copy.abyssEmpty}</p>}
      <div className="catalog swap" key={`${element}|${weapon}|${nation}`}>
        {filtered.map((character) => (
          <CatalogTile
            key={character.id}
            to={`/abyss/characters/${character.id}`}
            kind="characters"
            id={character.id}
            title={displayName(lang, character.name, character.nameVI)}
            accent={character.element}
            subtitle={
              <>
                <Stars n={character.rarity} /> {character.element} · {character.weaponType}
              </>
            }
          />
        ))}
      </div>
    </>
  );
}

export function CharacterDetail({ lang, id }: { lang: Lang; id?: string }) {
  const copy = t(lang);
  const [kept, setKept] = useState(id);
  useEffect(() => {
    if (id) setKept(id);
  }, [id]);
  const character = kept ? charactersByID[kept] : undefined;
  if (!character) return <p className="empty">{copy.abyssEmpty}</p>;
  const lv90 = character.baseStats.lv90;
  const lv1 = character.baseStats.lv1;
  return (
    <Reveal id={character.id}>
    <article>
      <p className="meta">
        <Link to="/abyss/characters">{copy.abyssCharacters}</Link>
      </p>
      <div className="detail-head">
        <Portrait kind="characters" id={character.id} alt={character.name} large />
        <div>
          <h1 style={{ margin: "0 0 6px", fontFamily: "var(--font-story)" }}>
            {displayName(lang, character.name, character.nameVI)}
          </h1>
          <div className="stat-row">
            <Stars n={character.rarity} />
            <ElementBadge element={character.element} />
            <span>{character.weaponType}</span>
            <span>{character.nationInGame}</span>
            {character.releaseDate && <span>{character.releaseDate}</span>}
            {character.tags.map((tag) => (
              <span key={tag} className="pill">
                {tag}
              </span>
            ))}
          </div>
        </div>
      </div>
      <div className="section-title">{copy.baseStats}</div>
      <div className="stat-row">
        <span>
          {copy.lv1}: HP {lv1.hp != null ? Math.round(lv1.hp) : "—"} · ATK{" "}
          {lv1.atk != null ? Math.round(lv1.atk) : "—"} · DEF {lv1.def != null ? Math.round(lv1.def) : "—"}
        </span>
      </div>
      <div className="stat-row">
        <span>
          {copy.lv90}: HP {lv90.hp != null ? Math.round(lv90.hp) : "—"} · ATK{" "}
          {lv90.atk != null ? Math.round(lv90.atk) : "—"} · DEF {lv90.def != null ? Math.round(lv90.def) : "—"}
        </span>
        {lv90.ascensionStatType && (
          <span>
            {lv90.ascensionStatType} {formatStatValue(lv90.ascensionStatType, lv90.ascensionStatValue)}
          </span>
        )}
      </div>
      {character.kit && <KitSection kit={character.kit} title={copy.kitTitle} />}
      {character.abyssRoleNotes && (
        <>
          <div className="section-title">{copy.roleNotes}</div>
          <p className="prose">{character.abyssRoleNotes}</p>
        </>
      )}
      <TalentBlock title={copy.normalAttack} talent={character.normalAttack} />
      <TalentBlock title={copy.skill} talent={character.elementalSkill} />
      <TalentBlock title={copy.burst} talent={character.elementalBurst} />
      {character.additionalTalents?.map((talent) => (
        <TalentBlock key={talent.name ?? "extra"} title={talent.name ?? copy.talents} talent={talent} />
      ))}
      <div className="section-title">{copy.passives}</div>
      {character.passives.map((passive) => (
        <p key={passive.name} className="prose">
          <strong>
            {passive.unlock} · {passive.name}.
          </strong>{" "}
          {passive.description}
        </p>
      ))}
      <div className="section-title">{copy.constellations}</div>
      {character.constellations.map((item) => (
        <div key={item.level} className="constellation">
          <div className="lv">{item.level}</div>
          <div>
            <strong>{item.name}</strong>
            <p className="prose" style={{ margin: "4px 0 0" }}>
              {item.description}
            </p>
          </div>
        </div>
      ))}
    </article>
    </Reveal>
  );
}

function KitSection({ kit, title }: { kit: NonNullable<Character["kit"]>; title: string }) {
  const hasBody =
    (kit.conversions && kit.conversions.length > 0) ||
    (kit.buffs && kit.buffs.length > 0) ||
    kit.energy ||
    kit.hits?.note ||
    (kit.reactionBaseDamageBonus && kit.reactionBaseDamageBonus.length > 0) ||
    kit.attack?.note;
  if (!hasBody) return null;
  return (
    <>
      <div className="section-title">{title}</div>
      {kit.conversions?.map((item) => (
        <p key={item.label} className="prose">
          <strong>
            {item.talent} · {item.label}
            {item.uptime != null ? ` · uptime ${item.uptime}` : ""}.
          </strong>{" "}
          {item.note}
        </p>
      ))}
      {kit.buffs?.map((item) => (
        <p key={`${item.scope}-${item.label}`} className="prose">
          <strong>
            {item.scope} · {item.label ?? item.stat}
            {item.uptime != null ? ` · uptime ${item.uptime}` : ""}.
          </strong>{" "}
          {item.note}
        </p>
      ))}
      {kit.energy && (
        <p className="prose">
          <strong>Energy.</strong>{" "}
          {[
            kit.energy.particlesPerCast != null ? `${kit.energy.particlesPerCast} hạt/E` : null,
            kit.energy.eventsPerCast != null ? `${kit.energy.eventsPerCast} lần/cast` : null,
            kit.energy.skillCastsPerRotation != null
              ? `${kit.energy.skillCastsPerRotation} E/rotation`
              : null,
            kit.energy.collectedBy ? `nhặt: ${kit.energy.collectedBy}` : null,
          ]
            .filter(Boolean)
            .join(" · ")}
          {kit.energy.note ? ` — ${kit.energy.note}` : ""}
        </p>
      )}
      {kit.reactionBaseDamageBonus?.map((item) => (
        <p key={item.reactions.join(",")} className="prose">
          <strong>Reaction base DMG +{Math.round(item.value * 100)}%.</strong> {item.reactions.join(", ")}
        </p>
      ))}
      {kit.attack?.note && <p className="prose">{kit.attack.note}</p>}
      {kit.hits?.note && <p className="meta">{kit.hits.note}</p>}
    </>
  );
}

function TalentBlock({
  title,
  talent,
}: {
  title: string;
  talent: Character["normalAttack"];
}) {
  if (!talent) return null;
  const rows = (talent.hits && talent.hits.length > 0 ? talent.hits : talent.scaling) ?? [];
  return (
    <>
      <div className="section-title">{title}</div>
      {talent.name && <h3 style={{ margin: "0 0 6px" }}>{talent.name}</h3>}
      {talent.description && <p className="prose">{talent.description}</p>}
      <p className="meta">
        {talent.cooldown ? `CD ${talent.cooldown}` : ""}
        {talent.energyCost != null ? ` · Energy ${talent.energyCost}` : ""}
      </p>
      {rows.length > 0 && (
        <div className="md-table-wrap">
          <table className="md-table">
            <thead>
              <tr>
                <th>Hit</th>
                <th>Lv.1</th>
                <th>Max</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((hit) => {
                const keys = Object.keys(hit.values);
                const first = keys[0];
                const last = keys[keys.length - 1];
                return (
                  <tr key={hit.label}>
                    <td>{hit.label}</td>
                    <td>{first ? hit.values[first] : "—"}</td>
                    <td>{last ? hit.values[last] : "—"}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </>
  );
}

export function WeaponCatalog({ lang }: { lang: Lang }) {
  const copy = t(lang);
  const [query, setQuery] = useState("");
  const [type, setType] = useState<WeaponType | "all">("all");
  const [rarity, setRarity] = useState<number | "all">("all");
  const needle = foldVi(query);
  const filtered = useMemo(() => {
    return weapons.filter((weapon) => {
      if (type !== "all" && weapon.type !== type) return false;
      if (rarity !== "all" && weapon.rarity !== rarity) return false;
      if (!needle) return true;
      return foldVi(`${weapon.name} ${weapon.nameVI ?? ""} ${weapon.id}`).includes(needle);
    });
  }, [type, rarity, needle]);

  return (
    <>
      <input
        className="search"
        value={query}
        onChange={(event) => setQuery(event.target.value)}
        placeholder={copy.abyssSearchWeapons}
      />
      <div className="filters">
        <Chip active={type === "all"} onClick={() => setType("all")}>
          {copy.abyssAll}
        </Chip>
        {WEAPON_TYPES.map((item) => (
          <Chip key={item} active={type === item} onClick={() => setType(item)}>
            {item}
          </Chip>
        ))}
      </div>
      <div className="filters">
        <Chip active={rarity === "all"} onClick={() => setRarity("all")}>
          {copy.abyssAll}
        </Chip>
        {[5, 4, 3].map((stars) => (
          <Chip key={stars} active={rarity === stars} onClick={() => setRarity(stars)}>
            {stars}★
          </Chip>
        ))}
      </div>
      {filtered.length === 0 && <p className="empty rise-once">{copy.abyssEmpty}</p>}
      <div className="catalog swap" key={`${type}|${rarity}`}>
        {filtered.map((weapon) => (
          <CatalogTile
            key={weapon.id}
            to={`/abyss/weapons/${weapon.id}`}
            kind="weapons"
            id={weapon.id}
            title={lang === "vi" ? weapon.nameVI ?? weapon.name : weapon.name}
            subtitle={
              <>
                <Stars n={weapon.rarity} /> {weapon.type}
                {weapon.subStat.type ? ` · ${weapon.subStat.type}` : ""}
              </>
            }
          />
        ))}
      </div>
    </>
  );
}

export function WeaponDetail({ lang, id }: { lang: Lang; id?: string }) {
  const copy = t(lang);
  const [kept, setKept] = useState(id);
  useEffect(() => {
    if (id) setKept(id);
  }, [id]);
  const weapon = kept ? weaponsByID[kept] : undefined;
  if (!weapon) return <p className="empty">{copy.abyssEmpty}</p>;
  return (
    <Reveal id={weapon.id}>
    <article>
      <p className="meta">
        <Link to="/abyss/weapons">{copy.abyssWeapons}</Link>
      </p>
      <div className="detail-head">
        <Portrait kind="weapons" id={weapon.id} alt={weapon.name} large />
        <div>
          <h1 style={{ margin: "0 0 6px", fontFamily: "var(--font-story)" }}>
            {displayName(lang, weapon.name, weapon.nameVI)}
          </h1>
          <div className="stat-row">
            <Stars n={weapon.rarity} />
            <span>{weapon.type}</span>
            <span>
              ATK {copy.lv1} {weapon.atkLv1 ?? "—"} · {copy.lv90} {weapon.atkLv90 ?? "—"}
            </span>
            {weapon.subStat.type && (
              <span>
                {weapon.subStat.type} {formatStatValue(weapon.subStat.type, weapon.subStat.valueLv90)}
              </span>
            )}
          </div>
        </div>
      </div>
      {weapon.passive && (
        <>
          <div className="section-title">{weapon.passive.name ?? "Passive"}</div>
          <p className="prose">{weapon.passive.description}</p>
          {weapon.passive.effects.length > 0 && (
            <div className="md-table-wrap">
              <table className="md-table">
                <thead>
                  <tr>
                    <th>{copy.refineTable}</th>
                    <th>R1</th>
                    <th>R2</th>
                    <th>R3</th>
                    <th>R4</th>
                    <th>R5</th>
                  </tr>
                </thead>
                <tbody>
                  {weapon.passive.effects.map((effect) => (
                    <tr key={effect.stat}>
                      <td>{effect.stat}</td>
                      <td>{effect.r1 ?? "—"}</td>
                      <td>{effect.r2 ?? "—"}</td>
                      <td>{effect.r3 ?? "—"}</td>
                      <td>{effect.r4 ?? "—"}</td>
                      <td>{effect.r5 ?? "—"}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </>
      )}
      <div className="section-title">{copy.acquisition}</div>
      <p className="prose">{weapon.acquisition}</p>
      {weapon.bestCharacters.length > 0 && (
        <>
          <div className="section-title">{copy.bestOn}</div>
          <p className="prose">{weapon.bestCharacters.join(", ")}</p>
        </>
      )}
    </article>
    </Reveal>
  );
}

export function ArtifactCatalog({ lang }: { lang: Lang }) {
  const copy = t(lang);
  const [query, setQuery] = useState("");
  const needle = foldVi(query);
  const filtered = artifactSets.filter((set) => {
    if (!needle) return true;
    return foldVi(`${set.name} ${set.nameVI ?? ""} ${set.id}`).includes(needle);
  });
  return (
    <>
      <input
        className="search"
        value={query}
        onChange={(event) => setQuery(event.target.value)}
        placeholder={copy.abyssSearchArtifacts}
      />
      {filtered.length === 0 && <p className="empty rise-once">{copy.abyssEmpty}</p>}
      <div className="catalog swap">
        {filtered.map((set) => (
          <CatalogTile
            key={set.id}
            to={`/abyss/artifacts/${set.id}`}
            kind="artifact-sets"
            id={set.id}
            title={lang === "vi" ? set.nameVI ?? set.name : set.name}
            subtitle={set.region ?? set.rarity}
          />
        ))}
      </div>
    </>
  );
}

export function ArtifactDetail({ lang, id }: { lang: Lang; id?: string }) {
  const copy = t(lang);
  const [kept, setKept] = useState(id);
  useEffect(() => {
    if (id) setKept(id);
  }, [id]);
  const set = kept ? artifactSetsByID[kept] : undefined;
  if (!set) return <p className="empty">{copy.abyssEmpty}</p>;
  const two = lang === "vi" ? set.twoPiece.descriptionVI ?? set.twoPiece.description : set.twoPiece.description;
  const four = lang === "vi" ? set.fourPiece.descriptionVI ?? set.fourPiece.description : set.fourPiece.description;
  return (
    <Reveal id={set.id}>
    <article>
      <p className="meta">
        <Link to="/abyss/artifacts">{copy.abyssArtifacts}</Link>
      </p>
      <div className="detail-head">
        <Portrait kind="artifact-sets" id={set.id} alt={set.name} large />
        <div>
          <h1 style={{ margin: "0 0 6px", fontFamily: "var(--font-story)" }}>
            {displayName(lang, set.name, set.nameVI)}
          </h1>
          <p className="meta">
            {set.rarity}
            {set.region ? ` · ${set.region}` : ""}
          </p>
        </div>
      </div>
      <div className="section-title">{copy.twoPiece}</div>
      <p className="prose">{two}</p>
      <div className="section-title">{copy.fourPiece}</div>
      <p className="prose">{four}</p>
      {set.domain && (
        <>
          <div className="section-title">{copy.domain}</div>
          <p className="prose">{set.domain}</p>
        </>
      )}
      {set.bestCharacters.length > 0 && (
        <>
          <div className="section-title">{copy.bestOn}</div>
          <p className="prose">{set.bestCharacters.join(", ")}</p>
        </>
      )}
    </article>
    </Reveal>
  );
}
