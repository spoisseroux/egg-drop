# Celebration screens redesign: hatch reveal and round results

**Status: design proposal, 2026-11-12. Nothing here is built.** It answers two of Spencer's v515 QA notes: the hatch reveal card ("make this preview screen more exciting ... spotlight ... stylized graphic ... spinnable") and the results screen ("a lot more animated and fun ... 3D stars model that counts up ... bigger text"), with his retention note ("we need people to come back") applied to results.

Mockups: `artifacts/redesign-2026-11-12/celebrations/`, drawn by `scripts/deck_art/build_redesign_celebration_mockups.py`. They are concept drawings at 1:1 Roblox pixels (plus `@2x`), not Studio captures. The "mid-way" frames are the timelines below evaluated at one millisecond value. The Bear in them is the Blender reference render, cut out and tinted to the undyed in-game colours.

| File | Shows |
|---|---|
| `hatch-desktop-t0360-spotlight-1920x1080.png` | Reveal at 360 ms: spotlight on, silhouette rising, streaks sweeping |
| `hatch-desktop-t0660-reveal-1920x1080.png` | Reveal at 660 ms: colour pop, sparkle burst, headline landed, plate sliding in |
| `hatch-desktop-settled-1920x1080.png` | Reveal settled |
| `hatch-desktop-storyboard.png` | The three desktop frames side by side |
| `hatch-phone-t0660-reveal-812x354.png`, `hatch-phone-settled-812x354.png` | Reveal on a phone |
| `hatch-template-variants.png` | The template filled for three pets and the four headline tags |
| `results-desktop-counting-1920x1080.png`, `-settled-win-`, `-missed-` | Results in the deck (each with `-lcd@2x.png`, the LCD alone) |
| `results-phone-counting-812x354.png`, `-settled-win-`, `-missed-` | Results on a phone |

The reference for the reveal is the energy of a fighting-game character reveal: a dark stage, one hard light, a big diagonal name plate, bold leaning type, light streaks. Every shape, word and sound is ours. No Nintendo asset, logo, layout trace or sound is used or should be.

---

## 1. Hatch reveal

### 1.1 What changes

The 560 px card, its pale bubble and its blue panel go. The reveal becomes a **full-screen stage** above the deck and the garden: near-black, one spotlight, the pet standing in its pool of light, a headline graphic top left, a name plate bottom right. The egg-crack part of `HatchCinematic` (0 to about 0.75 s, 0.95 s for a rare) stays as it is; this spec starts at the moment the egg splits (`t = 0` below).

### 1.2 Layout

All positions are offsets from the screen's top left. The stage is full bleed; only the items listed are placed.

| Item | Desktop 1920×1080 | Phone 812×354 |
|---|---|---|
| Stage fill | `#06070B`, plus a soft accent-tinted glow behind the pet | same |
| Pet (ViewportFrame) | 700×700 centred on x 800, feet on y 842, pet about 590 tall | 230×230 centred on x 268, feet on y 306, pet about 188 tall |
| Spotlight cone | from 92 wide at the top edge to 700 wide at the floor | 34 wide to 240 wide |
| Floor pool | ellipse 700×140 centred (800, 842), accent ring 4 px | ellipse 240×48 centred (268, 306) |
| Light streaks | three accent bands and two hairlines at −16°, behind the pet | same, scaled 0.36 |
| Headline graphic | top left at (88, 76); tag strip 26 px type, big line 80 px; rotated 4° up to the right | (22, 64); 12 px and 27 px |
| Name plate | left edge x 1010, top y 640, 168 high, runs off the right edge; name 128 px; tag strip 22 px; rotated 4° | x 444, y 104, 60 high; name 46 px; tag 12 px |
| Description | strip at (1108, 878), Medium 26, up to 700 wide, two lines at most | (470, 198), Medium 14, up to 300 wide |
| Buttons | y 968, 72 high: "Meet Bear" 300 wide, right edge 88 from the screen edge; "Play again" 240 wide, 16 to its left | y 292, 48 high: 176 and 150 wide, 24 from the edge, 10 apart |
| Spin hint | pill "Drag to spin" centred (800, 962), Bold 16 | centred (268, 338), Bold 12 |
| Next step line | "NEXT · Toy Egg · 6/8 Stars · win quests" at (88, 1004), 16 px | not shown |

