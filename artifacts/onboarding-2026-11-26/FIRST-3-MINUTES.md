# The first 3 minutes (Fable, 2026-11-25)

Read-only audit of a fresh save on the beta line (`fix/beta25-feedback`, beta (27)), from code and specs. Nothing here
was timed in Studio: times are from code constants plus an estimate, marked `~`. `[check]` = confirm before building.

**The numbers this answers** (`artifacts/growth-2026-11-26/CREATOR-HUB-2026-11-25.md`, live): D1 1.4%, about 45% of
new players gone by 1:00, 24% left at 5:00. Yet 92% of players who see the board reach the Bear. So the loss is at the
two ends of the first minute: **before the board** (loading, not in the funnel) and **right after the Bear** (the toy
ends, errands begin). And nothing in the first 3 minutes tells them about tomorrow.

## 1. Today, minute by minute

| Time | What happens | Where it loses people | Code |
|---|---|---|---|
| 0:00 to ~0:10+ | Loading screen: title, checker, five pals waving. It waits for the whole island to load. Skip appears at 10 s; it leaves by itself at 25 s. | The longest wait in the session comes before any play, and the first screen after it (the deck) does not need the island. | `src/first/LoadingScreen.client.lua` (`MaxSeconds, SkipAfter, WorldWait = 25, 10, 15`) |
| ~0:10 | Pocket Deck boot, 1.7 s, one sound. Any input skips it. | Fine. Short and charming. | `src/client/DeckBoot.lua` |
| ~0:12 to ~0:30 | Welcome round, calm deck: board, Next, a small "Mystery egg" in a side well, "Hatch a friend". Three balls are already on the board. A ghost hand loops; a quiet cue at 8 s idle; the game drops one for you at 25 s. Each merge adds its tier to the egg; 6 hatches it. That is 2 to 3 drops. | It is over before the player has felt the toy. Three drops cannot make a chain, so the best feedback in the game (rising notes, screen kick, bigger buzz) never fires. The egg is a small flat shape off to one side; its cracks are three thin lines and a 3 degree wobble. | `src/server/WelcomeSeed.lua`, `WelcomeState.lua`, `src/shared/WelcomeProgress.lua`, `src/client/WelcomePresentation.lua`, `DeckCalm.lua`, `FirstHatchGuide.lua`; charge in `src/server/init.server.lua:2514` |
| ~0:30 to ~0:40 | The Bear hatches: a 4.4 s film with the ASMR crack layers and vibration. Then a card: "You hatched Bear!", **Meet Bear** / Keep playing. | The player watches. The one moment the whole game is named after is not theirs. The result is always the same Bear, so there is no surprise either. | `src/client/HatchCinematic.lua`, `HatchAsmr.lua`, `Haptics.lua`, `init.client.lua:2613` |
| ~0:40 to ~1:15 | Garden. A hand bubble over the Bear, cream paw prints to him. Tap: "First hello! +3 ★", six hearts. | Good beat. But it is a different game from the one they just learned, 40 s in. | `BearNeeds.lua`, `PetTrail.lua`, `PetAffection.lua`, `src/shared/FirstHello.lua` |
| ~1:15 to ~2:00 | Ball bubble: "Bear wants a toy". Paw prints to the egg machine. Buy a Toy Egg, capsule shot, a second ASMR hatch (3.1 s), Give. | A walk and a shop inside the second minute. Works if the first hatch landed; a chore if it did not. | `BearNeeds.lua`, `ThingsTrail.lua`, `FirstSpendGuide.lua` |
| ~2:00 to 3:00 | Deck bubble: "Bear wants to watch you play". Round two: 24 balls, and every panel (score, chain, quests, difficulty, payout, controls) comes back at once. | Round two is the real game and most players reach it near the 2:00 mark, where 60% have already left. | `src/shared/BoardRoundSim.lua` (`Budget = 24`), `DeckScreen.lua` |
| after 3:00 | Results: Welcome bonus +12, "Coming up" strip. Only **then** the nest bubble: "Tuck in Bear's egg" (ready in 8 h). | The only come-back promise is the fourth errand. A player who leaves at 3:00 never saw it. | `BearNeeds.lua` (`Needs.Order`), `src/shared/Nest.lua` (`Hours = 8`), `StarterBonus.lua` |

## 2. What to change, ranked

**1. You crack the first egg. (M)** *Spencer's ASMR idea: keep, and make it the centre.*
- Fixes: 0:30, the watched hatch.
- Feel: "I did that." Crunch in the ear and the hand, then a held breath, then a face.
- Change: when the egg fills, it leaves its side well and lands in the middle of the glass; the board dims. "Tap the
  egg". Three taps: a crack from the tap point, a fork with the Bear's colour leaking through, then the creak and the
  pop. Each tap answers within a frame with the existing `asmr_*` layer and its buzz. Untouched, it cracks itself
  every 1.1 s, so nothing waits. Hold to hatch. This is the unbuilt half of
  `artifacts/qa-2026-11-23-beta14/ASMR-AND-SCALE-LOOK.md` section 1; build it for the Bear first, other eggs later.
