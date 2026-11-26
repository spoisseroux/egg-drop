# Onboarding v2: the stork, the egg, the Bear (Fable, 2026-11-26)

From Spencer's fresh-save run on beta (35), shots 59 and 60. Read from code, not played. For Opus to build.

**Rule for every step:** one instruction, 16 characters or fewer, never a key name. Phone shows a hand, PC a cursor, gamepad the button picture.

## What is wrong today

- **The Bear hatches twice.** Combo 3 plays the deck's own hatch modal (`init.client.lua` ~2690, `HatchReveal.lua`), then `PetArrivalHatch` hatches the Bear again with the taps.
- **Why the deck hatch looks wonky** (`HatchReveal.lua`):
  - the egg is a flat 58 x 68 round Frame, squashed by uneven `Size` and `Rotation` tweens, so it shears;
  - the portrait pops from 0.05 with a Back overshoot on a second `UIScale` stacked on `StageFit`;
  - ring and shards use fixed pixels (176 x 94, 83 px), not the card's size;
  - it lasts 0.94 s, is skipped under 70 px (phones), and is a different egg from the pixel egg beside it.
- **Shot 59.** "GOALS / Hatch a / friend" wraps in a mostly empty card. Three empty circles mean nothing. The lesson sits in two places (card and pill).
- **Shot 60.** See step 4.
- **After the hatch** nothing says what to do. The bubble's only label is a key cap (`BearNeeds.Keys`, G and L2).

## Cut

- The deck hatch modal and "Sprout Hollow is open!" during the Welcome round.
- The GOALS tab, the pixel egg and the three circles on the Welcome deck.
- The egg phase inside the Bear's reveal card (the egg now cracks in the world).
- "Back" on the first reveal card.
- Key caps on need bubbles for keyboard.
- `Ritual.Auto = 1.1` on the first hatch (too fast for the taps to matter).

## Step 1: the Welcome deck (about 30 s)

**Layout (calm deck, `DeckCalm`).** Left card: the instruction only. Right card: the 3D egg, full card height.

**Instruction card.** No tab. One centred line, `TextScaled` with a size limit of 18 to 34 px, white `#FFFFFF` on the card's navy. Under it, three 22 px shell pips: empty `#2B4C7E`, ring `#9FC4FF`, filled `#FFD86B`.

| When | Card says | Pill over the board |
|---|---|---|
| Start | Drop a ball! | hand tapping (phone), "Click to drop" (PC), A picture (pad) |
| After drop 1 | Match two! | hidden |
| Combo 1 | 2 more! | hidden |
| Combo 2 | 1 more! | hidden |
| Combo 3 | It's hatching! | hidden |

**The egg.** `EggPreview3D.new(card, …)`, type `companion` (the real shell meshes), in a ViewportFrame filling the card with 8 px padding. Glow `#FFE58A` at 20% behind it.

- Idle: yaw 25°/s, tilt bob ±3° at 0.5 Hz.
- Each combo: the spark flies in (keep), then a hop of 10% of card height, a wobble of ±14° damped over 0.4 s, and one fast full turn in 0.6 s. A crack seam lights `#FFFBE6` (one third longer each time) and one pip fills with a 1.0 → 1.3 → 1.0 pop over 0.2 s.
- Sounds: combo 1 `asmr_crack1`, combo 2 `asmr_crack2`, combo 3 `asmr_creak_long`. No pop here; the pop belongs to step 3. Haptics: `crack1`, `crack2`, `creak_long`.
- Combo 3: glow rises to 60% over 0.5 s and the egg lifts 20% and fades out of the card.

**Can / can't.** Aim and drop only. "Skip tutorial" stays, small, at the card's foot, and jumps to step 2.

**Reduced Motion.** No spin or hop: a still three-quarter pose, the seam and pips only.

## Step 2: the stork (6 s)

**Deck.** 0.4 s after combo 3 it tucks: slides down 100% and scales to 0.9 over 0.5 s (Quad in). No new sound.

**The stork (ours, built from parts, client-only, anchored).** About 4 studs tall, 7 stud wingspan. Matte (`SmoothPlastic`, no shine).

