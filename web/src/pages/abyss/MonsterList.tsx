import { createSignal, Show } from "solid-js";
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

function ResistanceTable(props: { monster: Monster }) {
  const cells = RES_ORDER.map((key) => ({ key, value: resistanceValue(props.monster, key) }));
  if (cells.every((cell) => cell.value == null)) return null;
  return (
    <div class="res-table">
      {cells.map((cell) => {
        const value = cell.value ?? 0.1;
        const known = cell.value != null;
        return (
          <span
            class={`res-cell ${!known ? "unknown" : value < 0 ? "weak" : value > 0.15 ? "strong" : ""}`}
            title={cell.key}
          >
            <span class="element" data-el={cell.key} aria-label={cell.key}>
              <ElementBadge element={cell.key} size={16} />
            </span>
            {known ? formatPercent(value, value % 0.01 === 0 ? 0 : 0) : "—"}
          </span>
        );
      })}
    </div>
  );
}

function Stat(props: { label: string; value: string }) {
  return (
    <div class="monster-stat">
      <span class="monster-stat-label">{props.label}</span>
      <span>{props.value}</span>
    </div>
  );
}

export function MonsterCard(props: { monster: Monster; level: number; multiplier: number; lang: Lang }) {
  const text = () => t(props.lang);
  const hp = () => monsterHPBreakdown(props.monster, props.level, props.multiplier);
  const icon = () => monsterIconId(props.monster);
  return (
    <div class="monster-card">
      <Portrait kind="monsters" id={icon()} alt={props.monster.name} large />
      <div class="monster-body">
        <div class="monster-top">
          <strong>
            {props.lang === "vi" ? props.monster.nameVI ?? props.monster.name : props.monster.name}
          </strong>
          <span class="meta">
            {props.monster.elements.map((element) => (
              <ElementBadge element={element} />
            ))}
          </span>
        </div>
        <div class="monster-stats">
          <Stat label={text().abyssCount} value={props.lang === "en" ? props.monster.countEN ?? props.monster.count : props.monster.count} />
          <Show when={props.monster.spawns != null}>
            <Stat label={text().abyssSpawns} value={String(props.monster.spawns ?? "")} />
          </Show>
          <Show when={props.lang === "en" ? props.monster.sizeEN ?? props.monster.size : props.monster.size}>
            <Stat label={text().abyssSize} value={(props.lang === "en" ? props.monster.sizeEN ?? props.monster.size : props.monster.size) ?? ""} />
          </Show>
          <Stat label={text().abyssLevel} value={String(props.level)} />
          <Show when={hp()}>
            {(row) => (
              <>
                <Stat label={text().abyssHPEach} value={formatHP(row().perSpawn)} />
                <Stat label={text().abyssHPTotal} value={formatHP(row().total)} />
                <Stat label={text().abyssHPRatio} value={`${row().ratio} × type ${row().type} ×${props.multiplier}`} />
              </>
            )}
          </Show>
          <Show when={props.monster.hp?.variant}>
            <Stat label={text().abyssVariant} value={props.monster.hp?.variant ?? ""} />
          </Show>
          <Show when={props.monster.weakpoint != null}>
            <Stat
              label={text().abyssWeakpoint}
              value={props.monster.weakpoint ? (props.lang === "vi" ? "Có" : "Yes") : props.lang === "vi" ? "Không" : "No"}
            />
          </Show>
        </div>
        <ResistanceTable monster={props.monster} />
        <Show when={(props.lang === "en" ? props.monster.mechanicsEN ?? props.monster.mechanics : props.monster.mechanics) && (props.lang === "en" ? props.monster.mechanicsEN ?? props.monster.mechanics : props.monster.mechanics) !== "chưa xác nhận"}>
          <p class="meta" style={{ margin: "6px 0 0" }}>
            {text().abyssMechanics}: {props.lang === "en" ? props.monster.mechanicsEN ?? props.monster.mechanics : props.monster.mechanics}
          </p>
        </Show>
        <Show when={props.lang === "en" ? props.monster.resistanceNotesEN ?? props.monster.resistanceNotes : props.monster.resistanceNotes}>
          <p class="meta">{props.lang === "en" ? props.monster.resistanceNotesEN ?? props.monster.resistanceNotes : props.monster.resistanceNotes}</p>
        </Show>
        <Show when={props.monster.hpRatio && props.monster.hpRatio !== "chưa xác nhận"}>
          <p class="meta">{props.monster.hpRatio}</p>
        </Show>
      </div>
    </div>
  );
}

export function FloorMonsters(props: { floor: CycleFloor; lang: Lang; defaultOpen?: boolean }) {
  const text = () => t(props.lang);
  const disorder = () => (props.lang === "en" ? props.floor.leyLineDisorderEN ?? props.floor.leyLineDisorder : props.floor.leyLineDisorder);
  const split = () => splitDisorder(disorder());
  const multiplier = () => props.floor.enemyHPMultiplier ?? 1;
  const [opened, setOpened] = createSignal(props.defaultOpen !== false);
  return (
    <details
      class="panel floor"
      classList={{ open: opened() }}
      open={opened()}
      on:toggle={(event) => {
        const node = event.currentTarget;
        if (node instanceof HTMLDetailsElement && node.open !== opened()) setOpened(node.open);
      }}
    >
      <summary class="floor-head">
        <strong>
          {props.lang === "vi" ? "Tầng" : "Floor"} {props.floor.floor}
        </strong>
        <span class="meta">
          ×{multiplier()} HP · {monsterCount(props.floor)} {text().abyssMonsters.toLowerCase()}
        </span>
      </summary>
      <div class="fold">
        <div class="fold-inner">
          <div class="section-title">{text().abyssLeyLine}</div>
          <Show
            when={split().half1 || split().half2}
            fallback={<p class="prose">{disorder()}</p>}
          >
            <Show when={split().half1}>
              <p class="prose">
                <strong>{text().abyssHalf1}.</strong> {split().half1}
              </p>
            </Show>
            <Show when={split().half2}>
              <p class="prose">
                <strong>{text().abyssHalf2}.</strong> {split().half2}
              </p>
            </Show>
          </Show>
          {props.floor.chambers.map((chamber) => (
            <div>
              <div class="section-title">
                {text().abyssChamber} {chamber.chamber} · {text().abyssLevel} {chamber.monsterLevel}
              </div>
              {chamber.waves.map((wave) => (
                <div>
                  <div class="wave-label">
                    {wave.wave === 1 ? text().abyssHalf1 : wave.wave === 2 ? text().abyssHalf2 : `${text().abyssWave} ${wave.wave}`}
                  </div>
                  {wave.monsters.map((monster) => (
                    <MonsterCard monster={monster} level={chamber.monsterLevel} multiplier={multiplier()} lang={props.lang} />
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


