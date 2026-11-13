# UI personality pass: scope

13 November 2026. Scope and mockups only. Nothing here is built and nothing in `src/` changed.

Spencer: "I like the UI and layout now, but we should scope out how we could make the UI, and the UI in the Pocket Deck, feel less vibe coded and a bit more personality with some minor tweaks."

**Every layout stays exactly where it is.** The "proposed" mockups are the approved mockup functions run again with the shared components swapped, so no rect, size or focus order moves. They are concept drawings, not Studio captures.

| Picture | What it shows |
|---|---|
| [01 Hatch eggs, desktop](artifacts/ui-personality-2026-11-13/01-hatch-eggs-desktop-before-after.png) | Now and proposed, the 848 x 608 panel, side by side |
| [02 Round results, desktop](artifacts/ui-personality-2026-11-13/02-results-desktop-before-after.png) | Now and proposed, the deck LCD |
| [03 Deck style, Balls tab, desktop](artifacts/ui-personality-2026-11-13/03-deck-style-balls-desktop-before-after.png) | Now and proposed |
| [04 Hatch eggs, phone 812 x 354](artifacts/ui-personality-2026-11-13/04-hatch-eggs-phone-before-after-812x354.png) | Now and proposed, sheet below y = 60 |
| [05 Details at 2x](artifacts/ui-personality-2026-11-13/05-details-2x.png) | Header, tile, sticker, button, hint caps, wallet Star |
| [Hatch eggs](artifacts/ui-personality-2026-11-13/01-hatch-eggs-after-desktop-1920x1080.png), [results](artifacts/ui-personality-2026-11-13/02-results-after-desktop-1920x1080.png), [Deck style](artifacts/ui-personality-2026-11-13/03-deck-style-balls-after-desktop-1920x1080.png), [phone](artifacts/ui-personality-2026-11-13/04-hatch-eggs-after-phone-812x354.png) | The proposed screens alone, at 1920 x 1080 and 812 x 354 |

Generator: `python scripts/deck_art/build_ui_personality_mockups.py`.

## 1. Why it reads generic today

From the Studio captures in `artifacts/redesign-2026-11-12/studio/` and from `src/client/DeckKit.lua`:

