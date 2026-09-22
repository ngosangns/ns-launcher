import { useEffect, useMemo, useState } from "react";
import { Link, useLocation, useNavigate } from "react-router-dom";
import { parseStoryPath } from "../lib/paths";
import { scrollBehavior } from "../components/motion";
import { Reveal } from "../components/Reveal";
import { GroupLabel } from "../components/ui";
import { entityKindLabel, t, type Lang } from "../lib/i18n";
import { foldVi } from "../lib/slug";
import {
  chaptersOf,
  documentHref,
  entitiesByKind,
  questsOf,
  storyLibrary,
} from "../lib/story";
import { StoryBlocks } from "./StoryBlocks";

export function StoryPage({ lang, active }: { lang: Lang; active: boolean }) {
  const copy = t(lang);
  const { pathname } = useLocation();
  const [heldPath, setHeldPath] = useState(pathname);
  useEffect(() => {
    if (pathname.startsWith("/story")) setHeldPath(pathname);
  }, [pathname]);
  // Keep the open chapter mounted while another tab is showing, so its scroll position survives.
  const { docId, sectionId, entityId } = parseStoryPath(pathname.startsWith("/story") ? pathname : heldPath);
  const navigate = useNavigate();
  const [query, setQuery] = useState("");
  const [open, setOpen] = useState(false);
  const library = storyLibrary;

  const needle = foldVi(query.trim());
  const chapters = useMemo(() => {
    const all = chaptersOf(library);
    if (!needle) return all;
    return all.filter((doc) => foldVi(`${doc.title} ${doc.id}`).includes(needle));
  }, [library, needle]);
  const quests = useMemo(() => {
    const all = questsOf(library);
    if (!needle) return all;
    return all.filter((doc) => foldVi(`${doc.title} ${doc.id}`).includes(needle));
  }, [library, needle]);
  const entities = useMemo(() => {
    const all = library.entities;
    if (!needle) return all;
    return all.filter((entity) =>
      foldVi([entity.displayName, ...entity.aliases, entity.summary ?? ""].join(" ")).includes(needle),
    );
  }, [library, needle]);

  const selectedDocument = docId ? library.documentsByID[docId] : undefined;
  const selectedEntity = entityId ? library.entitiesByID[entityId] : undefined;

  useEffect(() => {
    if (!active) return;
    if (!docId && !entityId) {
      const first = chaptersOf(library)[0];
      if (first) navigate(documentHref(first.id), { replace: true });
    }
  }, [active, docId, entityId, library, navigate]);

  useEffect(() => {
    if (!active || !sectionId) return;
    const node = document.getElementById(sectionId);
    node?.scrollIntoView({ behavior: scrollBehavior(), block: "start" });
  }, [active, sectionId, docId]);

  const empty = chapters.length === 0 && quests.length === 0 && entities.length === 0;

  return (
    <div className="split">
      <aside className={`sidebar collapsible ${open ? "open" : ""}`}>
        <button
          type="button"
          className="btn btn-quiet drawer-toggle"
          aria-expanded={open}
          onClick={() => setOpen((v) => !v)}
        >
          {copy.storyOpenToc}
        </button>
        <div className="drawer-fold">
          <div className="drawer-fold-inner">
        <p className="notice">{copy.storyCopyright}</p>
        <input
          className="search"
          value={query}
          onChange={(event) => setQuery(event.target.value)}
          placeholder={copy.storySearch}
        />
        <div className="sidebar-scroll">
          {empty && <p className="empty">{copy.storyEmpty}</p>}
          {chapters.length > 0 && (
            <>
              <GroupLabel>{copy.storyChapters}</GroupLabel>
              {chapters.map((doc) => (
                <Link
                  key={doc.id}
                  className={`nav-item ${docId === doc.id ? "active" : ""}`}
                  to={documentHref(doc.id)}
                  onClick={() => setOpen(false)}
                >
                  {doc.title}
                </Link>
              ))}
            </>
          )}
          {entities.length > 0 && (
            <>
              <GroupLabel>{copy.storyEntities}</GroupLabel>
              {entitiesByKind(entities).map((group) => (
                <div key={group.kind}>
                  <div className="kind-label">{entityKindLabel(lang, group.kind)}</div>
                  {group.entities.map((entity) => (
                    <Link
                      key={entity.id}
                      className={`nav-item ${entityId === entity.id ? "active" : ""}`}
                      to={`/story/e/${entity.id}`}
                      onClick={() => setOpen(false)}
                    >
                      {entity.displayName}
                    </Link>
                  ))}
                </div>
              ))}
            </>
          )}
          {quests.length > 0 && (
            <>
              <GroupLabel>{copy.storyQuests}</GroupLabel>
              {quests.map((doc) => (
                <Link
                  key={doc.id}
                  className={`nav-item ${docId === doc.id ? "active" : ""}`}
                  to={documentHref(doc.id)}
                  onClick={() => setOpen(false)}
                >
                  {doc.title}
                </Link>
              ))}
            </>
          )}
        </div>
          </div>
        </div>
      </aside>

      <article className="detail">
        <Reveal id={selectedEntity?.id ?? selectedDocument?.id ?? "empty"} pinTop={!sectionId}>
        {selectedDocument && (
          <>
            <div className="story-title">
              <h1>{selectedDocument.title}</h1>
            </div>
            {selectedDocument.sections.map((section) => (
              <section key={section.id} id={section.id}>
                {section.heading && (section.level <= 2 ? <h2>{section.heading}</h2> : <h3>{section.heading}</h3>)}
                <StoryBlocks blocks={section.blocks} lang={lang} />
              </section>
            ))}
          </>
        )}
        {selectedEntity && (
          <EntityDetail lang={lang} entityId={selectedEntity.id} />
        )}
        {!selectedDocument && !selectedEntity && <p className="empty">{copy.storySelect}</p>}
        </Reveal>
      </article>
    </div>
  );
}

