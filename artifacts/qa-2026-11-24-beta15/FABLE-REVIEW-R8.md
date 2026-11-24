# Fable review of Studio check R8, beta (16) candidate (2026-11-24)

Look only. Code and probes are Opus's.

**Seen:** `STUDIO-CHECK-R8.md` and all 14 captures in `studio/r8/` (01 to 14). 05, 13 and 14 are about 1200 px wide;
the rest are about 720 px, so anything under about 0.3 studs (straw strands, the pill text) I cannot judge from them.
**Not seen:** 844 x 390, a phone, the card on a phone, the plaza from the hub point and from (-9, 21), the east bench
looking west, any motion or sound. Opus's numbers are taken as given.

Spencer's two asks:
1. "the egg area should just be the egg nest. And the hatch eggs machine should look like a gachapon machine full of
   eggs? With a better, less crowded layout in the plaza, with the egg that hatches hours having a ? tip"
2. "the new area to be part of the same world, just like a level above, and not as big, like a different tier to the
   island"

## Fit to walk?

- **Egg corner: yes, now.** Nothing below blocks it.
- **Upper tier: yes after FIX 1** (colour constants only, no geometry). If FIX 1 cannot land within the hour, publish
  anyway with the note in "Notes for Spencer" below; do not hold the egg corner for it.

## Verdicts

| Item | Verdict | What I see |
|---|---|---|
| Plaza layout, less crowded | **GO** | 01 / 10: the marble is open. The nest is alone at the back under the tree, the arch alone on the right, the machine on the left. The old three-in-14-studs knot is gone. The bench and both egg statues are gone from the walk-in view. One caveat: from the path mouth and the bridge (01, 02) the machine and the Style deck kiosk stand edge to edge and their two pins sit side by side. They touch; they do not cover each other at this resolution. Stay at M5. |
| Machine at M5: scale | **GO** | 05 / 12: a little taller than the avatar, eye level at the middle of the globe, dial at hand height. It reads at once as a capsule machine full of eggs: egg globe, pastel eggs, cream pot, leaf collar, flower dial. Do not enlarge it. |
| Machine: read from the path mouth | **GO** | 01 / 10: the brightest thing on the left and the only glass on the plaza. Small at 23 studs, as specified. At dusk (12) the eggs still read by colour. |
| Attract ring, back arc | **FIX 2** | 05: the west and back part of the ring is a thin gold line on grass. My R2 ruling was to clip it if it showed. It shows. |
| Nest on plain marble | **GO** | 12: it sits; the shadow gives it contact; no rim, no plinth, and it is clearly "just the nest". From the path mouth (01) it is very quiet, a small dark shape with a lavender dot in the tree's shade. That is the design; the chip and the Hatch pin do the finding. |
| Straw scatter, 6 of 15 | **GO** | Opus counted one quadrant (x < -31 and z < -11). I meant the half of the ring toward the tree. Recount by the half behind the nest as seen from the star (z < -11). If 9 or more, nothing to do. If fewer, mirror pieces across until it is 10 of 15. Not visible at capture size either way; never a blocker. |
| "?" disc | **GO** | 13: one line, the clock and the disc, one prompt. The avatar's head covers half of it in the capture; that is the camera, not the pill. |
| "?" card | **GO, FIX 3** | 14: right frame, right lines, one button, no Stars button. Two look points under FIX 3. |
| Tier from the plaza | **FIX 1** | 01, 02, 04, 06, 10: the stacked path supports and the terrace face are the largest single object behind the plaza, one flat mid-grey slab rising above the ridge line, right behind the care arch. It reads as a concrete building, not as a higher piece of the island. Spencer will be answering "is this the same world?" and a grey monolith answers no for the wrong reason. No shaping needed: colour and material do it. |
| Ridge grass and rock through the terrace floor | **LATER (art pass), walk with a note** | 09: a grass mound and rock teeth standing in the floor, walk-through. Not a blocker: it is honest greybox, and it tells us something my 4-stud grid hid: the real crest peaks at 38, 9 over the floor, on the line I drew the Click Walk and beside the Overlook. The art pass must either cut the crest in the re-export or keep it as the tier's rock outcrop and route round it. I will rule that after Spencer's walk. FIX 1 makes the floor home's grass green, so the low tufts stop reading as errors. |
| Zigzag path, 4 legs and 3 landings | **GO for T0** | The grove at the cliff foot is a fair reason and 11 s is acceptable. 07: the near landing is tight but the frame is usable on PC. Cost of the stack: from below you see supports, not a path (06), so the climb does not show from the plaza as I asked. FIX 1's white kerbs and brown treads give it back as a zigzag line. The art pass revisits open sides and the phone camera. |
| Terrace and lookout | **GO** | 08 is the picture I wanted: plaza, stream, the pavilion and the arrival side in one look, lip below eye level. Pole and clump are in. Size and height are Spencer's to judge. |

