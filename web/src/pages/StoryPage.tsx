import { createEffect, createMemo, createSignal, For, Show } from "solid-js";
import { parseStoryPath } from "../lib/paths";
import { scrollBehavior } from "../components/motion";
import { Reveal } from "../components/Reveal";
import { iconUrl } from "../lib/abyss";
import { GroupLabel } from "../components/ui";
import { entityKindLabel, t, type Lang } from "../lib/i18n";
import { foldVi } from "../lib/slug";
import {
  chaptersOf,
  documentHref,
  entitiesByKind,
  entityIconId,
  questFaces,
  questsOf,
  storyLibrary,
  type StoryDocument,
} from "../lib/story";
import { navigate, pathname } from "../router";
import { StoryBlocks } from "./StoryBlocks";

export function StoryPage(props: { lang: Lang; active: boolean }) {
  const text = () => t(props.lang);
  const [heldPath, setHeldPath] = createSignal(pathname());
  const [query, setQuery] = createSignal("");
  const [open, setOpen] = createSignal(false);
  const library = storyLibrary;

  createEffect(() => {
    const path = pathname();
    if (path.startsWith("/story")) setHeldPath(path);
  });

  // Keep the open chapter mounted while another tab is showing, so its scroll position survives.
  const parsed = createMemo(() => parseStoryPath(pathname().startsWith("/story") ? pathname() : heldPath()));
  const needle = () => foldVi(query().trim());
  const chapters = createMemo(() => {
    const all = chaptersOf(library);
    const q = needle();
    if (!q) return all;
    return all.filter((doc) => foldVi(`${doc.title} ${doc.id}`).includes(q));
  });
  const quests = createMemo(() => {
    const all = questsOf(library);
    const q = needle();
    if (!q) return all;
    return all.filter((doc) => {
      if (foldVi(`${doc.title} ${doc.id}`).includes(q)) return true;
      return questFaces(doc).some((face) => foldVi(face.title).includes(q));
    });
  });
  const entities = createMemo(() => {
    const all = library.entities;
    const q = needle();
    if (!q) return all;
    return all.filter((entity) =>
      foldVi([entity.displayName, ...entity.aliases, entity.summary ?? ""].join(" ")).includes(q),
    );
  });
  const selectedDocument = () => {
    const docId = parsed().docId;
    return docId ? library.documentsByID[docId] : undefined;
  };
  const selectedEntity = () => {
    const entityId = parsed().entityId;
    return entityId ? library.entitiesByID[entityId] : undefined;
  };

  createEffect(() => {
    if (!props.active) return;
    if (!parsed().docId && !parsed().entityId) {
      const first = chaptersOf(library)[0];
      if (first) navigate(documentHref(first.id), { replace: true });
    }
  });

  createEffect(() => {
    if (!props.active) return;
    const sectionId = parsed().sectionId;
    parsed().docId;
    if (!sectionId) return;
    const node = document.getElementById(sectionId);
    node?.scrollIntoView({ behavior: scrollBehavior(), block: "start" });
  });

  const empty = () => chapters().length === 0 && quests().length === 0 && entities().length === 0;

  return (
    <div class="split">
      <aside class="sidebar collapsible" classList={{ open: open() }}>
        <button
          type="button"
          class="btn btn-quiet drawer-toggle"
          aria-expanded={open()}
          onClick={() => setOpen((value) => !value)}
        >
          {text().storyOpenToc}
        </button>
        <div class="drawer-fold">
          <div class="drawer-fold-inner">
            <input
              class="search"
              value={query()}
              onInput={(event) => setQuery(event.currentTarget.value)}
              placeholder={text().storySearch}
            />
            <div class="sidebar-scroll">
              <Show when={empty()}>
                <p class="empty">{text().storyEmpty}</p>
              </Show>
              <Show when={chapters().length > 0}>
                <GroupLabel>{text().storyChapters}</GroupLabel>
                {chapters().map((doc) => (
                  <a
                    class="nav-item"
                    classList={{ active: parsed().docId === doc.id }}
                    href={documentHref(doc.id)}
                    onClick={() => setOpen(false)}
                  >
                    {doc.title}
                  </a>
                ))}
              </Show>
              <Show when={entities().length > 0}>
                <GroupLabel>{text().storyEntities}</GroupLabel>
                {entitiesByKind(entities()).map((group) => (
                  <div>
                    <div class="kind-label">{entityKindLabel(props.lang, group.kind)}</div>
                    {group.entities.map((entity) => {
                      const iconId = entityIconId(entity);
                      return (
                        <a
                          class="nav-item"
                          classList={{ active: parsed().entityId === entity.id }}
                          href={`/story/e/${entity.id}`}
                          onClick={() => setOpen(false)}
                        >
                          <Show when={iconId}>
                            <img
                              class="nav-avatar"
                              src={iconUrl("characters", iconId!)}
                              alt=""
                              onError={(event) => {
                                const img = event.currentTarget;
                                if (img instanceof HTMLImageElement) img.style.visibility = "hidden";
                              }}
                            />
                          </Show>
                          <span class="nav-label">{entity.displayName}</span>
                        </a>
                      );
                    })}
                  </div>
                ))}
              </Show>
              <Show when={quests().length > 0}>
                <GroupLabel>{text().storyQuests}</GroupLabel>
                {quests().map((doc) => (
                  <QuestNav
                    doc={doc}
                    query={needle()}
                    activeDocId={parsed().docId}
                    activeSectionId={parsed().sectionId}
                    onNavigate={() => setOpen(false)}
                  />
                ))}
              </Show>
            </div>
          </div>
        </div>
      </aside>

      <article class="detail">
        <Reveal id={selectedEntity()?.id ?? selectedDocument()?.id ?? "empty"} pinTop={!parsed().sectionId}>
          <Show when={selectedDocument()}>
            {(doc) => (
              <>
                <div class="story-title">
                  <h1>{doc().title}</h1>
                </div>
                {doc().sections.map((section) => (
                  <section id={section.id}>
                    {section.heading && (section.level <= 2 ? <h2>{section.heading}</h2> : <h3>{section.heading}</h3>)}
                    <StoryBlocks blocks={section.blocks} lang={props.lang} />
                  </section>
                ))}
              </>
            )}
          </Show>
          <Show when={selectedEntity()}>
            {(entity) => <EntityDetail lang={props.lang} entityId={entity().id} />}
          </Show>
          <Show when={!selectedDocument() && !selectedEntity()}>
            <p class="empty">{text().storySelect}</p>
          </Show>
        </Reveal>
      </article>
    </div>
  );
}

