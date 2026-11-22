# Alive brief (Fable, 2026-11-22)

**Scoping only. Nothing here is built or approved.** Spencer: "just scope them, see assets we could bring in, etc. everything needs to feel alive but not break". This turns `V3-SCOPE-2026-11-21.md` sections 10, 11 and 12 into one ranked list with numbers.

What this is based on: the code (`WorldMotion`, `HollowAmbience`, `AmbientAudio`, `StationAttract`, `DeckKit`), the scope doc, and stills (`artifacts/store-listing/ad-v1/raw/garden-island-wide.jpg`, `artifacts/v2-bunny-wiring/04-garden-undyed.jpg`, `artifacts/bright-previews-2026-11-22/companions-new.jpg`). **Nothing was run in Studio and no motion was watched.** Every number below is a starting value to tune on a phone, not a measured result. The outside kits and the two Creator Store sounds were not opened or listened to in this pass.

What the stills show: every tree crown is one chunky still blob, the grass is a flat green sheet, and nothing in a frame says there is wind. The menus look finished (Toy Shell, ink outline) but a still can't show that they arrive in .16 s and leave in none.

Already shipped from `FEEL-ALIVE-DIRECTION-2026-11-13.md` (found in `src/client`): brook bed, two falls and bird chirps from 34 perches (`AmbientAudio`, `AmbientPerches`); pet sit, look-at-owner and idle beats (`PetSitPose`, `PetLookAt`, `PetIdleBeats`); station markers (`StationAttract`); flowers, but as flat ground decals (`WorldDressingClient`), not the upright sprites that were specified. So pets and stations are in good shape. The gaps are: menus have no spring, plants don't move, birds are heard and never seen, and nothing ties the moving things together.

> **Superseded where it disagrees with `ALIVE-SAFETY-2026-11-22.md`** (see `V3-SCOPE-2026-11-21.md` 12.8): A1 is a springy rise, not a scale; A2 is a ghost plate; A4 pops the art on a card, not the card. Tree count is unsettled (32 by placements, 34 perches).

## 1. The feeling

When I open a menu it goes *boing* like jelly and the cards hop in one by one. When I press a button it squishes. Outside, the wind comes across the garden and I can see it coming: the trees wobble, then the bushes, then the flags, and pink petals blow past me and the chimes go ting. A little bird is sitting on a branch and it flies away when I run at it. My pet watches a butterfly. Nothing is jumping at me and nothing is flashing. It feels like the garden is breathing, even when it's only me.

## 2. Alive moments, ranked

Springs are given as frequency (Hz) and damping ratio (1 = no overshoot, lower = bouncier). Sizes: S under half a day, M about a day, L several days. "Calm" always includes: Reduced Motion jumps to the end pose, and input is live on frame one.

### A. Menus and UI

| # | | What you see | Where | Numbers | How it stays calm | Asset | Cost |
|---|---|---|---|---|---|---|---|
| A1 | MUST | A panel pops open and settles | Every hub, shop, sheet (`CompanionsHub`, `MachineHub`, `StoreView`) | Scale .88 to 1, spring 4 Hz, damping .5, peak about 1.02, settled by .35 s; shade fades in .16 s | Once per open. Specs get an instant-settle switch (12.7) | none | M (builds `Kit.spring`) |
| A2 | MUST | A panel leaves, it doesn't vanish | Same | Scale 1 to .94 and fade, .12 s, Quad in. No spring | Shorter than the open so Back never feels slow | none | S |
| A3 | MUST | A button squashes and springs back | Every `Kit` button | Down: 1.06 wide, .90 tall in .05 s. Up: spring 6 Hz, damping .45, peak about 1.05 | Scale an inner frame, so neighbours and the 44 px target never move. Label never scales past 1.05 | none | S |
| A4 | MUST | Cards hop in one after another | Hub tiles, shop grids | Each rises 10 px and scales .94 to 1, spring 5 Hz, damping .6; 25 ms apart, first 8 only, all done by .35 s | The rest appear at once. Taps and focus work on a card that hasn't landed. Never replays on scroll | none | S |
| A5 | MUST | The thing you pick goes boing | Tiles, swatches, tabs (`Kit.boing`) | .94 to 1, spring 5 Hz, damping .45, peak 1.06 (today 4% in .16 s) | Only on change of selection. Never on text being read | none | S |
| A6 | MUST | The wallet star hops when you earn | `WalletStar` | 8 px up, spring 5 Hz, damping .4; count rolls in .45 s | Gains within .3 s share one hop | none | S |
| A7 | SHOULD | The page sticker wobbles once | Header chip ("Companions") | Plus or minus 5 degrees, 3 Hz, damping .3, still by .6 s | Once per page open | none | S |
| A8 | SHOULD | A card lifts under the mouse | Desktop only | Up 2 px, icon tips 6 degrees and back, .25 s | Off on touch. No loop while hovering | none | S |
| A9 | COULD | The tab pill overshoots | Tab rows | 4 px past, spring 6 Hz, damping .55 | | none | S |

