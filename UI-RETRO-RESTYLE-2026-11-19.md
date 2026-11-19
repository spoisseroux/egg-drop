# Pocket Pals v2: retro UI restyle ("Toy Shell")

**Status: direction, style system and mockups for approval, 2026-11-19 (Fable as Astra). Nothing here is built.** No `src/` code, other doc, Studio place or published build was changed.

Spencer (2026-11-19): *"in v2 we need to drastically upgrade the game screen/ui. it looks not retro enough, too vibe codey... the ux is good now, the position of things etc. but the basic styling, colors, etc of the menu uis etc looks too vibe codey/personalityless... I like the font now though. and the usability of the UI. just need a more fun style that's still coherent and usable. lets look to chao garden for inspo?"*

**Kept:** every layout, rect, hit area and focus order; the type (Fredoka One for titles, names and buttons, Builder Sans for body, Roboto Mono for numbers); Stars gold; the board during a round.
**Changed:** the surface of everything else: colour, frames, material, pattern, tabs, chips, headers, icons, motion and sound.

Mockups and generator: `artifacts/v2-ui-restyle-2026-11-19/` (`python artifacts/v2-ui-restyle-2026-11-19/build_mockups.py`). They are PIL drawings over real Studio phone captures. Pets, eggs, jars, jellies and the Star are cut from the capture and put back in the same place. No generated art.

![Before and after, four screens](artifacts/v2-ui-restyle-2026-11-19/contact-sheet.png)

## 1. Diagnosis: why it reads "vibe-coded"

Captures: [deck HUD](artifacts/qa-2026-11-16c-v775/ui-batch/after-14-deck-board-bottom-844x390.png), [Customize](artifacts/qa-2026-11-16c-v775/customization-egg/08-customize-hue-jars-750x402.png), [Pocket menu](artifacts/qa-2026-11-16c-v775/ui-batch/after-09-pocket-menu-animated-tiles-750x402.png), [results](artifacts/qa-2026-11-15-v735/verify-D/D6-results-844x390.png), [Wardrobe](artifacts/store-listing/raw/wardrobe-bell-collar.jpg).

1. **It is the default dark dashboard.** Panel `#152525`, raised `#213335`, well `#0D1818`: three grey-teals a few percent apart, with a 1 px white stroke at 14%. This is the look every generated app has. On the Pocket menu, six tiles and the sheet are one colour; on the deck HUD, eight cards are one colour.
2. **Mint on charcoal is the giveaway.** A single pastel accent (`#76F6B0`) on a dark neutral is the stock palette of 2020s tool UIs. It does every job (tabs, primary button, focus fill, "CURRENT"), so nothing ranks.
3. **No material.** Fills are flat and glassy. The deck beside them is glossy moulded plastic with a real A button; the menus are made of nothing. The personality pass added lips, but a 3 px lip in a slightly darker teal is invisible on a phone (see the Customize cards).
4. **No frame language.** Hairline strokes cannot say "press me" or "read me". The only strong edge in the UI is the focus ring.
5. **No saturated colour except content.** The brightest things on every screen are the pets, the hue thumbnails and the Star. The chrome around them is grey, so the game's own colour never reaches the UI.
6. **The round HUD is a spreadsheet.** CHAIN, SCORE, EGGS LEFT, WIN PAYS: identical boxes with identical grey caps labels, on the most-seen screen in the game.
7. **Details that confirm it:** thin line icons (back arrow, chevrons, clipboard), grey capsule chips, a title squiggle as the only ornament, uniform Quad tweens.

The earlier pass (`UI-PERSONALITY-SCOPE-2026-11-13.md`) fixed type, voice and a few details, and those still hold. What it deliberately kept, "today's default dark teal glass as its permanent palette", is the part Spencer is now reacting to. This page replaces that palette decision (T5) and deepens T2; that doc is not edited.

## 2. Three directions (drawn for this page)

![Mood board](artifacts/v2-ui-restyle-2026-11-19/05-mood-board-three-directions.png)