Phone rules. Everything starts **60 px down**, under the Roblox controls (keep-out 116×58, from `Kit.keepOut()`); nothing but the dark stage and the beam sits above y 60. Side margins are 24 px plus the device safe inset. Smallest text is 12 px. Buttons are 48 high. On roots under 700 wide, drop the tag strip from the headline and let the description take one line with `TextTruncate.AtEnd`.

Other sizes scale from the pet height: `u = petHeight / 590`, where `petHeight = min(0.55 × H, 0.31 × W)`.

### 1.3 2D or 3D

| Piece | How |
|---|---|
| Pet | **3D.** The existing `PetHero3D` ViewportFrame, bigger, transparent background. Light from above: `LightDirection (−0.25, −1, −0.4)`, `Ambient (88, 86, 104)`, `LightColor (255, 240, 212)`. |
| Spotlight cone, floor pool, accent ring, contact shadow | **2D** images behind and under the ViewportFrame. A ViewportFrame cannot cast a real spotlight or a shadow, so the light is painted. |
| Streaks, sparkles, dust, white flash | 2D frames and one sparkle sprite, pooled like the cinematic's `bits`. |
| Headline graphic | 2D **sprites**. Roblox cannot slant text, so the four fixed tags are drawn once (white, with a separate shadow layer) by `deck_art` and tinted with the accent at runtime. |
| Name plate | 2D. The plate is a sliced image tinted with the accent. The **name is live text** (Builder Extended Bold, upright), so any pet name works. The whole plate group is rotated 4°. |
| Description, buttons, hint | 2D live text and the existing `DeckKit` buttons. |

### 1.4 One template, any pet

| Slot | Comes from | Bear |
|---|---|---|
| Name | `PetCatalog[id].name`, upper-cased | BEAR |
| Tag strip | `"No. %02d · NEW FRIEND"` from `pet.index`; "RARE FRIEND" for `Pets.rares` | No. 01 · NEW FRIEND |
| Description | new field `PetCatalog[id].description`, one sentence, 60 characters at most | "Soft as a nap. Hugs first, asks questions never." |
| Accent (plate, streaks, ring, headline shadow) | the pet's current **secondary palette colour** (its dyed secondary, or `PetBaseColors.secondary`). Lift it so it reads on black: keep the hue, saturation at least 0.55, value at least 0.9. If its saturation is under 0.12 (the undyed grey `#A8A5AE`), use Stars gold `#FFC14D`. | grey, so gold |
| Ink on the plate | `#0E0F12` when it has 4.5:1 on the accent, else white | dark ink |
| Headline | `A NEW / LITTLE WONDER!`, `RARE / DISCOVERY!`, `ALREADY / OWNED!`, `SAVED FOR / YOUR GARDEN!` (the four tags the cinematic already chooses between) | A NEW LITTLE WONDER! |
| Buttons | "Meet {name}" (primary) and "Play again" (secondary), as now. A duplicate keeps its current labels. | Meet Bear |

The same stage can show any pet later (journal entry, rare trial win, shop preview) by passing a different pet, tag and buttons. `hatch-template-variants.png` shows Ovelle and Tikket with example dyed secondaries.

### 1.5 Timeline (ms after the egg splits)

| At | What | Motion | Sound |
|---|---|---|---|
| 0 | Card and egg scene cut away; stage fades to black | 120, Linear | `reveal_hush` |
| 120 | Spotlight snaps on: the cone and pool open from 25% to full width | 180, Back Out | `spot_on` |
| 120 | Pet rises as a **black silhouette**, scale 0.55 to 1, spinning in from 540° and slowing to rest (the first damped spin) | 300, Back Out | |
| 300 | Streaks sweep in from the left, three times brighter than at rest | 220, Quad Out; glow settles by 820 | `streak_whoosh` |
| 420 | **Reveal.** Silhouette turns to full colour; white flash at 60% fading; 18 sparkles burst outward | colour 120; flash 280; burst 480, Quint Out | `reveal_shimmer` |
| 480 | Headline slams in from the left with a 12 px overshoot | 200, Back Out | `tag_slam` |
| 560 | Pet does its greeting pose | existing rig | pet voice (`pet`) |
| 600 | Name plate slides in from the right, smeared while it moves; letters pop 40 ms apart | 240, Quint Out | `name_slam` |
| 840 | Description strip wipes open left to right | 160, Quint Out | `desc_tick` |
| 1000 | Buttons and the spin hint fade up; focus on "Meet"; input opens | 140, Quad Out | |
| 1140 | Settled | | |

