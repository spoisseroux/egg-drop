# Deck Aero brief (Fable, 2026-11-28, beta 44)

Spencer: "make the ui on the pocket deck game screen and first pocket onboarding deck game screen look less vibe codey, more frutiger aero, with reassignment colors for everything depending on the faceplate".

Scope: the round HUD, the well's frame, in-place results, WelcomeDeck2. Looks only: no rect, hit area, focus order or copy changes. Builds on ONBOARD-SIMPLIFY-BRIEF section 3 (Goals rows, results 8 px gaps): that lane owns geometry, this one owns surfaces and colour. Everything is Frames, UICorner, UIStroke, UIGradient, plus one tile we already render (`scripts/deck_art/build_aero_caustics.py` → `assets/ui/aero-caustics-512.png`, not uploaded yet).

## 1. What reads "vibe codey" (shot-67, 68, 70, 75, 76)

- **Cards**: flat single-colour navy boxes, 2 px ink outline `#15143A`, one 1 px highlight. No depth, all seven identical.
- **Tag pills**: six unrelated fixed colours (`Kit.HudTabColors`: yellow, green, red, sky, orange, gold), hard ink edge, 2 px grey lip. Colour means nothing and ignores the plate.
- **Numbers**: Roboto Mono with a slashed zero (SCORE `0`, `×0`, `24 /24`) is a terminal font.
- **Chain dots, bars, check rings**: flat ink blobs and flat green on the card colour.
- **Well**: near-black with hairline lane rules and a boxed "FILL LINE" label; the board looks like a debug view beside the glossy plate around it.
- **Results**: cream keys with ink outlines and lips (Toy Shell) on a flat navy pane; "○" typed as a character.
- **WelcomeDeck2** (shot-70): three surface languages side by side: a flat saturated blue card, a dark NEXT card, a pale egg card; radii differ. "Click to drop" also shows twice (bubble and well foot): drop the foot copy.

## 2. Target: glass on an LCD

New recipe `Glass.card(frame, radius)`. Radius **16 regular, 12 compact/phone** (Feel.Polish 18 → 16). Layers are children at the card's ZIndex, built once:

| Layer | Build | Values |
|---|---|---|
| Shadow | sibling Frame under the card, same radius | offset (0, 3), black, transparency .70; skipped when the gap to the next card is under 8 |
| Body | card BackgroundColor3 white + UIGradient 90° | `glassTop` 0 → `glassBottom` 1 |
| Rim | UIStroke Border 1.5 px replacing the ink outline, with its own UIGradient 90° | colour `rim`; transparency .15 top → .70 bottom |
| Gloss | Frame inset 2, top 46% of the card, radius − 2, white, UIGradient 90° | transparency **.90 → .96**, hard lower edge |
| Bounce | Frame, bottom 35%, colour `accent`, UIGradient 90° | transparency 1 → .84 |
| Streak | full-size white Frame, same corner, UIGradient 25° | transparency keys 0: 1, .30: 1, .33: .93, .36: 1, .39: .96, .42: 1 (static; it is also the sweep, section 5) |
| Caustics | `AeroUI.caustics(card)` once the tile is uploaded | 6% alpha, Goals and Next only |

Retire on these cards: `Kit.stroke` ink outline, `Kit.sink`, FeelHighlight, FeelInner, the stitched seam.

**Pills** (every eyebrow, the level name, ★ ×0.8, FILL LINE, LEFT/RIGHT): full radius, 22 tall (20 compact), pad 10 (8); fill UIGradient 90° `pill` mixed 55% to white → `pill`; UIStroke 1 px white at .45; text `ink`, Builder Sans Bold 12 caps. No lip, no tilt, no ink edge. One pill colour per plate; a pill changes colour only for state: Goals complete → `good`, Chain live → `warn`, Balls ≤ 3 → `bad`.

