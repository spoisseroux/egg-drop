# v2 round 3 creative brief (Fable, 2026-11-20)

Spencer's eight beta notes, as one spec for Opus. Times are seconds on the hatch clock unless a
line says "entrance" (RevealStage's own clock, which starts when the egg lead-in ends). Colours are
existing palette values. Every sound is an existing `BoardAudio` cue; no new audio was needed.

Files made for this round:
- `assets/eggs/textures/egg-stat-color.png` (1024, same UV layout as the other five; needs an Open
  Cloud image upload, then its id goes in `EggModels.Types.stat.colorMap`)
- `artifacts/v2-round3-2026-11-20/egg-stat-preview.png`, `egg-stat-vs-others.png` (software render,
  four yaw angles + the flat map; `render_stat_egg_preview.py` beside them)
- Tooling: `scripts/egg_types.py` gained `TYPES["stat"]` and `EXTRA=["stat"]` (not in `ORDER`, so the
  manifest and Blender previews of the shipped five are untouched); `scripts/build_egg_textures.py`
  gained `paint_stat` and `python scripts/build_egg_textures.py stat` (paints only that map).

Two facts found in the code that change the brief's assumptions:
- Pets already draw the tier's well (`RevealStage:build` calls `ItemStage.backdrop(...,tier,"companion")`).
  What they lack is the tier **sound**, the tier **burst** and every jackpot lane.
- `HatchRarityCue.tier("companion",{petId="blip"})` returns **Neutral** (the Bunny is in
  `Pets.earned`, not `Pets` or `Pets.rares`). Section 3 needs it to return **Rare**.

---

## 1. Stat Egg: its own 3D egg, and a bigger hatch

### 1.1 The egg type
Add to `EggModels.Types` (and `"stat"` to `M.Order` after `feature`):

```
stat={name="Stat Egg",colorMap="<upload egg-stat-color.png>",roughness=0.26,
 core=#FF8A5C, bloom=#FF9D4D, crackLight=#FFF3C4,
 particles={#FFFFFF,#FF86A8,#FF9D4D,#6CCBFF,#B9EE5A,#8FA8FF,#E58CFF}}
```

Look (painted): house cream `#FFF4DC` shell warming to peach `#FFE2B8` at the foot; a Stars-gold belt
(`#FFC14D`, lip `#D9A31C`, ink `#15143A` keyline) just under the seam, set with six round stones in
`StatCatalog.Order` (Heart faces the front, then Power, Energy, Jump, Speed, Smarts going round);
six small stone dots on the crown (each opposite its belt stone), gold four-point sparkles between
them, a ring of gold dots at the foot. Core is coral `#FF8A5C` so it is not mistaken for the
Companion (lemon) or Toy (amber) eggs.

Wiring: `EggHatchView.artOf("stat")` returns `"stat"` for the 3D preview (`EggPreview3D:setType`);
the 2D `EggArt` fallback keeps borrowing `"feature"`. Add `"stat"` to `EggPreview.prewarm`.
`EggPreview.rhythm("stat")`: `{gapMin=2.4,gapMax=3.6,double=true,hop=.08,sparkles=8}`.

### 1.2 The hatch uses the 3D egg
`StatEggReveal.snackScene` drops the flat `StatEgg` ImageLabel and the four ink `Crack` bars. The egg
is the same three meshes plus the split halves that every other item hatch draws, with
`Types.stat.colorMap`, posed by the same `HatchDisplayPose.sample(age,"stat",reduced,tier)` fields
(`rock, crack, eggSX/eggSY, eggLift, shiver, opening, shellAlpha, capAlpha, shellScale`). Preferred
route: one `HatchDisplayScene` with `kind="stat"` whose hero is the `SnackModel` (so there is one egg
renderer); acceptable: a ViewportFrame in `snackScene` that copies `HatchDisplayScene:render`'s egg
block. Acceptance: at 844x390 a Stat Egg and a Toy Egg hatch are the same egg size, camera (FOV 38)
and light, frame for frame, until the burst. The 2D `Stage.Art.statEgg` cell stays only as the lid /
waiting egg silhouette.

### 1.3 What makes it more exciting (all tiers, inside the existing clock)
- **Stone roulette.** While the egg rocks, six stat-coloured sparkles (`Stage.Art.sparkle`,
  14 px x L.s) pop on an ellipse round the belt (width 1.12 x egg width, height 0.20 x egg width,
  centred 36% up the egg): two per rock at 0.21, 0.48 and 0.81, in `StatCatalog.Order`. Each: scale
  0 to 1.2 to 0 over 0.22 s (sine), no travel. They say "one of six" and never show the result.
- **The answer is the burst.** At the burst the well's bloom, the confetti stones (already
  `stoneColors`) and the shockwave stroke (Feast) are the won stat's colour. Nothing before the
  burst uses the won colour.
