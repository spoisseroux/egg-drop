# Art mockups, 11 November 2026

First-pass blockouts built by script in Blender 5.2. They are meant to be reshaped by hand: scale, origins, names, L/R splits and colour-role splits are the parts to keep. Nothing here has been imported into Studio yet, and nothing is committed.

Common to all three files: Unit System None, degrees, Z up, front toward -Y. Every mesh has scale 1 / rotation 0, outward normals, one Smart UV Project layer, one flat Principled material, no loose vertices and no non-manifold edges (checked by script). FBX files were exported with the settings in the brief (selection only, FBX Units Scale, -Z forward, Y up, Face smoothing, meshes only).

**Deviation that applies everywhere:** there is no live Subdivision modifier and no cage. Shapes were generated directly at subdiv-1-equivalent density (all-quad rounded blobs, swept tubes, bevelled boxes), so sizes are exact instead of shrinking under Catmull-Clark. Flat planks (table tops, sign boards, screens) are bevelled boxes, not subdivided, to keep their faces flat. Many objects are several overlapping closed shells in one mesh; merge or retopologise as you like.

Renders in this folder are Workbench renders (Standard view transform), so colours are flatter than EEVEE.

## 1. assets/art-source/features/features.blend + features.fbx

Modelled at head width = 1 unit, stage 5. `REF_Head_Width_1.0` (1-unit sphere) was added to the existing `REF_Scale` collection at (0, -3, 0.5). That collection is left as it was found (visible in the viewport, hidden from render). The Zivvi template, anchors, camera and light are untouched; the previous file is kept as `features.blend1`. The FBX contains only the 16 meshes in `Features`.

| Object | Size W x D x H | Tris | Origin (world, in the .blend) | Notes: extents relative to origin |
|---|---|---|---|---|
| Horn_R_Base | 0.118 x 0.106 x 0.060 | 192 | (0.260, -3.000, 0.915) | x[-0.059,0.059] y[-0.053,0.053] z[-0.010,0.050] |
| Horn_R_Tip | 0.116 x 0.103 x 0.257 | 240 | (0.260, -3.000, 0.915) | x[-0.044,0.073] y[-0.046,0.057] z[-0.019,0.238] |
| Horn_L_Base | 0.118 x 0.106 x 0.060 | 192 | (-0.260, -3.000, 0.915) | x[-0.059,0.059] y[-0.053,0.053] z[-0.010,0.050] |
| Horn_L_Tip | 0.116 x 0.103 x 0.257 | 240 | (-0.260, -3.000, 0.915) | x[-0.073,0.044] y[-0.046,0.057] z[-0.019,0.238] |
| Claw_R_Base | 0.122 x 0.058 x 0.052 | 216 | (1.700, -3.000, 0.500) | x[-0.061,0.061] y[-0.041,0.017] z[-0.026,0.026] |
| Claw_R_Nail | 0.115 x 0.144 x 0.056 | 288 | (1.700, -3.000, 0.500) | x[-0.058,0.058] y[-0.142,0.002] z[-0.026,0.031] |
| Claw_L_Base | 0.122 x 0.058 x 0.052 | 216 | (1.300, -3.000, 0.500) | x[-0.061,0.061] y[-0.041,0.017] z[-0.026,0.026] |
| Claw_L_Nail | 0.115 x 0.144 x 0.056 | 288 | (1.300, -3.000, 0.500) | x[-0.058,0.058] y[-0.142,0.002] z[-0.026,0.031] |
| Wing_R_Root | 0.089 x 0.052 x 0.103 | 108 | (-1.400, -3.000, 0.500) | x[-0.024,0.064] y[-0.026,0.026] z[-0.036,0.066] |
| Wing_R_Fan | 0.269 x 0.049 x 0.276 | 492 | (-1.400, -3.000, 0.500) | x[0.024,0.293] y[-0.024,0.025] z[-0.112,0.164] |
| Wing_L_Root | 0.089 x 0.052 x 0.103 | 108 | (-1.600, -3.000, 0.500) | x[-0.064,0.024] y[-0.026,0.026] z[-0.036,0.066] |
| Wing_L_Fan | 0.269 x 0.049 x 0.276 | 492 | (-1.600, -3.000, 0.500) | x[-0.293,-0.024] y[-0.024,0.025] z[-0.112,0.164] |
| Horn_Bud_R_Base | 0.100 x 0.092 x 0.046 | 192 | (0.260, -4.200, 0.000) | x[-0.050,0.050] y[-0.046,0.046] z[-0.007,0.039] |
| Horn_Bud_R_Tip | 0.066 x 0.062 x 0.078 | 192 | (0.260, -4.200, 0.000) | x[-0.029,0.037] y[-0.029,0.033] z[0.006,0.084] |
| Horn_Bud_L_Base | 0.100 x 0.092 x 0.046 | 192 | (-0.260, -4.200, 0.000) | x[-0.050,0.050] y[-0.046,0.046] z[-0.007,0.039] |
| Horn_Bud_L_Tip | 0.066 x 0.062 x 0.078 | 192 | (-0.260, -4.200, 0.000) | x[-0.037,0.029] y[-0.029,0.033] z[0.006,0.084] |