1. **One box for everything.** A tile you can press, a pane that only shows information and a preview window are all the same dark rounded rect with a 1 px white 14% stroke (`Kit.card`, `Kit.frame`, radii 10 to 14). Only the focus ring says "press me".
2. **One typeface doing every job.** Builder Sans from 12 to 40 px. Titles, names and buttons differ only by size and weight. The only characterful type in the game is the results banner.
3. **Flat fills, no surface.** Panel, raised and well are three flat teal-greys. Nothing says "handheld LCD" or "plush garden".
4. **The pet never appears in the menus.** A game about a baby stuffed animal has menus with no animal in them, apart from the Companions portrait.
5. **Copy is accurate but mostly voiceless.** "Every egg lists its exact odds before you hatch it." A few lines already have voice ("Something is rattling around in here.", "Bear still thinks you're great."); they are the exception.
6. **Every chip is the same grey pill.** Price, tier, status and "New best" look alike, so the fun ones get no emphasis.
7. **Every screen is the same colour.** And once the faceplate tints only the deck and its background (Spencer's decision), the UI loses even the plate lean. It needs a fixed look of its own.
8. **Icons are system icons.** Thin geometric marks built from frames: correct, anonymous.
9. **Motion is correct and uniform.** Quad tweens of 60 to 160 ms everywhere and a 2 px press. No signature move.
10. **The UI ignores the hardware it lives in.** Hint glyphs are grey circles although the deck beside them has a big mint A and a dark B.

## 2. The tweaks

Effort: S = under half a day, M = about a day. Every motion below is a cut under Reduced Motion. **FIRST** marks the five to do first.

| # | Tweak | What changes | Where | Effort | Risk to readability and phones |
|---|---|---|---|---|---|
| T1 **FIRST** | **A display face: Fredoka One** | Screen titles, item and pet names and button labels use Fredoka One (`rbxasset://fonts/families/FredokaOne.json`, ships with Roblox). Body, labels and hints stay Builder Sans, numbers stay Roboto Mono, the results banner stays Builder Extended. Rule: Fredoka only at 15 px and up, never for sentences, never for numbers. | `DeckKit.lua` `Kit.Type` (new `Name` role; `Title`; the button label role). Screens that set `FontFace` by hand need a sweep. `SharedHeaders` spec. | S | Low. About 4% wider than Builder Sans Bold; titles already truncate. It has one weight, so it cannot carry emphasis inside text. |
| T2 **FIRST** | **Lips for things you press, seams for things you read** | Pressable tiles and secondary buttons get a 4 px darker bottom lip (3 px on phones), the language the primary button already has; the primary ledge deepens from 3 to 6 px. On press the face drops onto the lip (60 ms down, 100 ms up) instead of 2 px. Information panes get a faint stitched seam 6 px inside the edge (plush stitching) and no lip. Preview windows stay inset. Three surfaces, three meanings. | `DeckKit.lua`: `Kit.button` (edge on secondary, edge height), new `Kit.tile`, `Kit.card` option `seam`. Hand-built tiles in `EggHatchView`, `FaceplateShop`, `BackgroundShop`, `CustomizeCards`, `CompanionsHub`, `WardrobeShop`. The seam is one 9-slice image (a UIStroke cannot dash). | M | Low. The lip fits in the existing gaps (8 px or more on every screen drawn). The seam is white at 12% and is dropped on cards under 150 px tall. One asset upload. |
| T3 **FIRST** | **A copy voice, written down** | Warm, short, a little cheeky, from the garden's side. Facts stay literal: odds, prices and "never an advantage" are never joked away. Rules and a first table are in section 3. | The string sites in `EggHatchView`, `DeckResults`, `FaceplateShop`, `BackgroundShop`, `QuestLog`, `PocketMenu` and toasts (or one new `src/shared/UICopy.lua`). | S | Low. Each line must fit the current width (one line overflowed in the mockup pass and was shortened). Specs that assert exact strings need updating. |
| T4 **FIRST** | **Your pet peeks in** | The equipped pet looks over one edge per screen: up into the egg preview on Hatch eggs, over the tab bar on Deck style, over the come-back strip on results (it hops when the count lands; it droops then perks up on a miss). It blinks every 3 to 5 s. Never over text, never focusable, one per screen. | New `src/client/PetPeek.lua` on top of the existing `PetPortrait` head shot, so it shows the player's own hue, charm and wearables. Hosts: `EggHatchView`, `DeckResults`, the Deck style screen. | M | Medium. One more ViewportFrame per menu; phones drop the peek first (it is absent from the phone mockup). Needs a clip frame so it can never cover the wallet. |
| T5 **FIRST** | **A fixed house palette and one tint per screen** | The UI keeps today's default dark teal glass as its permanent palette and stops following the faceplate. Each screen family gets one tint, used in exactly three places: a dot plus the eyebrow, a squiggle under the title, and a halftone dot fade along the panel's bottom edge. Hatch = peach `#FFA98F`, Deck style = lilac `#C9A7FF`, Companions = pink `#FF9EC4`, Quests = sky `#8CC8FF`, results = Star gold. Mint stays the only action colour; gold stays Stars only. | `DeckKit.lua` `Kit.color` (fixed table instead of `theme.ui`), `Kit.header` option `tint`, the `DeckArt.bind` call sites; two small tiled images (squiggle, halftone). | S to M | Low. Tints are decoration, never state. Peach and lilac measure 8.6:1 and 7.9:1 on the panel. The halftone sits behind the hint bar at about 10%; phones skip it. |
| T6 | **Sticker chips** | The one chip that deserves attention on a card (the price, the tier on the detail card, "New best") becomes a sticker: solid colour, ink text, cream 2 px border, tilted 4 degrees, small shadow. It lands with a 120 ms overshoot. Small status chips in grids stay as they are. | `DeckKit.lua` `Kit.chip`, new kind `sticker`. | S | Low. Ink on gold 11.9:1, on lilac 11.2:1. The tilt needs 3 px of clearance; never under 22 px high. |
| T7 | **LCD dot grid in preview windows** | Wells that show an egg, a board or a row of balls get a 6 px dot grid at about 6% white, so they read as small screens. | `DeckKit.lua`, new `Kit.well`; one tiled image. | S | Very low. It sits under the art. |
| T8 | **Hint glyphs are the deck's own buttons** | In hint bars A is a mint cap with a lip and B and LB are grey caps, echoing the hardware. Keyboard and touch swaps do not change. | `DeckKit.lua` `Kit.glyph`. | S | Low. A mint A beside a mint primary button could compete, so caps stay 22 px and in hint bars only. |
| T9 | **The Star has a face** | The Stars star gets two eyes from 20 px up (wallet capsule), and eyes, a smile and cheeks on the results hero. It blinks, and watches the count while it runs. Below 20 px it stays plain. | A `star_face` icon cell (upload) for `Kit.wallet`; a face decal or 2D overlay on the 3D Star in `DeckResults`. | M | Low in the wallet. On the hero the face must follow the spin (hide it past 40 degrees of yaw). |
| T10 | **Icon rules** | One written rule set: filled silhouettes, round corners, one highlight or cut-out "bite", drawn for 20 and 24 px, and round things may have two dot eyes (the Balls tab icon already does). Redraw the 10 vector icons to match as one atlas upload. | `DeckKit.lua` `Vector` table becomes atlas cells in `DeckAssets`. | M | Low. Check each at 16 px in the phone tabs. |
| T11 | **Three motion signatures** | *Boing*: selection and stickers go 0.96, 1.04, 1 with Back-out in 160 ms. *Squash*: the tab pill stretches 6% along its travel. *Tick*: counters hop 1 px per digit change. Everything else stays. | `DeckKit.lua` `Kit.Motion`, new `Kit.boing`; `Kit.tabs`; `Kit.wallet`. | S | Low. Never boing text the player is reading. |
| T12 | **Empty states with a pet and a line** | An empty list shows the pet peeking and one line in voice (section 3) instead of blank space or grey text. Needs T4. | `QuestLog`, `WardrobeShop`, the item belt, `PocketMenu` locked rows. | S | Low. |

Suggested slices: T1 + T3 + T5 together (Kit and strings only), then T2 with T6 to T8 riding along, then T4. T9 to T12 later.

## 3. Copy voice

1. Talk like a friend at the garden gate: short, warm, present tense. No exclamation marks outside celebrations.
2. Lead with the pet or the object, not the system. "Give one a shake" beats "Select an egg".
3. Facts stay plain. Odds, prices, "looks only" and "never an advantage" are stated exactly; the wit goes around them.
4. Buttons keep plain verbs (Hatch, Buy, Replay, Leave). Voice lives in subtitles, hints, footers, toasts and empty states.
5. No baby talk and no memes.
6. Never longer than the line it replaces on the phone layout.

| Where | Now | Proposed |
|---|---|---|
| Hatch eggs, list footer | Every egg lists its exact odds before you hatch it. | Give one a shake. The odds are always on the label. |
| Hatch eggs, phone footer | Odds shown before you hatch | The odds are on the label |
| Hatch eggs, hint bar | Fixed odds. Shown before you pay. | No surprises. The odds never change. |
| Material Egg | A new body finish | A fresh coat for your pet |
| Deck style, Balls | Same sizes, same rules. Looks only. | Same sizes, same rules. Only cuter. |
| Deck style, footer | Fixed prices. Looks only, never an advantage. | Just for looks. Never an advantage. |
| Results, wallet line | Saved to your wallet | Tucked into your wallet |
| Results, nudge | Medium pays 6 to 8 | Brave? Medium pays 6 to 8 |
| Results, button | Leave to garden | Back to the garden |
| Not enough Stars | Not enough Stars | 3 Stars short. One more round? |
| Belt full toast | Belt full | Belt's full. Use one first. |
| Quests, all done | (blank) | All done. Bear is impressed. |
| Wardrobe, nothing owned | Nothing yet | Nothing to wear yet. Bear doesn't mind. |
| Locked row | Win a round to unlock | Win a round and this opens up |

The last five rows are proposals that are not in the mockups; check the current strings in source before changing them.

## 4. What does not change

Layout, sizes, hit areas, focus order, the shared header geometry, the mint action colour, gold for Stars, the 12 px text floor, the 4.5:1 rule, the celebration timelines, and the board during a round (no texture, pet or tint under the balls).

## 5. Open questions

1. **Fredoka One as the display face?** Recommended: yes. It is the one rounded, friendly face that ships with Roblox and stays legible at 15 px. Builder Extended Bold everywhere would be cleaner but keeps the dashboard feel.
2. **Does the pet peek on phones?** Recommended: not in the first pass. Phones keep the type, lips, stickers and copy; the peek needs room and a ViewportFrame.
3. **A face on the Star?** Recommended: yes, in the wallet and on the results hero only. It gives the currency a character cheaply, but it is a brand decision that is hard to walk back.