- Body and head: white `#F6F3EA` balls. Wing tips `#2E3440`.
- Beak: long wedge `#F28C28`. Legs: thin cylinders `#F28C28`.
- Eyes: two black dots, one white glint.
- A small delivery cap, `#5B8DEF` with a `#FFD86B` band.
- **Bundle:** a blanket `#8FD3FF` with white `#FFFFFF` dots (Fabric), knotted, hanging from the beak, the companion egg's top showing.

**Path.** The egg lands 6 studs in front of the character (raycast to ground; fall back to the spawn pad). The stork starts 40 studs out and 18 up, to the player's right.

| Time | What happens |
|---|---|
| 0.0 to 3.0 s | Glide in on a curve. Wings flap ±35° at 3 Hz, slowing to 1.5 Hz. |
| 3.0 to 3.8 s | Hover and lower the bundle to the ground. |
| 3.8 to 4.3 s | Let go. The blanket opens flat (1.2 stud radius). The egg settles with a ±6° rock. |
| 4.3 to 6.0 s | Two beak clacks, a nod, fly up and away. Destroyed at 6.0 s. |

**Camera.** Scriptable, framing the stork and the landing spot, FOV 55. The character turns to face it.

**Sounds.** New, synthesised with `scripts/synth_asmr.py`:
- `stork_flap_a/b/c` (soft cloth whoosh),
- `stork_clack` (two woody clicks),
- `blanket_rustle`.

Existing: `asmr_egg_set` on the set-down, haptic `settle`.

**Text.** Top-centre pill inside the safe area: "A delivery!"

**Can / can't.** No walking for 6 s. A "Skip" button (bottom-right, 44 px tall, appears at 1 s; B on pad, Esc on PC) jumps to the egg on its blanket.

**Reduced Motion.** No flight. Fade (0.3 s) to the egg on its blanket with the stork standing beside it; one nod; the stork fades out.

## Step 3: crack it (about 5 to 20 s)

**Camera.** Tween 0.6 s to 5 studs from the egg, slightly above, FOV 40. Soft vignette (`#0B1220`, 35%) at the edges.

**Prompt.** Gold pill `#FFD86B`, ink text, below the egg: "Tap the egg!" / "Click the egg!" / A picture + "Crack it!". The hand from `CrackFx` shows over the egg.

**Three taps.** Any tap in the middle 60% of the screen counts; mouse click; A, Space or E. Drive it with `CrackRitual` (three stops) and draw with `CrackFx` at the egg's screen spot (`WorldToViewportPoint`).

| Tap | Egg | Sound | Haptic |
|---|---|---|---|
| 1 | rock ±10°, first crack line, ring, 4 flakes | `asmr_crack1` + 1 `asmr_flake` | `crack1` |
| 2 | rock ±14°, second line, light leaks `#FFFBE6`, 6 flakes | `asmr_crack2` + `asmr_creak` | `crack2` |
| 3 | 0.25 s creak and swell to 1.08, then the pop | `asmr_creak_long` → `asmr_pop` + 3 flakes, then `asmr_exhale` | `creak_long` → `pop` |

**The pop.** The shell top flies up 3 studs and fades over 0.5 s. A white flash, 0.12 s. The real Bear model stands in the blanket and does a small hop. Hold 0.6 s, then step 4.

