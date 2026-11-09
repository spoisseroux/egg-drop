# Companion editor and pet material visual review

## Pet materials and Ring

**GO for the reviewed seven-pet visual matrix.** In the native midnight lineup each pet has distinct Main and Secondary surfaces, a visible face and a closed halo. The mixed preset uses five Rose and five Tide doses on Main and five Citrus on Secondary. It reads purple and yellow even at garden distance. The high fixture camera brings Tikket’s neutral halo close to the top of its head in projection. The colored version separates clearly. All seven still have individual silhouettes in the neutral noon and mixed dusk captures. At noon the upper crowns have little tonal variation. The native-recipe fallback bodies read darker at midnight but keep the correct channels and visible eyes. [Neutral night](seven-neutral-midnight-FIXTURE.jpg) · [Mixed night](seven-mixed-midnight-FIXTURE.jpg) · [Neutral noon](seven-neutral-noon-FIXTURE.jpg) · [Mixed dusk](seven-mixed-dusk-FIXTURE.jpg) · [Native fallback night](seven-fallback-midnight-FIXTURE.jpg)

In the close matched midnight Zivvi captures, enabling material emission changes the upper forehead from approximately RGB (128,164,152) to (206,236,226), the lower face from (121,153,140) to (202,230,218) and the authored eye mark from (128,149,135) to (209,227,208). The sampled lawn patch stays at (57,116,52). These seven-by-seven-pixel JPEG samples show a visible real rendering change. The eyes stay dark beneath the bright catchlights. The pale body still picks up a mild cool-green cast from the environment. A still cannot demonstrate moving specular reflections. [Emission off](candidate-midnight-emission-off-FIXTURE.jpg) · [Emission on](candidate-midnight-emission-on-FIXTURE.jpg)

The original torus is one 512-triangle mesh with smooth normals and a hole through its center. The mounted asset was initially losing its resource ID; the earlier emission pair shows the dark planar fallback. The separate corrected native close view shows the actual mesh. Its lightly rounded band appears brighter than the body at night and leaves the face clear. The colored two-pet and Level01 captures preserve the bright yellow ring against purple Main. Level01 has less surface depth. [Actual neutral torus](torus-native-midnight-FIXTURE.jpg) · [Two original rigs, mixed](torus-two-original-mixed-midnight-FIXTURE.jpg) · [Level01 close](torus-mixed-midnight-Level01-FIXTURE.jpg) · [Original model study](halo-original-geometry-study.png)

## Measured cost

Six rounds used the same current garden, seven idle AuthoredMesh pets, seven actual Ring meshes, Automatic graphics and the 749 × 381 emulated landscape viewport. Each round settled the rigs, warmed 180 frames and sampled 180 controlled frames. All six valid flags are true. The recorded camera, environment, UI, viewport and background counts match across rounds. There are 103 SurfaceAppearance instances on the seven fixture rigs when materials are enabled and zero when disabled. The percentiles below were checked directly against the stored frame samples. [Six raw rounds](seven-material-benchmark.json)

| Round | Materials | Elapsed frame p95, ms | Seven-rig CPU p95, ms |
|---:|---|---:|---:|
| 1 | Off | 17.765 | 1.539 |
| 2 | On | 17.863 | 1.906 |
| 3 | On | 17.648 | 1.698 |
| 4 | Off | 17.931 | 1.637 |
| 5 | Off | 17.999 | 1.566 |
| 6 | On | 17.687 | 1.538 |

The median of the three elapsed-frame p95s was **17.931 ms off, 17.687 ms on (−1.36%)**. The seven-rig CPU equivalent was **1.566 ms off, 1.698 ms on (+0.132 ms, +8.42%)**. This measures a short Studio client workload in one fixed scene. Physical-phone thermals, a crowded garden and longer play remain outside this comparison.

## Interface checkpoints

**GO for the actual Largest landscape Hue composition and corrected pickup arrow.** Scrolling from the Rose row to Iris and inventory keeps the complete live Zivvi, its name, both channels, all three tabs and × in place. The corrected arrow has one clear upward apex and matches Back’s stroke weight. The interim Charm capture had icon/name overlap. The corrected row places the icon and name together with a distinct trailing check. The settled Ring selection preserves the pet and both On/Off controls in the left rail. [Hue entry](actual-largest-phone-hue-top.jpg) · [Hue after scroll](actual-largest-phone-hue-scrolled.jpg) · [Pickup arrow](actual-largest-phone-up-arrow.jpg) · [Charm before correction](actual-largest-phone-charm-overlap.jpg) · [Settled Ring after correction](actual-largest-phone-charm-final.jpg)

**GO for the earned overflow recap at Largest text.** The dark +0 Stars, Quest/Daily amounts and first score tiles are readable on the cream sheet. Scrolling reveals the longest chain and objective details while the outcome and both actions stay pinned. This run scored 190, with a longest chain of three and zero Stars. [Actual overflow](actual-largest-phone-recap-overflow.jpg) · [Scrolled run details](actual-largest-phone-recap-scrolled.jpg)

Garden lineup images are client-only fixtures from the real production Factory with controlled camera and clock. The editor captures use an earned owner workflow in Studio phone emulation. Live visitor, physical-device, live repeated-save and private publication status are separate checks.

**Final editor and recap visual GO.** The earned single-pet card now shows the full live pet, Zivvi’s name and **✓ Active** without scrolling in the Medium phone capture. The seeded desktop grid shows seven named square previews, including the three retained species. At phone width four complete cards fit in the first row with the remaining row reachable by scrolling. In the final ordinary Hue wheel check the list moved from 200 to 100 with zero camera movement. [Earned single pet](actual-medium-phone-pet-final.jpg) · [Seven-owned desktop fixture](seven-owned-desktop-pet-FIXTURE.jpg) · [Seven-owned phone fixture](seven-owned-phone-pet-FIXTURE.jpg)

The positive receipt fixtures show **+14 Stars**, with Quest +8 and Daily +6. The outlined gold star and dark totals are readable against cream. Score/best, longest chain and clears appear directly in the receipt. These captures inject local data into the production component; neither grants Stars. The earned overflow capture above supplies the ordinary control proof. [Desktop positive fixture](positive-recap-desktop-FIXTURE.jpg) · [Phone positive fixture](positive-recap-phone-FIXTURE.jpg)
