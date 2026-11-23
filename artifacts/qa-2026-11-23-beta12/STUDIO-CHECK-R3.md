# Beta 14 candidate: Studio check R3 (Opus, 2026-11-23)

Branch `feat/egg-drop-arcade-polish` at 02978ee (QA round 2 merged), Studio Play (place file 96451847774961, Rojo live on 34872). The ZZSpecs copies of KitArrive, KitSpring, KitSurfaces, WorldDressing and UICopy were refreshed from `scripts/` (MenuPolish was already current). Before Play, Edit showed every copy at the repo length (CR stripped), `DeckKit` holding `PressScale`, `AmbientAudio` holding 9112764558 and `TomorrowStrip` holding `ComingUpStrip`. Fresh Studio save: Bear through the welcome skip, then the garden. Nothing published or saved. Captures are in `studio/r3/`.

## 1. Studio-only specs

| Spec | Result |
|---|---|
| KitArrive | **PASS 14** |
| UICopy | **PASS 9** |
| KitSpring | **FAIL** at :185 `disabled mid-release` (button test, flags on) |
| KitSurfaces | **FAIL** at :223 `and settles` |
| MenuPolish | **FAIL** at :69 `tabs shifted on daily` |
| WorldDressing | **FAIL** at :49 `assertion failed!` |

What each failure is (from probes in the same Play):
- **KitSpring: a real code gap.** `Kit.setEnabled(b,false)` while a press is springing back snaps `content` and `fill`, but leaves `Face.PressScale` mid-spring (read .982 for primary/secondary, .979 for ghost, still busy). `Kit.setEnabled` (DeckKit.lua:996) settles only `s.content` "KitDrop"; it does not settle the face's PressScale. The test fails on the first button, so the later KitSpring cases did not run.
- **KitSurfaces: spec timing.** With `springs` off it **passes 9**. With springs on, the tab pill is measured `Kit.Motion.tab + .1` (.24 s) after a select, but the R2 pill spring has a .45 s limit, so it has not settled yet.
- **MenuPolish: spec timing.** With `menus` off it **passes 10**. DeckMenu now opens with `Kit.arrive` (270b88a), and the spec reads header and tab Y .03 s after `open()`, in the middle of the 28 px rise.
- **WorldDressing: float32.** `Decal.Transparency = .08` reads back as 0.0799999982, so `Transparency == .08` is false in Studio (the same class as the R1 NumberSequence finding). The beta textures and the live fallback checks before it passed.

## 2. Output log

No errors or warnings from our scripts in about 35 minutes of Play: 6 specs, a deck round, 2 Dash races, `/hour on` and `/hour at 2950`. Lines seen: ConfigService missing keys, the Assistant plugin version notice, "Asset content representation is being generated" for the five new R2 flower ids at start (they loaded and render), `rbxassetid://203785492` type mismatch (long-standing), `EditableImage is not accessible` (JellyLCD, old), the KitSpring spec's deliberate throws, `UICopy: missing key no.such.key` (on purpose), and two typos of mine.

## 3. Checks

