# Onboarding v3 brief: the Bear leads (Fable, 2026-11-27)

For Opus, on Spencer's beta (37) notes 3 to 10. Read from code and captures, not played. Assumes the three bugs are fixed. Looks, words and flow only: no odds, payouts or save changes. All original.

**Two rules for every prompt.** (1) It closes only when the thing is really done (saved fact). Delete `V2.Guide.ignore` and the shrink-and-skip. (2) Ignored prompts nudge, then park; they never block and never count as done.

## 1. The after-hatch flow (P1, switch `lead`)

**Order: Pet Bear, then the Bear leads you to the nest, then Play for Stars. Keep the nest second.** Spencer, the reason: the deck is where a new player disappears for ten minutes, and many first sessions end right after it, so most players never see whatever comes after the deck. The nest takes 20 seconds, is the only thing that gives a reason to come back tomorrow, and the walk is their first trip through the garden with their pet. The order was not the problem; nobody said why. So the Bear now runs there itself and the words say what the egg is for.

**Bubble.** Two lines now: headline (16 characters or fewer, 20 px ExtraBold) and a sub-line (28 or fewer, 14 px Bold, ink at 70%). White `#FFFFFF`, ink `#1B2A4A`, as today.

| # | Headline | Sub-line | Icon | Done when |
|---|---|---|---|---|
| 1 | Pet {pet}! | (none) | hand | first pet |
| 2a | Follow {pet}! | A new egg is waiting | paws | the player is within 8 studs of the nest |
| 2b | Tuck the egg in! | It hatches tomorrow | moon | the egg is tucked |
| 3 | Play for Stars! | Stars buy eggs and toys | deck | a deck round is played (not just opened) |

After the tuck, a 3 s toast: "Sweet dreams! Come back tomorrow to hatch it." Rest between prompts: 2 s (was 4).

**The lead (2a).**

- **Start**, 2 s after the first pet: the Bear chirps, hops twice (0.6 studs, 0.35 s each), turns to the nest and runs.
- **Run**: 14 studs/s (the player walks 16) along the `ThingsTrail` route to `place("Nest")`, never a straight line through fences.
- **Stop and look back**: when it is 12 studs ahead of the player it stops, turns to face them (`PetLookAt.faceOwner`) and beckons: one hop, a paw wave (0.5 s), the `chirp`, the bubble hops. Repeats every 2.5 s.
- **Resume** when the player is within 7 studs.
- **Arrive**: the Bear stops 3 studs from the nest, faces it and bounces on the spot; the bubble moves onto the nest and becomes 2b; the nest's ground ring pulses.
- **Tucked**: the Bear spins once, 6 hearts, `settle` haptic, the toast.

**Edge cases (none may block).**

| Case | What happens |
|---|---|
| Player stands still 8 s | Nudge: the Bear runs back to 5 studs, hops, "This way!" replaces the headline for 2 s, runs again |
| 3 nudges ignored | Park: the Bear follows again; the bubble shrinks to a 36 px moon chip over it; the trail stays lit. Tapping the chip restarts the lead. Prompt 3 may show. The nest prompt returns 2.5 s after the deck next closes, and next session |
| Player walks the other way (over 30 studs from the Bear) | Same as a nudge, counted |
| Deck or a menu opens | Lead pauses; resumes 2.5 s after it closes |
| Player leaves the garden | Hidden; resumes 2.5 s after returning |
| Player gets there first, or tucks unprompted | 2a closes at once; a tuck closes 2b; same celebration |
| Pet stowed or swapped | Whichever pet is out leads, with its name. No pet out: no leader; the 2b bubble sits on the nest with the trail from the player |
| Nest not drawn within `NestWait` 6 s, or `nest` off | Skip to prompt 3 without marking; the nest prompt appears when the nest does |
| Bear stuck (under 2 studs in 2 s) | It poofs to the next route point in view |
| Session ends mid-guide | Next session resumes from saved facts (an unfinished guide is exempt from "returning gets none"; veterans still get none) |
| Reduced Motion | No hops or spin; the Bear walks and still looks back |

`lead` off: today's static bubble; the no-timeout rule stays on.

## 2. The trail: "glow steps" (P1, switch `trail2`, every trail)

Applies to `PetTrail` and `ThingsTrail`.

