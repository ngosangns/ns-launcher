import { For } from "solid-js";
import { currentCycle } from "../lib/abyss";
import { formatDateRange } from "../lib/format";
import { t, type Lang } from "../lib/i18n";
import { chaptersOf, documentHref, storyLibrary } from "../lib/story";

export function HomePage(props: { lang: Lang }) {
  const text = () => t(props.lang);
  const cycle = currentCycle();
  const blessing = cycle.blessingOfTheAbyssalMoon;
  const chapters = chaptersOf(storyLibrary);
  const blessingName = () => (props.lang === "vi" ? blessing.nameVI ?? blessing.name : blessing.name);

  return (
    <div class="ledger">
      <header class="ledger-mast">
        <h1>{text().brand}</h1>
      </header>
      <div class="ledger-spread">
        <section class="sheet" aria-labelledby="home-story">
          <h2 id="home-story">{text().story}</h2>
          <ol class="toc">
            <For each={chapters}>
              {(doc, index) => (
                <li>
                  <a href={documentHref(doc.id)}>
                    <span class="toc-index">{index() + 1}</span>
                    <span>{doc.title}</span>
                  </a>
                </li>
              )}
            </For>
          </ol>
        </section>
        <section class="sheet" aria-labelledby="home-abyss">
          <h2 id="home-abyss">{text().abyss}</h2>
          <dl class="record">
            <div>
              <dt>{text().currentCycle}</dt>
              <dd>{formatDateRange(cycle.periodStart, cycle.periodEnd, props.lang)}</dd>
            </div>
            <div>
              <dt>{text().abyssBlessing}</dt>
              <dd>{blessingName()}</dd>
            </div>
          </dl>
          <a class="btn btn-primary" href="/abyss/team">
            {text().abyssFindTeams}
          </a>
        </section>
      </div>
      <p class="copyright">{text().storyCopyright}</p>
    </div>
  );
}
