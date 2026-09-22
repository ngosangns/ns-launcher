import { currentCycle, floor12 as floor12Of } from "../../lib/abyss";
import { formatDateRange } from "../../lib/format";
import { t, type Lang } from "../../lib/i18n";
import { Reveal } from "../../components/Reveal";
import { FloorMonsters } from "./MonsterList";

export function CyclePage(props: { lang: Lang }) {
  const text = () => t(props.lang);
  const cycle = currentCycle();
  const blessing = cycle.blessingOfTheAbyssalMoon;
  const floor12 = floor12Of(cycle);

  return (
    <Reveal id={cycle.fileId}>
      <section class="panel" style={{ "margin-bottom": "16px" }}>
        <div class="group-label">{text().abyssBlessing}</div>
        <h2 style={{ margin: "4px 0 8px" }}>
          {props.lang === "vi" ? blessing.nameVI ?? blessing.name : blessing.name}
        </h2>
        <p class="prose">{blessing.description}</p>
        {blessing.relatedMechanic && <p class="meta">{blessing.relatedMechanic}</p>}
        <p class="meta" style={{ "margin-top": "8px" }}>
          {formatDateRange(cycle.periodStart, cycle.periodEnd, props.lang)}
          {cycle.gameVersion ? ` · v${cycle.gameVersion}` : ""}
        </p>
      </section>

      {floor12 && <FloorMonsters floor={floor12} lang={props.lang} defaultOpen />}
    </Reveal>
  );
}
