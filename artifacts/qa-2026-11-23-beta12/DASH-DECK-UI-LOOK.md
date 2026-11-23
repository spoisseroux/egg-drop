# Dash and Deck UI look (beta 12 QA: U1 to U7, G4, S2)

Fable, 2026-11-23. For the Opus builder. Look only: no game rules change. Source: `FEEDBACK.md` in this folder, Spencer's notes and his six phone screenshots.

Mockups (drawn with PIL by `look/ui/build_mockups.py`, no generated images; the pet in them is a placeholder blob, not art):

| File in `look/ui/` | Shows |
|---|---|
| `u1-u2-hint-toast-pet-tag.png` | U1 and U2, now and new, with paddings |
| `u3-dash-mode-picker.png`, `u3-stats-equal-state.png` | U3 |
| `u4-u5-dash-hud-and-lineup.png`, `u4-icons-sheet.png`, `u5-start-grid-plan.png` | U4, U5 |
| `u6-dash-results.png` | U6 |
| `u7-deck-results.png`, `tomorrow-strip-v2.png` | U7 |
| `g4-racing-tag.png` | G4 |
| `icons/dash.png`, `icons/jump.png`, `icons/racing-flag.png` (ink), `icons/dash-white.png`, `icons/jump-white.png` | 256 px, transparent, ready to upload |

## 0. Units, screens, house rules

- **Units are Roblox offset px ("pt")** inside `CoreUISafeInsets`. Spencer's phone is **874 x 402 pt**; his screenshots are 2048 x 942 px, so **1 pt = 2.343 px** there. Sizes below are pt; a few carry the screenshot px in brackets.
- **Phone** (the main target): H <= 430. This is `compact` in `DashCard` today, and it is what every mockup shows.
- **Small phone**: W < 640 or H < 340 (568 x 320). Each section lists what gives way. A 667 x 375 phone takes the phone layout unchanged unless a section says otherwise.
- **Tablet and desktop** (H > 430): the same layout under one `UIScale` of 1.25, lowered until the card fits in W - 48 by H - 120.
- **Colours** come from the Toy Shell roles in `DeckKit` so they follow the equipped deck: `panel` (shell), `raised` (tray), `well`, `tile` (cream key), `accent` (go). Fixed colours: ink `#15143A`, ink soft `#4A4972`, cream `#FFF4DC`, cream lip `#D6C196`, go `#43DB5F`, lemon `#FFE14D`, Stars `#FFC14D`, white `#FFFFFF`, soft `#DCE5FF`, puff `#B9B6C9`. Stat colours from `StatCatalog`: Heart `#FF86A8`, Power `#FF9D4D`, Energy `#6CCBFF`, Jump `#B9EE5A`, Speed `#8FA8FF`. The mockups use the moss deck (`#23752E` shell, `#164F1E` tray, `#091F0C` well).
- **Fonts** are the `Kit.text` roles: `Title` and all display words in FredokaOne; `Strong` BuilderSans Bold; `BodyMedium` Medium; `Body` and `Small` Regular; `Label` Bold caps; `Counter` RobotoMono Bold. Buttons use `Kit.button`.
- **Strokes**: 2 pt ink on cards and chips, 3 pt on the big sheet cards and the HUD pads. Radius: sheet 22, well 14, tray 10, chips half their height.
- **Reduced Motion** (`Kit.reduced()`): every move, pop, hop, count-up and confetti below becomes a 0.15 s fade to the final state. Each section only lists what is special.
- All new words go in `UICopy` (list in section 10) and through the localization export.

## U1. Notification text sits high

Two cards are affected. Both move their content down 2 pt; nothing else changes.

**Hint card** (`PetFocusUI` `PettingHint`, and `RoamPetHint` with the same rule). Today the label is its own background with 4 pt above and below the words and 8 pt at the sides.

| | Now | New |
|---|---|---|
| Top / bottom padding | 4 / 4 | **6 / 4** (`UIPadding`, height = text height + 10) |
| Side padding | 8 / 8 | **12 / 12** (width = text width + 24) |
| Radius | 10 | 10 |

