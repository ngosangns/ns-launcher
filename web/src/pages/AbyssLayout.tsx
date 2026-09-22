import { createMemo } from "solid-js";
import { KeepAlive } from "../components/KeepAlive";
import { Segmented } from "../components/Segmented";
import { t, type Lang } from "../lib/i18n";
import { parseAbyssPath } from "../lib/paths";
import { pathname } from "../router";
import { CyclePage } from "./abyss/CyclePage";
import { ArtifactCatalog, ArtifactDetail, CharacterDetail, WeaponDetail } from "./abyss/CatalogPages";
import { ResonancePage } from "./abyss/ResonancePage";
import { PlannerPage } from "./abyss/PlannerPage";

function isPlanner(section: string): boolean {
  return section === "characters" || section === "weapons" || section === "monsters" || section === "team";
}

export function AbyssLayout(props: { lang: Lang }) {
  const text = () => t(props.lang);
  const route = createMemo(() => parseAbyssPath(pathname()));
  const items = () => [
    { to: "/abyss/characters", label: text().abyssCharacters, section: "characters" },
    { to: "/abyss/weapons", label: text().abyssWeapons, section: "weapons" },
    { to: "/abyss/monsters", label: text().abyssMonsters, section: "monsters" },
    { to: "/abyss/team", label: text().abyssResults, section: "team" },
    { to: "/abyss/cycle", label: text().abyssCycle, section: "cycle" },
    { to: "/abyss/artifacts", label: text().abyssArtifacts, section: "artifacts" },
    { to: "/abyss/resonance", label: text().abyssResonance, section: "resonance" },
  ];
  const sectionId = (section: string) => (route().section === section ? route().id : undefined);
  return (
    <div class="hero abyss-shell">
      <Segmented nav class="abyss-nav tabs" label={text().abyss}>
        {items().map((item) => (
          <a href={item.to} class="tab" classList={{ active: route().section === item.section }}>
            {item.label}
          </a>
        ))}
      </Segmented>
      <div class="stage abyss-stage">
        <KeepAlive stage active={isPlanner(route().section) && !route().id}>
          <PlannerPage lang={props.lang} section={route().section} />
        </KeepAlive>
        <KeepAlive stage active={route().section === "cycle"}>
          <CyclePage lang={props.lang} />
        </KeepAlive>
        <KeepAlive stage active={route().section === "characters" && Boolean(route().id)}>
          <CharacterDetail lang={props.lang} id={sectionId("characters")} />
        </KeepAlive>
        <KeepAlive stage active={route().section === "weapons" && Boolean(route().id)}>
          <WeaponDetail lang={props.lang} id={sectionId("weapons")} />
        </KeepAlive>
        <KeepAlive stage active={route().section === "artifacts" && !route().id}>
          <ArtifactCatalog lang={props.lang} />
        </KeepAlive>
        <KeepAlive stage active={route().section === "artifacts" && Boolean(route().id)}>
          <ArtifactDetail lang={props.lang} id={sectionId("artifacts")} />
        </KeepAlive>
        <KeepAlive stage active={route().section === "resonance"}>
          <ResonancePage lang={props.lang} />
        </KeepAlive>
      </div>
    </div>
  );
}
