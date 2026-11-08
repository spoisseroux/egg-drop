# Egg Drop — November7 afternoon play build

This historical v125 handoff is superseded by [the living Hollow and arcade build](PLAY-BUILD.md), which records the current release and evidence.

**Private v125 Published**, verified in refreshed Studio Version History, titled **Pocket Deck hardware and companions - f813d61**. Runtime `f813d61` is committed and pushed on `feat/egg-drop-arcade-polish`. This supersedes the overnightv93 build. [Private play link](https://www.roblox.com/games/96451847774961/Egg-Drop) · [Publication proof](artifacts/hardware-companion-2026-11-07/private-published-f813d61.png).

## What changed

- Pocket Deck has inset rounded instruments, a subtle animated repeating backdrop that follows the shell, compact current/next and quest indicators, centered animated drop supply, and faint unstroked bank regions.
- Jelly is generated procedurally at64×107 with bounded GUI spans and fixed screen-space light. It does not rotate a pre-lit PNG. The optional EditableImage path remains unavailable under this place's existing settings; the tested fallback needs no settings change.
- Menu/shop share measured wallet/title/bare-X headers. Egg costs align under names, fresh rows clear headers, focused recipe buttons survive reflow, and roam uses separate48px Menu/Deck circles.
- Lounge pets are72% of authored hatch size, with subtle distance-driven gait and a bounded cadence. Crests sit above full silhouettes. Hatch models retain full size.
- Focus stays open until Back. Tap the pet for a grin; rub for a quiet original purr. Release/interruption stops it. No Greet button. First-session instructions retire after contact or leaving the taught visit.
- Original53⅓s music and2s purr are uploaded and connected. **Menu → Deck style → Club**, scroll to Music/SFX. Music On/Off is independent and lasts this joined session; saved SFX Full/Quiet/Off still controls the master. Sound Off is silent.
- Workbench/journal counters rise to avatar waist. Existing native Style deck/Open journal/Browse eggs prompts are shorter and offset clear of the avatar on tested approaches. No new shops or economy.

## What the player does

New players earn guaranteed Pip on the welcome board, then meet it in Sprout Hollow. Returning players enter the lounge. Open the deck, aim matching jellies at the left objective and then right, and keep the pile low over24 drops. Win for6nectar or8with the low-pile bonus; first daily skill contracts can add more. Failed completed runs can still progress skill contracts.

Spend18nectar on Mixed Meadow or24on Sprout Focused. Outcomes are random from the displayed pool. The collection is Pip, Puddle, Wick, Orbit, Bloom Pip, Foxfire Wick and Eclipse Orbit. After seven non-rare hatches the next is rare; it does not guarantee a missing common. A duplicate adds a family mark. Clean wins add2marks, ordinary wins1; ranksI/II/III at3/10/25 unlock progressively richer crests/effects, with skill conditions forIII. Optional daily nectar and contracts give return goals; there is no daily play cap or paid luck.

Walk to the hatch tree, journal or workbench, or use quick Menu shortcuts. Merely entering a station never spends anything. Click the companion to focus, rub it, then Back to roam. Leaving for the lounge pauses the current round; reconnecting restarts an unfinished round. [Full existing loop/odds/save rules](HATCH-LOOP.md).

## Exact verification

Astra reviewed architecture, source, fixture deltas and screenshots; Sol implemented. Each slice was tested and committed before the next.

Final fresh native Medium: **113 cases**, comprising station geometry/priority24, hatch actions/navigation/browse38, reward10, handheld23, recap16, quiet save ownership2. Earlier frozen contact/audio snapshot passes76 core cases at both actual Medium/Largest preferences, plus save-layout9, ownership2, headers12 and return-camera15 at each; controller semantic22+8 and additional scale/camera checks are separately recorded. Do not add repeats as unique coverage. The unchanged authority sources pass34 isolated server save/transaction cases.

Actual final route used read-only aim selection with **24 real pointer drops**: score/best640, peakchain4,0tierVclears, both objectives, clean8+contracts6=14nectar, saved bank6→20. One explicit18Meadow hatch yielded duplicatePip, bank2, one extra mark→earnedrankI. X/reopen kept the sameID/revision; Meet acknowledged it once and Back restored Custom camera/walk16/no jump. Server observer recorded **one hatch + one ack**.

Actual native E, touch and virtual Gamepad1X/B station paths pass without spending. Actual rub/purr/release and Music/SFX six-state matrix pass. Engine music crossed two natural boundaries with its start count unchanged; purr crossed five during one moving rub. Zero Music requests reached the save server in the observed local-toggle probe. These are playback/input observations, **not an audible mix audition**.

All65correct-place sources hash/compile against disk, Rojo builds, diff checks and QA-instance cleanup pass. Final console contains known optional EditableImage/asset203785492 warnings. Medium and desktop restored; Studio Edit; Egg Drop Rojo34873 connected.

## Evidence and limits

[Handheld/renderer gallery](artifacts/hardware-companion-2026-11-07/renderer-gallery.md) · [Headers](artifacts/hardware-companion-2026-11-07/headers-gallery.md) · [Companion scale](artifacts/hardware-companion-2026-11-07/companion-gallery.md) · [Petting/music](artifacts/hardware-companion-2026-11-07/contact-gallery.md) · [Stations and full loop](artifacts/hardware-companion-2026-11-07/station-integration-gallery.md) · [Detailed build notes](HARDWARE-AND-COMPANION-PASS.md).

Phone evidence is Studio emulation, controller evidence is the native diagram plus separately labeled semantic edge cases. No physical-device comfort/performance, live multiplayer, live-client save/rejoin, audible transcode seam or fun/retention claim. Fixed station offsets are approved for photographed ordinary approaches; arbitrary orbit angles can still overlap. Ordinary Roblox table climbing remains. A free-roam camera under branches can still be obscured.

Nursery, paid products and public release remain deferred.

## Small UI edits yourself

Edit `src/client/DeckLayout.lua`'s Settings near the top for simple layout tuning: MenuOffsetX/Y, LoungeOffsetX/Y, ControlCenter, ScreenGap and QuestHeight. Use small changes (for example MenuOffsetY=-4 moves Menu up4logical pixels), then restart Play and inspect desktop plus phone. `src/shared/DeckThemes.lua` owns shell/backdrop colors; `src/client/DeckArt.lua` owns shared UI materials/type.

The interface is created by code. Dragging generated objects during Studio Play is temporary; Rojo/source remains the saved version. Ask for a specific position change if a setting doesn't cover it; preserve44px touch targets and screen separation.