**Toast** (`NotificationRail`). The disc, message, "+N" and chevron are centred in the face minus `TimerRoom` (8), which leaves them high in the card.

| Size | Face | Shift | Disc y now -> new |
|---|---|---|---|
| full | 40 | **+2** | 4 -> 6 |
| compact | 31 | **+2** | 1 -> 3 |
| tight | 29 | **+1** | 1 -> 2 |

The message, amount and chevron get the same shift (their box moves down; height unchanged). The timer bar stays at face - 6. A persistent card (no timer) is already centred: no change.

## U2. Pet tag (`PetFocusUI` bond card with the Heart chip)

Today: 150 x 48 minimum, name on top, chip under it. That leaves 64 pt of empty card right of the chip and 3 pt under it.

New: **one row, 48 tall, the card hugs its words.**

- Row: `12 | name | 10 | chip | 10`. Both are centred on the 48 pt row, so the chip has 13 pt above and below it.
- Width = 12 + name + 10 + chip + 10, clamped **120 to 220**. The name truncates with an ellipsis first. `FocusRow.layout` keeps the right edge where it is and grows the card to the left.
- Name: `Title` (FredokaOne) 16, white, left aligned. Not localized.
- Position, stroke, 0.08 transparency: unchanged.

**The chip** (`StatsPanel.heartChip`, the non-compact one), 22 tall, radius 11:

- `6 | heart icon 14 | 4 | stat word | 5 | level disc 18 | 2`.
- Fill `well`, ring 1.5 pt in the stat colour (as now).
- Stat word: `Strong` 12, `#FFD3DF` (Heart colour lightened 60% to white; for another stat, the same mix of its colour).
- **Level in a filled disc**: 18 pt circle in the stat colour, the number in FredokaOne 12, ink. Two digits: the disc becomes a pill, 18 tall, 5 pt side padding. This is what makes "Heart 1" read as "Heart, level 1" and not as a name.
- Accessible label: unchanged ("Heart 1").
- Level up: the disc boings (`Kit.boing`), 0.3 s. Reduced Motion: none.
- **Small phone (W < 700)**: the word is dropped: `6 | heart 14 | 5 | disc 18 | 2` (45 wide). The card is then about 150 wide and stays clear of the hint card in the middle.

The task brief calls this "the pet's top stat"; the code shows the Heart level. The chip above works for either: icon, word, ring and disc all take the shown stat's colour.

## U3. Garden Dash mode picker (`DashCard` gate)

Replaces the low strip with a centred sheet: the pet on a stage at the left, its stats and the three races at the right. The side-on camera shot of the course stays behind the shade.

**Card**: 620 x 276 [1453 x 647 px], centred at (W/2, H/2 + 14), `panel`, radius 22, 3 pt ink stroke, padding 14. Shade as now.

**Stage** (left): x 14, y 14, **196 x 248**, `well`, radius 14, 2 pt ink stroke.

- A `ViewportFrame` fills the stage, with a `WorldModel` holding a clone of the active pet at race scale, posed by the Dash run cycle in place (treadmill: `DashPose` with a fixed spot, pace 100%). Camera: front three-quarter, 20 degrees right of head-on, 10 degrees down, the pet filling 60% of the stage width. `Kit.petLight`.
- **Pedestal**: a 132 x 26 cream ellipse (`#FFF4DC`) with a 6 pt lip (`#D6C196`) under the feet, 62 pt above the stage's bottom edge. Under it a 168 x 30 lemon glow, 18% opacity.
- **Spotlight**: a white wedge from the top centre (36 wide) to the pedestal (157 wide), 10% opacity, drawn behind the pet.
- Name: FredokaOne 16, white, centred, 32 pt above the bottom. Under it `Small` 11 soft: "{band} · Dash level {level}" (`DashStats.band`, `dashLevel`).
- The viewport is made when the card opens and destroyed with it. If the pet cannot be cloned: the stage shows the pet's portrait (`PetPortrait`) on the pedestal.

**Right column**: x 224, width 382.