## FIX list, ordered by impact on Spencer's two asks

**FIX 1 (ask 2, before the tier walk). Give the greybox home's colours.** Constants in the greybox rows, nothing else.

| Surface | Colour | Material |
|---|---|---|
| Terrace floor top, landing tops | home's lawn green, sampled from `W7_Ground__grass` | Grass, matte |
| Terrace face, skirt, every path support, the outer rock edge | home's cliff grey, sampled from `W7_Rocks__cliff_rock` (mid tone, not the seam dark) | Slate or Rock, matte |
| Garden-side lip and all path kerbs | plaza marble, sampled from `W7_Architecture__marble` | as the plaza marble, matte |
| Path treads (the four legs) | home's dirt path brown | Ground, matte |
| Clumps | the cliff grey, one step darker | Slate |
| Tree pole | leave pale | |

No gloss, no neon, nothing new. Recapture 04 and 06 after it, and 01 so I can see the block behind the arch.

**FIX 2 (ask 1, small, not blocking). The machine's ring: front arc only.** Draw 220 degrees centred on the machine's
facing (toward (-26, 7)); nothing behind it. All of that arc is on marble. If an arc costs more than a constant, drop
the radius to 3.0 instead and tell me.

**FIX 3 (ask 1, small, not blocking). The "?" card.**
- The live line under the title ("Hatches in 8 h · Egg 1 of 7") is the smallest text on the card, and it is the
  answer to the question the child just asked. Make it the body size, cream.
- Confirm the body lines are 14 px at native size. In 14 they look nearer 11 or 12 and the right 45% of the card is
  empty. If they are 14, leave them.
- The Got it button shows a gamepad "A" glyph in a mouse and keyboard session. If that came from the test input,
  ignore it; if a mouse player sees it, show no glyph.

## Ruling asked for: "Hatch another" on a Toy result that buys nothing

The dial must never make a full turn with no egg. The result arrives 0.09 s after the press, so **start the buy crank
on the result, not on the press.** A refused or no-change result gets the 15 degree hello nudge and one click, no
churn, no clunk, and does not count as a streak step.

## LATER

- The crest through the floor (above): cut or keep as an outcrop, after the walk.
- `Plaza_InlayStar`: in 05, 13 and 14 it is a flat, saturated yellow star 6 studs across, the brightest thing on the
  floor, in the dial's own hue, between the machine and the nest. In the re-export, tone it to a matte inlaid ochre
  so the machine stays the one bright toy.
- The pink pad with a lamp to the right of the care arch (01, 13). If that is `Pad_Future_B`, it is already ruled out
  in the re-export. If it is something else, tell me its name.
- Card open after `/onboard corner off`: close it. Not a look matter for the walk.
- Zigzag in art: open outer sides, the near landing on a phone.

## Notes for Spencer on the walk

- The tier is blocks only: no art, toys or sound. The questions are: is this the "level above" you meant, is the
  size right, is it high enough.
- Grass and rock poking through the terrace floor are the old hilltop. You walk through them. They go, or become a
  rock feature, in the art pass.
- Your pet waits at the foot of the path for now.

## Captures still owed

844 x 390 from the path mouth, the hub and the Overlook; the card at 844 x 390; noon and dusk from the hub and
(-9, 21); the east bench looking west; a phone clip with sound (open crank, one buy, a streak of three; the walk up
and down).
