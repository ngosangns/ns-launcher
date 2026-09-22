import { Show, createEffect, type JSX } from "solid-js";
import { scrollBehavior } from "./motion";

function Rise(props: { revealId: string; class?: string; pinTop?: boolean; children?: JSX.Element }) {
  let ref: HTMLDivElement | undefined;
  createEffect(() => {
    props.revealId;
    if (props.pinTop === false) return;
    const scroller = ref?.closest(".stage-pane");
    if (!(scroller instanceof HTMLElement)) return;
    scroller.scrollTo({ top: 0, behavior: scrollBehavior() });
  });
  return (
    <div ref={ref} class={`rise-once ${props.class ?? ""}`.trim()}>
      {props.children}
    </div>
  );
}

/** Replay a rise when `id` changes, and bring the surrounding pane back to the top. */
export function Reveal(props: { id: string; children?: JSX.Element; class?: string; pinTop?: boolean }) {
  return (
    <Show when={props.id} keyed>
      {(id) => (
        <Rise revealId={id} class={props.class} pinTop={props.pinTop}>
          {props.children}
        </Rise>
      )}
    </Show>
  );
}
