import { Link } from "react-router-dom";
import { t, type Lang } from "../lib/i18n";
import { currentCycle } from "../lib/abyss";
import { formatDateRange } from "../lib/format";
import { BookIcon, ShieldIcon } from "../lib/icons";

export function HomePage({ lang }: { lang: Lang }) {
  const copy = t(lang);
  const cycle = currentCycle();
  const blessing = cycle.blessingOfTheAbyssalMoon;

  return (
    <div className="hero">
      <h1>{copy.brand}</h1>
      <p className="lead">{copy.tagline}</p>
      <div className="card-grid">
        <section className="panel">
          <h2>
            <BookIcon /> {copy.story}
          </h2>
          <p>{copy.homeStoryLead}</p>
          <Link className="btn btn-primary" to="/story">
            {copy.homeOpen} {copy.story}
          </Link>
        </section>
        <section className="panel">
          <h2>
            <ShieldIcon /> {copy.abyss}
          </h2>
          <p>{copy.homeAbyssLead}</p>
          <p className="meta">
            {copy.currentCycle}: {formatDateRange(cycle.periodStart, cycle.periodEnd, lang)}
            {" · "}
            {lang === "vi" ? blessing.nameVI ?? blessing.name : blessing.name}
          </p>
          <Link className="btn btn-primary" to="/abyss/team">
            {copy.homeOpen} {copy.abyss}
          </Link>
        </section>
      </div>
      <p className="copyright">{copy.storyCopyright}</p>
    </div>
  );
}