- **Snack pop.** `heroScale` for `kind=="stat"`: 0.55 at burst+0.12, Back Out (overshoot 2.2) to 1.12
  at burst+0.34, settle to 1.00 by burst+0.50. One full yaw turn of the snack over 0.60 s (Expo Out)
  starting at burst+0.12, then its normal idle spin.
- Crack light and bloom under the egg use `Types.stat.crackLight` / `bloom` before the burst.

Per tier:

| | Nibble (Common) | Snack (Uncommon) | Feast (Rare, jackpot) |
|---|---|---|---|
| Clock | burst 0.98, name 1.65 | burst 0.98, name 1.65 | `Policy.Jackpot` unchanged (burst 1.72, stamp 2.30, name 3.15) |
| Stage | Sunny Peach, as now | Lime Soda, as now | Berry Blast, as now |
| Snack pop | to 1.08 | to 1.12 | to 1.18, lands with the 3 px shake |
| New at burst | nothing more (stays inside the well) | one ring in the stat colour: the `Shockwave` node, radius 40 to 280 px x L.s, 0.35 s Expo Out, 6 to 2 px, alpha 0.8 to 0 | shockwave stroke in the stat colour (white now) |
| Wind-up | n/a | n/a | the 12 orbit pieces are the six stat colours, two each in `Order` (pebbles; the sparkles stay white): the stones leave the belt and circle |
| Cannons | n/a | n/a | pieces alternate the stat colour and Stars gold `#FFC14D` |
| Stamp | n/a | n/a | "RARE!" as now (see Spencer's calls: "FEAST!") |

Reduced Motion: unchanged rules (0.6 s cross-fade, Feast 0.9 s). The egg in the cross-fade is the 3D
egg at rest with the crack drawn; no roulette, no ring, no snack spin; still stones in the stat colour.

---

## 2. One sound line for every egg (toy, look, material, feature, stat, pets)

Why the others do not sound like the Stat Egg today: they play the same tier sting, but the old body
cue (`hatch_display_<kind>`, gain 1) lands its own hit on the same frame and covers it. The Stat Egg
has no body, so its sting is clear. Decision: **the tier sting is the hatch's sound; the body cues
leave the line.**

The line (played by `HatchRarityCue.events` for every kind, companions included):

| When | Cue | Speed | Gain | Notes |
|---|---|---|---|---|
| 0.21 / 0.48 / 0.81 (rock peaks) | `egg_wobble` | 1.00 / 1.08 / 1.16 | 0.28 / 0.34 / 0.40 | new for all eggs; `pre=true` |
| 0.65 (crack starts) | `egg_crack_glint` | 1.00 | 0.45 | `pre=true` |
| burst - hit | tier sting, as now | 1 | Common 0.55, Uncommon 0.75 | Common/Uncommon start at 0.98 |
| Rare: 0.67 | `hatch_jackpot` | 1 | 0.72 | unchanged |
| Rare: 1.02 | `rarity_rare` | 1 | 0.80 | unchanged; hit on 1.72, chord on the stamp 2.30 |

- Body cues: add `Policy.BodyGain=0`; `HatchCinematic:playBody` plays `hatch_display_*` at
  `Policy.BodyGain` and skips the call at 0. Ids stay in `BoardAudio`. (Fallback if Spencer misses the
  old bodies: 0.30, never 1.)
- The `charge` cue at present (0.92, 0.18) stays.
- Reduced Motion: no foley; the sting (and `hatch_jackpot_calm` under a Rare) plays as now.
- Skips cancel the line as now (`Cue:cancel`, `stopOwner`).

Pets:
- `HatchRarityCue.new` returns `Policy.events(...)` for `kind=="companion"` too. The Bear (Common)
  gets the foley and `rarity_common` (0.55) at 0.98, when the shell opens.
- `RevealStage.Cues` stay for Common and Uncommon pets (they are the entrance: hush, spot, whoosh,
  shimmer, tag, name, desc at 0.55). For a Rare pet see section 3.
- Reduced Motion pets: the sting at 0 (Rare: calm layer + sting at 0, gains as items).
- Tier effects on a pet hatch: at the burst the well gets the tier's one bloom
  (`Policy.Stage[tier].bloom`: 0.20 / 0.35 / 0.60, radius 0 to 150 px x L.s, Expo Out 0.16 s, fade
  0.40 s) and the tier's confetti stones (`stones` / `sparkles` / `escape` from `Policy.Stage`, drawn
  with `ItemStage.confetti`, tier `look.color` / `look.second`). The pet's own 18-sparkle burst and
  28-piece poppers stay for Common and Uncommon. Rare pets take the full jackpot (section 3).

