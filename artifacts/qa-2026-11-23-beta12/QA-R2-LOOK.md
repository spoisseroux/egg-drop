# QA R2 look spec (Fable, 2026-11-23)

Spencer's second round of notes on beta (12). Six items; every number here is the target. Build is Opus's lane.
Standing rules hold: ambient life realistic and textured, motion soft, no AI art or audio, Reduced Motion unchanged.
Things I could not check from here are marked **[check]**.

## 1. Springs you can see

Why nobody saw them: a release overshoots 2 px (`Kit.Press.over`), a screen rises 12 px with 13% overshoot (1.5 px),
art pops from .85 and is clamped at 1.06. All real, all under what a thumb-covered phone screen shows. The fix is
amplitude and a slower, rounder ring, not more springs. Overshoot by damping, for reference: .28 = 40%, .32 = 34%,
.35 = 31%, .40 = 25%, .45 = 21%, .50 = 16%, .55 = 13%.

Add one thing: a **press scale** (a `UIScale` named `PressScale`, same rule as `BoingScale`: never beside a foreign
UIScale, never under a grid layout). Down is a 60 ms tween (as now), release is the spring. The hit rect never shrinks
(scale the face/content, not the button).

| Control | Down (60 ms tween) | Release spring | Clamp |
|---|---|---|---|
| Ledge button (`Kit.Press`) | face onto the lip as now, widen 2 -> **4 px** a side, PressScale **.95** | KitDrop and PressScale: **4.5 Hz, damping .32**, `over` 2 -> **5 px**, limit .35 -> **.6 s** | scale top **1.06** |
| Ghost / flat button | drop 2 px, PressScale **.94** | 4.5 Hz, .32 | top 1.06 |
| Tile (`pressTile`) | onto the lip, PressScale **.96** | 4.5 Hz, **.38** (was 6 / .28, 2 px); over **4 px** | top 1.04 |
| Round key / icon button | 2 px, PressScale **.88** | **5 Hz, .32** | top 1.12 |
| Wallet / chips (`TapScale`) | 1.12 -> **1.18** | replace the Back tween with a spring 5 Hz, .35 | 1.18 |
| Toggle knob | | 5 Hz / .65 -> **4.5 Hz / .45** (overshoots 4-5 px of the 22 px travel), limit .5 | |
| Tab pill (`KitPill`) | stretch 6% -> **14%** at mid-flight | 6 Hz / .7 -> **5 Hz / .5**, limit .25 -> .45 | inside the track, as now |
| Wallet Star hop (`KitHop`) | | 5 Hz, .4, velocity 416 -> **620**, cap 8 -> **12 px** | |
| `Kit.boing` | from .96 / .94 -> **.90 / .88** | 5 Hz, .45 -> **.35**; growth cap 8 -> **14 px** total | |

Menus (feature `menus`):

| Moment | Now | Target |
|---|---|---|
| Screen / card open (`Kit.arrive`) | 12 px rise, 3.2 Hz, .55 | rise **28 px** (phone **22**), **3.0 Hz, damping .42** (peaks ~6 px past home), plus a root UIScale **.90 -> 1** on the same spring, clamped at **1.03**, with the fade it has |
| Bottom sheet (phone) | | from **40 px** below, 3.2 Hz, **.50** (6 px past, then back) |
| Close | | no spring: **.12 s** Quad In, scale to **.94**, 10 px down, fade. Closing must stay snappy |
| Art pop (`Kit.Pop`) | .85 -> 1, top 1.06, 25 ms apart, done by .35 s | **.70 -> 1, top 1.12, 4.5 Hz, .40, 40 ms apart, done by .55 s** |
| Toast in | | from 16 px, 3.5 Hz, .45 |

Rules: `Kit.Motion.bounce` still scales all of it (1 = these numbers). Spring caps (24 phone / 48 desktop), AliveBudget
level 2 (no art pop, no root scale: rise only) and Reduced Motion (everything snaps, as today) do not change. Text is
never scaled on its own; it rides its panel's or button's scale. Acceptance: at 390 x 844, a filmed tap on Play and an
open of the deck menu show the overshoot on a single viewing at normal speed; nothing rings more than twice.
**[check]** a root UIScale on the big deck menu for text re-raster cost on a low phone; if it costs, keep the 28 px rise alone.

## 2. Crickets at night

