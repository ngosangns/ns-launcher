import { createEffect } from "solid-js";
import katex from "katex";
import "katex/dist/katex.min.css";

/** Typeset one TeX expression with KaTeX. Falls back to the source text if it cannot parse. */
export function MathBlock(props: { tex: string; display?: boolean }) {
  let host: HTMLSpanElement | undefined;
  createEffect(() => {
    const node = host;
    if (!node) return;
    const display = props.display !== false;
    try {
      katex.render(props.tex, node, { throwOnError: true, displayMode: display, strict: "ignore" });
    } catch {
      node.textContent = props.tex;
    }
  });
  return <span class="math" classList={{ "math-display": props.display !== false }} ref={host} />;
}