| | Idea | For | Against |
|---|---|---|---|
| **A Toy Shell** | Menus are moulded from the same plastic as the deck: blue shell, cream keys, thick ink outline, a lip you press, little LCD wells | Retro in the Dreamcast-toy sense, bright, obvious affordances, highest contrast, builds straight on "pocket console" | Biggest visual change; the outline needs a Studio spike first (section 6, step 0) |
| **B Pixel LCD** | Every menu is the deck's screen: phosphor green, stepped corners, dither | Most literally retro, cheap | Dark and one-colour again; fights Fredoka's round shapes; pets look wrong on green |
| **C Sticker Book** | Paper, gingham, pastel stickers, stitching | Cutest; closest to the garden | Cosy-2020s, not retro; pastel on cream leaves little contrast; nothing to do with the deck |

**Recommendation: A, Toy Shell**, with B kept where it belongs: inside wells and on the deck's LCD. The rule that falls out: **plastic is bright and outlined, screens are dark and dotted.**

Chao Garden is the reference for feel only: chunky frames, saturated primaries, a patterned backdrop, toy-console charm. Nothing of Sega's is used: no assets, emote ball, logos, fonts or layouts. The checker is a plain two-tone grid at 9%, not a copy of any screen.

## 3. The style system

![Style system](artifacts/v2-ui-restyle-2026-11-19/00-style-system.png)

### 3.1 Palette (`Kit.Toy`, fixed, never tinted by the faceplate)

Ratios are computed by the generator (WCAG relative luminance).

| Token | Hex | Job | Text on it | Ratio |
|---|---|---|---|---:|
| `ink` | `#15143A` | Every outline; text on light fills | cream | 16.1 |
| `inkSoft` | `#4A4972` | Body text on cream / on lemon | | 7.7 / 6.5 |
| `cream` / `creamLip` | `#FFF4DC` / `#D6C196` | Tiles and keys (anything you press) | ink | 16.1 |
| `shell` / `shellHi` / `shellLip` | `#2E55E6` / `#7C9BFF` / `#1A2F9C` | Sheets (the menu body); tab troughs use `shellLip` | white | 5.9 |
| `onShellSoft` | `#DCE5FF` | Secondary text on shell / on tray | | 4.7 / 7.8 |
| `tray` | `#1D36A6` | Info panes; `#1B2670` on the deck LCD | white | 9.9 |
| `well` / `wellDot` | `#10133A` / `#2A2F6B` | Little screens for 3D previews; the LCD glass | white | 17.9 |
| `go` / `goLip` | `#43DB5F` / `#1C8F3C` | The one primary action per screen; "done" | ink | 9.7 |
| `lemon` / `lemonLip` | `#FFE14D` / `#D9A31C` | Selected: active tab, selected tile | ink | 13.5 |
| `tomato` / `tomatoText` | `#FF5A4D` / `#B3261E` | Danger, promos; red text on cream | ink / on cream | 5.7 / 6.0 |
| `sky` `orange` `pink` `grape` `teal` | `#7FD4FF` `#FF9838` `#FF8FC0` `#A98BFF` `#3FD9B4` | Screen tints, HUD label tabs, icon badges | ink | 6.6 to 10.7 |
| `stars` | `#FFC14D` (unchanged) | Stars only: a star shape, or digits beside one | ink / on well | 10.9 / 11.0 |

Mint `#76F6B0` is retired from chrome. Lemon is an area fill for "selected"; Stars gold only ever appears as a star or its number, so the two do not collide. Screen tints replace the `Kit.Tint` values: Hatch `#FF8A5C`, Deck style grape, Companions pink, Quests sky, Book teal, Garden go.

### 3.2 Frame language: outline, face, glint, lip

Every piece is the same four-part moulding:

1. **Ink outline**, drawn *inside* the rect: 3 px on sheets, 2 px on everything else.
2. **Face**, flat colour.
3. **Glint**: one 1.5 px line of the face colour mixed 60% to white along the top, with a break and a dot at the right end. Pieces under 20 px tall skip it.
4. **Lip**: a darker band of the face colour below the rect. Sheet 4 to 5, primary 4, tile and key 3, tab and chip key 2. These are today's `Kit.Lip` depths, so they fit the existing gaps.

Three surfaces, three meanings (this is T2, made visible):

| Surface | Look | Means | Kit |
|---|---|---|---|
| **Tile / key** | Cream face, lip, glint | You can press it | `Kit.tile`, `Kit.button` |
| **Tray** | Dark blue, no lip, a 3 px shadow under its top edge (sunk) | You read it | `Kit.card`, `Kit.frame` |
| **Well** | Navy screen, 6 px dot grid, one light line at the bottom | A window onto 3D | `Kit.well`, `Kit.previewWell` |