A press before 1000 jumps to the settled frame; it does not activate a button (same rule as the results count).

**Idle.** The pet plays its idle and turns slowly on its own (12° a second) until it is touched. The beam breathes ±3% over 4 s. Eleven twinkles fade in and out, about two a second. Dust drifts up through the beam. A glint crosses the plate every 5 s. The spin hint fades after the first spin.

**Exit.** "Meet": plate and headline leave the way they came (140 ms), the beam narrows onto the pet and fades (180 ms), the pet hops, then the usual fade to the garden. About 320 ms. "Play again": everything fades in 160 ms. Sound: `reveal_out`.

**Reduced Motion.** One 150 ms cross-fade from the egg to the settled frame. No sweep, flash, burst, smear, breathing or self-turn; twinkles are still. Sound is `reveal_shimmer` at 60% volume and the pet voice. Spinning by drag still works, but the pet stops when released.

### 1.6 Spin

- **Drag or swipe** anywhere on the stage that is not a button: yaw follows the pointer at 0.5° per pixel (0.6° on a phone). Pitch is fixed; the camera looks 8° down.
- **Release:** the pet keeps the speed of the last 80 ms, capped at 1080° a second, and slows by `ω(t) = ω₀ · e^(−t / 0.55 s)`. It stops under 4° a second.
- **Settle:** after 2.5 s untouched it eases back to its three-quarter pose (yaw −25°) on a spring (1.6 Hz, damping 0.8) and the slow self-turn resumes.
- **Gamepad:** right stick X turns at up to 360° a second; L1 / R1 give a 45° flick that damps the same way. **Keyboard:** Q and E.
- **Tap or click the pet:** a boop, with a small squash (`bear_boop`).
- **A / Enter:** Meet. **B / Esc:** Play again. D-pad left and right move between the two buttons, as now.
- `spin_whoosh` plays on a flick faster than 360° a second, pitched by speed, at most once every 250 ms.

### 1.7 Sound cues (new; Spencer makes the audio)

| Cue | Feel | Length |
|---|---|---|
| `reveal_hush` | The room goes quiet: a short soft downward suck of air | 0.15-0.25 s |
| `spot_on` | A stage light: a soft "thunk" with a warm hum blooming after it | 0.3-0.5 s |
| `streak_whoosh` | Fast airy swipe, left to right, bright top end | 0.25-0.4 s |
| `reveal_shimmer` | The main moment. A bright chime bloom with a glittering tail, like a handful of tiny bells | 1.2-1.8 s |
| `tag_slam` | Punchy paper-and-wood thwack, mid pitch | 0.1-0.2 s |
| `name_slam` | Bigger than `tag_slam`: low thump with a sparkle on top | 0.2-0.35 s |
| `desc_tick` | Light wooden tick | 0.05 s |
| `spin_whoosh` | Soft cloth whirl, repitched by spin speed | 0.2-0.3 s |
| `shimmer_loop` | Very quiet twinkle bed under the idle, seamless | 3-4 s loop |
| `reveal_out` | `spot_on` in reverse: the hum closes down | 0.2-0.3 s |

The rare reveal uses the same cues with `reveal_shimmer` pitched up 3 semitones and a second `name_slam` 90 ms after the first. Existing cues kept: `merge_bubble`, `hatch_rise`, `hatch` (the egg), `pet`, `bear_boop`.

### 1.8 What changes in code

- `src/client/HatchCinematic.lua`: keep the egg beats; replace `buildScene` / `paint` after `splitAt` with the stage (new timeline, silhouette, spin). Grow `PetHero3D` and re-fit with `fitHero`. Add the spin state (yaw, angular velocity, damping) and its input.
- New `src/client/RevealStage.lua` (suggested): the reusable stage. `RevealStage.show(parent, {pet, tag, accent, buttons})` so the journal or a shop preview can use it without the egg.
- `src/client/EggHatchView.lua`: the reveal host becomes a full-screen layer instead of `Card.RevealHost`; the card hides during the reveal; "Meet" and "Play again" move onto the stage and become `DeckKit` buttons.
- `src/shared/PetCatalog.lua`: add `description` to each pet. Accent rule as a small pure function next to `PetBaseColors` so specs can cover it.
- `src/client/DeckAssets.lua` plus a new `scripts/deck_art` builder: four headline sprites (fill and shadow layers), the plate slice, the cone, the pool, one sparkle.
- `src/client/DeckKit.lua`: a `Display` role for Builder Extended Bold. Check in Studio that the family loads (`rbxasset://fonts/families/BuilderExtended.json`); if it does not, use Builder Sans ExtraBold.
- Audio: register the new cues in the audio manifest; `AUDIO-HANDOFF.md` gets the table above.
- Specs: a ZZSpec for the timeline (pure `sample(t)`), the accent rule, the spin decay, and Reduced Motion.

