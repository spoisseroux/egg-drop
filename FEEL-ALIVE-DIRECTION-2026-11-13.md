# Feel alive: art and audio direction (2026-11-13)

**Direction spec for approval. Nothing here is built.** Spencer: "Everything needs to feel alive." This covers the five requests in TODO batch B: a water bed, birds, pet life, a decluttered hub with retro sprite flowers, and stations that invite you over. Placeholder audio, the flower sprites and the mockups exist; `src/` is untouched.

| Deliverable | Where |
|---|---|
| Mockups (look at these first) | `artifacts/feel-alive-2026-11-13/01` to `09-*.png` |
| Flower sprites, attract icons (real assets) | `artifacts/feel-alive-2026-11-13/sprites/` |
| Placeholder audio (12 cues, WAV + OGG) | `assets/audio/placeholder/egg_drop_*.wav`, listed in `PLACEHOLDER-AUDIO.md` |
| Audio generator | `scripts/build_ambient_placeholder_audio.py` |
| Mockup scripts (re-runnable) | `artifacts/feel-alive-2026-11-13/build_sprites.py`, `render_hub_mockups.py`, `compose_mockups.py` |

Limits of this pass: the audio was checked by level, loop seam and spectrogram, not by ear. The mockups are Blender renders of `world1-mockup-v7.blend` (the source of the Studio island) with the attract effects painted on in 2D, so one ring overlaps the avatar in `04`. Nothing was run in Studio.

---

## A. Ambient audio

### A1. What exists

`BoardAudio` owns three SoundGroups: `EggDropSFX` (one-shots, default voice volume 0.72), `EggDropMusic` (voice 0.13, ducked to 0.22 by hatch and boot) and `EggDropPurr`. All follow the master `DeckSettings.Sound` (Full 1, Quiet 0.4, Off 0) and mute when the window loses focus. There is no ambience and nothing positional. The falls and stream are silent Beams (`LoungeWorldV7Art.water`).

Effective loudness today (file RMS plus voice volume): music about -41 dBFS, merges about -20, menu ticks -28, petting chirps -30, the scheduled coo -34.

### A2. Layers

A new `EggDropAmbience` SoundGroup (group volume = master x ambience setting), owned by a new client module `GardenAmbience.lua`.

| Layer | Cue | Type | Voice volume | Effective level |
|---|---|---|---|---|
| Brook bed | `water_bed_loop` | 2D, looped, always on in the garden | 0.22 away from water, up to 0.40 on the stream bank | -44 to -39 dBFS |
| Tumble Falls | `waterfall_loop` | 3D, looped | 0.70 | -30 dBFS at the pool |
| Sky Falls | `waterfall_loop` | 3D, looped | 0.50 | -33 dBFS at the lip |
| Birds | `bird_chirp_1..6` | 3D one-shots, pool of 3 emitters | 0.50 | -36 to -44 dBFS at 20 to 60 studs |
| Coos | `pet_coo_1..3` | 2D through `BoardAudio:play` (as now) | 0.30 | -32 dBFS |
| Station ping | `machine_attract` | 2D through `BoardAudio:play` | 0.35 | -30 dBFS |

The bed sits just under the music so it is felt as air, not heard as a track. Nothing ambient is louder than a menu tick except the falls when you stand in them.

### A3. Brook bed curve

The bed never goes silent in the garden. Its volume follows the distance `d` from the listener to the nearest point on the stream polyline (`WorldV7Data.beams.stream`, 14 points; test segments, not just points), sampled at 4 Hz and eased over 0.5 s:

`bed = 0.22 + 0.18 * smoothstep(1 - d / 45)`

| Distance to the stream | 0 | 10 | 20 | 30 | 45+ |
|---|---|---|---|---|---|
| Bed volume | 0.40 | 0.38 | 0.32 | 0.27 | 0.22 |

Reference spots: the hub plaza centre is about 36 studs from the stream (0.24), the bridge is on it (0.40), the arrival dais is far (0.22).

### A4. Waterfall emitters

Positions from `WorldV7Data.beams.falls`. One invisible anchored part each, in `room.WaterFlow`, with a looped `Sound`.

