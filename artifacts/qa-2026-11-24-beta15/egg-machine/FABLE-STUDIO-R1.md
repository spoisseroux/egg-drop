# Egg machine, Studio capture R1 (Fable, 2026-11-24)

**Verdict: GO WITH CHANGES.** The mesh is right; start the code wiring now. The four "Now" rows are texture, property
and pile-layout fixes that can land beside it; none needs the body, dial or sprout re-modelled. Seen: the four captures
in `studio-r1/`. Not seen: motion, the dusk light, night, the machine from (2.5, 21) or the hub, anything on a phone.

## What I see
- **Noon, path mouth:** reads at once as a cream pot with a heap of coloured eggs and a sprout, and as the one bright
  toy on that side. But the **globe is nearly invisible**: at 0.78 with no streak and no rim, the eggs look like a heap
  on a green tray in open air. The glass is half the idea, so this is the main fix. The 0.78 was my number.
- **Dusk 29:00:** better than noon with no light yet. The glass picks up the pink sky and shows its egg outline, the
  pot turns warm cream, the eggs stay saturated. The PointLight only needs to hold this into night.
- **Base:** at noon it is white, not cream, and matches the marble behind it; the band is a faint smudge. The ribbed
  brush grain is nice and should stay. The highlight is broad and soft: enamel, not chrome. Good.
- **Collar:** still the weakest part. Right size now, but one flat bright green with a hard edge: a plastic saucer.
  The lobes and notches do not read from any capture. Paint can fix it; the mesh is fine.
- **Egg pile:** blunt eggs and the marbled maps are lovely up close. The heap is still a pyramid with empty glass on
  both shoulders: about half full, not "full of eggs". The band is gone or invisible; leave it gone.
- **Dial:** flower reads from the path mouth, knob and emboss no longer merge. Done.
- **Feet, chute, cup:** feet tucked and quiet. Cup is right. The chute reads as a small green arrow, slightly adrift
  of the belly; fine until an egg rolls down it.

## Scale beside the avatar
Right. Globe top sits a head above the avatar, eyes level with the middle of the heap, dial at hand height, cup at the
toes. Change nothing. **Placement (not mesh):** in `noon-close-avatar` the pot stands on lawn with only the cup on
marble, and the dirt path looks under 4 studs away. That fails probe rules 1 and 2; run the probe and try M2.

## Now
| Part | Property | From | To |
|---|---|---|---|
| Globe | Transparency | 0.78 | **0.62**; add the missing highlight streak (upper left, 35% white) and the thin green rim at the collar |
| Base | texture albedo | reads white | true cream `#F4E8CF` at noon (multiply the map about x0.9); band `#D2BE94`, 0.5 tall, crisp edges |
| Collar | texture, finish | flat green, shiny | veins and a dark notch line `#4E9A5A` between the 8 lobes, tips lighter; roughness 0.8 |
| Baked pile | layout | 9 / 6 / 3 cone | add a shoulder ring of 7 at radius 0.95, about 4.7 up, so the heap is a mound that touches the glass; stay under 6,000 triangles |

## Later
- Material against Feature aqua: still one colour at every range. Rule after the light is in.
- Chute: judge its join with the first rolling egg. Sprout is lost against the tree behind; judge with the sway.
- Re-capture noon and dusk from (-20, 12), (2.5, 21) and the hub after the Now rows, at the probed spot, old globe removed.
