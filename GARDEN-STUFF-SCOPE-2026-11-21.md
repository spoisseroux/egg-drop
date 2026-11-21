# More to do in the garden: scope

**Status: scope for approval, 2026-11-21. Nothing here is built.** No code, save format, Studio place or published build was changed. Every number and position marked [P] is a placeholder: numbers to tune from play, positions to check against the walk map and by raycast in Studio.

Spencer, 2026-11-21: no landscape swap. Keep the v7 garden's shape and add "more stuff / interactivity". This is the list `V3-SCOPE-2026-11-21.md` decision 1 asks for. It adds things to do **for players, for pets, and for players together**, on the ground that is already there.

Read for this pass: `V3-SCOPE-2026-11-21.md`, `CHAO-GARDEN-DIRECTION.md`, `FEEL-ALIVE-DIRECTION-2026-11-13.md`, `GARDEN-VERTICAL-SLICE.md`, `PET-PARK-V1-SCOPE-2026-11-13.md`, `PLAY-FOREVER-SCOPE-2026-11-13.md`, and the code named in section 1. No mockups, no Studio session. All art and sound proposed is original, scripted or hand-authored. No generated art or audio.

---

## 0. The answer in one place

| Rank | Thing | For | Trains | Size | When |
|---:|---|---|---|---|---|
| 1 | **Bubble Spring** | pets, players, together | Jump | S to M | v3.0, with the Dash publish |
| 2 | **Trick Stump** (show a trick, others clap) | players together | Heart | S | v3.0, with "Levels matter" |
| 3 | **Hide and Seek** in the bushes | you and your pet | Smarts | M | v3.1 |
| 4 | **Leaf Boats** off the marble bridge | players together | Speed | M | v3.1 |
| 5 | **Tune Stones** (hop a tune) | players, together | Smarts | M | v3.1, with the chime game |
| 6 | **The Wishing Sprout** (grow one flower together) | everyone on the server | Power | M to L | v3.1 |
| 7 | **Sit anywhere** (hub benches, picnic tables) | players together | none | S | v3.0, with "Levels matter" |
| 8 | **Firefly finds** (garden finds at night) | you and your pet | Smarts | S | v3.0, with garden finds |
| 9 | **Seed Dish** (call the birds down) | players, pets | none | M | v3.1 |
| 10 | **Kick-about ball** | players together | Energy | S to M, risk | v3.1 |
| 11 | **Lookout Bell** on the rotunda | players | none | S | v3.1 |
| 12 | **Photo Spot** | players, families | none | M | later |
| 13 | Nap cushion, pet parade, the park disc | pets | none | S to M each | later (carried from the park scope) |

Three findings that shaped the list:

1. **Almost everything to do in the garden today is at the hub or inside a park kerb.** The east spring, the west lawn, the stream, the rotunda and both waterfalls have nothing to touch. The list spreads things out so a walk across the island passes something every 30 to 40 studs.
2. **Power and Energy have no garden source at all.** `StatCatalog.XP` trains them only on the Pocket Deck. Heart, Jump, Speed and Smarts each have one or two. Items 6 and 10 are the first garden sources for the two missing stats (question 2).
3. **Players have very few verbs of their own.** A player can walk, pet, throw the park ball, start a toy return and say hello to a pet. Roblox `Seat`s exist only on the park bench; the two hub benches and both picnic tables are scenery. Half this list is things the avatar does, not only the pet.

---

## 1. What is already there (checked 2026-11-21), so nothing below repeats it

| Thing | What it does | Where |
|---|---|---|
| Three hub stations | Eggs, the Care Cradle (dock and care for a pet), the Pocket Deck kiosk, each with attract rings | `HollowWorldLayout.Stations`, `GardenCareLayout`, `StationAttract` |
| Toy Lawn and personal toys | One shared toy with "Start a return" / "Join return" for two players; six personal toys a pet plays with alone (Speed XP per toy beat) | `GardenToyPrompt`, `GardenToyReturn`, `ToyCatalog` |
| Two Pet Parks (arrival, grove) | Swing, slide, see-saw, sandbox castle, ball toss, thrown fetch for up to 3 pets, one five-seat bench, the daily Play date (Jump and Speed XP) | `ParkLayout`, `ParkActivities`, `ParkFetch` |
| Pet life | Wander, sit, nap spots (creek nook, two spring rests), ten tricks, idle beats, coos, greetings between pets | `GardenActivity`, `GardenLayout`, `PetIdleBeats` |
| Petting and say hello | Rub your own pet; say hello to someone else's (Heart XP) | `PetContact`, `PetHello` |
| Ambient life | Birds on 34 canopy perches, 150 flower patches, 44 bushes, seven lamps, the day and night cycle, water sound | `AmbientPerches`, `WorldDressing`, `HollowAmbience` |
| Planned in V3 | Garden Dash and its start gate (section 4), **garden finds** (5.3), the stepping course and chime game (5.4), Tug of War and Treasure Hunt (v3.1) | `V3-SCOPE-2026-11-21.md` |
| Scoped for the park, not found in `src/` | Nap pile cushion, quick chat phrases, an emote row, pet tug, follow-the-leader, a park-only flying disc | `PET-PARK-V1-SCOPE` 2.2 to 2.6 |

