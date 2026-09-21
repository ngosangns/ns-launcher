#!/usr/bin/env bash
# Build the Teyvat web companion and publish it to Cloudflare Pages.
#
# Shared by `task web:deploy` and `.github/workflows/deploy-web.yml` so the
# project name, production branch, and custom domain cannot drift.
#
# Requires CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID. CLOUDFLARE_ZONE_ID
# is used only to create the CNAME if Pages did not attach one.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="gn-teyvat"
DOMAIN="teyvat.gnas.dev"
BRANCH="main"

cd "$ROOT"

if [[ -z "${CLOUDFLARE_API_TOKEN:-}" || -z "${CLOUDFLARE_ACCOUNT_ID:-}" ]]; then
  echo "CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID must be set." >&2
  exit 1
fi

npm --prefix web ci
npm --prefix web test
npm --prefix web run build

if ! wrangler pages project list 2>/dev/null | grep -q "$PROJECT"; then
  wrangler pages project create "$PROJECT" --production-branch "$BRANCH"
fi

wrangler pages deploy web/dist \
  --project-name "$PROJECT" \
  --branch "$BRANCH" \
  --commit-dirty=true

ACCOUNT_API="https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}"
AUTH=(-H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" -H "Content-Type: application/json")

domains="$(curl -fsS "${AUTH[@]}" "${ACCOUNT_API}/pages/projects/${PROJECT}/domains")"
if ! python3 -c "import json,sys; names=[d.get('name','') for d in json.load(sys.stdin).get('result',[])]; sys.exit(0 if '$DOMAIN' in names else 1)" <<<"$domains"; then
  echo "Attaching ${DOMAIN} to ${PROJECT}"
  curl -fsS "${AUTH[@]}" -X POST "${ACCOUNT_API}/pages/projects/${PROJECT}/domains" \
    --data "{\"name\":\"${DOMAIN}\"}"
fi

if [[ -n "${CLOUDFLARE_ZONE_ID:-}" ]]; then
  zone_api="https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records"
  records="$(curl -fsS "${AUTH[@]}" "${zone_api}?name=${DOMAIN}&type=CNAME")"
  if python3 -c "import json,sys; sys.exit(0 if json.load(sys.stdin).get('result') else 1)" <<<"$records"; then
    echo "DNS CNAME ${DOMAIN} already exists."
  else
    echo "Creating CNAME ${DOMAIN} -> ${PROJECT}.pages.dev"
    curl -fsS "${AUTH[@]}" -X POST "$zone_api" --data "{
      \"type\": \"CNAME\",
      \"name\": \"teyvat\",
      \"content\": \"${PROJECT}.pages.dev\",
      \"proxied\": true
    }"
  fi
fi

echo "Deployed https://${DOMAIN} (https://${PROJECT}.pages.dev)"