| | Tumble Falls (`W7_Water__waterfall_tumble`) | Sky Falls (`W7_Water__waterfall_sky`) |
|---|---|---|
| Beam | top (77.3, 51.6, -77.3), bottom (77.3, 3.2, -77.3), width 10.6 | top (-5.9, 3.25, 64.1), bottom (-5.9, -68, 64.1), width 3.7 |
| Emitter position | (77.3, 9, -77.3): the pool, a little above head height | (-5.9, 2.5, 64.1): the lip, where the water leaves the island |
| Volume | 0.70 | 0.50 |
| RollOffMode | InverseTapered | InverseTapered |
| RollOffMinDistance | 18 | 10 |
| RollOffMaxDistance | 150 | 90 |
| PlaybackSpeed | 0.92 (bigger, lower) | 1.08 (thinner, brighter) |
| Start offset | TimePosition 0 | TimePosition 3.7 (the two never phase) |

Design curve to check by ear in Studio (approximate: inverse falloff from the minimum distance, tapering to zero at the maximum):

| Distance to Tumble Falls | 18 | 36 | 72 | 110 | 150 |
|---|---|---|---|---|---|
| Heard volume | 0.70 | 0.33 | 0.12 | 0.04 | 0 |

| Distance to Sky Falls | 10 | 20 | 40 | 65 | 90 |
|---|---|---|---|---|---|
| Heard volume | 0.50 | 0.24 | 0.09 | 0.03 | 0 |

From the hub (about 70 studs from Sky Falls, 130 from Tumble Falls) the falls are a faint hint to the south and nearly nothing to the east; the bed carries the calm. Walking the stream to either end, the rush grows and pans, which is the "louder as you approach" Spencer asked for. If InverseTapered measures far off this table, keep the positions and drive `Volume` from the table instead.

### A5. Birds

One scheduler in `GardenAmbience.lua`, stepped from the existing `RoomView` update (the same owner and gate as `PetCooScheduler`). No per-tree Sounds: three pooled emitter parts are moved to a perch for each chirp.

- **Perches:** canopy points of the 34 trees in `artifacts/world1-mockup/v7/vegetation-placements.json` plus the Hatch Tree at (-36, 15, -18). Perch = tree position + (0, 7 x scale, 0). Export them as `perches` in `WorldV7Data` from `scripts/build_world_v7_assets.py`.
- **Pick:** among the 6 nearest perches within 70 studs of the listener, weighted to the nearer ones, never the same tree twice running. Each tree is one "bird": its pitch is seeded per tree (0.92 to 1.12) and it favours two of the day cues.
- **Emitter:** Volume 0.50, InverseTapered, min 12, max 85.

| Time (`HollowClock` daylight) | Gap between events | Cues | Phrase chance |
|---|---|---|---|
| Day (above 0.6) | 6 to 14 s, uniform | 1 to 5 | 25%: 2 or 3 chirps from one tree, 0.35 to 0.9 s apart |
| Dusk and dawn (0.3 to 0.6) | 12 to 24 s | 3 and 6 | 10% |
| Night (below 0.3) | 25 to 50 s | 6 only ("hoo-hoo"), volume 0.35 | none |

- **Never during the deck round:** the scheduler runs only while `mode == "Room"`. Entering Board mode cancels pending chirps and lets a sounding one finish.
- A second player's answer: 15% of day events queue one reply from a different tree 0.8 to 1.6 s later. That is the cheapest way to make it sound like a place.
- Original voices only: synthesised whistles, no recordings, no recognisable species call.

### A6. Mixing rules

- Board mode (deck round): birds, falls and coos off; the bed drops to 35% over 0.6 s and returns over 1.0 s. See open question 3.
- Hatch reveal and Pocket Deck boot already duck music; duck `EggDropAmbience` to 0.3 with the same calls (`Audio:duck`).
- An overlay menu in the garden leaves ambience alone. Window unfocused: muted, like SFX.
- Coos and the station ping go through `BoardAudio:play`, so they follow the SFX rules.
- Caps: at most 3 bird voices, 1 coo and 1 station ping at once.

### A7. Reduced audio option