---

## 2. Round results

### 2.1 What changes

Results stay inside the deck screen and keep their data, focus order and buttons. What changes is the weight: a **3D Star** in the middle that the payout flies into while a large number counts up; a slanted outcome **headline** in place of the 12 px eyebrow; larger type everywhere; and a **come-back strip** that always shows the next thing to return for.

### 2.2 Layout: desktop (the 848×608 LCD of the deck on 1920×1080)

| Item | Rect or position | Type |
|---|---|---|
| Headline | centred (424, 48), rotated 3° | Builder Extended Bold 44, white, accent shadow, three speed lines each side |
| Subline | centred (424, 94) | Medium 16, soft: "Creek crossing · Easy" |
| Wallet | right edge 824, y 16, 40 high | counts up with the Star |
| Payout card | (24, 124, 248, 276) | rows Medium 18 with amounts Mono Bold 20; Total Bold 18 with Mono Bold 22 |
| Star (ViewportFrame) | 200×200 centred (424, 212) | the Star is about 164 across |
| Count | centred (424, 332) | Builder Extended Bold 84, gold, dark-gold shadow |
| Unit | centred (424, 386) | "STARS", Builder Extended Bold 17, wide tracking |
| Goals card | (576, 124, 248, 276) | goals Medium 17; Score / Best / Chain Mono Bold 19; NEW BEST chip above the metrics |
| Come-back strip | (24, 412, 800, 56) | left half: next egg meter; right half: the quest this round moved |
| Buttons | y 484, 64 high | Replay (24, 392 wide, A) and Leave to garden (432, 392 wide, B). When an egg is affordable: Replay 392, **Hatch egg** 216 (gold), Leave 160 |
| Hints | y 576 | as now; during the count: "A Skip the count" |

For comparison, today the total is 40 px, payout rows 16 px and the outcome 13 px.

### 2.3 Layout: phone (812×354)

As built, every phone sheet starts at **y = kh + 2 = 60**, under the Roblox controls, with the plate showing in the band above it. The sheet here is 732×288 at (40, 60); the view is 294 tall. Numbers below are root coordinates.

| Item | Rect or position | Type |
|---|---|---|
| Header row | y 62 to 112, hairline at y 114 | |
| Headline | centred (406, 79), rotated 3° | Builder Extended Bold 22 |
| Subline | centred (406, 101) | Medium 12 |
| Stars capsule | right edge x 712, centred y 84, 32 high | Mono Bold 15; counts up |
| Back circle | 44 across at (722, 62) | |
| Payout card | (54, 120, 228, 162) | rows Medium 14 at a 24 px pitch, amounts Mono Bold 16; the next egg meter sits at the bottom of this card |
| Star | 80×80 centred (406, 160) | about 66 across |
| Count | centred (406, 223) | Builder Extended Bold 40 |
| Unit | centred (406, 263) | Builder Extended Bold 12 |
| Goals card | (530, 120, 228, 162) | goals Medium 14 at a 26 px pitch; NEW BEST chip 22 high under the goals; Score / Best / Chain Mono Bold 16 |
| Action row | y 290, 48 high | Leave to garden (54, 160 wide); shortcut cell (224, 238 wide); difficulty (472, 48); Replay (530, 228 wide) |

Compared with the desktop layout, the phone drops "Saved to your wallet" and the difficulty nudge on a win, and the come-back strip is split: the egg meter goes in the payout card and the quest goes in the shortcut cell. With three goals (Hard) the "One more ... would do it" line is dropped and the NEW BEST chip moves beside the `GOALS` label.

The shortcut cell shows the quest this round moved ("Win 2 rounds 1/2"), or a claim, as built. When an egg is affordable it becomes a gold **Hatch Toy Egg** button. At 568×320 the columns narrow to the as-built widths, the Best metric drops, and goals use `goal.short`.

### 2.4 2D or 3D