**Garden finds in context (V3 5.3, v3.0).** A sparkle spot on the lawn that only you see; your pet trots over, sniffs and pops it for +8 Smarts XP, at most 12 a day, from about 24 authored spots. Finds are the "walk around and look" layer. Everything below is a fixed place you go to. They share three things with finds: the authored-spot list (no new thing may sit on a find spot), the Smarts daily budget (items 3, 5 and 8 count against the same 12 a day, so Smarts cannot be farmed three ways), and the rule that the server places and confirms everything.

---

## 2. Rules every item follows

- **One way in.** Each thing uses the prompt players already know: **tap the prompt bubble on a phone, E on a keyboard, X on a gamepad** (the binding every station uses). Where a second input is needed it is the Roblox jump button, never a new on-screen stick. Touch targets 44 px or larger, nothing in the top-left quarter.
- **Pets never collide.** Props are non-colliding for pets and placed by the server from `World.groundY`, as park equipment is. Players get simple colliders only where they must stand on something.
- **The server owns it.** Clients send intent ("use this"), never a position, a result or a time. Shared things ride the existing garden snapshot with a start time, so a late joiner sees the same bubble, boat or flower.
- **Small XP, never Stars.** No item pays Stars, items or eggs. XP stays under the per-minute caps in `StatCatalog.Caps` (20 a minute for Heart, Jump and Speed), and each new source has a daily cap [P]. An away player earns nothing: every grant needs a fresh input.
- **Works alone.** Every item is fun with one player and one pet. A second player makes it better; nothing waits for one.
- **No grief.** Nothing can be taken, blocked or held. Shared props have a short per-player wait when others are near, as park fetch does. No free text, no pet you can touch that is not yours.
- **Phone budget.** No item adds a per-frame remote. Each is culled past 90 studs on a phone. Reduced Motion keeps the action and drops shake and bursts.
- **Sites.** Dry walkable ground, at least 6 studs from stations, park kerbs, find spots and the Dash course, and off the two grove tiles while the reroute is parked.

---

## 3. The list, ranked

### 1. Bubble Spring (S to M)

- **What:** the bubbling spring by the two spring rest daises starts blowing big wobbly bubbles across the lawn for 20 s.
- **Player:** use the prompt on the spring's rim stone. Then walk or jump into bubbles to pop them, or tap them on a phone.
- **Pet:** hops and bats at the nearest bubble, sneezes when one pops on its nose. Up to four pets near the spring join, whoever owns them.
- **Stat:** Jump, 3 XP for each bubble your own pet pops, at most 10 a run [P].
- **Social:** yes. Everyone sees the same bubbles (a seeded list from the server). Anyone can pop any bubble; popping one never takes XP from someone else's pet.
- **Where:** `Wet.BubbleSpring` at (52, 3), bubbles drift over the lawn toward (50, 14). It gives the quiet east side a reason to visit.
- **Art and sound:** one bubble (a sphere with a painted rim highlight), a pop ring, a rim stone. A low "blub" loop while it runs and five pop notes on one scale, so a flurry of pops sounds like a tune.
- **Why a kid likes it:** popping bubbles needs no explaining, and the pet being bad at it is funny.

### 2. Trick Stump (S)

