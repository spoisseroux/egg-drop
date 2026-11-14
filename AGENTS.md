# Egg Drop agent workflow

Spencer's standing instruction, 8 November 2026:

- Use **Astra** (`gpt-6-astra`) for 3D models, assets, music, UI/UX, visual and audio direction, and critique. Astra owns the creative brief and reviews actual rendered results.
- Use **Sol 6.1 High** (`gpt-6.1-sol`, high reasoning) for implementation code. This includes runtime systems, UI construction and asset tooling, following Astra's direction.
- The primary agent coordinates integration, actual Studio controls, tests, evidence and release checkpoints. Follow the review-driven-build skill for substantial implementation changes.
- Work in this Egg Drop repository on the authorized branch. Studio target is place **96451847774961**; never modify the other `roblox_suica_collector` project/place.

Keep `TODO.md` current while working: update **Now working on** when a task starts, check items off when they land, and add new findings as they come up. Do not wait until the end of a session.

Current approved creative direction: original quirky, expressive baby pets; a lively shared garden with the existing day/night cycle; one earned **Stars** wallet; optional floating charms using each pet's secondary palette. Read `CHAO-GARDEN-DIRECTION.md` before choosing an implementation slice. The new roster, wallet conversion, egg types, stats and world redesign are proposals until implemented and verified. Read `PLAY-BUILD.md` and the latest build evidence to distinguish repository checkpoints from the published private place.

## Every build: translations (Spencer, 2026-11-13)

Before each publish, keep the cloud localization table current so Roblox auto-translates new or changed text:

1. `python scripts/export_localization_csv.py` (regenerates `assets/localization/egg-drop-strings.csv` from UICopy + catalogues).
2. `python scripts/sync_localization.py` (pushes adds/changes and deletes removed strings it created; state in `assets/localization/synced.json`, commit it). It needs `ROBLOX_LOCALIZATION_KEY` (Open Cloud key, scope `legacy-universe:manage`) in `~/.claude/.env`; without it, `--emit DIR` writes PATCH bodies to send through Studio MCP `open_cloud_invoke` (needs that scope granted in Studio's Assistant MCP Permissions), then `--mark-synced`.
3. Record "translations synced (N add/update, M delete)" in the build's PLAY-BUILD entry.
