# Garden swap: verification (2026-11-11)

What changed: the approved greybox landscape (cliffs, cave, pond, west creek, waterfall, terraces, ramps, stepping pillars, ledge, south rim over the sea) now surrounds the existing hub. Every gameplay position is unchanged: stations, hatch tree, spawn, toy lawn, creek nook and spring meadow.

## How it was checked
The Rojo Studio plugin was disconnected, so each changed file was applied in Studio Edit and compared to the repo with a byte checksum. All 7 matched: LoungeArt, LoungeGreyboxArt, LoungeSpringArt, the server init script, HollowWorldLayout, GardenWalkability and GardenPathPlanner. The specs were pasted into Studio and hash-checked against the repo files before running in a Play server.

| Check | Result |
|---|---|
| `GardenGreyboxWorld.spec.lua` (new): floor and boundaries, West bridge span, wet and blocked regions, hub → west strip, pond strip, two-bridge chain, around the low ramp, waypoints stay on the floor, a short hop around the ramp beats a far bridge, single primary-bridge detour identical to the old planner leg for leg | 10/10 (after the review fixes) |
| `GardenWalkability.spec.lua` | 11/11 (re-run after the review fixes) |
| `GardenBridgeFollow.spec.lua` | 2/2 (re-run after the review fixes) |
| `WorldRoutes.spec.lua` (updated for the new world) | 11/13 passed. The 2 failures were stale `ReturnGateEdge` asserts: that part was retired with the shared toy before this work, and the asserts are now removed. |

## Reviews
- Architect plan review: five issues, all folded into the plan (bridge deck height, routing around the pond, blocked footprints for solids, boundary walls centred on the floor, where the ground-only hook goes).
- Code review: GO WITH CHANGES. Fixed: graph corner waypoints are now kept on the floor (before, they could land past the edge, inside cliffs); the planner keeps the shortest valid route rather than the first bridge detour; the ground anchor clears on respawn; a pet that appears while its owner is above the ground starts on the lawn. The live Play walk below ran before these fixes; the specs above ran after them.

## Live Play (Studio, R15, fresh save, Zivvi from onboarding)
- The owner walked from the hub across the west bridge into the west strip. The pet crossed on the deck (y 4.38) and settled beside the owner.
- The owner walked into the strip beside the pond. The pet followed around the pond and never entered the water.
- The owner walked back to the east side of the hub creek. The pet crossed both bridges.
- With the owner on the low terrace (y 15) and then the high terrace (y 23), the pet stayed at its last lawn spot (y 4.025). Pets stay on the ground.

Captures (night; the in-game clock was at night): `overview.jpg`, `west-bridge-and-pillars.jpg`, `terraces-from-hub.jpg`.

## Not checked
- Phone camera framing.
- Two players at once.
- Daytime look.
- Performance on a device.
- A full spec sweep beyond the garden specs above.

## Studio Edit place changes (not in the repo)
- `Workspace.GardenGreybox`, the review copy at X=1000, was deleted. It can be regenerated from `scripts/GardenGreybox.lua`.
- `Workspace.Baseplate` was moved to `ServerStorage.Baseplate_RetiredByGreybox`. It sat over the sea.
- The place has not been saved or published.
