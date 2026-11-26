# Fable review: round 6 C+D+E renders (2026-11-25)

Seen: all 17 renders, audit 01, studio-r6 07. Not seen: an avatar for scale, a lit night (Blender has no lamps), phone frame.

**Den: FIX. Path: FIX (small). Terrace: SHIP.**

The sizes are right: the room, the opening and the view out (CAM-DEN-BACK) are what I asked for. The mouth's face is not.

## Must fix

1. **Den, the collar is a brown bandshell.** The shell's reveal runs to z -96.9 (`COLLAR_END`), but the blobs centre at z -99..-102 and the lawn keep-out stops them at -96.6, so no rock covers it. In Roblox that outside is back faces: see-through. Move both buttresses, their feet and shoulders to z -96.8; brow to (-5.5, top+2.4, -96.4), radii (11.6, 2.2, 3.4), so it overhangs 2.5. Lawn keep-out front -96.6 to -93.0.
2. **Den, reveal colour.** Outer 2 studs of the reveal and jambs in the cliff's grey-green (about #6F7D78), graded to #7E6B58 over 4 studs in. No brown visible from CAM-MOUTH30.
3. **Den, backing masses invisible; grass flaps still float** (CAM-MOUTH30 upper left and right, CAM-MOUTH-EAST). Bring the four side masses to z -98.0 and the top one to (-7, 22, -99.0), until each stands 0.8 proud and swallows the flaps; else delete the flaps.
4. **Den, shard field west of the mouth** (CAM-LAWN01, right of the big boulder): stacked cards, cell sizes jumping. One extra mass about (-36, 14, -98.5), radii (7, 8, 3), yaw 10.
5. **Den, Deck screen pure white**, the brightest thing at night. #BFD8D2, emission 0.4 at most.
6. **Path, a lip stone floats in the sky** (CAM-SHELF2, upper left). Sink every stone 0.3; reject any more than 0.2 off the ground.
7. **Path, grass wedges through the treads** (CAM-TURN, two places). Cut the grass strip under each flight.
8. **Path, two flat brown boards at the foot** (CAM-FOOT). Replace with 0.5 x 3.4 stakes or remove.

## Can wait

- Jamb lean 8 to 10 degrees (jambs read vertical).
- Den walls read as smooth plaster; want 5 to 7 stud rock cells.
- Lip stones sparse on shelf 2: one per 7 studs.
- Lookout slab reads flat: raise 0.5 with a skirt.
- Tree renders as a bare trunk, absent from CAM-HUB's skyline: confirm the canopy in Studio.
- Top Lawn toys x1.25.

## Before a beta

Studio captures at CAM-MOUTH30 noon and night with an avatar: lamp pools and hook lanterns are unverified here.
