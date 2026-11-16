# v775 QA, 2026-11-16c: say-hi hint and the tip rail

Studio Play, viewport 1649x734 (not a 750x402 fixture: the garden HUD is spread over
several ScreenGuis, so it was not forced to a phone root; `PetRoamHint` spec checks the
line at 733x307, 750x402, 385x703 and 1649x971).

## Before (v775 source)
- `before-0`: the garden tour is open and the rail line under it changes (First round cleared -> Hatch your first egg).
- `before-1` -> `before-2`: the player taps "Hatch your first egg" and reads the card; a few seconds later the garden tour replaces it.
- `before-3`: "E  Say hi to your pet" (x 1457..1637, y 572..604) covers "Pets playing 1/9" (x 1515..1633, y 578..604).

## After
- `after-0`: the tour, open 11 s. The rail holds (the +14 toast waits). Card 2 is "Say hi to your pet".
- `after-1`: "Your first egg", opened by a tap, still open 13 s later with the tour due and a toast queued.
- `after-2`: a tapped "Quest done" line holds under its card (9 s at capture, 18.7 s in the log).
- `after-3`: the park, "Pets playing 1/9" clear; no say-hi hint.

`after-0` and `after-1` come from a harness in the Play client (the real CoachCards,
NotificationRail and HowItWorks modules with a focused-window ctx): the Studio window had
no OS focus, so the game's own garden step would not start. `after-2` is the real rail in
the same harness. `after-3` is the live game.

## Rail log, after (seconds; real rail, real cards)
```
 0.0  rail=Quest done: Chain 3 merges +3
 4.2  card=notice:questReady opened by a tap   rail unchanged
22.9  card closed -> line 1 done               rail empty
25.9  rail=Quest claimed +3                    (3.0 s gap)
29.8  rail empty

 2.5  card=garden (tour)                       rail empty, +14 toast waiting
24.0  tour closed
57.9  card=notice:firstSpend opened by a tap   rail=Hatch your first egg
58.9  tips replay requested + toast queued     nothing changes
77.6  card closed
80.1  tour opens (2.5 s settle)
```
The second block was logged before the last tweak (the rail now also rests 3 s when a card
closes, so the queued toast no longer shows the instant the card closes; NotificationQueue spec).

Untouched lines: 3.9 s on the rail, 3.0 s empty, next line (0.0 / 3.9 / 6.9 / 10.8 / 13.8 / 17.6).
