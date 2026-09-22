import {
  monsterHPBreakdown,
  monsterIconId,
  splitDisorder,
  type CycleFloor,
  type Monster,
} from "../../lib/abyss";
import { formatHP, formatPercent } from "../../lib/format";
import { t, type Lang } from "../../lib/i18n";
import { ElementBadge, Portrait } from "../../components/ui";

const RES_ORDER = ["Anemo", "Geo", "Electro", "Dendro", "Hydro", "Pyro", "Cryo", "Physical"] as const;

function resistanceValue(monster: Monster, key: string): number | null {
  if (key === "Physical") return monster.physicalResistance ?? null;
  const value = monster.resistances?.[key];
  return value == null ? null : value;
}

function ResistanceTable({ monster }: { monster: Monster }) {
  const cells = RES_ORDER.map((key) => ({ key, value: resistanceValue(monster, key) }));
  if (cells.every((cell) => cell.value == null)) return null;
  return (
    <div className="res-table">
      {cells.map((cell) => {
        const value = cell.value ?? 0.1;
        const known = cell.value != null;
        return (
          <span
            key={cell.key}
            className={`res-cell ${!known ? "unknown" : value < 0 ? "weak" : value > 0.15 ? "strong" : ""}`}
            title={cell.key}
          >
            <span className="element" data-el={cell.key === "Physical" ? undefined : cell.key}>
              {cell.key === "Physical" ? "Phys" : cell.key.slice(0, 3)}
            </span>
            {known ? formatPercent(value, value % 0.01 === 0 ? 0 : 0) : "—"}
          </span>
        );
      })}
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="monster-stat">
      <span className="monster-stat-label">{label}</span>
      <span>{value}</span>
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
  const hp = monsterHPBreakdown(monster, level, multiplier);
  const icon = monsterIconId(monster);
  return (
    <div className="monster-card">
      <Portrait kind="monsters" id={icon} alt={monster.name} large />
      <div className="monster-body">
        <div className="monster-top">
          <strong>{monster.name}</strong>
          <span className="meta">{monster.elements.map((element) => (
            <ElementBadge key={element} element={element} />
          ))}</span>
        </div>
        <div className="monster-stats">
          <Stat label={copy.abyssCount} value={monster.count} />
          {monster.spawns != null && <Stat label={copy.abyssSpawns} value={String(monster.spawns)} />}
          {monster.size && <Stat label={copy.abyssSize} value={monster.size} />}
          <Stat label={copy.abyssLevel} value={String(level)} />
          {hp && <Stat label={copy.abyssHPEach} value={formatHP(hp.perSpawn)} />}
          {hp && <Stat label={copy.abyssHPTotal} value={formatHP(hp.total)} />}
          {hp && (
            <Stat
              label={copy.abyssHPRatio}
              value={`${hp.ratio} × type ${hp.type} ×${multiplier}`}
            />
          )}
          {monster.hp?.variant && <Stat label={copy.abyssVariant} value={monster.hp.variant} />}
          {monster.weakpoint != null && (
            <Stat label={copy.abyssWeakpoint} value={monster.weakpoint ? (lang === "vi" ? "Có" : "Yes") : (lang === "vi" ? "Không" : "No")} />
          )}
        </div>
        <ResistanceTable monster={monster} />
        {monster.mechanics && monster.mechanics !== "chưa xác nhận" && (
          <p className="meta" style={{ margin: "6px 0 0" }}>
            {copy.abyssMechanics}: {monster.mechanics}
          </p>
        )}
        {monster.resistanceNotes && <p className="meta">{monster.resistanceNotes}</p>}
        {monster.hpRatio && monster.hpRatio !== "chưa xác nhận" && (
          <p className="meta">{monster.hpRatio}</p>
        )}
      </div>
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
    <details
      className={`panel floor${defaultOpen ? " open" : ""}`}
      open={defaultOpen}
      onToggle={(event) => {
        event.currentTarget.classList.toggle("open", event.currentTarget.open);
      }}
    >
      <summary className="floor-head">
        <strong>
          {lang === "vi" ? "Tầng" : "Floor"} {floor.floor}
        </strong>
        <span className="meta">
          ×{multiplier} HP · {monsterCount(floor)} {copy.abyssMonsters.toLowerCase()}
        </span>
      </summary>
      <div className="fold">
        <div className="fold-inner">
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
        </div>
      </div>
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
          <Portrait kind="monsters" id={monsterIconId(monster)} alt="" />
          <div>
            <strong>{monster.name}</strong>
            <span className="meta">
              {monster.elements.map((element) => (
                <ElementBadge key={element} element={element} />
              ))}
            </span>
          </div>
        </div>
      ))}
      {unique.length === 0 && <span className="meta">{t(lang).abyssEmpty}</span>}
    </div>
  );
}
