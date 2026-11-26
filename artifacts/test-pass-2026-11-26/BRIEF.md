# What changed since your beta (25) notes

Covers beta (26) to beta (33) (v97, runtime f37ac1e1), all on Pocket Pals Beta. **Live has not been touched.**
Your test doc is `TEST-PASS.md`, in this folder.

## Your beta (25) notes, all six done

| Your note | What was done | Beta |
|---|---|---|
| "the cave entrance is way too smal" | The mouth is now a rock arch 18 wide and 11 tall, and the den inside is 36 x 24. The island was re-carved around them. | (27) |
| "a lot of missing faces or inverted normals ... messy geometry" | Every stair step is now one closed stone block (before: 444 open edges and 26 flipped). The wall, terrace and rocks were cleaned. A new mesh check now refuses broken meshes. | (26), (27), (30), (31) |
| "make the clouds pocket deck skin the default" | Cloud Glass (blue) is the default deck, as a free starter. Saves that picked another skin keep it. | (26) |
| "no pets playing bubble thing anymore?" | "Pets playing N/M" is back, bottom right in parks. | (26) |
| "the race entrance ... kinda blends in" | The Garden Dash gate was rebuilt: teal posts with cream bands, a checker banner, seven bulbs, a "Garden Dash" board, a start mat and paw stones. | (26) |
| "everything feels a little too small" | The cave, den and path are bigger: the path is now 9 wide, with the switchback re-routed to fit. Top Lawn toys are not scaled yet (see "Not done"). | (27) |

## Added: the First Hatch (the new first minute)

From your "It needs to be GREAT!!!" and "Maybe three combos and the egg hatches?!":

- **Three combos hatch the Bear.** The Welcome round starts with six balls placed so the first drop sets off a three-merge chain wherever you aim. I tested every aim (81 of 81) in Studio on both difficulty settings. Any drop that merges counts as a combo.
- **Sparks.** Each merge flies a spark in its ball's colour into the egg, which bumps; one of three dots fills per combo.
- **A bigger egg.** It now nearly fills its card. On the calm first deck it also gets 40% of the mostly empty NEXT card's height. It is coloured like the reveal egg (blue spots, green band), so it reads as the same egg.
- **You crack it.** On the Bear's reveal the egg stops before each crack, and a gold pill asks you to tap ("Tap / Click the egg!", "Press A!"). A hand shows how. Each tap gives a crack sound and a buzz, a ring and flakes where you tap, and a crack drawn across the egg. Untouched, it opens by itself in about 4 s. Mashing never skips the pop.
- **Tomorrow's egg comes first.** Straight after the first hello, the Bear asks for the nest: the moon bubble now carries a little egg. When you tuck it in, a little egg flies from the nest to the rail and the new ticket pulses. The ticket says "Hatches tomorrow" if it really hatches on a later day, and counts down otherwise (a tuck at 4 am hatches at noon). The Bear's reveal no longer points at the Toy Egg.
- **Measuring.** Two new one-time events, "DeckShown" (the loading screen left) and "EggTapped" (the first crack tap), so the funnel can see loading losses and the tap.
- **Switches.** Every part has its own switch: `/onboard opener|crack|nestfirst off`. Off is exactly beta (27).
- No new Stars and no pressure timers. Art is drawn in code and the sounds are the existing crack sounds.

## Added overnight: the player scale (the world feels bigger)

You said the world feels tiny and asked for it to be easy to tweak. I didn't scale the geometry, because every coordinate in the island, den, path, parks, nest, dash route and pet paths is hard-coded. Instead the avatar is drawn smaller.

- **Default 0.8** on the beta, so the island reads 1.25x bigger. Live is unchanged (1).
- **One knob, live:**
  - `/scale 0.75` in chat (0.6 to 1.2), `/scale 1`, `/scale clear`, this server only;
  - the ConfigService value `player_scale` changes every server without a publish.
