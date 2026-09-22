import { useMemo, useState } from "react";
import { currentCycle, cycles, floor12 as floor12Of } from "../../lib/abyss";
import { formatDateRange, todayISO } from "../../lib/format";
import { t, type Lang } from "../../lib/i18n";
import { Reveal } from "../../components/Reveal";
import { FloorMonsters, UniqueMonsterStrip } from "./MonsterList";

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
  const floor12 = floor12Of(cycle);

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

      <Reveal id={cycle.fileId}>
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

      {floor12 && (
        <section className="panel" style={{ marginBottom: 16 }}>
          <div className="group-label">{copy.abyssMonsters} · {lang === "vi" ? "Tầng" : "Floor"} 12</div>
          <UniqueMonsterStrip floor={floor12} lang={lang} />
        </section>
      )}

      {floor12 && <FloorMonsters floor={floor12} lang={lang} defaultOpen />}
      </Reveal>
    </>
  );
}