Radii stay as `Kit.Radius`. Round keys (back, help, chevrons) are circles with the same outline and lip.

### 3.3 Patterns

- **Shell checker:** 12 px squares, shell mixed 9% to white, fading from full strength at the top of a sheet to 35% at the bottom. One small tile image plus a transparency gradient. Tiles and trays cover it; it never sits under a sentence.
- **Well dots:** already in Kit (`Kit.dotGrid`); raised from 6% white to the visible `wellDot`.
- **Sunburst:** a two-blue 12-ray burst behind a hero (results Star, hatch reveal). One image, slow 20 s rotation; still under Reduced Motion.
- No pattern on the board, in trays, or behind body text.

### 3.4 Buttons

| State | Primary (go) and key (cream) |
|---|---|
| Rest | Outline, face, glint, lip |
| Hover (mouse) | Face 22% lighter (a key goes white), piece rises 1 px, lip grows 1 px |
| Press | Face drops onto the lip (lip height 0), face 10% darker, no glint. 60 ms down, 100 ms up, as today |
| Focus (gamepad, keys) | 2.5 px white ring 3.5 px outside the piece, with a 1.5 px ink hairline outside that. The ring wraps the lip |
| Disabled | Face `#B9B6C9`, 2 px lip `#8C89A3`, text `#5A5878`, no glint; the reason line beside it stays, as now |
| Selected (tiles) | Lemon face and lemon lip; ink text stays |

One primary per screen. Everything else pressable is a cream key. Danger is a tomato key with ink text. The A / B hint caps sit on buttons as white discs with an ink ring.

### 3.5 Tabs and chips

- **Tabs:** the bar is a sunk trough (`shellLip`, ink outline, top shadow). The active tab is a raised key: lemon on the main bar, cream on a second-level bar (Main / Secondary). Inactive labels are white on the trough. Same segments, same heights.
- **Count chips** ("1/6 TOYS"): solid ink pill, cream caps. **State chips** ("CURRENT", "WEARING"): go fill, ink outline, ink caps. **Quantity** ("×2"): lemon pill, mono.
- **Stickers** (T6, kept): cream edge inside an ink outline, tilted, for the one thing per card that deserves a shout ("THIS WEEK", "NEW", "New best").
- **HUD label tabs:** on the deck LCD each card's caps label sits on a small coloured plate with an ink edge: CHAIN tomato, SCORE lemon, GOALS go, NEXT sky, EGGS LEFT orange, WIN PAYS Stars gold. Same text, same place; the HUD stops being eight grey boxes.

### 3.6 Header plates

The title keeps its position and size. Behind it goes a plate in the screen's tint (9 px side padding, 26 px tall, 2 px lip) with the title in ink and a four-point sparkle after it. It replaces the eyebrow dot and the squiggle. The wallet becomes a well-coloured capsule (an LCD counter) with the faced Star and gold mono digits. Back and help are cream round keys.

### 3.7 Icons

- Filled ink silhouettes, round ends, one cut-out or glint each, drawn for 16, 20 and 24 px. No hairline icons: the back arrow and chevrons become 2.4 px ink strokes with round caps.
- Navigation icons sit on a **badge**: a round key in the screen's tint with outline and lip. Round things may have two dot eyes (T10, kept).
- One atlas upload replaces the `Vector` table in `DeckKit`. Drawn by hand or in code, as here; no AI art.

### 3.8 Rune stat stones

The stones in `V2-FEEDING-RUNES-ONBOARDING-2026-11-19.md` 1.3 are already this language: a rounded square in the stat's colour with an ink rune and a darker lip. Two changes make them fit; they are proposed here and that doc is not edited:

1. **Edge:** on cream tiles and on the shell, the stone takes the 2 px ink outline (instead of "flat chip, no outline" on dark glass and the white sticker edge on light UI). In the 3D world it keeps the white sticker edge.
2. **Stat tiles** become cream tiles with the stone at the left, the name in ink Fredoka and the value in mono; the stats panel body is a tray.

