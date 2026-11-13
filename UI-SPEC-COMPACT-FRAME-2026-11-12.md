# UI spec: Compact v2, the slim frame (phone landscape)

Written 2026-11-12 by Fable (visual lead) for the implementer. It replaces sections 3 and 4 of `UI-SPEC-COMPACT-2026-11-12.md` (the shell and the round HUD) and changes one number in section 5 (the menu sheet's side rim). Everything else in that file still holds: the Compact rule, the insets, no `UIScale`, type, touch targets, contrast, input, and the picker, results, quest log and shop layouts.

**Status.** Implemented 2026-11-12 late (Claude) with Spencer's section 9 decisions. **Section 10 is the as-built rule and its tables win over the numbers in sections 2-4**, which are kept only as the original proposal. `scripts/deck_art/build_compact_frame_mockups.py` (`frame_geometry`) and `DeckScreen.resolveCompact` compute the same numbers and `scripts/CompactPhone.spec.lua` asserts them. Studio FIXTURE captures in `artifacts/deck-rebuild/studio/compact-frame/`. Not yet run on a phone.

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

*Proposal table removed: see section 10 "Shell and screen" and "Shoulders" for the as-built numbers (shoulders 106 / 94 / 80, no B).*

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

*Proposal table removed: see section 10. As built, every phone has the board centred; 568×320 and 667×375 use the narrow icon-goal columns.*

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

*Proposal table removed: see section 10 "Screen cards".*

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

*Table: see section 10 "Menu sheet" (unchanged numbers).*

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

## 9. Decisions (Spencer, 2026-11-12)

Spencer approved v2 ("looks great") and asked to build it with these changes. Where a decision differs from sections 2-4, the decision wins.

1. **Board height.** 8 px for the frame is fine.
2. **Shoulders a little slimmer.** Take roughly 12-16 px off each shoulder tier (about 120/108/92 to 106/94/80) and give it to the LCD. Recompute the tables.
3. **A at mid height** on the right shoulder, as in the mockups.
4. **B is unassigned for now.** Do not draw B on the touch round HUD; keep its space free under A. Keyboard and gamepad back/leave keep working, and the back arrow still leaves. Update the Controls card (no "B: Leave" row on touch).
5. **Small phones (568×320, 667×375): board centred**, with icon-only goals in narrow side columns, if it stays readable (text >= 14, counters >= 13, targets >= 44, nothing in the keep-out). If centred plus icon goals fails readability at 568×320, keep the one-column layout and say why.
6. **MENU opens a Pocket Menu screen**, not the quest log: a menu on the deck screen that animates in and out (Quad Out about 160 ms in, 120 ms out; instant under Reduced Motion). Items: **Resume**, **Restart round**, **Quit to garden**, **Hatch eggs**, **Customize**. Hatch eggs and Customize open the existing flows (the egg shop / hatch screen and the companion editor). The Daily quests card still opens the quest log. Restart and Quit ask for no extra confirm on an empty board, and a one-tap confirm mid-round.
7. **Menus as a sheet with plate grips** and the **Controls card** stay as proposed.

## 10. As built (2026-11-12 late)

Implemented in `DeckScreen.resolveCompact` / `layoutCompact` / `buildCompactHud`, `PocketMenu.lua` and `init.client.lua`. Plan, architect review and code review: `artifacts/deck-rebuild/COMPACT-FRAME-PLAN.md`.

### 10.1 Rule changes from sections 2-4

```
tier = 0 when H >= 380, 1 when H >= 340, else 2
SW   = 106 /  94 /  80      -- decision 2 (was 120 / 108 / 92)
D    =  88 /  80 /  68      -- d-pad
A    =  92 /  82 /  70      -- A, with its +10 well it stays on the shoulder; B is not drawn (decision 4)
c2   = floor((LW - bw - 16) / 2)
layout = "wide" when c2 >= 144, "narrow" when c2 >= 96, else the one-column fallback
```

- **Board centred on every phone.** `bw = round(LH * aspect)`, `bh = LH = H - 24`, centred in the screen.
- **Narrow (decision 5): 568×320 and 667×375 stay centred.** It passed every readability floor, so the one-column layout is only a fallback for odd windows (`c2 < 96`). Left column: Chain in the first row beside the Roblox controls (from `t0`), Score under it, Goals as **icon rows** (tier egg with its mark, `+` for "or higher", a mini-tray zone glyph lit on the goal's third; a check replaces the count when done; the full goal text is the row's `AccessibleLabel`), the quest handle at the bottom (icon and count; "Quests" when 130+ wide). Right column: Next, Eggs left and Win pays as label-over-value cards, Difficulty with the name at Strong 14, Controls.
- **No quest drawer.** The Daily quests card (wide) and the quest handle (narrow) open the quest log. The desktop Daily quests card is a click target too.
- **D-pad halves** are `max(44, D/2)` wide and `max(44, D)` high, shifted right when they would leave the root (at tier 2 they reach 8 px into the bezel, never into screen content).
- **MENU** is drawn `min(72, SW - 16)` wide, hit `min(84, SW - 8)` × 44. The wordmark shows when `SW - 28 >= 64`.
- **Controls card** shows the rows of the last input, bottom-anchored: touch is Drag "Aim" and A "Drop" (no B row); keyboard and gamepad keep Leave.
- **Sheets.** The content of every phone sheet is padded in by `mg - 6` (a `UIPadding`, so the screens' own open animations still work); the faceplate shop applies the same rule in `FaceplateShop:fit`. Grips get five ridges when `mg >= 24`. The HUD-glass-to-sheet grow transition is **not built yet**.
- **Glare** is hidden on the phone while any sheet or the Pocket Menu is up (never over text). Desktop is unchanged.

### 10.2 Pocket Menu (decision 6)

- Opened by the MENU pill, M, gamepad Y / Select / Start during a round (desktop too). On results, MENU still opens the quest log; with the log open it closes it. Q / LB open the quest log mid-round (MENU no longer does).
- Lives in the lit screen rect on a phone (the shoulders and A stay live) and in the LCD on desktop. Rows 44 high (60 on desktop), 8 apart; one column when five fit, two columns at 568×320. Title and rows keep out of the Roblox keep-out.
- Items: Resume, Restart round, Quit to garden, Hatch eggs, Customize. Mid-round, Restart and Quit turn into "Tap again to restart / quit" (destructive) for 3 s; on an empty board they act at once (Restart on an empty board just resumes: it is already a fresh round). Hatch eggs uses the egg-shop route (`visitEggs`); Customize uses the same board-to-garden route and then the companion editor (`roomView.care.openFree`). Quit / Hatch / Customize are disabled with no pet; Restart is disabled without a field, after the round ends and for 3.5 s after a restart.
- Motion: two panel shutters wipe open from the middle in 0.16 s (Quad Out) and close in 0.12 s (Quad In); Reduced Motion cuts. Opening pauses the round; one pause owner (`clientUI.syncPause`) covers modals, the quest log and the Pocket Menu.
- Server `restart` action: `RunReturn.restart` accepts only a started (drops > 0), live, non-pending run on the deck with a matching sequence; it re-initialises the **same field template with a new seed** (a learned egg queue cannot be replayed), has its own 3 s cooldown and clears the menu pause. Known trade-off: a player can restart to stay on a field they like.

### 10.3 Tables (printed by `build_compact_frame_mockups.py --tables`)

### Shell and screen
| | 844×390 | 740×360 | 932×430 | 568×320 | 667×375 |
|---|---|---|---|---|---|
| Shoulder `SW` | 106 | 94 | 106 | 80 | 94 |
| Glass (bezel) | 106, 4, 632×382 | 94, 4, 552×352 | 106, 4, 720×422 | 80, 4, 408×312 | 94, 4, 479×367 |
| Screen content `x0..x1, y0..y1` | 114..730, 12..378 | 102..638, 12..348 | 114..818, 12..418 | 88..480, 12..308 | 102..565, 12..363 |
| `LW × LH` | 616×366 | 536×336 | 704×406 | 392×296 | 463×351 |
| Layout | wide | wide | wide | narrow | narrow |
| Board | 313, 12, 218×366 | 270, 12, 200×336 | 345, 12, 242×406 | 196, 12, 176×296 | 229, 12, 209×351 |
| Board today (v1) | 223×374 | 205×344 | 247×414 | 181×304 | 214×359 |
| Height lost | 8 px (2.1%) | 8 px (2.3%) | 8 px (1.9%) | 8 px (2.6%) | 8 px (2.2%) |
| Info column width | 191 and 191 | 160 and 160 | 223 and 223 | 100 and 100 | 119 and 119 |

### Shoulders
| | 844×390 | 740×360 | 932×430 | 568×320 | 667×375 |
|---|---|---|---|---|---|
| D-pad | 9, 154, Ø 88 | 7, 143, Ø 80 | 9, 174, Ø 88 | 6, 129, Ø 68 | 7, 150, Ø 80 |
| MENU pill (drawn) | 17, 346, 72×28 | 11, 316, 72×28 | 17, 386, 72×28 | 8, 276, 64×28 | 11, 331, 72×28 |
| MENU hit | 11, 338, 84×44 | 5, 308, 84×44 | 11, 378, 84×44 | 4, 268, 72×44 | 5, 323, 84×44 |
| Wordmark | 14, 64, 78×30 | 14, 64, 66×26 | 14, 64, 78×30 | none | 14, 64, 66×26 |
| Back arrow | 788, 8, 44×44 | 684, 8, 44×44 | 876, 8, 44×44 | 512, 8, 44×44 | 611, 8, 44×44 |
| A centre, Ø | 791, 191, 92 | 693, 176, 82 | 879, 211, 92 | 528, 157, 70 | 620, 184, 82 |
| A hit | 741, 141, 100×100 | 648, 131, 90×90 | 829, 161, 100×100 | 489, 118, 78×78 | 575, 139, 90×90 |
| D-pad halves (hit) | 9, 154, 44×88 / 53, 154, 44×88 | 3, 143, 44×80 / 47, 143, 44×80 | 9, 174, 44×88 / 53, 174, 44×88 | 0, 129, 44×68 / 44, 129, 44×68 | 3, 150, 44×80 / 47, 150, 44×80 |

### Screen cards
| | 844×390 | 740×360 | 932×430 | 568×320 | 667×375 |
|---|---|---|---|---|---|
| Score | 120, 12, 113×44 | 120, 12, 142×44 | 120, 12, 145×44 | 88, 64, 100×44 | 102, 64, 119×44 |
| Chain | 241, 12, 64×44 | in the Score card | 273, 12, 64×44 | 120, 12, 68×44 | 120, 12, 101×44 |
| Goals (3 goals) | 114, 64, 191×132 | 102, 64, 160×132 | 114, 64, 223×132 | 88, 116, 100×108 | 102, 116, 119×132 |
| Daily quests card | 114, 238, 191×140 | 102, 214, 160×134 | 114, 278, 223×140 | none | none |
| Quest handle | none | none | none | 88, 264, 100×44 | 102, 319, 119×44 |
| Next | 539, 12, 191×64 | 478, 12, 160×64 | 595, 12, 223×64 | 380, 12, 100×44 | 446, 12, 119×64 |
| Eggs | 539, 84, 191×44 | 478, 84, 160×44 | 595, 84, 223×44 | 380, 64, 100×44 | 446, 84, 119×44 |
| Difficulty | 539, 136, 191×44 | 478, 136, 160×44 | 595, 136, 223×44 | 380, 116, 100×44 | 446, 136, 119×44 |
| Win pays | 539, 188, 191×44 | 478, 188, 160×44 | 595, 188, 223×44 | 380, 168, 100×44 | 446, 188, 119×44 |
| Controls (max rows; touch shows 2) | 539, 264, 191×114 (3 rows) | 478, 262, 160×86 (2 rows) | 595, 304, 223×114 (3 rows) | 380, 222, 100×86 (2 rows) | 446, 249, 119×114 (3 rows) |
| Toast (centre x, top y) | 634, 330 | 558, 300 | 706, 370 | 430, 260 | 505, 315 |

### Menu sheet
| | 844×390 | 740×360 | 932×430 | 568×320 | 667×375 |
|---|---|---|---|---|---|
| Side grip `mg` | 40 | 24 | 40 | 6 | 6 |
| Sheet | 42, 8, 760×374 | 26, 8, 688×344 | 42, 8, 848×414 | 8, 8, 552×304 | 8, 8, 651×359 |
| `hx` | 128 | 128 | 128 | 128 | 128 |
| `cw × ch` | 238×250 | 214×220 | 268×290 | 169×180 | 202×235 |
| Action row y | 324 | 294 | 364 | 254 | 309 |

### Pocket Menu
| | 844×390 | 740×360 | 932×430 | 568×320 | 667×375 |
|---|---|---|---|---|---|
| Columns | 1 | 1 | 1 | 2 | 1 |
| Title | 123, 21, 598×28 | 120, 21, 509×28 | 123, 21, 686×28 | 120, 21, 351×28 | 120, 21, 436×28 |
| Resume (first row) | 272, 89, 300×44 | 220, 74, 300×44 | 316, 109, 300×44 | 97, 106, 183×44 | 183, 82, 300×44 |
| Customize (last row) | 272, 297, 300×44 | 220, 282, 300×44 | 316, 317, 300×44 | 288, 158, 183×44 | 183, 290, 300×44 |
