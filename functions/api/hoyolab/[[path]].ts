const UPSTREAM = "https://sg-public-api.hoyolab.com";

export const onRequest = async ({
  request,
  params,
}: {
  request: Request;
  params: { path?: string | string[] };
}): Promise<Response> => {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsPreflight() });
  }

  const path = splat(params.path);
  const incoming = new URL(request.url);
  const target = `${UPSTREAM}/${path}${incoming.search}`;
  const headers = new Headers();
  headers.set("Accept", request.headers.get("Accept") ?? "application/json");
  headers.set("Content-Type", request.headers.get("Content-Type") ?? "application/json");
  headers.set(
    "User-Agent",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36",
  );
  copy(request.headers, headers, [
    "ds",
    "x-rpc-app_version",
    "x-rpc-client_type",
    "x-rpc-language",
    "x-rpc-lang",
  ]);
  const cookie = request.headers.get("Cookie") ?? cookieFromParts(request.headers);
  if (cookie) headers.set("Cookie", cookie);

  const response = await fetch(target, {
    method: request.method,
    headers,
    body: request.method === "GET" || request.method === "HEAD" ? undefined : request.body,
  });
  return new Response(response.body, {
    status: response.status,
    headers: corsHeaders(response.headers),
  });
};

function splat(path: string | string[] | undefined): string {
  if (Array.isArray(path)) return path.join("/");
  return path ?? "";
}

function cookieFromParts(headers: Headers): string | null {
  const ltuid = headers.get("X-Ltuid");
  const ltoken = headers.get("X-Ltoken");
  if (!ltuid || !ltoken) return null;
  return `ltuid_v2=${ltuid}; ltoken_v2=${ltoken}`;
}

function copy(from: Headers, to: Headers, names: string[]): void {
  for (const name of names) {
    const value = from.get(name);
    if (value) to.set(name, value);
  }
}

function corsPreflight(): Headers {
  const headers = new Headers();
  headers.set("Access-Control-Allow-Origin", "*");
  headers.set("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
  headers.set("Access-Control-Allow-Headers", "Content-Type, ds, x-rpc-app_version, x-rpc-client_type, x-rpc-language, x-rpc-lang, X-Ltuid, X-Ltoken");
  return headers;
}

function corsHeaders(source: Headers): Headers {
  const headers = new Headers(source);
  headers.set("Access-Control-Allow-Origin", "*");
  return headers;
}
