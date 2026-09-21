import { defineConfig, type Plugin } from "vitest/config";
import react from "@vitejs/plugin-react";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(root, "..");
const abyssIcons = path.resolve(
  repoRoot,
  "Sources/NSLauncherApp/Resources/Abyss/icons",
);

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

export default defineConfig({
  plugins: [react(), abyssIconPlugin()],
  server: {
    fs: { allow: [repoRoot] },
    port: 5173,
    proxy: {
      "/api/enka": {
        target: "https://enka.network",
        changeOrigin: true,
        rewrite: (p) => p.replace(/^\/api\/enka/u, ""),
      },
      "/api/hoyolab": {
        target: "https://sg-public-api.hoyolab.com",
        changeOrigin: true,
        rewrite: (p) => p.replace(/^\/api\/hoyolab/u, ""),
      },
    },
  },
  preview: {
    port: 4173,
    proxy: {
      "/api/enka": {
        target: "https://enka.network",
        changeOrigin: true,
        rewrite: (p) => p.replace(/^\/api\/enka/u, ""),
      },
      "/api/hoyolab": {
        target: "https://sg-public-api.hoyolab.com",
        changeOrigin: true,
        rewrite: (p) => p.replace(/^\/api\/hoyolab/u, ""),
      },
    },
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
