# Fable review, world finish in Studio, round 1 (2026-11-25)

Against `WORLD-FINISH-LOOK.md`. Seen: `studio-r1/01` to `06` (Studio, PC, beta, play mode; 01-02 day, 04-06 night).
**Not seen:** any phone frame, CAM-HUB, CAM-FOOT, CAM-SHELF2, CAM-TURN, CAM-ARRIVE, CAM-BENCH, CAM-LOOKOUT, the
steps, the rope, MOUTH30 at night, anything moving. Verdicts below cover only what the six frames show.

## Verdicts

| Slice | Verdict | Why, in one line |
|---|---|---|
| **Den** | **FIX-FIRST** | Island rock hangs through the ceiling, the room is flat-lit pale plaster with no lamp pools, tan holes beside the mouth. Three of the brief's "never" lines broken. |
| **Path** | **FIX-FIRST** | The cut wall in 05 is a pile of intersecting stretched planes with spikes across the tread; from the lawn (02) it is a thin brown stripe with dots, not a shadowed notch. |
| **Terrace** | **SHIP-ON-BETA** | No box, no band, no white; grass top on rock. But the edge is one ruler-straight line about 40 studs long and the face is near vertical: you can point at where it starts. Fix after. |
| **Top Lawn** | **SHIP-ON-BETA** | 06 reads as a playground on a hilltop; swing, slide roof and tree are on the skyline in 02. |
| **Paw Glade** | **SHIP-ON-BETA** | Toys gone, log, stumps, column and bench stay, pale flower patches. Paw reading from shelf 2 not yet seen. |

## The coordinator's notes, checked

- **Rock through the den ceiling: confirmed, and worse than noted.** 04 shows two kinds: thin teal-grey slabs (island
  skin) and tan faceted flaps (island inside faces), across the whole dome and down the right wall to about y 9. Also
  visible above the frame in 03 (both top corners). The checker's "10 of 13,500 rays" does not match what is drawn.
- **Timber frame: correction.** It stays by my brief (section 2, Props). The fault is its proportion, fix 9.
- **Marble pillar: correction.** The standing column in 01 / 02 is lawn ruin dressing about 15 studs east of the
  mouth, not the mouth's marble. It may stay. The real white leaks are the **column stub at the path's foot**
  (01 bottom left, still showing over its boulder) and **two white slivers at the jamb feet** (03, bottom corners).
- **Tan faces left of the mouth: confirmed**, a hole about 14 x 10 studs with loose shards floating in front of it
  (01), plus two more tan holes on the hill face under the path (02, mid and right).
- **Path wall overlapping old rock: confirmed** (05). Also long thin spikes lying across the tread.
- **Den walls smooth: confirmed.** Pale warm grey, even value floor to dome, at night. Reads as plaster or a sand dune.
- **Top Lawn reads well: agreed.**

## Must before beta (22)

1. **Den ceiling and walls, island rock out.** Re-cut `W7F_Region__cliff_rock` by volume, not by picked faces: remove
   every triangle with any vertex inside the shell's outer surface grown 1.5 studs (dome included, up to y 18). No
   partial triangles kept. Check: orbit at CAM-DEN-BACK and CAM-DEN-IN, look straight up and at both top corners;
   nothing but shell. Extend `check_world_finish_den.py` to cast from 5 heights to the full dome and report 0.
2. **Loose shards and tan holes at the mouth.** After fix 1, every island triangle left with a free edge inside 40
   studs of the mouth is either deleted or buried: add two backing masses to `W7F_DenMouth__cliff_rock` (west of the
   mouth, covering the 14 x 10 hole; and the smaller gap east of the brow), same rock map and density. Delete the
   floating slivers and the hanging round boulder west of the mouth. Check: CAM-MOUTH30 noon, no tan, nothing floating.
3. **Den is too bright: make it a cave.** On screen today the walls are about #A89F8C at night; target is base
   #7A6A5C read **in game**, with the wall between two lanterns two stops under the wall beside one. Sky light is
   reaching the room. Opus picks the mechanism (shell or a hidden lid casting shadow, or a darker map); do not add
   lights. Then, if still flat, lower the bake 15% as briefed. Check: CAM-DEN-BACK noon and night; the Deck screen
   and the pet are the two brightest things; lamp pools visible on the back wall.
4. **Den wall reads as plaster.** The bedding is there but the grain and normal are not showing. Raise the normal's
   mid-frequency strength about 2x, add broken value variation (patches 2 to 4 studs, plus or minus 8% value), and
   break each bedding line so no line runs more than 5 studs unbroken. Check at CAM-DEN-IN beside the outside rock:
   same family, darker and warmer. (01 may have had maps still loading; recapture before re-baking.)