What plays now: `Ambient.band` gives birds in the dusk band (daylight .3 to .6; the dusk hold is .55, dawn .5) and one
chirp (cue 6) every 25-50 s in the night band (night hold .12). So birds really are heard at night.

- Birds: full while daylight >= **.40**, fading to nothing at **.30** (multiply the chirp volume by
  smoothstep((d - .30) / .10)). The night band schedules **nothing**. Dusk and dawn keep their sparse chirps.
- Crickets: gain = smoothstep((**.45** - d) / .25): silent at daylight >= .45, full at <= **.20**. So they start as the
  dusk-to-night blend passes .45, are at half by about .33 and full before the night hold; at dawn the reverse, and the
  first birds come in over the last crickets (the two overlap between .40 and .30, which is the nice part).
- The gain also eases at most **.25 a second**, so a clock jump still takes 4 s.
- Bed: one looped 2D voice in the ambience group, volume **.16** at full (try .12 to .20 on the beta; it must sit
  under the brook and never mask a pet's sounds). EqualizerSoundEffect LowGain **-18 dB** to take out any rumble.
- Variation, so it never reads as a loop: a second looped voice (a different recording, different length) at **.09**;
  each layer's volume breathes +-25% on its own slow sine (**23 s** and **37 s**); PlaybackSpeed **.97** and **1.03**.
- Near crickets: at night the three bird voices become three positional crickets at the nearest **bushes**
  (`WorldDressing` bushes within 40 studs): a 1-2 s trill cut from the bed's source, every **6-14 s** each, pitch
  **.94-1.08**, volume **.22**, roll-off 6 to 40. A cricket whose bush is within **6 studs** of the player goes quiet
  and stays quiet for **4 s** after they leave (real ones do; it is the one bit of charm here).
- A full gust ducks crickets by 20%. Rounds, menus and the deck music duck them exactly as birds are ducked.

Candidates (Roblox audio library, found with a read-only search; nothing inserted). I could not listen from here, so
these are picked from their descriptions; Spencer's ears decide on the beta:

| # | Id | Name | Length | Why / caveat |
|---|---|---|---|---|
| A | **9112764558** | Crickets Night 2 (SFX), Pro Sound Effects | 36.0 s loop | "Constant chirping", made as a loop, plain crickets. Caveat: "distant freeway" in the description, hence the low cut. First choice for the bed. |
| B | **9112764023** | Crickets Canyon 2 (SFX), Pro Sound Effects | 46.2 s loop | Constant crickets with a breeze; a different length to A, so the pair drifts and does not repeat for minutes. Second layer. (Its sibling 9112764040, Canyon 1, 36 s, is the swap-in.) Caveat: "distant traffic". |
| C | **9112762451** | Crickets And Cicadas 1 (SFX), Pro Sound Effects | 36.0 s loop | Denser, "heavy activity". Only if A + B sound thin; at .10. Cicadas lean hot-afternoon, so not my first pick for a calm night. |

Passed over: the "Night Jungle" and "Malaysian Forest" beds (bird chirps, a rooster and a dog in them), the "Electronic
Crickets" set (alarms), and user uploads with no stated licence (130778180, 6520245154).

## 3. Birds that read as birds

The round-3 bird is two balls (body 1.05, head .68): a chick or a snowman from any distance. A songbird's silhouette is
an egg tipped nose-up, a small head set forward on it, a point at the front and a long narrow tail carrying the body's
line down at the back. Still **8 parts, no mesh assets**, same pool, same three colourways and wing/breast/tail files.
It is also 18% shorter overall (1.93 -> **1.59 studs** beak tip to tail tip), so it is about the length of a pet's
body instead of longer than one. If it is lost in the canopy, multiply every number here by 1.2.

Root = body centre, -Z forward, studs:

| Part | Now | Target |
|---|---|---|
| Body | Ball 1.05 | Block + Sphere mesh (the `spindle` helper), Size **(.50, .52, .82)**, pitched **20 deg nose-up**: `root * Angles(rad(20),0,0)`. Breast decal stays on Front. |
| Head | Ball .68 at (0, .37, -.35) | Ball **.40** at **(0, .28, -.30)**: half the body's length, overlapping the breast, crown above the back line |
| Beak | spindle (.10, .09, .24) | **WedgePart (.09, .08, .20)** at head * **(0, -.02, -.27)**, thin edge forward (a flat-bottomed point, like an upper mandible). **[check]** the wedge's facing in Studio; fallback: the spindle at (.07, .06, .24) |
| Eyes | Ball .14 at (+-.235, .065, -.22) | Ball **.08** at head * **(+-.135, .04, -.12)** |
| Wings, folded | plates (.04, .95, .66) at (-+.54, -.02, .20), yaw 12 | plates **(.03, .68, .32)** at **(-+.25, .03, .11)**, yaw **8**, laid along the pitched body and drooped **10 deg** more, so the tips cross over the tail root |
| Wings, flying | shoulder (+-.37, .11, .04), half-span .475 | shoulder **(+-.20, .10, -.04)**, half-span **.34**; span tip to tip 1.76 |
| Tail | plate (.46, .68, .02), pivot (0, -.09, .40), +20 deg (cocked up) | plate **(.22, .62, .02)**, pivot **(0, -.01, .32)**, half-length .31, rest **-15 deg** (below level, in line with the back), flick to **+5** |

Proportions to hold if anything is retuned: head diameter : body length = **1 : 2**; tail length : body length = **3 : 4**;
tail width under half the body's width; overall length : height about **2.3 : 1**. Colours unchanged (Ember, Slate,
Moss). The wing file on the narrower plate reads as a pointed folded wing; the tail file on the narrower plate reads as
a taper. If the tail still looks like a paddle in Studio I will redraw `bird-tail.png` with a shallow fork.
Motion: head turns, hops and bounding flight unchanged; `Sim.Bird.tail` 20 -> **-15**, `tailUp` stays relative.