**Tracks** (balls bar, goal bars, chain dots): full radius, 8 tall (6 compact); track = `glassBottom` mixed 60% to `ink`; fill UIGradient 90° `accent` mixed 35% to white → `accent`. Chain dots: empty = track, lit = `warn` with a 2 px white dot at upper left.

**Well frame**: UIGradient 90° `wellTop` → `well`; UIStroke 1.5 px `rim` at .55; keep the 3 px top shadow; lane columns `accent` at 6%; rules and the fill line stay white mixes (`theme.lcd`). The board pixels do not change.

**Keys** (results, "Click to drop", Skip): same rects and lips as the other lane lays out. Primary: UIGradient `#7BEE8C` → `#2FC552`, rim white .4, gloss top half .72 → .9, ink label. Secondary: `#FFFFFF` → `#DDEBFA`, ink label; the lip is the face mixed 30% to `ink` (no ink outline).

**Type** (built-ins with a legacy twin, so `Kit.measure` stays exact): numbers move to **Builder Sans ExtraBold** (two new roles `HudCounter` 18/15 and `HudCounterL` 34/22; Roboto Mono leaves the deck HUD); the level name, key labels and "Drop a ball!" stay **Fredoka One** (15 and up); body **Builder Sans Medium** 15 (13 small deck); pills Builder Sans Bold 12. Nothing under 11 px at 600x360.

## 3. Palette: every colour from the plate

New pure module `Shared/DeckGlass.lua`: `DeckGlass.palette(theme)` → frozen roles. Source is the plate's `toyShell` row, whose roles are already solved to one luminance on every deck, so contrast is the same everywhere.

| Role | Rule |
|---|---|
| `glassTop` | `toy.shell` |
| `glassBottom` | shell mixed 55% to `shellLip` |
| `rim` | `shellHi` mixed 45% to white |
| `accent` | plate `accent` |
| `pill` | `toy.tag` |
| `ink` / `text` / `soft` | `toy.ink` / white / `toy.onShellSoft` |
| `well`, `wellTop` | `toy.well`; well mixed 12% to accent |
| `good` / `warn` / `bad` | fixed `#43DB5F` / `#FFC14D` / `#FF5A4D` (state never changes with the skin) |

Bookworm and Stargazer have no `toyShell`: solve `deep` to luminance .131 (shell), .045 (lip), .011 (ink, well), and `deep` mixed 35% to accent to .37 (hi); pill = accent. Add these rows to DeckThemes so they stop falling back to Classic blue.

