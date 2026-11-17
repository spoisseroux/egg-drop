# Pocket Deck layout pass + monotone ball themes (after v834)

Art direction only (Astra lane). No code changed. Sol implements in
`src/client/DeckScreen.lua` (`Screen.resolveCompact`) and `src/shared/BallThemes.lua`.
Read from the code and the 750x402 capture; nothing here has been rendered yet, so
every number needs one screenshot check at both sizes before it is called done.

## 1. Handheld layout

### What is wrong now (measured from the code, 874x402 pt, top bar 58)

Body 743 x 323, wings `SW` = 124, d-pad `D` = 88, `A` = 80, B `ib` = 50.

- **The wings are too narrow for what they hold.** A wing is 16.7% of the body. A (80)
  fills 65% of it, the d-pad (88) 71%; with their wells there is about 14 px of enamel
  either side. A Game Boy Micro wing is nearer 28% of the body. This is the cramping.
- **A and B are a stack, not a diagonal.** `ax + bxo` = 25 px across, `dy` = 73 px down:
  71 degrees from horizontal. It reads as two buttons piled up, and B's well lands
  10 px from the glass (the ring touches the bezel in the capture).
- **The left wing has uneven rhythm.** Wordmark to d-pad is about 42 px, d-pad to MENU
  about 61 px, so the d-pad looks like it floated up.
- **The two wings do not answer each other.** D-pad centre is on `mid`; A's centre is
  26 px above it and the pair's mass is right-of-centre in its wing.

### The composition

All fractions are of the body (`bodyW`, `bodyH`) or of the wing (`SW`). Round to whole px.
Worked values: **L** = 874x402 (body 743 x 323), **S** = 812x375 (body 681 x 296).

**Unchanged:** `Screen.Fit` = margin 8, aspect 2.3, crown 16, chin 14. The body is still
the largest 2.3 shape with 8 px clear on all four sides under the top bar. Hit areas
keep their current sizes and rules (A + 8, B + 8, d-pad box up to 144, MENU 44 high).

| # | Variable | Now | Spec | L | S | Why |
|---|---|---|---|---|---|---|
| 1 | `SW` (wing width) | 124 / 112 / 98 by tier | `0.19 * bodyW` | 141 | 129 | Micro proportion: wide wings, small screen. Gives every control 17 px more enamel. |
| 2 | `D` (d-pad) | 88 / 80 / 68 | `0.62 * SW` | 87 | 80 | Same size as today; the wing grows around it (27 px a side instead of 18). |
| 3 | `A` | 80 / 72 / 64 | `0.54 * SW` | 76 | 70 | Still clearly the big button; 4 px smaller buys the diagonal. |
| 4 | `ib` (B) | 50 / 48 / 46 | `0.63 * A`, min 44 | 48 | 44 | Keeps today's A:B ratio (Spencer's "A big, B smaller"). |
| 5 | A-B gap (the `12` in `apart`) | 12 | `0.10 * SW` | 14 | 13 | Wells stop touching. |
| 6 | Pair angle | 71 deg (falls out of `ax`, `bxo`) | **55 deg** from horizontal: `dx = apart*cos55`, `dy = apart*sin55` | dx 44, dy 62 | dx 40, dy 57 | A real diagonal, A up and out, B down and in. Micro's is ~30 deg; 55 is the flattest that fits unequal buttons. |
| 7 | Pair x (replaces `ax`, `bxo`, `nx`) | A +4 out, B 21 in, nudge 6 | Centre the pair's bounding box (B's left edge to A's right edge) on the wing centre, then shift `0.015 * SW` towards the glass | 15 px to glass, 19 px to body edge | 14 / 18 | Equal air both sides; the small inward bias keeps A off the rounded far-right edge (v775 note). |
| 8 | Pair y (replaces `ay` formula, `ny`) | A centre `mid - 26` | Centre the visual mass (A's top to the Items caption's bottom) on `mid + 0.03 * bodyH` | A cy `mid - 22`, B cy `mid + 40` | A cy `mid - 20`, B cy `mid + 37` | The caption is part of the mass; without it the pair hangs low. |
| 9 | D-pad centre `dcy` | `min(mid, lowest)` | `min(mid + 0.03 * bodyH, lowest)` | mid + 10 | mid + 9 | Same optical line as the pair; the bumpers add weight on top, so true centre looks high. |
| 10 | Wordmark width `ww` | `SW - 56` (68) | `0.60 * SW`; `wh = ww * 16/41` | 85 x 33 | 77 x 30 | It is the brand; at 55% of the wing it looked like a label. |
| 11 | Wordmark top `wordY` | `0.15 * bodyH` | `0.13 * bodyH` (keep the `kh + 12`, `top + 10` floors and the give-way rule) | 42 | 38 | Evens the two left gaps: ~52 px above the d-pad, ~51 px below (L); 48 / 46 (S). |
| 12 | MENU pill `g.menu` | 72 x 28 at `H - 44` | `0.45 * SW` wide, 24 high, centred at `bodyTop + 0.86 * bodyH` | 63 x 24 | 58 x 24 | Micro's Start/Select are small and quiet; a pill 58% of the wing and 28 high competed with the d-pad. `g.menuHit` stays 44 high, centred on the pill. |
| 13 | Items caption | 17 high, 4 px under B | Same, 11 pt at tier 2, 12 pt otherwise, 60% opacity, centred on B | | | A label, not a third control. |
| 14 | Items count badge | Upper-left, overhangs towards the glass | Diameter `0.40 * ib`, centre on B's rim at 135 deg (upper-left), so it overhangs by at most `0.1 * ib` | 19 | 18 | Stays inside the wing; never touches the bezel. |
| 15 | `BEZ` (black glass border) | 5 | `0.018 * bodyH` | 6 | 5 | The Micro's black faceplate border is thick; one more px at the large size, free at the small. |

