import { createSignal } from "solid-js";

export type LocationState = {
  pathname: string;
  search: string;
  hash: string;
};

const [location, setLocation] = createSignal<LocationState>(readLocation(), {
  equals: (a, b) => a.pathname === b.pathname && a.search === b.search && a.hash === b.hash,
});

function readLocation(): LocationState {
  if (typeof window === "undefined") return { pathname: "/", search: "", hash: "" };
  return {
    pathname: window.location.pathname,
    search: window.location.search,
    hash: window.location.hash,
  };
}

export function pathname(): string {
  return location().pathname;
}

export function search(): string {
  return location().search;
}

export function hash(): string {
  return location().hash;
}

/** Same-origin path this click should open inside the app, or null to let the browser handle it. */
export function shouldHandleLink(args: {
  href: string | null;
  base: string;
  button: number;
  modified: boolean;
  defaultPrevented: boolean;
  target: string | null;
  download: boolean;
}): string | null {
  if (args.defaultPrevented || args.button !== 0 || args.modified) return null;
  if (args.target && args.target !== "_self") return null;
  if (args.download) return null;
  const href = args.href;
  if (
    !href ||
    href.startsWith("#") ||
    href.startsWith("mailto:") ||
    href.startsWith("javascript:") ||
    href.startsWith("blob:") ||
    href.startsWith("data:")
  ) {
    return null;
  }
  let url: URL;
  try {
    url = new URL(href, args.base);
  } catch {
    return null;
  }
  let origin: string;
  try {
    origin = new URL(args.base).origin;
  } catch {
    return null;
  }
  if (url.origin !== origin) return null;
  return `${url.pathname}${url.search}${url.hash}`;
}

export function navigate(to: string, opts?: { replace?: boolean }): void {
  if (typeof window === "undefined") return;
  const url = new URL(to, window.location.href);
  const next = `${url.pathname}${url.search}${url.hash}`;
  const current = `${window.location.pathname}${window.location.search}${window.location.hash}`;
  if (next !== current) {
    if (opts?.replace) history.replaceState({ internal: true }, "", next);
    else history.pushState({ internal: true }, "", next);
  }
  setLocation(readLocation());
}

let started = false;

/** History API plus same-origin link clicks. Pages stay mounted and crossfade in `.stage`. */
export function startRouter(): void {
  if (started || typeof window === "undefined") return;
  started = true;
  setLocation(readLocation());
  window.addEventListener("popstate", () => setLocation(readLocation()));
  document.addEventListener("click", (event) => {
    const node = event.target;
    if (!(node instanceof Element)) return;
    const anchor = node.closest("a");
    if (!(anchor instanceof HTMLAnchorElement)) return;
    const next = shouldHandleLink({
      href: anchor.getAttribute("href"),
      base: window.location.href,
      button: event.button,
      modified: event.metaKey || event.ctrlKey || event.shiftKey || event.altKey,
      defaultPrevented: event.defaultPrevented,
      target: anchor.getAttribute("target"),
      download: anchor.hasAttribute("download"),
    });
    if (next == null) return;
    event.preventDefault();
    navigate(next);
  });
}
