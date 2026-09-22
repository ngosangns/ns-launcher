import { useEffect, useState, type ReactNode } from "react";
import { prefersReducedMotion } from "./motion";

type Phase = "enter" | "shown" | "leave" | "idle";

const LEAVE_MS = 240;

/**
 * Hide without unmounting, so scroll, form fields, and search results survive tab switches.
 * `stage` panes crossfade in place. Flow panes stay in document order and rise in when shown.
 */
export function KeepAlive({
  active,
  children,
  className = "",
  stage = false,
}: {
  active: boolean;
  children: ReactNode;
  className?: string;
  stage?: boolean;
}) {
  const [phase, setPhase] = useState<Phase>(active ? "enter" : "idle");

  useEffect(() => {
    if (!stage) return;
    if (active) {
      setPhase("enter");
      let second = 0;
      const first = requestAnimationFrame(() => {
        second = requestAnimationFrame(() => setPhase("shown"));
      });
      // rAF does not run while the tab is in the background; don't leave the pane at opacity 0.
      const fallback = window.setTimeout(() => setPhase("shown"), 64);
      return () => {
        cancelAnimationFrame(first);
        cancelAnimationFrame(second);
        window.clearTimeout(fallback);
      };
    }
    setPhase((current) => (current === "idle" ? "idle" : "leave"));
    const ms = prefersReducedMotion() ? 0 : LEAVE_MS;
    const timer = window.setTimeout(() => setPhase("idle"), ms);
    return () => window.clearTimeout(timer);
  }, [active, stage]);

  if (!stage) {
    return (
      <div
        className={`keep-alive ${active ? "is-active" : ""} ${className}`.trim()}
        hidden={!active}
        inert={!active}
        aria-hidden={!active}
      >
        {children}
      </div>
    );
  }

  return (
    <div
      className={`keep-alive stage-pane phase-${phase} ${active ? "is-active" : ""} ${className}`.trim()}
      inert={!active}
      aria-hidden={!active}
    >
      {children}
    </div>
  );
}
