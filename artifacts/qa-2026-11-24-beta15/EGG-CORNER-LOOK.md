# The egg corner: one nest, one egg machine (Fable, 2026-11-24)

For Spencer after beta (15): "I think the egg area should just be the egg nest. And the hatch eggs machine should look
like a gachapon machine full of eggs? With a better, less crowded layout in the plaza, with the egg that hatches hours
having a ? tip to click to learn more."

Direction only; Opus implements. This replaces "Nest merge rulings (R2)" sections 1 to 3 in
`artifacts/qa-2026-11-23-beta14/WORLD-AND-NEST-LOOK.md`. The R2 idea ("one place for eggs") is withdrawn: two egg
things 5.85 studs apart read as one muddle, and the pill, the pin, the attract ring and the need bubble all stacked
there (Spencer's shot `4-nest-bubbles-crowded.webp`).

**What I read:** R2, `Nest.lua`, `NestClient.lua` (pill, sign, Bear spot), `HollowWorldLayout.lua` (V7 stations and
the arrival route), `LoungeWorldV7Art.lua` (`Art.stations`, `EggNestLight`), `StationAttract*.lua`, `ThingsPage.lua`
(the "?" button), `EggModels.lua` (egg colours), UICopy `onb3.nest.*` and `r5.station.Eggs*`,
`ASMR-AND-SCALE-LOOK.md` section 1, captures r6/03, r6/04, r6/07 and Spencer's shot 4.

**Not seen:** nothing here has been placed in Studio. All positions are arithmetic from `HollowWorldLayout`. I have not
measured the old station's dais, the plaza's marble edge, or the west path mouth. Those are the `[check]` items.

---

## 0. The idea in one line

**The nest is where an egg sleeps. The machine is where eggs come from.** The nest is quiet, matte, twig and straw,
in the middle at the back. The machine is the one bright toy on the plaza, off to the side, and it is the only thing
there that sells anything.

---

## 1. The plaza, re-laid

### Where things are today (world x, z)

Plaza middle (-30, -4). Hub star (-30, 4). Arrival walk-in: bridge (2.5, 21), then (-9, 21), (-20, 12), hub.
Seen from the path mouth (-20, 12), left to right: Style deck bench (-46, -9), Eggs station (-31, -11), nest
(-25.12, -9.82), care arch (-17, -15). The right half holds three things in 14.6 studs; the left half is empty.

### The new layout

| Thing | World (x, z) | Was | From plaza middle | Bearing from path mouth (0 = straight to the plaza middle side, left negative) |
|---|---|---|---|---|
| **Egg machine** (new, station id stays `Eggs`) | **M = (-44, 4)** `[check]` probe below | new | 16.1 | about 72 left |
| Style deck bench (`Customize`) | (-46, -9) | same | 16.8 | about 51 left |
| **Sleepy Nest** | **(-31, -11)**, the old Eggs station's spot | (-25.12, -9.82) | 7.1 | about 26 left |
| Care arch (`Journal`) | (-17, -15) | same | 17.0 | about 6 right |

- Neighbour gaps: machine to bench **13.2**, bench to nest **15.1**, nest to arch **14.6**. Smallest gap on the plaza
  goes from 5.85 to 13.2. Rule from now on: **no two interactive things on the plaza closer than 12 studs.**
- The fan from the path mouth is even: about 20, 25 and 32 degrees between neighbours. Nothing hides behind anything.
- The nest is now on the plaza's centre line, at the back, under the big tree: the first thing you see straight ahead
  as you walk in, low and calm. The machine is the bright thing off to the left that pulls you across the plaza.
- `HollowWorldLayout.V7.Stations.Eggs` becomes the machine's CFrame. Front (local +Z) looks at **(-26, 7)**, between
  the hub and the path mouth, so its face is seen on the whole walk in.
- `Nest.Spot` = (-31, y, -11). `Nest.Facing` stays (-30, y, -4). Everything else on the nest is root-local and
  follows. Nothing is saved by position, so a tucked egg simply shows at the new spot.

### What happens to today's station model

Today's Eggs station (world mesh `Station_EggNest*`: stepped marble dais, glass globe, glowing egg, gold ring, the
small gold tag post beside it) **becomes the nest's seat**:

