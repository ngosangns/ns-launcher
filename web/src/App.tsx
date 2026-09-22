import { useEffect, useState } from "react";
import { NavLink, useLocation, useNavigate } from "react-router-dom";
import { KeepAlive } from "./components/KeepAlive";
import { Segmented } from "./components/Segmented";
import { HomePage } from "./pages/HomePage";
import { StoryPage } from "./pages/StoryPage";
import { AbyssLayout } from "./pages/AbyssLayout";
import { BookIcon, HomeIcon, ShieldIcon, SparkleIcon } from "./lib/icons";
import { readLang, t, writeLang, type Lang } from "./lib/i18n";
import { topTab } from "./lib/paths";

export function App() {
  const [lang, setLang] = useState<Lang>(readLang);
  const location = useLocation();
  const navigate = useNavigate();
  const tab = topTab(location.pathname);
  const [last, setLast] = useState({ home: "/", story: "/story", abyss: "/abyss/team" });

  useEffect(() => {
    const path = `${location.pathname}${location.search}${location.hash}`;
    if (location.pathname === "/abyss" || location.pathname === "/abyss/") {
      navigate("/abyss/team", { replace: true });
      return;
    }
    setLast((current) => {
      if (tab === "story") return { ...current, story: path };
      if (tab === "abyss") return { ...current, abyss: path };
      return { ...current, home: path };
    });
  }, [location.hash, location.pathname, location.search, navigate, tab]);

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
        <Segmented nav className="tabs" label={copy.brand}>
          <NavLink to="/" end className={({ isActive }) => `tab ${isActive ? "active" : ""}`}>
            <HomeIcon />
            <span className="label">{copy.home}</span>
          </NavLink>
          <NavLink to={last.story} className={`tab ${tab === "story" ? "active" : ""}`}>
            <BookIcon />
            <span className="label">{copy.story}</span>
          </NavLink>
          <NavLink to={last.abyss} className={`tab ${tab === "abyss" ? "active" : ""}`}>
            <ShieldIcon />
            <span className="label">{copy.abyss}</span>
          </NavLink>
        </Segmented>
        <span className="spacer" />
        <Segmented className="lang-switch" label="Language">
          <button type="button" className={lang === "vi" ? "active" : ""} onClick={() => switchLang("vi")}>
            VI
          </button>
          <button type="button" className={lang === "en" ? "active" : ""} onClick={() => switchLang("en")}>
            EN
          </button>
        </Segmented>
      </header>
      <main className="page">
        <div className="stage">
          <KeepAlive stage active={tab === "home"}>
            <HomePage lang={lang} />
          </KeepAlive>
          <KeepAlive stage active={tab === "story"}>
            <StoryPage lang={lang} active={tab === "story"} />
          </KeepAlive>
          <KeepAlive stage active={tab === "abyss"} className="keep-alive-fill">
            <AbyssLayout lang={lang} />
          </KeepAlive>
        </div>
      </main>
    </div>
  );
}