Master `Sound` (Full, Quiet, Off) scales everything already. Add one setting beside it, **Ambience: On / Soft / Off**, default On: `EggDropAmbience` x 1, x 0.5 or 0. Off also stops scheduled coos and the station ping (petting sounds stay). Store it where `DeckSettings.Sound` is stored. Reduced Motion does not change audio.

---

## B. Pet life

### B1. What exists today

"Do our pets coo already?" **Yes, but you would barely notice.** One coo every 35 to 75 s for the whole screen, at volume 0.18 (petting chirps play at 0.26 to 0.42, ordinary SFX at 0.72), and the beat is skipped when no pet is standing still and on screen.

| Behaviour | What it does now | Where |
|---|---|---|
| Breath | body and head rise 0.014 on a 3.2 s cycle | `PetIdleMotion.sample` |
| Blink | every 3.2 to 5.4 s (seeded per pet), 0.15 s | `PetIdleMotion.sample` |
| Glance | head turns about 2 degrees, one side then the other, on a 10.4 s cycle | `PetIdleMotion.sample` (`glance`) |
| Ears, tail, wings | ear flick every 4 to 9 s; tail 1 Hz, 3 Hz when pleased, still when sleepy; wings flap on 1.8 s | `PetIdleMotion.appendages`, `.wings` |
| Idle beats | after 8 to 10 s standing, at most one per 10 s, picked evenly from yawn 2.2 s, stretch 1.8 s, sneeze 1.4 s, look 2.4 s, wave 1.8 s (wave only if the owner stands within 6 studs). **Owner's own pet only.** | `PetIdleBeats`, enabled in `RoomView` line 216 |
| Faces | six: neutral, curious, startled, pleased, sleepy, affectionate. Mouths: smile, open, line, soft | `PetExpression` |
| Face by activity | focus: curious. Greet: pleased. Investigate: curious. Play: pleased with a startled flash. **Every rest, even a 1.5 s pause, is sleepy** (eyes at 18%) | `shared/GardenActivity.lua` line 173 |
| Sit | **None.** The pet stands through `rest`, `settle` (5 s) and `nookRest` (6 s). The only lowered body is the Docked care pose | `PetCarePose.set` |
| Coo | one listener-owned voice, 35 to 75 s, volume 0.18, family cue (`pet`, `puddle`, `wick`, `orbit`) at pitch 0.83 to 0.90, with a 0.4 to 0.6 s head-roll, nod, hand and mouth overlay. Needs: on screen, within 28 studs, standing, neutral or sleepy face | `PetCooScheduler`, `PetCooPose`, `CareFeedbackData.families` |
| Contact sounds | boop, petting chirps (0.26 to 0.42), purr loop | `RoomView`, `BoardAudio` |
| Walk | one gait cycle per 1.45 studs x scale, capped at 3 cycles a second; bob 0.065 (Ovelle 0.055) once per cycle; weight shift 0.045 studs and 3 degrees of roll; planted feet with 58% stance; hands swing | `PetFollow` lines 62 to 73 and 110 to 114, `GardenPetVisual` lines 279 to 300, `PetPoseSampler.plant` |
| Speeds | stroll 3, walk 4, catch-up 9, leash 18 studs a second | `shared/GardenLayout.lua` |
| Deck reactions | cheer hop, win double hop, loss startled then sleepy | `PetReactions` |

Three things make the pets read as flat: the sleepy face on every pause, a glance too small to see, and idle beats that are rare, evenly random and missing on everyone else's pet.

### B2. Tuned behaviour table