| Item | Result | Evidence |
|---|---|---|
| Button mid-press: Face scaled .95 | **PASS** | 01 rest, 02 held. Mouse held on the egg shop's Hatch button: `Face.PressScale.Scale` .95 (Face holds Edge, Fill, Content), Face 483 x 64 inside the unchanged 509 x 67 hit rect. The shop's round Back and Help keys have no Face (`Disc`, `KeyLip` only), so the .88 round-key press does not reach them |
| Menu mid-open: rise + scale on a centred screen | **PASS** | 03 frozen mid-open, 04 at rest. Pocket menu (MachineHub, fit UIScale 1.2), sampled per frame from the real click: y +18, scale 1.119 (k .93), then y -5/-6 and scale 1.227 (k 1.022, under the 1.03 clamp), then +1, then rest at y 0 / 1.200 by .65 s. About 6 px past home, rings twice. Frame times were about 66 ms (unfocused Studio) |
| QuestLog: rising only | **PASS** | 05 frozen mid-rise. `Content` (anchor 0,0): y 18, 4, -5, -6, -3, 0, +1, 0; its UIScale stays 1.200 every frame |
| Bird shape, beak forward | **PASS, one note** | 06, 08, 09, 10. Pitched egg body, small head set forward, folded wing along the body, thin tail. The beak points forward along the body (beak LookVector = body forward), a thin dark wedge (10). Notes: head-on it reads as a small brown square (08); side-on at 2.6 studs it all but vanishes (09). The tail still reads as a thin spike from some angles (06, 10) |
| Butterflies and leaves next to a pet | **PASS for butterflies; leaves for Fable** | 06, 07. Live parts match the spec: wings .24 x .29, body .04 x .035 x .18; leaf emitter sizes A .16/.24/.22, B .14/.21/.19, petal .11/.17/.15. A butterfly next to the Bear reads at about a third of the pet (07, right of the cube). Leaves: in 07 an emitter at constant Size .25 beside a .5 stud cube draws a leaf about .36 studs across, so a Size .24 leaf reads near a quarter of the pet's height, not the 1:6 Fable targeted. The particle quad looks like about 2 x Size, with the leaf filling about 70% of it |
| Ground flowers, day | **PASS** | 11 to 14 (ClockTime 10.5). All 81 patches use the five R2 ids at Transparency .08. Petals are soft and muted, with no ink outlines, and the leaf rosettes blend into the lawn. Daisy whites are the brightest thing on the lawn, and only a little. Night not captured |
| Crickets at `/hour at 2950` | **PASS** | SoundService `EggDropAmbient_crickets_bed` id 9112764558, looped, speed .97, EqualizerSoundEffect LowGain -18, group EggDropAmbience, volume breathing .12 to .20 over 30 s; `_crickets_layer` id 9112764023, speed 1.03, LowGain -18, .068 to .107. Near crickets near a bush cluster: 3 `CricketBush` voices on bed id 9112764558, PlaybackRegions 1.2 to 2.0 s long, every 6 to 13 s each, speed .95 to 1.07, volume up to .22, roll-off 6 to 40. Standing 4 studs from a bush: that bush stayed quiet for 25 s, and it played again 4.1 s after I left. `PlaybackLoudness` read 0 on every sound, because the unfocused Studio window plays no audio, so this is state and timing, not a listen |
| Birds silent at night | **PASS** | Over 30 s and then 45 s more: no bird voice played. The perch voices are idle, and the 6 chirp cues are at volume 0 |
| Deck results "Coming up" strip, live countdown | **PASS** | 17. Title "Coming up" with the clock mark. Chips: "3 quests to go", "Egg in 7 h 48 m", "Stamp 1 in 8 h". Read twice: "Egg in 7 h 48 m", then 10 s later "Egg in 7 h 47 m". Quests sort first with a gold outline because one quest was ready to claim after the round (`ready>0`). The stamp text is #FFC14D by design |
| Dash results strip | **PASS** | 19. The same three chips at "Egg in 7 h 46 m", read twice 4 s apart (same minute both times) |
| Nest sign back face from the arrival path | **PASS** | 15, 16. "Bear's egg." reads whole; the post stops under the board (post top 5.14, board bottom 5.11 before tilt) |
| Dash race to results: place pill hidden | **PASS** | 18, 19. Logged every 50 ms over two races in a row. The pill is blank and hidden through gather and countdown, shows 1st, 2nd, then 4th at the start, and clears and hides as `results` begins, before the sheet shows. Race 2 never showed race 1's "4th" |

How the bird, butterfly and leaf shots were taken: all birds were parked (Y 4096). These are clones of the live pool parts, with their real sizes, colours and decals, wings and tail kept at Transparency 1 as live. They are posed with `LifeSim.birdParts` / `butterflyParts` beside a clone of the Bear on the lawn at (-20, 12). The leaves are clones of the live emitters fired with `:Emit`. None of it is live flight. The magenta cube in 07 is a .5 stud scale reference.

## 4. Could not check

- Hearing the crickets, the bed against the brook, or the breathing: no audio comes out while the window is unfocused.
- Live bird and butterfly flight, and how big leaves look on screen while they fall in real time.
- A real touch press on a phone, and the 390 x 844 filmed acceptance test.
- The sheet open on phones (needs a phone viewport), and close animations.
- Flowers at night, and the #C8D0E0 night tint question.
- The strip's ready-egg gold and boing: the egg is 7 h 46 m out.

## Captures (`studio/r3/`)

01 egg shop Hatch button at rest · 02 the same button held (Face .95) · 03 pocket menu frozen mid-open (rise + scale) · 04 pocket menu at rest · 05 quest log frozen mid-rise (no scale) · 06 bird, butterfly and leaves beside the Bear (staged) · 07 scale reference: .5 stud cube, a Size .25 leaf and a butterfly · 08 bird front · 09 bird side · 10 bird front-quarter close (beak) · 11 to 14 ground flowers by day (tulip/bellflower, bellflower low, daisy by the path, wide) · 15 and 16 nest sign back face from the arrival side · 17 deck results with the Coming up strip · 18 Dash results staging, no place pill · 19 Dash results with the strip, no place pill.
