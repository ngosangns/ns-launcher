import { Link } from "react-router-dom";
import { charactersWithTag, damageFormula, teamBonus } from "../../lib/abyss";
import { t, type Lang } from "../../lib/i18n";
import { ElementBadge } from "../../components/ui";

function CoeffTable({ values }: { values: Record<string, number> }) {
  return (
    <div className="md-table-wrap">
      <table className="md-table">
        <tbody>
          {Object.entries(values).map(([key, value]) => (
            <tr key={key}>
              <td>{key}</td>
              <td>{value}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function TaggedList({ tag, lang }: { tag: string; lang: Lang }) {
  const copy = t(lang);
  const list = charactersWithTag(tag);
  if (list.length === 0) return null;
  return (
    <p className="prose">
      <strong>
        {copy.taggedCharacters} ({list.length}):
      </strong>{" "}
      {list.map((character, index) => (
        <span key={character.id}>
          {index > 0 ? ", " : ""}
          <Link to={`/abyss/characters/${character.id}`}>
            {lang === "vi" ? character.nameVI ?? character.name : character.name}
          </Link>
        </span>
      ))}
    </p>
  );
}

export function ResonancePage({ lang }: { lang: Lang }) {
  const copy = t(lang);
  const df = damageFormula;
  return (
    <>
      <section className="panel" style={{ marginBottom: 16 }}>
        <h2 style={{ marginTop: 0 }}>{copy.abyssResonance}</h2>
        {teamBonus.elementalResonance.map((item) => (
          <div key={item.id} className="constellation">
            <div />
            <div>
              <strong>{lang === "vi" ? item.nameVI ?? item.name : item.name}</strong>
              <div className="meta" style={{ margin: "4px 0" }}>
                {item.elements.map((element) => (
                  <ElementBadge key={element} element={element} />
                ))}
                {item.requiresUniqueElements
                  ? ` · ${item.requiredCount} unique`
                  : item.elements.length > 0
                    ? ` ×${item.requiredCount}`
                    : ""}
              </div>
              <p className="prose">{item.description}</p>
            </div>
          </div>
        ))}
      </section>

      <section className="panel" style={{ marginBottom: 16 }}>
        <h2 style={{ marginTop: 0 }}>Moonsign / Nguyệt Triệu</h2>
        {teamBonus.moonsign.note && <p className="meta">{teamBonus.moonsign.note}</p>}
        {teamBonus.moonsign.levels.map((level) => (
          <p key={level.name} className="prose">
            <strong>
              {level.name} ({level.requiredCount}+).
            </strong>{" "}
            {level.description}
          </p>
        ))}
        <TaggedList tag="moonsign" lang={lang} />
        {teamBonus.moonsign.lunarReactionDmgBonusByElement && (
          <>
            <div className="section-title">{copy.lunarBonus}</div>
            <div className="md-table-wrap">
              <table className="md-table">
                <thead>
                  <tr>
                    <th>Elements</th>
                    <th>Stat</th>
                    <th>Rate</th>
                  </tr>
                </thead>
                <tbody>
                  {teamBonus.moonsign.lunarReactionDmgBonusByElement.map((row) => (
                    <tr key={row.elements.join(",")}>
                      <td>{row.elements.join(", ")}</td>
                      <td>{row.statBasis}</td>
                      <td>{row.note ?? row.ratePer100OrPer1000}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </>
        )}
        {teamBonus.moonsign.maxBuffThresholds && (
          <>
            <div className="section-title">{copy.lunarCap}</div>
            <div className="md-table-wrap">
              <table className="md-table">
                <thead>
                  <tr>
                    <th>Elements</th>
                    <th>Stat</th>
                    <th>Cap</th>
                  </tr>
                </thead>
                <tbody>
                  {teamBonus.moonsign.maxBuffThresholds.map((row) => (
                    <tr key={row.elements.join(",")}>
                      <td>{row.elements.join(", ")}</td>
                      <td>{row.statBasis}</td>
                      <td>{row.thresholdValue}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </>
        )}
      </section>

      <section className="panel" style={{ marginBottom: 16 }}>
        <h2 style={{ marginTop: 0 }}>Hexerei</h2>
        <p className="prose">{teamBonus.hexerei.description}</p>
        {teamBonus.hexerei.requirement && <p className="meta">{teamBonus.hexerei.requirement}</p>}
        <TaggedList tag="hexerei" lang={lang} />
      </section>

      <section className="panel" style={{ marginBottom: 16 }}>
        <h2 style={{ marginTop: 0 }}>Stellar Jubilee</h2>
        <TaggedList tag="stellar-jubilee" lang={lang} />
      </section>

      <section className="panel" style={{ marginBottom: 16 }}>
        <h2 style={{ marginTop: 0 }}>Nightsoul Burst</h2>
        <p className="prose">{teamBonus.nightsoulBurst.description}</p>
        <ul className="bullet-list">
          {teamBonus.nightsoulBurst.intervalsByCount.map((row) => (
            <li key={row.natlanCharacterCount}>
              <span>
                {row.natlanCharacterCount} Natlan · {row.intervalSeconds}s
              </span>
            </li>
          ))}
        </ul>
        {teamBonus.nightsoulBurst.exclusionNote && (
          <p className="meta">{teamBonus.nightsoulBurst.exclusionNote}</p>
        )}
      </section>

      <section className="panel">
        <h2 style={{ marginTop: 0 }}>{copy.formulaTitle}</h2>
        <p className="prose">
          <strong>RES.</strong> {df.resMultiplier.formula}
        </p>
        <ul className="bullet-list">
          {df.resMultiplier.breakpoints.map((row) => (
            <li key={row.condition}>
              <span>
                {row.condition}: {row.formula}
              </span>
            </li>
          ))}
        </ul>
        {df.resMultiplier.note && <p className="meta">{df.resMultiplier.note}</p>}
        <p className="prose">
          <strong>DEF.</strong> {df.defMultiplier.formula}
        </p>
        {df.elevationMultiplier && (
          <p className="prose">
            <strong>Elevation.</strong> {df.elevationMultiplier.formula} {df.elevationMultiplier.note}
          </p>
        )}
        <p className="prose">
          <strong>CRIT.</strong> {df.critMultiplier.critFormula ?? ""} EV:{" "}
          {df.critMultiplier.expectedValueFormula}
        </p>
        {df.critValueHeuristic && (
          <p className="prose">
            <strong>Crit Value.</strong> {df.critValueHeuristic.formula} ({df.critValueHeuristic.targetRatio})
          </p>
        )}
        <p className="prose">
          <strong>Amplifying.</strong> {df.amplifying.formula} EM: {df.amplifying.emBonusFormula}
        </p>
        {df.amplifying.note && <p className="meta">{df.amplifying.note}</p>}
        <CoeffTable values={df.amplifying.coefficients} />
        {df.catalyze && (
          <>
            <p className="prose">
              <strong>Catalyze.</strong> {df.catalyze.formula} EM: {df.catalyze.emBonusFormula}
            </p>
            <CoeffTable values={df.catalyze.coefficients} />
          </>
        )}
        {df.transformative && (
          <>
            <p className="prose">
              <strong>Transformative.</strong> {df.transformative.formula} EM:{" "}
              {df.transformative.emBonusFormula}
            </p>
            {df.transformative.note && <p className="meta">{df.transformative.note}</p>}
            {df.transformative.coefficients && <CoeffTable values={df.transformative.coefficients} />}
          </>
        )}
        {df.lunarStellar && (
          <>
            <p className="prose">
              <strong>Lunar / Stellar.</strong> EM: {df.lunarStellar.emBonusFormula}
            </p>
            {df.lunarStellar.note && <p className="meta">{df.lunarStellar.note}</p>}
            {df.lunarStellar.direct && (
              <p className="prose">
                <strong>Direct ({df.lunarStellar.direct.appliesTo.join(", ")}).</strong>{" "}
                {df.lunarStellar.direct.formula}
              </p>
            )}
            {df.lunarStellar.direct && <CoeffTable values={df.lunarStellar.direct.coefficients} />}
            {df.lunarStellar.indirect && (
              <p className="prose">
                <strong>Indirect ({df.lunarStellar.indirect.appliesTo.join(", ")}).</strong>{" "}
                {df.lunarStellar.indirect.perCharacterFormula} {df.lunarStellar.indirect.aggregationFormula}
              </p>
            )}
            {df.lunarStellar.indirect && <CoeffTable values={df.lunarStellar.indirect.coefficients} />}
          </>
        )}
        {df.trueDamage && (
          <p className="prose">
            <strong>True DMG.</strong> {df.trueDamage.note}
          </p>
        )}
        {df.workedExample && (
          <>
            <div className="section-title">Worked example</div>
            <p className="prose">{df.workedExample.scenario}</p>
            <ul className="bullet-list">
              {Object.entries(df.workedExample.steps).map(([key, value]) => (
                <li key={key}>
                  <span>
                    {key}: {value}
                  </span>
                </li>
              ))}
            </ul>
            <p className="prose">
              <strong>
                {df.workedExample.result.value} {df.workedExample.result.unit}
              </strong>
            </p>
          </>
        )}
      </section>
    </>
  );
}
