# Through the cave: a second garden, and room for more (Fable, 2026-11-23)

For Spencer, after option B of `ASMR-AND-SCALE-LOOK.md` section 3 (a west island by bridge): "can't we expand the
garden? not just redo the whole thing? like expand it thru the cave, add a new level? look at the chao garden
expansion mod for SA2 and make it somewhat like that?"

Yes. This **replaces option B** (the bridge and the west islet). Option A (camera, haze, far islets, sightline
breaks) carries on underneath. Nothing on the main island is redone. Direction only; Opus builds.

**What I read:** `CHAO-GARDEN-DIRECTION.md`, `ASMR-AND-SCALE-LOOK.md`, `WORLD-AND-NEST-LOOK.md` section 2,
`V3-SCOPE-2026-11-21.md` section 13, `artifacts/qa-2026-11-23-beta12/STUDIO-PROBES.md`, `HollowWorldLayout.lua`
(the v7 table), `WorldV7Data.lua` (parts, `perimeter`, `caveBlocker`, `fallCatch`, the `ground` height grid),
`LoungeWorldV7Art.lua` (header and the blocker), `IslandBounds.lua`, `IslandBoundsConfig.lua`,
`GardenPathPlanner.lua` line 73, `default.project.json`. **Nothing here has been seen in Studio or on a phone.**
Every `[check]` is for Opus or Spencer to settle.

**The one idea:** the cave at the back of the garden stops being a painted-on hole and becomes a **room with
doors**. One door opens today, onto a sunken garden hidden behind the mountain. The others are sealed and visibly
waiting. The world grows one door at a time and the home garden never changes.

---

## 1. What the mod teaches (principles, in my own words)

**What I could and could not read.** The Chao Island wiki pages for the mod returned 403 to me today. What I did
read: a long Steam thread by the mod's author describing its 6.x versions, search extracts of the wiki's 9.x page
and of the Chao modding docs, and a general article on the original feature. The structure of the original game's
pet area (a lobby with doors, extra gardens earned by how you raise a pet, a cave in the garden wall that leads to
the races, pets carried by hand) is from my own memory of it, not fetched today. Sources at the foot.

What I found: the mod grew in two directions. Outward: more gardens, grouped in themed lobbies (the 6.5 version
described eight lobbies of three gardens each, every lobby with its own look and its own save). And inward: the
later versions added more for pets to do inside each garden (zones to climb, flying without needing a cliff,
restored instruments, more toys and races). Nobody in what I read asked for a bigger lawn.

The principles I take from it:

1. **Add rooms, do not stretch the room.** Every garden is small enough to see across. The world feels large
   because there are several, not because any one is large. This is the same finding as option C: a rescale makes
   the same garden emptier.
2. **A small plain connector with every door visible.** The lobby is not a place to stay; it is where you see how
   many places there are. A closed door you can see is a promise, and it costs almost nothing to build.
3. **Each garden is a mood, not a feature list.** Same pets, same care, different light, ground, water and sound.
   The difference is felt in the first second, before the player has pressed anything.
4. **You cannot see one garden from another.** The transition is a short dark beat, then a reveal. That beat is
   what makes the next place feel far away, even if it is close.
5. **The first extra garden comes easily; later ones are earned by caring for pets,** not bought. Earning a door
   is a point of pride.
6. **Pets come with you, one at a time.** The pet you bring is the one you are paying attention to. The rest stay
   home and are fine. (In the original you carry it. Ours follows.)
7. **Each garden gives pets a few things to do that exist only there.** That is the reason to bring a pet, and the
   later versions of the mod show this is where the lasting interest was.
8. **Home stays home.** Arrival, the nest, the stations and the shop are in the first garden only. The others are
   for being in, not for doing chores in.
9. **The way in is part of the garden.** The original's race entrance is a cave mouth in the garden wall: a hole in
   the scenery that turns out to go somewhere. We already have the hole.

We copy none of its gardens, names, layouts, art or music. Ours is one cave, one room of doors, one new garden.

---

## 2. What we have at the cave today

- The world data already has an authored cave: `Landmarks.Cave` = (-7, -101), and an invisible `CaveBlocker` at
  **(-7.1, 11.5, -101.1), 20 wide x 17 high x 3 thick**, a wall across the mouth, facing south into the garden.