- No rub loop in this slice (no sound for it yet). `[check]` `Cinematic:held()` can gate before age 0.98.

**2. The board in five seconds. (M, plus S to measure)**
- Fixes: 0:00 to 0:10.
- Feel: "It started straight away."
- Change: new saves leave the loading screen as soon as the deck can draw; the island keeps loading behind the
  Welcome round and the hatch (about 30 s of cover). Returning saves keep today's wait. First, add two funnel steps:
  "Joined" before "Board ready", and "Egg tapped". Today the funnel cannot see loading losses.
- `[check]` what the deck needs loaded; the garden must be whole by Meet Bear, else hold on the hatch card.

**3. A Welcome round that shows off. (S to M)**
- Fixes: 0:12 to 0:30, a round with no chain.
- Feel: "Whoa, it kept going."
- Change: re-seed the opener so the **second** drop sets off a sure three-step chain (rising notes, kick, growing
  buzz all fire once). Every merge sends a bright spark from the merge point to the egg, which takes it with a
  squash and a crack tick. Egg well twice the size on phones. Target 5 to 6 drops, about 30 s; threshold raised to
  match. `[check]` the charge sum against `Pets.byId.pip.charge`; welcome-only value, the solver spec re-run.

**4. The Bear brings tomorrow's egg. (S to M)**
- Fixes: no reason to return before 3:00.
- Feel: "There's a present for me tomorrow."
- Change: move `needNest` to straight after the first hello (before the toy). The Bear walks the prints to the nest;
  one tap tucks the egg in; the card shows what is inside (day 1: beanie + 10 Stars, already in `UICopy` `nest.inside`).
  The rail ticket then says "Hatches tomorrow" for a new save, not a countdown. A gift that waits, never one that
  expires: no pressure. `[check]` the nest exists in the garden at that moment.

**5. Juice the classic deck. (M)** *Spencer's "insanely tactile": keep, but spend it on the default look.*
- Fixes: rounds one and two feel flatter than the hatch. The pops, trails and start lids are level rewards
  (`src/shared/DeckJuiceCatalog.lua`), so a new player sees none of them.
- Change, all in classic: balls squash on landing and wobble to rest; a 40 ms hit-stop on tier III and up; the two
  merging balls pull together for two frames before the pop; a ring ripples across the glass in the new tier's colour;
  aim detents tick in the hand; the last three balls each get a low drum. Sounds from the existing synth scripts.

**6. The handheld is alive. (S to M)** *"Exciting deck UI": adapt. Not more panels; the shell reacts.*
- Change: A and the d-pad sink when pressed (touch too); the shell rocks 1 to 2 px with the merge kick; the wordmark
  light pulses with each chain note; the egg well beats faster as it fills. Round two brings panels back in two steps
  (score and balls left first, quests and difficulty from round three) instead of all at once.

**7. Endless mode: not now. (L)** *Adapt later, as "Chill mode".*
- A new player cannot use it in 3 minutes, and unbounded play breaks the Stars budget. Later: no line, no ball count,
  Stars only at set marks up to one round's pay, unlocked after round three. A day-2 reason, not a first-session one.

**Rejected:** more Stars up front (22 one-time Stars already land in session one); any streak or countdown that can
be lost; anything that pays for posting outside Roblox.

## 3. Build first: "The First Hatch"

Items **1, 3, 4** and the two funnel steps from 2. One story, one minute: a round that shows off, an egg you crack
yourself, a pal who hands you tomorrow's egg. No new art beyond crack lines and flakes drawn in code; sounds are the
existing `asmr_*` set; no new Stars. Switches (off = today exactly): `/onboard crack`, `/onboard opener`,
`/onboard nestfirst`. Translations: "Tap the egg", "Hatches tomorrow".

**Test plan (beta, `/freshsave`, once on a phone and once on PC):**
1. Stopwatch from the board appearing. The egg should be in the middle of the glass by ~0:35.
2. Drop two: does the chain fire every time? Three tries, three chains. Notes rise, the deck kicks.
3. Each merge: a spark reaches the egg and it cracks a little. Can you see the egg well on the phone?
4. Tap the egg three times: each crack starts under your finger, with sound and buzz in the same instant. Then try
   hands off (it opens alone in about 4 s) and holding (it opens by itself, fast).
5. Sound off, then Reduced Motion on: still readable, still buzzes.
6. Garden: say hi, then the Bear leads to the nest before the toy. Tuck in. The ticket says "Hatches tomorrow".
7. Leave at 3:00 and rejoin: the ticket is still there; nothing pays twice.
8. Each switch off in turn: that piece is exactly as beta (27).
9. Your own save: none of it shows.

**What should move:** the share still in at 1:00 and 2:00; "Bear met" to "Second round started"; D1 once traffic
returns. One question for Spencer after the pass: did cracking the egg make you want to hatch another?