One dial, `Kit.Motion.bounce` (0 = today, 1 = this table, up to 1.5), scales every overshoot so Spencer can say "more" or "less" once.

### B. Garden world

| # | | What you see | Where | Numbers | How it stays calm | Asset | Cost |
|---|---|---|---|---|---|---|---|
| B1 | MUST | One wind that everything follows | Whole island | Section 3 | Section 3 | none | M |
| B2 | MUST | Bushes shiver as the gust passes | The 44 bushes (already separate parts) | Rest 1.5 degrees, gust peak 6, own period 1.8 to 2.4 s | Nearest 16 only on phones; 30 Hz; within 120 studs | none | S |
| B3 | MUST | Pennants, flags and chimes pick up in a gust | Existing `WorldMotion` movers | Pennant amp x1.8 at peak; chime sway x2.5 | Same parts as today, no new ones | none | S |
| B4 | MUST | Pink petals blow off the blossom trees | The pink crowns nearest you | 0 a second at rest, 3 a second at gust peak, life 5 s, drift 6 studs a second downwind, slow tumble | 3 emitters live, 24 petals at most, none nearer than 6 studs to the camera | make our own: one 64 px petal, one leaf (script-drawn, like the flower sprites) | S |
| B5 | MUST | Tree crowns sway | 34 trees and the Hatch Tree | Rest 1.2 degrees, gust peak 4, lean 1.5 degrees downwind at peak, own period 3.4 to 4.6 s, pivot at the trunk top | About 24 crown parts (clump twos and threes); trunks and collision never move; draw calls and triangles measured before and after | make in our Blender: re-export of the crowns we already have, split, not new art | L |
| B6 | SHOULD | A bush rustles when you brush it | Bushes within 3 studs of you or your pet | 8 degree kick, spring 2.5 Hz, damping .3, still by 1.2 s | Once per bush per 4 s; your own avatar and pet only | none | S |
| B7 | SHOULD | Slow soap bubbles drift by | Around the camera, by day | 1 every 3 s, 8 alive at most, life 9 s, rise .4 and drift 1.5 studs a second downwind, .5 to 1.1 studs wide | Never over a station or a prompt; off in menus | make our own: one 128 px bubble (ring, highlight, faint rainbow edge) | S |
| B8 | COULD | Ripple rings on the stream | Stream bank near you | One ring every 2.5 s, grows to 3 studs in 1.6 s and fades | Raise the `HollowAmbience` active cap from 3 to 6, no higher | none (authored parts exist) | S |

### C. Pets and creatures

| # | | What you see | Where | Numbers | How it stays calm | Asset | Cost |
|---|---|---|---|---|---|---|---|
| C1 | MUST | The bird you hear is sitting there | The perch `AmbientAudio` just picked | Lands in .8 s, hops and tail-flicks on each chirp, stays 8 to 20 s; flies off in a 1.2 s arc if you come within 12 studs | 3 birds at most (the 3 voices that exist); none in a deck round; never lands on a station | make in our Blender: one round bird, about 120 triangles, body and two wings, 3 palette colours | M |
| C2 | SHOULD | Your pet watches things | Garden | Head follows a bird, butterfly or bubble within 15 studs for 1.5 s (`PetLookAt` exists) | At most once per 20 s; the owner always wins | none | S |
| C3 | SHOULD | Butterflies over the flowers | Flower patches, by day | Wings 9 Hz, wander 3 studs around a patch at .8 studs a second, rest 2 to 4 s on a flower | 4 at most, within 60 studs, never crossing the screen centre in a menu | make in our Blender: two quads and a body, about 12 triangles, 4 wing colours from the hue jars | S |
| C4 | SHOULD | Ears and charm trail in a gust | Your pet | Ears back 6 degrees, one blink at gust arrival | Only standing or sitting pets; one blink per gust | none | S |
| C5 | COULD | Garden pals stroll, nap and greet | Paths, benches, swings | 3 at most alone, 0 once 4 real pets are present; leaf tag; never named like players | Shares the Dash pals code (section 4.5), so wait for it | none (recoloured Bear and Bunny) | L |
| C6 | COULD | Fish shadows in the stream | Stream | 3 at most, 1.2 studs a second, dart away within 5 studs | Shadow shapes only, no model | make our own: one 64 px shadow | M |

