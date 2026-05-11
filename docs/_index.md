# Docs Index

## Project

- [Architecture](architecture.md) describes the current app layers, Sophon-only install/update flow, progress surface, and runtime integration.
- [Genshin Install Plan](genshin-install-plan.md) describes the current Genshin Sophon-only behavior, remaining work, and risks.

## Modules

- [Downloader Optimization](modules/downloader-optimization.md) documents the current Sophon downloader design, concurrency limits, resume sidecars, verification, pruning, and tuning constraints.

## Planning

- [Sophon-only Download Flow](specs/planning/sophon-only-download-flow.md) describes the completed migration away from archive/package/manifest download paths.
- [Fix Genshin Wine Kernel Driver Launch](specs/planning/fix-genshin-wine-kernel-driver-launch.md) describes the supported handling when Wine reports Windows kernel driver protection errors.
- [HoYoKProtect Wine Launch Handling](specs/planning/hoyokprotect-wine-launch-handling.md) records the no-bypass launch policy and targeted error guidance for `HoYoKProtect.sys`.
- [Genshin Launch Alternatives](specs/planning/genshin-launch-alternatives.md) evaluates GeForce NOW, Windows native, Boot Camp, and VM options when Wine cannot run the game.
- [Implement Genshin Sophon Update](specs/planning/implement-genshin-sophon-update.md) describes the HoYoPlay Sophon chunk update path for Genshin 6.x.
- [Optimize Genshin Sophon Downloads](specs/planning/optimize-genshin-sophon-downloads.md) describes the chunk downloader optimization strategy for Sophon assets.
- [Fix Genshin Stale Update Source](specs/planning/fix-genshin-stale-update-source.md) is historical context for the stale package metadata issue that led to Sophon-first updates.
- [Implement Game Update](specs/planning/implement-game-update.md) is historical context for the former manifest-backed update flow.
- [Optimize Genshin ScatteredFiles Downloads](specs/planning/optimize-genshin-scatteredfiles-downloads.md) is historical context for the removed file-level downloader path.

## Sync

- [Sync State](_sync.md) records the commit reflected by the docs.