| Behaviour | Change | File |
|---|---|---|
| **Idle beat timing** | `IdleAfter` 8 to 5 s. `Gap` 10 to 7 s plus the existing 0 to 2 s jitter. A standing pet does something about every 9 s instead of every 20 | `PetIdleBeats` |
| **Idle beat weights** | Replace the even pick with weights. Day: look 28, sit 16, stretch 14, wiggle 10, wave 12 (owner near, else added to look), yawn 10, sneeze 5, scratch-ear 5. Night (daylight below 0.3): yawn 30, sit 25, look 20, stretch 10, others 15. Never the same beat twice running | `PetIdleBeats` |
| **Beats for other pets** | Enable for the 4 nearest visitor pets within 40 studs (seeded, local, no network) | `RoomView` (set `idleBeatsEnabled` on `companions.active`) |
| **Look around** | Beat `look`: 2.8 s, head yaw to one side 30 degrees, hold 0.5 s, the other side 22 degrees, eyes lead the head by 0.1 s (the curious eye offset at line 361). Micro-glance raised from 2 to 5 degrees | `PetIdleBeats.pose`, `PetIdleMotion` (`HeadAngle`) |
| **Look at owner** | New. When the owner is within 12 studs and moves or stops, the head turns toward them up to 35 degrees at an ease rate of 4 per second, then relaxes after 3 s. The biggest single "alive" win | `GardenPetVisual` (head yaw), `RoomView` passes the owner position |
| **Stretch** | 2.2 s: arms up and out (hand fold 1.1 as now), body stretch 0.07 to 0.10, rise onto toes 0.05, eyes shut for the middle third, tail up, then a 0.15 s settle squash | `PetIdleBeats.pose` |
| **Yawn** | 2.4 s: head back 9 degrees (as now), mouth open from 20% to 80%, one hand to the mouth (right hand fold 0.9), ears droop, a slow blink after. 50% end with `pet_coo_3` | `PetIdleBeats.pose` |
| **Wiggle** (new) | 1.2 s: hips sway 4 degrees three times, tail 3 Hz, pleased face | `PetIdleBeats.pose` (uses the hip roll lever `weightRoll`) |
| **Sit, cute** (new) | See B3 | new `PetSitPose.lua`, `GardenPetVisual`, `PetPoseSampler` |
| **Face by activity** | `wanderPause`: neutral, with a look-around beat allowed at once. `settle`, `nookRest`, plain `rest` under 20 s: the new `content` face while sitting. Sleepy only for a rest longer than 20 s, at night, or while the owner plays the deck | `shared/GardenActivity.lua` line 173 |
| **New faces** | `content` (sit): eye 0.78, mouth soft, tilt 0.09, hand 0.2, blush 0.25. `joy` (owner returns from a round, greet after 60 s apart, win): eye 0.5, mouth open, head 0.05, hand 0.45, blush 0.5. `dozy` (first 3 s of going sleepy): eye 0.5, mouth line, tilt 0.06 | `PetExpression` |
| **Coo frequency** | Scheduled interval 35 to 75 s to 14 to 28 s by day, 40 to 70 s at night. Volume 0.18 to 0.30. Keep one voice per listener and the skip-if-nobody-eligible rule | `PetCooScheduler` (`wait`, `gain`) |
| **Coo triggers** (new) | Besides the schedule: look-at-owner starts (20%, `pet_coo_1`), sit lands (50%, `pet_coo_3`), stretch ends (35%, `pet_coo_2`), greet (60%, `pet_coo_2`), owner returns from Board mode (always, `pet_coo_2`, with the `joy` face). Limits: 6 s between coos of one pet, 2.5 s between any two coos | `PetCooScheduler` (a `request(visual, cue)` entry), callers in `PetIdleBeats`, `RoomView` |
| **Coo voice** | Cues by mood: curious `pet_coo_1`, happy `pet_coo_2`, sleepy `pet_coo_3`. One pitch per family so each pet has a voice from the same three files: Bear 1.00, Ovelle 0.92, Tikket 1.12, Nuum 0.84. The existing coo pose overlay plays unchanged | `CareFeedbackData.families` (add `cooPitch`), `BoardAudio` cues |
| **Walk cadence** | Stride grows with speed so the feet stop sliding at the cap: `stride = lerp(1.5, 3.2, clamp((speed - 3) / 6, 0, 1)) x scale`. Cadence stays 2.4 to 2.9 cycles a second from stroll to catch-up (today it hits the 3 per second cap at walk speed) | `PetFollow` (both gait blocks) |
| **Walk bob** | Two bounces per cycle, one per footfall: `movementBob = 0.05 x (1 - cos(2 x phase)) / 2 x gaitWeight` (Ovelle 0.042). Today's single 0.065 bounce per cycle is out of step with the feet | `PetFollow` lines 73 and 114 |
| **Walk body** | Lean 4 degrees into travel x gaitWeight. Head nods 2 degrees a quarter cycle behind the bob. Ears and tail trail by 0.08 s. On stopping: a 0.12 s settle squash (the boop squash at half strength). Above 7 studs a second: ears back 10 degrees, bob x 1.5 (a scamper) | `GardenPetVisual` lines 279 to 300 |
| **Reduced Effects** | All new motion rests at zero under `reducedEffects`, as the existing beats do. Sit becomes an instant lowered pose | all of the above |