| Piece | How |
|---|---|
| The Star | **3D.** One `MeshPart` (`StarToken`: a chunky five-point star, bevelled, about 300 triangles, warm gold, slightly glossy) in a ViewportFrame with its own camera. It spins, squashes and tilts for real. |
| Rays behind it | 2D image, rotated. |
| Mini Stars flying in, confetti, sparkles | 2D sprites from a pool. |
| Headline | Live text is fine here (upright Builder Extended Bold, rotated 3°), with 2D speed lines. No sprite needed, so the copy can vary. |
| Everything else | Existing `DeckKit` cards, text and buttons. |

A missed round shows the same Star mesh as a pale glass outline (transparency 0.6, no rays).

### 2.5 Headline copy

Picked once per result, first match wins:

| When | Headline |
|---|---|
| Win with the tidy stack | TIDY WIN! |
| Win and a new best score | NEW BEST! |
| Win on Hard | SPICY WIN! |
| Any other win | ROUND CLEAR! |
| Goals missed | SO CLOSE! |
| Overflow | TOO TALL! |

Missed rounds use white type with grey speed lines, not red. Under the hollow Star: "No Stars this time" and one warm line, rotated from a short list ("Bear still thinks you're great.", "Bear saw that last merge. Bear was impressed.", "One more round? Bear is watching."). The pet's own name fills in.

### 2.6 Coming back

These use data the screen already receives (`balance`, `canHatch`, quest progress, `weeklyLine`); no new economy.

- **Next egg meter.** The wallet against the cheapest egg the player can buy (Toy Egg, 8 Stars). It fills one segment per Star during the count. Full: gold outline, "Ready to hatch!", and the Hatch button appears. On a miss it still shows how close they are ("6/8"); this is the main reason to press Try again.
- **Quest moved.** The daily or weekly quest that advanced this round, with "+1 this round". Rounds-played quests advance on a miss too, so a loss still shows progress.
- **Difficulty nudge.** A quiet line in the payout card: "Medium pays 6 to 8" after an Easy win, "A win on Easy pays 5 to 6" after a miss.
- **Replay stays the primary button**, focused, with a soft pulse every 3 s once the count ends.

Payout rows in the mockups read "Round win 5" and "Tidy stack +1" (total 6), which are the Easy amounts from `HeatPayout` (`roundStars(6) = 5`, `roundStars(8) = 6`). Today the rows read "Round win + tidy stack 8" then "Easy ×0.8 −2". Same total; see open question 3.

### 2.7 Timeline (ms after the screen shows)

For a 6 Star win. The count keeps `RecapFeedback`'s rule: at most 80 ms a Star, done within 900 ms.

| At | What | Motion | Sound |
|---|---|---|---|
| 0 | Screen rises 12 px (as now). Headline slams: scale 1.6 to 1, tilt −8° to 3° | 220, Back Out | `win` (or `lose`, soft) |
| 150 | Goal checks stamp one at a time, 90 ms apart | scale 1.4 to 1, 120 | `goal_tick`, pitch up each time |
| 300 | Payout rows flip in, 120 ms apart; the paying row is highlighted | 140, Quad Out | `row_flip` |
| 450 | The Star drops in from above and bounces; starts spinning at 360° a second | 300, Bounce Out | `star_land` |
| 600 | **Count.** Per Star: a mini Star arcs from the paying row to the big Star (180 ms); the big Star squash-pops (1.12 to 1, 90 ms); the number punches (1.25 to 1); wallet and egg meter tick | every 80 ms or faster | `charge`, +3% pitch a Star (as now) |
| count end + 80 | **Finale.** The Star spins 720° and stops facing front; rays flare and turn; 34 confetti pieces pop; the number flashes white then gold | 500, Quint Out | `stars_total` |
| + 200 | NEW BEST chip stamps in (if earned) | 160, Back Out | `new_best` |
| + 300 | Come-back strip settles; "Ready to hatch!" pulses if earned | 200 | `egg_ready` |
| + 500 | Hints return; Replay starts its idle pulse | | |

The first A, click or tap during the count finishes it at once (as now); the second acts.

**Idle.** The Star turns at 40° a second and bobs 4 px over 2 s. Rays turn at 6° a second. Two or three sparkles twinkle. Confetti falls and fades within 1.2 s.

**Exit.** Replay: the Star zips to the wallet (200 ms), then the existing `retry` wipe. Leave: content drops 12 px and fades (120 ms).

