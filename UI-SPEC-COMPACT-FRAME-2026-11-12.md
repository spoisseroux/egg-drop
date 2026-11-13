# UI spec: Compact v2, the slim frame (phone landscape)

Written 2026-11-12 by Fable (visual lead) for the implementer. It replaces sections 3 and 4 of `UI-SPEC-COMPACT-2026-11-12.md` (the shell and the round HUD) and changes one number in section 5 (the menu sheet's side rim). Everything else in that file still holds: the Compact rule, the insets, no `UIScale`, type, touch targets, contrast, input, and the picker, results, quest log and shop layouts.

**Status.** Proposal. Nothing is implemented. The mockups are drawn by `scripts/deck_art/build_compact_frame_mockups.py`. Its `frame_geometry(W, H)` is the layout rule; the pictures are drawn from it and the tables below are printed from it (`--tables`), so they agree by construction. The script also asserts the 44 px targets, the 8 px gaps, the keep-out and the text fits at every size it draws. Not run in Studio or on a phone.

**Why.** Spencer played Compact v1 on his phone and said: "the pocket deck in game screenshots didn't show the wide screen? like it's still just ui on the sides". He is right. v1 made the phone the deck, so there is no deck to see: a board, and loose glass pills on a green background. Desktop reads as a handheld because there is one dark screen between two shoulders with real buttons on them. v2 brings that back on phones: a slim shell, one wide LCD, the d-pad and A / B on the shoulders, and all HUD content inside the screen. The price is 8 px of board height.

| What | Where |
|---|---|
| Mockups, 1 image px = 1 offset px | `artifacts/deck-rebuild/mockups/compact-frame/` |
| Before and after at 844×390 | `artifacts/deck-rebuild/mockups/compact-frame/compare-844x390.png` |
| Faceplates (Scout, Night Orb, Aqua Pop) | `faceplates-844x390.png`, `faceplates-568x320.png` in the same folder |
| Generator | `scripts/deck_art/build_compact_frame_mockups.py` |

Mockup index: `01-round-hud` at 844×390, 740×360, 932×430, 568×320 (each with `@2x`) and 667×375; `01b-round-hud-quest-drawer` at 568×320 and 667×375; `03-results` at all four roots; `02-difficulty-picker` and `04-quest-log-daily` at 844×390 and 568×320; `07-faceplate-shop` at 844×390; Night Orb and Aqua Pop versions of the HUD and results. The two dark circles at the top left are a stand-in for the Roblox controls.

---

## 1. When it applies

The same rule as v1, unchanged:

```
landscape = root.X >= root.Y * 1.2
compact   = landscape and (root.Y < 500 or root.X < 1000)
```

Every Compact root gets the slim frame. There is no third mode. Root, `DeviceSafeInsets`, and the keep-out (`kx`, `kh` from `GuiService.TopbarInset`, 116 × 58 when unknown) are as in v1 section 1.1. 568×320 is still the minimum.

---

## 2. The shell

The faceplate still fills the whole root, cropped and stretched as in v1. On top of it sit one glass and two shoulders.

```
tier = 0 when H >= 380, 1 when H >= 340, else 2
SW   = 120 / 108 / 92        -- shoulder width, by tier
D    =  96 /  88 / 76        -- d-pad diameter
A    = 104 /  92 / 76        -- A diameter
B    =  56 /  52 / 48        -- B diameter

glass  = SW, 4, (W - 2*SW) x (H - 8)            -- bezel, #090A0C gradient, radius 16
screen = glass inset by 5                       -- the lit LCD, `panel`, radius 11
x0 = SW + 8      x1 = W - SW - 8                -- screen content (3 px padding inside the screen)
y0 = 12          y1 = H - 12
LW = x1 - x0     LH = y1 - y0
```

| Part | Compact v2 |
|---|---|
| Faceplate | Whole root, as v1. Add the desktop plate overlay's top lip (white 25% to 0 over the top 30%) and bottom shade (black 0 to 29% over the bottom 38%). |
| Rim | 4 px of plate above and below the glass. Shoulders are `SW` wide. |
| Glass | One piece. 5 px bezel with a 1 px white 18% stroke, a soft drop shadow under it and a 1.5 px white 24% lip around it, so it sits in the plate. |
| Screen | `panel` with the usual top-to-bottom gradient. Cards on it are `raised`, radius 10, 1 px white 14% stroke, 8 px apart. The board is `well`, radius 8. |
| Glare | One faint streak on the board only. Never over text. |
| D-pad, A, B | Each in a dark well (diameter + 10, + 10 and + 8), as on desktop. |
| MENU pill | Back on the left shoulder, 72×28 drawn, 84×44 hit. Opens the pocket menu / quest log, as on desktop. |
| Wordmark | Engraved under the Roblox controls, only when `SW - 28 >= 80`. Decoration. |
| Speaker seeds | Bottom-right corner, 30% of desktop size. Decoration. |
| LED, screws, metal band, shoulder bumpers | Dropped. They cost pixels and do not help a player. |
| Back arrow | `W - 56, 8`, 44 px, as v1. It now sits on the right shoulder and mirrors the Roblox controls on the left one. |

With `SW >= 108` the Roblox controls sit on the left shoulder like two top buttons. At tier 2 (`SW` 92) the second control overlaps the glass corner by 16 px; the first row of screen content starts at `kx + 4` to stay clear of it.

### 2.1 Shoulders

| Part | Rule |
|---|---|
| D-pad | Centre `SW/2, kh + (H - kh - 52)/2`, Ø D. Left and right halves are the hit areas in a round. |
| MENU | Drawn `SW/2 - 36, H - 44, 72×28`. Hit `SW/2 - 42, H - 52, 84×44`. Label Bold 12, tracking 1.2, `#E6E9EE`. |
| Wordmark | `14, kh + 6`, width `SW - 28`, aspect 41:16. |
| A | Centre `W - SW/2, round(H * 0.49)`, Ø A. Accent cap, plate `ink` letter. The biggest thing on the shell. |
| B | Centre `W - SW + 14 + B/2, A.y + A/2 + 12 + B/2`, Ø B. `#3A3E47` cap. |

| | 844×390 | 740×360 | 932×430 | 568×320 | 667×375 |
|---|---|---|---|---|---|
| Shoulder `SW` | 120 | 108 | 120 | 92 | 108 |
| Glass (bezel) | 120, 4, 604×382 | 108, 4, 524×352 | 120, 4, 692×422 | 92, 4, 384×312 | 108, 4, 451×367 |
| Screen content `x0..x1, y0..y1` | 128..716, 12..378 | 116..624, 12..348 | 128..804, 12..418 | 100..468, 12..308 | 116..551, 12..363 |
| `LW × LH` | 588×366 | 508×336 | 676×406 | 368×296 | 435×351 |
| D-pad | 12, 150, Ø 96 | 10, 139, Ø 88 | 12, 170, Ø 96 | 8, 125, Ø 76 | 10, 146, Ø 88 |
| MENU pill (drawn) | 24, 346, 72×28 | 18, 316, 72×28 | 24, 386, 72×28 | 10, 276, 72×28 | 18, 331, 72×28 |
| MENU hit | 18, 338, 84×44 | 12, 308, 84×44 | 18, 378, 84×44 | 4, 268, 84×44 | 12, 323, 84×44 |
| Wordmark | 14, 64, 92×36 | 14, 64, 80×31 | 14, 64, 92×36 | none | 14, 64, 80×31 |
| Back arrow | 788, 8, 44×44 | 684, 8, 44×44 | 876, 8, 44×44 | 512, 8, 44×44 | 611, 8, 44×44 |
| A centre, Ø | 784, 191, 104 | 686, 176, 92 | 872, 211, 104 | 522, 157, 76 | 613, 184, 92 |
| B centre, Ø | 766, 283, 56 | 672, 260, 52 | 854, 303, 56 | 514, 231, 48 | 599, 268, 52 |

667×375 is not a reference root. It is drawn because it is a common phone and it lands in the one-column arrangement.

---

## 3. Round HUD

### 3.1 The board and the columns

```
aspect = (Config.Width + .8) / (Config.Height + .8)                 -- 0.596
bw = min(round(LH * aspect), LW - 8 - 160)        bh = LH, or round(bw / aspect) when the min bit
c2 = floor((LW - bw - 16) / 2)                                      -- width of each side column
two columns when c2 >= 144, else one column
```

- **Two columns** (844×390, 740×360, 932×430): the board is centred in the screen, `bx = x0 + floor((LW - bw) / 2)`. Left column `x0 .. bx - 8`, right column `bx + bw + 8 .. x1`. This is the desktop arrangement.
- **One column** (568×320, 667×375): two columns would be 88 px wide, too narrow for a goal line at 14 px. The board goes to the right end of the screen, `bx = x1 - bw`, and one info column takes `x0 .. bx - 8`. It reads like a classic handheld puzzle screen: playfield on one side, numbers on the other. The board sits by the right thumb and A.
- The `min` in `bw` only matters on odd small windows (for example 600×480). It keeps the info column at 160 or more and centres the board vertically.

| | 844×390 | 740×360 | 932×430 | 568×320 | 667×375 |
|---|---|---|---|---|---|
| Columns | 2 | 2 | 2 | 1 | 1 |
| Board | 313, 12, 218×366 | 270, 12, 200×336 | 345, 12, 242×406 | 292, 12, 176×296 | 342, 12, 209×351 |
| Board today (v1) | 223×374 | 205×344 | 247×414 | 181×304 | 214×359 |
| Height lost | 8 px (2.1%) | 8 px (2.3%) | 8 px (1.9%) | 8 px (2.6%) | 8 px (2.2%) |
| Info column width | 177 and 177 | 146 and 146 | 209 and 209 | 184 | 218 |

**What the frame costs.** v1 gave the board `H - 16`. v2 gives it `H - 24`: 4 px of plate, 5 px of bezel and 3 px of screen padding on each edge, where v1 had 2 px of plate and a 6 px bezel. That is 8 px at every size, about 2%. An egg at 844×390 goes from 18.9 px per cell to 18.5. I think that is the smallest loss that still lets the eye see a plate, a bezel and a screen as three separate things; at 2 px each they smear into one dark line. Board width follows the height, so it loses 5 px.

Drag-to-aim on the board is unchanged and is still the main touch control. Everything inside the board well is the existing renderer.

### 3.2 Two columns

Left column, `c` wide, from `L0 = x0`:

| Part | Rect | Contents |
|---|---|---|
| Score | `t0, 12, …×44`, where `t0 = max(L0, kx + 4)` | `SCORE` Label 12 at +10, +5. Value Counter 18, baseline at +39. |
| Chain | With `tw = L1 - t0`: `tw >= 154`: its own card, 64 wide, right-aligned, Score takes the rest. `130 <= tw < 154`: inside the Score card, label and value right-aligned. Under 130: `CHAIN ×3` at the right of the Goals header. | Same type as Score |
| Goals | `L0, 64, c × (24 + n·p + 6)`; `p` = 34 (26 when H < 340) | Header 24: `GOALS 1/3` Label 12 at +12. Rows: check Ø 20 centred at x + 18, `goal.short` Body 14 Medium at x + 34, count Counter 13 `soft` right-aligned at 10. Status lines as in v1. |
| Daily quests | `L0, y1 - qh, c × qh`; `qh = 24 + 3·qp + 8`; `qp` = 36 (34 when H < 380). Shown when it clears a three-goal Goals card by 8. Otherwise the one-column handle and drawer are used. | Header: `DAILY QUESTS` (`QUESTS` when c < 170) Label 12, `stars` dot when a quest is ready, `1/3` Counter 13 and a chevron-right. Three rows. c ≥ 170: name Body 14 and count Counter 13 on one line, bar 4 high under it. c < 170: name on its own line, then the bar with the count at its right end. The whole card is one target. It opens the quest log, as MENU does. |

Right column, from `R0`:

| Part | Rect | Contents |
|---|---|---|
| Next | `R0, 12, c × 64` (44 when H < 340) | `NEXT` Label 12 over the next egg Ø 36. `THEN` Label 12 over upcoming eggs Ø 24: two when c ≥ 150, else one. In the 44-high form it is the v1 pill. |
| Eggs left | next row, 44 high | `EGGS LEFT` Label 12 left. `14` Counter 18 and `/24` Counter 13 `soft` right. |
| Difficulty | next row, 44 high | Bars in the difficulty colour, name Strong 15 at +46, gold `★ ×1.5` chip right when c ≥ 170. |
| Win pays | next row, 44 high | `WIN PAYS` Label 12 left. Star and range Counter 17 `stars` right (15 and 10 px padding when c < 160). |
| Controls | Bottom of the column: `rows = min(3, floor((y1 - top - 30) / 28))`, height `30 + 28·rows`, shown when rows ≥ 2 | `CONTROLS` Label 12. Rows of Body 14: a drag chip and "Aim", an A dot and "Drop", a B dot and "Leave". It tells a new player what the board and the two buttons do. Touch only; on keyboard or gamepad show the key glyphs. |
| Toast | 40 high, centred on the right column, top at `y1 - 48` | It covers the Controls card for its 2 s. Never over the board. |

`BEST` and the eggs-left bar stay off, as in v1. The third upcoming egg comes back when the column is 150 or wider.

### 3.3 One column

One info column `c` wide, from `L0 = x0`, top to bottom:

| Part | Rect | Contents |
|---|---|---|
| Next | `L1 - 76, 12, 76×44` | Next egg Ø 32 and one upcoming egg Ø 22. No label; it sits against the top of the board, as in v1 at this size. |
| Score | `t0, 12` to 8 px before Next (or before Chain), 44 high | As above |
| Chain | Its own 64-wide card between Score and Next when the row is 248 or wider. Otherwise in the Goals header. | |
| Goals | `L0, 64, c × (24 + n·p + 6)` | As above |
| Eggs | `L0`, 8 under a three-goal Goals card, 88×44 (58 wide and no `/24` when c < 200) | `EGGS` Label 12 over Counter 18 |
| Difficulty | Right of Eggs, rest of the row, 44 high | Bars and name. No multiplier chip. |
| Win pays | Next row, 44 high, or what is left above the handle (24 at 568×320) | One line. Not a target. |
| Quest handle | `L0, y1 - 44, c × 44`, `well`, radius 12 | Quests icon, "Quests" Strong 14, `1/3`, chevron-up, `stars` dot. Opens the drawer. |
| Quest drawer | `L0, 64, c × (y1 - 64)` | The v1 drawer (v1 section 4.4), inside the screen. It covers Goals down to the handle, never the board or the top row. |
| Toast | Centred on the column, top at `y1 - 92` | Covers the Win pays row |

No Controls card and no multiplier chip in one column. They are the first to go.

| | 844×390 | 740×360 | 932×430 | 568×320 | 667×375 |
|---|---|---|---|---|---|
| Score | 128, 12, 105×44 | 120, 12, 142×44 | 128, 12, 137×44 | 120, 12, 80×44 | 120, 12, 130×44 |
| Chain | 241, 12, 64×44 | in the Score card | 273, 12, 64×44 | in Goals header | in Goals header |
| Goals (3 goals) | 128, 64, 177×132 | 116, 64, 146×132 | 128, 64, 209×132 | 100, 64, 184×108 | 116, 64, 218×132 |
| Daily quests card | 128, 238, 177×140 | 116, 214, 146×134 | 128, 278, 209×140 | none | none |
| Quest handle | none | none | none | 100, 264, 184×44 | 116, 319, 218×44 |
| Quest drawer | none | none | none | 100, 64, 184×244 | 116, 64, 218×299 |
| Next | 539, 12, 177×64 | 478, 12, 146×64 | 595, 12, 209×64 | 208, 12, 76×44 | 258, 12, 76×44 |
| Eggs | 539, 84, 177×44 | 478, 84, 146×44 | 595, 84, 209×44 | 100, 180, 58×44 | 116, 204, 88×44 |
| Difficulty | 539, 136, 177×44 | 478, 136, 146×44 | 595, 136, 209×44 | 166, 180, 118×44 | 212, 204, 122×44 |
| Win pays | 539, 188, 177×44 | 478, 188, 146×44 | 595, 188, 209×44 | 100, 232, 184×24 | 116, 256, 218×44 |
| Controls | 539, 264, 177×114 (3 rows) | 478, 262, 146×86 (2 rows) | 595, 304, 209×114 (3 rows) | none | none |
| Toast (centre x, top y) | 627, 330 | 551, 300 | 699, 370 | 192, 216 | 225, 271 |

### 3.4 Type

No new roles. Label 12 caps for card labels. Body 14 for goals, quest names and control names. Strong 14 / 15 for "Quests" and the difficulty name. Counter 18 for Score, Chain and Eggs, 17 (15 in a column under 160) for Win pays, 13 for counts. MENU is Bold 12. Nothing is under 12 and no body text is under 14.

### 3.5 What moved, shrank or went

| Thing | v1 | v2 |
|---|---|---|
| Deck frame | none | Slim shell, one LCD |
| Daily quests | Drawer behind a handle | Always-visible card in two columns. Handle and drawer in one column. |
| MENU pill | hidden | On the left shoulder |
| Controls card | not shown | Two columns only, when 2 rows fit |
| `THEN` label, second upcoming egg | not shown | Two columns |
| A / B | Bottom-right corner, A Ø 104 / 96 / 88 | Stacked on the right shoulder at mid height, A Ø 104 / 92 / 76 |
| D-pad | Bottom-left corner, Ø 104 / 96 / 88 | Left shoulder at mid height, Ø 96 / 88 / 76 |
| Wordmark | In the left column when it fits | On the left shoulder when `SW >= 108` |
| Multiplier chip | when the column is ≥ 190 | Two columns ≥ 170 |
| LED, screws, band, bumpers | hidden | still dropped |

---

## 4. Menus: keep the sheet, widen the grips

Decision: the picker, results, quest log and shop **do not go inside the framed LCD**. They keep the v1 full sheet.

- The framed screen is 588 px wide at 844×390 and 368 px at 568×320. The v1 sheet is 804 and 528. Inside the frame the picker loses its bullets at 844, the shop drops to one column, and nothing fits at 568 or 740 without shrinking type. Readability wins.
- One sheet layout per screen at every phone size is also less code and less to test than "in the LCD on big phones, a sheet on small ones".

What changes is the side rim, so the faceplate still shows on menus. In v1 it was a 6 px line and a paid plate was almost invisible on results.

```
mg = 40 when W >= 800, 24 when W >= 700, else 6        -- plate grip left and right of the sheet
bezel = mg, 6, (W - 2*mg) x (H - 12)                   -- radius 18
sheet = mg + 2, 8, (W - 2*mg - 4) x (H - 16)           -- radius 16
body  = x from mg + 14 to W - mg - 14
hx    = max(kx + 12, mg + 18)
cw    = floor((W - 2*mg - 48) / 3)        ch = H - 140        action row y = H - 66
```

With `mg = 6` this is v1 exactly, so 568×320 does not change. Every v1 rule written from the sheet edge (`20`, `W - 20`, `W - 56`, `W - 66`) moves in by `mg - 6`. All v1 thresholds still pass: `cw >= 200` at 740 and up, so bullets, three metrics and full goal text stay.

| | 844×390 | 740×360 | 932×430 | 568×320 | 667×375 |
|---|---|---|---|---|---|
| Side grip `mg` | 40 | 24 | 40 | 6 | 6 |
| Sheet | 42, 8, 760×374 | 26, 8, 688×344 | 42, 8, 848×414 | 8, 8, 552×304 | 8, 8, 651×359 |
| `hx` | 128 | 128 | 128 | 128 | 128 |
| `cw × ch` | 238×250 | 214×220 | 268×290 | 169×180 | 202×235 |
| Action row y | 324 | 294 | 364 | 254 | 309 |

- **Grips.** When `mg >= 24` each grip gets five moulded thumb ridges at mid height (black 30% with a white 24% lower edge), plus the plate lip and shade. The sheet gets the same shadow and lip as the HUD glass, so it reads as the same screen, grown.
- **Transition.** Opening a menu from the HUD: the glass grows from its HUD rect to the sheet rect while the d-pad, A, B and MENU fade out, 160 ms Quad Out. Closing reverses it. Under Reduced Motion it cuts. This is what tells the player the sheet is the deck's screen and not a new window.
- A, B, the d-pad and MENU are not drawn on a sheet (as v1 section 2.5). On-sheet buttons do those jobs and the keys still work.
- Results at 568×320 is the v1 layout unchanged: Leave bottom left, Replay bottom right, text at 14.

---

## 5. Contrast

The four v1 rules hold and nothing new breaks them.

- No text sits on the faceplate. The wordmark and the speaker are decoration. MENU is `#E6E9EE` on its own dark pill, 9.5:1.
- HUD cards are `raised`; labels on them use `dim` (4.7:1 worst case on Scout and Aqua Pop, 5.6:1 on Night Orb). `soft` on `raised` is 7.8:1 or better, `stars` on `raised` 8.1:1 or better, `soft` on `well` (the handle) 10.8:1. Checked by the generator for Scout, Night Orb, Aqua Pop, Liquid Chrome and Ember.
- The `Line` chip on the board is unchanged from v1.
- A's letter is the plate `ink` on the plate accent, as on desktop (8.3:1 worst case, Night Orb).

---

## 6. What changes in code

| Module | Change |
|---|---|
| `DeckScreen.resolveCompact` | Replace the island geometry with `frame_geometry`: `SW, D, A, B`, `glass`, `screen`, `x0..y1`, `columns`, `board`, the card rects, `chainIn` (`pill` / `score` / `goals`), `quests` or `handle` + `drawer`, `controls` + `controlRows`, `dpad`, `menu`, `menuHit`, `wordmark`, `a`, `b`, `toast`. Sheet fields gain `mg`; `sheet`, `hx`, `cw` use it. Keep it pure. |
| `DeckScreen:layoutCompact` | Show one glass frame and one screen frame instead of the board island bezel. Parent the HUD cards to the screen. Place the d-pad, A, B, MENU pill and wordmark from the new rects and un-hide MENU. Add the plate lip and shade. Keep rebuilding only when the layout key changes; add `columns` to the key. |
| `DeckScreen:buildCompactHud` / `setCompactHud` | Cards instead of islands. Two branches: two columns (Score with optional Chain inside, Goals, Daily quests card, tall Next, Eggs row, Difficulty, Win pays, Controls) and one column (v1's pieces at the new rects, plus handle and drawer). `setHud` keeps its data contract; the quests card reads the same data the drawer does. `placeCompactWordmark` goes away. |
| `DeckScreen:placeOverlay` and the results layer | Use the sheet rect with `mg`. Add the glass grow / shrink tween between the HUD glass and the sheet. |
| `DeckKit` | A `Kit.screenCard` (raised, radius 10) beside `Kit.island`; the shoulder wells; toast offsets from `g.toast`. `Kit.island` stays for the handle. |
| `DeckResults`, `DifficultyPicker`, `QuestLog`, `FaceplateShop` | Take the left and right body edges from the sheet rect instead of the literals 20 and `W - 20`, and `cw` from `resolveCompact`. No other layout change. |
| `init.client.lua` | MENU on the shoulder calls what the drawer's "Open quest log" calls today. Nothing else. |
| `scripts/CompactPhone.spec.lua` | Replace the section 4 rect table with the tables above (five sizes). New asserts: the glass is inside the root with 4 px of plate above and below; every HUD card and the board lie inside the screen rect; `columns` is 2 at 844, 740 and 932 and 1 at 568 and 667; the board is `H - 24` high and keeps its aspect; the d-pad, MENU, A, B and back lie outside the glass; A and B are 8 px apart; no target or text in the keep-out; the quests card exists exactly when `columns == 2`; sheet body edges equal `mg + 14` and `W - mg - 14`. Keep the v1 audit (targets ≥ 44, text ≥ 12 and fits, no overlapping targets, Replay and Leave in the bottom corners). |

No server, data or asset changes. The shell sprites (d-pad, buttons, menu pill, wordmark) are the existing ones at smaller sizes.

---

## 7. Risks

- **Not run anywhere.** Drawings from arithmetic. Needs a Studio emulator capture at the four roots, then Spencer's phone.
- **Thumb reach.** A and the d-pad moved from the bottom corners to mid height. That is where thumbs rest on a real handheld, but phones are held lower. If A feels high, lower its centre toward `H - 16 - A/2`; B then goes up and left of it. Nothing else depends on it.
- **A is smaller on short phones.** Ø 76 at 568×320 (was 88) and 92 at 740×360 (was 96). Still far over 44, but it is the main button.
- **740×360 is tight.** Its columns are 146 wide and the two-column cut-off is 144. The widest goal caption tested, "I+I CENTER", fits with 4 px to spare. Longer `goal.short` strings will truncate. If that shows up, raise the cut-off to 160 and 740×360 becomes one column with a roomy 300 px info column.
- **Keep-out width.** At tier 2 the Roblox controls already overlap the glass corner. A wider unibar eats more of the first row; the `t0 = kx + 4` rule covers it down to a Score card of about 60 px, then Score needs to drop a row.
- **Notches.** The glass starts at `SW` from the safe-area edge, so a notch only ever covers plate.
- **One column puts the board off centre.** It is deliberate, but it is a different picture from desktop. See the open questions.

---

## 8. Open questions for Spencer

1. **8 px of board height for the frame.** OK? (374 to 366 at 844×390.) A thinner bezel can win back 4 px but starts to look like a line, not a frame.
2. **One column on small phones** (568×320, 667×375): board on the right, info on the left. Or would you rather keep the board centred and drop Goals text to icons only?
3. **A at mid height on the right shoulder**, B under it. Or keep A in the bottom-right corner as today?
4. **Menus stay as a full sheet** with plate grips (40 px each side at 844×390), not inside the framed screen. Is the grip enough to show off a paid plate, or do you want the results screen framed on big phones even if it costs the picker bullets?
5. **MENU pill and the Daily quests card both open the quest log** in two columns. Keep both, or should MENU open a pause / pocket menu instead?
6. **Controls card on phones** ("Aim: drag board, A: Drop, B: Leave"). Keep it for new players, or show it only for the first few rounds and leave the space empty after?
7. **Keep the d-pad on touch?** Same question as v1. Without it the left shoulder could shrink and the screen could grow about 60 px wider.