**Idle help.** No countdown is shown. After 3 s the hand bounces. After 7 s that tap happens by itself. Mashing never skips the pop (keep today's rule).

**Can / can't.** Only tapping. No skip: it finishes itself within 21 s.

**Reduced Motion.** Camera cuts. No rock or flash; a 0.3 s fade. 3 flakes per tap. Sounds and haptics stay.

## Step 4: the Bear's card, fixed

**What is wrong in the code.**

1. `PetArrivalHatch.lua:77` (and `NameEggReveal.lua:86`) sets `ScreenInsets = None` and `IgnoreGuiInset = true`, and `RevealStage` lays everything out from the raw screen corner.
2. `Stage.geometry` (desktop) puts the headline at `(88*s, 76*s)`, right under the Roblox buttons.
3. `Stage.wellRect` computes `top = max(16, feet - petH*1.55)`. At 1080 high that is 842 - 914, so the card's top is clamped to 16 px: inside the top bar.
4. X positions mix three rulers (`W*800/1920`, `88*s` from the left, `W - 910*s` from the right) while `s = min(W/1920, H/1080)`. Off 16:9 they drift apart: the headline slides off the card.
5. Only the phone branch has a top margin: a fixed `top = 60`.

**The rule.**

- The ScreenGui stays full-bleed for the backdrop only: checker, flash, confetti, fade cover.
- Measure a **safe rect** from a probe ScreenGui with `ScreenInsets = CoreUISafeInsets` (same pattern as `clientUI.insetProbe`), re-measured when it changes.
- Inside the safe rect, centre one **content box** with the authored shape: 1920 x 1080 on desktop, 812 x 354 on phone. `s = min(safeW/boxW, safeH/boxH)`.
- Every content position is `boxOrigin + authored * s`. No `W -` or `H -` terms. The name plate's band may bleed to the screen edge, but its text stays in the box.
- Card top is at least `safeTop + 8`.
- Portrait and near-square (W < H * 1.2): a stacked box, 390 x 700: headline, card, plate, line, button.

**Spec.** `Stage.geometry` at 844x390, 932x430, 1024x768, 1366x768, 1920x1080, 2560x1080, 2560x1440 and 390x844, each with a 58 px top inset and a 44 px side notch: headline, card, name, line, buttons and hint all inside the safe rect. Capture each size in Studio for my review.

**Content.** The card opens after its egg phase (start its clock at `timing.ready`). One button: "Meet Bear". Movement returns the moment it is pressed.

## Step 5: what now (about 60 to 90 s, never locked)

One prompt at a time, in the world: a white bubble (`#FFFFFF`, ink `#1B2A4A`) on a BillboardGui with a bouncing arrow `#FFD86B` (6 px, 1 Hz; still under Reduced Motion). A dotted ground trail leads to anything over 12 studs away.

| # | Bubble | Where | Done when |
|---|---|---|---|
| 1 | Pet Bear! (hand icon) | over the Bear | first pet. Hearts, purr, `settle` haptic |
| 2 | Tuck the egg in! (egg and moon icon) | over the Sleepy Nest, with a trail | the egg is tucked ("Hatches tomorrow") |
| 3 | Play for Stars! (deck icon) | over the Bear, with a matching pulse on the deck button | the deck opens, or 20 s pass |

- Phone: tap the thing. PC: click it. Gamepad: the bubble shows the X picture. G and L2 still work but are never printed.
- A prompt ignored for 20 s shrinks to an icon and the next shows.
- **The end.** After the third: a centre card, 2.5 s, tap to close: "You're all set!" over three icons (Deck, Ball, Eggs). `asmr_exhale`, no confetti. The ball and the egg machine are then found through Things to do, as today.
- Join to free: about 60 s. Fully taught: about 3 minutes.

## Skip and replay

- Skip tutorial (deck) → step 2. Skip (stork) → step 3. Steps 4 and 5 never lock.
- Replay: Settings → "Watch the first hatch again" plays steps 2 and 3 with a stand-in egg, no rewards.

## Switches

Add to `Onboard.Features`, `Attributes`, `Keys` and `switches`:

| Switch | On | Off |
|---|---|---|
| `egg3d` | step 1: 3D egg, new words, pips | today's pixel egg and GOALS card |
| `stork` | steps 2 and 3; no deck hatch modal (needs `opener` and `crack`) | today's deck modal and in-card crack |
| `safecard` | step 4's safe-rect layout, for every reveal | today's layout |
| `guide` | step 5's bubbles and the end card | today's need bubbles with key caps |

`/onboard egg3d|stork|safecard|guide off`. All four off is exactly beta (35). `safecard` should go live on its own once the spec and captures pass.

**Events (one-time).** `StorkShown`, `EggSetDown`, `EggTapped` (exists), `BearMet`, `FirstPet`, `NestTucked`, `AllSet`, `OnboardSkipped` (with the step).

## To confirm in play

- That the deck modal and the arrival hatch both play on the Welcome round (read from code).
- Whether shot 60's right crop is the layout or the capture window. The rule covers both.

New art and sound: the stork and bundle (parts), five synthesised sounds, three bubble icons. All ours.
