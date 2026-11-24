# Beta (14) QA, Spencer, 2026-11-23 (night): triage (Opus)

Source: Spencer's chat message and 5 phone screenshots (Napping egg tag over the arch; Bear reveal; ball bubble at the
cliff; nest bubbles crowded; deck results). Checklist: `TEST-RUN.md`. Standing look rule: ambient world realistic,
textured and matte so the pets stand out.

## Passed
- Ground flowers: "way better". Phone section 9: good. Everything not listed below: good.
- Not done: the second-player test.

## Bugs (find the cause, then fix)
- **B1 Springs:** only the quest log springs; no other menu or button does (phone). Studio check R4 saw the Pocket menu
  rise, so suspect a phone-only path, the beta gate, or menus that open without `Kit.arrive`.
- **B2 Fireflies:** none seen at night.
- **B3 New-player bubbles:** never saw the hand bubble over the Bear; the ball bubble showed but could never be tapped (phone).
- **B4 Fountain:** not heard.
- **B5 Dewdrops:** float under the crowns, not on them; his pet did nothing when one fell.
- **B6 Deck results (phone, shot 5):** the "Power +64" stat row is cut off under the wallet chip (row 22 said fixed).
- Shot 5 also shows the ready quest chip first: fixed after beta 14 (64a987c, Fable R4).

## Quick fixes
- **Q1** The "Napping egg" tag shows from far away (over the arch in shot 1). Short draw distance.
- **Q2** The nest's words are crowded: two bubbles stacked plus the ball bubble on top (shot 4). Declutter.
- **Q3** Bear reveal (phone, shot 2): Back and Meet Bear cut into the preview card.
- **Q4** The constant water ambience is too loud and annoying.
- **Q5** More leaves blowing, with more texture.
- **Q6** Tip chime: a few nice short sounds, random pick and pitch (instead of one fixed sound).

## Features
- **F1 "Coming up" chips tappable:** tapping one closes the Pocket Deck and opens what it points at (egg -> nest,
  stamp -> stamp card, quests -> quest log).
- **F2 Race queue:** leave the queue by tapping its notification, with a confirm; while queued, a visible boundary
  you can't walk out of.
- **F3 Race finish:** the win screen and sound are still anticlimactic. A race song, a win song, a better win animation
  for the pet on the results screen.
- **F4 A night version of the garden song.**

## World (look)
- **W1 Waterfall:** still looks bad, especially from a little way off, where the animated layers can't be seen.
- **W2 Lime trees:** denser, textured leaves.
- **W3 More calm and more excitement in the world:** study well-done chill-out levels.
- **W4 "The world feels a bit small, do we need to scale it up?"**

## Design questions
- **D1** Merge the nest with the egg-hatching station in the plaza (one place for eggs)?
- **D2** Should the Dewdrop fruit do anything?
- W4 above.

## Routing
- Island re-export session (local_a0f7d8a7, already on pool/crowns/fountain): W1, W2, Q4, B4.
- Fable: F3 + F4 + Q6 (sound and the race finish); W3 + D1 + Q2 + F2's boundary look + Q5 + D2 (world and nest).
- Opus builder: B1-B3, B5, B6, Q1, Q3, F1, F2 (plan first, architect, build, review).