- **Keep:** the marble dais steps only. Matte marble, as now.
- **Remove:** the globe, the glowing egg (`Station_EggNest_Glow*`), the gold ring, the tag post. Glass and glow now
  belong to the machine and nowhere else on the plaza.
- The twig nest (the 21 parts, unchanged) sits on the dais top, centred.
- `[check]` Opus measures the dais: the nest needs a flat disc of **radius 3.0 or more at one height** (nest fringe
  2.57, Bear spot at radius 2.6). If the top is smaller, or the dais cannot be split from the globe in the chunk
  builder, **remove the whole station mesh** and stand the nest on plain marble at (-31, -11). Do not build a new
  plinth; a nest on the floor under the tree is fine.
- `EggNestLight` stays at this spot (it is the nest's warm light now). Lower it from +4 to **+2.5** over the ground,
  range 10 to **8**, so it pools on the straw instead of on a globe that is gone.

### Sign, Bear, pill at the new nest

With no station beside it the R2 "outer side only" rule is not needed, but the R2 numbers already work, so keep them:
`BearSpot` (-2.2, 0, -1.4), sign (-1.7, y, +1.6), `SignYaw` +50. `[check]` at the new root the sign's Front should
still be within 40 degrees of the walk-in points; if it is not, yaw it to face (-20, 12) and tell me the number.
If Bear's spot lands on a dais step edge, move it out to radius 3.4 on the same bearing (onto the marble below).

### The egg machine's spot: probe before any `src/` edit

Extend `scripts/probe_nest_spot.luau` (read-only):

1. 16 rays down on a ring r **2.8** round M, plus the centre: all on plaza marble, within 0.1 of each other in height.
2. No dirt path, trim strip or lawn within **4.0** of M (the west path mouth is the risk).
3. Sight lines at 5 studs up from (2.5, 21), (-9, 21) and (-20, 12) to M + 5 up: nothing hit. (The toy lawn at
   (-30, 18.5) is south of all three lines by my arithmetic; confirm.)
4. The same three sight lines to the nest at (-31, -11) + 2 up, with the machine's box in place: clear.

Fallbacks, in order: **M2 = (-41.5, 2.5)** (12.4 from the bench, 15 degrees off it); then **M3 = (-17.5, -2.5)**, the
old nest spot A, probed clear in beta 12. M3 costs something: from the path mouth it stands about 10 degrees off the
care arch and partly covers it. Use it only if both west spots fail, and tell me.

### Every plaza element: keep, move, remove

| Element | Ruling |
|---|---|
| Hub star on the floor (-30, 4) | Keep. |
| Style deck bench and its Deck board | Keep, untouched. |
| Care arch with the mobile | Keep, untouched. |
| Old Eggs dais | Keep the steps as the nest's seat (or remove whole, see above). |
| Old Eggs globe, glow egg, gold ring, tag post | **Remove.** |
| Twig nest, sign, Bear spot | **Move** to (-31, -11). |
| `EggNestLight` | Keep at the nest, lowered (above). |
| Egg machine | **New** at M. |
| Eggs attract pin (egg glyph, hue `#FFC83C`) and its floor ring | **Move** to the machine. Pin height: machine top + 1.6. |
| A pin or attract ring on the nest | **None**, ever. The only marks on the nest are its sign, its pill, and the existing `pinReady` "Hatch!" pin when the egg is ready. |
| Nest pill | Keep, **shortened** (section 3). |
| Nest rail toast "Tucked in! Come back in 8..." | **Remove** the rail copy of it. Shot 4 shows the same sentence three times at once (rail, pill, pill). The pill says it once. |
| HUD chip `Egg 8 h` | Keep. Tap still routes to the nest. |
| Pet need bubble | Keep. With the nest 13 studs from anything, the R2 overlap rule (`BubbleNear` 6) fires far less; leave it in. |
| Show me trail | Hatch eggs trail ends 3.0 in front of the machine. Nest trail ends at `Nest.Front` as now. |
| Pet block boxes | The nest's box follows the root. Add one for the machine: 4.8 x 4.4, turned with it. |
| Lamps, big tree, pergola, toy lawn, benches | Keep. |
| Anything else standing on the plaza marble that is not in this table | `[check]` Opus lists it (name, position) and I rule. I could not enumerate the baked world mesh from the repo. |

### Prompts: one verb each

| Thing | State | Prompt | Reach |
|---|---|---|---|
| Egg machine | always | **`Turn`** (was `Browse eggs`) | 7 |
| Nest | new egg, not tucked | `Tuck in` (unchanged) | 4.5 |
| Nest | napping, tucked | **`Peek`** (new: opens the "?" card, section 3) | 4.5 |
| Nest | ready | `Hatch` (unchanged) | 4.5 |
| Style deck, care arch | | unchanged | 7 |

`[check]` `Turn` on its own may translate badly. Give the localization row the context "turn the handle of a toy
machine". If Spencer finds it unclear on the beta, fall back to `Browse`.

---

## 2. The egg machine

A capsule-toy machine is a generic object; this one is ours. It must not read as any particular real or game machine:
no boxy red cabinet, no coin slot, no price plate, no logo. The silhouette is **an egg in an egg cup with a sprout on
top**: an egg-shaped glass globe (taller than wide) held in a scalloped leaf collar, on a round pot-bellied base with
three stubby feet. The handle is a big flower-shaped dial with one round knob. The chute is a curled leaf that ends in
a small woven cup, a tiny echo of the nest.

### Size (studs; an avatar is about 5.5 tall)

| Part | Size | Notes |
|---|---|---|
| Whole machine | **4.2 wide, 3.8 deep, 7.2 tall** | Footprint fits a 4.8 x 4.4 block box. |
| Feet (3) | 0.9 across, 0.35 tall | Rounded pads; two front, one back. |
| Base (pot belly) | 4.2 wide, 3.6 deep, 2.6 tall, from 0.35 to 2.95 | Widest at 1.4 up, tapering to 3.2 at the top. |
| Leaf collar | 3.9 across, 0.55 tall, at 2.95 to 3.5 | 8 scallops, each tip curls out 0.2. |
| Globe | **3.5 wide, 3.9 tall**, 3.3 to 7.0 | Egg profile: widest at 40% of its height. Wall reads 0.08 thick. |
| Cap | 1.3 across, 0.3 tall, on the globe's top | Small matte disc. |
| Sprout | two leaves, 0.9 long each, on a 0.35 stem; top at 7.2 | Its own part: it sways. |
| Dial | **1.7 across**, 0.3 deep, centre at 1.95 up on the front face | 6 rounded petals, a raised 0.55 knob at radius 0.5. Its own part: it turns. An egg shape embossed in the middle. No text. |
| Chute | leaf slide 0.9 wide, starts 1.1 up at front-right, curls down 1.3 long | Part of the body mesh. |
| Cup | 1.2 across, 0.45 tall, sitting on the ground at front-right, 0.5 proud of the base | Woven look, matte. This is where the egg lands. |
| Eggs in the globe | **0.55 wide, 0.72 tall** each | About 24 seen: a baked pile of 18 plus 6 loose. |
| The dropped egg | 0.62 wide, 0.8 tall | One pooled part. |

The player's eye (about 5 up) is level with the middle of the globe. The dial is at a child's hand height.

### Materials and colours

The body is a toy, so it may be brighter than the world, but it is **enamel, not chrome**: one soft highlight, no
mirror shine, no neon. The colour comes from the eggs, not from the casing.

| Part | Colour | Finish |
|---|---|---|
| Base | cream `#F4E8CF` with a hand-painted darker band `#E2D2B0` round the widest point | Matte painted enamel; texture carries fine brush grain and a few rim chips. Roughness about 0.6. |
| Feet, cap | deep garden green `#38694A` (the sign green) | Matte. |
| Leaf collar, sprout, chute leaf | leaf green `#6FBF73`, underside `#4E9A5A` | Matte, vein lines painted in. |
| Dial | sunflower `#FFC83C` (the Eggs attract hue), knob cream `#FFF3C4` | Satin, roughness about 0.4: the one part that catches a little light. |
| Cup | straw `#C9A560` weave over `#8A6A3A` | Matte, same family as the nest's straw so the two places rhyme. |
| Globe | clear, faint warm tint `#FFF8E6` | Transparency **0.78**, one painted highlight streak on the upper left (a decal or vertex stripe at 35% white), a thin green rim where it meets the collar. `[check]` Roblox Glass material against transparent things behind it; if it sorts badly use SmoothPlastic at 0.78 with the painted streak. |
| Eggs | only the egg types the screen sells: Toy `#FFB340`, Hue `#FF7AB8`, Material `#8FF0E4`, Feature `#9CFFDD`, Stat `#FF8A5C` | Use each type's own colour map from `EggModels` where it is cheap; otherwise flat colour with the type's zigzag band. Mix about 6 Toy, 5 Stat, 5 Hue, 4 Material, 4 Feature. |
| **Never in the globe** | lavender `#C9B4FF` | That is the napping egg. It lives only in the nest, so the two never get confused. |
| Light | one PointLight inside the globe, `#FFE9A6`, range 8, brightness 0.5, **dusk and night only** | By day the eggs are lit by the sun. |

### Idle motion

Calm. It should look alive from across the plaza without ever looking like it is shouting.

- **Sprout:** sways 4 degrees each way at 0.35 Hz, always.
- **Loose eggs (6):** each rocks 3 degrees at its own rate (0.2 to 0.3 Hz, own phase).
- **A settle:** every 9 to 14 s (random) one loose egg slips 0.15 to 0.3 studs down the pile and comes to rest over
  0.5 s with one small bounce. Sound `egg_tok` (3 variants): a soft glassy knock, -26 dB, heard within 14 studs.
- **The body never moves on its own.**
- **Hello:** when a player comes within 10 studs the dial nudges 15 degrees and springs back (0.4 s) with one click at
  -24 dB. Once per approach, at most every 20 s.
- Reduced motion: sprout and rock off, settle stays (it is small), hello stays.
- All of it is client-side and stops beyond 60 studs.

### The crank when you open Hatch eggs (press `Turn`)

A quarter turn, then the screen. It must not make the screen feel slow.

| Time | What | Sound | Haptic |
|---|---|---|---|
| 0 | Dial turns 90 degrees over 0.28 s, easing out with a small overshoot | 3 ratchet clicks at 0, 90, 180 ms (`crank_click`, 3 variants: a wooden pawl on a plastic gear, 1.2 to 2 kHz, 12 ms, -20 dB) | 3 light ticks |
| 0.1 | The 6 loose eggs hop 0.12 and land | one `egg_tok` at -24 dB | |
| 0.3 | Hatch eggs opens as today | today's open sound | |

Closing the screen: nothing. The dial does not turn back; it simply rests wherever it is.

### The crank when a hatch is bought

This is the new front of the hatch ritual (`ASMR-AND-SCALE-LOOK.md` section 1). It adds a **beat before stage 0
"Settle"**, and it hands over to it: **the thud of the egg landing in the cup is the Settle thud.** One egg, one
landing. Do not play two.

| Time | Machine (world) | Sound | Haptic |
|---|---|---|---|
| 0 | Dial makes one full turn over 0.6 s, even speed, a little resistance at the start | 5 clicks at 0, 110, 220, 330, 440 ms; pitch steps up about 4% a click | 5 light ticks |
| 0.1 to 0.6 | Eggs in the globe churn: loose eggs hop 0.2, the pile shivers 0.04 | 2 `egg_tok`, soft | |
| 0.6 | Dial stops with a spring-back of 8 degrees | `crank_clunk`: a low wooden knock, 180 Hz body, 60 ms, -16 dB | 1 medium |
| 0.62 to 0.85 | One egg **in the bought type's colour** rolls down the leaf chute | `egg_roll`: a hollow rattle, 0.22 s, -20 dB, rising slightly | |
| 0.85 | It lands in the cup, rocks once | the ritual's Settle thud | the ritual's Settle haptic |
| after | The ritual carries on from "Tap the egg" exactly as specified | | |

- **On screen** (the screen covers most of the machine): the preview egg in the right pane gives a 6 degree shake on
  each of the 5 clicks and drops 8 px on the clunk. No new art. The sound does the work.
  `[check]` against `HatchCinematic`'s first frame; if the cinematic already owns the screen at 0, put the 5 clicks
  over a dimmed frame and start the egg's fall-in at 0.62.
- **Streaks** (the ritual's rule: "Hatch another" within 20 s): 2nd in a row, a half turn in 0.45 s with 3 clicks;
  3rd onward, a quarter turn in 0.25 s, 1 click and the drop. The clunk and the roll always play.
- **Skip:** the crank beat cannot be skipped (it is under a second); everything after follows the ritual's skip rule.
- **Others nearby** see the dial turn and the egg drop, with sound inside 20 studs, at most once every 2 s per player.
  `[check]` cheapest route (a station attribute or one unreliable remote); if it costs a new remote, ship local-only
  first.
- The egg in the cup fades 1.5 s after the screen's hatch ends.
- The globe never empties. No stock, no counter, nothing that hints at scarcity.

### How it is built

**Blender mesh through the kit pipeline** (the `build_world_aero_kit.py` route), not Studio parts. The egg profile,
the scallops and the leaf chute are curves; parts would look like a greybox. Hand-modelled, hand-painted texture. No
AI art, no generated mesh.

| Piece | Instances | Triangles |
|---|---|---|
| Body (feet, base, collar, chute, cup, cap) | 1 MeshPart, anchored, collides (box collision) | 2,200 |
| Globe | 1 MeshPart, no collision | 320 |
| Dial | 1 MeshPart | 420 |
| Sprout | 1 MeshPart | 120 |
| Baked egg pile (18 eggs, vertex-coloured, backs removed) | 1 MeshPart | 1,300 |
| Loose eggs | 6 MeshParts sharing one 96-triangle egg | 576 |
| Dropped egg | 1 pooled MeshPart, same mesh | 96 |
| **Total** | **12 instances** | **about 5,000; hard cap 6,000** |

One 512 px texture for body, dial and cup. Egg colour by vertex colour or `Color`, no extra textures unless the
`EggModels` colour maps are already loaded. No physics anywhere: every egg move is a tween.

Opus sends me, before wiring anything: a Blender render front, three-quarter and from the path mouth's angle; then a
Studio capture at noon and at dusk from (-20, 12), with an avatar beside it.

---

## 3. The "?" on the napping egg

### What you tap

The nest's pill gets short, and gets a "?".

- **Pill while napping:** the clock only, `Hatches in 8 h` (existing `onb3.nest.hours` / `minutes`), with a round
  **"?" disc** on its right end: 24 px on screen inside a **44 px hit area**, cream fill, dark ink, the same button
  look as the Things to do "?" (`Kit.button`, `secondary`). Tapping the disc **or** the pill opens the card.
- The long sentence `onb3.nest.how` ("{pet}'s egg naps for 8 hours. Come back to hatch a gift.") **leaves the pill**
  and lives in the card. The pill is now one line, about 130 px wide instead of 220 over two lines.
- **Pill when ready:** `Hatch me!` in gold, no "?".
- **Keyboard and gamepad:** the `Peek` prompt (section 1) opens the same card.
- **HUD chip `Egg 8 h`:** unchanged (it routes you to the nest). No "?" on the chip; it is too small to split.
- First time only, the "?" disc pulses twice (scale 1 to 1.15, 0.5 s each) when the pill first shows after the
  first tuck-in. Never again.

### The card

Reuse the Things to do "?" card exactly: same frame, same title bar, same close. Opens centred as that card does
(bottom sheet on phone, if that is what it does today `[check]`). One button.

| Key (new, under `onb3.nest.help`) | Text |
|---|---|
| `title` | **Napping egg** |
| `what` | Your pet's egg is asleep in the nest. |
| `time` | It naps for {hours} hours, even when you're not playing. |
| `gift` | When it wakes up, come back and hatch it for a gift. |
| `inside` | reuse `onb3.nest.inside` / `insideStars`: "Inside: {item} and {stars} Stars." |
| `free` | It's always free. You never need Stars for it. |
| `next` | Hatch it, and a new egg starts its nap. |
| `wait` | Naps can't be hurried. Go play, it will be here. |
| `button` | Got it |

- Under the title, one live line in the small style: `Hatches in {hours} h` and, in the welcome week,
  `Egg {count} of 7` (both existing keys).
- Six short lines, each with a small leading dot, 14 px, at most two lines each at 320 px wide. `[check]` at 320 px;
  if it runs past the card, drop `next` first.
- Icon: the lavender egg in its nest, the same art as the chip, 56 px, top left.
- No Stars icon anywhere on the card except inside the `inside` line. No "Get Stars", no button but "Got it".
- `wait` is there on purpose: there is no skip of any kind, and a child should hear that as a calm fact, not find it
  out by hunting for a button.
- `[check]` Opus confirms each line is true of `Nest.lua` as shipped (I read: 8 hours, server clock, a new egg lands
  on hatch, gifts fixed for eggs 1 to 7 then Stars only, never a cost). If tucking in changes anything but the look,
  tell me and I will add a line.

---

## 4. The Hatch eggs screen and the station line

### The "Napping egg" row: removed

R2 kept the row because the nest stood at the station's foot ("one place for eggs"). Under the split that reason is
gone, and the row now points at something across the plaza.

- **Remove the `Napping egg` row from Hatch eggs**, in every state, including ready. The list starts at the first egg
  type. First focus is the first egg type, always.
- The row's jobs are already covered: the HUD chip, the Coming up strip's egg chip (it routes to the nest pin), the
  `pinReady` "Hatch!" pin, and the ready ping at 14 studs.
- The `"nest"` close reason and the Board-mode display-only row go with it. `[check]` nothing else reads that reason.
- The space it leaves: do not fill it. The three egg rows move up; the list is less crowded, which is the brief.

### The station line

| Key | Ruling |
|---|---|
| `r5.station.Eggs.name`, `EggsV3.name` | `Hatch eggs` (unchanged) |
| `r5.station.EggsV3.line` | `Toys, looks and snacks for your pet` (unchanged; now the only line on v3 places) |
| `r5.station.EggsNest.*` ("Toys, looks and snacks. Your napping egg is here too.") | **Retired.** It is no longer true. `StationAttract` drops the `nest` branch and always uses `EggsV3` under the ceiling. Remove the key so the sync deletes its translations. |
| `onb3.tip.hatch` "{pet} found the egg machine!" | Keep. It is finally literally true. |
| `onb3.tip.nest` | Keep. |

Still no "friends", "pets" or "new pets" on the machine or its screen: these eggs give toys, looks and snacks.

---

## 5. Order, switch, and what I want to see

1. Probe (section 1). Send me the numbers and the list of unlisted plaza elements.
2. Nest to the old station's spot, station mesh stripped, pill shortened, "?" card, `Peek`. No new art needed; this
   can ship on the beta first, with the Eggs prompt on an invisible anchor at M and a plain marker, if the mesh is not
   ready. `[check]` whether an interim with no machine is acceptable to Spencer; if not, hold step 2 for step 3.
3. Machine mesh (Blender renders to me first), then placed, idle motion, open crank.
4. Buy crank, joined to the hatch ritual. If the ritual is not built yet, the crank beat ships in front of today's
   cinematic and the landing thud stands in for Settle.
5. Row and line removal (section 4) lands with step 2.

One switch for the whole split (suggest `Onboard.on("eggCorner")`, under the ceiling), so the beta can flip back.
Add the `V3-TEST-PASS.md` rows when it publishes.

**Captures I need back:** from (2.5, 21), (-20, 12) and the hub at noon and dusk; the nest close with the short pill
and "?"; the card on desktop and at 844 x 390; a phone clip with sound of open-crank, one buy, and a streak of three.

## 6. Open items

- `[check]` M = (-44, 4) is on clear marble and off the west path mouth (probe 1 to 4).
- `[check]` The dais top is flat to radius 3.0, and the globe and glow can be removed without the steps.
- `[check]` Unlisted plaza elements.
- `[check]` `Turn` as a one-word prompt in translation.
- `[check]` Glass sorting on the globe.
- `[check]` Where the buy crank sits against `HatchCinematic`'s first frame.
- `[check]` Whether others see the crank (remote cost).
- `[check]` The "?" card's phone layout and the six lines at 320 px.
- `[check]` Every card line against `Nest.lua` behaviour.

---

## Placement rulings (R2) (Fable, 2026-11-24)

Answers F1 to F6 in `EGG-CORNER-BUILD-PLAN.md` and its section 2 list. Where this differs from sections 1 and 6 above,
this wins.

**Seen:** the builder's plan (sections 1, 2, 5, 9, 14) and the four machine captures in `egg-machine/studio-r1/` (the
machine standing at M, on lawn). **Not seen:** the machine at M4 or M5, the west bench or either egg statue (I cannot
pick them out in the captures), the plaza with the old station gone. Every angle below is arithmetic from the
builder's coordinates; the kiosk's width (about 7 studs) is read off pixels in `noon-path-mouth.jpg`. The captures at
the end are what confirm it.

### 1. The machine spot

M and M2 are dead (bench, lawn). M4 works but has two faults, so it is the interim, not the final.

| | **M4 = (-38.5, 1.5)** interim | **M5 = (-41, 2)** final |
|---|---|---|
| Needs | nothing; ships now | `Station_BenchWest` removed (same island re-export as the station split) |
| From plaza middle (-30, -4) | 10.1 | 12.5 (footprint ring reaches 15.3; paving edge 15.5) |
| To kiosk / nest / hub (-30, 4) | 12.9 / 14.6 / 8.9 | 12.1 / 16.4 / 11.2 |
| To Blossom mouth / Knoll mouth | 6.6 / 8.5 | 5.0 / 8.5 |
| Bearing from path mouth (-20, 12) | about 60 left, 21.3 away | about 65 left, 23.3 away |
| Against the kiosk (51 left) from the path mouth | edges overlap about 2 degrees | clear by about 2 degrees |
| Same from (-9, 21) / (2.5, 21) | overlap 2 / touching | clear by 1 / clear by 2 |
| `Turn` prompt anchor to the hub | 6.3: the prompt shows on arrival | 8.6: it does not |

- **Why not stay at M4:** the bench at (-43, 5) faces the plaza middle, and M4 is 5.2 studs straight down that line.
  The bench would stare at the pot's back across 2.3 studs. And the machine clips the Style deck's left post through
  the whole walk in, which breaks "nothing hides behind anything".
- **Ruling:** build at **M4 now**; `EggCorner.Spot` moves to **M5** in the build that carries the re-export. One
  constant. If the M5 capture shows the kiosk is wider than I measured and they still touch, tell me before moving.
- **Facing, both spots:** front (+Z) looks at **(-26, 7)**, unchanged. At M5 that is 7 degrees off the path mouth,
  8 off the hub, 12 off (-9, 21): face-on for the whole walk.
- **Fan from the path mouth at M5:** machine 65, kiosk 51, nest 26, arch 6 right. Gaps 14, 25, 32.
- **Reach:** `Turn` reach **6 while at M4** (keeps it off the hub), back to 7 at M5.
- **Inlay ring:** both spots stand across `Plaza_InlayRing` (r 10.4 to 11.9, 0.2 proud). Probe rule 1 becomes: all
  17 rays on marble or inlay, within **0.25**. Seat the machine on the highest hit; a foot may sink 0.2 (feet are
  0.35 tall). No shim.
- **Attract ring at the machine:** r **3.6**, not 4.7 (at M5 4.7 spills 1.7 onto lawn). `[check]` if the back arc
  still shows on grass, clip it and tell me.
- Pin (top + 1.6), block box, trail end (front x 3.0): unchanged.
- M3 east stays the last resort. Probe M5 in the same run as M4 (rule A2 will fail on the bench; I expect that).

### 2. The plaza list

"Re-export" means the island re-export of plan section 6.2. Until it lands, those pieces stay where they are.

| Element | Ruling |
|---|---|
| `Plaza_Paving`, `Plaza_InlayRing` | Keep. |
| `Plaza_InlayStar` (-30, -4) | Keep. **F5:** this is the drawn star. My table's "(-30, 4)" was the hub route point, which has nothing drawn on it. Both stay. |
| `Station_EggNest`: steps, cup, glow egg, halo, gold trim ring, stele | **Remove, all of it** (top step 2.2 < 3.0). Now, under the switch: hide `W7_NestHalo__glow_warm`, `W7_Stations__foliage`, the `AeroAdditions` dome and `GlossLip_Eggs`. Steps, egg and stele go in the re-export, which fills the floor under r 3.6 with paving marble in the same plank pattern. |
| `Station_BenchWest` (-43, 5) | **Remove** in the re-export. The machine takes its side of the plaza. |
| `Station_BenchEast` (-17, 5) | Keep. |
| `Statue_Egg` (-42, 9.5) | **Remove** in the re-export (**F2**). 7.6 from M5 and 19 degrees off it from the path mouth: a third egg shape on the machine's side. Plinth goes too; grass or paving as underneath. |
| `Statue_Egg` (-18, 9.5) | **Remove** with its twin. It stands 3.2 from the path mouth and 1.6 to 2.3 studs off the line from the bridge head (2.5, 21) to the machine. Eggs on the plaza are then only the machine's and the nest's. |
| Kiosk + `Pad_Workbench`, care cradle + pad | Keep, untouched. |
| `Urn` (-46.5, -17), `Urn` (-13.5, 5) | Keep both. |
| Colonnade columns, entablature, `Colonnade_FallenDrum` | Keep. |
| Hatch tree, lantern, `LanternLight` | Keep. |
| `Pad_Future_A` (-48, -22) | Keep, empty. |
| `Pad_Future_B` (-13, -4) | **Remove** in the re-export. It is 11.7 from the care arch, so under the 12-stud rule nothing interactive can ever stand on it; an empty disc in the walk-in view promises something that will not come. |
| `Station_ToyLawn`, `Station_PicnicWest`, lamp 5, flower patch, path mouths | Keep. |
| Attract pins and rings: Customize, Journal | Keep. |
| Eggs pin and ring | To the machine (ring r 3.6). |
| `EggNestLight` | At the nest, **+2.5 over the marble**, range 8. `KioskLight`, `CradleLight`, `PlazaLight`: keep. |
| **F4** nest trail pin while napping | Allowed, only while a Show me trail is drawn, no ring. It goes when the trail goes. |
| **F6** buy crank sounds away from the machine | Play them, flat (not positioned), with the screen. The world motion only runs inside 60 studs. |

### 3. The nest on plain marble

**Confirmed: (-31, -11), on the paving, no dais.** It sits 7.1 from the star's middle: the fringe (r 2.57) spans 4.5
to 9.6, so it clears the star (r 3.2) by 1.3 and the inlay ring (10.4) by 0.8. It lands in the plain band between
them. Do not nudge it.

- **No rim, no rug, no plinth.** The nest already stands on bare marble at today's spot (bottom right of
  `noon-path-mouth.jpg`) and reads fine. A rug or rim would make it a second "station".
- **It gets two small things so it sits, not floats** (root-local, part of the nest, no collision):
  1. **Straw scatter:** 12 flat strands and 3 small fallen leaves on the marble, radius 2.7 to 3.6, two thirds of
     them on the tree side (north-west). Strands 0.5 to 0.9 long, 0.02 over the floor, the nest's own straw texture,
     matte. Budget 40 triangles. None inside the Bear spot's 1.0 radius or on the prompt point.
  2. **Contact shadow:** one soft dark disc under the nest, r 3.0, black at 22% in the middle fading to 0 at the
     edge. `[check]` if `Nest.lua` already draws one, keep that and skip this.
- Bear spot, sign, `SignYaw` 50: as section 1; the probe's B5 decides the yaw. With no steps, the "step edge" rule for
  Bear is void.
- **Interim (plan A1):** while the bare steps and glow egg cannot be removed, the nest may stay at its old spot beside
  them **on the beta only**. The corner does not go live until the re-export has landed and the nest is at (-31, -11).

### Captures that settle this

Noon and dusk from (2.5, 21), (-9, 21), (-20, 12) and the hub: once at M4 now, again at M5 after the re-export with
the bench, both statues, pad B and the station gone and the nest moved. Plus one from the east bench looking west.
