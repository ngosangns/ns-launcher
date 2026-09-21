const UPSTREAM = "https://enka.network";

export const onRequest = async ({
  request,
  params,
}: {
  request: Request;
  params: { path?: string | string[] };
}): Promise<Response> => {
  const path = splat(params.path);
  const incoming = new URL(request.url);
  const target = `${UPSTREAM}/${path}${incoming.search}`;
  const headers = new Headers();
  headers.set("Accept", request.headers.get("Accept") ?? "application/json");
  headers.set("User-Agent", "NSLauncher (github.com/ngosangns/ns-launcher)");
  const response = await fetch(target, { method: "GET", headers });
  return new Response(response.body, {
    status: response.status,
    headers: corsHeaders(response.headers),
  });
};

function splat(path: string | string[] | undefined): string {
  if (Array.isArray(path)) return path.join("/");
  return path ?? "";
}

function corsHeaders(source: Headers): Headers {
  const headers = new Headers(source);
  headers.set("Access-Control-Allow-Origin", "*");
  return headers;
}
