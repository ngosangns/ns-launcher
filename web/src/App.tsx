import { createEffect, createSignal } from "solid-js";
import { KeepAlive } from "./components/KeepAlive";
import { Segmented } from "./components/Segmented";
import { HomePage } from "./pages/HomePage";
import { StoryPage } from "./pages/StoryPage";
import { AbyssLayout } from "./pages/AbyssLayout";
import { BookIcon, HomeIcon, ShieldIcon } from "./lib/icons";
import { readLang, t, writeLang, type Lang } from "./lib/i18n";
import { topTab } from "./lib/paths";
import { hash, navigate, pathname, search } from "./router";

export function App() {
  const [lang, setLang] = createSignal<Lang>(readLang());
  const [last, setLast] = createSignal({ home: "/", story: "/story", abyss: "/abyss/characters" });
  const tab = () => topTab(pathname());
  const text = () => t(lang());

  createEffect(() => {
    const path = pathname();
    if (path === "/abyss" || path === "/abyss/") {
      navigate("/abyss/characters", { replace: true });
      return;
    }
    const full = `${path}${search()}${hash()}`;
    const current = topTab(path);
    setLast((prev) => {
      if (current === "story") return { ...prev, story: full };
      if (current === "abyss") return { ...prev, abyss: full };
      return { ...prev, home: full };
    });
  });

  const switchLang = (next: Lang) => {
    setLang(next);
    writeLang(next);
    document.documentElement.lang = next === "vi" ? "vi" : "en";
  };

  return (
    <div class="app-shell">
      <header class="topbar">
        <a href="/" class="brand">
          <img class="brand-logo" src="/icons/brand/genshin-logo.png" alt="" />
          {text().brand}
        </a>
        <Segmented nav class="tabs" label={text().brand}>
          <a href="/" class="tab" classList={{ active: tab() === "home" }} aria-current={tab() === "home" ? "page" : undefined}>
            <HomeIcon />
            <span class="label">{text().home}</span>
          </a>
          <a href={last().story} class="tab" classList={{ active: tab() === "story" }}>
            <BookIcon />
            <span class="label">{text().story}</span>
          </a>
          <a href={last().abyss} class="tab" classList={{ active: tab() === "abyss" }}>
            <ShieldIcon />
            <span class="label">{text().abyss}</span>
          </a>
        </Segmented>
        <span class="spacer" />
        <Segmented class="lang-switch" label="Language">
          <button type="button" classList={{ active: lang() === "vi" }} onClick={() => switchLang("vi")}>
            VI
          </button>
          <button type="button" classList={{ active: lang() === "en" }} onClick={() => switchLang("en")}>
            EN
          </button>
        </Segmented>
      </header>
      <main class="page">
        <div class="stage">
          <KeepAlive stage active={tab() === "home"}>
            <HomePage lang={lang()} />
          </KeepAlive>
          <KeepAlive stage active={tab() === "story"}>
            <StoryPage lang={lang()} active={tab() === "story"} />
          </KeepAlive>
          <KeepAlive stage active={tab() === "abyss"} class="keep-alive-fill">
            <AbyssLayout lang={lang()} />
          </KeepAlive>
        </div>
      </main>
    </div>
  );
}
