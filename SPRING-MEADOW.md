# Spring Meadow — the larger-garden continuation

**Accepted and published:** private **v309 / pushed runtime b71c702**, verified in refreshed Studio Version History. [Evidence](artifacts/spring-meadow-2026-11-09/VERIFY.md) · [Gallery](artifacts/spring-meadow-2026-11-09/GALLERY.md). The plan below was written November9 at6:25AM Eastern because the original larger-world requirement was not satisfied by v297's unchanged160 ×128 floor. Its source, native, actual-control, visual and performance-investigation gates are complete; physical phone/live services remain separate.

## Player outcome and art

Walk beyond the old south edge into a recognizable spring meadow. Bring another player and both babies, rest together, pet a baby or open a handheld there, then return to the compact hub. No shop or new activity mode separates those actions. Astra designed the expansion and Sol independently reviewed its architecture GO before implementation.

- Floor **160 × 176**, center **(0, 3.5, 24)**, top Y = 4. Edges X ±80, north Z −64, south Z +112: **37.5% more floor area**. Ten spawns and all existing hub stations, benches, toy, bridge and nook retain their coordinates.
- Existing south trail reaches (0,39), then forks at (0,48). West limb: (−12,60) → (−17,77) → (−9,91). East return: (+5,83) → (+6,63) → fork. At least eight studs of usable dry passage, with both limbs crossing the former Z64 boundary.
- A **14 × 12** gathering lawn around (−10,88) accommodates two avatars and pets. Its west/east rest slots at (−12.5,87) and (−7.5,87) reuse the existing six-second settle, cooldown and interruption behavior. This is one destination, with two positions so both babies need not converge on one point.
- Three asymmetric lavender shelves behind the lawn rise roughly 4, 7 and 11 studs, with rounded green caps and a chartreuse rim. A cyan-to-teal spring inset and narrow ivory foam lip stay inside the rock envelope, beyond the walking route. Saturated terracotta/cornflower accents and pale stepping stones add depth without covering the pets.
- One slow spring glint uses the existing nearest-three, 12 Hz ambient owner and freezes under reduced motion. Target **≤65 net new parts**, **eight lamp fixtures / four managed lights**, at most three active ambient accents. Reassign existing fixtures when useful; keep accepted hub/nook lighting readable. Do not expand visitor radius or per-frame scans.

## Implementation ownership

Sol world/host owns `HollowWorldLayout`, `LoungeArt`, bounded `LoungeSpringArt`, `GardenLayout`, `GardenState`, any necessary cached spring wet classification in `init.server`, and affected/new tests. Explicit floor center drives floor, all four boundaries and perimeter planting; it must not translate hub objects. New rest selection is deterministic by eligible distance then stable ID. Validate the full approach before changing actor state, reject safety stops as arrivals, and retain old Nook aliases/behavior. No save schema, remote command or economic mutation is needed.

Sol UI independently reviews the actual source diff. Astra reviews the actual approach, landmark, night pet readability, movement and focus screenshots. Root alone controls Studio, source equality, tests, evidence, commit/push and private publication. All workers preserve other edits and the accepted fallback.

## Cases that must remain explicit

| Case | Required result |
|---|---|
| Crossing former Z64 | Old wall absent; avatar shoulders, feet and pet full cubic path stay supported and clear on both limbs. |
| New colored water | Finite actual wet footprint is cached and excluded with buffer; advertised dry route never crosses deceptive water or raised rocks. |
| Rest selection | Actual owner reach/height and pet reach remain bounded; nearest valid free anchor wins deterministically. Existing actors' selected IDs block overlapping approach/rest targets; focused peers within two studs also block a slot. Failed preflight changes nothing, including claims and cooldown. |
| Leaving, focusing, changing pet/character | Existing generation/cooldown/ownership fences release the selected rest; no teleport or stale restore. |
| Focus by spring shelves | Visible scenery participates in the existing collector; face, feet, charm and Back stay readable without a large camera overhang. |
| Returning to hub | Existing stations, toy Start/Join, bridge and original nook continue to work. |
| Old outer boardwalks | Their pet support remains unproved and outside this dry extension's claim; no general navigation rewrite. |
| Reduced motion and mobile | No new uncontrolled loops; 44px controls and existing input paths remain intact. |

## Evidence and release gates

1. Native geometry: exact floor/center/boundaries, unchanged ten spawns and hub activation disks, loop center/shoulder/turn clearance and floor support, contained wet exclusions, rest endpoint <.1 stud, old bridge/C0/speed/session/receipt gates intact, measured parts/lights/ambient cap.
2. Ordinary avatar and follower walk the complete loop both directions across the former edge. Observe arrival, six-second rest and release; test walking and focus interruptions. Two ordinary local clients meet at the destination and see each other's pets. Distinguish this from synthetic actors and live service conditions.
3. Actual noon/night approach and close pet/rest/focus views, plus short landscape Largest focus. Astra render/motion GO is required. Retain failed first captures as diagnostic evidence.
4. Matched fixed-camera performance at noon and midnight: same current seven rigs + one fixture toy, same camera, graphics, viewport, cadence, measured light and 180 warm / 180 capture frames, three rounds per light. Only the world changes. This synthetic workload is not an ordinary phone or historical full-place comparison. Investigate repeated >10% p95 regressions. Baseline raw rounds are in `artifacts/spring-meadow-2026-11-09`; they deliberately place the benchmark outside the old floor and do not prove traversal.
5. After source freeze: exact native source equality, native compilation, Rojo build, independent source and actual visual review. Update gallery/rundown and commit/push explicit files; update only existing private place 96451847774961 after gates pass, then verify Published version.

Budget: build/source review by about 7:10, native/render/control checks by 7:55, bounded fixes through 8:25, final release/handoff before 9. At/after 9 start no new changes. If the candidate fails its gates, retain v297 rather than claim the expansion shipped. Keep nursery, battles, clothing/stat eggs, new currencies/rewards, paid luck, daily play caps and public release deferred. Existing liked music stays default.
