import { Link } from "react-router-dom";
import type { ReactNode } from "react";

type Token =
  | { type: "text"; value: string }
  | { type: "strong"; value: string }
  | { type: "em"; value: string }
  | { type: "link"; href: string; value: string };

const TOKEN =
  /(\*\*[^*]+\*\*|\*[^*]+\*|_[^_]+_|\[(?:[^\]]+)\]\([^)]+\))/g;

function tokenize(markdown: string): Token[] {
  const tokens: Token[] = [];
  let last = 0;
  for (const match of markdown.matchAll(TOKEN)) {
    const index = match.index ?? 0;
    if (index > last) tokens.push({ type: "text", value: markdown.slice(last, index) });
    const raw = match[0];
    if (raw.startsWith("**") && raw.endsWith("**")) {
      tokens.push({ type: "strong", value: raw.slice(2, -2) });
    } else if ((raw.startsWith("*") && raw.endsWith("*")) || (raw.startsWith("_") && raw.endsWith("_"))) {
      tokens.push({ type: "em", value: raw.slice(1, -1) });
    } else if (raw.startsWith("[")) {
      const close = raw.indexOf("](");
      tokens.push({
        type: "link",
        value: raw.slice(1, close),
        href: raw.slice(close + 2, -1),
      });
    } else {
      tokens.push({ type: "text", value: raw });
    }
    last = index + raw.length;
  }
  if (last < markdown.length) tokens.push({ type: "text", value: markdown.slice(last) });
  return tokens;
}

export function InlineMarkdown({ text }: { text: string }) {
  const nodes: ReactNode[] = tokenize(text).map((token, index) => {
    if (token.type === "strong") {
      return (
        <strong key={index}>
          <InlineMarkdown text={token.value} />
        </strong>
      );
    }
    if (token.type === "em") {
      return (
        <em key={index}>
          <InlineMarkdown text={token.value} />
        </em>
      );
    }
    if (token.type === "link") {
      const internal = token.href.startsWith("/");
      if (internal) {
        return (
          <Link key={index} to={token.href}>
            {token.value}
          </Link>
        );
      }
      return (
        <a key={index} href={token.href} rel="noreferrer">
          {token.value}
        </a>
      );
    }
    return <span key={index}>{token.value}</span>;
  });
  return <>{nodes}</>;
}
