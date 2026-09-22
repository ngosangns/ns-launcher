import { createEffect, createSignal, onCleanup, type JSX } from "solid-js";
import { prefersReducedMotion } from "./motion";

type Phase = "enter" | "shown" | "leave" | "idle";

const LEAVE_MS = 240;

/**
 * Hide without unmounting, so scroll, form fields, and search results survive tab switches.
 * `stage` panes crossfade in place. Flow panes stay in document order and stay mounted.
 */
export function KeepAlive(props: {
  active: boolean;
  children?: JSX.Element;
  class?: string;
  stage?: boolean;
}) {
  const [phase, setPhase] = createSignal<Phase>(props.active ? "enter" : "idle");

  createEffect(() => {
    if (!props.stage) return;
    if (props.active) {
      setPhase("enter");
      let second = 0;
      const first = requestAnimationFrame(() => {
        second = requestAnimationFrame(() => setPhase("shown"));
      });
      // rAF does not run while the tab is in the background; don't leave the pane at opacity 0.
      const fallback = window.setTimeout(() => setPhase("shown"), 64);
      onCleanup(() => {
        cancelAnimationFrame(first);
        cancelAnimationFrame(second);
        window.clearTimeout(fallback);
      });
      return;
    }
    setPhase((current) => (current === "idle" ? "idle" : "leave"));
    const ms = prefersReducedMotion() ? 0 : LEAVE_MS;
    const timer = window.setTimeout(() => setPhase("idle"), ms);
    onCleanup(() => window.clearTimeout(timer));
  });

  if (!props.stage) {
    return (
      <div
        class={`keep-alive ${props.active ? "is-active" : ""} ${props.class ?? ""}`.trim()}
        hidden={!props.active}
        inert={!props.active || undefined}
        aria-hidden={!props.active}
      >
        {props.children}
      </div>
    );
  }

  return (
    <div
      class={`keep-alive stage-pane phase-${phase()} ${props.active ? "is-active" : ""} ${props.class ?? ""}`.trim()}
      inert={!props.active || undefined}
      aria-hidden={!props.active}
    >
      {props.children}
    </div>
  );
}