---

## 3. The Bunny's hatch: a Rare pet jackpot

Plays client-side through the companion path (HatchCinematic + HatchDisplayScene + RevealStage)
after the adopt saves (400 Stars or the free 7-stamp claim; it replaces the toast / arrival card).
On the save's success the hub plays `egg_ready` (1, 0.5), and the hatch opens 0.25 s later.
`Policy.tier`: earned pets are **Rare**. `Policy.timing`: a Rare **pet** is a jackpot too.
The egg is the Companion Egg (cream, blue dots, lime ribbon), the same egg the Bear came from.

Stage: Berry Blast (`Policy.Stage.Rare`: core `#E845C8`, edge `#6B3BEA`, rays `#FF79D9`, floor
`#FFE9F8`, deep `#3B1FA0`, diamonds, rays turning 12 deg/s). Keep `b.shafts` for Rare pets (it is
destroyed today). Accent / name plate: `Stage.accentFor` (undyed Bunny: Stars gold `#FFC14D`), which
sits well on the magenta-violet. Orbit pebbles: Jump lime `#B9EE5A` (his favourite stat), sparkles
white. Cannon pieces: `#FFC14D`, `#FFFFFF`, `#FF79D9`, `#B9EE5A` in turn.

Jackpot lanes: RevealStage reads them from `ItemStage.sample(age,reduced,"Rare")` (shafts, orbit,
orbitRadius, shake, punch, shock, rainbow, stamp, stampScale) and builds the same nodes
(Shockwave, RainbowEdge with section 8's corners, RareStamp, 12 orbit, 52 cannon pieces).

Beat strip (hatch clock; entrance = hatch - 1.79, i.e. `LeadIn` + 0.74):

| Time | Beat | Picture | Sound |
|---|---|---|---|
| 0.00 | Rest | egg in the Berry Blast well, checker 8 px/s | `charge` as now |
| 0.12-0.94 | Three rocks | -5, +8, +10 deg with the squash; camera push 4% | `egg_wobble` x3 (section 2) |
| 0.65-0.93 | Crack | seam light `#FFFBE6` | `egg_crack_glint` 0.45; 0.67 `hatch_jackpot` 0.72 |
| 0.95 | Wind-up | egg lifts 10 px (Expo Out 0.20 s), shiver builds, shafts fade to 0.25, 12 lime pebbles orbit (radius 132 to 92 px), checker 8 to 48 px/s | 1.02 `rarity_rare` 0.80 (harp rise) |
| 1.60 | Freeze | squash 114% x 86%, checker at one tenth, orbit holds | the riser's gap |
| 1.72 | **Burst** | shell opens; bloom 0.60; shockwave 40 to 600 px in 0.5 s (white); rainbow on the rim and the screen edge (0.25 s); well punches open (Back 2.4, 0.22 s); shake 3 px 0.2 s | both hits land |
| 1.91-2.25 | **The leap** (entrance 0.12-0.46) | the Bunny comes out of the shell as a silhouette: scale 0.55 to 1 (Back Out 2.4), spin-in 720 deg (Quint Out; the Bear's is 540), and an arc 0.38 x pet height high (sine) | - |
| 1.95 / 2.07 | Cannons | left then right, 26 pieces each | - |
| 2.21 | Colour | silhouette to colour, flash 0.6, 30 burst sparkles (Bear: 18) | - |
| 2.25 | Landing 1 | squash 112% x 88% (spring n 1, d 6, 0.26 s); ears flick 22 deg | `bear_boop` 1.25, 0.40 |
| 2.30 | **Stamp** | "RARE!" drops 2.6x to 1x (Expo In 0.12 s), -6 deg, centre of the well, over the Bunny's head; shake 4 px 0.18 s | the fanfare chord (in `hatch_jackpot`) |
| 2.41-2.63 | Hop 2 | 0.16 x pet height, land 2.63 with squash 106% x 94% | `bear_boop` 1.40, 0.30 |
| 2.67-2.83 | Hop 3 | 0.07 x pet height, land 2.83 | `bear_boop` 1.55, 0.22 |
| 2.80-2.87 | Stamp leaves | pets only: the stamp shrinks to 0.9x and fades in 0.07 s (no travel; items keep their seat move), so the headline lands in clear air | - |
| 2.87 | Headline | "RARE / DISCOVERY!" slams (Back Out 0.20 s) | `tag_slam` 1, 0.55 |
| 2.89 | Greeting | wave pose + voice | `pet` 1.12, 0.40 |
| 2.99 | Name plate | plate slides (Quint Out 0.24 s), letters 0.04 s apart | `name_slam` 1, 0.55; +0.09 `name_slam` 1.06, 0.45 |
| 3.23 | Description | wipe 0.16 s | `desc_tick` 1, 0.45 |
| 3.39 | Buttons, input opens | `ready` = 3.39; rainbow edge and rays keep turning while the card is up | - |
| 5.2 | Jackpot voices have rung out | `duration` / `quiet` = 5.2 | accent voice stops |

For a Rare pet, drop `reveal_hush`, `spot_on`, `streak_whoosh`, `reveal_shimmer` and the popper cue
`new_best` (they fight the jackpot layer), and drop the two corner poppers (the cannons replace them).
The Bunny's hatch plays once per adopt and is not skippable before 3.39; the spin pad, wave loop
and buttons after 3.39 are unchanged.

Bigger than the Bear's, in numbers: 3.39 s to the name against 2.05; wind-up + freeze; 720 deg
spin and a three-hop landing against one rise; shafts, shockwave, rainbow edge, stamp and 52 cannon
pieces against 28 popper pieces; two layered voices against one pop.

Reduced Motion: 0.9 s cross-fade (`J.reducedReady`), egg with its crack drawn to the Bunny standing
in the settled frame (fade 0.30 to 0.45). Rainbow edge and rim static at 0.6, shafts static at 0.15,
12 still pieces round the well (lime, gold, white). "RARE!" fades in at full size at 0.45 and out as
the headline and plate fade in at 0.9. No leap, spin, hops, shake, cannons or shockwave.
Sound: `hatch_jackpot_calm` 0.72 + `rarity_rare` 0.80 at 0; no slams. Buttons at 0.9.

---

## 4. Hatch eggs screen: the glint (`EggPreview3D`)

Remove the `Glint` capsule (and its lines in `measure`, `paintStatic`, `step`, `showOverlays`).
Replace it with a soft specular that lives **inside `SheenClip`** (so it can never leave the egg's
oval) and moves with the yaw. `cw`, `ch` are the clip's width and height; `yaw` is `self.yaw`.

- **Spec** (new, `SheenClip.Spec`): round frame (`UICorner` 0.5), white, size `cw*.36 x ch*.30`,
  `UIGradient` Rotation 90 with Transparency keypoints 0: 1, 0.5: 0.45, 1: 1 (a soft-edged streak;
  peak opacity 0.55, no hard rim). Rotation `-32 + 6*sin(2*yaw)` deg. Centre
  `(cw*(.30 + .05*sin(2*yaw)), ch*(.27 + .015*cos(2*yaw)))`: it drifts 10% of the width, twice per
  turn (the egg turns 20 deg/s, so one drift cycle is 9 s). Opacity breathes with the bloom:
  multiply by `.85 + .15*sin(now*2*pi/1.6)`.
- **Hot dot** (`SheenClip.SpecDot`): circle `cw*.075`, white, BackgroundTransparency 0.15, at the
  Spec's centre + `(-cw*.035, -ch*.055)`; same drift.
- **Sweep**: the existing `Sheen` bar (0.18 wide, rotation 20) crosses `x` -0.2 to 1.2 in 0.8 s
  (Quad In-Out) at BackgroundTransparency 0.78, once each time the yaw passes a multiple of 180 deg
  (every 9 s), for every type. The Material Egg keeps its own 4 s sweep at 0.75. Phones
  (`g.phone`): no sweep, Spec and dot only.
- Hop and squash: Spec, dot and clip move up by `hopPx`; Spec width x `(2 - sy)`.
- Hatch press: Spec and dot fade out with `topFade`.
- Reduced Motion / inactive: Spec and dot at their home position (`yaw` term 0), no breath, no sweep.

---

## 5. The peek glare (`EggPreview3D`, `Preview.flash`)

Today: a hard slab wider than the egg (`ew*1.3 x eh*.25`), up in 0.125 s and gone by 0.25 s, with a
linear 0.05-stud lift. New: a light that swells out of the seam and fades with a tail.
`Preview.FlashLength=.90`; `Preview.flash(ft)` returns `lift, coreTransparency, haloTransparency, env`.

- **Envelope `env`** (0..1): attack 0.18 s `1-(1-u)^2`; hold 0.14 s at 1; release 0.50 s `(1-u)^2`
  (fast, then a long tail). Ends at 0.82.
- **Lift** (studs): 0 to 0.06 over 0.22 s (Quad Out), hold to 0.40, back to 0 by 0.70 (Quad In-Out).
- **Core** (`CrackFlash`): the type's `crackLight`, height `eh*.10`, width `ew*(.55 + .50*env)` during
  the attack (it spreads from the middle; then stays `ew*1.05`), never wider than the egg.
  BackgroundTransparency `1 - .80*env`. Starts 0.04 s after the lift.
- **Halo** (new `CrackGlow`, under the core, same centre): round frame `ew*1.5 x eh*.42`,
  `crackLight:Lerp(bloom,.5)`, the same centre-weighted `UIGradient` the bloom uses,
  BackgroundTransparency `1 - .35*env`. Starts with the lift.
- **Bloom**: instead of the jump to 0.45, `bloom = bloom - .14*env`.
- **Core mesh**: `coreScale += .08*env`.
- Cue `egg_crack_glint` at the start as now. A second flash never starts while one runs
  (`flashStart` rule unchanged; compare against `FlashLength`).
- Idle "something inside" beat (`Preview.beat`): keep the timing, soften the snap: the counter-tilt
  (0.10-0.18 s) uses smoothstep instead of the linear ramp.
- Reduced Motion: no flash, as now.

---

## 6. The Star counter (`WalletStar`)

Why it is dull: the one light points at the camera (`LightDirection=(-.55,-.6,.6)`, a back light), so
the Star's face is its texture multiplied by a grey-beige ambient (206,192,166).

| | Now | New |
|---|---|---|
| `AmbientBase` | 206,192,166 | **250,226,176** |
| `AmbientBright` (glint peak) | 255,240,200 | **255,244,206** |
| `LightColor` | 255,214,120 | **140,104,52** (a low front fill) |
| `LightDirection` | (-.55,-.6,.6) | **(.45,-.55,-.7)** (front, upper left: the side the texture's baked light is on) |
| Glow colour | 255,193,77 | **`#FFD45C`** |
| Glow transparency (rest / glint peak) | .78 / .48 | **.62 / .40** |
| Glow size | 1.25 | **1.35** |
| Sparkle size | size x .62 | size x .70 |

Material stays SmoothPlastic, no Reflectance (it greys a small viewport). Check on a capture at 22 px
and 28 px: the lit facets should be saturated gold, not white; if they clip to pale yellow, lower
`LightColor` to 110,82,40 and keep the rest. `Kit.wallet`: the medallion's inner ring goes from 1.5
to 2 px Stars gold (`#FFC14D`); nothing else moves.

---

## 7. Pet previews in menus

The shared set-up (Ambient 175,184,183; LightColor 255,250,231) has a cool grey-green ambient and a
full-strength key light: shadows read grey, lit fur clips to white. Move it toward the reveal
stage's approved light (`RevealStage.Light`), a small step:

| | Now | New |
|---|---|---|
| Ambient | 175,184,183 | **206,202,194** |
| LightColor | 255,250,231 | **128,122,110** |
| LightDirection | (-1,-1.4,-3) | unchanged |

Shadow side +17%, warm instead of green-grey; peak light 1.69 to 1.31, so colour holds in the lit
areas. Apply to `CardPreviewCache.buildPet` (PetHeadshot uses it) and `CompanionsHub:buildWell`.
The same two numbers are copied in `WardrobeShop` (258, 552), `PetInspect` 298, `PetPeek` 136,
`HueEggView` 124 and `MachineHubArt` 307: move them together (one shared `Kit.PetLight` table) so a
pet does not change brightness between menus. `PetHeadshot.LockedTint` is unchanged.

---

## 8. The Rare border (`HatchItemStage` `RainbowEdge`)

It is a 14 px inner stroke on a square full-screen frame, so its inside corners are square against
the phone's round display. Make the band's **inner** edge round and keep its outer edge off screen:

- Inner radius: **34 px** on the phone layout (844x390; the display's own corner is about 47, the
  band is 14 thick, so the band runs parallel to the glass), **24 px** on desktop and tablet.
- Build: the frame overscans the screen by 24 px on every side (Position -24,-24; Size 1,48,1,48);
  the stroke stays `Inner`, Thickness 14+24 = **38**; `UICorner` = inner radius + 38 (**72** phone,
  **62** desktop). The visible band is still 14 px and no screen corner is left uncovered.
- How it reads: one even ribbon of light all the way round, like the screen's own bezel glowing; the
  rainbow keeps turning (216 deg/s) through the corners with no square notch. Under Reduced Motion
  it is the same shape, static at 0.6.
- The well's `TierRim` is unchanged. The Bunny's hatch (section 3) uses the same node.

---

## Spencer's calls
1. **Old hatch body sounds leave** (section 2). The tier sting, the wobbles and the crack become
   the whole line for every egg. If the eggs feel thin, `BodyGain` 0.30 brings the beds back quietly.
2. **The Feast stamp**: keep "RARE!" (no new string), or "FEAST!" on a Stat Egg (one new UICopy
   string, so one more translation sync).
3. **The Bunny is Rare** on its hatch (Berry Blast stage, "RARE DISCOVERY!"). The Bear stays Common.
4. Most of the pet entrance cues (`tag_slam`, `name_slam`, `bear_boop`, `egg_wobble`,
   `egg_crack_glint`) are still the placeholder sounds from 2026-11-13; this brief leans on them more.
5. The Stat Egg map is checked in a software render only; it wants one look in Studio on the mesh.
