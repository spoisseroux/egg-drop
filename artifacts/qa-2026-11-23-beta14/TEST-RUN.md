# Pocket Pals QA run: beta (14)

**Where:** Pocket Pals Beta (place 107705084891479). It has its own saves and no Robux products. Live is untouched.
**What's new:** everything since your beta (12) pass: your round 1 notes (beta 13) and round 2 notes (beta 14).
**How to note things:** write under each line, or paste screenshots like last time, and I'll triage them the same way.
**Commands:** type them in the chat box. They only work for you, on the beta. Each piece has an `off` switch, so if something looks wrong, turn it off and see if the problem goes away.

Play on PC first, then on your phone (section 9).

---

## 1. Brand-new player (most important)

This is the path new players get on live once v3 ships, so it decides next-day returns.

- [ ] Type `/freshsave`. It kicks you. Rejoin: you should be on a brand-new save.
- [ ] **No tour cards.** A hand bubble floats over the Bear.
  - Tap it, tap the Bear, or press G (L2 on a gamepad): the greeting opens.
- [ ] Then a ball bubble appears, with paw prints and a "Hatch eggs" label.
  - Stand still for 20 s: a hint shows.
- [ ] Does it feel obvious what to do next at each step? Note any moment you weren't sure.
- [ ] **The nest** (plaza, east rim): a woven twig nest on a straw bed, with a wooden sign showing your pet's name.
  - Does the sign read from where you arrive?
  - Do pets walk around it, not through it?
- [ ] Before your first hatch, the nest explains itself: "Bear's egg naps for 8 hours. Come back to hatch a gift."
  - **Does that make the sleeping egg clear now?** (Your round 1 note O1.)
- [ ] Tuck in. It should tell you when to come back, with a toast too. The HUD chip reads "Egg 7 h".
- [ ] Play one deck round. The results show the **"Coming up"** strip:
  - "Egg in 7 h 52 m", counting down live
  - "Stamp N in X h Y m"
  - "N quests to go", or "1 ready to claim" with a gold outline
  - **Does "Coming up" fix the "see you tomorrow" problem?** (R2.6)
- [ ] When you're done, type `/freshsave restore`. It kicks you; rejoin and your old save is back.

## 2. Springy menus (R2.2)

- [ ] Tap any button: the face squeezes in and bounces back a little past full size. The button itself doesn't move.
- [ ] Round keys (Back, Help) squeeze more.
- [ ] Open Pets, Machines, Stats, the quest log and the Pocket menu. Each should:
  - rise about 28 px
  - grow from 90%
  - land with a **visible** bounce
  - pop its icons from 70%
- [ ] Closing is quick: a fade, a little down and smaller.
- [ ] **Can you see the springs now?** That was your round 2 complaint.
- [ ] Open and close menus fast: nothing sticks or doubles.
- Off switch: `/alive springs off`, `/alive menus off`

## 3. Garden life (R2.3 to R2.5, L1 to L3)

- [ ] **Birds:** small songbirds (rust, slate, moss) with:
  - an upright egg-shaped body and a small head
  - a bright little beak
  - a tail wedge and two legs
  - They hop, cock their heads, flick their tails, and fly off when you get close. **Bird-shaped now?**
- [ ] **Butterflies:** four real-looking ones, about Animal Crossing size (half what they were).
  - A soft flutter with glides, not snapping between two poses.
- [ ] **Leaves:** a few drift down around you all the time.
  - Mostly green, with the odd yellowing leaf or pale petal. They slant in a gust.
  - None under the rotunda, the bridge arch, the colonnades or the station roof.
- [ ] **Night** (`/hour at 3100`):
  - no birds
  - butterflies fade into soft firefly glows one by one at dusk
- [ ] **Crickets:** `/hour at 2950` (dusk), then `/hour at 3100` (night). Listen with sound on.
  - [ ] A cricket bed fades in as the light drops.
  - [ ] A few chirp in the nearest bushes, and go quiet when you walk right up to one.
  - [ ] `/hour at 120` (dawn): the first birds come in over the last crickets.
  - [ ] **Keep or swap?** Also: does any traffic rumble come through, and do the close chirps sound like the same clip three times?
