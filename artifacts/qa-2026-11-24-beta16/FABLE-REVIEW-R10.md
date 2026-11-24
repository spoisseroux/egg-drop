# Sleepy Nest landmark, Studio check R10: look review (Fable, 2026-11-24)

For Spencer's "let's make the egg nest look more substantial like the machines".

**Seen:** `STUDIO-CHECK-R10.md`; all 14 captures in `studio/r10/` (01, 02, 03, 04a, 04b, 05, 06a, 06b, 06c, 07, 08, 09,
10, 11); `NEST-LANDMARK-LOOK.md`; `nest-landmark/FABLE-RENDER-R2.md`; `NestLandmark.lua` constants; `Client.Scale` in
`NestClient.lua`.
**Not seen:** the "Hatch!" pin, the hub and (2.5, 21) angles, a phone, tuck-in in motion, the Bear on the mat (it
never went there). Positions below are arithmetic from the data file, not measured in Studio.

## Verdict: FIX 1, 2, 4, 8, then fit for the beta (16) walk

The landmark itself is a GO. Against 08 (the twig nest) it is a different class of object: a cream pot on green feet
with the machine's collar, a plaited nest, a moon. No re-export is needed for the walk; every fix is a constant or
client code. As captured it is **not** fit: the pill is unreadable in every state.

| # | Item | Ruling |
|---|---|---|
| 1 | Egg size | **FIX.** Per-look sizes, ready = today's twig-nest size. |
| 2 | Leaf across the pill | **FIX.** Move the pill forward, not the leaf. |
| 3 | Ring arc | **GO** at 194. |
| 4 | Empty nest | **FIX.** The landmark never switches off. |
| 5 | Trunk behind the crook | **Do not mirror.** Crook repaint LATER. |
| 6 | Egg through the legs | **LATER.** Acceptable for the walk. Do not raise the box to 4.4. |
| 7 | Matched pair | **Yes** at dusk and close; at noon from the path mouth the nest is still the quieter one, by design. |
| 8 | Feet 0.057 low (R10 row 2) | **FIX.** It is visible: it sinks the pet mat. |
| 9 | Bear on the mat | **LATER** (Sol). Tell Spencer it is a known gap. |

---

## 1. Egg size: FIX

My spec had a wrong premise. "Today it is 1.25 x 1.63" was the **small** look, not the ready one (`Client.Scale`
small 1.25, glow 1.6, rocking 2, ready 2; the mesh at scale 1 is about 0.96 x 1.3). So 1.3 on everything made ready
2.5 x 3.4, and 0.8 on everything makes the napping egg 0.96 x 1.3, lost in a 2.6 opening under a blanket baked for a
1.6 x 2.1 egg.

What the captures show: the **napping** egg in 04b and 06b (scale 1.625, 1.56 x 2.1) is right. It fills the bed and
the draped quilt fits it. The **ready** egg in 06c is too big: it fills the whole opening, tops out at 5.6 and covers
the pill.

Ruling: drop the single `Land.EggScale`. The landmark gets its own table, a narrower range:

| Look | Scale | Egg (wide x tall) | Top (base 2.15) |
|---|---|---|---|
| small | **1.6** | 1.54 x 2.08 | 4.23 |
| glow | **1.75** | 1.68 x 2.28 | 4.43 |
| rocking | **1.9** | 1.82 x 2.47 | 4.62 |
| ready | **2.0** | 1.92 x 2.6 | 4.75 |

- Ready is exactly today's twig-nest ready egg, so nothing shrinks against what players have now; napping is bigger
  than today (1.6 against 1.25).
- Ready's top (4.75) is level with the moon's top (4.75) and 0.45 under the pill (5.2).
- The draped quilt has 0.15 clearance on a 1.6 egg (inner 1.9): rocking at 1.82 just fits. `[check]` tucked + rocking
  for the egg showing through the quilt; if it does, scale the draped quilt's X and Z by egg width / 1.6.
- Growth still reads: 25% from small to ready, plus the existing glow, rock and gold halo.

## 2. Leaf across the pill: FIX, move the pill

Seen in 04a, 04b, 05, 06b ("Hatc[leaf]8 h") and 06c. The leaf is where I put it. My spec left no margin: the awning's
front edge is at z +0.17 and the pill at z 0, and a billboard seen from above leans back about 0.2 at its top, into
the leaf. The fault is the spec's, not the build's.

- Pill bottom edge: **(0, 5.2, -1.0)** nest-local, a fixed world offset toward the nest's front (not a camera-facing
  offset). It sits over the egg's front edge.
- Gift peek tile: **(0, 5.6, -1.0)**. Zzz unchanged.
- Height stays 5.2. Raising it over the awning (6.6+) would detach it from the egg and crowd the "Hatch!" pin at 8.2.
- Not AlwaysOnTop: the pill must still hide behind the trunk and avatars.
- Capture back: napping and ready from the play camera, and from 38 degrees off on each side. If a leaf still crosses
  from the east side, the front leaf gets shortened to 1.8 in the next export (LATER).