**Missed round.** 0: headline. 150: goal checks; the unmet goal's ring wobbles once, with "One more III would do it" under it when progress was within one. 300: the glass Star floats in and bobs. 500: the egg meter fills to where the wallet stands and the quest line ticks. No count, no confetti. Sound: `lose`, then `meter_fill`.

**Reduced Motion.** Final values at once (as now). The Star is still and faces front, rays do not turn, no confetti, no flying Stars. One `stars_total`, or `lose`.

### 2.8 Input

Unchanged: D-pad or arrows move focus (desktop: Replay, Hatch when shown, Leave; phone: Leave, shortcut, difficulty, Replay); A confirms; B leaves; Up on Replay opens the difficulty picker. New: the Hatch button uses the existing `visitEggs` route. The Star is not interactive.

### 2.9 Sound cues

| Cue | Feel | Length | New? |
|---|---|---|---|
| `win`, `lose`, `charge`, `retry`, `quest_complete` | as in `AUDIO-HANDOFF.md` | | existing names (`win` and `lose` still need audio) |
| `goal_tick` | Small bright check "tik", repitched up per goal | 0.05-0.1 s | new |
| `row_flip` | Soft card flip | 0.08-0.12 s | new |
| `star_land` | A chunky, friendly "boing-clink": metal coin landing on a cushion | 0.3-0.5 s | new |
| `stars_total` | The payoff: a sparkly cymbal bloom over a warm two-note "ta-da" | 0.8-1.2 s | new |
| `new_best` | Short rising three-note flourish | 0.4-0.6 s | new |
| `egg_ready` | A hollow egg "knock-knock" with a twinkle | 0.4-0.6 s | new |
| `meter_fill` | Quick rising zip, quiet | 0.2-0.3 s | new |

### 2.10 What changes in code

- `src/client/DeckResults.lua`: new layout numbers in `build` and `buildPhone`; the Star ViewportFrame replaces the star icon and `starScale`; headline with rotation; come-back strip (desktop) and egg meter (phone payout card); Hatch button and its focus index; `paintCount` drives the number punch, wallet, meter and flying Stars.
- `src/client/RecapFeedback.lua`: `sample` gains the entrance, finale and per-Star pop phases; new cues; the count rule itself is unchanged.
- `src/client/init.client.lua` (the results data builder near line 1540): add `headline`, `eggName`, `eggCost` and the moved quest's progress; optionally the two-row payout wording.
- New `StarToken` mesh (Astra to model, per `AGENTS.md`), referenced from `DeckAssets.lua`; rays, mini Star, confetti and speed-line sprites from a `deck_art` builder.
- `src/client/DeckKit.lua`: the shared `Display` font role (section 1.8); a `reward` button variant if `Kit.button` does not have one.
- Specs: `ZZSpecs` for headline choice, meter maths, focus order with the Hatch button, and Reduced Motion.

---

## 3. Risks

- **ViewportFrame cost on phones.** Each screen has one live ViewportFrame with one small model. Stop the idle turn when the window loses focus (the cinematic's `owned()` check already exists).
- **Painted light.** The beam does not really light the pet; top-down `LightDirection` and the contact shadow have to sell it. Judge it in Studio against the mockup before polishing anything else.
- **Builder Extended.** If the family is not available to the client, the name plate falls back to Builder Sans ExtraBold and long names get narrower. Names over 8 characters scale the plate text down to fit (`TextScaled` with a max size).
- **Length.** The reveal adds about 1.1 s after the egg. Any press skips to settled.

## 4. Open questions for Spencer

1. **Reveal as a full-screen takeover, or kept inside a bigger card?** Recommendation: full screen. The dark stage and the off-edge name plate are what make it feel like an event; a card cannot do either.
2. **Bear's plate colour.** An undyed Bear has a grey secondary, so the rule gives it Stars gold. Recommendation: keep gold for undyed pets and let dyed secondaries take over, so the plate becomes a small reward for customising.
3. **Payout wording on Easy.** Show "Round win 5, Tidy stack +1" instead of "Round win + tidy stack 8, Easy ×0.8 −2"? Recommendation: yes. Same total, and a celebration should not show a minus row. Hard would read "Round win 9, Tidy stack +3".
4. **A Hatch button on results when an egg is affordable?** Recommendation: yes. It is the clearest reason to keep going in the session, and the meter filling toward it is the reason to come back for one more round.
