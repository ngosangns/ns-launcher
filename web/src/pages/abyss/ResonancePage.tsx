import { For, Show } from "solid-js";
import { charactersWithTag, damageFormula, teamBonus } from "../../lib/abyss";
import { t, type Lang } from "../../lib/i18n";
import { MathBlock } from "../../components/MathBlock";
import { ElementBadge } from "../../components/ui";
import { formulaTex } from "./formulaTex";

function CoeffTable(props: { values: Record<string, number> }) {
  return (
    <div class="md-table-wrap">
      <table class="md-table">
        <tbody>
          <For each={Object.entries(props.values)}>
            {([key, value]) => (
              <tr>
                <td>{key}</td>
                <td>{value}</td>
              </tr>
            )}
          </For>
        </tbody>
      </table>
    </div>
  );
}

function TaggedList(props: { tag: string; lang: Lang }) {
  const text = () => t(props.lang);
  const list = () => charactersWithTag(props.tag);
  return (
    <Show when={list().length > 0}>
      <p class="prose">
        <strong>
          {text().taggedCharacters} ({list().length}):
        </strong>{" "}
        <For each={list()}>
          {(character, index) => (
            <span>
              {index() > 0 ? ", " : ""}
              <a href={`/abyss/characters/${character.id}`}>
                {props.lang === "vi" ? character.nameVI ?? character.name : character.name}
              </a>
            </span>
          )}
        </For>
      </p>
    </Show>
  );
}

