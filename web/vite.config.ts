import { defineConfig, type Plugin } from "vitest/config";
import react from "@vitejs/plugin-react";
import type { ProxyOptions } from "vite";
import type { IncomingMessage } from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(root, "..");
const abyssIcons = path.resolve(
  repoRoot,
  "Sources/NSLauncherApp/Resources/Abyss/icons",
);

function header(value: string | string[] | undefined): string | undefined {
  if (Array.isArray(value)) return value[0];
  return value;
}

function abyssIconPlugin(): Plugin {
  return {
    name: "abyss-icons",
    configureServer(server) {
      server.middlewares.use("/icons", (req, res, next) => {
        const rel = decodeURIComponent((req.url ?? "").split("?")[0] ?? "");
        const file = path.normalize(path.join(abyssIcons, rel));
        if (!file.startsWith(abyssIcons)) {
          next();
          return;
        }
        if (fs.existsSync(file) && fs.statSync(file).isFile()) {
          res.setHeader("Content-Type", "image/png");
          res.setHeader("Cache-Control", "public, max-age=86400");
          fs.createReadStream(file).pipe(res);
          return;
        }
        next();
      });
    },
    closeBundle() {
      const dest = path.resolve(root, "dist/icons");
      fs.cpSync(abyssIcons, dest, { recursive: true });
    },
  };
}

const apiProxy: Record<string, ProxyOptions> = {
  "/api/enka": {
    target: "https://enka.network",
    changeOrigin: true,
    rewrite: (p) => p.replace(/^\/api\/enka/u, ""),
  },
  "/api/hoyolab": {
    target: "https://sg-public-api.hoyolab.com",
    changeOrigin: true,
    rewrite: (p) => p.replace(/^\/api\/hoyolab/u, ""),
    configure(proxy) {
      proxy.on("proxyReq", (proxyReq, req: IncomingMessage) => {
        const ltuid = header(req.headers["x-ltuid"]);
        const ltoken = header(req.headers["x-ltoken"]);
        if (ltuid && ltoken) {
          proxyReq.setHeader("Cookie", `ltuid_v2=${ltuid}; ltoken_v2=${ltoken}`);
        }
      });
    },
  },
};

export default defineConfig({
  plugins: [react(), abyssIconPlugin()],
  server: {
    fs: { allow: [repoRoot] },
    port: 5173,
    proxy: apiProxy,
  },
  preview: {
    port: 4173,
    proxy: apiProxy,
  },
  resolve: {
    alias: {
      "@": path.resolve(root, "src"),
    },
  },
  test: {
    environment: "node",
  },
});