### D. Sound

All levels sit under the brook bed and the menu tick. Spencer has turned the falls down three times ("wind too loud", 2026-11-21), so start quiet.

| # | | What you hear | Where | Numbers | How it stays calm | Asset | Cost |
|---|---|---|---|---|---|---|---|
| D1 | MUST | Leaves rustle as the gust reaches you | 2D, follows the wind at the listener | Volume 0 at rest to .10 at peak, .8 s in, 2.7 s out | Never louder than the bed (.22); ducked with ambience; follows the Ambience setting | synthesise (filtered noise) | S |
| D2 | MUST | A soft "bloop" up on open, down on close | Panels (A1, A2) | 90 ms, up a fifth on open, down on close, volume .25 | None on card stagger, none on hover | synthesise | S |
| D3 | SHOULD | Chimes ting when the gust reaches them | 3D at the arch chimes | 2 or 3 notes from a 5-note scale, volume .2, heard within 30 studs | One phrase per 12 s; none in a deck round | synthesise | S |
| D4 | SHOULD | Wing flutter when a bird leaves | 3D at the perch (C1) | .3 s, volume .2 | Rides the bird cap of 3 | synthesise | S |
| D5 | COULD | Bubble pop | When your pet or you touch a bubble (B7) | 60 ms, pitch 1.0 to 1.3 at random, volume .18 | One per second at most | synthesise | S |

Count: 28 rows. 14 MUST, 9 SHOULD, 5 COULD. The COULDs can all be dropped without losing the feeling.

## 3. The gust system

One module, `Wind`, client only. Everything asks it one question: "how windy is it here, now?"

- **`Wind.at(position, time)` returns 0 to 1.** No instances, no network. Time is `workspace:GetServerTimeNow()` and gust number N is seeded from N, so every player sees the same gust cross the garden without a single remote.
- **Direction:** fixed, west to east, 20 degrees toward south, so gusts run from the hub out toward Tumble Falls. One direction is easier to read than a turning wind.
- **Breeze:** always .2, with a slow 11 s rise and fall of plus or minus .05. The garden never stands fully still.
- **Gust:** a front 50 studs deep that travels at 14 studs a second. At any one spot it rises in .8 s and fades over 2.7 s. From the hub you watch it arrive: far trees first, you about 3 s later.
- **Period:** a new gust every 9 to 16 s. About 3 in 10 are skipped, so there are real lulls of up to half a minute. Peak strength varies .6 to 1.
- **Followers** (each keeps its own small period and phase; the wind only scales it):

| Follower | At rest | At gust peak | Extra |
|---|---|---|---|
| Tree crowns | 1.2 degrees | 4 degrees | leans 1.5 degrees downwind |
| Bushes | 1.5 | 6 | |
| Hero flowers (Alive 3) | 2 | 8 | flat decal patches stay still |
| Pennants and flags | today's amp | x1.8 | |
| Chimes | today's amp | x2.5 | D3 fires as the front arrives |
| Petals and leaves | 0 a second | 3 a second | drift speed follows the wind |
| Bubbles and motes | 1.5 studs a second | 3 | |
| Rustle | 0 | .10 | sampled at the listener |
| Pet ears | 0 | 6 degrees back | |

- **Caps:** `WorldMotion` stays at 30 Hz and one `BulkMoveTo`. Phones: sway within 120 studs, at most 60 swaying parts; desktop 200 studs. Followers out of range hold their rest pose, they don't pop.
- **Reduced Motion:** wind reads 0 for anything that moves. Sound still follows the gust schedule (Reduced Motion does not change audio, per the 11-13 direction).
- **Off when:** deck round, hatch reveal. Menus leave it running behind the shade.
- **One dial:** `Wind.Strength` (0 to 1.5) scales every row above.

## 4. Assets: make versus bring in

**My verdict: make all of it ourselves.** The list is small and almost none of it is new modelling.

| Need | Source | Why |
|---|---|---|
| Crown parts for 35 trees | Our `.blend`, re-exported split | They exist already; this is an export change |
| Bird, butterfly | Our Blender, new | About 130 triangles together. They must look like cousins of the Bear and Bunny (round, big eye dot), which no kit bird does |
| Petal, leaf, bubble, fish shadow | Script-drawn textures | Four small images, same route as the flower sprites |
| Rustle, bloops, chime, flutter, pop | Our synth script (`build_ambient_placeholder_audio.py` route) | Seven short cues; matches the voice of the cues we already ship |

**Candidates, one by one:**

