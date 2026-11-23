# World kit review, round 1 (Fable, 2026-11-23)

Judged from seven stills in this folder against `waterfall-r1-wide.jpg`, `waterfall-r1-close.jpg`, `lime-mapped.jpg`.
Motion not seen. Numbers below are in `scripts/build_world_aero_kit.py`.

**Verdict: GO WITH CHANGES for the private beta.** Nothing is broken. Three cheap fixes first: rock colour, foot rock
variety, lip overhang.

## What I see

- **Split crowns:** `hub-split-crowns` and `hub-merged-crowns` match. I find no difference. Pass.
- **Lime gradient:** visible and gentle. Undersides sit deeper, tops keep the drawn lime. Keep as is.
- **Sheets:** the wavy, tapered outline works. The ruler edge is gone. Colour still cobalt, stripes still even: that is
  the map, not this slice. Bow cannot be judged from the front.
- **Lips:** thickness is right now. They still overhang the sheet at both ends and read as a thin bar.
- **Rocks:** too pale. They render periwinkle, near the marble's value, far lighter than the cliff boulders. They look
  dry and plastic. The three foot rocks are one size in an even row. The rim rocks are all on the west side, so the
  ring still reads as a clean circle from most angles.
- **Flank rocks:** I cannot find the two ledge rocks in any still.
- **Artefact:** `pool-edge.jpg` shows a thin white vertical line down the lower sheet, from the lip, near centre.
- **Hub:** saturation 1.0 reads fine. No change.

## Now

| Piece | Property | From | To |
|---|---|---|---|
| Rocks | ROCK_TOP | #9AA8B4 | #74858C |
| Rocks | ROCK_BOTTOM | #5E6B76 | #3F4E55 |
| Foot rock 1 | size; s, o | 2.2, 1.6, 1.8; -3.4, 1.7 | 3.0, 2.2, 2.4; -4.2, 1.4 |
| Foot rock 2 | size; s, o | 1.8, 1.3, 1.6; .4, 2.1 | 1.3, .9, 1.2; -.8, 2.7 |
| Foot rock 3 | size; s, o | 2.4, 1.8, 2.0; 3.8, 1.6 | 2.1, 1.5, 1.8; 3.3, 1.9 |
| Lip upper | over | .5 | .15 |
| Lip lower | over | .6 | .2 |

No change: lip radius, sheet bow 1.5, sheet edge tint #C8D8EE, crown gradient #5FAE2A.

## Marble decision

Stay as is. Do not go to #E6ECF2: it would brighten the marble and lose the grounding. No cool tint either. The grey
map already sits well between white cloud and the cool rocks. Slice 9 marble line is closed.

## Later

- Move one rim rock to the east bend if the pet check allows it.
- Find the cause of the white line (likely a ribbon beam seen edge on).

## Re-capture

- Side view of both sheets, to judge the bow.
- The ledge, framed so the two flank rocks show.
- `falls-close` and `pool-edge` again after the Now changes.
- A short clip: crown sway at breeze and at full gust, and the falls.
- Pool edge with a pet standing in the pool, and one phone frame. Still owed from round 1.

## Round 2 (kit r5, 2026-11-23)

Judged from `falls-wide`, `falls-close`, `pool-edge`, `falls-oblique`, `ledge` (all r5). Motion still not seen.

**Verdict: GO for the private beta.** No more numbers needed in the kit.

- **Rocks:** fixed. The foot rocks now read as dark wet slate and belong to the cliff. Big, small, medium breaks the
  row. The nudge into the pool is fine.
- **Rim rocks:** their sunlit tops still read paler than the foot rocks. Acceptable. Leave.
- **Flank rocks:** seen in `ledge.jpg`. Small, dark, tucked in the corners. Good.
- **Lips:** no longer overhang. Pass.
- **Bow:** `falls-oblique.jpg` shows a clean curve away from the cliff. 1.5 is right. Keep.
- **White line: not fixed.** A thin hard vertical line is still there, now off centre. It shows in `falls-wide` (it
  pokes above the top lip), `falls-close`, `pool-edge` and faintly across the ledge gap in `ledge.jpg`. It runs through
  both falls and the air between, so it is one layer spanning the whole drop, not the sheet. Shift moved it; it did
  not soften it.

## Before live (not blocking the beta)

- Find the line: turn the Aero falls layers off one at a time at the `pool-edge` camera. Then either end that layer at
  each sheet's top and foot, or widen and fade it so it reads as a soft ribbon (Transparency .7 or more at both ends).
- The mossy brown rock on the ledge pool is old mesh. It clashes with the new slate. Hide it under Aero if cheap.
- Still owed: a pet standing in the pool at pet height, one phone frame, and eyes on motion (crown sway at full gust,
  the falls). Spencer's test pass can cover motion.