### Screen and edges

- **Glass:** `g.glass = rect(SW, top, W - 2*SW, ...)` is unchanged in form. With row 1
  the glass is 461 wide at L (was 495) and 423 at S (was 457). Top inset stays `crown`
  16, bottom stays `chin` 14. Reason: the Micro's screen is about half its face; ours
  goes from 67% to 62%, which is the look he asked for.
- **Cost, for Sol to check first:** the screen loses 34 px of width. The two-column
  HUD (`LW - GAP - 160` branch) must still fit its cards at S. If a card clips, drop
  row 1 to `0.175 * bodyW` (130 / 119, a 12 px loss) and keep every other row; the fractions still hold.
- **Screen edge:** `Fit.margin` 8 on all four sides, unchanged. Do not shrink it to pay
  for the wings.
- **Top bar:** bumpers still start `Fit.margin` under `kh`. Nothing in either wing may
  sit above `top + 6` (the wordmark's floor); the back button stays in root px, outside
  the body.
- **Tiers:** rows 1-5 replace the three tier tables with fractions. Keep `tier` itself
  for everything else that reads it. Clamp: `A >= 64`, `ib >= 44`, `D >= 68`.

### Acceptance (rendered, both sizes)

1. No well, ring or badge closer than 10 px to the glass or to the body's edge.
2. The gaps wordmark-to-d-pad and d-pad-to-MENU differ by 6 px or less.
3. A line from A's centre to B's centre is 50-60 degrees from horizontal.
4. The whole shell still clears the screen edge and the top bar by 8 px (DeckFit spec).
5. HUD cards on the glass: no clipped or truncated text at 812x375.

## 2. Monotone ball themes

Each theme is one hue; the five sizes step in **value**, smallest darkest to largest
lightest (a ball "charges up" as it merges). Steps are about 10-11 L* apart, and the
balls also differ in radius, so no tier relies on hue. `body / deep / light` are the
existing `ramp(body, deep, light)` arguments. Faces and textures reuse what the
renderer already draws.

| Theme | Price | Face / texture | Ink (face) |
|---|---|---|---|
| **Pea Soup** | 40 | `smiley` / `none` | `#0F1A08` |
| **Pocket Grey** | 40 | `dots` / `none` | `#14161C` |
| **Amber** | 100 | `happy` / `none` | `#2A0E04` |
| **Deep Sea** | 100 | `sleepy` / `none` | `#081430` |
| **Bubblegum** | 100 | `happy` / `sugar` | `#2B0A1C` |
| **Midnight** | 250 | `dots` / `none` | `#F6F2FF` (light face on dark balls) |

Ramps, tier I to V:

| Theme | | I | II | III | IV | V |
|---|---|---|---|---|---|---|
| Pea Soup | body | `#5F7F2A` | `#7A9A34` | `#97B63F` | `#B5D15A` | `#D6EC8A` |
| | deep | `#3F5A1A` | `#56741F` | `#6E8F28` | `#8BAA3A` | `#AFCB5E` |
| | light | `#A8C66A` | `#C2DC78` | `#D9EE8E` | `#ECF9B0` | `#F7FFD6` |
| Pocket Grey | body | `#6B7280` | `#8A919E` | `#A9B0BB` | `#C8CED6` | `#E8ECF0` |
| | deep | `#474D59` | `#636A78` | `#808795` | `#9EA5B1` | `#C0C6CF` |
| | light | `#A3AAB6` | `#BFC5CF` | `#D8DDE4` | `#EDF0F4` | `#FFFFFF` |
| Amber | body | `#B5541A` | `#D4701F` | `#EE8F2A` | `#FFB347` | `#FFD98A` |
| | deep | `#7E3410` | `#A04C14` | `#C0661A` | `#E08A2A` | `#F2B85C` |
| | light | `#E89A5A` | `#FFB866` | `#FFD080` | `#FFE3A6` | `#FFF4D6` |
| Deep Sea | body | `#2F6FD0` | `#4A8CE6` | `#6BA9F5` | `#96C6FF` | `#C8E2FF` |
| | deep | `#1B4A9E` | `#2C66BE` | `#4283D6` | `#6AA2EC` | `#9CC4F5` |
| | light | `#7FB0F5` | `#9CC8FF` | `#BFDDFF` | `#DCEEFF` | `#F4FAFF` |
| Bubblegum | body | `#C2357A` | `#DE5596` | `#F27BB0` | `#FFA3CB` | `#FFD0E4` |
| | deep | `#8A1E55` | `#AE346F` | `#CC548C` | `#E87BAC` | `#F5A8C8` |
| | light | `#EE86B6` | `#FFA6CC` | `#FFC4DD` | `#FFDDEB` | `#FFF2F7` |
| Midnight | body | `#3A2A78` | `#4E3A9A` | `#6650BE` | `#8169DC` | `#9480EE` |
| | deep | `#241A52` | `#34266E` | `#48388E` | `#5E4CAE` | `#7462CC` |
| | light | `#7C6AD0` | `#9280E6` | `#AA98F5` | `#C2B4FF` | `#DCD2FF` |

Size names (the `names` list): Pea Soup: Pea, Sprout, Leaf, Lime, Glow. Pocket Grey:
Pebble, Slate, Stone, Cloud, Pearl. Amber: Ember, Rust, Flame, Honey, Spark.
Deep Sea: Trench, Tide, Wave, Sky, Foam. Bubblegum: Berry, Rose, Candy, Blush, Puff.
Midnight: Dusk, Plum, Iris, Lilac, Star.

Pitches: "Old handheld green, dark to bright." / "Grey pebbles. Size is the tell." /
"Warm embers that glow as they grow." / "From the trench up to the foam." /
"One pink, five strengths." / "Dark balls with glowing eyes."

### Readability rules (and what to check in a render)

- One `ink` per theme has to read on all five bodies. The dark inks are about 3.7:1 on
  each tier I body and higher on the rest. Midnight inverts it: the pale ink is about
  3:1 on tier V and higher on the rest. Hand-estimated; run the numbers once.
- **Midnight tier I on the dark LCD is the risk.** It relies on its `light` rim. If it
  sinks into the board, lift the whole ramp one step (drop I, add `#A894FA` as V) or
  cut the theme.
- Adjacent tiers must be tellable in greyscale: screenshot the Next / Then queue and
  the quest circles desaturated; if II and III merge, widen that step.
- Pocket Grey is the purest test of the idea and also the most colour-blind-safe
  theme in the shop. Worth saying in its listing later.

### How they get added

1. Append six ids to `Themes.Order` after `bubbles` (the saved order of the first seven
   never moves; `Limit` 64 has room) and add six `Themes.ById` entries with `ramps`,
   `ink`, `face`, `texture`, `price`, `pitch`, `names`. Tiers: 40 = `common`,
   100 = `rare`, 250 = `showcase`. The server needs nothing else (it reads `price` and `ById`).
2. **One real change:** line 7's promise ("every theme keeps the hue family per size")
   and `Themes.word` / `spoken` / `aBall` return blue, orange, green, pink, violet for
   every theme. A monotone theme makes "a pink ball" false. Add `mono = true` to these
   entries and have `word(tier)` return a size word (tiny, small, medium, large, huge)
   when the current theme is mono. This touches quest text and screen-reader labels,
   so it is a Sol change with a spec, not a palette edit.
3. No new sprites: `JellyLCD` and the colour circles already draw from the ramps.
   `CircleScale` already steps circle size per tier, which is what carries the
   monotone circles in quest text.
4. New strings (6 names, 6 pitches, 30 size names, 5 size words) go through
   `export_localization_csv.py` and `sync_localization.py` before the publish.
5. Suggested rollout: ship Pea Soup and Pocket Grey first (40 each); they test the
   value-only idea cheaply. Add the three at 100 and Midnight after a render check.
