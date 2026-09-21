import { useMemo, useState } from "react";
import {
  currentCycle,
  cycles,
  monsterHP,
  splitDisorder,
  type AbyssCycle,
  type Monster,
} from "../../lib/abyss";
import { formatDateRange, formatHP, formatPercent, todayISO } from "../../lib/format";
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
            {element} {formatPercent(value, value % 0.01 === 0 ? 0 : 0)}
          </span>
        ))}
    </div>
  );
}

function MonsterCard({
  monster,
  level,
  multiplier,
  copy,
}: {
  monster: Monster;
  level: number;
  multiplier: number;
  copy: ReturnType<typeof t>;
}) {
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
      {monster.mechanics && (
        <p className="meta" style={{ margin: "6px 0 0" }}>
          {copy.abyssMechanics}: {monster.mechanics}
        </p>
      )}
      {monster.resistanceNotes && <p className="meta">{monster.resistanceNotes}</p>}
    </div>
  );
}

export function CyclePage({ lang }: { lang: Lang }) {
  const copy = t(lang);
  const [fileId, setFileId] = useState(currentCycle().fileId);
  const cycle = useMemo(
    () => cycles.find((item) => item.fileId === fileId) ?? currentCycle(),
    [fileId],
  );
  const now = todayISO();
  const expired = cycle.periodEnd < now;
  const blessing = cycle.blessingOfTheAbyssalMoon;

  return (
    <>
      <div className="filters">
        {cycles.map((item) => (
          <button
            key={item.fileId}
            type="button"
            className={`chip ${item.fileId === cycle.fileId ? "active" : ""}`}
            onClick={() => setFileId(item.fileId)}
          >
            {item.fileId === currentCycle().fileId ? copy.currentCycle : copy.previousCycle}
            {item.periodEnd < now ? ` · ${copy.expired}` : ""}
          </button>
        ))}
      </div>

      <section className="panel" style={{ marginBottom: 16 }}>
        <div className="group-label">{copy.abyssBlessing}</div>
        <h2 style={{ margin: "4px 0 8px" }}>
          {lang === "vi" ? blessing.nameVI ?? blessing.name : blessing.name}
        </h2>
        <p className="prose">{blessing.description}</p>
        {blessing.relatedMechanic && <p className="meta">{blessing.relatedMechanic}</p>}
        <p className="meta" style={{ marginTop: 8 }}>
          {formatDateRange(cycle.periodStart, cycle.periodEnd, lang)}
          {cycle.gameVersion ? ` · v${cycle.gameVersion}` : ""}
          {expired ? ` · ${copy.expired}` : ""}
        </p>
      </section>

      {cycle.floors.map((floor) => (
        <FloorCard key={floor.floor} floor={floor} lang={lang} />
      ))}
    </>
  );
}

function FloorCard({
  floor,
  lang,
}: {
  floor: AbyssCycle["floors"][number];
  lang: Lang;
}) {
  const copy = t(lang);
  const split = splitDisorder(floor.leyLineDisorder);
  const multiplier = floor.enemyHPMultiplier ?? 1;
  return (
    <details className="panel floor" open={floor.floor === 12}>
      <summary className="floor-head">
        <strong>
          {lang === "vi" ? "Tầng" : "Floor"} {floor.floor}
        </strong>
        <span className="meta">×{multiplier} HP</span>
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
              </div>
              {wave.monsters.map((monster) => (
                <MonsterCard
                  key={`${monster.name}-${wave.wave}`}
                  monster={monster}
                  level={chamber.monsterLevel}
                  multiplier={multiplier}
                  copy={copy}
                />
              ))}
            </div>
          ))}
        </div>
      ))}
    </details>
  );
}