export function ResonancePage(props: { lang: Lang }) {
  const text = () => t(props.lang);
  const df = damageFormula;
  return (
    <>
      <section class="panel" style={{ "margin-bottom": "16px" }}>
        <h2 style={{ "margin-top": "0" }}>{text().abyssResonance}</h2>
        <For each={teamBonus.elementalResonance}>
          {(item) => (
            <div class="constellation">
              <div />
              <div>
                <strong>{props.lang === "vi" ? item.nameVI ?? item.name : item.name}</strong>
                <div class="meta" style={{ margin: "4px 0" }}>
                  <For each={item.elements}>{(element) => <ElementBadge element={element} />}</For>
                  {item.requiresUniqueElements
                    ? ` · ${item.requiredCount} unique`
                    : item.elements.length > 0
                      ? ` ×${item.requiredCount}`
                      : ""}
                </div>
                <p class="prose">{item.description}</p>
              </div>
            </div>
          )}
        </For>
      </section>

      <section class="panel" style={{ "margin-bottom": "16px" }}>
        <h2 style={{ "margin-top": "0" }}>Moonsign / Nguyệt Triệu</h2>
        {teamBonus.moonsign.note && <p class="meta">{teamBonus.moonsign.note}</p>}
        <For each={teamBonus.moonsign.levels}>
          {(level) => (
            <p class="prose">
              <strong>
                {level.name} ({level.requiredCount}+).
              </strong>{" "}
              {level.description}
            </p>
          )}
        </For>
        <TaggedList tag="moonsign" lang={props.lang} />
        <Show when={teamBonus.moonsign.lunarReactionDmgBonusByElement}>
          <div class="section-title">{text().lunarBonus}</div>
          <div class="md-table-wrap">
            <table class="md-table">
              <thead>
                <tr>
                  <th>Elements</th>
                  <th>Stat</th>
                  <th>Rate</th>
                </tr>
              </thead>
              <tbody>
                <For each={teamBonus.moonsign.lunarReactionDmgBonusByElement ?? []}>
                  {(row) => (
                    <tr>
                      <td class="element-list">
                        <For each={row.elements}>{(element) => <ElementBadge element={element} />}</For>
                      </td>
                      <td>{row.statBasis}</td>
                      <td>{row.note ?? row.ratePer100OrPer1000}</td>
                    </tr>
                  )}
                </For>
              </tbody>
            </table>
          </div>
        </Show>
        <Show when={teamBonus.moonsign.maxBuffThresholds}>
          <div class="section-title">{text().lunarCap}</div>
          <div class="md-table-wrap">
            <table class="md-table">
              <thead>
                <tr>
                  <th>Elements</th>
                  <th>Stat</th>
                  <th>Cap</th>
                </tr>
              </thead>
              <tbody>
                <For each={teamBonus.moonsign.maxBuffThresholds ?? []}>
                  {(row) => (
                    <tr>
                      <td class="element-list">
                        <For each={row.elements}>{(element) => <ElementBadge element={element} />}</For>
                      </td>
                      <td>{row.statBasis}</td>
                      <td>{row.thresholdValue}</td>
                    </tr>
                  )}
                </For>
              </tbody>
            </table>
          </div>
        </Show>
      </section>

      <section class="panel" style={{ "margin-bottom": "16px" }}>
        <h2 style={{ "margin-top": "0" }}>Hexerei</h2>
        <p class="prose">{teamBonus.hexerei.description}</p>
        {teamBonus.hexerei.requirement && <p class="meta">{teamBonus.hexerei.requirement}</p>}
        <TaggedList tag="hexerei" lang={props.lang} />
      </section>

      <section class="panel" style={{ "margin-bottom": "16px" }}>
        <h2 style={{ "margin-top": "0" }}>Stellar Jubilee</h2>
        <TaggedList tag="stellar-jubilee" lang={props.lang} />
      </section>

      <section class="panel" style={{ "margin-bottom": "16px" }}>
        <h2 style={{ "margin-top": "0" }}>Nightsoul Burst</h2>
        <p class="prose">{teamBonus.nightsoulBurst.description}</p>
        <ul class="bullet-list">
          <For each={teamBonus.nightsoulBurst.intervalsByCount}>
            {(row) => (
              <li>
                <span>
                  {row.natlanCharacterCount} Natlan · {row.intervalSeconds}s
                </span>
              </li>
            )}
          </For>
        </ul>
        {teamBonus.nightsoulBurst.exclusionNote && <p class="meta">{teamBonus.nightsoulBurst.exclusionNote}</p>}
      </section>

      <section class="panel">
        <h2 style={{ "margin-top": "0" }}>{text().formulaTitle}</h2>
        <p class="formula-label">RES</p>
        <MathBlock tex={formulaTex.res} />
        <ul class="formula-cases">
          <For each={formulaTex.resCases}>
            {(row) => (
              <li>
                <MathBlock tex={row.condition} display={false} />
                <MathBlock tex={row.formula} display={false} />
              </li>
            )}
          </For>
        </ul>
        {df.resMultiplier.note && <p class="meta">{df.resMultiplier.note}</p>}
        <p class="formula-label">DEF</p>
        <MathBlock tex={formulaTex.def} />
        <MathBlock tex={formulaTex.defK} />
        <Show when={df.elevationMultiplier}>
          <p class="formula-label">Elevation</p>
          <MathBlock tex={formulaTex.elevation} />
          <p class="meta">{df.elevationMultiplier?.note}</p>
        </Show>
        <p class="formula-label">CRIT</p>
        <MathBlock tex={formulaTex.crit} />
        <MathBlock tex={formulaTex.critExpected} />
        <Show when={df.critValueHeuristic}>
          <p class="formula-label">Crit Value</p>
          <MathBlock tex={formulaTex.critValue} />
          <p class="meta">{df.critValueHeuristic?.targetRatio}</p>
        </Show>
        <p class="formula-label">Amplifying</p>
        <MathBlock tex={formulaTex.amplifying} />
        <MathBlock tex={formulaTex.amplifyingDmg} />
        <MathBlock tex={formulaTex.amplifyingEm} />
        {df.amplifying.note && <p class="meta">{df.amplifying.note}</p>}
        <CoeffTable values={df.amplifying.coefficients} />
        <Show when={df.catalyze}>
          <p class="formula-label">Catalyze</p>
          <MathBlock tex={formulaTex.catalyze} />
          <p class="meta">{formulaTex.catalyzeNote}</p>
          <MathBlock tex={formulaTex.catalyzeEm} />
          <CoeffTable values={df.catalyze?.coefficients ?? {}} />
        </Show>
        <Show when={df.transformative}>
          <p class="formula-label">Transformative</p>
          <MathBlock tex={formulaTex.transformative} />
          <MathBlock tex={formulaTex.transformativeEm} />
          {df.transformative?.note && <p class="meta">{df.transformative.note}</p>}
          <Show when={df.transformative?.coefficients}>
            <CoeffTable values={df.transformative?.coefficients ?? {}} />
          </Show>
        </Show>
        <Show when={df.lunarStellar}>
          <p class="formula-label">Lunar / Stellar</p>
          <MathBlock tex={formulaTex.lunarEm} />
          {df.lunarStellar?.note && <p class="meta">{df.lunarStellar.note}</p>}
          <Show when={df.lunarStellar?.direct}>
            <p class="formula-label">Direct · {df.lunarStellar?.direct?.appliesTo.join(", ")}</p>
            <MathBlock tex={formulaTex.direct} />
            {df.lunarStellar?.direct?.note && <p class="meta">{df.lunarStellar.direct.note}</p>}
            <CoeffTable values={df.lunarStellar?.direct?.coefficients ?? {}} />
          </Show>
          <Show when={df.lunarStellar?.indirect}>
            <p class="formula-label">Indirect · {df.lunarStellar?.indirect?.appliesTo.join(", ")}</p>
            <MathBlock tex={formulaTex.indirect} />
            <MathBlock tex={formulaTex.aggregation} />
            <p class="meta">{formulaTex.aggregationNote}</p>
            <CoeffTable values={df.lunarStellar?.indirect?.coefficients ?? {}} />
          </Show>
        </Show>
        <Show when={df.trueDamage}>
          <p class="formula-label">True DMG</p>
          <p class="prose">{df.trueDamage?.note}</p>
        </Show>
        <Show when={df.workedExample}>
          <div class="section-title">Worked example</div>
          <p class="prose">{df.workedExample?.scenario}</p>
          <ul class="formula-cases">
            <For each={Object.entries(df.workedExample?.steps ?? {})}>
              {([key, value]) => (
                <li>
                  <span class="meta">{key}</span>
                  <MathBlock tex={formulaTex.steps[key] ?? value} />
                </li>
              )}
            </For>
          </ul>
          <p class="prose">
            <strong>
              {df.workedExample?.result.value} {df.workedExample?.result.unit}
            </strong>
          </p>
        </Show>
      </section>
    </>
  );
}