- [ ] `/hour at 1000` puts the day back.
- Off switch: `/alive life off`

## 4. Sounds

- [ ] The "toilet flush" in gusts is gone (R2.1).
- [ ] **Fountain** (meadow): a stone fountain with a jet. The splash grows as you walk up to it.
  - This sound is a Roblox library stand-in. **Does it sound right?** An original one is being made.
- [ ] New tip notification: still silent. You'll get a shortlist of chime sounds to pick from.

## 5. World

- [ ] **Trees:** they sway from the trunk top, gentle in the breeze, a lean in a gust.
  - Lime crowns are matte, not neon.
  - Walk the camera into a crown: it goes see-through, no more clipping.
- [ ] **Tumble Falls:** white water over dark wet rock, spray and a foam apron at the foot. You can't walk through the rocks.
  - **Still awful, or better?** (The blue pool under it is being toned down next.)
- [ ] **Ground flowers** (R2.7): softer, and they sit in the grass instead of glaring.
- [ ] **Island edges:** try to climb the mountains or jump off. You're blocked, or put back where you last stood.
- Off switch: `/aero off` puts the old trees, falls and spring back at once.

## 6. Pets and finds

- [ ] **Catch-up** (G1): run far ahead of your pet, respawn, or get it stuck behind a wall.
  - After about 1.5 s it poofs and lands right behind you.
  - Never during a deck round or your own race.
  - Off switch: `/catchup off`
- [ ] **Garden finds** (G2): walk around for a minute. A gold sparkle shows on a lawn near you.
  - Walk to it with your pet: pop, "+16 Smarts".
  - `/finds now` drops one at once.
- [ ] **Dewdrop fruit** (G3): honey-coral drops under the lime trees. Did you spot them this time?
- [ ] **Pet tag:** one row, showing the top stat with a level disc.
  - Less dead space? Better bottom padding? (U2)

## 7. Garden Dash (U3 to U6, G4)

- [ ] **Picker:** your pet runs on a lit pedestal, with Speed, Energy and Jump bars beside it.
  - Just for Fun and Time Trial say "All pets equal".
- [ ] **Start:** the whole row stands 1.5 studs apart with every name over it, then they funnel onto the path.
- [ ] **HUD:** drawn Dash and Jump keys with words.
  - On PC: the "Shift" and "Space" caps are fully on screen.
  - **Can you read them now?**
- [ ] **Results:**
  - a podium hop and a medal
  - your time and best
  - Stars
  - the top three plus you
  - Race again or Done
  - **Exciting enough, and clear what to do next?**
- [ ] The place pill no longer reads "1st" under a 4th-place result.
- [ ] Race Stats On and Time Trial once each (never tested yet).
- Off switch: `/dash off`

## 8. Deck results (U7)

- [ ] The "Coming up" strip is full width under the panes and readable.
- [ ] The four buttons are compact, with Hatch and Leave side by side.
- [ ] The wallet chip never covers a stat row.

## 9. Phone (never tested yet)

- [ ] Frame rate in the garden with everything on (birds, leaves, swaying trees, waterfall).
- [ ] Menus spring and fit the screen. Deck results, Dash picker and Dash results fit.
- [ ] Touch works on finds, Things to do and the race buttons.
- [ ] The "Coming up" strip is readable.

## 10. If you have a second player

- [ ] Watch someone else race: a "Racing" pill over their pet, and no inspect prompt.
- [ ] Race together: does the pill and the start line look right with two players?

---

## Coming next (not on the beta yet)

These will be added here when they land on the beta (15):
- the waterfall pool no longer bright cobalt
- the tree crown leaves reshaped
- an original fountain sound
- three small look fixes:
  - the ready quest chip sits after the egg and stamp
  - the petal colour is softer
  - the bird's folded wing tips no longer poke out from the front
- the tip chime shortlist, for you to pick from

## Notes

(write here)
