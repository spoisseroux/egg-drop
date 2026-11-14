# Blip v2 concepts (2026-11-14)

Spencer: "can we make blip look a little more different than bear". Concept renders only: nothing exported,
nothing in Studio, nothing committed. v1 (`pet-blip.blend`, `scripts/build_blip.py`) is untouched.

- Sheet: `blip-v2-contact-sheet.png` (each variant beside the Bear: front, three-quarter, side)
- Phone: `blip-v2-phone-96px-silhouettes.png` (true 96 px tiles and silhouettes, plus the same pixels 3x; Bear and v1 for reference)
- Build: `scripts/build_blip_v2.py -- <A|B|C> [--render DIR] [--save]`, sheets: `scripts/blip_v2_sheets.py DIR`
- Saved blend: `assets/art-source/pets/pet-blip-v2.blend` holds the pick (C). A and B rebuild from the script in seconds.

All three: original shapes built by script from the shared plush base, no generated art. Same face kit (the
Bear's eye mesh at v1 size, mouth, pale snout spot), same 46 anchor names, same piece names and topology
(only vertices move; antennae and tail are rebuilt as in v1). Height 1.56 (v1 1.57, Bear 1.48).
Tris: A 1262, B 1262, C 1310 (v1 1262).

## A "Bean"
- Thick capsule body (half-width 0.42, was 0.30) that meets the head with no neck.
- Head lower and flatter (height x0.86), slightly broader on top.
- Arms 60% length, set out on the flanks as nubs. Feet 20% wider, 15% taller.
- Antennae wider apart (base x 0.34, was 0.27), thicker stalks, bobbles r 0.12 (was 0.098). Curl tail 15% bigger.
- Read: sturdy toy robot-bean. Clearly not the Bear, but the head is still the v1 head, so it is the mildest change.

## B "Saucer"
- Wide, low, flat head (width x1.16, height x0.76), eyes set 20% wider apart (x 0.257, was 0.215).
- Small pear body (Bear-sized), arms 70% length, feet unchanged.
- Long V antennae out at the edges of the head (base x 0.42), bobbles r 0.125.
- Read: strongest silhouette at 96 px (a wide bar on a small body). Most "alien", least cuddly; the head overhangs a lot in side view.

## C "Sprout" (pick)
- Egg build: body wider than the head (half-width 0.49), head tapers to the top (top 28% narrower), sits 0.05 lower.
- Arms 55% length as flank nubs, feet 25% wider. Curl tail 10% bigger.
- Drooping feelers: stalks arc up and out, bobbles (r 0.11) hang at x 0.53, z 1.35.
- Read: its own little species (snail/sprout creature), softest and friendliest face, silhouette unlike the Bear in every view.

## Refit impact (nothing refitted yet)
| Slot | A Bean | B Saucer | C Sprout |
|---|---|---|---|
| Hats (beanie, sunhat, crown) | refit: crown 0.12 lower, flatter top; stalks clear (0.26 vs limit 0.19) | refit: crown 0.16 lower, flat top; stalks well clear (0.355) | **blocked as drawn**: stalk bases at 0.13 are inside the 0.19 hat limit. Move bases to about x 0.26 (the arc still works) or hats sit between/through the stalks; then refit to the narrower dome |
| Horns | re-seat only | re-seat only | tight: horn anchors (x 0.10) are next to the stalk bases, check S4/S5 |
| Eye items (specs, alt eyes) | height only (eyes 0.035 lower) | refit: eyes wider apart and 0.06 lower | height and depth (eyes 0.04 lower, 0.05 further back) |
| Mouth items (blep, W mouth) | re-seat | re-seat | re-seat |
| Ear / helix / lobe (studs, rings) | re-seat | re-seat (head side moved out to 0.52) | re-seat (head side moved in to 0.32) |
| Tee, hoodie, beads, collar | **full refit**: body 40% wider, squarer | none: body is Bear-sized (pear, check the hem) | **full refit**: body 63% wider, egg-shaped |
| Wrist / hand items | refit: arm shorter, shoulder moved out | small refit | refit: arm shorter, shoulder moved out |
| Feet / ankle items | refit (bigger feet) | none | refit (bigger feet) |
| Tail items (bow tail) | re-seat (anchor moved with the back) | re-seat | re-seat |
| Wings, back | re-seat | re-seat | re-seat |
| Floating charm | fine | CharmLeft/Right (x 0.60) sit inside the bobbles (x 0.54 to 0.67): move out | CharmLeft/Right close to the bobbles (x 0.42 to 0.64): move out |

Also for whichever variant goes to production: the hidden alt eyes and W mouth were re-seated by the same code
but not rendered or checked; rig data, hit boxes and the nod pivot (Anchor_Head moved down 0.03 in A, 0.05 in C)
need a pass; the 96 px check here is on a neutral backdrop, not on garden grass.

## Pick
**C Sprout.** It is the only one where body, head and antennae all stop echoing the Bear, and it has the
friendliest face. Cost: the biggest refit (body items, hats), and the antenna bases must move out to about
x 0.26 before hats can fit. If refit budget decides it, **B Saucer** is the cheap route: body items carry over
as they are and hats clear the stalks, but it is the least cuddly. A is the safe middle and the least different.

## Housekeeping
The first render pass wrote its tiles to `C:\artifacts\blip-v2-2026-11-14\raw\` (Blender resolved a relative
path against the drive root; fixed in the script). They are copies of iteration 1 and can be deleted; a safety
check stopped me removing that folder myself.