### B3. The sit, in rig terms

A relative overlay like `PetCooPose` (no root motion, no sound of its own), sampled in `GardenPetVisual.update`.

- **Body:** lowers 0.22 x scale onto the ground (the `careBodyLower` lever) and pitches back 6 degrees about the Body anchor. A 0.15 s landing squash (the boop squash) on arrival.
- **Feet:** released from foot planting (as Docked does in `PetPoseSampler.plant`), pushed forward 0.16 x scale, toes up 20 degrees and splayed 15 degrees outward, soles showing.
- **Hands:** fold 0.35, resting forward on the tummy between the feet.
- **Head:** up 5 degrees toward the owner, tilted 8 degrees to a side seeded per pet, with look-at-owner still active.
- **Ears, tail:** ears perk 6 degrees; tail sweeps slowly at 0.6 Hz behind the body.
- **Face:** `content`, a slow blink every 2 to 3 s.
- **Timing:** in 0.35 s, hold 6 to 14 s, out 0.3 s with a small hop (the greet hop at 40%).
- **Triggers:** the `sit` idle beat; the owner standing still within 8 studs for 6 s (the pet sits facing them); `settle`, `nookRest` and any `rest` of 4 s or more. The last three are derived from replicated actions, so every player sees the same pet sit.
- **Escalation:** 20 s into a sit with nothing happening, the pet goes `dozy`, then sleepy, and nods.

---

## C. Declutter and sprite flowers

Mockups: `02-hub-before.png`, `03-hub-after-declutter-flowers.png`, `05-hub-before-after-compare.png`, `09-declutter-plan-map.png`.

### C1. Why the hub reads as cluttered

Within 25 studs of the plaza there are 12 white marble objects that are not stations, on a white marble floor, next to three white marble stations. Two of them are **egg statues on pedestals**, which a new player reads as the place to hatch eggs. A column and an urn stand 5 to 8 studs from the Pocket Deck kiosk; two broken columns and a fallen drum stand 5 to 8 studs behind the Care cradle.

### C2. Remove these 12 objects

The island in Studio is merged per material (`W7_Architecture__marble`, `__marble_smooth`, `__palette`, `__trim`; `W7_Stations__marble`), so no prop can be deleted at runtime. The names below are the objects in `artifacts/world1-mockup/v7/build_world_v7.py` / `world1-mockup-v7.blend`. Positions are Roblox X, Z.

| # | Object | What | X, Z | Why |
|---|---|---|---|---|
| 1 | `Plaza_Ornament_09` | egg statue | -42, 9.5 | reads as a hatch spot |
| 2 | `Plaza_Ornament_10` | egg statue | -18, 9.5 | reads as a hatch spot |
| 3 | `Plaza_Ornament_11` | urn | -46.5, -17 | 8 studs from the deck kiosk |
| 4 | `Plaza_Ornament_12` | urn | -13.5, 5 | crowds the east bench and the cradle approach |
| 5 | `Stairs_Urn_18` | urn | -41.4, 16.4 | foreground clutter from the toy lawn |
| 6 | `Stairs_Urn_19` | urn | -31.9, 23.8 | on the rim of the toy lawn (pets play here) |
| 7 | `Colonnade_Column_01` and its lintel span | column | -52.1, -10.3 | 6 studs from the kiosk; the kiosk posts vanish against it |
| 8 | `Colonnade_Column_06` | broken column | -12.9, -19.4 | behind the cradle |
| 9 | `Colonnade_Column_07` | broken column | -8.7, -12.6 | beside the cradle |
| 10 | `Colonnade_FallenDrum_08` | fallen drum | -10.5, -18.2 | beside the cradle |
| 11 | `Pad_Future_A` | empty marble pad | -48, -22.1 | looks like a missing machine |
| 12 | `Pad_Future_B` | empty marble pad | -13, -3.9 | looks like a missing machine |

