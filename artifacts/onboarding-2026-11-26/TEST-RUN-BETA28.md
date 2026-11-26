# Beta (28) test run: the First Hatch

Runtime f65a2be9, published to Pocket Pals Beta on 2026-11-26. All three parts are on in the beta by default.
Switches: `/onboard opener off`, `/onboard crack off`, `/onboard nestfirst off` (each off is beta (27)).
Start each run with `/freshsave` (your own save shows none of it).

## What to try

1. **Three combos hatch the Bear.** Drop anywhere: the first drop sets off a chain of three merges (the
   notes rise, the deck kicks). The meter reads "Bear 1/3", then 2/3, 3/3, then the hatch. A drop that
   merges nothing does not count. Try it three times, with different first aims.
2. **Crack the egg yourself.** On the Bear's reveal the egg stops before each crack and "Tap the egg"
   shows. Each tap cracks it with the sound and buzz together; three taps, then the pop. Hands off, it
   cracks itself about every second. Mashing it never skips the pop.
3. **Reduced Motion on:** no tap stops, the reveal plays as before.
4. **The nest first.** In the garden say hi to the Bear; the next bubble is the moon (the nest), before the
   toy ball. Tuck the egg in. The rail ticket reads "Hatches tomorrow" (it changes to the ready words once
   the egg is ready).
5. **Leave and rejoin** mid-Welcome and after the hatch: the Bear is never granted twice.
6. **Each switch off in turn:** that piece is exactly as beta (27): the egg fills by charge, the reveal plays
   by itself, the toy comes before the nest and the ticket counts down.
7. **Phone and PC** once each.

## Checked in Studio before publishing (2026-11-26)

- Opener sweep (WelcomeSeed spec): a 3-chain to tier IV on 81 of 81 first aims, Springy and Gentle; no
  aim without a merge; the balls do not move before the first drop. Old starter: 402 of 402 aims merge.
- Live Play: drop 1 a 3-chain, drop 2 a 2-chain, drop 3 missed, drop 4 merged: Bear granted on the third
  combo. Two holds seen on the reveal (the focus click itself released crack 1), each released after 1.1 s.
- Moon bubble straight after hi; "Hatches tomorrow" in the rail: `studio/nest-first-moon-and-ticket.jpg`.
- Specs: offline 92 PASS; Studio CrackRitual 5, BearNeeds 31, Onboard 14.

## Not checked

- The DeckShown and EggTapped events (FirstSession runs on live servers only).
- The tap-to-crack feel with sound on a real device (Studio was unfocused for most of the run).
- A phone.