- **What stays the same:** walk speed, jump and every world coordinate (travel times don't change).
- **What follows the scale:**
  - the Pocket Deck in your hands;
  - the spot where you carry your pet;
  - your hair and clothes, including ones that load late;
  - Board mode, where the avatar is lowered so it doesn't float.
- **Checked in Studio:**
  - it scales automatically after spawning, and again on respawn;
  - `/scale 1`, `0.7` and `clear` work live;
  - walking is normal.
  - in Board mode the feet stay on the ground;
  - a hat that loads late comes out at the right size.
  - Captures at 1.0, 0.8 and 0.7 are in `artifacts/player-scale-2026-11-26/studio/`.
- The follow camera's zoom cap shrinks a little with the scale (0.9x at 0.8, per Fable), so you don't end up looking at a tiny avatar.
- Fable picked 0.8: 0.75 is the floor, and at 0.7 the Bear stops reading as a baby. Tell me your number after S4 and I'll set it.

## Fixed along the way

- **A tap on the reveal would have skipped the Bear's hatch.** The full-screen reveal treated a tap as "skip". It now cracks the egg instead. This covers every key too, including E, which is the pet key.
- **The path's ground fixes never showed (since round 6).** The world pack held two pieces with the same name, one from the den and one from the path, and the game always used the den's copy. That is why the pale bank kept coming back. The pack now gives each its own name.
- **Whole island mirrored inside its pieces.** The round 6 rebuild had dropped a 180° turn, which put invisible rock over the path. It is restored.
- **Combo counting.** A quick second drop could take the first chain's merges, so two drops could hatch the Bear. Fixed before shipping.
- **Crack timing.** At some frame rates the crack sound played before the egg stopped. Fixed before shipping.
- **"Hatches tomorrow" no longer appears before you tuck the egg in.** It also never hides the "Hatch egg!" ticket once the egg is ready.

## The world, rounds 6 and 7 (cleanup)

- Pale bank beside the lower path: gone.
- Dark blades below the terrace arrival: gone.
- Rock slivers through the path: cut. They are unconfirmed, because they never reproduced outside Studio.
- Jagged shards and thin slivers above the den mouth: gone, with solid rock behind.
- Pale plank at the mouth's west side: gone.
- Lip stones: 3 on the first shelf, 5 on the second and 2 in the pocket, all seated on the edge.
- Den mouth colour: graded from grey-green to warm brown.
- Grass flaps around the mouth: removed.
- Path grass edges: tidied, and the lip by the top steps is now rock.
- Two wooden boards at the path foot: removed.
- Waterfalls: look right at a distance.

## Not done, or not checked

- **Top Lawn toys at 1.25x.** The toy frames come from one shared park layout that every park site uses. The swing pivots, the see-saw pivot and the slide root drive the pets' animations on each client. Scaling the frames while keeping seats pet-sized means reworking those anchors and re-probing every seat. That's too risky to rush overnight, and Fable said to ship without it. It is a job of its own.
- **Two small steps on the path** come from the island's collision, not the art: the switchback's outer edge and the terrace floor corners.
- **Not seen on a real phone.** Studio can't emulate a phone here, so sizes come from the layout maths: on an 844x390 phone the Welcome egg's shell is about 95 wide by 104 tall (Fable asked for about 104 x 130). Please judge it on your phone.
- **Studio's Output panel** is floating at the bottom of the screen after my phone-size attempt. Drag its title bar back to the bottom dock, or reopen it from the Window menu.
- **The two new events** only record on live servers.

## Waiting on you

1. Your test pass (`TEST-PASS.md`), on a phone and on PC.
2. Whether Cloud Glass becomes the default on **live** too. You said "yes to live eventually". Players who paid for Cloud Glass get no refund.
3. The next live update: the new loading screen plus "BALLS LEFT". It goes out after your test, with the translation sync and a code review.
4. Ads stay off until the new version is tested and live.
