import type { ReactNode } from "react";
import { Link } from "react-router-dom";
import { iconUrl, type ElementName } from "../lib/abyss";

export function Panel({ children, className = "" }: { children: ReactNode; className?: string }) {
  return <section className={`panel ${className}`}>{children}</section>;
}

export function GroupLabel({ children }: { children: ReactNode }) {
  return <div className="group-label">{children}</div>;
}

export function Portrait({
  kind,
  id,
  alt,
  large = false,
}: {
  kind: "characters" | "weapons" | "artifact-sets";
  id: string;
  alt: string;
  large?: boolean;
}) {
  return (
    <img
      className={large ? "portrait lg" : "portrait"}
      src={iconUrl(kind, id)}
      alt={alt}
      loading="lazy"
      onError={(event) => {
        event.currentTarget.style.visibility = "hidden";
      }}
    />
  );
}

export function Stars({ n }: { n: number }) {
  return (
    <span className="stars" aria-label={`${n} sao`}>
      {"★".repeat(Math.max(0, Math.min(n, 5)))}
    </span>
  );
}

export function ElementBadge({ element }: { element: string }) {
  return (
    <span className="element" data-el={element}>
      {element}
    </span>
  );
}

const ACCENT: Record<string, string> = {
  Pyro: "var(--pyro)",
  Hydro: "var(--hydro)",
  Anemo: "var(--anemo)",
  Electro: "var(--electro)",
  Dendro: "var(--dendro)",
  Cryo: "var(--cryo)",
  Geo: "var(--geo)",
};

export function elementColor(element: string): string {
  return ACCENT[element] ?? "var(--gold)";
}

export function CatalogTile({
  to,
  kind,
  id,
  title,
  subtitle,
  accent,
  selected = false,
  disabled = false,
  onClick,
}: {
  to?: string;
  kind: "characters" | "weapons" | "artifact-sets";
  id: string;
  title: string;
  subtitle: ReactNode;
  accent?: ElementName | string;
  selected?: boolean;
  disabled?: boolean;
  onClick?: () => void;
}) {
  const inner = (
    <>
      <span className="accent-bar" style={{ background: accent ? elementColor(accent) : "transparent" }} />
      <Portrait kind={kind} id={id} alt="" />
      <span className="tile-copy">
        <strong>{title}</strong>
        <span className="meta">{subtitle}</span>
      </span>
    </>
  );
  const className = `tile ${selected ? "selected" : ""} ${disabled ? "disabled" : ""}`;
  if (onClick || disabled) {
    return (
      <button type="button" className={className} onClick={onClick} disabled={disabled}>
        {inner}
      </button>
    );
  }
  return (
    <Link to={to ?? "#"} className={className}>
      {inner}
    </Link>
  );
}

export function Chip({
  active,
  onClick,
  children,
}: {
  active: boolean;
  onClick: () => void;
  children: ReactNode;
}) {
  return (
    <button type="button" className={`chip ${active ? "active" : ""}`} onClick={onClick}>
      {children}
    </button>
  );
}
