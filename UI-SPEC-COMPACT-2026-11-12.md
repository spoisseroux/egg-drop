# UI spec: Compact (phone landscape) deck screens

Written 2026-11-12 by Fable (visual lead) for the implementer. It replaces section 7 of `UI-SPEC-2026-11-12.md` and the "Compact" lines in `UI-DESIGN-SYSTEM.md`. Tokens, components, focus rules, motion and data ownership are unchanged from the main spec; this file only says where things go on a phone.

**Status.** Implemented 2026-11-12 night (Spencer approved DeviceSafeInsets with the TopbarInset keep-out, `#FF8090` danger text and the Results change-difficulty button). Studio FIXTURE captures in `artifacts/deck-rebuild/studio/compact/` (see its README for the gaps); `scripts/CompactPhone.spec.lua` asserts the tables below. Not yet run on a phone. The mockups are drawn by `scripts/deck_art/build_compact_mockups.py`, which evaluates the rules below at each size, so the pictures and the tables agree by construction.

**Why.** Today a phone gets the desktop screens scaled down. The picker, quest log and results sit in a 417×299 LCD at a scale near 0.49, so 16 px body text renders at about 8 px, and the faceplate shop fits itself at about 0.6. The round board is about 282 px tall on a 740×360 phone. This spec stops scaling: the phone itself becomes the deck, every screen is authored in real pixels, and the board grows to 344 px tall on the same phone (about 22% taller, by arithmetic from `DeckScreen.resolve`, not measured).

| What | Where |
|---|---|
| Mockups, 1 image px = 1 offset px | `artifacts/deck-rebuild/mockups/compact/` |
| Generator | `scripts/deck_art/build_compact_mockups.py` (`--all` adds 932×430 and 568×320) |

Mockup index, each at `-844x390`, `-740x360`, `-932x430` and `-568x320`: `01-round-hud`, `01b-round-hud-quest-drawer`, `02-difficulty-picker`, `03-results`, `04-quest-log-daily`, `07-faceplate-shop`. The two dark circles at the top left are a stand-in for the Roblox controls; we do not draw them.

---

## 1. When Compact applies

```
landscape = root.X >= root.Y * 1.2
compact   = landscape and (root.Y < 500 or root.X < 1000)
```

| Mode | When | Layout |
|---|---|---|
| Regular | not compact and `s >= 0.75` | Main spec, unchanged |
| **Compact** | the rule above | This file |
| Portrait / square | not landscape | Unchanged (legacy stacked case) |

- Compact is chosen by size, never by input type. A small desktop window gets it too, so keyboard, mouse and gamepad must keep working (section 2.5).
- Re-evaluate on every root size change and on `GuiService.TopbarInset` change. Rebuild the HUD only when the mode changes, as `DeckScreen:layout` does today; a rotation mid-drag clears aim input as it does today.
- Landscape roots that are not compact but still give `s < 0.75` (for example 1024×768) keep today's behaviour. That band is not redesigned here (section 11).

### 1.1 Root and insets

- **Root.** In Compact the deck, board and overlay ScreenGuis use `ScreenInsets = DeviceSafeInsets`. All coordinates below are in that root, `W × H`. The faceplate texture is the only thing that bleeds past it (it already lives in the full-bleed layer).
- **Roblox controls.** Read `GuiService.TopbarInset`. Define the keep-out as `kx = TopbarInset.Min.X` (the mockups use 116) and `kh = TopbarInset.Height` (58 on current phones). Nothing interactive and no text goes inside `x < kx, y < kh`. If the API returns an empty rect, use `kx = 116, kh = 58`.
- Using the device root instead of `CoreUISafeInsets` is what buys the height: the top bar only occupies the top-left corner, so the band beside it is ours.
- **Reference roots.** 844×390, 740×360 and 932×430 are drawn and tabulated. **568×320 is the minimum**; every rule below is checked there. Under 320 high, the body of a menu sheet scrolls as one `ScrollingFrame` with its bottom action row pinned, and the round HUD keeps the 568×320 arrangement with the board solved from the height.

---

## 2. Rules for every Compact screen

