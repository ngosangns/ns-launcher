# ns-launcher

## Branching

- Work only on `main`. Do not create new branches.
- Commit directly on `main` and push to `origin/main`.
- Exception: Firstmate delivery workers may use one short-lived `fm/<task>` branch per task to open a pull request into `main`; that branch is deleted as soon as it is merged.

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.

## Web companion

`web/` is a Vite + SolidJS site (Ký Sự Teyvat) for Story and Abyss. The macOS
launcher does not include those screens. The site reads data from
`Sources/NSLauncherApp/Resources/` (no copies). Run with `task web` or
`cd web && npm run dev`. See `web/README.md`.

Deploy to Cloudflare Pages (not cloudflared): `task web:deploy` runs
`scripts/deploy-web.sh`, which is also the GitHub Actions path. Live URL is
https://teyvat.gnas.dev (`gn-teyvat` Pages project). Needs
`CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`, and `CLOUDFLARE_ZONE_ID`.