function QuestNav(props: {
  doc: StoryDocument;
  query: string;
  activeDocId?: string;
  activeSectionId?: string;
  onNavigate: () => void;
}) {
  const faces = () => {
    const all = questFaces(props.doc);
    const query = props.query;
    if (!query) return all;
    const matched = all.filter((face) => foldVi(face.title).includes(query));
    if (foldVi(props.doc.title).includes(query)) return all;
    return matched;
  };
  return (
    <>
      <a
        class="nav-item"
        classList={{ active: props.activeDocId === props.doc.id && !props.activeSectionId }}
        href={documentHref(props.doc.id)}
        onClick={() => props.onNavigate()}
      >
        {props.doc.title}
      </a>
      <For each={faces()}>
        {(face) => (
          <a
            class="nav-item"
            classList={{ active: props.activeDocId === props.doc.id && props.activeSectionId === face.sectionID }}
            href={documentHref(props.doc.id, face.sectionID)}
            onClick={() => props.onNavigate()}
          >
            <Show when={face.iconId}>
              {(iconId) => (
                <img
                  class="nav-avatar"
                  src={iconUrl("characters", iconId())}
                  alt=""
                  onError={(event) => {
                    const img = event.currentTarget;
                    if (img instanceof HTMLImageElement) img.style.visibility = "hidden";
                  }}
                />
              )}
            </Show>
            <span class="nav-label">{face.title}</span>
          </a>
        )}
      </For>
    </>
  );
}

function EntityDetail(props: { lang: Lang; entityId: string }) {
  const text = () => t(props.lang);
  const entity = () => storyLibrary.entitiesByID[props.entityId];
  const occurrences = () => storyLibrary.occurrences[props.entityId] ?? [];
  const chapters = () => occurrences().filter((item) => item.documentKind === "narrativeChapter");
  const quests = () => occurrences().filter((item) => item.documentKind === "questReference");

  return (
    <Show when={entity()} fallback={<p class="empty">{text().storyEmpty}</p>}>
      {(item) => (
        <>
          <div class="entity-header">
            <h1 style={{ "font-family": "var(--font-story)", margin: "0" }}>{item().displayName}</h1>
            <span class="pill">{entityKindLabel(props.lang, item().kind)}</span>
          </div>
          <Show when={item().aliases.length > 0}>
            <p class="meta">
              {text().storyAlsoKnownAs}: {item().aliases.join(", ")}
            </p>
          </Show>
          <p class="prose" style={{ "margin-top": "12px" }}>
            {item().summary ? item().summary : text().storyNoSummary}
          </p>
          <Show when={chapters().length > 0}>
            <div class="section-title">{text().storyAppearsIn}</div>
            {chapters().map((occurrence) => {
              const section = storyLibrary.documentsByID[occurrence.documentID]?.sections.find(
                (entry) => entry.id === occurrence.sectionID,
              );
              return (
                <div class="excerpt">
                  <a class="jump" href={documentHref(occurrence.documentID, occurrence.sectionID)}>
                    {occurrence.documentTitle}
                    {occurrence.sectionHeading ? ` · ${occurrence.sectionHeading}` : ""}
                  </a>
                  {section && <StoryBlocks blocks={section.blocks} lang={props.lang} />}
                </div>
              );
            })}
          </Show>
          <Show when={quests().length > 0}>
            <div class="section-title">{text().storyRelatedQuests}</div>
            {quests().map((occurrence) => (
              <a class="nav-item" href={documentHref(occurrence.documentID, occurrence.sectionID)}>
                {occurrence.documentTitle}
                {occurrence.sectionHeading ? ` — ${occurrence.sectionHeading}` : ""}
              </a>
            ))}
          </Show>
        </>
      )}
    </Show>
  );
}