### 2.1 No scaling

Compact screens have **no `UIScale`**. Sizes are offset pixels; containers stretch by the formulas given. Type never shrinks with the viewport.

### 2.2 Type

| Role | Compact size | Notes |
|---|---|---|
| Display | 30 | Stars total only |
| Title | 20 | Sheet titles, card nicknames; 18 for the plate name in the shop pane |
| Heading / button label | 16 primary, 15 secondary | |
| Body, Strong | 14 (16 for quest row titles) | Goals, bullets, payout rows, tile names, status lines |
| Small (caption) | 12 | Sub-lines, "Saved to your wallet", timer, finish name |
| Label | 12, caps, tracking 0.6 | Eyebrows and card labels |
| Counter | 15 amounts, 13 counts, 17 Win pays, 18 Score / Chain / Eggs | Roboto Mono Bold |

Body text is never under 14 and captions never under 12. `Kit.setCompact` already floors at 12; the picker, quest log and shop must stop inheriting sizes through an 848-wide `UIScale`.

### 2.3 Touch targets

- Every control is at least **44×44**. Where the drawing is smaller (tabs are 36 high, the drawer close is a 12 px chevron) add an invisible hit frame, as the Menu pill does today.
- 8 px minimum between two targets.
- **Thumb zones** are the bottom-left and bottom-right corners, roughly 200×170 each. The primary action sits bottom right, the way out sits bottom left, and nothing a player needs mid-round sits in the middle of the top edge.

### 2.4 Contrast

All text is 4.5:1 or better against its own surface on all 16 plates if these four rules hold (checked for Scout, Liquid Chrome, Night Orb and Ember by the generator):