| Row | y | h | Content |
|---|---|---|---|
| Title | 14 | 30 | `dash.title`, FredokaOne 24, white. Close key 32 at the top right (x 574, y 12) |
| Line | 46 | 18 | `dash.gate.line`, `Body` 13, soft |
| Stats | 72 | 72 | a `raised` tray, radius 10: three rows, pitch 20, first at y 8 |
| Races | 152 | 76 | three tiles, 122 x 76, gap 8 |
| Foot | 238 | 22 | left: Star 14 + `things.dash.prizes` in `BodyMedium` 12 soft (only with prizes on). Right: "Best {best} s", `Strong` 12 soft, right aligned (only with a saved best) |

**A stat row** (Speed, Energy, Jump, in that order): icon 14 at x 10 (the atlas `sneaker`, `bolt`, `spring`, in the stat colour); name `Strong` 12 white at x 30; bar at x 92, **210 x 8**, radius 4, track `well`, fill the stat colour, fill = level / 99 with an 8 pt minimum; "Lv {n}" `Strong` 12 white, right aligned at x 372.

**A race tile**: `Kit.button`, 4 pt lip. Name in the button face, 15, ink, centred 10 pt above the middle; one line under it, `BodyMedium` 11, ink soft, centred 11 pt below the middle.

| Tile | Line under it |
|---|---|
| Just for Fun | All pets equal |
| Stats On | Your levels count |
| Time Trial | Solo. Beat the clock |

**States**

- The race played last time (Just for Fun for a new racer) is the `primary` (go green) tile and has the focus. The others are cream.
- **The stats follow the focused or hovered tile.** Stats On: full colour, as drawn. Just for Fun or Time Trial: rows at 45% opacity, every bar a 50% puff-grey fill, the "Lv" numbers hidden, and a cream pill centred on the tray: "All pets equal in this race" (FredokaOne 12, ink, 22 tall, 10 pt side padding, 1.5 pt ink stroke). Cross-fade 0.15 s. Touch has no hover: the stats show the green tile's state.
- A tap on a tile starts that race at once, as now. Pressed: the tile drops its lip.
- A locked reason (`dash.reason.*`) still shows as the toast it is today.

**Motion**: the card springs in (scale 0.92 to 1, 0.22 s, as other sheets). The pet runs all the time. The spotlight fades in over 0.3 s, 0.1 s after the card. Reduced Motion: the pet stands in its idle pose; no spring.

**Gamepad and keys**: focus starts on the green tile. D-pad left and right move between the three tiles (no wrap). A or Enter starts. B, Backspace or the close key closes. Nothing else is selectable.

**Small phone**: card min(620, W - 24) x 236; stage 150 x 208 (pedestal 102, name 14, the band line dropped); the Line row dropped; stats at y 50, pitch 18, tray 64 tall; tiles at y 122, 60 tall, the line under each name dropped below W 600; foot at y 190.

## U4. Dash HUD: sprint and jump pads (`DashHud`)

The bar-built bolt and spring go. Each pad gets a drawn icon and its word.