function EntityDetail({ lang, entityId }: { lang: Lang; entityId: string }) {
  const copy = t(lang);
  const entity = storyLibrary.entitiesByID[entityId];
  if (!entity) return <p className="empty">{copy.storyEmpty}</p>;
  const occurrences = storyLibrary.occurrences[entity.id] ?? [];
  const chapters = occurrences.filter((item) => item.documentKind === "narrativeChapter");
  const quests = occurrences.filter((item) => item.documentKind === "questReference");

  return (
    <>
      <div className="entity-header">
        <h1 style={{ fontFamily: "var(--font-story)", margin: 0 }}>{entity.displayName}</h1>
        <span className="pill">{entityKindLabel(lang, entity.kind)}</span>
      </div>
      {entity.aliases.length > 0 && (
        <p className="meta">
          {copy.storyAlsoKnownAs}: {entity.aliases.join(", ")}
        </p>
      )}
      <p className="prose" style={{ marginTop: 12 }}>
        {entity.summary && entity.summary.length > 0 ? entity.summary : copy.storyNoSummary}
      </p>
      {chapters.length > 0 && (
        <>
          <div className="section-title">{copy.storyAppearsIn}</div>
          {chapters.map((occurrence) => {
            const section = storyLibrary.documentsByID[occurrence.documentID]?.sections.find(
              (item) => item.id === occurrence.sectionID,
            );
            return (
              <div key={`${occurrence.documentID}#${occurrence.sectionID}`} className="excerpt">
                <Link className="jump" to={documentHref(occurrence.documentID, occurrence.sectionID)}>
                  {occurrence.documentTitle}
                  {occurrence.sectionHeading ? ` · ${occurrence.sectionHeading}` : ""}
                </Link>
                {section && <StoryBlocks blocks={section.blocks} lang={lang} />}
              </div>
            );
          })}
        </>
      )}
      {quests.length > 0 && (
        <>
          <div className="section-title">{copy.storyRelatedQuests}</div>
          {quests.map((occurrence) => (
            <Link
              key={`${occurrence.documentID}#${occurrence.sectionID}`}
              className="nav-item"
              to={documentHref(occurrence.documentID, occurrence.sectionID)}
            >
              {occurrence.documentTitle}
              {occurrence.sectionHeading ? ` — ${occurrence.sectionHeading}` : ""}
            </Link>
          ))}
        </>
      )}
    </>
  );
}
