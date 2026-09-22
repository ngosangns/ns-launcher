import { NavLink, useLocation } from "react-router-dom";
import { KeepAlive } from "../components/KeepAlive";
import { Segmented } from "../components/Segmented";
import { t, type Lang } from "../lib/i18n";
import { parseAbyssPath } from "../lib/paths";
import { CyclePage } from "./abyss/CyclePage";
import {
  ArtifactCatalog,
  ArtifactDetail,
  CharacterCatalog,
  CharacterDetail,
  WeaponCatalog,
  WeaponDetail,
} from "./abyss/CatalogPages";
import { ResonancePage } from "./abyss/ResonancePage";
import { PlannerPage } from "./abyss/PlannerPage";

export function AbyssLayout({ lang }: { lang: Lang }) {
  const copy = t(lang);
  const { pathname } = useLocation();
  const { section, id } = parseAbyssPath(pathname);
  const items = [
    { to: "/abyss/team", label: copy.abyssTeam, section: "team" },
    { to: "/abyss/cycle", label: copy.abyssCycle, section: "cycle" },
    { to: "/abyss/characters", label: copy.abyssCharacters, section: "characters" },
    { to: "/abyss/weapons", label: copy.abyssWeapons, section: "weapons" },
    { to: "/abyss/artifacts", label: copy.abyssArtifacts, section: "artifacts" },
    { to: "/abyss/resonance", label: copy.abyssResonance, section: "resonance" },
  ];
  return (
    <div className="hero abyss-shell">
      <Segmented nav className="abyss-nav tabs" label={copy.abyss}>
        {items.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            className={`tab ${section === item.section ? "active" : ""}`}
          >
            {item.label}
          </NavLink>
        ))}
      </Segmented>
      <div className="stage abyss-stage">
        <KeepAlive stage active={section === "team"}>
          <PlannerPage lang={lang} />
        </KeepAlive>
        <KeepAlive stage active={section === "cycle"}>
          <CyclePage lang={lang} />
        </KeepAlive>
        <KeepAlive stage active={section === "characters" && !id}>
          <CharacterCatalog lang={lang} />
        </KeepAlive>
        <KeepAlive stage active={section === "characters" && Boolean(id)}>
          <CharacterDetail lang={lang} id={id} />
        </KeepAlive>
        <KeepAlive stage active={section === "weapons" && !id}>
          <WeaponCatalog lang={lang} />
        </KeepAlive>
        <KeepAlive stage active={section === "weapons" && Boolean(id)}>
          <WeaponDetail lang={lang} id={id} />
        </KeepAlive>
        <KeepAlive stage active={section === "artifacts" && !id}>
          <ArtifactCatalog lang={lang} />
        </KeepAlive>
        <KeepAlive stage active={section === "artifacts" && Boolean(id)}>
          <ArtifactDetail lang={lang} id={id} />
        </KeepAlive>
        <KeepAlive stage active={section === "resonance"}>
          <ResonancePage lang={lang} />
        </KeepAlive>
      </div>
    </div>
  );
}
