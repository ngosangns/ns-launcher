import { useEffect, useRef, type ReactNode } from "react";
import { scrollBehavior } from "./motion";

/** Replay a rise when `id` changes, and bring the surrounding pane back to the top. */
export function Reveal({
  id,
  children,
  className = "",
  pinTop = true,
}: {
  id: string;
  children: ReactNode;
  className?: string;
  pinTop?: boolean;
}) {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!pinTop) return;
    const scroller = ref.current?.closest(".stage-pane");
    if (!(scroller instanceof HTMLElement)) return;
    scroller.scrollTo({ top: 0, behavior: scrollBehavior() });
  }, [id, pinTop]);

  return (
    <div ref={ref} key={id} className={`rise-once ${className}`.trim()}>
      {children}
    </div>
  );
}