In the build script: drop angles 196, 318 and 338 from the colonnade tuple (line 613) so the entablature spans columns 02 to 05 only, delete the `Colonnade_FallenDrum` line, the four `Plaza_Ornament` entries (line 625), the `Stairs_Urn` loop (line 820) and the `Pad_Future` line.

**Keep:** columns 02 to 05 (they frame the Hatch Tree), both benches, the lantern, the egg nest's sign stele, the toy lawn set, the bridge urns and everything beyond 36 studs. The bridge, rotunda and Blossom Point keep their ruins and statues: marble belongs at landmarks, grass belongs between stations.

### C3. Retro sprite flowers

Five original flowers, drawn on a 32 x 32 grid: hard pixels, a darker selective outline, no gradients. Files in `artifacts/feel-alive-2026-11-13/sprites/`: `flower_<name>_64.png` (game resolution), `flower_<name>_256.png` (the same art scaled 8x with nearest-neighbour; upload this one so Roblox filtering keeps the pixels crisp) and `flower_atlas_320x64.png`.

| Sprite | Colours (world v7 palette) | Used |
|---|---|---|
| `daisy` | white #FFFFFF, yellow #FFD84A | everywhere, the filler |
| `tulip` | pink #FF6FAE | the Care cradle side |
| `bellflower` | lilac #A88BFF | shade, rim of the lawn |
| `buttercup` | yellow #FFD84A, cream | the egg nest side |
| `starbloom` | aqua #35C7F5 | the Pocket Deck side |

Stems #2FA83F, leaves #5FE89A. Flowers beside a station echo that station's attract hue, so the planting itself points at the machines.

- **How to draw them:** upright quads that turn to face the camera about the vertical axis (the classic sprite look). Recommended: one `Beam` per flower with `FaceCamera = true`, `Segments = 1`, two Attachments on one invisible anchored part per patch, `LightInfluence = 1`, `LightEmission = 0.15` (they dim at night but still read). The project already uses Beams for water. Beam textures run along the beam, so the upload may need a 90 degree turn: settle that in a 30 minute Studio spike. Fallback: a `BillboardGui` per flower (`Size` in studs, `LightInfluence = 1`, `MaxDistance = 90`), which is simpler but heavier per sprite. Do not use crossed 3D quads; they lose the flat look.
- **Size:** 1.05 to 1.55 studs tall, bottom edge on the ground. Shorter than a pet, so a pet is never hidden.
- **Density:** hub ring (17 to 36 studs from the plaza centre): 22 patches of 5 to 9 sprites, 112 sprites, as mocked. A patch replaces each removed prop; two patches flank each station approach. Minimum 0.85 studs between sprites. None within 4.9 studs of a station, on paths, the plaza, the toy lawn or a rest dais.
- **Island:** replace the 32 existing 3D flower clusters (`Flowers_A`, `Flowers_B`, 55 triangles each) with sprite patches of 3 to 5. That removes 1,760 triangles and gives the island one flower look. See open question 2.
- **Budget for phones:** at most 260 sprites on the island and 160 drawn at once: 320 triangles, five 256 px textures, no per-frame script. Cull whole patches beyond 90 studs on phones, 140 on desktop (4 Hz check in `WorldMotion`). Optional sway: only the 40 nearest sprites, top attachment 0.06 studs at 15 Hz, off under Reduced Motion.
- **Build them on the client** from a patch table (position, radius, count, kinds, seed) so nothing replicates. Ground height from `HollowWorldLayout.groundY`.

---

## D. Station attract

Mockups: `04-hub-after-attract-beacons.png` (all three from across the plaza), `06-attract-deck.png`, `07-attract-eggs.png`, `08-attract-care.png` (each shows the three states).

### D1. One kit, three hues

