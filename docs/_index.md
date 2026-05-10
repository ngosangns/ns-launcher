# Docs Index

## Project

- [Architecture](architecture.md) describes the current app layers, installer strategies, download behavior, progress flow, and runtime integration.
- [Genshin Install Plan](genshin-install-plan.md) describes the current Genshin MVP behavior, supported sources, remaining work, and risks.

## Modules

- [Downloader Optimization](modules/downloader-optimization.md) documents the current manifest and Sophon downloader design, concurrency limits, resume sidecars, verification, and tuning constraints.

## Planning

- [Fix Genshin Stale Update Source](specs/planning/fix-genshin-stale-update-source.md) describes the guard against stale HoYoPlay package metadata during update checks.
- [Implement Game Update](specs/planning/implement-game-update.md) describes the manifest-backed update flow.
- [Implement Genshin Sophon Update](specs/planning/implement-genshin-sophon-update.md) describes the HoYoPlay Sophon chunk update path for Genshin 6.x.
- [Optimize Genshin ScatteredFiles Downloads](specs/planning/optimize-genshin-scatteredfiles-downloads.md) describes the native ranged downloader strategy for official file-level installs.
- [Optimize Genshin Sophon Downloads](specs/planning/optimize-genshin-sophon-downloads.md) describes the chunk downloader optimization strategy for Sophon assets.

## Sync

- [Sync State](_sync.md) records the commit reflected by the docs.
