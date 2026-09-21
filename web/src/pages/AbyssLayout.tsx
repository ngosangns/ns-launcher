import { NavLink, Outlet } from "react-router-dom";
import { t, type Lang } from "../lib/i18n";

export function AbyssLayout({ lang }: { lang: Lang }) {
  const copy = t(lang);
  const items = [
    { to: "/abyss/team", label: copy.abyssTeam },
    { to: "/abyss/cycle", label: copy.abyssCycle },
    { to: "/abyss/characters", label: copy.abyssCharacters },
    { to: "/abyss/weapons", label: copy.abyssWeapons },
    { to: "/abyss/artifacts", label: copy.abyssArtifacts },
    { to: "/abyss/resonance", label: copy.abyssResonance },
  ];
  return (
    <div className="hero" style={{ maxWidth: 1200 }}>
      <nav className="abyss-nav tabs" aria-label={copy.abyss}>
        {items.map((item) => (
          <NavLink key={item.to} to={item.to} className={({ isActive }) => `tab ${isActive ? "active" : ""}`}>
            {item.label}
          </NavLink>
        ))}
      </nav>
      <Outlet />
    </div>
  );
}