| Candidate | Licence | Use it? |
|---|---|---|
| Quaternius Ultimate Animated Animals | CC0 | **No.** Realistic-proportioned rigs would look foreign next to round baby pets, and they'd need re-rigging for Roblox. Fine to look at for how a bird's hop is timed |
| Quaternius Ultimate Nature, Stylized Nature MegaKit | CC0 | **No for now.** We don't need new trees, we need ours to move. Only worth a look if Spencer wants new plant kinds for the Aero pass (reeds, lily pads, big-leaf plants) |
| Kenney Nature Kit | CC0 | **No.** Among the most recognisable asset looks there is; it would make the garden look like other games |
| Kenney Particle Pack | CC0 | **No.** We need four textures; drawing them keeps the petals and bubbles in our line weight |
| Kenney Interface Sounds, UI Audio | CC0 | **Fallback only.** If our synthesised bloops sound thin by ear, pick two and re-pitch them. Lowest risk of all the outside options, since nobody recognises a 90 ms click |
| ProSoundEffects leaf rustle loops (9116258071, 9116258282) | Roblox Creator Store licence, not CC0 | **Audition against ours.** A recorded rustle may simply sound better than filtered noise. It is a real recording, not AI, but it is not ours and only usable inside Roblox |

**Flag for Spencer (this needs an explicit yes or no):** sections 10.3 and 11.3 say "original art only". CC0 is legally clean, but it is not original, so I read the rule as ruling out every mesh and texture above. Two questions:
1. **Does "original art only" also cover sound?** If not, the Kenney UI sounds and the ProSoundEffects rustle are allowed as a fallback.
2. **Would you ever accept a restyled CC0 mesh for background plants?** My advice is no for anything a player looks at closely, and "only under the rule below" for far scenery.

**Restyle rule, if any outside mesh is ever allowed:**
- It goes through our Blender file; nothing is imported straight into Studio.
- Triangles: creature 150 or fewer, plant 300 or fewer, tree crown clump 600 or fewer.
- Kit textures and materials are stripped. It takes our v7 world materials and colours only from the v7 palette plus the Aero set (section 11).
- At least half the silhouette is reshaped toward our rounder, chunkier forms, then it is judged in a real garden capture beside the Bear and the Bunny. If you can pick it out as "the kit one", it goes.
- Never for pets, residents, stations, icons or anything in a thumbnail.
- Listed with its source and licence in the repo.

## 5. Too much: what stays still

- **Text you are reading.** Labels, prices, descriptions, numbers after they land.
- **Menus at rest.** Nothing loops in an open menu except the preview pet breathing. No pulsing buttons, no shimmering cards, no bouncing "buy".
- **Anything that sells.** Stars prices and product cards get the same press squash as every other button and nothing more.
- **The ground you walk on.** Paths, marble, bridges, benches, rocks, trunks, stations' bodies. If collision is on it, it does not move.
- **The camera.** No sway, shake or drift from wind.
- **The whole screen at once.** A gust is a wave, not everything moving together; lulls matter as much as gusts.
- **The centre of the screen.** Bubbles, petals and butterflies keep clear of your pet, of prompts and of station markers.
- **Sound per thing.** No sound on card stagger, hover, petals or sway. One rustle, one chime phrase, three birds.
- **Counts.** 3 birds, 4 butterflies, 8 bubbles, 24 petals, 3 pals. These are caps, not targets.
- **Day and night.** Stays off (11.3); fireflies stay parked.
- **During a deck round or a hatch:** all of sections B to D rest.

## 6. Three sizes

**Alive 1 (one week, no world export, no mesh uploads):**
A1 to A6 (springy menus, `Kit.spring`, bounce dial), B1 wind module, B2 bushes, B3 pennants and chimes, B4 petals, D1 rustle, D2 bloops. Uploads: two small textures and three sounds. Risk: open animations breaking focus and click specs (12.7), so the instant-settle switch goes in first.

**Alive 2 (the trees and the first creatures):**
B5 crown split and re-export with before and after draw-call and triangle checks, C1 visible birds, C3 butterflies, B7 bubbles, B6 brush-past, C2 and C4 pet reactions, D3 chimes, D4 flutter, A7 and A8. This is the build that changes the store art audit, since the garden will look different in motion captures.

**Alive 3 (company and events):**
C5 garden pals (after the Dash pals exist), C6 fish, B8 ripples, D5 pop, A9, upright hero flowers that lean, and the "little events" from 10.2 (a drifting balloon, a ball your pet chases). Belongs with the Aero world pass in section 11.

## Open questions for Spencer

1. Does "original art only" cover sound too (section 4)?
2. Any restyled CC0 scenery ever, or never?
3. Alive 1 as scoped: go?
4. The screen recording of the reference game's menus is still wanted before the spring numbers are locked (12.1). Until then the numbers are our own taste.
