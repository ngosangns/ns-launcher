import { useState } from "react";
import { Navigate, NavLink, Route, Routes } from "react-router-dom";
import { HomePage } from "./pages/HomePage";
import { StoryPage } from "./pages/StoryPage";
import { AbyssLayout } from "./pages/AbyssLayout";
import { CyclePage } from "./pages/abyss/CyclePage";
import {
  ArtifactCatalog,
  ArtifactDetail,
  CharacterCatalog,
  CharacterDetail,
  WeaponCatalog,
  WeaponDetail,
} from "./pages/abyss/CatalogPages";
import { ResonancePage } from "./pages/abyss/ResonancePage";
import { PlannerPage } from "./pages/abyss/PlannerPage";
import { BookIcon, HomeIcon, ShieldIcon, SparkleIcon } from "./lib/icons";
import { readLang, t, writeLang, type Lang } from "./lib/i18n";

export function App() {
  const [lang, setLang] = useState<Lang>(readLang);

  const switchLang = (next: Lang) => {
    setLang(next);
    writeLang(next);
    document.documentElement.lang = next === "vi" ? "vi" : "en";
  };

  const copy = t(lang);

  return (
    <div className="app-shell">
      <div className="backdrop" aria-hidden />
      <header className="topbar">
        <NavLink to="/" className="mark" aria-label={copy.home}>
          <SparkleIcon size={18} />
        </NavLink>
        <NavLink to="/" className="brand">
          {copy.brand}
        </NavLink>
        <nav className="tabs">
          <NavLink to="/" end className={({ isActive }) => `tab ${isActive ? "active" : ""}`}>
            <HomeIcon />
            <span className="label">{copy.home}</span>
          </NavLink>
          <NavLink to="/story" className={({ isActive }) => `tab ${isActive ? "active" : ""}`}>
            <BookIcon />
            <span className="label">{copy.story}</span>
          </NavLink>
          <NavLink to="/abyss" className={({ isActive }) => `tab ${isActive ? "active" : ""}`}>
            <ShieldIcon />
            <span className="label">{copy.abyss}</span>
          </NavLink>
        </nav>
        <span className="spacer" />
        <div className="lang-switch" role="group" aria-label="Language">
          <button type="button" className={lang === "vi" ? "active" : ""} onClick={() => switchLang("vi")}>
            VI
          </button>
          <button type="button" className={lang === "en" ? "active" : ""} onClick={() => switchLang("en")}>
            EN
          </button>
        </div>
      </header>
      <main className="page">
        <Routes>
          <Route path="/" element={<HomePage lang={lang} />} />
          <Route path="/story" element={<StoryPage lang={lang} />} />
          <Route path="/story/d/:docId" element={<StoryPage lang={lang} />} />
          <Route path="/story/d/:docId/:sectionId" element={<StoryPage lang={lang} />} />
          <Route path="/story/e/:entityId" element={<StoryPage lang={lang} />} />
          <Route path="/abyss" element={<AbyssLayout lang={lang} />}>
            <Route index element={<Navigate to="team" replace />} />
            <Route path="cycle" element={<CyclePage lang={lang} />} />
            <Route path="characters" element={<CharacterCatalog lang={lang} />} />
            <Route path="characters/:id" element={<CharacterDetail lang={lang} />} />
            <Route path="weapons" element={<WeaponCatalog lang={lang} />} />
            <Route path="weapons/:id" element={<WeaponDetail lang={lang} />} />
            <Route path="artifacts" element={<ArtifactCatalog lang={lang} />} />
            <Route path="artifacts/:id" element={<ArtifactDetail lang={lang} />} />
            <Route path="resonance" element={<ResonancePage lang={lang} />} />
            <Route path="team" element={<PlannerPage lang={lang} />} />
          </Route>
        </Routes>
      </main>
    </div>
  );
}
