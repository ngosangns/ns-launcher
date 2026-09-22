import type { ReactNode } from "react";

/** Hide without unmounting, so scroll, form fields, and search results survive tab switches. */
export function KeepAlive({
  active,
  children,
  className = "",
}: {
  active: boolean;
  children: ReactNode;
  className?: string;
}) {
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
