# Fable review: The First Hatch (2026-11-26)

From the six PC stills in `studio/`. Motion, sound and phones not seen; `[check]` = confirm in Studio. Sizes are for the 1649x676 view unless stated.

## MUST (before the test pass)

**1. Taps change nothing you can see.** `tap-the-egg-pc` and `after-first-tap-pc` are the same picture: the zigzag is already there before tap one. "I did that" fails. Add, smallest first:
- a. Squash on tap: 1.0 > 0.92 > 1.06 > 1.0 in 120 ms, plus a cream ring at the tap point, 24 > 64 px, 200 ms.
- b. 6 flakes from the tap point: cream squares 4 to 8 px, thrown up 60 to 120 px, falling, gone in 500 ms. Tap two: 10 flakes.
- c. A drawn crack from the tap point: 3 zigzag segments of 18 to 26 px, 3 px dark brown (about #5A3A22), growing in 90 ms. Tap two forks it with a 2 px Bear-cream glow line inside. Keep the egg still during holds so 2D lines stay put; fade them at the pop.
- `[check]` hide the native zigzag until tap one if cheap. If not, a+b+c still carry it.

**2. Sparks do not read.** At 14 px they are smaller than the "+60" text, with no trail, and two of them overlap (orange on green). I found them only by looking for them.
- 24 px on PC, never under 16 px on phones. White core (40% of the diameter), tier colour, 2 px cream outline.
- Trail: 4 ghost dots, 70/50/30/15% opacity, shrinking.
- Flight 450 ms, ease-in, arc peak 60 px above the straight line. Chain sparks 90 ms apart.
- Landing: keep 1.14; add a 100 ms flash of the spark colour on the egg card border. One spark per merge is right.

**3. The pill looks like a tooltip.** About 130x42 px, navy on blue, centred on the screen, so about 135 px right of the card's centre and outside the frame.
- Centre it on the card, inside, overlapping the bottom edge.
- Brand yellow (the BEAR banner's) with dark ink, 56 px tall, 24 px type; 40 px tall on phones.
- Pulse 1.0 > 1.06 every 1.1 s (the auto-crack beat). Egg idles with a 3 degree wobble every 0.8 s so the hold looks like waiting, not a freeze.
- Reuse the ghost hand: one tap on the egg after 0.6 s.
- Wording: "Tap the egg!" on touch, "Click the egg!" on mouse. `[check]` A and Space also crack it.

**4. Egg on phones: 90 px is too small** (brief said 120+). The column is fixed, so use it: egg at 90% of card width, about 104 wide by 130 tall on 844x390. Take the height from the NEXT card (mostly empty; cut it about 40%). Let the bump overflow the card, no clipping.

**5. Nest: reads as "bedtime", not "present".** A moon over a bare stone disc; no egg anywhere. The ticket sits in the far corner and seems to show before the tuck `[check]`.
- Bubble icon: egg with the moon, not the moon alone.
- After the tuck, an egg stays on the nest with a slow glow (2.4 s).
- The ticket appears only after the tuck and flies from the nest to the rail (500 ms). Wording is good.

## CAN WAIT

- **Two different eggs.** Deck egg: pixel cream with teal specks. Reveal egg: blue spots, green band. Recolour the pixel egg in code to match.
- **Three pips under the deck egg**, one per combo. Keep the goal as "Hatch a friend"; "Merge" in `sparks-pc` is flatter.
- **Bear reveal** shows him turned away, pale on orange `[check]` it opens face-on (the capture may have been spun).
- **"NEXT Toy Egg ready, choose it in Menu"** under the reveal: an errand at the peak. Hide it on the first hatch.
- **"Skip tutorial"** is larger than the goal text; dim it to 60%.
- Sparks could pitch up per chain step.

Nothing here needs new art or audio: all code-drawn shapes and existing sounds.
