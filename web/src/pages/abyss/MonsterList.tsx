import {
  monsterHP,
  splitDisorder,
  type CycleFloor,
  type Monster,
} from "../../lib/abyss";
import { formatHP, formatPercent } from "../../lib/format";
import { t, type Lang } from "../../lib/i18n";
import { ElementBadge } from "../../components/ui";

function ResistancePips({ monster }: { monster: Monster }) {
  const entries: Array<[string, number]> = [];
  if (monster.resistances) {
    for (const [element, value] of Object.entries(monster.resistances)) {
      entries.push([element, value]);
    }
  }
  if (monster.physicalResistance != null) entries.push(["Physical", monster.physicalResistance]);
  if (entries.length === 0) return null;
  return (
    <div className="res-pips">
      {entries
        .filter(([, value]) => value !== 0.1)
        .map(([element, value]) => (
          <span
            key={element}
            className={`res-pip ${value < 0 ? "weak" : value > 0.15 ? "strong" : ""}`}
          >
            {element} {formatPercent(value, 0)}
          </span>
        ))}
    </div>
  );
}

export function MonsterCard({
  monster,
  level,
  multiplier,
  lang,
}: {
  monster: Monster;
  level: number;
  multiplier: number;
  lang: Lang;
}) {
  const copy = t(lang);
  const hp = monsterHP(monster, level, multiplier);
  return (
    <div className="monster">
      <div className="monster-top">
        <strong>{monster.name}</strong>
        <span className="meta">
          {monster.count}
          {hp != null ? ` · ${copy.abyssHP} ${formatHP(hp)}` : ""}
        </span>
      </div>
      <div className="meta">
        {monster.elements.map((element) => (
          <ElementBadge key={element} element={element} />
        ))}
        {monster.size ? ` · ${monster.size}` : ""}
        {monster.weakpoint ? " · weak point" : ""}
      </div>
      <ResistancePips monster={monster} />
      {monster.mechanics && monster.mechanics !== "chưa xác nhận" && (
        <p className="meta" style={{ margin: "6px 0 0" }}>
          {copy.abyssMechanics}: {monster.mechanics}
        </p>
      )}
      {monster.resistanceNotes && <p className="meta">{monster.resistanceNotes}</p>}
    </div>
  );
}

export function FloorMonsters({
  floor,
  lang,
  defaultOpen = true,
}: {
  floor: CycleFloor;
  lang: Lang;
  defaultOpen?: boolean;
}) {
  const copy = t(lang);
  const split = splitDisorder(floor.leyLineDisorder);
  const multiplier = floor.enemyHPMultiplier ?? 1;
  return (
    <details className="panel floor" open={defaultOpen}>
      <summary className="floor-head">
        <strong>
          {lang === "vi" ? "Tầng" : "Floor"} {floor.floor}
        </strong>
        <span className="meta">
          ×{multiplier} HP · {monsterCount(floor)} {copy.abyssMonsters.toLowerCase()}
        </span>
      </summary>
      <div className="section-title">{copy.abyssLeyLine}</div>
      {split.half1 || split.half2 ? (
        <>
          {split.half1 && (
            <p className="prose">
              <strong>{copy.abyssHalf1}.</strong> {split.half1}
            </p>
          )}
          {split.half2 && (
            <p className="prose">
              <strong>{copy.abyssHalf2}.</strong> {split.half2}
            </p>
          )}
        </>
      ) : (
        <p className="prose">{floor.leyLineDisorder}</p>
      )}
      {floor.recommendation && (
        <aside className="callout turning" style={{ marginTop: 12 }}>
          <span className="callout-bar" />
          <div className="callout-body">
            <strong>{copy.abyssRecommendation}.</strong> {floor.recommendation}
          </div>
        </aside>
      )}
      {floor.chambers.map((chamber) => (
        <div key={chamber.chamber}>
          <div className="section-title">
            {copy.abyssChamber} {chamber.chamber} · {copy.abyssLevel} {chamber.monsterLevel}
          </div>
          {chamber.waves.map((wave) => (
            <div key={wave.wave}>
              <div className="wave-label">
                {copy.abyssWave} {wave.wave}
                {wave.wave === 1 ? ` · ${copy.abyssHalf1}` : wave.wave === 2 ? ` · ${copy.abyssHalf2}` : ""}
              </div>
              {wave.monsters.map((monster, index) => (
                <MonsterCard
                  key={`${monster.name}-${wave.wave}-${index}`}
                  monster={monster}
                  level={chamber.monsterLevel}
                  multiplier={multiplier}
                  lang={lang}
                />
              ))}
            </div>
          ))}
        </div>
      ))}
    </details>
  );
}

function monsterCount(floor: CycleFloor): number {
  return floor.chambers.reduce(
    (sum, chamber) => sum + chamber.waves.reduce((inner, wave) => inner + wave.monsters.length, 0),
    0,
  );
}

export function UniqueMonsterStrip({ floor, lang }: { floor: CycleFloor; lang: Lang }) {
  const seen = new Set<string>();
  const unique: Monster[] = [];
  for (const chamber of floor.chambers) {
    for (const wave of chamber.waves) {
      for (const monster of wave.monsters) {
        if (seen.has(monster.name)) continue;
        seen.add(monster.name);
        unique.push(monster);
      }
    }
  }
  return (
    <div className="monster-strip">
      {unique.map((monster) => (
        <div key={monster.name} className="monster-chip">
          <strong>{monster.name}</strong>
          <span className="meta">
            {monster.elements.map((element) => (
              <ElementBadge key={element} element={element} />
            ))}
          </span>
        </div>
      ))}
      {unique.length === 0 && <span className="meta">{t(lang).abyssEmpty}</span>}
    </div>
  );
}