5. **Den floor.** Reads pinkish and light (about #A98C78), close to the wall value, no pressed stones visible. Bring it
   to #6E5140 in game, clearly darker than a lit wall pool. The **threshold strip** in 03 is a different speckled
   gravel material: give it the `den_floor` tile so mouth and room are one floor. Check: CAM-DEN-IN.
6. **Deck screen back.** From CAM-DEN-BACK (04) the back of the propped screen is a blank pale pink slab filling a
   third of the frame, the brightest thing in the room. Its back and sides take the stump's dark wood, not Neon and
   not the screen colour. Check: 04 again.
7. **White at the mouth.** Close the two white slivers at the jamb feet (extend the collar or the buttress toes 0.5
   down and in). Enlarge or move the boulder so the column stub at the path's foot is fully hidden from CAM-MOUTH30
   and CAM-FOOT. Check: both cameras, noon and night, no white.
8. **Path cut wall, rebuild the join.** The new cut must replace the island skin behind it, not sit in it: remove
   the island faces inside the cut's volume grown 1.0 stud (same volume rule as fix 1), close the cut mesh to the
   kept island rock with a welded skirt, and re-project its texture so cells are the island's size (no stretched
   smears; texel density within 20% of the neighbouring rock). **Nothing may cross the tread:** delete the spikes at
   the foot of the wall in 05. Check: CAM-SHELF2 and CAM-FOOT, one continuous leaning wall; rerun probe 2.
9. **Tan holes on the hill face under the path** (02, about a third and two thirds along shelf 1). Same cause as fix
   2; cover with the outer dry-stone shoulder or restore the island faces. Check: 02 again, and CAM-HUB.

## After (next art round)

10. **Timber frame proportion.** In 01 and 04 the opening reads as a letterbox: the lintel boards take the top third
    and a wood strip closes the bottom. Raise the lintel's underside so the clear opening is 8+ studs high, and thin
    the board stack to one plank row plus the sign. Check: CAM-MOUTH30 and CAM-DEN-BACK.
11. **Path reads as a stripe from the lawn** (02). The back wall needs to be 3 to 5 high along the middle 60% and its
    lowest stud darker (my D1 fix 2, still open: give that band its own strip mesh). Check: CAM-HUB, a shadowed notch.
12. **Rock fin** (05, left). Still a rounded upright thumb. Lean it 15 degrees, lower it to 5 studs, add the two side
    lobes at different heights so the silhouette is not symmetrical. Check: CAM-TURN and 02.
13. **Terrace edge.** Break the straight run seen in 02: wander the cap's outline 0.5 to 2.5 studs as briefed (no
    straight run over 12), lean the face back 15 to 25 degrees, and make the three grass tongues 3 to 5 studs long
    (only one short one shows). Check: CAM-HUB and CAM-LAWN01, cannot point at where the terrace starts.
14. **Rock scale mismatch.** The hill's lower face has cells about twice the size of the new cut and terrace face
    (02). Match the new pieces to the island's cell size once fix 8 sets it.
15. **Crystals.** Read as lemon blobs (03, 04, and at the mouth's feet in 01). Colour to #C98A3C as seen in game,
    sharper six-sided silhouette with the slanted break showing, scale down 20%. Check: CAM-DEN-IN, amber, not lemon.
16. **Lantern panes.** In 03 the panes are large bright yellow-orange squares; target #C9772E with the frame hiding
    about half. Thicken the crossbars or shrink the panes 25%.
17. **Paw stones.** Read pale blue-white (03, 04). Set #8A8378 in game and sink 0.1; they should nearly disappear.
18. **Crate tops.** The dust sheets read as granite slabs. Cloth colour (#8C8474), soft edge, no speckle.
19. **Apron.** Still close to a rectangle with an orange cast (01). Break the lawn edge more (0.4 to 1.6 as built is
    not reading), pull the colour to the garden dirt path's.
20. **Top Lawn rim boulders.** The grey speckled eggs (06) are a different stone from everything else on the hill.
    Swap to lip-stone kit pieces in the rock material.

## Captures I need for round 2

Each PC and 844 x 390: CAM-MOUTH30 noon and night, CAM-DEN-IN, CAM-DEN-BACK (noon and night), CAM-FOOT, CAM-SHELF2
(down at the glade too), CAM-TURN, CAM-HUB, CAM-ARRIVE, CAM-BENCH, CAM-LOOKOUT night. Wait for textures to finish
loading before the den frames. One clip of a pet climbing the path.