| Plate | glassTop | glassBottom | rim | accent | pill | ink | soft | wellTop |
|---|---|---|---|---|---|---|---|---|
| Scout | #0E735B | #095946 | #A5D4C9 | #76F6B0 | #A4F57C | #0A1B17 | #CDEFE7 | #1B3441 |
| Pebble | #426F51 | #32553E | #BCD1C2 | #C8EB9B | #C9F08A | #0A1C10 | #CEF0D9 | #25333F |
| Creek | #186F84 | #115566 | #ABD1DB | #70ECFF | #70ECFF | #0B1A1E | #D1ECF3 | #1B334B |
| Ember | #BE2E37 | #942129 | #F2BDC0 | #FF9B70 | #FF9B70 | #2A1011 | #FFE0E2 | #4B201C |
| Canopy | #23752E | #1A5A22 | #AFD4B4 | #BCF57B | #BCF57B | #0A1C0D | #CEF0D2 | #1E3919 |
| Honey | #945709 | #724305 | #E0C7A8 | #FFD77D | #FF9838 | #1F170C | #F4E6D2 | #3D3019 |
| Gloaming | #5A5ABC | #454592 | #C9C9EB | #92ECE6 | #92ECE6 | #141435 | #E6E6FF | #232E57 |
| Copperleaf | #A54B2B | #7F391F | #E6C4B7 | #FFBC90 | #FFBC90 | #24140E | #FCE2D8 | #44291D |
| Aqua Pop | #0E69AB | #085184 | #ACD0E8 | #6FE3FF | #6FE3FF | #0D1A22 | #D6EBF9 | #183441 |
| Lime Gel | #37730E | #295909 | #B8D4A5 | #B6F24B | #B6F24B | #111B0A | #DAEECC | #253711 |
| Sorbet Sky | #B63363 | #8D254B | #EEBDCF | #FFB37A | #FFB37A | #291019 | #FEE0EB | #4A2326 |
| Liquid Chrome | #526689 | #3E4E6A | #C4CCDB | #DCE6F5 | #DCE6F5 | #0F1827 | #DDE8FB | #273348 |
| Tidepool | #1C62C9 | #134B9D | #B5CDF0 | #5CD6E8 | #5CD6E8 | #0F1827 | #DAE9FE | #173144 |
| Aurora Glass | #5246FB | #3E34C6 | #C9C6FC | #7CF5C4 | #A8F27A | #161433 | #E6E5FE | #232F51 |
| Prism Flare | #96459C | #743478 | #E1C1E4 | #F3B6FF | #F3B6FF | #260F27 | #FBDFFD | #442248 |
| Night Orb | #7A3CE7 | #5E2CB5 | #D6C2F8 | #FF7AD9 | #FF7AD9 | #1D1230 | #EDE3FD | #3C1E4D |
| Bookworm | #366E6B | #245653 | #B5D2CF | #7FE0CF | #7FE0CF | #0A1E1D | #C3F0E8 | #183632 |
| Grape Soda | #8A46B7 | #6B348E | #DBC2EB | #C9A6FF | #C9A6FF | #21112C | #F1E2FB | #3A224D |
| Rose Chrome | #994C72 | #763A58 | #E1C3D2 | #FFC2D4 | #FFC2D4 | #29101C | #FEDFEE | #492435 |
| Stargazer | #616381 | #494C6E | #CACCDB | #B9C6FF | #B9C6FF | #151839 | #E1E6FF | #282D51 |
| Cloud Glass (default) | #2667AD | #1B4F86 | #B5CEE8 | #8FD2FF | #BFE6FF | #0E1924 | #D8EAFC | #1D3244 |
| Lagoon | #107171 | #0A5757 | #A5D3D3 | #6FF0E0 | #7CFFD2 | #0A1B1B | #CCEEEE | #1B3447 |
| Dewy Meadow | #13753D | #0D5A2E | #A8D5BB | #8CF07A | #F6C9E6 | #0A1C12 | #CEEFDC | #1E343B |
| Sky Fizz | #186D94 | #105472 | #AED0E1 | #7FDCFF | #FFB3DA | #0C1A20 | #D4EBF6 | #1C314B |
| Storm Glass | #4565A4 | #344D7F | #C0CCE4 | #A9C4F2 | #C4B5FF | #0F1828 | #DDE8FC | #212E47 |

**Contrast, computed across all 25 plates (worst case)**: white on the body 5.7:1, white under the 10% gloss 4.6:1, `soft` on the body 4.7:1, `soft` under the gloss 3.8:1, `ink` on `pill` 7.6:1, `ink` on `accent` 7.6:1, fills on their track: accent 5.9, good 7.3, warn 8.2, bad 4.3; gold on the body 3.6:1.

Rules that follow:
1. Gloss never stronger than 10% white where text sits.
2. `soft` text only below the gloss line, or at 14 px bold and up; otherwise white.
3. Gold and state colours as text only at 18 px bold and up (Chain, Win pays); smaller, they go on a pill with ink text.
4. Accent and state fills always sit on a track, never bare on glass (accent on glass is as low as 2.1:1).
5. A spec asserts these floors for every plate in `Themes.Plates` (4.5 text, 3.0 large text and fills), so a new plate cannot ship unreadable.