Ink on the six stat colours measures 7.7 to 12.9. Heart pink `#FF86A8` and Power orange `#FF9D4D` sit near our pink and orange tints, so stat colours only ever appear as a stone or directly beside one. The 16 px floor and the "never without colour, name where there is room" rules are unchanged. The stones on the style sheet are my redraw for this page, not the approved art.

### 3.9 Motion

| Name | Where | What | Reduced Motion |
|---|---|---|---|
| **Press-in** | Every key and tile | Face drops onto the lip in 60 ms; back in 100 ms with 1 px overshoot | Kept (it is feedback) |
| **Boing** | Selection, stickers, chips landing | 0.96, 1.04, 1 in 160 ms, Back out (`Kit.boing`, exists) | Cut |
| **Squash** | Tab key travelling | Stretches 6% along its travel, lands with a 2 px settle | Slide only |
| **Plate drop** | Screen open | Header plate drops 10 px and rocks 2 degrees once, 220 ms | Cut |
| **Shell rise** | Sheet open | The existing slide, with the lip appearing last (40 ms) | Existing fade |
| **Tick** | Counters | Digits hop 1 px per change | Cut |

Never animate text the player is reading. Nothing loops except the sunburst and the existing pet idles.

### 3.10 Sound (spec only; nothing was synthesised for this page)

Same house method as the feeding sounds (numpy, fixed seeds, no samples, no AI audio), on the existing `ClickSound` attribute:

| Cue | Sound | Length |
|---|---|---:|
| `press` | Soft plastic "tok": a 180 Hz thump with a 2 kHz click | 50 ms |
| `release` (primary only) | A lighter "tik", a fifth up | 40 ms |
| `tab` | Wooden "thock" with a short downward bend | 70 ms |
| `select` | Two-note blip, rising a fourth | 80 ms |
| `open` / `back` | Cartridge "ka-chunk" / the same two parts in reverse order, softer | 140 ms |
| `deny` | Existing | |

All follow the SFX volume and none is the only signal. Spencer must listen before any upload.

## 4. Readability and touch rules

1. **Body text is ink on cream, or white on tray, shell or well. Nothing else.** Every pair in 3.1 passes WCAG AA for body text (4.5:1). The lowest is soft text on the bare shell at 4.7, so that pair is for hint bars only.
2. **Saturated colours never carry sentences.** On go, lemon, tomato and the tints, text is ink, 12 px or larger, labels only.
3. **Coloured text on cream is limited to `tomatoText`** (promos, 6.0). Gold text is allowed on tray or well (8.3, 11.0) and never on cream, where it fails.
4. **Colour is never the only signal:** selected is lemon *and* a ring or a raised key; done is go *and* a tick; a stat is colour *and* rune *and* name.
5. **Outlines go inside the rect**, so 44 px targets stay 44 px and no gap shrinks. Lips use the gaps `Kit.Lip` already uses. Phone minimums stand: 44 px targets, 12 px text floor, `TextScaled` off.
6. **Disabled text is 3.4:1** by design (WCAG exempts disabled controls); the reason line beside it is at full contrast.
7. **The board is untouched:** no pattern, tint or outline inside it. The HUD around it uses the dark tray so the board stays the brightest thing on the LCD.
8. The focus ring is white with an ink hairline, so it reads on blue (5.9), on cream and over the garden.

## 5. The four screens

Each file shows the Studio capture on the left and the drawing on the right, at 2x. The `-after@2x.png` files are the proposal alone.

| # | Screen | File | What changed |
|---|---|---|---|
| 1 | Pocket Deck round HUD, 844x390 | [01](artifacts/v2-ui-restyle-2026-11-19/01-pocket-deck-hud-844x390-before-after.png) | Navy LCD glass, trays with coloured label tabs, Quests as the one cream key, round back key. Board, shell and hardware untouched |
| 2 | Customize, Hue, 750x402 | [02](artifacts/v2-ui-restyle-2026-11-19/02-customize-hue-750x402-before-after.png) | Blue checker sheet, pink header plate, tab troughs with raised keys, cream jar tiles, a tray and well for the pet, go button |
| 3 | Pocket menu (the hub), 750x402 | [03](artifacts/v2-ui-restyle-2026-11-19/03-pocket-menu-750x402-before-after.png) | Cream tiles, icon badges, ink count chips, wells for the live previews, tilted stickers |
| 4 | Round results, 844x390 | [04](artifacts/v2-ui-restyle-2026-11-19/04-results-844x390-before-after.png) | Sunburst behind the Star, payout and goals trays, Total as a gold plate, one go button and three keys |

