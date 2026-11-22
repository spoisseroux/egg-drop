# Overnight decisions (2026-11-22)

Spencer, asleep: "make decisions ot move forward by urself". Each row is a choice made without him. All are beta only and behind a flag. Say "undo N" to reverse one.

| # | Decision | Why | How to undo |
|---|---|---|---|
| 1 | Alive can only switch on in the beta place and Studio | A later live hotfix must not leak it | One line in `src/shared/Alive.lua` |
| 2 | No open/close bloop sound; the rustle is the only new sound | Menus already click; his note was that sounds get too loud | Add in step 5 |
| 3 | Menus rise on a spring, they don't scale open | Scaling rebuilds the egg list every frame and shrinks phone buttons | Optional step 7 |
| 4 | Medal at 25: no extra beyond the egg and name piece (Q9). New toys and charms as level rewards wait (Q12) | The scope's recommendations | Later slice |
| 5 | Capes wait for v3.1 (Q10) | The scope's recommendation; needs art on both rigs | Later slice |
| 6 | Medal eggs are worked out from levels and sit outside the 10-egg bank; no Collect key | They can't be paid twice and never block the daily free egg (`V3-LEVELS-BUILD-PLAN-2026-11-22.md`) | Later slice |
| 7 | Level-locked items never go on the weekly shelf or count in Book totals | Adding rows would change this week's picks and everyone's Book percent | Per item |
| 8 | No level-25 badges yet (ids empty) | Creating badges is public and yours to do | Add three ids |
| 9 | Wind also moves pennants x1.8, and gusts run toward Tumble Falls | The brief asked for both; its "south" was a compass slip | One line in `WorldMotion` |
| 10 | Levels stays off on a server until the remote settings load once | If Roblox's settings service is down, nothing level-locked sells by mistake | `LevelsConfig` |
| 11 | Dash maths tuned and merged, but nothing uses it yet: idling earns no medal, dashing all the time costs you, stats clamp within a band (7.6% widest gap), luck never beats a run one trip cleaner | Tuned by simulation only; the line still needs a Studio walk and every number is [P] | Nothing to undo: no script requires it |
| 12 | Fixed the desktop Balls tab (rows 5 to 7 unreachable by mouse) and scroll-to in Balls and Faceplates | Real bugs on live today; in the beta, goes live with your next publish | Revert ed8a1a6 |
| 13 | Medal ring art, recolours, two level faceplates (Sky Fizz, Storm Glass) and six deck effects are Fable's or drawn from shapes | No outside art used | Per item |
| 14 | Garden Dash server and player side merged (9d98503), reviewed and fixed, not published | Nobody has run a race yet; it needs the Studio window | `garden_dash` off, or revert |
| 15 | Stopped building at about 91% of the weekly limit | Leaves usage for your feedback; it resets 4 PM | |
| 16 | Star prizes for races are off unless a remote setting turns them on | Nothing can pay out until you decide | `garden_dash_prizes` |
| 17 | The race route goes around the leaning tree at (38, 8) | Lanes 5 to 8 ran into it, measured in Studio | `scripts/build_dash_course.py` |
