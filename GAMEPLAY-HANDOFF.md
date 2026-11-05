# Egg Drop gameplay review brief

Review https://github.com/spoisseroux/egg-drop on `feat/egg-drop-arcade-polish`.
Use the current code, PROTOTYPE.md and PRODUCT-SCOPE.md as evidence. GAME-DESIGN.md
contains earlier ambitions; do not describe those as implemented features.

## Why we need a redesign

The creator tested the private game on a phone. Repeatedly pressing A with little
aiming unlocked all seven creatures relatively quickly. The collection currently
finishes before there is a compelling reason to improve, return, socialize, or
buy cosmetics. Treat this as a failed gameplay/progression hypothesis, not proof
that players need a paid daily drop allowance. Recommend a specific playable loop.

## Identity to preserve

A satisfying jelly merge arcade on a customizable landscape handheld, leading
into Sprout Hollow, a botanical 3D garden with original collectible companions.
The handheld is visible on avatars, with a live board display visible to nearby
players. Strong deformation, playful graphics and pleasant original synth SFX
matter. Broad appeal, including boys. No selected background music currently.

Recent phone fixes add reachable lower thumb controls, forest/toy UI, free-roam
camera, an equipped companion that follows the player, brief pet close-ups, and a
shared actual 24-hour day/night clock. These improve presentation; they do not
create a progression economy or substantial lounge activities.

## Implemented mechanics

- Server-authoritative 2D circle physics. Tray 14 x 19, five tiers, default
  Springy bounce 0.64 with merge kicks. No active items or pet gameplay powers.
- Aim left/right or drag; A drops. Cooldown 0.35s. A repeating tier queue
  `[1,1,2,1,2,1]` and the same four starter jellies begin every round.
- Matching tiers merge into the next tier. Matching tier V jellies disappear,
  free space and award a 100-point clear bonus. Cascades can happen automatically.
- Each merge within 1.25 seconds extends the chain. Score gain is
  `10 * (merge tier + min(chain - 1, 9))`, plus the clear bonus. The reported
  merge tier is the resulting tier, or V for a clear.
- Overflow above Y=14.6 for 1.1s ends a round. Fresh drops have entry grace.
  A population of 32 also ends it. There is no round timer or drop budget.
- Retry starts a new tray with the same seed and queue. Earned pets, trial
  completions, hatch charge and personal best carry over. Entering the lounge
  pauses the current board; returning resumes it.
- Every merge adds its tier in hatch charge. Base unlocks are a fixed sequence:
  Pip costs 6, Puddle 12 more, Wick 24 more, Orbit 36 more. Charge is spent at
  each hatch. These are deterministic unlocks, with no randomized hatch odds.
- Rare variants: Bloom Pip for 250 points in one round; Foxfire Wick for a
  five-merge chain; Eclipse Orbit for two tier V pair clears in one round.
  These are permanent achievement unlocks. There is no duplicate system.
- Three basic Pocket Trials earn a cosmetic Club sticker. There are five shell
  finishes and stickers, journal/equip, pet greeting, round recap, first-hatch
  tutorial, sound level and reduced-effects settings. Published saves exist.
- Seven implemented creatures total. The lounge currently has two UI stations,
  roaming and greeting; no meaningful pet care, expeditions, housing or trading.
- No implemented shop, currency, products, passes, paid hatches or daily limits.

## Questions to resolve

1. Diagnose why center/A spam succeeds. Which physics, tier-clear, queue and
   encounter changes create legible skill, choices and recoverable mistakes?
2. Specify the first 30 seconds, 5 minutes, 20 minutes and a return visit. Keep
   the first companion approachable while making later achievements satisfying.
3. Choose a coherent core structure: endless arcade, bounded challenge rounds,
   or free play plus expeditions. Compare three concrete options and recommend
   one. Avoid feature accumulation. Explain what losing and succeeding mean.
4. Design a small, testable progression model: initial roster versus long-term
   collection, common/rare acquisition, unlock pacing, meaningful goals after
   the collection, optional repeat rewards, and sustainable content scope.
5. Give Sprout Hollow and companions a purpose connected to arcade decisions
   and social play. Define useful activities rather than another row of menus.
6. Recommend things players could willingly buy: handheld/sticker cosmetics,
   animations, world decoration, optional expansions, etc. Critically compare
   that with paid extra daily drops. Do not presume an energy paywall solves
   boredom. Separate engagement hypotheses from monetization hypotheses.
7. Check current Roblox policy and regional restrictions if proposing paid
   random rewards or similar mechanics. Cite primary sources; do not invent
   revenue, audience behavior, odds or benchmark figures.
8. Deliver recommended numerical starting values, economy sources/sinks if
   justified, state transitions, edge cases, server/client responsibilities,
   rollout order, and an implementable vertical slice. Label assumptions.
9. Provide falsifiable tests: an A-only baseline versus intentional aiming,
   round length/success/overflow distributions, time to each pet, comprehension,
   voluntary replay, and return intent. Set provisional acceptance targets and
   explain how to validate them with phone and multiplayer playtests.

Useful code: `src/shared/BoardConfig.lua`, `PetCatalog.lua`, `PocketTrials.lua`;
`src/server/BoardSimulation.lua`, `BoardRound.lua`, `PlayerProgress.lua`,
`init.server.lua`; `src/client/init.client.lua`, `RoomView.lua`, `RoundRecap.lua`.

Give a clear recommendation and staged build plan. Challenge the assumptions.
Ask questions only when an answer would materially change that recommendation.