- Behind the blocker the ground grid shows a **flat floor at y 4 about 12 to 16 studs wide (x -14 to -2) running
  back about 20 studs (z -96 to about -116)**, with rock rising to y 20 to 30 on three sides. So there is a real
  roofed pocket behind the blocker today that nobody has stood in.
- The probes list covered ground at (-31.8, -109.4) r 17.6 and (9.1, -122.9) r 10.7, either side of that pocket.
  `[check]` in Studio, with the blocker off: stand in the pocket, capture it, and measure its true floor, roof
  height and back wall. Everything below assumes a pocket of about **14 x 20 studs, roof 8+ studs**.
- Behind the back wall the ridge is about 20 studs thick and 20 to 30 high. The perimeter ring passes behind it at
  about z -122. The ground grid stops at z -136. The floating drift rocks reach to about z -195.
- The mountain is on the north edge, so **anything placed north of it is hidden from every point of the home
  garden** by a 20 to 35 stud ridge. That is principle 4 for free.

---

## 3. Same place or a separate Roblox place: same place

**Recommendation: the new garden is in the same place, on the same server.** A short black beat inside the tunnel
moves you there. No Roblox teleport.

| | Same place (recommended) | Separate place, Roblox teleport |
|---|---|---|
| The wait | About 0.4 s of black inside a tunnel you are already walking through. | A real rejoin. On a phone that is several seconds to much longer, with the Roblox loading screen, never 1 to 2 s `[check]` on Spencer's phone if he wants a number. The cave moment is lost. |
| Friends | Everyone on the server can be in either garden and see each other. | A new server. Friends are split unless teleported as a group. |
| Pets | The pet beside you is moved with you in the same beat. | Rebuilt from the save on arrival. |
| Saves | Untouched. Nothing new is saved for the first build. | The save must be released by one server and picked up by the next every time you walk through a door. That is the riskiest thing we could do to the economy save. |
| Shipping | One publish, one translations sync, one set of switches. | Two places to publish, test and keep in step every build, on both the beta and live. |
| Phone memory | The new garden's meshes and textures are loaded as well as home's. This is the real cost. | Each place holds only its own garden. This is its one real advantage. |

So the only argument for a separate place is memory, and that is a thing to measure, not guess. The home island
is **115,900 triangles in 99 mesh parts**. Budget for the new garden: **at most 25,000 triangles and 6 new
textures**, reusing home's cliff rock and grass textures. `[check]` whether the place uses instance streaming; if
it does, the far garden streams out on its own and the black beat waits for the destination to be ready; if it
does not, Opus picks between leaving it loaded and showing each client only the garden it is in. Measure memory
on the phone at the greybox and again with art.

**When to revisit:** if a third garden puts the phone over budget, the gardens beyond the first two can move to a
separate place then. The room of doors works the same either way, so nothing built now is wasted.

**The door is a beat of black, not a carved tunnel.** I do not want the island mesh cut open: that is a Blender
re-export of the rock and its collision, a new walk map and a new edge sweep, for a few studs nobody sees in the
dark. Instead a short new tunnel piece is set against the pocket's back wall and goes dark; walking into it fades
to black, moves you, and you walk out of the matching tunnel on the far side. It reads as one tunnel. It also
means a garden can sit anywhere, which is what makes more doors cheap later.

---

## 4. The room of doors: "the Underway" (working name)

The existing pocket behind the blocker, dressed. It is the lobby. It is small and plain on purpose.

- **Size:** as found, about 14 wide x 20 deep, roof 8+ `[check]`. No new ground.
- **Three throats**, each **6 wide x 8 high**: one in the back (north) wall, one in the west wall, one in the east.
  - **North: open.** Leads to the new garden. Cool green-white light leaks from it.
  - **West and east: sealed** with dry-stacked stones up to head height and a dark gap above. A different colour
    of light leaks over each (warm amber from one, a deep blue from the other). No sign, no text, no timer, no
    price. They say "there is more" and nothing else. Build them as scenery only until a second garden is approved.
- **Floor:** packed earth and flat stones, worn smooth in a line from the mouth to the north throat.
- **Light:** no lamp. Daylight from the mouth falls about 8 studs in; beyond that the only light is what leaks
  from the throats. At night, two small glow-caps (section 5) by the north throat.