- **Print**: paw, 1.3 studs (was 1.1). Core `#FFF4DC`, a soft outer ring `#FFD86B` at 1.6x the print, 50% alpha. `LightInfluence = 0` so it reads at night. Rest see-through 0.30.
- **Pulse wave**: every 1.2 s a wave runs toward the target, 0.10 s apart per print: scale 1.0 to 1.35 to 1.0 and see-through 0.30 to 0.05 over 0.30 s, with the ring rippling out to 2.2x and fading over 0.4 s.
- **Target ring**: `#FFD86B`, radius 2.2 studs, ripples every 1.2 s in step with the wave arriving.
- **When a pet leads**: the prints are the Bear's own. Each pops in under its feet (0 to 1.2 to 1.0 in 0.15 s) with a soft `pat` tick (new, gain .12, at most one per 0.18 s), running from the Bear back to the player. Prints the player walks over pop away with 2 gold sparkles. At most 12, nearest the player.
- **Life**: a guide trail stays while its prompt is open (no 30 s end). Others keep today's rules.
- **Off-screen chip**: 36 px, pulses 1.0 to 1.15 with the wave.
- **Reduced Motion**: no swell or ripple; see-through breathes 0.30 to 0.15 at 0.5 Hz.

## 3. "You're all set!" (P1, switch `allset2`)

Shows only when all three are truly done, in the garden, no menu open (wait for the deck to close). 5 s; any tap, B or Esc closes it after 0.4 s.

| Time | What |
|---|---|
| 0.0 s | The Bear jumps and spins (0.6 s). 24 Aero bubbles and 16 confetti dots (`#22B8F2`, `#FFB52A`, `#2FCB5A`, `#FF6FA8`) rise from the bottom edge. `charge` cue at pitch 1.0. Haptic tick |
| 0.15 s | Card pops in (0.85 to 1.05 to 1.0, 0.3 s): white glass 85%, 22 px corners, 320 x 210 (360 x 230 max), ink `#0E0F12`. The Bear's headshot (`PetHeadshot`, 72 px) pokes over the top edge |
| 0.3, 0.5, 0.7 s | Three stamps land one by one with a gold tick `#FFC14D`: Pet, Nest, Stars. Each: 1.4 to 1.0 in 0.12 s, `charge` at 1.12, 1.26, 1.5, a tick buzz |
| 0.9 s | Title punches (`PunchScale` 1.45): "You're all set!". `rarity_common` sting, `pop` buzz, one white light sweep across the card |
| 1.2 s | Sub-line: "{pet} loves it here." One gold button: "What's next?" opens Things to do |

Optional, needs Spencer's OK (economy): a one-time "+5 ★ welcome gift" under the stamps. Reduced Motion: no confetti, spin or sweep; sound and buzz stay. Off: today's card.

## 4. The petting screen (P1 slice, P2 rest; switch `pet2`)

`callbacks.pet()` still decides the Star; this is presentation.

**Layout.** Phone (812 x 354): camera 15% closer, the pet fills the middle 50%. Back: a 48 px round glass button, top-left. Top-centre: a glass name pill (name + bond pips). Right edge: the **Happy heart**, 56 x 56, a glass heart that fills from the bottom. Bottom-centre hint pill "Rub {pet}!" that fades after the first rub. PC: same; heart 72 px; pill 16 px text. Aero: edge vignette `#58B8F2` to `#0E5FB8` at 25%, 6 bubbles at 12%, plates white glass 85%, ink `#0E0F12`.

**The hand.** Our own soft mitten sprite, white with a 2.5 px `#1B2A4A` outline. PC: 48 px, replaces the cursor. Phone: 56 px, drawn 28 px above the finger so the thumb never hides it. It tilts up to 12 degrees with the rub direction and squashes to 0.92 on contact. Gamepad: the left stick moves it, X rubs.

**The pet answers.**

- Eyes follow the hand when it hovers. On contact the body leans up to 12 degrees toward the hand (0.2 s ease).
- **Spots**: head (eyes close, slow nod), cheeks (head tilts into the hand, squish), chin (nose lifts), belly (giggle wiggle, a squeak), back (a slow stretch), ears or tail (a twitch and a blink: ticklish, never upset).
- **Favourite spot**: one per pet, picked from its id (no save). Faint sparkles sit there after 4 s of rubbing elsewhere. Rubbing it fills the heart twice as fast and shows "{pet} loves this!" the first time each visit.
- **Build-up**: the heart fills in about 6 s of rubbing. At 33%: small hearts (`#FF6FA8`, white glint), one per 0.5 s. At 66%: bigger hearts, purr pitch up to 1.15, cheeks blush. At 100%: the happy burst: a wiggle-jump, 8 hearts, 10 sparkles `#FFE58A`, the chime, a `pop` buzz, then the heart empties to 20%.
- Drains 5% a second unrubbed. No fail state, no timer.

