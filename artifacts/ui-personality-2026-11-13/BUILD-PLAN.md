# UI personality pass: build plan (2026-11-13)

Spencer approved `UI-PERSONALITY-SCOPE-2026-11-13.md` ("proceed with all recommended"): Fredoka One display face,
button lips + stitched seams, copy voice + string table, pet peek (desktop first), fixed house palette with one tint
per screen, a face on the Star. Built after private v550 (0cc2c3a). Layout, hit areas and focus order never move.

## Goal

The menus and the Pocket Deck screens read as Egg Drop, not a generic dark dashboard, with no layout change and no
readability loss on phones (12 px floor, 4.5:1).

## Slices (one Studio; implementers write code + specs, coordinator tests in Studio)

| Slice | Tweaks | Owns |
|---|---|---|
| P1 Kit + strings | T1 Fredoka One display role, T3 copy voice, T5 fixed house palette + per-screen tint, T8 hint caps | `DeckKit.lua` (`Kit.Type` new `Name` role, `Title`, button label; `Kit.header` option `tint`; `Kit.glyph` caps), `DeckArt.lua` house palette (already fixed to the default plate in v550), new `src/shared/UICopy.lua` string table, string call sites in `EggHatchView`, `DeckResults`, `FaceplateShop`, `BackgroundShop`, `BallShop`, `QuestLog`, `PocketMenu`, `ItemCarousel` notes/toasts; hand-set `FontFace` sweep; two tiled images (squiggle, halftone) |
| P2 Surfaces | T2 lips + seams, T6 sticker chips, T7 LCD dot grid wells, T11 motion signatures | `DeckKit.lua` (`Kit.button` secondary edge, new `Kit.tile`, `Kit.card{seam=true}`, `Kit.chip` kind `sticker`, `Kit.well`, `Kit.boing`, tab squash, counter tick), hand-built tiles in `EggHatchView`, `FaceplateShop`, `BackgroundShop`, `BallShop`, `CustomizeCards`, `CompanionsHub`, `WardrobeShop`; seam 9-slice + dot grid images |
| P3 Pet + Star | T4 pet peek (desktop only), T9 Star face, T12 empty states | new `PetPeek.lua` on `PetPortrait`; hosts `EggHatchView`, `DeckResults`, Deck style screen; Star face cell for `Kit.wallet` + overlay on the results 3D Star (hidden past 40 degrees yaw); empty states in `QuestLog`, `WardrobeShop`, item belt, `PocketMenu` locked rows |

Order: P1 first (Kit tokens other slices read), P2 after P1 lands (both edit `DeckKit.lua`), P3 can run beside P2
because it touches different files, except `EggHatchView` / `DeckResults` (P3 edits only its peek host lines, anchored).
T10 icon redraw is deferred (one atlas upload, no behaviour).

## Rules

- Fredoka One (`rbxasset://fonts/families/FredokaOne.json`) only at 15 px and up, never sentences or numbers.
- Buttons keep plain verbs; facts (odds, prices, "never an advantage") are stated exactly.
- Every new string fits the width of the line it replaces on the 812 x 354 layout.
- Tints are decoration only; mint is the only action colour, gold only Stars.
- Every motion is cut under Reduced Motion. Phones skip the peek and the halftone.
- No per-frame allocation; peek blink and Star blink run on one shared timer.

## Edge cases

| Case | Expected |
|---|---|
| Fredoka title wider than the header slot | Truncates (`TextTruncate.AtEnd`), never wraps |
| No pet equipped / fresh save | No peek; empty-state line without the pet |
| Reduced Motion | No boing, squash, tick, peek hop or Star blink |
| Phone 812 x 354 | Lips 3 px, no seam under 150 px tall cards, no peek, no halftone |
| Peek would cover the wallet or text | Clip frame; peek hidden when its slot is under 64 px |
| Star hero spinning | Face hidden past 40 degrees of yaw |
| Asset not uploaded yet | Seam, squiggle, halftone, dot grid and Star face fall back to nothing |

## Tests

- Specs: `SharedHeaders`, `DeckScreen`, `DeckStyle`, `DeckResults`, `HatchEggsList`, `CompactPhone`, `UsableSheetWidth`,
  `ControllerSheets`, `CustomizeRedesign`, `CompanionsHub` (geometry must not move); new `UICopy` spec (every string
  fits its phone width with `TextService:GetTextBoundsAsync`), `KitSurfaces` spec (lip/seam/sticker rules, Reduced
  Motion), `PetPeek` spec (clip, no focus, phone off, no allocation per frame).
- Studio captures of Hatch eggs, results, Deck style (three tabs), Companions, Quests, Pocket Menu at 1920 x 1080 and
  812 x 354 against the scope mockups.

## Not in this pass

T10 icon redraw (later, one atlas upload); translations (separate v1 item).

## Architect review changes (2026-11-13)

1. **Pet peek (P3) is 3D, not PetPortrait.** `PetPortrait` is a 13x13 hue-only sprite with no charm or wearables, so
   the approved "your own pet with hue, charm and wearables" needs the 3D pet: build `PetPeek` on the viewport pet in
   `CompanionsHub.lua` / `WardrobeShop.lua`, one cached ViewportFrame reparented between hosts (never rebuilt per open),
   camera and blink paused while hidden, destroyed at session end; off on phones and under Reduced Motion.
2. **Text measuring follows the role font.** New `Kit.measure(text, role, size)` (font from `Kit.Type[role][3]`, via
   `TextService:GetTextBoundsAsync`, cached); `Kit.chip`, `Kit.glyph`, `Kit.tabs`, `Kit.tabIconsFit` and the toaster
   switch to it, so Fredoka labels never clip and tab dots stay aligned.
3. **One owner for display type.** `Kit.Type` owns Fredoka (`Name`, `Title`, button label). `DeckArt.Art.Font` /
   `Art.SheetFont` / `Art.type` stay Builder Sans; `CelebrationKit` and the `DeckScreen` banner are untouched.
   `PlayfulPresentation.spec` is updated deliberately only where a Kit role changes.
4. **Strings move with their specs.** `src/shared/UICopy.lua` with semantic nested keys (`results.leave.wide`,
   `results.leave.narrow`, `hatch.footer.phone`) and `UICopy.get(key, vars)` with `{count}` placeholders (no string
   concatenation; translations slot in later). Every exact-string spec (`SaveNoticeLayout`, `DeckResults`, ...) asserts
   `UICopy.get(key)` in the same commit; all three `DeckResults` layout branches use the same keys.
5. **Every Kit API lands in P1 as working stubs:** `Kit.measure`, `Kit.tile`, `Kit.well`, `Kit.boing`, chip kind
   `sticker`, `Kit.card{seam=}`, `Kit.header{tint=}`. P2 and P3 only fill bodies and edit call sites.
6. **Press depth stays compatible.** Lip depth is a parameter; secondary buttons keep the 2 px press the
   `DeckScreen` spec checks unless that spec changes in the same commit; `buttons[button]` state keys and `Kit.pulse`
   stay.
7. **Rotated stickers clip:** sticker chips get 3 px clearance and never sit at a scroll area's edge.
8. **Missing asset ids create nothing** (no empty grey ImageLabels): seam, squiggle, halftone, dot grid, Star face.
