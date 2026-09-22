import { onCleanup, onMount, type JSX } from "solid-js";

type Box = { x: number; y: number; w: number; h: number };

function readBox(root: HTMLElement): Box | null {
  const active = root.querySelector<HTMLElement>(
    ":scope > a.active, :scope > button.active, :scope > .tab.active",
  );
  if (!active || active.offsetWidth === 0 || active.offsetHeight === 0) return null;
  return {
    x: active.offsetLeft,
    y: active.offsetTop,
    w: active.offsetWidth,
    h: active.offsetHeight,
  };
}

/**
 * Pill that slides between the active tab. Geometry is written on the indicator
 * so a re-render does not restart the CSS transition.
 */
export function Segmented(props: { children?: JSX.Element; class?: string; label?: string; nav?: boolean }) {
  let root: HTMLElement | undefined;
  let indicator: HTMLSpanElement | undefined;
  let box: Box | null = null;
  let ready = false;

  onMount(() => {
    const host = root;
    const pill = indicator;
    if (!host || !pill) return;

    const apply = () => {
      const next = readBox(host);
      if (!next) return;
      const prev = box;
      if (prev && prev.x === next.x && prev.y === next.y && prev.w === next.w && prev.h === next.h) return;
      box = next;
      const snap = !ready;
      if (snap) pill.style.transition = "none";
      pill.style.opacity = "1";
      pill.style.width = `${next.w}px`;
      pill.style.height = `${next.h}px`;
      pill.style.transform = `translate3d(${next.x}px, ${next.y}px, 0)`;
      if (snap) {
        void pill.offsetWidth;
        pill.style.transition = "";
        ready = true;
      }
    };

    const watchChildren = () => {
      resize.disconnect();
      resize.observe(host);
      for (const child of host.children) {
        if (child instanceof HTMLElement && !child.classList.contains("tab-indicator")) resize.observe(child);
      }
    };

    const resize = new ResizeObserver(() => apply());
    const mutations = new MutationObserver(() => {
      watchChildren();
      apply();
    });
    mutations.observe(host, { subtree: true, childList: true, attributes: true, attributeFilter: ["class"] });
    watchChildren();
    const onResize = () => apply();
    window.addEventListener("resize", onResize);
    void document.fonts?.ready.then(onResize);
    apply();
    onCleanup(() => {
      mutations.disconnect();
      resize.disconnect();
      window.removeEventListener("resize", onResize);
    });
  });

  const classes = () => `segmented ${props.class ?? ""}`.trim();
  const indicatorNode = (
    <span ref={indicator} class="tab-indicator" aria-hidden="true" />
  );
  if (props.nav) {
    return (
      <nav ref={(el) => (root = el)} class={classes()} aria-label={props.label}>
        {indicatorNode}
        {props.children}
      </nav>
    );
  }
  return (
    <div ref={(el) => (root = el)} class={classes()} role="group" aria-label={props.label}>
      {indicatorNode}
      {props.children}
    </div>
  );
}
