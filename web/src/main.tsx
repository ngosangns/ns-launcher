import { render } from "solid-js/web";
import { App } from "./App";
import { readLang } from "./lib/i18n";
import { startRouter } from "./router";
import "./styles.css";

document.documentElement.lang = readLang() === "en" ? "en" : "vi";
startRouter();

const root = document.getElementById("root");
if (root) render(() => <App />, root);
