# Companion Ring

The original Ring is a single closed band with a smooth tube, a front-facing opening and a slight ellipse. Its saved shape ID stays `ring`. The mesh, tintable icon and close study come from the same profile. [Mesh](care-halo-ring.glb) · [Mask](care-halo-ring-mask.png) · [Dimensions and hashes](halo-manifest.json) · [Offline model study](../../artifacts/companion-editor-2026-11-09/halo-original-geometry-study.png)

## Integration

Import the GLB's single mesh, check its actual imported resource bounds, then size the runtime part to **0.259 × 0.195 × 0.049** times the pet's visual scale. At 0.72 the expected size is approximately 0.1865 × 0.1404 × 0.0353 studs. The source faces +Z, uses +Y up, and has its origin at the center. Apply the existing charm frame and its 12° X tilt once. Draw the visible shape in the saved Secondary tint. Ring Off hides the selected geometry and its emission together. Fit the face-to-charm space in both the carry and dock poses.

The 32 × 8 surface has 512 triangles. The build checks outward winding, edge incidence across welded UV seams and torus topology. A neutral albedo, one smooth normal per vertex and a continuous UV parameterization support runtime tint and gloss. The PNG contains a neutral white band and an alpha-cut center. It can carry the shape into the editor icon or onto a thin two-sided world proxy while the mesh loads. The six-pixel horizontal transparent margin is intentional. Review the flat proxy in world and viewport separately, including failure and delayed upgrade. Keep the actual hole visible whenever the angle permits. Inspect the naturally thin side profile at ordinary camera distance. Use the mask when a visible image is confirmed. If images are unavailable too, a native circle outline can serve as the editor icon. Any world fallback using a different renderer still needs its own native capture.

## Pet material trial

Sample the two original pets against the current unchanged scene. Use the selectively inspected white albedo/mask, nonmetal, body roughness 82/255 and eye roughness 36/255 from the parked trial. Use a preauthored MeshPart template. Bind resolved Main/Secondary **once**, preserving black eyes, ivory teeth, blush, blink ownership and saved colors. Look for excessive darkening of saturated coats when combining emissive tint with albedo. Test a neutral emission tint against a color-matched alternative with actual geometry. [Roblox PBR textures](https://create.roblox.com/docs/art/modeling/surface-appearance)

| Trial role | Noon | Dusk | Midnight |
|---|---:|---:|---:|
| Body and ordinary Secondary | .12 | .29 | .46 |
| Visible charm | .25 | .62 | .98 |
| Dark eye | 0 | 0 | 0 |
| Pale catchlight | .12 | .30 | .48 |

These are trial strength values. Match current camera, time, pigment, pose and exposure. An emission-off clone with the same mapped material gives a direct control. A moving camera should show a moving broad highlight on the rounded body, while the authored eye mark should stay attached until blink closes the eye. Remove explicit body and hand darkening only on the working material path. Keep an immediate complete native pet during optional material loading. Support the original rig's lack of patterned UVs by starting with uniform maps. Evaluate plain Part/SpecialMesh and low-quality fallback independently.

The current close neutral Zivvi JPEG samples give these approximate display RGBs from seven-pixel-square patches. At noon the forehead is (255,255,255), lower face (183,192,175), torso (227,232,212) and charm (201,204,183). At midnight the same patches are (171,194,186), (165,186,177), (154,176,164) and (134,151,145). Aim to lift the lower daylight face, retain a visible contour at midnight and let the charm read as a small luminous accent. Watch the size of the already clipped noon crown. Confirm the same hierarchy on Rose Main/Tide Secondary. Asset fetch callbacks and ImageLabel loading cannot establish the final material appearance. [Noon baseline](../../artifacts/companion-editor-2026-11-09/baseline-noon-zivvi-FIXTURE.jpg) · [Midnight baseline](../../artifacts/companion-editor-2026-11-09/baseline-midnight-zivvi-FIXTURE.jpg)
