# Beta (25) cave, path and terrace audit (2026-11-25)

The audit behind Spencer's beta (25) notes: "the cave entrance is way too smal", "a lot of missing faces or inverted normals etc around teh cave and stairs ramps to terrace / just a lot of messy geometry", "the race entrance in the cave thing needs to be clearer / the model / it kinda belnds in", "everything feels a little too small idk".

The avatar in Studio is 6.4 studs tall (R15 extents 3.2 x 6.4 x 2.1).

## 1. The mouth (capture 01)

- The walk-in opening is the old collision mouth (`scripts/cliff_den_sculpt.py` `MOUTH`): x -14.5 .. 0.5 (15 wide), floor 4.2, top 9.85. That's **5.65 studs clear, shorter than the avatar**. The PlayDen's wooden frame sits inside it, so it reads as a shed door in a cliff.
- The den room behind it (`DEN`): 28 x 18.5, wall top 11.0 (6.8 over the floor), peak 16.0 (11.8 over the floor).
- The rock collar around the mouth (`W7_F_DenMouth`) is 45.5 wide x 18.1 tall: big rock, tiny hole.

## 2. Messy geometry (`mesh-audit.json`, captures 02-03)

Mesh audit of the three uploaded FBXs. Boundary = open edges; flip = edges where neighbouring faces wind opposite ways (one of them renders inside out). Roblox MeshParts are single-sided, so an open edge or a flipped face seen from its back shows as a hole.

| Mesh | Faces | Open edges | Flipped edges | Note |
|---|---|---|---|---|
| W7_F_PathSteps (boulder_rock) | 252 | 444 | **26** | Each step is loose open boxes with mixed winding: the "inverted normals" on the stairs |
| W7_F_PathWall (cliff_rock) | 415 | 446 | 0 | Strips, open along every edge; capture 03 shows stretched tiles, flat slivers and spikes |
| W7_F_TerraceFace (cliff_rock) | 608 | 420 | 0 | Same strip build as the wall |
| W7_F_Stake (wood) | 5 | 4 | 4 | Flipped |
| W7_F_PathFoot, PathGrass, Path | 56-82 | 114-168 | 0 | Open sheets (fine from above, holes from the side) |
| Den shells, lid, mouth | 976-2335 | 18-110 | 0 | Closed enough; the mouth is the size problem |

Also seen in capture 03: thin grey shards standing out of the wall top, a dark triangle sliver, and texture scale jumping between patches.

## 3. The race gate (capture 04)

The Garden Dash gate in the den (`W7D_bay1Gate*`) is two 0.5-stud posts 5 tall with a 4.5-stud bar and a bunting strip: greybox size, the den's own wood colour, no light. It reads as furniture.

## 4. Scale

Everything was sized to the old greybox: the path is 6 wide, the mouth shorter than the avatar, the den 11.8 at its peak, the race gate shorter than the avatar.

## 5. Studio facts found in passing

- The wall, steps and terrace face are already `DoubleSided` in the pack. So the "inverted normals" are the steps' 26 flipped faces (lit from the wrong side, dark), plus open strips seen edge-on, not culled back faces.
- Every pack MeshPart is `RenderFidelity` Automatic. At distance Roblox drops detail from these thin open strips, which can open holes. Round 6: Precise on the den, path and terrace shells (each under 2.4k triangles).
- The beta place has **two** `ServerStorage.WorldFinish` folders. #8 (51 parts, den r8 / path r6: the repo's) is the one mounted, since it comes first. #9 (53 parts, mouth 82037462920460, round 3) is a stale copy. Remove it before the next publish.
