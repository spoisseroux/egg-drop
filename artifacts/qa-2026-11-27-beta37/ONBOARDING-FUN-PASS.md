# Onboarding fun pass: every step ends in a hatch (Fable, 2026-11-27)

For Opus, after beta (38). Spencer: "we want a gacha focused game"; onboarding "not tedious but fun and exciting". Read from code and docs, not played. Anything that grants an egg or Stars is marked **OK?** for Spencer. All original.

**The finding.** The first five minutes hold one hatch, then three errands: pet, walk and tuck (payoff tomorrow), play a whole round. The card stamps the errands and its button opens a list. A gacha game lets you pull again by minute three.

**The new spine.** Bear hatch, pet, tuck and Peek, **gift Paint Egg (crank, pot, the Bear painted)**, Play for Stars, all set with +5 ★, their own first pull.

## 1. The first five minutes, as built

| Beat | Feels like (kid 9 / impatient teen) | Change | P |
|---|---|---|---|
| Welcome deck | Kid: the knocking egg is great. Teen: "2 more!" is a quota | Words become the egg's: "It moved!", "It's cracking!", "It's hatching!" (the gold numeral stays) | P1 |
| Deck to stork | Up to 4 s of nothing (`V2.Hold`); looks frozen | Fill it: the egg knocks every 0.4 s, the card border pulses | P1 |
| Stork | Kid loves it. Teen: 6 s of watching | `total` 6.0 to 4.6 (glide 3.0 to 2.0); Skip at 0.5 s (was 1) | P1 |
| Crack, three taps | The best 5 s in the game | No change | |
| Bear card | One more button, but earned | Keep. Stand beat 1.5 to 0.8 s | P1 |
| "Pet Bear!" | A chore with a 6 s meter | First visit: the heart fills twice as fast (3 s); the burst closes the screen after 0.8 s and the Bear runs out of it | P1 |
| Rest, two hops | Waiting | Rest 2 s to 0 after the first pet; one hop; the run starts within 0.6 s | P1 |
| The lead | The Bear (14) is slower than me (16): I pass it and stand around | Run 18: a chase. Look-back at 12 and resume at 7 stay; nudge after 6 s (was 8) | P1 |
| Tuck | Walked 20 s to be told "tomorrow" | **Peek.** On the tuck the egg wobbles, a crack of light shows its shell colour and a "?" shadow of who is inside (0.9 s), the Bear gasps. Sub-line becomes "Peek inside!". Toast 2 s: "Sweet dreams! It hatches tomorrow." | P1 |
| (new) Gift | | The Paint Egg (section 2, step 1), straight after the tuck | P1 |
| "Play for Stars!" | A whole round to close a prompt | The fact stays. Sub-line becomes "Stars turn the crank!" | P1 |
| "You're all set!" | Kid likes confetti. Teen: three ticks for homework | Stamps shrink to 44 px, 0.08 s apart (was 0.2). Hero is the +5 ★ (section 4). Button "Hatch one!" when Stars cover the cheapest egg (leads to the machine), else "What's next?" | P1 |
| Nest egg appears from nowhere | | The Sleepy Egg comes out of the machine: one free crank, the Bear rolls it to the nest beside it, then the tuck | P2 |

Bubble voice, all prompts: the pet asks, we do not order. Headline in the pet's voice ("Pet me!", "This way!", "Tuck it in!", "Let's win Stars!"). 16 characters still.

## 2. Part 2: the gift chain (switch `gifts`, replaces `invites`)

Gifts are **pulls, never items**: each is a crank at the machine (crank, egg out, then the reveal) and ends with the Bear changed or doing something new.

| # | When | Bubble | What happens | Ends in |
|---|---|---|---|---|
| 1 | Session 1, 1.5 s after the tuck toast. No wait: it is a present | "A gift for you! / A free Paint Egg" (gift icon) | The Bear leads to the machine; its dial wears a ribbon. The player turns it. Welcome Paint Egg: one of the four paint pots, 25% each, shown as its own odds. Card button "Paint {pet}!" | The Bear painted in the garden (section 3) |
| 2 | Stars first cover an egg, garden free | "You can hatch one! / Turn the crank" | Lead to the machine. No gift: their own Stars, their own choice of egg | Their first paid pull |
| 3 | Two rounds after the Bear, or session 2 | "A toy for me? / A free Toy Egg" | Crank, toy reveal, the Bear plays with it on the spot (5 s) | A toy, then step 4 offers itself |
| 4 | Right after step 3's play, or next garden visit | "Let's go play! / The Pet Park is open" | Lead to the park gate; one tip there: "Throw it!" | Reveal card "{pet} learned Fetch!" (a trick card, no economy) |
| 5 | Park visited, session 2 or later | "Race time! / Try the Garden Dash" | Lead to the dash start | First finish, any place: a free Snack Egg ticket, cranked at the machine: "A snack for the racer!" |
| 6 | Session 2 start, nest ready | "It's hatching! / Come and see" | Lead to the nest; the egg hatches by the built path | The second pet |