| Station | Prompt today | Hue | Light | Icon (`sprites/attract_icon_*_128.png`) | Ping pitch |
|---|---|---|---|---|---|
| Pocket Deck kiosk (`Stations.Customize`, -46, -9) | "Style deck" | aqua #35C7F5 | #B8ECFF | handheld | 1.00 |
| Egg nest (`Stations.Eggs`, -31, -11) | "Browse eggs" | gold #FFC83C | #FFEEAA | cracked egg | 1.12 |
| Care cradle (`Stations.Journal`, -17, -15) | "Open companions" | pink #FF6FAE | #FFC9DC | heart | 0.89 |

Pink is chosen for the cradle so it never fights the existing dock status colours (free warm #FFD889, occupied aqua #62DEDC in `LoungeWorldV7Art.CareStatus`).

### D2. States

| State | When | What shows |
|---|---|---|
| **Learned** | used today, or far away | The station's own idle animation and a glow breath: plus or minus 8% on a 3.2 s cycle. No icon, no ring, no sound |
| **Beckon** | within 40 studs, not used today (or first visit) | Glow breath at plus or minus 20%. A soft light shaft 12 studs tall (a `FaceCamera` Beam, 75% to 100% transparent). A ring on the ground at radius 4.7. The icon, 1.8 studs wide, floating above the station and bobbing 0.25 studs on a 1.6 s cycle |
| **Invite** | within 14 studs, not used today | Adds: a chevron under the icon that hops twice (0.5 s each) then rests 1 s; a ripple leaving the ring every 2.4 s; a few sparkles; one `machine_attract` ping on entering range |
| Prompt | within 7 studs | The existing ProximityPrompt, unchanged |

- **Icon height:** deck and cradle 9.4 to 9.6 studs above the base (above the roof and arch), egg nest 5.6 studs. Icons are `BillboardGui`, 1.8 studs, `MaxDistance` 60, never `AlwaysOnTop`.
- **Sound limits:** one ping per station per 45 s, one ping of any kind per 20 s, none within 10 s of joining.
- **At night:** pulse the station's existing PointLight (`KioskLight`, `EggNestLight`, `CradleLight`) by the same percentage. Do not raise their base brightness; the QA pass on 2026-11-12 already dimmed them 40%.
- **Hidden when:** Board mode, any overlay or menu, the hatch reveal, the cradle while a pet is docked there, and for 2 s after a prompt is used.
- **Reduced Motion:** icon and ring shown still; no bob, hop, ripple or sparkles.

### D3. Idle animation per station

| Station | Always-on idle | Needs |
|---|---|---|
| Pocket Deck kiosk | Arcade attract mode on the sign screen: a 3-frame pixel loop at 2 frames a second (an egg drops, lands, "PLAY" blinks), on a `SurfaceGui` over the screen. The two hanging hex tags sway 4 degrees | a SurfaceGui anchor; tags split out as `sway` parts in the world re-merge |
| Egg nest | The egg rocks 4 degrees twice, then rests 3 to 5 s (random). `W7_NestHalo__glow_warm` already pulses: raise its amplitude from 0.35 to 0.5 in Beckon. Gold sparkles rise at 2 a second in Invite. `egg_wobble` (existing placeholder) at volume 0.2 within 14 studs, at most every 8 s | `Station_EggNest_Egg` split out as its own part with a new `wobble` motion kind in `WorldMotion` |
| Care cradle | `W7_CradleMobile` already turns: speed it up 1.5x in Beckon. A small heart drifts up from the cushion every 1.5 s in Invite. All of it off while the bay is occupied | particle emitter on `JournalTop` |

Until the world re-merge lands, the egg and the tags stay still; glow, shaft, ring, icon and ping work without it.

### D4. Staying subtle once learned

- "Used today" is tracked per station. First step: session memory on the client (each station beckons once per visit until used). Later: three bits in the `coachMask` save field that the onboarding scope already adds, so a station stops beckoning for good after 3 uses. See open question 4.
- The icon then returns only as **news**, never as a nag: the egg icon when a hatch is affordable or pending (`LoungeStations.hasPending`); the deck icon when the daily quests have rolled over; the heart when the pet's daily care is unused. In that case it shows Beckon only: no chevron, no ping.
- The glow breath (plus or minus 8%) and the idle animation stay forever. That is the "alive" part.

---

## E. Build order

Sizes: S under half a day, M about a day, L several days with Studio and upload work.

| # | Slice | Size | Files |
|---|---|---|---|
| 1 | Upload the 12 placeholder cues; add them to `BoardAudio` (`cues`, `placeholderIds`) and write `assetId` into `manifest.json` | S | `BoardAudio.lua`, `assets/audio/placeholder/manifest.json` |
| 2 | `GardenAmbience.lua`: Ambience group, brook bed with the stream curve, two falls emitters, Board-mode duck, Ambience setting. Spec the curve as a pure function | M | new `GardenAmbience.lua`, `LoungeWorldV7Art.lua` (emitter parts), `DeckSettings.lua` |
| 3 | Bird scheduler and perch export | S | `GardenAmbience.lua`, `build_world_v7_assets.py`, `WorldV7Data.lua` |
| 4 | Coo retune: interval, volume, mood cues, per-family pitch, triggered coos | S | `PetCooScheduler.lua`, `CareFeedbackData.lua`, `RoomView.lua` |
| 5 | Idle retune: beat timing and weights, new look, stretch, yawn and wiggle poses, face mapping, new faces, look-at-owner, beats on nearby visitors | M | `PetIdleBeats.lua`, `PetIdleMotion.lua`, `PetExpression.lua`, `GardenActivity.lua`, `GardenPetVisual.lua`, `RoomView.lua` |
| 6 | Sit pose and its triggers | M | new `PetSitPose.lua`, `GardenPetVisual.lua`, `PetPoseSampler.lua` |
| 7 | Walk retune: stride, two-bounce bob, lean, settle, scamper | S | `PetFollow.lua`, `GardenPetVisual.lua` |
| 8 | Station attract: state machine, glow, shaft, ring, icon, chevron, ping, three icon uploads | M | new `StationAttract.lua`, `LoungeWorldV7Art.lua`, `LoungeStations.lua` |
| 9 | World re-merge in Blender: remove the 12 objects, shorten the entablature, split the nest egg and kiosk tags as animated parts, export perches; rebuild chunks, assets and collision; re-upload the changed meshes; Studio check and `WorldRoutes` spec | L | `build_world_v7.py`, `build_world_v7_chunks.py`, `build_world_v7_assets.py`, `WorldV7Data.lua`, `WorldMotion.lua` |
| 10 | Sprite flowers: Studio spike (Beam or BillboardGui), five uploads, client patch builder, culling | M | new `GardenFlowers.lua`, `WorldMotion.lua` |

Order by "alive per hour": 1, 2, 3 (sound changes the whole garden with no art risk), then 4 to 7 (pets), then 8, then 9 and 10 together (flowers go where props came out). Slices 2, 5, 6 and 8 touch more than one unit and should go through review-driven-build.

Two hazards for the coordinator:
- `scripts/build_placeholder_audio.py` rewrites `manifest.json` from scratch, which would drop the ambient entries and every `assetId`. Run `build_ambient_placeholder_audio.py` after it, or teach the main script to merge.
- `assets/art-source/environment/environment.blend` was already modified in the working tree before this pass. The mockups used `world1-mockup-v7.blend`, opened with `--factory-startup` and never saved.

## Open questions for Spencer

1. **How deep should the declutter go?** Recommended: all 12, including colonnade column 01 and the three ruin pieces by the cradle (see `05-hub-before-after-compare.png`). The lighter option keeps the colonnade and ruins and removes only the urns, egg statues and empty pads (8 objects).
2. **Sprite flowers everywhere, or only around the hub?** Recommended: everywhere, replacing the 32 3D flower clusters, so the island has one flower look and saves 1,760 triangles.
3. **During a deck round, keep the brook at 35% under the deck music, or go silent?** Recommended: keep it at 35%; birds, falls and coos stop.
4. **Should a station remember that you have learned it?** Recommended: session memory now (each station beckons once per visit until used), then three saved bits in `coachMask` when onboarding lands, with the icon returning only for news (an egg you can afford, fresh quests, unused daily care).
