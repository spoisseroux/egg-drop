# Onboarding v3: follow the Bear, the Sleepy Nest, welcome week (Fable, 2026-11-23)

Spencer, 2026-11-22: "look and build out really effective onboarding by researching exemplary examples from Roblox on line? And making it fit our game?" Sources: `research/ONBOARDING-RESEARCH-2026-11-23.md`, `research/FUNNEL-SNAPSHOT-2026-11-23.md`. Opus architects and builds this on the **beta** only; live is untouched. Everything here is a proposal until built and checked in Studio.

**The problem in two lines.** The first minute works (89% meet the Bear). Then a five-card text tour loses 24%, and nothing in the garden is unfinished when you leave, so 1% come back.
**The answer in two lines.** The Bear teaches by wanting things, one tap each, with no cards. Before you leave, an egg is asleep in a nest with its gift showing and a clock on it.

**Switch (Things pattern):** `FeatureFlags.OnboardingV3`, beta place or Studio only, three runtime keys `onboard_follow`, `onboard_needs`, `onboard_nest`; owner chat `/onboard follow|needs|nest on|off|clear`. Off is exactly today's game.

## 1. The new first session

| When | What the player sees and does |
|---|---|
| **0:00 to 0:30** | Unchanged. The deck is up at once, the "Match eggs. Hatch a friend." pill fades at the first drop, seeded merges pop. |
| **to 1:00** | The Bear hatches and is revealed (unchanged). The garden opens with **no cards**. The Bear faces you with a **hand bubble**. Behind it, by its rest spot, a small egg already sits in a nest with a soft glow. A nest chip sits beside the wallet: egg icon, "8 h". |
| **to 3:00** | Tap the Bear: hearts, the bubble pops. A **ball bubble** appears and the Bear hops toward the Hatch eggs machine, looking back; paw prints follow it. At the machine one line shows on the label ("{pet} found the egg machine!"). You hatch the Toy Egg with the 20 Stars you hold, press **Give to {pet}**, the Bear plays. A **deck bubble** appears. |
| **to 5:00** | Tap the deck bubble: round two. Its results screen ends on the **See you tomorrow** strip. Back in the garden the Bear yawns: **moon bubble**. Prints lead to the nest. You press **Tuck in**; the egg shows what is inside (a hat on a ghost Bear for 2 s, "+10 Stars"), the Bear curls up beside it. Then a **friends bubble** points to the Pet Park. |
| **The moment you leave** | Roblox shows nothing at quit, so the promise is already on screen: the nest chip on the HUD from 0:40, the strip on every results screen, and the Bear asleep by a glowing egg. |

- **Day 2:** you arrive in the garden. The egg is big and rocking; the Bear hops beside it with an **egg bubble**. One tap: the existing hatch reveal, the hat goes on at once. A new egg drops into the nest showing a toy. Stamp 2 and three new quests wait on the strip. The Bear's bubble is the deck.
- **Day 3:** hatch the toy egg; the Bear plays with it. The existing Garden Dash line shows (`dashIntro`), now as a bubble with a flag.
- **Day 7 (the seventh egg, whenever that is):** the last egg gives the **Nest Charm**, a keepsake only welcome week gives, and 25 Stars. One card shows all seven gifts ticked: "Welcome week done!". The nest stays and keeps making small eggs.
- **Returning and veteran players** skip bubbles 1 to 3. They get one rail ticket, "New in the garden" / "{pet} has a nest now." with Show me, and the full welcome week.

## 2. The Sleepy Nest

**What it is.** A woven nest with a cushion, and one **Sleepy egg** in it. The egg grows while you are away. It is the only thing in the garden that changes while you are gone.

**Where.** Beside your pet's rest spot (`GardenLayout` Rest / your `RestAnchors` slot), 4 studs toward the lawn, facing the arrival point so it is in view when you land. Opus confirms it is walkable, not on a path, a find spot or the Dash line. Tonight it is drawn on the owner's client only (like finds); other players seeing it is a later step.

**Timer.** Ready **8 hours** after the egg lands in the nest. The first egg lands the first time you stand in the garden, so a player who quits at 1:30 still has one growing. Three looks by time passed: small and still (0 to 1/3), bigger with a slow glow (to 2/3), full size and rocking (to ready), then **ready**: hops, sparkles, one soft ping when you come within 14 studs. No expiry. No Robux skip, no Stars skip, no ad skip, ever. Server time only.

**What it gives: fixed, shown, never rolled.** The gift is printed on the egg's label and on the chip from the moment it lands.