**Results** take the same palette: pane = glass card; goals list per the other brief (tick disc in `good`, ring white 55%); metrics `soft` below the gloss line; "New best!" on a `warn` pill; keys as section 2. The Star, rays and count keep their own gold.

## 4. WelcomeDeck2

New players wear Cloud Glass, so it stays sky blue, now from the palette rather than `V2.Deck2` constants:

- **Sky card** (left): the glass card recipe with body `glassTop` mixed 25% to `accent` → `glassBottom` (white 26 px line stays 3:1 or better; lower the mix if a plate fails). Delete the hard 1 px highlight; the rim and gloss replace it. Bubbles: keep 3, rim white .7.
- **Egg card**: stays a light little world (sky over grass is the Aero motif): white mixed 35% to `accent` → `accent` mixed 35% to `glassTop`; grass arc and blob shadow unchanged; same rim, radius and gloss as the sky card.
- **NEXT**: a normal glass card with the plate pill.
- All three share radius 12 and the 1.5 px rim. Pips: empty = track colour, filled = existing gold.
- "Click to drop": secondary key recipe, 2 px `good` rim.

## 5. Motion (subtle, cheap)

- **Gloss sweep**: the Streak's gradient Offset tweens (−1, 0) → (1, 0) in 0.35 s when a card's value changes (score, goal ticked, chain up, ball spent), at most once per card per 1.2 s. One TweenService tween, no Heartbeat.
- **Bubble drift**: Goals and Next only, 2 bubbles each (8 and 12 px, white 10%, rim .7), rising on one looping tween each (7 s, 9 s). None on phone or compact.
- Existing punches, pops and counters stay.
- Reduced Motion or `AliveBudget` low: no sweep, no bubbles, no caustics scroll; the static glass is unchanged.

## 6. Files, phases, risks

**Must tonight** (beta only, behind a new Alive switch `deckglass`; off = today's HUD path for path):
1. `src/shared/DeckGlass.lua` (new): palette + contrast helpers; spec `ZZSpecs/DeckGlass.lua` with the floors above.
2. `src/shared/DeckThemes.lua`: `toyShell` rows for Bookworm and Stargazer.
3. `src/client/DeckKit.lua`: `Kit.glass(card, radius)`, glass branch in `Kit.hudLabel` and `Kit.progress`, the two counter roles.
4. `src/client/DeckFeelScreen.lua` `View:built` / `View:pill`: call `Kit.glass` in place of FeelHighlight / FeelInner, pill state colours, well frame; `DeckFeel.Polish.radius` 16.
5. `src/client/DeckScreen.lua`: counter roles, chain dots, lane tint.
6. `src/client/WelcomeDeck2.lua` + `OnboardV2.Deck2`: section 4.
7. `V3-TEST-PASS.md` row, switch `AliveDeckGlass`.

**Later**: results pane and keys (`DeckResultsInPlace`, `DeckFeelResults`, `Kit.button` glass variant) after the other lane's gap change lands; sweep and bubbles (`AeroUI`); upload the caustics tile and set `AeroUI.CausticsImage`; the picker and tour bubbles.

**Risks**
- Repaint on plate change: gradient colours must rebind. `Art.bind` takes property functions; confirm it accepts a UIGradient's `Color`, otherwise rebuild the HUD on theme change.
- Roughly 5 extra instances per card, 45 on the regular HUD: fine. Static gradients and strokes cost nothing per frame; never write gradient or stroke properties from Heartbeat.
- A UIStroke with a UIGradient on a TextLabel parent strokes the text: put rims on Frames only.
- Builder Sans digits are not fixed width: right-aligned counters may shimmer while rolling; keep those labels left-aligned or fixed width.
- Specs that read `HudTabColors`, card stroke colour or `Kit.Radius` (DeckHeader, KitSurfaces, DeckFit) need the switch-off path kept intact.
- Check with Reduce Transparency on, at 600x360, and on a phone before the beta publish.
