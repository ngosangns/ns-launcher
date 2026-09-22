import { createEffect, type JSX } from "solid-js";
import { iconUrl } from "../lib/abyss";

export function Panel(props: { children?: JSX.Element; class?: string }) {
  return <section class={`panel ${props.class ?? ""}`}>{props.children}</section>;
}

export function GroupLabel(props: { children?: JSX.Element }) {
  return <div class="group-label">{props.children}</div>;
}

export function Portrait(props: {
  kind: "characters" | "weapons" | "artifact-sets" | "monsters";
  id: string;
  alt: string;
  large?: boolean;
}) {
  return (
    <img
      class={props.large ? "portrait lg" : "portrait"}
      src={iconUrl(props.kind, props.id)}
      alt={props.alt}
      loading="lazy"
      onError={(event) => {
        const img = event.currentTarget;
        if (img instanceof HTMLImageElement) img.style.visibility = "hidden";
      }}
    />
  );
}

export function ElementBadge(props: { element: string; size?: number }) {
  const size = () => props.size ?? 20;
  return (
    <span class="element" data-el={props.element} title={props.element} aria-label={props.element}>
      <img
        class="element-icon"
        src={`/icons/elements/${props.element}.png`}
        alt=""
        width={size()}
        height={size()}
        style={{ width: `${size()}px`, height: `${size()}px` }}
      />
    </span>
  );
}

export function CatalogTile(props: {
  to?: string;
  kind: "characters" | "weapons" | "artifact-sets" | "monsters";
  id: string;
  title: string;
  subtitle: JSX.Element;
  rarity?: number;
  selected?: boolean;
  disabled?: boolean;
  onClick?: () => void;
}) {
  const inner = (
    <>
      <Portrait kind={props.kind} id={props.id} alt="" />
      <span class="tile-copy">
        <strong>{props.title}</strong>
        <span class="meta">{props.subtitle}</span>
      </span>
    </>
  );
  const className = () => `tile ${props.selected ? "selected" : ""} ${props.disabled ? "disabled" : ""}`.trim();
  if (props.onClick || props.disabled) {
    return (
      <button
        type="button"
        class={className()}
        data-rarity={props.rarity}
        onClick={() => props.onClick?.()}
        disabled={props.disabled}
      >
        {inner}
      </button>
    );
  }
  return (
    <a href={props.to ?? "#"} class={className()} data-rarity={props.rarity}>
      {inner}
    </a>
  );
}

export function Chip(props: { active: boolean; onClick: () => void; label?: string; children?: JSX.Element }) {
  return (
    <button
      type="button"
      class="chip"
      classList={{ active: props.active }}
      aria-label={props.label}
      onClick={() => props.onClick()}
    >
      {props.children}
    </button>
  );
}

/** Replay the catalog rise when the filter key changes, without remounting on every keystroke. */
export function SwapGrid(props: { id: string; children?: JSX.Element }) {
  let el: HTMLDivElement | undefined;
  let seen = "";
  createEffect(() => {
    const id = props.id;
    const node = el;
    if (!node) return;
    if (seen === "") {
      seen = id;
      return;
    }
    if (seen === id) return;
    seen = id;
    node.classList.remove("swap");
    void node.offsetWidth;
    node.classList.add("swap");
  });
  return (
    <div ref={el} class="catalog swap">
      {props.children}
    </div>
  );
}
