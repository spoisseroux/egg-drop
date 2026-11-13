# Compact (phone landscape) Studio captures, 2026-11-12

Built from `UI-SPEC-COMPACT-2026-11-12.md`; compare with `../../mockups/compact/`.

**How they were taken (FIXTURE sizing, live game).** In a Studio Play client the `EggDrop.Backdrop` frame was forced to the phone size (`Position (40,40)`, `Size W x H`; the deck host, overlays and safe content follow it), `PlayerGui:SetAttribute("FixtureKeepOut", Vector2.new(116, 58))` pinned the Roblox-controls keep-out to the spec's value (desktop Studio reports `TopbarInset.Min.X = 208`), and two 6 px magenta markers were placed 10 px outside the root's top-left and 4 px outside its bottom-right. `scripts/deck_art/crop_fixture_capture.py` finds the markers, crops the root and resizes it back to W x H (Studio captures arrive at about 0.91 scale, so text is slightly soft). For the faceplate shop the backdrop was set 16 px larger so the overlay content root is exactly W x H.

Everything else is the real game: a fresh save, five drops for the first pet, real rounds, the Studio-only `EggDropRoundTestHook` to finish a field through the award path, the real quest log, a real claim, and a real 40-Star purchase (Studio grant).

| File | State |
|---|---|
| `01-round-hud-*` | Guided Easy round, keyboard input |
| `01b-round-hud-quest-drawer-*` | Drawer open from the handle |
| `02-difficulty-picker-*` | Opened by the new Change difficulty button on Results |
| `03-results-*` | Hard win with a finished quest (Claim shortcut) |
| `03-results-easy-hatch-*` | Easy win, "You can hatch an egg" shortcut state |
| `04-quest-log-daily-*`, `04-quest-log-daily-ready-740x360` | Daily tab (ready rows reached from the results shortcut) |
| `05-quest-log-weekly-740x360`, `06-quest-log-history-740x360` | Weekly and History tabs (not drawn in the mockups) |
| `07-faceplate-shop-*` | Garden shop, Aurora Glass selected, Buy 40 |

932x430 and 568x320 are covered by `scripts/CompactPhone.spec.lua` (geometry tables, targets, keep-out, text), not captured. Not checked: a real phone, Studio device emulation, or the DeviceSafeInsets switch itself (the desktop Studio window is never compact, so the probe kept CoreUISafeInsets).