## 4. Smaller butterflies and leaves

Size reference only: in Animal Crossing a butterfly is about a tenth of the player's height and a falling leaf about a
twentieth. Our avatar is about 5 studs, a pet's body 1.35-1.65.

| Thing | Now | Target | Ratio |
|---|---|---|---|
| Butterfly wingspan | 1.20 | **.52** | 1 : 10 of the avatar, 1 : 3 of a pet |
| Wing plates | (.56, .67, .02) | **(.24, .29, .02)** | x .43 |
| Wing hinge / half offset | +-.03 / .28 | **+-.013 / .12** | |
| Body spindle (`Life.ButterflySize`) | (.09, .08, .42), .03 forward | **(.04, .035, .18)**, .013 forward | |
| Flap | 2.2 / 1.6 Hz, bob .06 | **3.0 / 2.2 Hz**, bob **.04** (small things beat faster) | |
| Firefly glow | | unchanged (it has to carry at night) | |
| Leaf A size keys | {.30, .46, .08, .42} | **{.16, .24, .04, .22}** | x .52; 1 : 21 of the avatar, 1 : 6 of a pet |
| Leaf B | {.26, .40, .06, .36} | **{.14, .21, .03, .19}** | |
| Petal | {.22, .34, .05, .30} | **{.11, .17, .03, .15}** | |

Leaf rates, fall and drift stay. If the air looks empty after the shrink, raise the rate 2.4 / 1.2 -> 3.0 / 1.5 and
nothing else. The butterfly's rest height (1.2 to 2.4 studs) stays, so it still drifts at pet height.

## 5. The strip: "Coming up"

"See you tomorrow" says the day is over and, with an 8 h egg, is not even true. The strip becomes a small live status
of what is on its way while you play. Same place, same size (44 desktop, 48 phone), still not a button.

- **Title: "Coming up"**. The moon mark goes (it says night); in its place a 10 px clock: a soft disc with two 1 px ink
  hands (4 px up, 3 px right). Instance name `ComingUpStrip`; the module can keep its file name.
- The "Miss a day, lose nothing." line stays as it is.

Chips (whole / short / tiny; the fit picks the longest that fits and never truncates; gold = ready now):

| Chip | State | Whole | Short | Tiny |
|---|---|---|---|---|
| Egg | over 1 h | **Egg in 7 h 52 m** | 7 h 52 m | 7h 52m |
| | exact hours | Egg in 7 h | 7 h | 7h |
| | 1 to 60 min | Egg in 42 min | 42 min | 42m |
| | under 1 min | Egg in under 1 min | <1 min | <1m |
| | ready (gold) | **Egg ready!** | Ready! | Ready! |
| Stamp | today's is waiting (gold outline, Star icon) | **Stamp 3 ready: +25** | +25 | +25 |
| | taken today | **Next stamp: +30** | +30 | +30 |
| | taken, and the reset time is known | Stamp 4 in 5 h | 5 h | 5h |
| Quests | some open | **2 quests to go** | 2 left | 2 |
| | all done | **Quests done!** (a tick, soft text) | Done! | Done |
| | all done, reset time known | New quests in 5 h | 5 h | 5h |

