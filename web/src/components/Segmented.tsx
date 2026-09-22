import { useLayoutEffect, useRef, type ReactNode } from "react";

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
export function Segmented({
  children,
  className = "",
  label,
  nav = false,
}: {
  children: ReactNode;
  className?: string;
  label?: string;
  nav?: boolean;
}) {
  const ref = useRef<HTMLElement | null>(null);
  const indicatorRef = useRef<HTMLSpanElement | null>(null);
  const boxRef = useRef<Box | null>(null);
  const readyRef = useRef(false);
  const applyRef = useRef<() => void>(() => {});

  useLayoutEffect(() => {
    const root = ref.current;
    const indicator = indicatorRef.current;
    if (!root || !indicator) return;

    const apply = () => {
      const next = readBox(root);
      if (!next) return;
      const prev = boxRef.current;
      if (prev && prev.x === next.x && prev.y === next.y && prev.w === next.w && prev.h === next.h) return;
      boxRef.current = next;
      const snap = !readyRef.current;
      if (snap) indicator.style.transition = "none";
      indicator.style.opacity = "1";
      indicator.style.width = `${next.w}px`;
      indicator.style.height = `${next.h}px`;
      indicator.style.transform = `translate3d(${next.x}px, ${next.y}px, 0)`;
      if (snap) {
        void indicator.offsetWidth;
        indicator.style.transition = "";
        readyRef.current = true;
      }
    };

    applyRef.current = apply;
    apply();
  });

  useLayoutEffect(() => {
    const root = ref.current;
    if (!root) return;
    const onResize = () => applyRef.current();
    const observer = new ResizeObserver(onResize);
    observer.observe(root);
    for (const child of root.children) {
      if (child instanceof HTMLElement && !child.classList.contains("tab-indicator")) observer.observe(child);
    }
    window.addEventListener("resize", onResize);
    void document.fonts?.ready.then(onResize);
    return () => {
      observer.disconnect();
      window.removeEventListener("resize", onResize);
    };
  }, []);

  const indicator = <span ref={indicatorRef} className="tab-indicator" aria-hidden="true" />;
  const classes = `segmented ${className}`.trim();
  if (nav) {
    return (
      <nav ref={(node) => { ref.current = node; }} className={classes} aria-label={label}>
        {indicator}
        {children}
      </nav>
    );
  }
  return (
    <div ref={(node) => { ref.current = node; }} className={classes} role="group" aria-label={label}>
      {indicator}
      {children}
    </div>
  );
}
