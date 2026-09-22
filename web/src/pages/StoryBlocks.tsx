import { For, Match, Switch } from "solid-js";
import { InlineMarkdown } from "../components/InlineMarkdown";
import type { StoryBlock, StoryCalloutKind } from "../lib/markdown";
import { t, type Lang } from "../lib/i18n";

function calloutClass(kind: StoryCalloutKind): string {
  if (kind === "turningPoint") return "turning";
  if (kind === "openMystery") return "mystery";
  return "note";
}

function Block(props: { block: StoryBlock; lang: Lang }) {
  const text = () => t(props.lang);
  return (
    <Switch>
      <Match when={props.block.type === "paragraph" ? props.block : undefined}>
        {(block) => (
          <p>
            <InlineMarkdown text={block().markdown} />
          </p>
        )}
      </Match>
      <Match when={props.block.type === "callout" ? props.block : undefined}>
        {(block) => (
          <aside class={`callout ${calloutClass(block().kind)}`}>
            <span class="callout-bar" />
            <div class="callout-body">
              <span class="visually-hidden">
                {block().kind === "turningPoint"
                  ? text().turningPoint
                  : block().kind === "openMystery"
                    ? text().openMystery
                    : text().note}
                .{" "}
              </span>
              <InlineMarkdown text={block().markdown} />
            </div>
          </aside>
        )}
      </Match>
      <Match when={props.block.type === "table" ? props.block : undefined}>
        {(block) => (
          <div class="md-table-wrap">
            <table class="md-table">
              <thead>
                <tr>
                  <For each={block().headers}>
                    {(header) => (
                      <th>
                        <InlineMarkdown text={header} />
                      </th>
                    )}
                  </For>
                </tr>
              </thead>
              <tbody>
                <For each={block().rows}>
                  {(row) => (
                    <tr>
                      <For each={row}>
                        {(cell) => (
                          <td>
                            <InlineMarkdown text={cell} />
                          </td>
                        )}
                      </For>
                    </tr>
                  )}
                </For>
              </tbody>
            </table>
          </div>
        )}
      </Match>
      <Match when={props.block.type === "list" ? props.block : undefined}>
        {(block) => (
          <ul class="bullet-list">
            <For each={block().items}>
              {(item) => (
                <li>
                  <span>
                    <InlineMarkdown text={item} />
                  </span>
                </li>
              )}
            </For>
          </ul>
        )}
      </Match>
      <Match when={props.block.type === "tree" ? props.block : undefined}>
        {(block) => <pre class="tree-block">{block().lines.join("\n")}</pre>}
      </Match>
    </Switch>
  );
}

export function StoryBlocks(props: { blocks: StoryBlock[]; lang: Lang }) {
  return (
    <div class="story-body">
      <For each={props.blocks}>{(block) => <Block block={block} lang={props.lang} />}</For>
    </div>
  );
}