**No free hat.** The wardrobe is a fixed-price shop; a free hat teaches the shop, not the machine. Outfits join when they come from an egg (an Outfit Egg: Spencer's call). The wardrobe invite stays parked.

**Paint pots leave the shop.** In Dress up > Colour, the 15 Star buy goes. A pot you do not own shows "From Paint Eggs" and a "Show me" trail to the machine. Duplicates are good news: a second Blue is one more depth pip ("Deeper blue!").

**Rules.**
- One at a time. Every bubble has an "x". Never beside another prompt, a menu or the deck.
- After step 1: 3 minutes clear of the last reveal, at most two a session. No timers, nothing expires.
- Ignored: one nudge (the Bear hops, "For you!"), then it parks as a 36 px wrapped-egg chip over the Bear, a ribbon on the machine dial and a "Gift waiting" row at the top of Things to do. Tap any of the three to start it. It waits forever.
- "x": parks at once, same three places, not asked again that session.
- A step done unprompted closes its invite; its gift egg still waits as a chip.
- Returning mid-chain: resume from saved facts; step 6 goes first when the nest is ready.
- Veterans: no leads. Ungranted gifts show as the ribbon and the row, one a session, Paint first, normal pool.
- Accounts that cannot roll: the gift is the next pot in order, same crank, same reveal.

**OK?** three free cranks (Paint 12, Toy 20, Snack 15 Stars of value), each once per save.

## 3. The pull as the hero moment

Built: crank, capsule shot, landing, Aero cards, three tier stings, crack sound and haptics. This is staging only.

**The player turns it (first pull of each egg type, P1 for the gift).** The dial shows a hand. Each tap is a third of a turn: click, tick buzz, the loose eggs hop. Third tap: the clunk and the roll. Untouched 3 s, it turns itself. Later pulls are the built auto crank.

**Anticipation (P1).** The egg lands; the Bear's head follows it down the chute and it hops on the thud. Hold 0.5 s: two knocks from inside (the deck egg's knock), camera 4% closer.

**The honest tell (P1).** No fake near-miss: we never flash a tier or item the egg does not hold. Light leaks from the cracks in the result's true tier colour, and it can only **step up**: every egg starts white-gold; an Uncommon shifts on crack two; a Rare shifts again on crack three with the harp rise. The player learns to watch for the second shift. A Paint Egg also drips its pot's colour from the first crack, so the kid shouts "BLUE!" before the pop.

**Escalation (P1 common and uncommon, P2 rare).**

- Common: pop, sting, card, 1.2 s in all. Fast is a feature.
- Uncommon: plus a 0.3 s hush, the beam, glitter rain 1 s.
- Rare: plus a 0.4 s slow-down, the machine's globe lights, the Bear jump-spins, pets within 20 studs look. A server-wide cheer waits for the clip-moments work.

**The pet wears it at once (P1).** "Paint {pet}!" is one tap: the pot tips over the Bear, colour wipes up its body in 0.6 s, it shakes off drops, looks at its paws, spins; `settle` buzz, 10 sparkles in the pot's colour. Body by default; "Back to white" already exists. Toy: the Bear pounces. Snack: it eats it, a stat pip pops. The card closes into the garden, never a menu.

**Pulls two to five (P2).** "New!" on first finds; a quiet "4 of 10 found" line; duplicates say what they add. "Hatch another" stays plain: no pulse, no Robux offer beside it, no "only N more".

## 4. The +5 ★ welcome gift

Being added to "You're all set!" now. Make it the card's hero: at 0.9 s five gold Stars burst from the Bear's headshot and fly to the wallet one by one (0.08 s apart, `charge` rising); the wallet punches 1.3. Sub-line: "A welcome gift from {pet}." With a first round's Stars it should reach an egg, so "Hatch one!" is the next tap. Once per save.

## Priority and switches

**P1 (beta 39), in order:** `gifts` step 1 (the grant, the lead to the machine, tap-to-turn, the tell, "Paint {pet}!"), the Peek, the timing cuts and words in section 1 (`fun1`), +5 ★ staging, pot buy off. **P2:** gift steps 2 to 6, the Sleepy Egg from the machine, rare escalation, "New!" and found count.

Off is beta (38). Events: `GiftShown`, `GiftParked`, `GiftCranked`, `GiftDone`, `PeekShown`. Each slice adds its `V3-TEST-PASS.md` row. Captures for my review: the Peek, the gift crank and paint wipe at 600 x 360, the tell on all three tiers.

**Spencer decides:** the three free cranks; the Welcome Paint Egg's pots-only pool; removing the 15 Star pot buy; an Outfit Egg later.