- **Outside, at the mouth:** nothing is added to point at it. One find spot placed just inside the mouth
  `[check]` clear of the blocker's old footprint, and the worn line on the floor, are the invitation.
- **The blocker** moves from the mouth to the back of the sealed throats. With the switch off it stays where it
  is today and the game is unchanged.

---

## 5. The new garden: "the Hush" (working name, kept from option B)

**What it is:** a sunken garden in a hollow of rock behind the mountain, open to the sky. A cavern whose roof fell
in long ago: high mossy walls all round, a still dark pool in the middle, ferns, three shafts of light. You enter
high on one wall and look down into it.

**Why this and not another lawn:** home is bright, open, marble and wide sky; you look out and across. The Hush is
the opposite on every axis: shaded, enclosed, rock and moss, and you look down and up. It is distinct in the first
second (principle 3). The walls also do three jobs: they hide the edge, so there is no rail and no drop to guard;
they make a small floor feel tall; and moss is why sounds here are close and soft, which is what the ASMR toys
need.

**Mood:** the quiet room of the house. Calm, cool, a little damp, never spooky. No station, no shop, nothing sold,
no prompts except the toys.

**Look** (Spencer's rule: surroundings textured, realistic and matte so the pets stand out):

- Rock: home's cliff rock texture, darker and wetter toward the floor. Matte. No gloss except the pool.
- Moss: deep, soft, real-looking, in three greens. Thick on the north-facing rock, thin on the south.
- Plants: ferns, low broad-leaf clumps, hanging roots from the lip. No flowers except one white-flowering shrub by
  the pool: the single bright thing, as home has its one blossoming landmark.
- Pool: dark and still, the sky disc reflected in it. No waterfall here (home has two). One slow drip line from a
  root into the pool, with rings.
- Palette: moss greens, wet slate, bark brown, the white shrub. Low saturation. The pets are the colour.
- Light: three fixed shafts from the sky disc, soft-edged, with slow dust in them. They follow the day cycle:
  warm at dawn and dusk, gone at night.
- Night: the moss edges and about 12 small **glow-caps** (low rounded lamp-plants, our own shape) give a dim
  blue-green light at ankle height. The pool reflects them. Pets keep their faint body glow from the home rule.
- Lighting is per player: a cool tint and slightly lower saturation while you are in the Hush, laid over the
  existing day and night grade `[check]` how a region grade combines with `WorldDawn` / `WorldDusk` / `WorldNight`.

**Size:** a bean-shaped floor about **150 x 110 studs**, walls **35 to 50** high, sky opening about 110 x 80.
About **+40% walkable ground** `[check]` against the real walk map. The longest walk in the world goes from about
290 studs to about **400** (arrival dais to the Quiet Shelf), with a tunnel in the middle of it.

**Where:** north of the mountain and lower. Proposed floor at **y -20**, centred about **(-7, -20, -275)**
`[check]` clear of the drift rocks (they reach about z -195), of any far islet of option A on the north bearing,
and inside the fall catch (it is). From the Quiet Shelf you look out north over open sky; you never see home.

### Layout sketch

Hush-local studs. Origin = the tunnel mouth on the entry ledge. **u** = east (+) / west (-), **v** = distance into
the garden (north). Floor is height 0; the entry ledge is +6.

```
                         v 132   ( open sky, far islets )
                    ..........====..........        ==== Quiet Shelf: gap in the wall, one bench
                 ...                        ...
               ..                              ..
   v 80      ..   Crunch      ~~~~~~~~~~~~        ..      Moss Beds
             .    + Pop      ~ Still Pool ~   o o o  .     (under the east overhang)
             .   [bench]      ~~~~~~~~~~~~           .
   v 50      ..      {clump}        . . .           ..
               ..            . . . .   Click Walk  ..
                 ...       . .                  ...
                    ....  ramp foot  .........
   v 14                 \\\\ ramp \\\\
   v 0               [==== the Sill ====]   <- you come out here, 6 studs up
                           | tunnel |
```

| Thing | Where (u, v) | Size | Notes |
|---|---|---|---|
| Tunnel | (0, -24) to (0, 0) | 6 wide, 8 high, 24 long | One bend of about 35 degrees at v -12, so you cannot see the exit from the dark. |
| **The Sill** (entry ledge) | u -8 to 8, v 0 to 10, height +6 | 16 x 10 | A low rock lip at the edge with an invisible wall above it. The whole garden is in view from here. |
| Ramp | from (8, 6) curving east and down to (30, 34) | 7 wide, about 32 long, drops 6 (about 11 degrees) | Worn stone. Pets walk it. |
| Floor | u -75 to 75, v 14 to 124 | bean shape | Moss, packed earth paths, flat stones. |
| **The Click Walk** (keycap path, 13.2 item 1) | from the ramp foot (30, 34) curving west to (-10, 62) | 24 keycaps, 2 abreast x 12 rows, each 3.2 square with 0.6 gaps: about 46 studs | Three patches of 4 rows: clicky, thocky, creamy. Stone-coloured caps with a soft icon each, no letters. It is the path, so everyone walks it once without being told. |
| **Still Pool** | centre (0, 78) | 44 x 26, 0.4 deep | A wet region. 5 stepping stones across the narrow part. The white shrub on its north bank. |
| Screen clump | (-24, 50) | 10 wide, 12+ high | Boulders and tall ferns. Hides the Crunch room from the Click Walk. |
| **Crunch Bed** (13.2 item 2) | (-45, 52) | 12 x 8 | Crisp fallen leaves in a hollow of rock. |
| **Pop Pad** (13.2 item 3) | (-56, 62) | 8 x 6 | A sheet of round water-blisters on a tilted slab. |
| Bench | (-48, 64) | | Faces the pool. |
| **Moss Beds** | (52, 80), under the east overhang | 3 cushions, each about 4 across | A light shaft lands here at midday. |
| **Quiet Shelf** | u 0 to 10, v 118 to 132 | 20-wide gap in the wall | One bench facing out over open sky. Nothing to do. A rail and an invisible wall. |
| Light shafts | on the Moss Beds, the pool's west end, the ramp foot | | Fixed beams. Mind the beam rule: width is on the secondary axis. |
| Find spots | 5, spread, one on the Quiet Shelf | | A reason to come for players who do not care about toys. |
| Glow-caps | about 12, in threes | | Night only. |
| Drip points | 4, under hanging roots | | See "what pets do" below. |

Three rooms, each hidden from the next: the Click Walk (east and middle), the Crunch room (west, behind the clump),
the Quiet Shelf (north, behind the shrub and the pool). The Moss Beds are a pocket off the pool.

### What pets do here that they cannot do at home

1. **Press the keys.** A pet following along the Click Walk presses the caps under its own feet, each with its own
   quieter, higher click.
2. **Crunch and pop.** Pets wade through the Crunch Bed (leaves fly, it grows back in about 20 s) and boop the Pop
   Pad with their nose.
3. **Moss naps.** A pet left idle near the Moss Beds walks over, kneads the cushion three times and curls up in
   the light shaft. A new rest spot on the existing rest behaviour, with a kneading lead-in `[check]` what the
   rest daises use.
4. **Catch a drip.** Under a drip point the pet looks up, waits, and catches a drop on its nose or tongue. This is
   the Dewdrop snack moment of `WORLD-AND-NEST-LOOK.md` section 7, re-dressed as a drip `[check]` it can run from
   a second list of spots.
5. **Wade.** The Still Pool is shallow all the way across, so small pets paddle through it with slow rings.
6. **Call in the tunnel.** Once per crossing, the pet stops in the tunnel, chirps, and hears itself come back.
7. **Glow prints (later).** At night a pet's feet leave soft glowing prints on the moss that fade in 4 s.

All of it is looks and sound only, per 13.3: no Stars, XP or odds for pressing anything. The reasons to come are
the toys, the finds, and that it is a good place to sit.

### Sound

- **No music in the Hush.** Home's music fades out in the Underway and comes back when you return. Silence is the
  point, and the ASMR sounds need it (13.3: close and quiet; the "dry, close, lean in" rule of the ASMR doc).
- Bed: a very low air tone, one drip into the pool every 3 to 6 s at random, leaf movement, a rare soft two-note
  call from high on the wall (synthesised, our own; never a recognisable real bird phrase). All through the
  existing ambience group and its voice caps. Quieter than home's bed: Spencer has asked for quieter world sound
  three times.
- Footsteps on moss are nearly silent, so the keycaps, leaves and pops are the loudest things in the garden.
- No AI audio. Synthesised by script or recorded by Spencer, as everywhere else.

---

## 6. The passage: mouth to reveal in about four seconds

At 16 studs a second. Every number is a starting point to tune on the phone.

| Beat | Where | What you see | What you hear | In the hand |
|---|---|---|---|---|
| 1. The mouth | Crossing the old blocker line | Daylight falls off over 8 studs. The screen exposure eases down by about 0.4. Leaf shadows stop. | Music fades out over 1.0 s. Wind drops. Your footsteps change from grass to packed earth. | |
| 2. The Underway | About 18 studs, 1.1 s | Three throats, three colours of leaking light. | One drip. Footsteps get a short, quiet slap-back (the only reverb in the game) `[check]` a baked echo on the step sound against a live reverb effect, on the phone. | |
| 3. The throat | The north throat, about 8 studs of new tunnel | Walls close in to 6 wide. Fade to black over 0.35 s as you walk. Controls are never taken away. | Steps only. | One soft tick as it goes fully dark, if vibration is on (ASMR doc section 0). |
| 4. The dark | At most 0.3 s held, longer only if the far side is not ready | Black. You and your pet are moved. | The pet's chirp and its echo (once per crossing). | |
| 5. The far tunnel | 24 studs, 1.5 s, one bend | Fade in over 0.5 s to a dark tunnel with green-white light on the wall of the bend. | Steps with slap-back. A drip ahead, getting closer. | |
| 6. The Sill | Stepping out | Exposure overshoots by about +0.4 (eyes adjusting) and settles over 1.5 s. The whole hollow is below you: pool, shafts, the white shrub. The camera does nothing on its own. | The slap-back stops dead. One soft low note swells and fades over 2 s (once per visit, not per crossing). Then the bed. | |

Rules: build, release, stillness, as in the ASMR doc. Reduced Motion: no exposure overshoot, a plain fade. The way
back is the same in reverse, and beat 6 at home is the music returning as you step into sunlight on the lawn.
First time only, the pet runs ahead to the edge of the Sill and looks down before you get there.

---

## 7. Rules of the house

- **Open or earned:** I recommend the Hush is **open from day 1**. It is the answer to "the world feels too
  small", so it should not be hidden behind a gate; it sells nothing; and a gate needs save data and UI. **The
  later doors are the earned ones** (principle 5), earned by caring for pets, never bought. Spencer's call.
- **Which pet comes:** the pet following you. It is moved with you in the black beat, so it never has to path
  through the tunnel. The others stay home. Leaving a pet to live in the Hush is a later question (it touches the
  save), not part of this.
- **Other players:** same server. Anyone can be in either garden. Server size stays 12.
- **The race and garden events** stay at home. `[check]` what a player in the Hush sees when a race is called, and
  that joining one brings them home cleanly.
- **Nothing sold, no stations, no nest** in the Hush or the Underway.
- **Behind a build flag and a remote switch**, beta place only, in the `IslandBounds` pattern (a ceiling plus a
  ConfigService key, off = the game as it is today, blocker in place).
- **Text:** any new strings (the garden's name on a find, a settings line) go through the translations steps
  before publish.

---

## 8. Room for more gardens

- The Underway has three throats. Garden 3 and garden 4 open the west and east ones. Each new garden is: a mood,
  a floor, two or three things pets can only do there, and a throat. Nothing at home changes.
- If a fifth is ever wanted, the Underway grows a second small chamber behind a throat; a door can lead to more
  doors.
- Each door's leaking light already says what is behind it, so the theme of the next garden is a decision that
  can wait until the Hush is judged. I am deliberately not designing gardens 3 and 4 here. Loose moods only, to
  show the range: something high, bright and windy (amber light), and something wet and deep (blue light).
- Every garden obeys the same budget (25k triangles, 6 new textures) and the same passage, so the cost of the
  next one is mostly art.
- TODO.md already lists "cave activity" and "additional garden spaces" as deferred; this is the frame for both.

---

## 9. Build order and cost

S = up to a day, M = 2 to 3 days, L = a week or so of slices. Art is the island session in Blender (no AI art);
I review real renders and phone captures of each.

| # | Slice | What | Size | Risk |
|---|---|---|---|---|
| **G0** | **Walkable greybox on the beta** | Flag and switch. Blocker opens. A trigger in the pocket's back wall, the 0.4 s black, the move. Far side: a plain tunnel box, a flat 150 x 110 slab at y -20, box walls 40 high, the Sill and ramp as wedges, three grey clumps, the gap for the Quiet Shelf. Player only: the pet waits in the Underway. Teach `IslandBoundsHost` the second region first, or its safe-spot return will pull the player home (it treats anything outside the ring as off the island). | **S** (about a day) | Low |
| | **Spencer walks it.** Is this the "bigger" he means? Is the size right? Phone memory measured. | | |
| G1 | Two regions in code | `HollowWorldLayout` gains a list of gardens, each with its own floor rectangle, walk map and safe ground. `GardenPathPlanner` clamps to the garden its pet is in (today one rectangle, line 73). Bounds, fall return, camera clamps. The sweep script runs per garden. | M | **The riskiest slice.** Still less than option B's: there is no bridge for pets to path across, because the move carries them. |
| G2 | Pets in the Hush | The following pet is moved with its owner, follows, and returns. Race and event call-back from the Hush. | M | Medium |
| G3 | The passage | The throat tunnel pieces (both ends), the Underway dressed, sealed throats, fades, exposure, the tunnel sounds, the swell, the tick. | S to M + small art + sound | Low |
| G4 | The Hush shell | Walls, floor, Sill, ramp, pool, Quiet Shelf. Collision and walk map. Region lighting. | L, art-led | Medium (phone memory) |
| G5 | The Hush dressed | Moss, ferns, roots, the shrub, shafts, glow-caps, bench, night look, the sound bed. | M, art-led | Low |
| G6 | The ASMR toys | V3 section 13 slices A (Spencer hears candidates), then the Click Walk, Crunch Bed and Pop Pad placed here. Already scoped there; this only gives them their home. | as section 13 | As section 13 |
| G7 | Pet life | Moss naps, drips, wading, the tunnel call, 5 find spots. Glow prints last. | M | Low |

G0 can go on the beta at once. G1 to G3 can ship on the greybox before any art exists, so the passage and the pet
behaviour are proven while the island session models. In all: about **8 slices**, against 5 to 7 for the bridge.
It costs a little more than option B and buys the room of doors, with the riskiest piece of B removed.

Per the standing rules: each slice that lands on the beta gets its row in `V3-TEST-PASS.md` (what to try, its
switch) and its line in `TODO.md`.

---

## 10. Decisions for Spencer

1. **Yes to the cave** in place of the bridge and west islet, starting with the one-day greybox on the beta?
2. **Same place, with a beat of black in the tunnel** (my recommendation), or does he want a truly separate place
   despite the wait and the save risk?
3. **The mood:** a sunken mossy hollow with a still pool, quiet, no music. Or does he have another in mind for the
   first door?
4. **Size:** about 150 x 110 (two-thirds of home's footprint). He can say bigger or smaller after walking G0.
5. **Open from day 1** (my recommendation), or earned? If earned, by what?
6. **Names:** "the Hush" and "the Underway" are working names.
7. **Sealed doors now:** show the two sealed throats from the first build (a promise of more), or keep the pocket
   to one door until a second garden is approved?
8. **No music in the Hush:** agreed, or a very sparse night-garden piece under it?

## 11. Captures and checks I want back

- The pocket with the blocker off: from the mouth looking in, and from the back looking out. True measurements.
- G0: the view from the Sill; the view back up at the Sill from the pool; the Quiet Shelf looking out; from the
  home lawn looking north (the Hush must not be visible); a phone video of one full crossing each way.
- Phone memory and frame rate at home and in the greybox Hush, then again at G4.
- Every `[check]` above, answered in a line.

## Sources

- [Steam: Chao World Extended thread (the author's notes on 6.x)](https://steamcommunity.com/app/213610/discussions/0/558751813141858630)
- [Chao Island wiki: Chao World Extended (search extract only; the page returned 403)](https://chao-island.com/wiki/Chao_World_Extended_(More_Chao_Animations))
- [Chao modding docs (search extract)](https://nostalgianinja.github.io/ChaoModding_Docs)
- [Steam: notes on the mod and the Dreamcast garden mods](https://steamcommunity.com/app/213610/discussions/0/3211505894141744272)
- [Wikipedia: Chao Garden](https://en.wikipedia.org/wiki/Chao_Garden)
