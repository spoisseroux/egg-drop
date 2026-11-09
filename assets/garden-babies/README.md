# Zivvi and Ovelle

These are the first two authored garden babies. The original Blender scene contains both rigs and their neutral, curious, startled, pleased, sleepy and affectionate faces. Each family has an FBX for the Studio importer and a GLB with named expression morphs. The three PNGs are actual Blender renders.

| Asset | Body at garden size | Original FBX | Imported color correction |
|---|---|---|---|
| Zivvi | 1.534 studs tall, 1.635 wide | 14 meshes, 5,492 triangles | Replace the two mixed-material hand meshes with four single-color pieces. |
| Ovelle | 1.400 studs tall, 1.656 wide, hovering 0.10 studs above the origin | 15 meshes, 5,388 triangles | Replace the two mixed-material cuff meshes with four single-color pieces. |

**Source coordinates.** The JSON recipes use Roblox axes with +Y up, +Z forward and the ground origin beneath the paws. Head, hands, feet, Ovelle’s cuffs, eye line, catch point and charm have named anchors. The meshes use the same physical proportions. The frozen Studio import faces −Z, so its presentation adapter applies one half-turn. Exclude the optional dot from body size and contact bounds. Include it in camera clearance while visible.

**Material splits.** The Studio importer produced gray MeshParts. Use the role colors from the family’s native JSON. [The supplemental FBX](garden-material-splits.fbx) contains only the affected pieces. [Its manifest](garden-material-splits.json) gives their original paw-space centers, sizes, materials and animation channels. Use those centers when positioning the pieces. Rescaling the supplemental group to its own bounding box would change the hand and cuff proportions.

**Fallback.** The native JSON files describe approximate primitive rigs for clients without the imported template. [The portrait map](portraits.json) provides a 13×13 fallback. [The expression render](garden-babies-expressions.png) shows the intended mouth, gaze, head tilt and hand poses. The Studio adapter drives these through named pieces.