1. No text sits on the faceplate. Everything is on `panel`, `raised`, `well` or a fill.
2. `dim` is for 12 px labels on `panel`, `raised` and `well` only (4.7:1 worst case with DeckKit's `#959BA5`). On a `selected` surface use `soft` (5.5:1); `dim` drops to 3.3:1 there.
3. `danger` as **text** is `#FF8090` on `raised` (5.5:1). The token `#FF5A6E` is 4.4:1 on Scout's `raised`, so keep it for lines, strokes, bars and dots.
4. The EASY / MEDIUM / HARD eyebrow on a picker card is a 20-high chip with a `well` fill, so its tone colour never sits on `selected` (danger on `selected` is 3.0:1).

### 2.5 Input

- Focus logic, shortcuts and the `move / confirm / back` methods are unchanged. Compact only moves things.
- Glyph chips on buttons and the shared focus ring show only when the last input was gamepad or keyboard. Hint bars are removed in Compact.
- The hardware A, B and d-pad are drawn only on the round HUD. On menu sheets the sheet covers them and on-sheet buttons do the same jobs. A, B, the d-pad keys, L / R and M still work from a controller or keyboard.

---

## 3. The shell in Compact

The phone is the deck. `DeckScreen.resolve` gets a Compact branch that returns rects instead of a scaled 1600×800 body.

| Part | Compact |
|---|---|
| Faceplate | Fills the whole viewport: crop the middle 80% × 76% of the plate texture and stretch (`ScaleType.Crop`). Finish overlay on top as today. |
| Band, shoulders, shadow, plate overlay, glass sprite, LED, Menu pill | Hidden |
| Wordmark | Shown on the round HUD only, when it fits (section 4.3) |
| LCD | Replaced by **glass islands**: dark glass pieces set into the plate. An island is the content rect in `panel` (or `well`) with the usual 1 px white 14% stroke, inside a bezel: the rect grown by 3 px, `#090A0C`, radius + 3, 1 px white 18% stroke. |
| Glare | Board island only |
| Back arrow | 44 px, right edge 12 px and **top edge 8 px** inside the root, so it lines up with the Roblox controls |
| Toast | 40 high, Strong 14. On the HUD: centred in the right column at y = 164. On a sheet: centred at y = 66. Never over the board. |

Because the plate is the full background, a new faceplate still recolours the whole phone, which is the thing players pay Stars for.

---

## 4. Round HUD (`01-round-hud`, `01b-round-hud-quest-drawer`)

The side panels collapse into a strip in the top band, split around the board. Goals stay on the left under it, the daily quest ticker becomes a drawer, and the hardware sits under the thumbs.

### 4.1 Geometry

```
aspect = (Config.Width + .8) / (Config.Height + .8)        -- 0.596
bh = H - 16            bw = round(bh * aspect)
bx = floor((W - bw) / 2)        by = 8                     -- board rect; bezel is 6 px here, radius 12 + 6
L0 = 12                L1 = bx - 14                        -- left column
R0 = bx + bw + 14      R1 = W - 12                         -- right column
D  = 104 if H >= 380, 96 if H >= 340, else 88              -- d-pad and A diameter
```

| | 844×390 | 740×360 | 932×430 | 568×320 |
|---|---|---|---|---|
| Board `x, y, w×h` | 310, 8, 223×374 | 267, 8, 205×344 | 342, 8, 247×414 | 193, 8, 181×304 |
| Left column `x..x (w)` | 12..296 (284) | 12..253 (241) | 12..328 (316) | 12..179 (167) |
| Right column | 547..832 (285) | 486..728 (242) | 603..920 (317) | 388..556 (168) |
| D | 104 | 96 | 104 | 88 |

Everything inside the board well is the existing renderer. Drag-to-aim on the board is unchanged and stays the main touch control.

### 4.2 Top strip (y = 8, height 44)

Strip pills are islands, radius 12. Inside each: Label 12 at +13 from the top, value Counter 18 with its baseline at +39 (47 from the root top).

**Left wing** runs from `x0 = max(kx + 8, L0)` to `L1`. `wing = L1 - x0`.

| `wing` | Result |
|---|---|
| ≥ 154 | Score pill `min(132, wing - 70)` wide, then 6 px, then a Chain pill 64 wide. Both right-aligned to `L1`. |
| 84 to 153 | Score pill `min(132, wing)` wide, right-aligned to `L1`. Chain becomes `CHAIN ×3` at the right end of the Goals header. |
| < 84 | No left wing. Score is a full-width pill at `L0, 60, (L1 - L0)×44` with the label left and the value right. Chain goes in the Goals header. Everything below starts at y = 112. |

**Right wing** runs from `R0` to `W - 64` (the back arrow owns the last 56). `wr = W - 64 - R0`.

| Part | Rule |
|---|---|
| Eggs pill | Rightmost. 88 wide with `14` and `/24` (Counter 13, `soft`); 58 wide with the count only when `wr < 150`. |
| Next pill | From `R0`, width `nw = min(140, wr - eggsW - 6)`, content centred. Next egg Ø 32. Second egg Ø 22 when `nw ≥ 80`. `NEXT` label when `nw ≥ 124`. |
| Back arrow | `W - 56, 8`, 44 px. Mid-round it pauses and leaves, as today. |

| | 844×390 | 740×360 | 932×430 | 568×320 |
|---|---|---|---|---|
| Score | 124, 8, 102×44 | 124, 8, 129×44 | 126, 8, 132×44 | 12, 60, 167×44 |
| Chain | 232, 8, 64×44 | in Goals header | 264, 8, 64×44 | in Goals header |
| Next | 547, 8, 139×44 (label, 2 eggs) | 486, 8, 96×44 (2 eggs) | 603, 8, 140×44 | 388, 8, 52×44 (1 egg) |
| Eggs | 692, 8, 88×44 | 588, 8, 88×44 | 749, 8, 88×44 | 446, 8, 58×44 |

`BEST`, the `THEN` label, the third upcoming egg, the eggs-left bar and the Controls card are not shown in Compact.

### 4.3 Left column

| Part | Rect | Contents |
|---|---|---|
| Goals | `L0, top, (L1 - L0) × (24 + n·p + 6)`; `top` = 60 (112 with no left wing); `p` = 34 (26 when H < 340); `n` = goal count | Header 24: `GOALS 1/3` Label 12 at x + 12. Rows: check Ø 20 at x + 12, `goal.short` in Body 14 Medium at x + 40, count Counter 13 `soft` right-aligned at 12 from the edge. No bars. A finished goal's text goes `soft`. |
| Status | Same card | "Falling", "Settling" and save waits replace the `GOALS` label in `stars`; the full goal sentence replaces the rows for 2 s when a goal changes. Both as today. |
| D-pad | `16, H - m - D`, Ø D; `m` = 12 (8 when H < 340) | Disc and accent arrows. During a round the left and right halves (D/2 × D each) are the hit areas; up and down do nothing. |
| Quest handle | `x = 16 + D + 12` to `L1`, `y = H - 56`, height 44, radius 22, `well` island | Quests icon 18 at +22. "Quests" Strong 14 when width ≥ 110. Count `1/3` Counter 13 when width ≥ 150 (or alone when 84 to 109). Chevron-up at the right. 8 px `stars` dot on the icon when a quest is ready to claim. Left-thumb reachable. |
| Wordmark | Centred between the Goals card and the handle, right of the d-pad, up to 123 wide (aspect 41:16) | Plate `engrave` colour and opacity. Only when that gap is at least 100 wide and tall enough plus 10 px above and below. Decoration; it leaves first. |

| | 844×390 | 740×360 | 932×430 | 568×320 |
|---|---|---|---|---|
| Goals (3 goals) | 12, 60, 284×132 | 12, 60, 241×132 | 12, 60, 316×132 | 12, 112, 167×108 |
| D-pad | 16, 274, Ø 104 | 16, 252, Ø 96 | 16, 314, Ø 104 | 16, 224, Ø 88 |
| Handle | 132, 334, 164×44 | 124, 304, 129×44 | 132, 374, 196×44 | 116, 264, 63×44 |

### 4.4 Quest drawer

Tapping the handle opens the drawer; it is the Daily quests card from the wide HUD, on demand.

- **Rect** `L0, 60, (L1 - L0) × (H - 72)`, `panel` island. It covers the Goals card, the d-pad and the handle, never the board. The round does not pause.
- **Contents.** Header 44: `DAILY QUESTS` Label 12 at +12, +16; a 44×44 close target at the top right with a chevron-down. Three rows at pitch 44 from +46: name Body 14 (truncate), count Counter 13 right (`stars` when done), bar 4 high at +28 (`stars` when done). A secondary button "Open quest log", full width minus 24, 44 high, 12 from the bottom; it does what the Menu pill does today.
- **Motion.** Slides up from the handle and fades, 140 ms Quad Out; instant under Reduced Motion.
- **Closes** on the close target, on a tap anywhere outside it, on back, and by itself 6 s after the last touch inside it. Aiming by drag and the A button keep working while it is open.
- The quest-complete toast still fires with the drawer shut.

### 4.5 Right column

| Part | Rect | Contents |
|---|---|---|
| Difficulty | `R0, 60, (R1 - R0)×44` | Three bars (6 wide; 10 / 16 / 22 high) in the difficulty colour at +12. Name Strong 15 at +46. Gold chip `★ ×1.5`, 22 high, right-aligned at 10, when the width is ≥ 190. |
| Win pays | `R0, 112, (R1 - R0)×44` | `WIN PAYS` Label 12 at +12. Star 17 and the range in Counter 17 `stars`, right-aligned at 12. |
| A | centre `W - 16 - D/2, H - 16 - D/2`, Ø D | Accent cap, plate `ink` letter. Hit Ø D + 8. Right thumb. |
| B | centre `A.x - D/2 - 42, H - 44`, Ø 56 | `#3A3E47` cap. Hit 56. |

| | 844×390 | 740×360 | 932×430 | 568×320 |
|---|---|---|---|---|
| A centre, Ø | 776, 322, 104 | 676, 296, 96 | 864, 362, 104 | 508, 260, 88 |
| B centre, Ø | 682, 346, 56 | 586, 316, 56 | 770, 386, 56 | 422, 276, 56 |

---

## 5. Menu sheet (picker, results, quest log, shop)

One frame for all four. In Compact the three LCD overlays (`DeckScreen:addOverlay`, the results layer) and the faceplate shop root are placed on this rect instead of the LCD rect, with `UIScale = 1`.

| Part | Rect | Notes |
|---|---|---|
| Rim | whole root | The faceplate shows as a 6 px rim |
| Bezel | 6, 6, (W − 12)×(H − 12), radius 18 | `#090A0C` |
| Sheet | 8, 8, (W − 16)×(H − 16), radius 16 | `panel`, the usual top-to-bottom gradient, 1 px stroke |
| **Header** (sticky) | y 8 to 60, centre line y = 30 | Never scrolls. Content starts at `hx = max(kx + 12, 24)`. |
| Back arrow | W − 56, 8, 44 px | Same component. On results it is Leave. |
| Wallet pill | right edge W − 66, y 14, 32 high | Star 17 and Counter 15. Not a target. |
| Hairline | 20..W − 20 at y = 60 | White 7% |
| Body | x 20..W − 20, y 64..H − 18 | |
| Action row | y = H − 66, 48 high | Where a screen has one. Body content above it ends at H − 76. |

Shared sizes: `cw = floor((W − 60) / 3)` (three columns, 10 px gaps) and `ch = H − 140` (card height above an action row).

| | 844×390 | 740×360 | 932×430 | 568×320 |
|---|---|---|---|---|
| `cw × ch` | 261×250 | 226×220 | 290×290 | 169×180 |
| Action row y | 324 | 294 | 364 | 254 |

Open and close keep the 160 ms fade and 12 px rise.

---

## 6. Difficulty picker (`02-difficulty-picker`)

| Element | Rect | Notes |
|---|---|---|
| Title "Pick a difficulty" | `hx`, centre y 30 | Title 20. The `EGG DROP` eyebrow is hidden. |
| Wallet, back arrow | section 5 | Back leaves to the garden |
| Cards ×3 | x = 20 + i·(cw + 10), y 64, cw×ch | Radius 14. Whole card is the target. |
| Quests | 20, H − 66, 148×48 | Secondary, quests icon, "Quests 1/3", `stars` dot when something is ready. Opens the quest log. Left thumb. |
| Goal line | x 180 to Start − 12, in the action row | Target icon 18, then "Goal this round: …" Body 14 `soft`, two lines at most. The "Quest:" half of the old info strip is dropped. |
| Start | right edge W − 20, H − 66, 200×48 (160 wide when W < 600) | Primary. Right thumb. |

**Inside a card** (card-local px):

| Element | Position | Shown when |
|---|---|---|
| Difficulty chip (EASY …) | 12, 10, 20 high, `well` fill, tone-coloured Label 12 | always |
| Bars icon | right edge at cw − 12, y 9 | always |
| Nickname | 12, centre y 47, Title 20 | always |
| Reward chip `★ ×0.8 STARS` | 12, 64, 24 high, gold, Label 12 | always |
| Bullets ×3 | dot Ø 6 at x 16, text Body 14 `soft` at x 28; centres at y 108, 130, 152 | `ch ≥ 205` and `cw ≥ 200` |
| Hairline | y = ch − 62 with the tidy line, else ch − 44 | always |
| "Win pays 9 to 12" | 12, hairline + 20, Strong 14 | always |
| "Tidy stack pays 12" | 12, hairline + 42, Counter 12 `soft` | `ch ≥ 244` |

So 844×390 and 932×430 show everything, 740×360 drops the tidy line, and 568×320 also drops the bullets.

Behaviour is unchanged: tap a card to select it, tap it again or Start to start. The selected card is `selected` with the 2 px accent stroke.

---

## 7. Results (`03-results`)

Three columns over an action row. Replay is under the right thumb and Leave under the left.

| Element | Rect | Notes |
|---|---|---|
| Outcome eyebrow | `hx`, y 15 | Label 12: `ROUND CLEAR` in `accent`; `OVERFLOW` / `GOALS MISSED` in `#FF8090` |
| Sub-line | `hx`, centre y 41 | Body 14 `soft`: goal template · difficulty; truncate before the wallet |
| Wallet, back arrow | section 5 | The wallet pill moves here from the Payout card. Back is Leave. |
| Payout card | 20, 64, cw×ch | below |
| Stars total | middle column, no card | below |
| Goals card | W − 20 − cw, 64, cw×ch | below |
| Leave | 20, H − 66, 160×48 ("Leave to garden"); 100 wide and "Leave" when W < 600 | Secondary. Left thumb. |
| Replay | W − 20 − cw, H − 66, cw×48 | Primary, replay icon, label 16. Right thumb. Focus on open. |
| Difficulty | Replay.x − 58, H − 66, 48×48 | Secondary. The bars in the difficulty colour and a small chevron. Opens the picker (the touch route for "Up on Replay"). `AccessibleLabel` "Change difficulty". |
| Quest shortcut | from Leave + 10 to Difficulty − 10, H − 66, 48 high | below |

**Payout card.** `PAYOUT` Label 12 at 12, 10. Up to three rows (the same rows as the wide screen, not the one-row compact card built today): name Body 14 left, amount Counter 15 `stars` right, centres at y = 46 + i·p with `p` = 28 (26 when `ch < 200`), hairline between rows. `Total` Strong 14 with star 15 and Counter 15 at y = 46 + 3p + 4. "Saved to your wallet" / "Saving…" Small 12 `soft` at ch − 18 when `ch ≥ 186`. A loss shows the single line "No Stars this round".

**Stars total.** With `mid = 64 + (ch − 62)/2`: star 34 and Display 30 `stars`, "+12 Stars", centred in the middle column on y = mid − 13, counted up as today. `NEW BEST` gold chip, 22 high, centred, top at mid + 14. A loss reads "0 Stars" in `soft`. A hairline at 64 + ch − 60, then the metrics at 64 + ch − 50: Label 12 over Counter 15, evenly spaced. `SCORE`, `BEST`, `CHAIN` when `cw ≥ 200`; `SCORE` and `CHAIN` otherwise.

**Goals card.** `GOALS` Label 12 and the count Counter 13 right. Rows at pitch 32 (28 when `ch < 200`) from y = 48: check Ø 20 at x 12, Body 14 at x 40, truncated. Use the full goal text; fall back to `goal.short` when `cw < 200`. A missed goal has the open ring and `soft` text.

**Quest shortcut.** Replaces the quest strip.

| State | Look | Tap |
|---|---|---|
| A quest finished this round | `well` + 6% gold, 1.5 px `stars` stroke, gold check, the quest name Strong 14, gold `CLAIM` chip right. When narrower than 200: "Claim 1 quest", no chip. | Opens the quest log on that tab |
| Nothing finished | Ghost secondary: quests icon and "Quests 1/3" | Opens the quest log |
| An egg is affordable and nothing to claim | Body 14 `soft` "You can hatch an egg", no fill | Not a target |

**Rules that do not change.** The first A or tap during the count-up only finishes it. A pending save disables Replay with "Saving…" and moves focus to Leave. Confetti stays under the sheet content.

---

## 8. Quest log (`04-quest-log-daily`)

A single-column list under a sticky header that holds the tabs and the back arrow.

| Element | Rect | Notes |
|---|---|---|
| Tabs | `hx`, 12, `min(312, W − hx − 174)` × 36 | In the header, in place of the title. Bold 14. 44-high hit frame per segment. `stars` dot on a tab with something to claim. |
| Reset timer | right edge at wallet − 12, centre y 30 | Clock 15 and Small 12 `soft`. Only when the gap between the tabs and the wallet is ≥ 130; otherwise omit it. |
| Wallet, back arrow | section 5 | Back returns to where the log was opened |
| Quest rows ×3 | x 20, width W − 40, y = 64 + i·(rh + g) | `g` = 8 (6 when H < 340); `rh = clamp(floor((H − 134 − 2g) / 3), 56, 76)` |
| Footer | 20, H − 62, (W − 40)×44 | `well`, radius 12. Pinned. |

| | 844×390 | 740×360 | 932×430 | 568×320 |
|---|---|---|---|---|
| Row height, y of rows | 76; 64, 148, 232 | 70; 64, 142, 220 | 76; 64, 148, 232 | 58; 64, 128, 192 |
| Footer y | 328 | 298 | 368 | 258 |

All three rows fit without scrolling at every reference size. Put them in a `ScrollingFrame` (y 64 to footer − 8) anyway so a fourth row or a shorter root scrolls under the pinned header and footer.

**Row** (row-local px, `rh` high, `w` wide):

| Part | Position |
|---|---|
| Icon well | 12, (rh − 44)/2, 44×44, radius 12, `well`; icon 22 |
| Title | x 68, centre y 19 (16 when rh < 64), Strong 16 |
| Sub-line | x 68, 20 below the title centre, Small 12 `soft` |
| Bar | 68, rh − 14 (rh − 11 when rh < 64), (w − 318)×6 |
| Count | 10 right of the bar, Counter 13 `soft` |
| Reward `★ +4` | right edge at w − 128, centred, Counter 15 `stars` |
| Action | w − 116, (rh − 44)/2, **104×44**: Claim (reward button), Reroll (secondary), or a `CLAIMED` chip 24 high |

States (in progress, ready, claimed, locked) look as in the main spec.

**Footer.** Daily: reroll icon 18 in `accent` at +22; "1 free reroll left today" Strong 14 ("No reroll left today" in `soft`); when W ≥ 800 add "Swaps one quest you have not started." Small 12 `soft`. Right side, from the right: a "Menu ›" ghost target 84×44 behind a hairline (the pocket menu button that sits in the header on desktop), then `★ 4/12` Counter 15, then `TODAY` Label 12. Weekly: trophy in `stars`, "Clear all three this week", a three-segment gold bar, then `★ +5`, or a 104×44 Claim button in that slot when the bonus is ready.

**History.** The `ScrollingFrame` takes x 20, y 64, (W − 40)×(H − 110). Rows are 44 high: tag Counter 12 `dim` at 12, title Body 14 at 72, reward Counter 14 right, check 18. Group headers are Label 12, 28 high. "52 Stars from quests this week" Small 12 `soft`, right-aligned, pinned on y = H − 30.

---

## 9. Faceplate shop (`07-faceplate-shop`)

A scrolling two-column grid on the left and a pinned preview pane on the right, so Buy / Equip is under the right thumb and the left thumb scrolls.

| Element | Rect | Notes |
|---|---|---|
| Title "Faceplates" | `hx`, centre y 30 | Title 20. The `DECK STYLE` eyebrow is hidden. |
| Backgrounds | 14 right of the title, 12, 122×36 | Ghost with a 1 px stroke, Bold 14, 44-high hit frame |
| Wallet, back arrow | section 5 | |
| Preview pane | W − 20 − pw, 64, pw×(H − 82); `pw` = 232 (200 when W < 700) | `raised` card. Pinned. |
| Grid | 20, 64, gw×(H − 82); `gw = W − pw − 52` | `ScrollingFrame`, vertical, 4 px scrollbar inside an 8 px gutter |

**Grid.** `cols = 2` when `gw ≥ 420`, else 1. Tile width `(gw − 8 − (cols − 1)·8) / cols`, height 64, gap 8 (pitch 72). `Shop.Columns` becomes a per-instance value so `Shop.step` follows it.

| | 844×390 | 740×360 | 932×430 | 568×320 |
|---|---|---|---|---|
| Pane | 592, 64, 232×308 | 488, 64, 232×278 | 680, 64, 232×348 | 348, 64, 200×238 |
| Grid width, columns, tile | 560, 2, 272×64 | 456, 2, 220×64 | 648, 2, 316×64 | 316, 1, 308×64 |
| Whole rows in view | 4 | 3 | 4 | 3 |

**Tile** (tile-local px): mini deck 88 wide at 10, 9. Name Strong 14 at x 108, centre y 22, truncated. Status at x 108, centre y 43: `EQUIPPED` Label 12 `accent`; check and "Owned" Small 12 `soft`; padlock and "Win 3" Small 12 `soft`; star and price Counter 13 in `stars` when affordable, `soft` when not. Idle `raised` with the stroke; the selected tile is `selected` with the 2 px accent stroke. The whole tile is the target.

**Pane** (pane-local px):

| Part | Position |
|---|---|
| Mini deck | centred, y 10; width pw − 24 (144 when H < 340) |
| Name | 12, 16 below the deck, Bold 18 |
| Tier chip | right edge pw − 12, on the name's line, 22 high |
| Finish | 12, 22 below the name centre, Small 12 `soft` |
| Tint sample | 12, 38 below the name centre, (pw − 24)×36. Only when at least 44 px is free above the status line (844×390 and 932×430). |
| Status line | 12, centre 14 above the button, Body 14 (`soft`; `accent` for Equipped; `#FF8090` for a shortfall) |
| Action | 12, paneH − 60, (pw − 24)×48, primary |

- Scrolling follows selection: keep the selected tile fully in view with 8 px to spare. On open, scroll so the equipped plate is in the second visible row.
- Touch is unchanged: the first tap selects, the pane button acts, and tapping the selected tile again also acts. Buying still needs the 3 s "Confirm ★ 40" second tap. The status table from the main spec applies as written.

---

## 10. What changes in code

| Module | Change |
|---|---|
| `DeckScreen.resolve` | Add the Compact rule from section 1 ahead of the `s < 0.75` test. Return `mode = "Compact"`, the board rect, both columns, `kx / kh`, the strip, control and sheet rects. Keep it pure so `CompactDeck.spec` can assert sizes. |
| `DeckScreen:layout` / `buildHud` | In Compact, hide the shell sprites listed in section 3, stretch the plate, and build the HUD from section 4 as islands on the deck root rather than inside one LCD frame. `setHud` keeps its data contract; add the drawer state. |
| `DeckScreen:addOverlay` / `placeOverlay` | In Compact, place overlays and the results layer on the sheet rect with scale 1. |
| `DifficultyPicker`, `QuestLog`, `DeckResults`, `FaceplateShop` | Each gets a `build(compact)` path, as `DeckResults` already has, that lays out sections 6 to 9 from `W`, `H`, `cw`, `ch`. Callbacks, pure helpers and focus logic stay. `DeckResults` gains an optional `picker` callback and loses its 417-wide compact branch. `FaceplateShop:fit` takes the sheet rect. |
| `DeckKit` | A `Kit.island` constructor; toast and back-arrow offsets for Compact; `dangerText = #FF8090`. |
| `init.client.lua` | Switch the three deck ScreenGuis to `DeviceSafeInsets` while Compact is active and listen for `TopbarInset` changes. |
| `CompactDeck.spec.lua` | It tests the legacy case. Add a spec that runs the four reference sizes and asserts: every target ≥ 44×44, nothing interactive inside the keep-out, no two targets overlap, every `TextLabel` ≥ 12 with `TextFits`, the board keeps its aspect, Replay and Leave lie in the bottom corners. |

---

## 11. Open points

- **Not run anywhere.** These are drawings from arithmetic. Text widths use the Builder Sans files Roblox ships, but island bezels, the cropped plate and `TopbarInset` values need a Studio emulator capture, then a real phone for thumb comfort.
- **Keep-out width.** 116 px is an assumption for two Roblox controls. A wider unibar only narrows the left wing, and the rules in 4.2 already cover that down to no wing at all.
- **Inset switch.** Moving the deck guis to `DeviceSafeInsets` is what gives the board its height. If that is not wanted, the same rules work on a `CoreUISafeInsets` root with `kx = 0`, but a 740×360 phone then has about 302 px of height, which is under the 320 minimum, so sheets would scroll.
- **The band between Compact and Regular** (not compact, `s < 0.75`, for example 1024×768) keeps today's scaled LCD. At 1024×768 today's formula makes the LCD wider than the root. That wants its own pass.
- **The d-pad on touch** is kept because nudging by tap is more precise than dragging for some players. If phone playtests show nobody uses it, the left column can give that corner to the quest handle.
- **Portrait** is still the legacy stacked case.
- **Weekly and History tabs** are specified but not drawn; only the Daily tab has a Compact mockup.