- Hours are floored and minutes are the rest, rounded up (7 h 52 m, never "8 h" with 7 h 10 m left; 60 m rolls to the hour).
- Live: recompute every second while the strip is shown, write a label only when its text changes (once a minute,
  in practice). When the egg turns ready the chip goes gold with one `Kit.boing` (Reduced Motion: colour only).
- Ready chips sort first (egg, then stamp, then quests).
- Phone fit, FredokaOne 12, icon 16: 400 wide and up shows the whole words when they fit their column (125 px), else
  short; under 300 the tiny form ("7h 52m" is about 67 px in a 72 px column); under 240 no strip, as now.
- Numbers ride `{hours}`, `{minutes}`, `{count}`, `{stars}`, `{left}` parameters so the sentences translate; the bare
  number forms stay out of translation as now.
- Copy keys (`onb3.strip`): title "Coming up"; eggHM "Egg in {hours} h {minutes} m"; eggH "Egg in {hours} h";
  eggM "Egg in {minutes} min"; eggSoon "Egg in under 1 min"; eggReady "Egg ready!"; stampReady "Stamp {count} ready: +{stars}";
  stampNext "Next stamp: +{stars}"; stampIn "Stamp {count} in {hours} h"; questsLeft "{left} quests to go";
  questsOne "1 quest to go"; questsDone "Quests done!"; questsIn "New quests in {hours} h". The nest sign's own
  "Hatches in..." lines are not touched.
- **[check]** whether the client snapshot carries the daily reset time; without it the two "in 5 h" rows are simply not shown.

## 6. Ground flowers that sit in the lawn

Cause: the five patches (`assets/world/textures/flower_patch_*.png`, Decals on the lawns via `WorldDressingClient`) were
painted against the ungraded grass #2DA83A. The world pass then graded the lawn (hue +4, S x .80, V x .70) to about
**#31763D** (S .58, V .46). The patches kept V 1.0 whites, S .7-.8 petals, leaves brighter than the grass and a dark ink
outline, on hard 4 px blocks. Everything in them is louder than what they lie on.

Targets, relative to the lawn:

| Element | Now | Target |
|---|---|---|
| Leaf rosettes | #2FA83F / #1F8338 / #4FCB62, inked | the lawn's own hue, value within **+-12%** of it: **#347D41 / #296A34 / #3B8440**, **80% alpha**, no outline |
| Outline | dark ink per colour | none on leaves; a petal's rim is its own colour at 78% value, 78% alpha |
| Petal saturation | .56 to .78 | x **.70**, never over **.58** |
| Petal value | up to 1.0 | x **.86**, never over **.86** (the lawn is .46; the brightest petal is under twice it) |
| White | #FFFFFF | **#E2DFCB** (warm, never pure) |
| Yellow / pink / lilac / aqua | #FFD84A / #FF6FAE / #A88BFF / #35C7F5 | **#DBC46E / #DB85AB / #A795DB / #5FB7D3** |
| Heads | 8 a patch | **6**, each **85%** the size |
| Edges | nearest-neighbour blocks | smooth, soft alpha edge (matches the textured, realistic lawn) |

Redrawn with PIL from the same generator, seeds and layout family (the placer, patch sizes and the 150 cap do not
change): `look/r2/flower_patch_{daisy,tulip,bellflower,buttercup,starbloom}.png` (256 px RGBA),
`look/r2/before-after.png` (old row over new row on the graded lawn), `look/r2/palette.txt`, and the script
`look/r2/draw_flower_patches_r2.py`. To ship: upload the five as Images, put the ids in
`assets/world/world-dressing-import.json` ("flowers"), rerun `scripts/build_world_v7_dressing.py`. Nothing uploaded yet.
In the placer set the Decal's `Transparency` to **.08**. **[check]** on the beta at noon and at night: at night the
whites should be the brightest thing on the lawn only by a little; if they still pop, tint `Decal.Color3` toward
#C8D0E0 while daylight is under .3. The lawn colour here is computed from the grade row, not sampled in Studio: **[check]**
it against a beta capture and re-run the script with the sampled value if it is off.
