import { InlineMarkdown } from "../components/InlineMarkdown";
import type { StoryBlock, StoryCalloutKind } from "../lib/markdown";
import { t, type Lang } from "../lib/i18n";

function calloutClass(kind: StoryCalloutKind): string {
  if (kind === "turningPoint") return "turning";
  if (kind === "openMystery") return "mystery";
  return "note";
}

export function StoryBlocks({ blocks, lang }: { blocks: StoryBlock[]; lang: Lang }) {
  const copy = t(lang);
  return (
    <div className="story-body">
      {blocks.map((block, index) => {
        if (block.type === "paragraph") {
          return (
            <p key={index}>
              <InlineMarkdown text={block.markdown} />
            </p>
          );
        }
        if (block.type === "callout") {
          const label =
            block.kind === "turningPoint"
              ? copy.turningPoint
              : block.kind === "openMystery"
                ? copy.openMystery
                : copy.note;
          return (
            <aside key={index} className={`callout ${calloutClass(block.kind)}`}>
              <span className="callout-bar" />
              <div className="callout-body">
                <span className="visually-hidden">{label}. </span>
                <InlineMarkdown text={block.markdown} />
              </div>
            </aside>
          );
        }
        if (block.type === "table") {
          return (
            <div key={index} className="md-table-wrap">
              <table className="md-table">
                <thead>
                  <tr>
                    {block.headers.map((header) => (
                      <th key={header}>
                        <InlineMarkdown text={header} />
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {block.rows.map((row, rowIndex) => (
                    <tr key={rowIndex}>
                      {row.map((cell, cellIndex) => (
                        <td key={cellIndex}>
                          <InlineMarkdown text={cell} />
                        </td>
                      ))}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          );
        }
        if (block.type === "list") {
          return (
            <ul key={index} className="bullet-list">
              {block.items.map((item, itemIndex) => (
                <li key={itemIndex}>
                  <span>
                    <InlineMarkdown text={item} />
                  </span>
                </li>
              ))}
            </ul>
          );
        }
        return (
          <pre key={index} className="tree-block">
            {block.lines.join("\n")}
          </pre>
        );
      })}
    </div>
  );
}