Honest limits:

- These are drawings, not Studio captures. Rects were measured from the captures by eye against a 10 px grid, so they are within about 2 px, not pixel-exact.
- Customize and the Pocket menu only exist as 750x402 phone captures, so those two are at that size, not 844x390. The results capture is 860x406 as saved.
- Cut-outs are soft because the captures are 1x. The hardware MENU pill, A, B and d-pad are left as captured.
- Desktop is not drawn; the same tokens apply, with a 5 px sheet lip.

## 6. Migration: restyle without moving anything

The work is almost all in `src/client/DeckKit.lua`. Screens call Kit, so most of them change without being opened. **No `Position`, `Size`, `AnchorPoint`, padding or focus order changes in any step.** Each step is checked by overlaying a new Studio capture on the old one at 844x390 and 750x402 (rects must match) and by the existing layout specs.

| Step | Kit change | Reaches | Risk |
|---|---|---|---|
| 0 | **Spike in Studio: the inner 2 px outline.** Try `UIStroke` with an inner border position if the engine offers it (I have not verified this in Studio); otherwise one white 9-slice "toy frame" image tinted by `ImageColor3`. Decide once | Nothing shipped | This decides the cost of everything below |
| 1 | `Kit.Color` and the `fallback` table take the `Kit.Toy` palette; `Kit.Stroke` becomes ink, opaque; text roles split into "on cream" and "on shell" | Every screen recolours | Labels that set their own colour by hand: sweep `TextColor3` |
| 2 | `Kit.tile`, `Kit.button`, `Kit.paintButton`: cream and go faces, outline, glint, lip colours, the five states | All tiles and buttons | Hand-built tiles in `CustomizeCards`, `HueEggView`, `CompanionsHub`, `EggHatchView`, the shops |
| 3 | `Kit.card` / `Kit.frame` become trays; `Kit.well` / `Kit.previewWell` / `Kit.dotGrid` become wells; `Kit.seam` retired | Detail panes, previews | A screen that uses `card` for something pressable must switch to `tile` |
| 4 | `Kit.sheet`: shell, checker, sheet lip. `Kit.header`: plate instead of eyebrow and squiggle. `Kit.wallet`, `Kit.backArrow`, `Kit.helpButton` as LCD capsule and round keys. New `Kit.Tint` values | Every menu | Long translated titles: the plate follows the text and truncates where the title does now |
| 5 | `Kit.tabs`: trough and raised key, squash. `Kit.chip`: ink, state, quantity and sticker kinds. `Kit.glyph` caps | Tabs and chips everywhere | Low |
| 6 | Deck LCD: `DeckScreen` HUD cards use the tray plus a new `Kit.hudLabel`; `DeckResults` trays, sunburst, Total plate | The round and results | The most-seen screen: check on the smallest phone (568x320) |
| 7 | Icon atlas replaces `Vector`; badges in `PocketMenu`; rune stones | Icons | One upload batch |
| 8 | Motion (`Kit.Motion`, `Kit.boing`, plate drop) and the five sounds | Feel | Reduced Motion paths |
| 9 | Sweep the outliers: `NoticeCards`, `CoachCards`, `NotificationRail`, `QuestLog`, `BookView`, `PetFocusUI`, `PetInspect`, `HowItWorks`, toasts | Leftovers | Anything still teal after step 5 is a hand-built frame |

Steps 1 to 4 change most of what Spencer sees. Ship 0 to 5 as one private build for his eyes before touching the deck LCD (step 6). The faceplate keeps tinting only the deck and its backdrop, as already decided.

## 7. Open questions for Spencer

1. **One blue shell for every menu, or a shell colour per screen family?** Recommended: one blue, with the header plate carrying the tint. That is the coherence he asked for.
2. **Green stays the action colour, as saturated go instead of pastel mint?** Recommended: yes. It keeps "green means go" and matches the A button on the default plate.
3. **Does the deck LCD go navy too?** Recommended: yes for the HUD and results around the board; no change to the board itself.
4. **Checker, or plainer?** If the checker feels busy on a phone, keep it in the header band only. Nothing else depends on it.