## 3. Ring arc: GO at 194

196 leaves 0.5 degrees of margin on the outer edge. **`Corner.RingArc` 194** (+-97) leaves 1.5. Nobody can see 6
degrees missing from the back of a ring (09, 11). This replaces the 200 in my spec.

## 4. The empty nest: FIX

06a is the weakest capture: a dark pot with two rope loops and no light, next to lit lamps. The rule: **the landmark
is a place, so it never switches off.** Only the egg's own things leave.

| Thing | Empty |
|---|---|
| Moon | Day rule or dusk rule, exactly as napping: lit at dusk and night (`#FFE9A6`, range 9, 0.6, halo 1.6). Sways. |
| Awning | Sways. No ready lift. |
| Sign board | **Stays.** With a known pet it keeps its words. With no words to show, the board stays blank with its painted moon. No new string. The rope loops never hang empty. |
| Blanket | Folded on the rim (as built). |
| Bed | Dent showing (as built). |
| Shadow, straw scatter | Stay. |
| Pill, "?", prompt, Zzz, sparkles, pin, peek tile | None. |
| Reduced motion | No sway; the moon still lights. |

So the moon, awning and sign run on the landmark, not on the egg. The 60-stud cut-off still applies.

## 5. Trunk behind the crook: do not mirror

I withdraw the mirror rule. In 01 and 03 the trunk does stand behind the crook, and the crook is lost against it. But
the trunk is also the best backdrop the moon could have: a cream crescent on dark bark at noon (01), a glowing one at
dusk (03, 07). Mirrored to the east, the moon would land on the pergola columns and beside the hanging lamp (the glow
right of the egg in 04b to 06c), and it would cost a re-export of the body, mat and blankets.

What is wrong is the crook's colour, my R2 note 3 again: in 04b and 05 it is the trunk's brown, not peeled wood.
**LATER** (texture repaint only, no mesh): crook to `#B8915E`, bark patches cut to two small ones near the base.

## 6. Egg through the avatar's legs: LATER

10 looks broken, but a player has to jump into the bowl to see it. Acceptable for the walk.

I withdraw the 4.4 box: a flat lid at 4.4 would have players standing on air above the egg, which is worse. Next
slice instead: a **ball** collider on the egg, radius 1.05 at (0, 3.4, 0), client-side, solid only while an egg is in
the bed. Players can stand on the plaited rim; anyone who lands on the egg slides off it.

## 7. Do the machine and the nest read as a pair?

- **Close and mid, noon (11, 02): yes.** Same cream pot, same green feet, same scalloped collar. One potter.
- **Dusk (03, 07): yes, and this is the best the plaza has looked.** Globe and moon are the same warm cream, and 07
  with the ready egg is the frame to show Spencer.
- **Path mouth, noon (01): a pair, but unequal.** The machine is about 2.5 times the nest's height on screen (it is
  nearer and taller), and the nest sits in the tree's shade against the trunk. The drooping collar covers most of the
  cream bowl from that distance, so the nest reads green and brown where the machine reads cream and glass. That is
  the intended order (machine first, nest second), and the bigger napping egg from item 1 stays. If Spencer still
  finds it slight after the walk, the next lever is lifting the collar's droop by 0.2 so more cream shows; not before.
- Against 08 the answer to Spencer's ask is yes: it now has a body, a height (6.6) and a light of its own.

## 8. Feet 0.057 low: FIX

R10 lists this as a note. It shows: the pet mat is 0.06 thick, so at 0.057 low it is under the marble, and in 04a,
04b, 05, 06a to 06c and 10 it reads as three or four orange shards poking through the floor. Opus's Include filter on
`room.World` is the fix. After it the mat sits 0.06 proud (the star inlay is 0.07, so it matches).

## 9. Other things seen

- **Tucked quilt (04b, 06b): GO.** One cloth, star flap over the rim. R2 change 1 is closed.
- **Awning: GO.** It reads as a sprig on the crook rather than a canopy, which rhymes with the machine's sprout. R2
  change 2 is closed.
- **Sign (04b): GO.** Readable, hangs where the machine has its dial.
- **Slipped quilt at ready (06c): GO**, to be judged again with the smaller ready egg.
- **Bear on the mat: LATER** (Sol, a pet rest target at `BearSpot`). Until then the mat is an empty mat; harmless.
- **Chip `AccessibleLabel`** reading "naps for 8 hours" while showing "Hatch egg!": Opus to confirm with a real ready
  state, not a forged one.

## Captures I still need (with the fixes)

1. Napping, tucked and ready from the play camera at noon and dusk, with the pill readable.
2. Empty at night with the moon lit and the sign up.
3. Tucked + rocking for the quilt fit.
4. The mat after the floor fix.
5. Hub and (2.5, 21), noon and dusk, machine and nest in one frame. Not blocking the walk.