- **What:** a low round stump stage. Your pet hops up and does one of the tricks it knows. Anyone watching can clap.
- **Player:** use the stump, then pick a trick from a row of pictures (left and right to choose, the prompt key to go). Watchers within 14 studs get one **Clap** key for 5 s.
- **Pet:** the chosen trick, then a bow. Pets of clapping players do a small hop. A locked trick shows its Heart level ("Happy hop at Heart 18").
- **Stat:** Heart, 6 XP for a show, +2 for each other player who clapped (up to 3), at most 5 shows a day [P]. Clapping pays the clapper nothing.
- **Social:** yes, and safe: the only thing one player can do to another is clap.
- **Where:** the edge of the Toy Lawn, in view of both hub benches, about (-30, 12) [P].
- **Art and sound:** one stump with a painted star on top, a small confetti puff (the reveal stage's pieces), a clap sound in three layers so three clappers sound like a crowd, a short "ta-da".
- **Why a kid likes it:** "watch what mine can do". It is also the best advert for "Levels matter": tricks now unlock by Heart level, and this is where everyone sees them.

### 3. Hide and Seek (M)

- **What:** your pet hides in one of the garden's bushes and you find it.
- **Player:** choose "Hide and seek" from pet focus (or accept when the pet offers with a "?" bubble). Cover your eyes for 3 s (the screen dims), then look for the bush that wiggles and giggles, and use its prompt.
- **Pet:** scurries off, dives in, peeks out every few seconds. Found: it bursts out in a puff of leaves with its joy face. Not found in 45 s: it pops out by itself and runs back, no fail.
- **Stat:** Smarts, 8 XP a find, counted in the same 12 a day as garden finds.
- **Social:** light. Other players see your pet run, the bush wiggle and the pop-out, and can point it out. Only the owner's prompt counts.
- **Where:** the 44 dressing bushes (`WorldDressing`). The server picks one 12 to 30 studs away on walkable ground, never inside a park.
- **Art and sound:** no new models. A bush wiggle (code), a leaf puff sprite, eyes peeking from the bush, a giggle in each pet's voice pitch, a "found you" chirp.
- **Why a kid likes it:** it is the game they already play at home, and the pet is hopeless at keeping quiet. Wiggle range grows with Smarts level, like "finds glow from further away" on the reward track.

### 4. Leaf Boats (M)

- **What:** drop a leaf boat off the marble bridge and watch it sail down the stream to the pool.
- **Player:** use the prompt at the bridge rail. The camera stays yours; walk or run along the bank with it.
- **Pet:** chases it along the bank, ears back, and barks it home at the pool.
- **Stat:** Speed, 5 XP when your pet reaches the pool with the boat, at most 6 boats a day [P].
- **Social:** yes. Two boats dropped within 5 s are a race: each takes a seeded line through the stream's eddies, so the winner is a surprise. No prize, a "1st!" flag on the winning leaf. Up to four boats at once.
- **Where:** `WalkableSpans.MainBridge` at (2.5, 21), along the stream to the pool. The boat follows one authored line measured from the water parts; no physics.
- **Art and sound:** four leaf boats in four colours with a twig mast, a ripple decal, a plop, a soft finish bell.
- **Why a kid likes it:** a race where nobody can be bad at it. It is also the second place luck shows itself in the open, after the Dash clover.

### 5. Tune Stones (M)

- **What:** five flat round stones in an arc. Each plays its own note and lights up when stepped on.
- **Player:** walk or jump across them. No prompt needed for free play. Once a day a signpost shows the **tune of the day** as five coloured dots; hop it in order and the flowers around the arc bloom and the birds answer.
- **Pet:** hops stone to stone behind you, a beat late, and sits on the last one you touched.
- **Stat:** Smarts, 16 XP for the tune of the day, once [P]. Free play pays nothing.
- **Social:** yes. Everyone hears every note, so two players can play a round. Each stone has a 0.2 s gap between notes, so it cannot be spammed into noise.
- **Where:** open lawn north of the bridge toward Sky Falls, about (-8, 44) [P].
- **Art and sound:** five stones (one mesh, five colours), a signpost, five bell notes on one pentatonic scale from the garden music's key, a bloom sprite.
- **Why a kid likes it:** stamping on things that make noise. **It replaces the three chime posts in V3 5.4:** the Speed chime game is played on these stones, so one instrument is built, not two.

### 6. The Wishing Sprout (M to L)

- **What:** one big sprout the whole server grows together. Water and dig around it and it grows from a shoot to a bud to a flower taller than a player, then blooms with a petal shower and drops back to a shoot.
- **Player:** use the watering can on its stand (pick up, walk to the sprout, pour). Each pour adds a little. A ring of leaves around the base shows progress.
- **Pet:** digs at the base (the sandbox dig pose), flings soil, and dances when it blooms.
- **Stat:** Power, 4 XP a pour with your pet digging, at most 12 pours a day [P], plus 20 Power XP if you helped a bloom, once a day.
- **Social:** the most social item here. Growth is shared and kept only for the life of the server (no save). About 40 pours to bloom [P], so alone it takes a session and with four players a few minutes. Each player's can refills at the stream, 20 s between pours.
- **Where:** the empty west lawn near lamp 5, about (-70, -8) [P], to pull players across the island.
- **Art and sound:** the sprout in four growth stages (one script, scaled pieces), a watering can and stand, a petal shower, a rising five-note "grow" figure, a bloom chord.
- **Why a kid likes it:** growing something together, and the moment it opens. Bloom colour is random each time (visible luck again), and a small counter on the stand shows blooms today.

### 7. Sit anywhere (S)

- **What:** real seats on the two hub benches and both picnic tables (today only the park bench has them).
- **Player:** the standard Roblox seat: walk onto it or use its prompt; jump to stand.
- **Pet:** sits on the ground beside you, or hops onto the picnic bench next to you. Two pets at one table turn to face each other.
- **Stat:** none. **Social:** yes, it is the "sit and chat while the pets play" posture, at the hub where people gather.
- **Where:** `Station_BenchWest` (-43, 5), `Station_BenchEast` (-17, 5), `Station_PicnicWest` (-58, 12), `Station_PicnicEast` (34, 46).
- **Art and sound:** none. Seat anchors and the pet's sit spots are data.
- **Why a kid likes it:** it makes the garden a place to be with a friend, and gives the Trick Stump an audience.

### 8. Firefly finds (S)

- **What:** at night, garden finds (V3 5.3) appear as a firefly circling a spot, not a sparkle.
- **Player:** the same as a find: walk near with your pet out.
- **Pet:** creeps up, jumps and claps its paws; the firefly loops once around its head and flies up to the nearest lamp.
- **Stat:** Smarts, the same +8 and the same 12 a day. It is a second look for the same system, not a second source.
- **Social:** fireflies you caught tonight show to everyone as extra glints around the lamps, so a busy garden has brighter lamps. No count, no board.
- **Where:** the finds spot list. **Art and sound:** one firefly sprite with a soft glow, a tiny rising chime.
- **Why a kid likes it:** it makes night worth staying for, which the day and night cycle does not yet do.

### 9. Seed Dish (M)

- **What:** a stone dish on a post. Scatter seed and the birds come down from the trees.
- **Player:** use the dish (60 s wait for the whole server [P]). Stand still and more birds land; run at them and they burst up.
- **Pet:** sits and watches with its curious face, tail going; after 8 s it cannot help itself, pounces, and the flock scatters.
- **Stat:** none. **Social:** shared flock, shared scatter.
- **Where:** beside `Station_PicnicWest`, about (-62, 16) [P], under the two nearest perches.
- **Art and sound:** the dish and post, seed specks, a hop and peck cycle for the existing birds, a flutter burst. Size is M because birds are client-only ambience today and need a shared fly-down.
- **Why a kid likes it:** chasing pigeons.

### 10. Kick-about ball (S to M, risk)

- **What:** one big soft ball players push around by walking into it, with two flower-arch goals.
- **Player:** walk into it. No prompt. **Pet:** chases it and headbutts it when it stops.
- **Stat:** Energy, 3 XP for each goal while your pet is chasing, at most 10 a day [P].
- **Social:** yes, the first thing two avatars do with each other directly. A goal counter on each arch resets each server.
- **Where:** open lawn south-east of the bridge near lamp 6, about (46, -14) [P].
- **Art and sound:** ball, two arches, a boing, a goal jingle.
- **Risk:** it is the only physics prop. It needs a soft boundary (it rolls home if it leaves the lawn or sits still for 30 s) and a check that it cannot be used to shove players. If that is not clean in the beta, cut it.
- **Why a kid likes it:** a ball.

### 11. Lookout Bell (S)

- **What:** a small bell in the rotunda. Ring it and every pet in the garden looks up and hops, and the birds lift off.
- **Player:** use the bell (90 s wait for the whole server [P]). **Pet:** the look-up and hop, wherever it is. **Stat:** none.
- **Social:** a harmless "I did that" that the whole server sees. **Where:** `Landmarks.Rotunda` (-60, 50), on the knoll only players can climb, so the climb gets a reward.
- **Art and sound:** one bell and rope, one clear bell note with a long tail. **Why:** a button that makes everything react.

### 12 and 13. Later

- **Photo Spot (M):** a flower arch facing Tumble Falls where the HUD hides, your pet does a trick beside you and Roblox's own capture prompt saves the picture. Needs a check of the current capture API and its rules for young accounts [CHECK]. Good for sharing, so it is worth doing once the garden has more in it to photograph.
- **Nap cushion, pet parade, park disc (S to M each):** carried over from `PET-PARK-V1-SCOPE` 2.2 and 2.6, still wanted, still behind everything above. Pet tug is covered by Tug of War in v3.1.

---

## 4. What goes where

| Release | Items | Why |
|---|---|---|
| **v3.0, "Levels matter"** | 2 Trick Stump, 7 Sit anywhere | Both are S, need almost no art, and the stump shows off the Heart tricks that publish is about. |
| **v3.0, Garden Dash publish** | Garden finds (S9), 8 Firefly finds, 1 Bubble Spring | Finds are already in. Fireflies are one sprite on top. Bubble Spring ships only if the Dash art (4.2 and 4.4b) is done first; otherwise it leads v3.1. |
| **v3.1** | 3 Hide and Seek, 4 Leaf Boats, 5 Tune Stones (with the chime game), 6 Wishing Sprout, 9 Seed Dish, 10 Kick-about, 11 Lookout Bell | Each is its own small slice. Tune Stones first, since the training courses need them. |
| **Later** | 12 Photo Spot, 13 the park carry-overs | Need a policy check or more players on at once. |

New work for Fable in v3.0 from this list: one stump, one clap and one "ta-da", one firefly sprite and chime, and (if it makes the Dash publish) a bubble, a pop ring, a rim stone and six sounds. That is on top of the V3 question 11 budget.

New for Sol: one small shared "garden things" module on the garden snapshot (a prop id, a start time, a seed), XP keys and daily caps in `StatCatalog`, a walk-map site check that fails the build if any site breaks the section 2 rule.

---

## 5. Open questions for Spencer

1. **Is this the kind of "stuff" you meant?** The list leans to small toys spread across the island, not one big new area. **Recommend yes:** it fills the empty east, west and stream sides without touching the landscape.
2. **May the garden train Power and Energy?** Today only the Pocket Deck does. The Wishing Sprout (Power) and the Kick-about (Energy) would be the first garden sources, small and capped a day. **Recommend yes, small:** a child who mostly plays in the garden should see all six bars move, and the deck stays by far the faster way.
3. **Two S items into "Levels matter" (Trick Stump, Sit anywhere)?** **Recommend yes.** They cost little and give that publish something to see in the world, not only in menus.
4. **Bubble Spring in v3.0 or first in v3.1?** **Recommend: v3.0 only if the Dash art is finished first.** Dash is the headline and must not slip for it.
5. **Tune Stones replace the chime posts in V3 5.4?** **Recommend yes:** one instrument, used for free play, the daily tune and the Speed chime game.
6. **Should Hide and Seek, the daily tune and fireflies share the finds' 12 a day?** **Recommend yes,** so Smarts has several ways to play and one budget.
7. **The Wishing Sprout resets with the server (no save).** A saved "blooms helped" count for a badge or a name piece is possible later. **Recommend no save in the first version.**
8. **Kick-about ball: accept the physics risk?** **Recommend try it in the beta and cut it if it can shove players or leaves the lawn.**
9. **Clapping: is one fixed "Clap" key enough social for now,** or do you want the park scope's quick chat phrases and emote row built too? **Recommend clap only for v3.0;** quick chat needs the Roblox policy check the park scope flagged.
10. **Sites.** Every position here is a guess from the layout tables. **Recommend one Studio walk with Fable's marked-up top-down map before any slice starts,** so all the sites are picked together and stay clear of the Dash course and the finds.

---

## Files

- This document: `GARDEN-STUFF-SCOPE-2026-11-21.md`
- Builds on: `V3-SCOPE-2026-11-21.md` (decision 1, 4.4b, 5.3, 5.4), `PET-PARK-V1-SCOPE-2026-11-13.md` (2.2 to 2.6), `FEEL-ALIVE-DIRECTION-2026-11-13.md` (birds, pet life), `CHAO-GARDEN-DIRECTION.md` ("An open garden with places to go")
- Code read: `HollowWorldLayout`, `ParkLayout`, `ParkActivities`, `ParkFetch`, `ParkMount`, `GardenLayout`, `GardenActivity`, `GardenCareLayout`, `GardenToyPrompt`, `ToyCatalog`, `StatCatalog`, `WorldDressing`, `AmbientPerches`, `PetHello`, `artifacts/world1-mockup/v7/stations.json`
- Not done in this pass: no mockups, no Studio session, no site measured. Whether the stream has one clean line from the bridge to a pool, how the birds are drawn, and the current Roblox capture rules were not checked.