| Egg | Gift | Stars |
|---|---|---:|
| 1 | The Bear's first hat: the cheapest common Hat with no level gate | 10 |
| 2 | Stars | 15 |
| 3 | A toy: the next unowned toy in `ToyCatalog.PaidOrder` (the fixed-order rule, no roll) | 5 |
| 4 | Stars | 15 |
| 5 | A Neck piece: the cheapest common, no level gate | 10 |
| 6 | Stars | 20 |
| 7 | **Nest Charm** (new floating charm, welcome week only) | 25 |
| 8 and on | Stars | 4 |

- **Welcome week total: 100 Stars, once per save.** That is half of one casual week (200), and it lands in week one when wallets are empty. After it, 4 Stars per egg: at most 84 a week if you never miss an 8-hour window, well under 10% of an engaged week (900). The 2x Stars pass does not apply. Nothing is level-gated and nothing bypasses a gate.
- **Already own the item?** The egg shows its Stars price instead, from the start (hat or neck price, capped at 20; toy 20). Decided by ownership at the time the egg lands, then stored, so the label never changes.
- **Tuck in** is a cosy action, not a gate: the egg grows whether or not you tuck it. Tucking shows the gift close up and puts the Bear to sleep beside it.

**Miss a day: nothing happens.** The egg waits, fully grown, for as long as it takes. The week counts eggs hatched, not calendar days. No streak, no "you missed", no countdown to a loss. The strip says so: "It will wait for you."

**HUD.** A nest chip left of the stamp chip: egg icon, gift icon, "7 h" (hours above one hour, then "40 min"). Ready: the chip glows and reads "Ready!". A tap lays the Show me trail to the nest. Hidden in deck rounds, races and menus like the other chips.

**Results: the "See you tomorrow" strip.** One row under every results screen (`DeckResults`, `DeckResultsInPlace`, `DashResults`), three chips, icons first: **nest** (gift icon + time), **stamp** ("Stamp {count}: {stars} Stars"), **quests** ("3 new quests"). It also shows once on the rail when the player stands still for 60 s after the 5-minute mark. Never a button that must be pressed.