- **Icons**: `icons/dash.png` (a bolt with three speed lines) and `icons/jump.png` (a fat arrow going up over one of the course's own hoops). 256 px, transparent, ink `#15143A`. White copies are there if a tintable upload is wanted (`ImageColor3` = ink). They hold up down to 24 pt (`u4-icons-sheet.png`).
- **Pad**: 96 pt circle (108 on desktop), where it is now (16 pt from the corner). Face lemon `#FFE14D` (Dash) or go `#43DB5F` (Jump), opaque (today 8% see-through). 3 pt ink ring. A **5 pt ink lip** under it, like every other key.
- **Icon**: 50 x 50, centred, its top 9 pt under the pad's top.
- **Word**: `dash.dash` / `dash.jump` in capitals, FredokaOne 14, ink, centred at 76% of the pad's height. Always shown, on every device.
- **Key cap** (keyboard or gamepad only): a `Kit.glyph` cap 20 tall at the pad's top right, overlapping it by 8 pt: Shift / Space, RT / A. It replaces the white stroked text under the pad.
- **Dash bar**: as now (above the Dash pad, pad wide, 14 tall, 2 pt ink ring, lemon fill).

**States**

| State | Look |
|---|---|
| Rest | as above |
| Pressed | the face drops 4 pt into the lip, 0.06 s; back in 0.1 s |
| Dash held | the face stays down; the ring turns white while the bar drains |
| Out of puff | face and bar fill `#B9B6C9`, icon at 50%, the word becomes `dash.puff` ("Phew!") until the bar is back |
| Jump ring | the white closing ring, as now |
| Perfect | the Jump pad flashes white 30% for 0.12 s |

Reduced Motion: no drop, no flash; the pressed face is 10% darker.

**Around them** (small, same pass):

- **Countdown digits**: centre at 26% of the height (today the middle, on top of the pets). FredokaOne 72, white, 4 pt ink stroke.
- **Place**: a pill left of the progress strip (8 pt gap), 54 x 24, ink at 65%, FredokaOne 15 white. It no longer sits alone at the far left.
- **Progress strip**: 20 tall. A cream cap with `icons/racing-flag.png` (16) at its right end; 2 x 12 white ticks at 35% where the hoops are. Your dot: 18, lemon, 2 pt ink ring. Others: 12, cream.

Gamepad: nothing here is selectable (as now).

## U5. Dash start: a wider line, every name

Max racers: **8** (`DashSim.MaxRunners`, `DashCourse.LaneCount`). Today the lanes are 0.5 studs apart (3.5 studs for eight pets), so they stand inside each other.

**The line** (`u5-start-grid-plan.png`). The race only counts the centre line, so this is drawing only.

- At the start the lanes are **1.5 studs apart** (rule: the widest racer's width at race scale + 0.3, never under 1.5). Eight racers span 10.5 studs between the outer centres.
- **Fewer racers stay centred**: a racer's slot is its order among the racers present minus (n + 1) / 2, not its lane number. Two racers stand side by side in the middle.
- **Funnel**: from 3 studs to 11 studs past the line the step eases from 1.5 to today's 0.5 (smoothstep), so everyone is on the path before the first hoop (14 studs on at the earliest, 4.4 wide). Reduced Motion: the same path (it is the race, not an effect).
- **Arch posts** move out to +/- 6.4 studs from the centre line; the start pad's slabs widen to match (eight slabs, 1.5 each).
- **Line-up shot**: for the gather and the countdown the camera sits behind and above the row so the whole row fills at most 70% of the screen width, then eases to the race camera over 0.6 s at GO. Reduced Motion: a cut.

**Names** (`DashProps` tags). During the gather and the countdown **every racer's name shows**, never hidden by another.

- Tag: 22 tall, radius 11, FredokaOne 13, ink on cream `#FFF4DC`; **yours is lemon** `#FFE14D`. 2 pt ink ring. 9 pt side padding, 104 wide at most (ellipsis). The same size on screen at any distance.
- **Two tiers**: odd slots sit 0.5 studs over the head, even slots one tier higher (30 pt more on screen). A 2 pt ink stem joins each tag to its pet's head. Same-tier tags are then two pets apart and cannot touch.
- If two tags still overlap after that (odd camera angles), the farther one goes up one more tier. None is hidden.
- In: each tag pops (scale 0.8 to 1, 0.15 s), 40 ms apart, left to right. Out: at GO + 1.5 s all fade over 0.3 s. From then on today's rule runs (a pal's tag shows near your pet). Your own pet keeps a small lemon chevron (14 pt, bobbing 3 pt at 1 Hz) over its head for the race. Reduced Motion: no pop, no bob.

## U6. Dash results (`DashCard` results, words from `DashResults`)

One sheet with a pet moment, the place, the time, what was earned, the field, and one green next step.

**Card**: 620 x **312** with the See you tomorrow strip, **256** without; centred at (W/2, H/2 + 14); `panel`, radius 22, 3 pt stroke, padding 14. **No close key**: Done is the way out, so there is only one decision on the card.

**Stage** (left): x 14, y 14, 196 x 172. The same stage as U3 (well, spotlight, glow), with:

- A **podium step** in place of the pedestal: 132 x 22 cream block, 8 pt lip, radius 8.
- The pet in its finish pose: two hops (1.2 studs, 0.42 s each, as `DashPose`), then a happy idle with a hop every 3 s. 4th or lower: one hop, then a wave or wag. Never a sad pose.
- A **medal** at the stage's top left (8 pt in): 40 pt disc, 2 pt ink ring, the ordinal (`dash.ordinal.*`) in FredokaOne 16, ink. Disc colour: 1st Stars `#FFC14D`, 2nd soft `#DCE5FF`, 3rd Power `#FF9D4D`, 4th to 8th cream. Time Trial: the cup colour for a cup time, else cream with a stopwatch glyph.
- **Confetti** for 1st to 3rd and for a cup: 24 pieces, 3 x 8, in Stars, Heart, Energy, Jump and white, falling inside the stage for 1.2 s.

**Right column**: x 224, width 382.

| Row | y | h | Content |
|---|---|---|---|
| Headline | 12 | 36 | the existing title (`dash.result.place` / `trial` / `noTime`), FredokaOne 28, white, with a 2 pt drop shadow in `#B8791A` |
| Time | 54 | 40 | `raised` tray. "TIME" `Label` 11 soft at x 12; the time FredokaOne 22 white at x 48. "BEST" `Label` 11 soft at x 166; the best `Strong` 16 white at x 202. A new best: a Stars chip "NEW BEST" (72 x 22, FredokaOne 11, ink) at the right. No best yet: the BEST pair is left out |
| Earned | 100 | 40 | `raised` tray. Star 24 at x 12; "+{n} Stars" FredokaOne 20 in Stars at x 44. Right: five 10 pt pips (filled Stars for races paid today, `well` for the rest, 1 pt ink ring) and "{done} of {total} today" `BodyMedium` 12 soft |
| Field | 146 | 40 | up to four chips, equal width, gap 6: the top three and you (if you are lower, you take the fourth). Each: place disc 16 in its medal colour, name `Strong` 11, time `BodyMedium` 11 soft under it. **Yours is lemon** with ink text; the others `well` with white. Left out for a Time Trial and for a race of one |

The Earned row's other cases, same tray:

| Case | Row shows |
|---|---|
| Stars not saved yet | Star at 40%, "Saving…" soft; the count starts when the receipt arrives (as `setLine` does today) |
| Today's Stars races used up | five full pips and "Stars again tomorrow" soft; no "+0" |
| Prizes off | the row is left out; the Field row moves up |
| Time Trial with a cup time | a cup disc in the cup colour and `dash.medal.*` in FredokaOne 18 |
| Time Trial, no cup | `dash.result.tryAgain`, soft |

**See you tomorrow**: x 14, y 194, 592 x 48 (strip v2, section U7). Only when its model is there.

**Buttons**: y 250 (194 without the strip), 48 tall with the lip. **Race again**: primary, x 14, **388** wide. **Done**: secondary, x 410, **196** wide. Two to one, so the eye lands on the green one.

**Order of events** (seconds from the card opening)

| t | What |
|---|---|
| 0.00 | shade 0.2 s; card springs in 0.22 s |
| 0.15 | the pet drops 12 pt onto the step, lands with a squash (0.3 s); the medal pops |
| 0.30 | the headline lands: scale 1.5 to 1 with a back-out, 0.32 s (the deck results' own move). Buttons take input from here |
| 0.55 | the time counts up from 0, 0.5 s |
| 1.05 | the Stars count up, 0.6 s, the pips fill one by one; confetti starts |
| 1.25 | the Field chips pop, 60 ms apart |
| 1.70 | the strip comes in (its own move) |
| 1.90 | Race again pulses once (`Kit.pulse`), then every 6 s |

Reduced Motion: the pet sits and smiles; no confetti, no pulse; final numbers at once.

**Gamepad and keys**: focus on Race again. D-pad left and right move between the two. A or Enter presses the focused one. B or Backspace is Done.

**Small phone, or H < 390**: the Field row is dropped (card 272 / 216, stage 132 tall). Below W 640: card W - 24 wide, stage 150 wide, Race again and Done keep two to one.

## U7. Pocket Deck results in place (`DeckResultsInPlace`, `TomorrowStrip`)

On Spencer's phone the three LCD panes are about 125, 162 and 126 pt wide and 261 tall. The strip was squeezed into the 125 pt pane (27 pt per chip), which is why it could not be read; the four 44 pt buttons took 188 of the right pane's 261.

### See you tomorrow strip, v2 (all three hosts)

The title tab that sat half over the top edge is gone. **The title has its own row inside the strip.**

- **48 tall** on phones (was 36), radius 12, fill `#20234A`, 2 pt ink stroke.
- Title row: a 10 pt moon mark at x 10 and `onb3.strip.title` at x 25, FredokaOne 12, `#DCE5FF`, vertical centre at y 11.
- Chips: y 21, **22 tall**, three equal columns, 6 pt from the sides and between. Fill `#2C3060`, 1.5 pt ink stroke. Icon 16 + 5 + words, **centred in the chip**. FredokaOne 12, white; the stamp chip in Stars `#FFC14D`; a ready nest chip stays gold as now.
- **Width decides the words**: 400 or wider, the whole words ("Ready in 8 h.", "Stamp 2: 4 Stars", "3 new quests"). Under 400, the short values. **Under 240 the strip is not drawn at all.**
- Desktop (the one-row 44 pt strip with the title at the left): unchanged.
- Motion: as now (12 pt up and a fade, chips 60 ms apart).

### Layout with the strip on

- The three panes give up **54 pt** of height (48 + 6). The strip sits under them across the **full LCD width**: x = the left pane's x, width = from there to the right pane's right edge (about 427), so it always gets the whole words.
- With the strip off, the panes keep their full height and everything below still applies.

**Left pane, payout** (padding 10):

- "PAYOUT" `Label` 11 soft at y 8. Rows from y 28, pitch 22, `BodyMedium` 13, amounts `Strong` 13 right aligned. A 1 pt rule, then **Total** `Strong` 15 in Stars with a 12 pt Star and the number in FredokaOne 16 at the right.
- The "Today" line is left out while the strip is on (the wallet says it); kept without the strip.
- **Stat gains**: no "Stats" title. One row a stat, pitch 18, starting 14 pt under the Total: a 10 pt dot in the stat colour, the stat name `BodyMedium` 12 in its colour, the gain `Strong` 12 white. A level-up shows as a **pill at the right**: "Lv {n}", FredokaOne 10, ink on the stat colour, 14 tall. It replaces "(Lv 2!)".
- Wallet chip (28): pinned 8 pt from the left and bottom.
- More than fits: the rows scroll above the wallet, as now.

**Middle pane, the Star**: headline 24 at y 26; round name `BodyMedium` 12 at y 46; with the strip on the Star's band is top 58, foot 52 (today 70 / 64), so the Star stays about 80 pt; the count FredokaOne 26; the saved line 11 pt, 15 pt above the bottom.

**Right pane, goals and actions** (padding 6 for the actions, 10 for the goals):

Actions, pinned to the bottom, **128 tall in all (was 188)**:

| Row | Button | Size | Notes |
|---|---|---|---|
| 1 | Replay | full width x 44 | primary, 15 |
| 2 | Difficulty | full width x 36 | cream, 3 pt lip, radius 10, 13. A soft chevron (`‹` `›`, ink soft, 18) 12 pt in from each side shows that it steps |
| 3 | Hatch, Leave | two halves x 40, gap 4 | cream, 3 pt lip, radius 10, 13. Short labels: "Hatch", `results.leave.narrow` |

Gaps between rows: 4. Sizes include the lip. If a translated label does not fit a half button at 13, it goes to 11; if it still does not fit, row 3 becomes two full-width rows of 36 (164 in all).

Goals, in what is left above: "GOALS" `Label` 11 soft with the count right aligned at y 8; rows from y 26, pitch 22, a 12 pt ring or check and the goal in `BodyMedium` 12 (open goals at 75%). A third goal or the score line scrolls.

**States**: pending save: Replay reads "Saving…" and rows 1 to 3 except Leave are disabled (as now). Focus ring as now.

**Motion**: the existing entry (`View.Entry`) is kept. The strip comes in 1 s after, as now.

**Gamepad**: Replay, Difficulty, Hatch, Leave (the existing `ORDER`). Down from Difficulty goes to Hatch; right from Hatch goes to Leave, left from Leave to Hatch; up from either goes to Difficulty. On Difficulty, left and right change it (as now). A presses, B leaves.

**The grid layout** (right pane 176 or wider) and the desktop sheet (`DeckResults`) are not changed by this pass, except that they take strip v2.

## G4. Onlookers: a "Racing" tag

Keep racing pets visible to everyone: it is lively and it shows the game to people who have not tried it. Give each racing pet a small tag so it reads as "in a race", not as a pet running off.

- Who sees it: every player who is **not** in that race. Racers see names (U5) and never this tag.
- A `BillboardGui` 0.5 studs over the pet's head, in place of its normal name tag for the race. The same size on screen at any distance; hidden past 60 studs.
- Pill **20 tall**, radius 10, cream `#FFF4DC`, 2 pt ink ring, 90% opaque: `7 | icons/racing-flag.png 14 | 4 | "Racing" FredokaOne 12 ink | 9`.
- In: fade 0.2 s at GO. Out: fade 0.2 s when that pet is home. No bob, no loop.
- While it shows, the pet takes no pet, feed or pick-up prompts from onlookers.
- Not selectable, no sound.

## S2. New tip chime

A sound for a new tip arriving in the Things trail, and nothing else.

- **Character**: two soft mallet notes going up, like a small wooden xylophone or a kalimba with a felt beater. Second note a fourth or a fifth above the first (for example G5 then C6, or E5 then B5). Notes 90 ms apart.
- **Length**: 0.35 to 0.5 s with the tail. Soft attack (no click), quick decay, a little room, no long reverb.
- **Tone**: warm and round, most energy between 600 Hz and 3 kHz. No bell shimmer, no synth "ding", nothing that reads as a phone alert or an error. No voice, no melody a player could name.
- **Level**: quieter than the Stars pickup; about 0.25 volume on the UI group. Pitch varies +/- 3% between plays.
- **When**: once as the tip card lands. Never more than once in 20 s; silent while a deck round, a race or a hatch is on, and when the sound setting is off. Reduced Motion does not change it.
- Sourcing: a CC0 file or a Roblox library sound that fits, two or three candidates for Spencer to pick from. Record the licence beside the file.

## 10. New words (`UICopy`)

| Key | English |
|---|---|
| `dash.sub.fun` | All pets equal |
| `dash.sub.stats` | Your levels count |
| `dash.sub.trial` | Solo. Beat the clock |
| `dash.equal` | All pets equal in this race |
| `dash.band` | {band} · Dash level {level} |
| `dash.bestShort` | Best {best} s |
| `dash.label.time` / `dash.label.best` | Time / Best |
| `dash.result.newBest` | New best |
| `dash.result.starsShort` | +{reward} Stars |
| `dash.result.today` | {done} of {total} today |
| `dash.result.tomorrow` | Stars again tomorrow |
| `dash.result.saving` | Saving… |
| `dash.racing` | Racing |
| `results.inPlace.hatchShort` | Hatch |

`dash.gate.modes` is no longer shown (the tiles say it).

## 11. Uploads

`icons/dash.png`, `icons/jump.png`, `icons/racing-flag.png` to the UI image set; record the ids next to `DashHud` and `DashProps`. The chime once Spencer has picked one.

## 12. Open questions for Spencer

1. **Pet tag stat.** Is the chip always the Heart level, or the pet's highest stat? The look covers both; the builder needs to know which number to show.
2. **Start width.** Eight racers need the arch about 13 studs wide (posts at +/- 6.4). OK to widen the arch and pad, or keep the arch and let the outer pets stand outside it?
3. **Lanes mid-race** stay 0.5 studs apart, so pets side by side still overlap after the funnel. Widen the course lanes too (needs the course script and wider hoops), or leave it?
4. **Onlookers and hoops.** Hoops are local to racers, so onlookers see pets jump over nothing. Show the hoops to everyone near the course during a race?
5. **Deck results**: is "Hatch" short for "Hatch eggs" fine on the half button?
6. **Results with no X**: Done is the only way out besides Race again. OK?