**Sound.** A purr loop (pitch 0.9 to 1.15 with the heart), a soft `fur_brush` loop (new; gain follows hand speed, 0 to .25), the belly squeak, a `settle` buzz at each third.

**Exit.** Back, B, Esc, or any walk input. The pet waves; 0.3 s camera ease out.

**P1 slice:** the hand, the lean, the Happy heart and burst, the glass plates. **P2:** per-spot reactions and the favourite spot.

## 5. The Welcome deck (P1, switch `deck2`)

Inside the two existing cards; board untouched.

**Left card.** Fill: glass sky gradient `#2FA8F0` to `#0E5FB8`, 1 px white top highlight, 3 rising bubbles at 12%. Top 45%: a looping picture of the step. "Drop a ball!": a 40 px ball falls and squashes (1.6 s loop). "Match two!": two balls bump and become a bigger one. "2 more!" / "1 more!": the numeral, 64 px, sun-gold `#FFD86B`. Under it the line, white, 18 to 34 px; each change punches 1.25 with a `menu` tick.

**Egg card.** Fill `#C9F1FF` to `#58B8F2` with the hatch card's grass arc on the bottom 18%. A soft shadow under the egg. The egg **knocks from inside**: a 5 degree twitch and a quiet tap (gain .15) every 4 s, then 2.5 s, then 1.2 s as combos land.

**Pips.** Three egg-shaped pips, 26 px. Empty: white at 25% with a 2 px `#9FC4FF` ring. Filled: `#FFD86B` with a white glint. The next one to fill breathes 1.0 to 1.12 at 1 Hz.

**Combo moment.** The spark arcs from the merge to its pip (0.35 s, 4 beads behind it); the pip pops 1.0 to 1.4 to 1.0 with a ring; the egg hops (as now); the egg card's border flashes the merged tier's `light` for 0.3 s; a word punches over the well for 0.6 s: "Nice!", "So close!", "It's hatching!". Combo 3: the three pips fly into the egg, one light sweep, then the tuck. Reduced Motion: no loops, arc or knock.

## 6. Onboarding part 2: invites (P2, switch `invites`)

After "You're all set!", the Bear has **one idea at a time**: the same lead, a bubble with a small "x" (parks it, no penalty).

| # | Headline / sub-line | Leads to | Unlocks when | Done when |
|---|---|---|---|---|
| 1 | A toy for {pet}! / Hatch a Toy Egg | egg machine | Stars reach a Toy Egg's cost | a toy is given |
| 2 | Let's go play! / The Pet Park is open | park gate | toy given and 2 rounds played, or session 2 | the player enters; there, one tip: "Throw the ball!" |
| 3 | Race time! / Try the Garden Dash | dash start | park visited, session 2 or later | a race starts |
| 4 | Dress up {pet}! / Try the wardrobe | wardrobe | **waiting on Spencer's decision on redoing the materials, colour and hue system (note 11)**; do not build | a look is changed |

Rules: none within 3 minutes of "You're all set!"; at most one per 5 minutes and two a session; never beside another prompt. Ignored: two nudges, then a "new" dot in Things to do and back next session. Never done by timeout. Off: Things to do only, as today.

## Priority and switches

**P1 (beta 38), in this order:** `lead` (with the no-timeout rule), `trail2`, `allset2`, `deck2`, `pet2` slice one. **P2:** `pet2` spots, `invites` 1 to 3. **Waiting on note 11:** invite 4.

All off is beta (37) plus the bug fixes. New, all ours: the mitten hand, egg pip, paw-wave pose, `pat`, `fur_brush`. Events: `LeadStarted`, `LeadParked`, `NestReached`, `InviteShown`/`InviteDone`. Each slice adds its `V3-TEST-PASS.md` row. Captures for my review: the lead, the trail at night, the all-set card, the deck at 600 x 360.