**Notifications.** Opt-in Roblox experience notifications only (`ExperienceNotificationService`, 13+ and eligible players only, checked with `CanPromptOptInAsync`). One prompt, once ever, 3 s after the first Tuck in, never over a menu. Sent only when the egg is really ready, at most one a day, never a second reminder for the same egg. Exact text: **"{pet}'s Sleepy egg is ready to hatch!"** (`{pet}` is a name from our own name list; fallback "Your Sleepy egg is ready to hatch!"). Sending needs a notification string made in Creator Hub (public text: Spencer's OK) and a sender that runs while the player is offline; see question 3. Tonight: nothing is prompted or sent.

**Save fields (hatching save; additive, optional, tolerant, like `coachMask`):**
- `nest = { at = <unix seconds the egg landed>, n = <eggs hatched, 0 and up>, gift = <stored gift id or Stars number>, tucked = <bool> }`. Missing reads "no egg yet"; malformed is dropped at load, never a failed load. Written only inside `HatchProgress.transact`; the claim is one transaction (grant + `n+1` + new `at`), so a retry can never pay twice.
- `firstDay = <game day string, DailyContracts.dayOf>`, written once. Lets the Return funnel see a later-day join.
- New `coachMask` bits, appended: `needHi`, `needToy`, `needDeck`, `needNest`, `needPark`, `nestIntro`, `weekDone`.

## 3. Follow the Bear (replaces the five-card tour)

- **Zero cards in the garden.** The Bear is the guide. While a need is open the Bear stands between you and the target, hops, looks back, and `ThingsTrail` prints run from you to the target with its marker on top.
- **Reuse.** `ThingsTrail` for prints (first trail starts by itself after Say hi; later ones on a bubble tap). `StationAttract` for the machine: while a need points at a station only that station beckons, the others keep the glow breath. `ThingsTips` holds the timing rules (`blocked`, `Idle`, `Settle`) and the cap.
- **One-line tips near things,** on the station's own label, first time within 14 studs, using the saved station bits that already exist (`hatch`, `style`, `companions`, `park`). Not on the rail, not a card.
- **Idle hint.** 20 s in the garden with an open need and no progress: the Bear chirps (existing coo), the bubble hops and the prints replay. Three times per need at most, then it waits quietly.
- **Removed (when the switch is on):** the auto-opened `garden` How it works set (five cards), the three garden beats in `CoachCards` (machines, hub, quest), the always-on "Say hi" line, the `parkInvite` rail line (need 5 takes its place), the "Hatch your first egg" pill. **Kept:** the Welcome pill on the deck, the fill-line card, "Show tips again" in the Pocket menu (the five cards live there for anyone who wants them), Skip nowhere needed because nothing blocks.
- `gardenIntro` is set when Say hi is done or after 60 s in the garden, whichever is first, so everything that waits for "the tour is over" still works.
- **Never interrupt:** a deck round, hatch reveal, greeting shot, open menu or card, race, play date, petting, purchase. A bubble hides during these and returns after 2.5 s free. One bubble at a time. No rail line while a trail runs. Nothing takes the camera or locks movement. Reduced Motion: no hops, bubble fades only.

## 4. The Bear asks for things (need bubbles)

A white glossy bubble over the Bear with one icon, no words. The same words show on the Things to do page as the top row, for readers. A tap on the bubble (or the row) does the next step; nothing is ever more than one tap from starting.

| # | Bubble | A tap does | Done when | It teaches |
|---|---|---|---|---|
| 1 | Hand | Says hi to the Bear | First pet accepted | You can touch your pet; it answers |
| 2 | Ball | Prints to Hatch eggs | Toy given to the Bear | Machines, spending Stars, toys |
| 3 | Pocket Deck | Opens the deck | One round finished | Rounds earn Stars; the deck is always there |
| 4 | Moon | Prints to the nest | Tuck in pressed | Something grows while you are away |
| 5 | Two paws | Prints to the Pet Park | Walked into the park | Other pets and players |

- Each closes with the Bear's own reaction (hearts, toy play, a cheer at the results, curling up, a wave), then 4 s of nothing before the next bubble.
- If the player does the thing unprompted, the need closes silently and the next one comes. If a later one is done first, it is skipped, not replayed.
- Need 2 with fewer than 20 Stars (rare): the bubble is the deck first, then the ball.
- From day 2 the same bubble shows the nest when an egg is ready (egg icon), otherwise nothing: the Bear does not nag a player who has learned the garden.

## 5. Slices, in build order

| # | Slice | Size | Verify in Studio | Funnel step it should move |
|---|---|---|---|---|
| A | **Follow the Bear:** tour and beats off, auto trail to Hatch eggs, station label tips, idle hint, `gardenIntro` rule | S | New save: no card in the garden; prints reach the machine; tip shows once; idle replay 3 times then stops; switch off = old tour | Garden walkthrough done 68% → 80%+; FollowedBearToMachine |
| B | **Need bubbles 1 to 3,** pill removed, Things to do top row | M | Each bubble: tap, done, reaction, next; hidden in every never-interrupt case; phone tap target 44 px or more; gamepad can pick the row | FirstPet, ToyGiven (was First spend 57%), SecondRoundDone |
| C | **Nest, server:** save fields, 8 h timer, gift table, claim transaction, owned-item swap, specs | M | Specs: tolerant load, one payout on retry, clock from server, n caps nothing; a test command moves `at` back 8 h (Studio only) | None alone |
| D | **Nest, garden:** model, three growth looks, ready state, Tuck in, hatch with the existing reveal, need 4, HUD chip | M | Egg at each look; hatch puts the hat on; new egg shows the next gift; chip time matches; fresh join with a ready egg | NestTucked; Return funnel NestHatched |
| E | **See you tomorrow strip** on results and the 60 s rail showing | S | Three chips right on first, second and day-2 results; fits a phone; no overlap with the near-miss item | SecondRoundDone → FiveMinutes |
| F | **Funnel, strict and linear** (below) + custom events | S | Fake AnalyticsService spec: order held, flush on gap close, once only | Makes A to E readable |
| G | Need 5 (park), veterans' "New in the garden" ticket, welcome-week card | S | Park bubble after Tuck in; veteran gets one ticket, no bubbles 1 to 3 | TenMinutes |
| H | Later, not tonight: notification prompt and sender, nests others can see, HUD goal line, shorter round two | M | n/a | D1 |

**Onboarding funnel (strictly linear; the beta is its own universe, so it starts clean there).** Step N logs only after N-1; a step that comes early is held and flushed in order when the gap closes, and also logged at once as a custom event `Early_<name>`.

| # | Step | Our hook |
|---|---|---|
| 1 | BoardReady | Existing `FirstSession` step 1 |
| 2 | FirstMerge | Existing first-merge hook (First drop becomes a custom event) |
| 3 | BearMet | Existing Bear met |
| 4 | InGarden | First Room mode with the character spawned (`Coach.gardenReady` inputs) |
| 5 | FirstPet | `PetContact` award or `GardenCareHost` accept; closes need 1 |
| 6 | FollowedBearToMachine | First Hatch eggs station opened (trail or not) |
| 7 | ToyGiven | First toy equip accepted after the first `toyBuy` |
| 8 | NestTucked | Tuck in command accepted |
| 9 | SecondRoundDone | First round settled after BearMet |
| 10 | FiveMinutes | Session clock |
| 11 | TenMinutes | Session clock |

**Return funnel** (`LogFunnelStepEvent "Return"`, needs `firstDay`): JoinedLaterDay, NestHatched, RoundPlayedDay2, NewNestTucked. **Custom events:** BubbleTapped (which), TrailAuto, TrailTapped, IdleHint, TipShown (which), StripSeen, NestChipTapped, LastStepAtLeave. When this goes live, the live funnel's nine steps are replaced by these eleven on a noted date; compare cohorts from that date only.

## 6. Copy and art

**Strings** (`UICopy.onb3`, in the localization export; whole sentences; `{pet}`, `{stars}`, `{count}`, `{hours}`, `{minutes}`, `{item}`):

| Key | Text |
|---|---|
| need.hi | Say hi to {pet}. |
| need.toy | {pet} wants a toy. |
| need.deck | {pet} wants to watch you play. |
| need.nest | {pet} is sleepy. |
| need.park | {pet} wants to meet friends. |
| need.egg | {pet}'s Sleepy egg is ready! |
| tip.hatch | {pet} found the egg machine! |
| tip.style | Dress up your Pocket Deck here. |
| tip.companions | Care for {pet} here. |
| tip.park | Pets play together in here. |
| tip.nest | This is {pet}'s nest. |
| nest.title | Sleepy egg |
| nest.inside | Inside: {item} and {stars} Stars. |
| nest.insideStars | Inside: {stars} Stars. |
| nest.hours | Ready in {hours} h. |
| nest.minutes | Ready in {minutes} min. |
| nest.ready | Ready! |
| nest.tuck | Tuck in |
| nest.hatch | Hatch |
| nest.tucked | Sleep tight. It will wait for you. |
| nest.next | A new egg is growing. |
| nest.count | Egg {count} of 7 |
| strip.title | See you tomorrow |
| strip.stamp | Stamp {count}: {stars} Stars |
| strip.quests | 3 new quests |
| strip.wait | Miss a day, lose nothing. |
| week.title | Welcome week done! |
| week.line | {pet} loves the garden. The nest keeps growing eggs. |
| new.title | New in the garden |
| new.line | {pet} has a nest now. |
| charm.name | Nest Charm |
| notify / notifyPlain | {pet}'s Sleepy egg is ready to hatch! / Your Sleepy egg is ready to hatch! |

**Art.** No AI-made art or audio; everything is built by hand or drawn by our own scripts.

| Thing | Tonight (by script) | Final |
|---|---|---|
| **Nest** | A ring of 14 short rounded twig parts in two browns from the garden palette, a round cream cushion, three lime leaves. Under 40 parts, anchored, no collision | **Blender:** one hand-modelled woven nest, about 400 tris, with a cushion and a little moon flag. Fable reviews the render |
| **Sleepy egg** | The existing egg mesh (`EggModels`) in a new pale lilac with a cream band; glossy Aero highlight; scale and glow by growth look; rocking by script | Speckle and moon texture drawn by a script (the `build_attract_icons.py` way); no new mesh |
| **Gift preview** | The real item on the existing ghost preview / `ItemIcons` icon on the label | Same |
| **Need bubbles** | In-engine bubble: white round with a tail, 2 px ink outline, soft gloss arc, one icon. Stand-in glyphs first (hand, ball, deck, moon, paws, egg) | Six icons drawn by script in the attract-icon style, uploaded by the coordinator; Fable reviews captures at phone size |
| **Nest chip, strip chips** | `DeckKit` tiles with existing icons plus the egg icon | Same set as the bubbles |
| **Nest Charm** | A small nest-and-egg charm from primitives in `CharmShapeModel`, pet's secondary palette | Fable reviews; Blender only if it reads badly |
| **Sound** | Existing: coo, yawn beat, `machine_attract` ping, hatch reveal | A soft tuck-in chime needs Spencer's pick; none tonight |

Fable reviews real captures of: the garden at arrival (is the nest in view?), each bubble over the Bear at phone size, the egg at its three looks, the strip on a phone results screen.

## 7. Questions for Spencer (built tonight on the recommended answers)

1. **Welcome week gifts: a hat, a toy, a neck piece, the Nest Charm and 100 Stars in all, once per save?** Recommend **yes**. It is half a casual week of Stars, all fixed and shown.
2. **After the seventh egg, the nest keeps giving 4 Stars per egg (8 hours each)?** Recommend **yes**. The other choice is nothing after week one, which removes the reason to look at the nest.
3. **Notifications: may we use "{pet}'s Sleepy egg is ready to hatch!" and set up a sender later?** Recommend **yes to the text, build the sender as its own slice**. It needs you to create the string in Creator Hub, and something that can send while no server is running. Nothing is prompted until then.
4. **The first egg starts growing the moment you first stand in the garden, not only after Tuck in?** Recommend **yes**, so the half of players who leave before five minutes still have an egg waiting.