- Materials: `Secondary` (#F2A7C3 placeholder pastel) on Base/Root, `Ivory` (#F4F2E8) on Tip/Nail/Fan.
- Horns: origin at base centre, rise 0.238 above the origin, curve outward and slightly back. The collar is 0.118 wide (brief: about 0.09) because a 0.09 collar read as a thin ring under a stubby horn. The tip dips 0.019 below the origin so it buries into the head.
- Claws: origin at the base, nails reach -Y 0.142. Both nails are one `Nail` mesh and both toe beans are one `Base` mesh.
- Wings: origin at the shoulder joint, tip at X 0.293 from the origin, three lobes. The fan is flat in the XZ plane (0.05 thick).
- `Horn_Bud_R/L` is split into `_Base` + `_Tip` like the full horn (the brief named a single mesh). It is 0.084 tall, a dome, not a scaled horn.
- Tris per piece (base + tip): horn 432, bud 384, claw 504, wing 600.
- Canonical layout: horns sit on the REF head at X +/-0.26 (the code's offset); wings at X -1.5 +/-0.10; claws at X 1.5 +/-0.20; buds on the ground at Y -4.2.

`Preview_OnZivvi` (not exported): mesh copies scaled by Zivvi's head width 1.32 with transforms applied, using Zivvi's secondary and ivory materials. Their origins are at the world origin; they are for looking at, not for export.
- Preview horns are at X +/-0.264, Y -0.20 on the forehead, tilted with the surface. At the code's 0.26 x 1.32 = X +/-0.343 on the head centreline they land on Zivvi's ear bumps, so the code offset will need a forward nudge or a smaller X for this pet.
- Preview claws are on the front of each hand; preview wings are on the back of the body at X +/-0.132, Z 0.66.

Unsure / for the hand pass:
- Horn silhouette is closer to a little devil horn than intended; a fatter curve may be cuter while keeping the 0.25 rise.
- Claws at 0.15 x 1.32 are long on Zivvi's small hands. Consider a smaller stage-5 length and tell Claude the number.
- Wings at 0.30 spread barely clear the head silhouette from the front on Zivvi. They probably want to be 1.5 to 2 times bigger; the origin stays at the shoulder.
- Feather lobes are plain ellipsoids; the overlap and a scalloped trailing edge need doing by hand.

## 2. assets/art-source/toys/toys.blend + toys.fbx

Modelled at pet body height = 1 unit. Each toy has a root Empty (`Ball`, `Bone`, `Sparkler`) at the pivot, and every colour part's origin is at that same pivot. The Empties are not in the FBX (meshes only), so the parts arrive flat with the right pivots. The `REF` collection (avatar 5.5, baby 1.5, `REF_Pet_Body_Height_1.0`) is hidden in the viewport and render.

| Object | Size W x D x H | Tris | Origin (world, in the .blend) | Notes: extents relative to origin |
|---|---|---|---|---|
| Ball | EMPTY | - | (-0.350, 0.000, 0.120) |  |
| Bone | EMPTY | - | (0.150, 0.000, 0.060) |  |
| Sparkler | EMPTY | - | (0.650, 0.000, 0.000) |  |
| Ball_Body | 0.228 x 0.228 x 0.228 | 432 | (-0.350, 0.000, 0.120) | x[-0.114,0.114] y[-0.114,0.114] z[-0.114,0.114] |
| Ball_Band | 0.239 x 0.240 x 0.100 | 240 | (-0.350, 0.000, 0.120) | x[-0.121,0.118] y[-0.121,0.119] z[-0.051,0.049] |
| Ball_Dots | 0.113 x 0.039 x 0.165 | 216 | (-0.350, 0.000, 0.120) | x[-0.065,0.048] y[-0.103,-0.064] z[-0.075,0.090] |
| Bone_Shaft | 0.205 x 0.062 x 0.063 | 112 | (0.150, 0.000, 0.060) | x[-0.102,0.102] y[-0.031,0.031] z[-0.031,0.032] |
| Bone_Ends | 0.328 x 0.074 x 0.127 | 768 | (0.150, 0.000, 0.060) | x[-0.164,0.164] y[-0.037,0.037] z[-0.063,0.063] |
| Bone_Wrap | 0.097 x 0.069 x 0.071 | 64 | (0.150, 0.000, 0.060) | x[-0.017,0.079] y[-0.034,0.034] z[-0.032,0.038] |
| Sparkler_Grip | 0.057 x 0.060 x 0.192 | 180 | (0.650, 0.000, 0.000) | x[-0.029,0.029] y[-0.030,0.030] z[-0.011,0.181] |
| Sparkler_Wire | 0.040 x 0.017 x 0.136 | 108 | (0.650, 0.000, 0.000) | x[-0.005,0.034] y[-0.009,0.009] z[0.158,0.294] |
| Sparkler_Head | 0.128 x 0.062 x 0.118 | 372 | (0.650, 0.000, 0.000) | x[-0.033,0.095] y[-0.031,0.031] z[0.270,0.388] |
| Spark_1 | 0.039 x 0.022 x 0.036 | 108 | (0.592, 0.000, 0.384) | x[-0.019,0.019] y[-0.011,0.011] z[-0.018,0.018] |
| Spark_2 | 0.030 x 0.022 x 0.045 | 108 | (0.684, 0.000, 0.423) | x[-0.015,0.015] y[-0.011,0.011] z[-0.023,0.023] |
| Spark_3 | 0.040 x 0.022 x 0.035 | 108 | (0.770, 0.000, 0.381) | x[-0.020,0.020] y[-0.011,0.011] z[-0.018,0.018] |
| REF_R15_Avatar_5.5 | 2.000 x 1.000 x 5.500 | 12 | (2.600, 0.600, 0.000) | x[-1.000,1.000] y[-0.500,0.500] z[0.000,5.500] |
| REF_Baby_Body_1.5 | 1.500 x 1.500 x 1.500 | 12 | (-2.200, 0.600, 0.000) | x[-0.750,0.750] y[-0.750,0.750] z[0.000,1.500] |
| REF_Pet_Body_Height_1.0 | 0.800 x 0.700 x 1.000 | 12 | (-0.950, 0.600, 0.000) | x[-0.400,0.400] y[-0.350,0.350] z[0.000,1.000] |

- Whole toys: Ball 0.239 x 0.240 x 0.228, 888 tris. Bone 0.328 x 0.074 x 0.127, 944 tris. Sparkler 0.217 x 0.062 x 0.457 including sparks, 984 tris.
- Ball origin is the centre; the body is 0.228 and the cream band takes it to 0.24.
- Bone origin is the centre, length along X.
- Sparkler origin is the bottom of the grip (the rounded end cap dips 0.011 below it). `Spark_1..3` are separate meshes with origins at their own centres so they can be animated individually; say if they should sit at the grip pivot instead.
- Colours follow the current code palette (coral/cream/teal, ochre/seafoam, indigo/brass/citrine). `Toy_Spark` is emissive.

For the hand pass: the ball band is a thin shell sitting about 0.006 proud of the body and its edge is rough; the bone wrap is off-centre on purpose; the sparkler head is a ball with three prongs and wants a real seed-pod shape.

## 3. assets/art-source/stations/stations.blend + stations.fbx

All on Z = 0 in a row along +X with 4-stud gaps between bounding boxes, starting after the REF avatar at X 0 (the REF baby is at Y -3). `REF` is left visible in this file so the avatar is in the row. Multi-colour props are a root Empty at the ground pivot with one single-material mesh per colour role, each with its origin at the root; single-colour props are one mesh. Empties are not in the FBX.

Heights are relative to the ground. Today's LoungeArt floor is Y 4.0, so today's table top surface is 2.63, the bench top 0.77 and the pet sole in the care cradle 1.18.

| Object | Size W x D x H | Tris | Origin (world, in the .blend) | Notes: extents relative to origin |
|---|---|---|---|---|
| **CareMachine** (whole asset) | 5.15 x 2.25 x 4.66 | 3004 | (7.57, 0.00, 0.00) | x[-2.57,2.57] y[-1.12,1.12] z[0.00,4.66] |
| **HatchTree** (whole asset) | 20.45 x 11.27 x 14.26 | 4396 | (22.62, 0.00, 0.00) | x[-8.47,11.98] y[-5.66,5.61] z[0.00,14.26] |
| **Workbench** (whole asset) | 5.65 x 2.89 x 4.93 | 1756 | (41.43, 0.00, 0.00) | x[-2.83,2.83] y[-1.12,1.76] z[0.00,4.93] |
| **JournalStand** (whole asset) | 2.70 x 1.85 x 3.24 | 900 | (49.60, 0.00, 0.00) | x[-1.35,1.35] y[-0.97,0.88] z[0.00,3.24] |
| **Lantern** (whole asset) | 0.90 x 0.90 x 3.64 | 908 | (55.40, 0.00, 0.00) | x[-0.45,0.45] y[-0.45,0.45] z[0.00,3.64] |
| **Bench** (whole asset) | 5.30 x 1.46 x 0.77 | 648 | (62.50, 0.00, 0.00) | x[-2.65,2.65] y[-0.73,0.73] z[0.00,0.77] |
| **Signpost** (whole asset) | 2.45 x 0.57 x 2.01 | 328 | (70.38, 0.00, 0.00) | x[-1.22,1.22] y[-0.28,0.28] z[-0.00,2.00] |
| **Rock_01** (whole asset) | 0.62 x 0.53 x 0.35 | 192 | (75.91, 0.00, 0.00) | x[-0.31,0.31] y[-0.26,0.26] z[0.00,0.35] |
| **Rock_02** (whole asset) | 1.00 x 1.00 x 0.59 | 192 | (80.72, 0.00, 0.00) | x[-0.50,0.50] y[-0.50,0.50] z[0.00,0.59] |
| **Rock_03** (whole asset) | 1.55 x 1.25 x 0.87 | 384 | (85.85, 0.00, 0.00) | x[-0.64,0.91] y[-0.62,0.62] z[0.00,0.87] |
| **Rock_04** (whole asset) | 2.28 x 1.88 x 1.32 | 384 | (91.70, 0.00, 0.00) | x[-0.94,1.34] y[-0.94,0.94] z[0.00,1.32] |
| **Rock_05** (whole asset) | 3.67 x 2.72 x 1.86 | 492 | (98.81, 0.00, 0.00) | x[-1.77,1.90] y[-1.40,1.32] z[0.00,1.86] |
| **Bush_01** (whole asset) | 1.46 x 1.45 x 0.74 | 576 | (105.31, 0.00, 0.00) | x[-0.60,0.86] y[-0.73,0.73] z[0.00,0.74] |
| **Bush_02** (whole asset) | 2.04 x 2.05 x 1.09 | 684 | (111.33, 0.00, 0.00) | x[-1.16,0.88] y[-1.02,1.02] z[0.00,1.09] |
| **Bush_03** (whole asset) | 3.14 x 2.82 x 1.49 | 792 | (117.79, 0.00, 0.00) | x[-1.58,1.56] y[-1.42,1.40] z[0.00,1.49] |
| **FlowerClump_01** (whole asset) | 1.26 x 0.47 x 1.07 | 1296 | (123.96, 0.00, 0.00) | x[-0.61,0.65] y[-0.23,0.23] z[0.00,1.07] |
| **FlowerClump_02** (whole asset) | 1.05 x 0.77 x 0.99 | 1428 | (129.19, 0.00, 0.00) | x[-0.58,0.47] y[-0.40,0.37] z[0.00,0.99] |
| **SteppingStone_01** (whole asset) | 1.67 x 1.50 x 0.24 | 192 | (134.49, 0.00, 0.00) | x[-0.83,0.83] y[-0.75,0.75] z[0.00,0.24] |
| **SteppingStone_02** (whole asset) | 2.10 x 1.95 x 0.24 | 192 | (140.38, 0.00, 0.00) | x[-1.05,1.05] y[-0.98,0.98] z[0.00,0.24] |
| **SteppingStone_03** (whole asset) | 2.48 x 2.16 x 0.24 | 192 | (146.67, 0.00, 0.00) | x[-1.24,1.24] y[-1.08,1.08] z[0.00,0.24] |
| CareMachine_Body | 5.135 x 2.250 x 3.920 | 924 | (7.575, 0.000, 0.000) | x[-2.575,2.560] y[-1.125,1.125] z[0.140,4.060] |
| CareMachine_Controls | 1.663 x 0.638 x 0.694 | 720 | (7.575, 0.000, 0.000) | x[0.660,2.323] y[-0.714,-0.076] z[2.445,3.139] |
| CareMachine_Cushion | 2.150 x 1.700 x 0.200 | 192 | (7.575, 0.000, 0.000) | x[-2.125,0.025] y[-0.850,0.850] z[1.070,1.270] |
| CareMachine_Dark | 4.685 x 2.075 x 3.200 | 432 | (7.575, 0.000, 0.000) | x[-2.250,2.435] y[-1.075,1.000] z[0.550,3.750] |
| CareMachine_Gauge_Glow | 1.500 x 0.060 x 0.200 | 44 | (7.575, 0.000, 0.000) | x[-1.800,-0.300] y[-1.105,-1.045] z[0.620,0.820] |
| CareMachine_Screen_Glow | 1.500 x 0.060 x 0.860 | 44 | (7.575, 0.000, 0.000) | x[0.710,2.210] y[0.120,0.180] z[2.770,3.630] |
| CareMachine_Trim | 5.150 x 2.250 x 4.657 | 648 | (7.575, 0.000, 0.000) | x[-2.575,2.575] y[-1.125,1.125] z[0.000,4.657] |
| HatchTree_Canopy_Dark | 20.111 x 10.511 x 5.763 | 1152 | (22.622, 0.000, 0.000) | x[-8.131,11.980] y[-5.663,4.848] z[7.264,13.027] |
| HatchTree_Canopy_Light | 15.161 x 9.054 x 5.308 | 648 | (22.622, 0.000, 0.000) | x[-5.816,9.346] y[-3.445,5.609] z[8.956,14.264] |
| HatchTree_Canopy_Mid | 19.111 x 8.347 x 6.244 | 1152 | (22.622, 0.000, 0.000) | x[-8.472,10.639] y[-3.389,4.958] z[7.626,13.870] |
| HatchTree_Trunk | 14.632 x 6.164 x 11.313 | 1444 | (22.622, 0.000, 0.000) | x[-5.663,8.969] y[-2.960,3.205] z[0.000,11.313] |
| Workbench_Awning | 5.650 x 2.399 x 0.722 | 648 | (41.427, 0.000, 0.000) | x[-2.825,2.825] y[-0.636,1.764] z[4.204,4.925] |
| Workbench_Deck | 1.020 x 0.185 x 0.470 | 200 | (41.427, 0.000, 0.000) | x[-0.710,0.310] y[0.190,0.375] z[2.630,3.100] |
| Workbench_Deck_Glow | 0.280 x 0.040 x 0.390 | 44 | (41.427, 0.000, 0.000) | x[-0.340,-0.060] y[0.195,0.235] z[2.670,3.060] |
| Workbench_Frame | 5.240 x 2.380 x 4.700 | 648 | (41.427, 0.000, 0.000) | x[-2.620,2.620] y[-0.810,1.570] z[0.000,4.700] |
| Workbench_Sign | 4.650 x 0.180 x 0.680 | 108 | (41.427, 0.000, 0.000) | x[-2.325,2.325] y[0.810,0.990] z[2.960,3.640] |
| Workbench_Top | 5.150 x 2.250 x 0.240 | 108 | (41.427, 0.000, 0.000) | x[-2.575,2.575] y[-1.125,1.125] z[2.390,2.630] |
| JournalStand_Cover | 2.320 x 1.369 x 0.560 | 108 | (49.602, 0.000, 0.000) | x[-1.160,1.160] y[-0.706,0.663] z[2.567,3.127] |
| JournalStand_Pages | 2.174 x 1.230 x 0.492 | 216 | (49.602, 0.000, 0.000) | x[-1.087,1.087] y[-0.677,0.553] z[2.724,3.216] |
| JournalStand_Stand | 2.700 x 1.807 x 3.016 | 488 | (49.602, 0.000, 0.000) | x[-1.350,1.350] y[-0.928,0.879] z[0.000,3.016] |
| JournalStand_Trim | 0.450 x 1.574 x 0.667 | 88 | (49.602, 0.000, 0.000) | x[-0.055,0.395] y[-0.972,0.602] z[2.572,3.239] |
| Lantern_Glow | 0.500 x 0.500 x 0.560 | 192 | (55.402, 0.000, 0.000) | x[-0.250,0.250] y[-0.250,0.250] z[2.620,3.180] |
| Lantern_Post | 0.900 x 0.900 x 3.640 | 716 | (55.402, 0.000, 0.000) | x[-0.450,0.450] y[-0.450,0.450] z[0.000,3.640] |
| Bench_Legs | 3.920 x 1.240 x 0.560 | 324 | (62.502, 0.000, 0.000) | x[-1.960,1.960] y[-0.620,0.620] z[0.000,0.560] |
| Bench_Seat | 5.300 x 1.460 x 0.220 | 324 | (62.502, 0.000, 0.000) | x[-2.650,2.650] y[-0.730,0.730] z[0.550,0.770] |
| Signpost_Board | 2.450 x 0.140 x 0.640 | 108 | (70.377, 0.000, 0.000) | x[-1.225,1.225] y[-0.200,-0.060] z[1.180,1.820] |
| Signpost_Post | 0.662 x 0.567 x 2.007 | 220 | (70.377, 0.000, 0.000) | x[-0.331,0.331] y[-0.284,0.284] z[-0.002,2.005] |
| Rock_01 | 0.616 x 0.529 x 0.348 | 192 | (75.910, 0.000, 0.000) | x[-0.308,0.308] y[-0.264,0.264] z[0.000,0.348] |
| Rock_02 | 0.996 x 0.998 x 0.595 | 192 | (80.716, 0.000, 0.000) | x[-0.498,0.498] y[-0.499,0.499] z[0.000,0.595] |
| Rock_03 | 1.547 x 1.247 x 0.869 | 384 | (85.849, 0.000, 0.000) | x[-0.635,0.912] y[-0.623,0.623] z[0.000,0.869] |
| Rock_04 | 2.278 x 1.879 x 1.320 | 384 | (91.701, 0.000, 0.000) | x[-0.939,1.338] y[-0.939,0.939] z[0.000,1.320] |
| Rock_05 | 3.669 x 2.717 x 1.860 | 492 | (98.809, 0.000, 0.000) | x[-1.770,1.899] y[-1.401,1.315] z[0.000,1.860] |
| Bush_01 | 1.462 x 1.454 x 0.742 | 576 | (105.311, 0.000, 0.000) | x[-0.604,0.858] y[-0.727,0.727] z[0.000,0.742] |
| Bush_02 | 2.037 x 2.046 x 1.089 | 684 | (111.327, 0.000, 0.000) | x[-1.158,0.879] y[-1.024,1.022] z[0.000,1.089] |
| Bush_03 | 3.141 x 2.820 x 1.486 | 792 | (117.790, 0.000, 0.000) | x[-1.584,1.558] y[-1.416,1.405] z[0.000,1.486] |
| FlowerClump_01_Centers | 0.980 x 0.280 x 0.390 | 144 | (123.962, 0.000, 0.000) | x[-0.490,0.490] y[-0.230,0.050] z[0.530,0.920] |
| FlowerClump_01_Petals | 1.264 x 0.260 x 0.687 | 720 | (123.962, 0.000, 0.000) | x[-0.614,0.650] y[-0.190,0.070] z[0.381,1.069] |
| FlowerClump_01_Stems | 0.939 x 0.468 x 0.855 | 432 | (123.962, 0.000, 0.000) | x[-0.446,0.493] y[-0.234,0.234] z[0.000,0.855] |
| FlowerClump_02_Centers | 0.610 x 0.500 x 0.400 | 240 | (129.189, 0.000, 0.000) | x[-0.300,0.310] y[-0.330,0.170] z[0.590,0.990] |
| FlowerClump_02_Petals | 0.740 x 0.630 x 0.608 | 540 | (129.189, 0.000, 0.000) | x[-0.365,0.375] y[-0.395,0.235] z[0.336,0.944] |
| FlowerClump_02_Stems | 1.045 x 0.748 x 0.707 | 648 | (129.189, 0.000, 0.000) | x[-0.578,0.468] y[-0.374,0.374] z[0.000,0.707] |
| SteppingStone_01 | 1.669 x 1.501 x 0.240 | 192 | (134.492, 0.000, 0.000) | x[-0.835,0.835] y[-0.751,0.751] z[0.000,0.240] |
| SteppingStone_02 | 2.100 x 1.950 x 0.240 | 192 | (140.376, 0.000, 0.000) | x[-1.050,1.050] y[-0.975,0.975] z[0.000,0.240] |
| SteppingStone_03 | 2.479 x 2.158 x 0.240 | 192 | (146.666, 0.000, 0.000) | x[-1.240,1.240] y[-1.079,1.079] z[0.000,0.240] |

Per asset:
- **CareMachine**: footprint equals today's Journal table (5.15 x 2.25). The bay is on the left: clear opening 2.4 wide x 2.05 deep x about 2.15 high above the cushion (cushion top Z 1.27, hood underside 3.42), open toward -Y. Console with dial, three buttons and a lever on the right; `CareMachine_Screen_Glow` (1.5 x 0.86, faces -Y) above it and `CareMachine_Gauge_Glow` on the base front. This is a new standalone floor machine, not a copy of today's cradle on a table, so the pet sole height moves from 1.18 to about 1.27 and the bay centre is 1.05 left of the origin. Body height 4.06; the sprout on the hood takes it to 4.66.
- **HatchTree**: origin at the trunk base. Trunk S-curve, right shelter branch, six roots and six branch tips are taken from today's coordinates (Blender X = Roblox X, Blender Y = -Roblox Z), with 18 canopy blobs in three leaf tones. Trunk is about 3.9 across at the ground (today 3.35) and narrows to 3.0 at the waist. Root spread is about 7.6 x 5.5. The hanging lantern, vines, fungus and nest are not included.
- **Workbench**: origin is under the table centre, not the bounding-box centre, because the awning posts and sign sit behind the table as they do today. Top 5.15 x 2.25 x 0.24 with its surface at 2.63. Sign 4.65 x 0.68, flat, faces -Y. `Workbench_Deck` is today's little display device, with `Workbench_Deck_Glow` as its LCD.
- **JournalStand**: new lectern. Today the field guide lies on the care table. Book cover 2.32 x 1.42 tilted 18 degrees, centre about 2.85 high.
- **Lantern**: standing post lantern 3.64 tall; `Lantern_Glow` is 0.5 x 0.5 x 0.56 (today's LanternGlass is 0.47 x 0.54 x 0.47). Today's only lantern hangs from the tree, so this is a new form; the head from Z 2.5 up can be cut off and reused as a hanging one.
- **Bench**: three-plank seat 5.3 x 1.46, top at 0.77, legs at X +/-1.8 like today, plus a stretcher. No backrest, as today.
- **Signpost**: `Signpost_Board` 2.45 x 0.14 x 0.64 centred 1.5 up, flat front toward -Y for the SurfaceGui, mounted 0.13 in front of the post.
- **Rock_01..05**: about 0.6, 1.0, 1.5, 2.3 and 3.7 wide. **Bush_01..03**: about 1.5, 2.0 and 3.1 wide, single leaf tone. **FlowerClump_01** daisies and **FlowerClump_02** bell buds: Stems / Petals / Centers. **SteppingStone_01..03**: about 1.7, 2.1 and 2.5 wide, 0.24 thick.
- Rocks, bushes, stones and mound bases were flattened at Z = 0, so their undersides are faces squashed onto the ground plane. Delete or clean the bottoms.

Unsure / for the hand pass:
- Whether the care machine should replace the table outright or sit on it. Replace was assumed. The prompt, sign and camera in code are tied to the table position.
- The hatch tree canopy is the biggest shape decision: blobs are random-seeded ellipsoids. The trunk is smooth tubes with visible seams where branches and roots intersect.
- The tree is 4,396 tris, the closest to the 5k budget. The care machine is 3,004.
- Flower clumps are heavy for their size (1,296 and 1,428 tris); fine for a few, too many for scattering.
- Lantern height and the journal stand are guesses at scale; both read well next to the 5.5 avatar but have no footprint in today's code to match.
- `Screen_Glow` and `Lantern_Glow` use emissive materials only as a marker; Roblox will need Neon or an emissive mask.

## Not done

- No Studio import or test-cube check of these FBX files. The 100x scale issue in ART-HANDOFF section 1 is the thing to verify first.
- No re-import of the FBX back into Blender to confirm axes.
- No textures, vertex colours, LODs or collision meshes.

## 4. assets/art-source/environment/environment.blend + environment.fbx

Built from `garden-greybox-underlay.blend` (saved as a new file; the underlay file is unchanged). Blender X = greybox X, Blender Y = -(greybox Z) so north is +Y, Blender Z = greybox Y, floor top Z = 0, 1 unit = 1 stud. Unit System None. The underlay file had no scene of its own, so one named `Environment` was made; `GreyboxUnderlay` is linked into it and hidden.

Collections: `Ground`, `Water`, `Cliffs`, `Terraces`, `Structures`, `Waterfall`, `Props` (all exported), `Cliff_Kit` (module masters, exported separately), `REF` (eight 5.5 avatars, not exported), `Cameras`, `GreyboxUnderlay` (hidden).

**Origins.** Every environment chunk has its origin at the world origin (0, 0, 0), rotation 0, scale 1. The scattered props (`Props`) have their origin at bottom centre on Z = 0 and keep an object-level Z rotation and uniform scale; copies share one mesh and are named `Tree_01_Trunk__a`, `__b` and so on.

`environment.fbx` holds the 111 environment meshes, exported with the settings in the brief. `environment-cliff-kit.fbx` (extra) holds the five cliff modules alone.

Total: **111905 tris** in environment.fbx (budget 150k). The largest mesh is 5040 tris.

| Object | Bounds min (X, Y, Z) | Bounds max (X, Y, Z) | Tris | Notes |
|---|---|---|---|---|
| Creek_Bed | -86.5, -96.8, -4.0 | -66.8, 30.0, 0.2 | 4400 | sunken 1.8, 0.2 lip, ends rounded at Y -97 |
| Creek_Stone_01 | -77.5, -57.5, -2.2 | -72.5, -52.5, 0.5 | 128 | top Z 0.5, 5 across |
| Creek_Stone_02 | -75.5, -63.5, -2.2 | -70.5, -58.5, 0.5 | 128 |  |
| Creek_Stone_03 | -73.5, -69.5, -2.2 | -68.5, -64.5, 0.5 | 128 |  |
| Ground_01 | -122.6, 4.0, -4.0 | -44.0, 106.0, 0.0 | 3500 | NW chunk (west strip north, pond banks) |
| Ground_02 | -44.0, 4.0, -4.0 | 40.0, 106.0, 0.0 | 4840 | N centre |
| Ground_03 | 40.0, 4.0, -4.0 | 126.0, 106.0, 0.0 | 4948 | NE (under both terraces, runs 6 under the cliffs) |
| Ground_04 | -122.7, -100.0, -4.0 | -44.0, 4.0, 0.0 | 4396 | SW (west strip south, creek banks) |
| Ground_05 | -44.0, -100.0, -4.0 | 40.0, 4.0, 0.0 | 4930 | S centre (spawn side) |
| Ground_06 | 40.0, -100.0, -4.0 | 126.0, 4.0, 0.0 | 5040 | SE |
| Pond_Basin | -92.9, 30.0, -4.0 | -57.2, 104.0, 0.2 | 3480 | sunken 1.8, 0.2 lip, inside the greybox pond rectangle |
| Pond_Island | -81.5, 54.9, -2.1 | -70.5, 65.2, 0.9 | 300 | rounded mound, top Z 0.89 |
| Sea_Plane | -1200.0, -1200.0, -40.0 | 1200.0, 1200.0, -40.0 | 2 | 2400 x 2400 at Z -40, centred on the garden |
| Water_Creek | -77.3, -95.0, -0.4 | -68.7, 30.0, -0.4 | 173 | flat, Z -0.4 |
| Water_Pond | -91.0, 30.0, -0.4 | -59.1, 102.1, -0.4 | 134 | flat, Z -0.4 |
| Cave_Arch | 6.3, 99.7, -4.0 | 33.7, 122.0, 60.0 | 1152 | jambs + lintel mass + arch plate; opening 17 wide x 17 tall, centred X 20 |
| Cave_Arch_Stones | 8.9, 98.5, -0.5 | 31.1, 101.5, 20.1 | 2068 | 9 voussoirs + 2 foot stones, in front of the Y 100 face |
| Cave_Interior | 9.0, 106.0, -1.2 | 31.0, 118.0, 22.0 | 916 | dark floor (top Z 0, Y 106..118), back wall at Y 115, boulder pile |
| Cliff_E1_StraightC | 120.0, 52.6, -4.0 | 142.0, 102.4, 60.0 | 1692 | placed copy of a kit module, see the placement table |
| Cliff_E2_StraightA | 119.9, 2.5, -3.6 | 142.0, 57.5, 54.0 | 1692 | placed copy of a kit module, see the placement table |
| Cliff_E3_StraightB | 120.0, -47.5, -4.1 | 142.0, 7.5, 62.0 | 1692 | placed copy of a kit module, see the placement table |
| Cliff_E4_StraightC | 120.0, -102.7, -3.3 | 142.0, -42.3, 50.0 | 1692 | placed copy of a kit module, see the placement table |
| Cliff_N1_StraightA | -122.5, 99.9, -4.1 | -85.5, 122.0, 62.0 | 1692 | placed copy of a kit module, see the placement table |
| Cliff_N2_StraightB | -91.0, 100.0, -3.7 | -37.0, 122.0, 56.0 | 1692 | placed copy of a kit module, see the placement table |
| Cliff_N3_StraightC | -42.5, 100.0, -4.3 | 12.5, 122.0, 64.0 | 1692 | placed copy of a kit module, see the placement table |
| Cliff_N4_StraightA | 27.8, 99.9, -3.9 | 72.2, 122.0, 58.0 | 1692 | placed copy of a kit module, see the placement table |
| Cliff_N5_StraightB | 67.3, 100.0, -4.4 | 127.7, 122.0, 66.0 | 1692 | placed copy of a kit module, see the placement table |
| Cliff_NE_CornerInside | 113.0, 93.0, -4.0 | 143.0, 123.0, 70.0 | 940 | placed copy of a kit module, see the placement table |
| Cliff_NW_CornerOutside | -144.5, 99.0, -3.6 | -120.5, 123.0, 50.0 | 940 | placed copy of a kit module, see the placement table |
| Cliff_SE_CornerOutside | 120.7, -120.0, -3.1 | 143.9, -96.0, 44.0 | 940 | placed copy of a kit module, see the placement table |
| Cliff_WestOutcrop | -138.9, 59.6, -4.0 | -120.4, 100.9, 30.0 | 752 | unique piece, 30 tall |
| South_Cliff_Face | -132.2, -116.8, -46.0 | 145.2, -102.4, -0.4 | 4700 | hangs from Z -0.4 to -46 (sea at -40); runs east under the SE cap |
| South_Rim_Lip | -123.0, -104.8, -1.5 | 124.0, -99.8, 2.3 | 2218 | grass hump 1.4..2.3 tall along the south edge |
| Ramp_High | 95.0, 30.0, 7.0 | 105.0, 50.6, 16.0 | 40 | 8 to 16 toward +Y (north), 21.8 deg, sits on the low terrace |
| Ramp_High_Grass | 96.1, 30.0, 7.4 | 103.9, 50.0, 16.0 | 12 | 7.8 wide grass strip, same plane |
| Ramp_Low | 56.0, -13.0, -1.0 | 80.6, -3.0, 8.0 | 40 | stone body + 1.1 kerbs flush with the slope; 0 to 8 toward +X, 18.4 deg |
| Ramp_Low_Grass | 56.0, -11.9, -0.6 | 80.0, -4.1, 8.0 | 12 | 7.8 wide grass strip, same plane |
| Terrace_High | 90.2, 50.1, -2.0 | 123.0, 104.0, 15.7 | 188 | rock body, hidden top at 15.7 |
| Terrace_High_Grass | 90.0, 50.0, 15.2 | 123.0, 104.0, 16.0 | 108 | WALK SURFACE top Z 16.0 |
| Terrace_High_Trim | 89.3, 49.3, 13.4 | 120.9, 100.4, 15.9 | 2052 | kerb stones, tops Z 15.95; gap at the ramp mouth |
| Terrace_Low | 80.2, -19.9, -2.0 | 123.0, 59.9, 7.7 | 188 | rock body, hidden top at 7.7 |
| Terrace_Low_Grass | 80.0, -20.0, 7.2 | 123.0, 60.0, 8.0 | 108 | WALK SURFACE top Z 8.0, exact greybox footprint |
| Terrace_Low_Trim | 79.3, -20.7, 5.4 | 120.9, 60.5, 8.0 | 3240 | kerb stones, tops Z 7.95, stick out 0.3..0.7 past the wall; gap at the ramp mouth |
| Bridge_West | -81.0, -13.0, -0.9 | -65.0, -7.0, 0.4 | 1944 | 16 planks + 2 stringers, deck top Z 0.36 |
| Bridge_West_Rails | -80.7, -13.0, -0.6 | -65.3, -7.0, 1.8 | 1080 | 6 posts, top rail Z 1.52, inside the 6-wide footprint |
| Nook_Posts | 103.7, -17.3, 7.8 | 106.3, -2.7, 16.5 | 240 | 2 posts at (105, -4) and (105, -16), Z 7.8..16.5 |
| Nook_Roof | 103.0, -18.0, 17.4 | 121.5, -2.0, 19.9 | 404 | moss roof, underside Z 17.4, domed to 19.9 |
| Nook_Roof_Frame | 103.2, -17.4, 16.4 | 121.5, -2.6, 17.6 | 324 | wood frame + 2 beams, underside Z 16.45 (8.45 clear above the terrace) |
| Pillar_01 | -112.0, -44.0, -0.5 | -102.0, -34.0, 3.5 | 336 | top Z 3.5, 10 across (flat top 9.4) |
| Pillar_02 | -112.0, -33.0, -0.5 | -102.0, -23.0, 7.0 | 336 | top Z 7, 10 across (flat top 9.4) |
| Pillar_03 | -112.0, -22.0, -0.5 | -102.0, -12.0, 10.5 | 336 | top Z 10.5, 10 across (flat top 9.4) |
| Pillar_04 | -112.0, -11.0, -0.5 | -102.0, -1.0, 14.0 | 336 | top Z 14, 10 across (flat top 9.4) |
| Pillar_05 | -112.0, 0.0, -0.5 | -102.0, 10.0, 17.5 | 336 | top Z 17.5, 10 across (flat top 9.4) |
| Pillar_Ledge | -119.0, 11.0, -0.5 | -101.0, 23.0, 21.0 | 564 | flat top Z 21.0 |
| Waterfall_Foam | -83.0, 92.0, -1.0 | -67.0, 98.0, 0.1 | 1004 | flat half ring at Z -0.36 + 9 foam blobs |
| Waterfall_Strip | -81.0, 97.2, -0.6 | -69.0, 104.5, 55.8 | 128 | single-sided strip, 4 x 16 quads; UV: U across, V along the flow (length / 12) |

**Cliff kit** (`Cliff_Kit` collection, parked at X 260..540; origin at the bottom centre of the front face for straights and at the footprint centre for corners; bases run down to Z -4):

| Module | Size W x D x H | Tris |
|---|---|---|
| Cliff_Straight_A | 53 x 22 x 60 | 1692 |
| Cliff_Straight_B | 53 x 22 x 60 | 1692 |
| Cliff_Straight_C | 53 x 22 x 60 | 1692 |
| Cliff_CornerInside | 30 x 30 x 70 | 940 |
| Cliff_CornerOutside | 24 x 24 x 56 | 940 |

Placed copies are separate meshes with the transform applied, so their origin is the world origin. To rebuild the ring from the five modules instead:

| Placed piece | Module | Position X, Y | Yaw | Scale along wall | Scale height |
|---|---|---|---|---|---|
| Cliff_N1_StraightA | Cliff_Straight_A | -104, 100 | 0 | 0.7 | 1.033 |
| Cliff_N2_StraightB | Cliff_Straight_B | -64, 100 | 0 | 1.02 | 0.933 |
| Cliff_N3_StraightC | Cliff_Straight_C | -15, 100 | 0 | 1.04 | 1.067 |
| Cliff_N4_StraightA | Cliff_Straight_A | 50, 100 | 0 | 0.84 | 0.967 |
| Cliff_N5_StraightB | Cliff_Straight_B | 97.5, 100 | 0 | 1.14 | 1.1 |
| Cliff_E1_StraightC | Cliff_Straight_C | 120, 77.5 | -90 | 0.94 | 1.0 |
| Cliff_E2_StraightA | Cliff_Straight_A | 120, 30 | -90 | 1.04 | 0.9 |
| Cliff_E3_StraightB | Cliff_Straight_B | 120, -20 | -90 | 1.04 | 1.033 |
| Cliff_E4_StraightC | Cliff_Straight_C | 120, -72.5 | -90 | 1.14 | 0.833 |
| Cliff_NE_CornerInside | Cliff_CornerInside | 128, 108 | 0 | 1.0 | 1.0 |
| Cliff_NW_CornerOutside | Cliff_CornerOutside | -132.5, 111 | 0 | 1.0 | 0.893 |
| Cliff_SE_CornerOutside | Cliff_CornerOutside | 132.3, -108 | 180 | 0.97 | 0.786 |

**Scattered props** (33 placements, 55 meshes, 32168 tris). Each copy: position (X, Y), yaw, scale.

| Prop mesh | Tris each | Copies |
|---|---|---|
| Bush_Cluster_01 | 768 | (-21, 95) 0 deg x1; (76.5, 30) 90 deg x0.9; (113, -61) 45 deg x1; (-98.5, 52) 200 deg x1; (-59, -58) 300 deg x0.9 |
| Bush_Cluster_02 | 960 | (59, 95) 30 deg x1; (84, 64.5) 10 deg x0.8; (96, -25.5) 0 deg x0.8; (-51, 62) 120 deg x0.9; (-101, -90) 20 deg x1 |
| Rock_Large_01 | 492 | (2.5, 96) 10 deg x1; (37, 96) 130 deg x1.1; (77, 45) 250 deg x1; (-98, 93) 0 deg x1; (-61, -88) 40 deg x0.9 |
| Rock_Large_02 | 684 | (-30, 95.5) 40 deg x1; (114, -49) 100 deg x1; (-52, 39) 300 deg x0.9; (-115, -91) 160 deg x0.9 |
| Rock_Large_03 | 684 | (72, 94.5) 15 deg x0.9; (113, -92) 190 deg x0.85; (-110, 90) 70 deg x0.9 |
| Tree_01_Canopy | 876 | (-6, 92) 200 deg x1; (82, 88) 300 deg x1.05; (-49, 84) 60 deg x1.1; (-51, -91) 110 deg x1 |
| Tree_01_Canopy_Light | 384 | (-6, 92) 200 deg x1; (82, 88) 300 deg x1.05; (-49, 84) 60 deg x1.1; (-51, -91) 110 deg x1 |
| Tree_01_Trunk | 220 | (-6, 92) 200 deg x1; (82, 88) 300 deg x1.05; (-49, 84) 60 deg x1.1; (-51, -91) 110 deg x1 |
| Tree_02_Canopy | 876 | (-46, 91) 20 deg x1; (111, -34) 140 deg x1; (-113, 42) 320 deg x0.9; (-113, -70) 75 deg x1 |
| Tree_02_Canopy_Light | 384 | (-46, 91) 20 deg x1; (111, -34) 140 deg x1; (-113, 42) 320 deg x0.9; (-113, -70) 75 deg x1 |
| Tree_02_Trunk | 220 | (-46, 91) 20 deg x1; (111, -34) 140 deg x1; (-113, 42) 320 deg x0.9; (-113, -70) 75 deg x1 |
| Tree_03_Canopy | 876 | (49, 91) 80 deg x1; (110, -78) 250 deg x0.95; (-105, 72) 10 deg x1 |
| Tree_03_Canopy_Light | 384 | (49, 91) 80 deg x1; (110, -78) 250 deg x0.95; (-105, 72) 10 deg x1 |
| Tree_03_Trunk | 220 | (49, 91) 80 deg x1; (110, -78) 250 deg x0.95; (-105, 72) 10 deg x1 |

Unscaled prop sizes: Tree_01 is 8.0 tall, Tree_02 10.5, Tree_03 12.5 (canopy about two thirds of the height across). Rock_Large_01/02/03 are about 4.5 / 6.5 / 9 wide. Bush_Cluster_01/02 are about 4 / 5.5 wide. Each tree is three meshes: `_Trunk`, `_Canopy`, `_Canopy_Light`.

### Walkable heights (measured from the meshes)

| Surface | Z | Footprint (Blender X, Y) |
|---|---|---|
| Lawn (Ground_01..06) | 0.00, flat everywhere | X -122..126, Y -100..106. The greybox floor is X -121..120, Y -100..100; the rest is under the cliffs. |
| Terrace_Low_Grass | 8.00 | X 80..120, Y -20..60 |
| Terrace_High_Grass | 16.00 | X 90..120, Y 50..100 |
| Ramp_Low | 0 to 8.00 | X 56..80, Y -13..-3; 10 wide, 18.4 deg, top flush at X 80 |
| Ramp_High | 8.00 to 16.00 | X 95..105, Y 30..50; 10 wide, 21.8 deg, top flush at Y 50 |
| Pillar_01..05 | 3.50 / 7.00 / 10.50 / 14.00 / 17.50 | centres X -107, Y -39 / -28 / -17 / -6 / 5 |
| Pillar_Ledge | 21.00 | X -119..-101, Y 11..23 |
| Bridge_West deck | 0.36 | X -81..-65, Y -13..-7 |
| Creek_Stone_01..03 | 0.50 | (-75, -55), (-73, -61), (-71, -67) |
| Water_Pond / Water_Creek | -0.40 | basin floor at -1.80 |
| Sea_Plane | -40.00 | |

Checks done: the bounds of each piece were compared with the matching underlay block by script; nothing but ground is inside X -40..45, Y -80..35; the scene was looked at from the top and from eye level at the hub, beside the bridge and at the low ramp.

### Deviations from the brief

- **Bridge position.** The brief gave the bridge centre as greybox (-73, 35). That 35 is the world Z; in greybox-local it is (-73, 10), which is what `HollowWorldLayout` and the underlay both give. The bridge is at Blender X -81..-65, Y -13..-7.
- **Cliff modules are placed as baked copies**, each stretched along the wall (0.70 to 1.14) and in height (0.83 to 1.10) to hit the greybox block sizes, so they keep the shared world origin. The five masters are in `Cliff_Kit`.
- **Multi-colour pieces are one mesh per colour**, as in the stations file: `Terrace_*` + `_Grass` + `_Trim`, `Ramp_*` + `_Grass`, `Bridge_West` + `_Rails`, `Cave_Arch` + `_Stones` + `Cave_Interior`, `Nook_Roof` + `_Frame` + `Nook_Posts`.
- **Terrace trim sticks out 0.3 to 0.7 past the greybox footprint** and its tops are 0.05 below the walk surface. The walk surface itself is the exact footprint.
- **Cliff faces** sit between 0.3 in front of and 3.6 behind the greybox face. The cave arch stones are 1.45 in front of it.
- **Pond and creek basins are slightly smaller than the greybox water rectangles** (0.3 to 1.0 inside, pond corners rounded at radius 10), so no slope falls outside the wet regions. The creek stops at Y -97 and does not spill over the south rim. The water sheets start 1.9 inside the basin edge.
- **Added, not in the brief's list:** `Pond_Island` and `Creek_Stone_01..03` (both are in the underlay), `Cave_Interior`, and `environment-cliff-kit.fbx`.
- **Ground** runs 6 studs under the north and east cliffs and has a wavy west edge (X -121.1 to -122.7). Each chunk is a closed slab 4 thick; the undersides are large n-gons.
- **Sea_Plane** is centred on the garden (the greybox sea is offset south), so the sea shows on all sides.
- Rounded pieces are several overlapping closed shells in one mesh, shaded smooth. Ground, ramps and water are flat-shaded.
- The FBX exporter printed "cannot register a valid material index" for the prop copies that share a mesh. Geometry is unaffected; material links on those copies may be missing in the FBX.

### For the hand pass

- Cliffs are stacks of bevelled boxes. They need real rock silhouettes: broken tops, ledges, strata and a recess behind the waterfall. The backs and the outer side of the ring are plain.
- The west side has no cliff below the lawn. The ground slab floats over the sea there, as in the greybox. A west face like `South_Cliff_Face` would fix the view from the pillars.
- Terrace walls are flat rock under the kerb stones and the grass tops are plain slabs. Ramps are straight prisms.
- The basin lip and slope are one clean sweep. The pond wants shallows and a nicer island; the creek has no outflow.
- Ground is a 2-stud quad grid snapped to the basin edge (a few triangles there). It is dead flat on purpose.
- The waterfall pours straight out of the cliff top at Z 55.8; there is no source.
- The nook is a placeholder pergola. The pillars are lathed and share one profile.
- Trees, rocks and bushes are seeded blobs like the stations set; rock and bush undersides are squashed onto Z = 0.
- Not done: Studio import, FBX re-import check, textures, collision meshes, sky. The landmark tree is the HatchTree in stations.blend and is not in this file.
