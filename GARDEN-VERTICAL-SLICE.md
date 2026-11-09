# Garden vertical slice — implementation and verification

Started 8 November 2026 after approval of `CHAO-GARDEN-DIRECTION.md`. Starting runtime checkpoint1366c31, branch `feat/egg-drop-arcade-polish`; published private place remainsv180 until this slice passes and publication is verified.

## Player outcome

Zivvi and Ovelle are real expressive 3D companions. The owner can hide/show their secondary-colored dot charm. A solo pet can investigate and shove a wobble ball; nearby owners see the same timed play/greeting. A handheld player remains visible with their pet resting nearby. Petting/focus preempts autonomous behavior and Back restores the prior camera.

## Owners and boundaries

- **Astra:** architecture/art review, authored Zivvi/Ovelle model geometry, semantic anchors/part recipe and source Blender/FBX/glTF assets, actual render critique. Headless Blender uses a separate factory-startup scene; unrelated live Blender projects are untouched.
- **Sol pet:** common visual factory, asset/primitive adapter, expression/gait/charms, preference persistence helper and focused controls as coordinated; production construction is shared by Room, remote peers and hatch portraits.
- **Sol garden:** shared layout/activity sampler, server activity coordinator, sole editor of server init, RoomView/RoomCompanions/PetFollow integration. Changed snapshots from one2Hz server owner; positions interpolate each rendered frame. One reservation/epoch owns paired play and toy state.
- **Primary:** integration, Studio imports, test execution, actual controls, captures, evidence, reviewed commit/push and private publication.

The two common catalog IDs `pip` and `puddle` temporarily remain stable aliases for the new visuals. Rare and sparse ownership, stored balances, hatch odds, care rewards and pending result IDs retain their current meaning. This slice does not implement the Stars rename, new egg pools, additional pets, training economy, paid products or a broad world rebuild. Those follow sequentially after this playable foundation is verified.

## Review decisions

Astra approved the plan with these requirements: Focus preempts AI within the server-validated care reach; paired greetings and the toy share one atomic reservation/generation; interrupted peers cannot remain reserved; Board peers remain visible; charm saves have independent acknowledgment and preserve all unrelated profile fields; first-arrival framing must not overwrite a captured user orbit. Existing PetContact remains the only care-reward authority. No AI/AFK award path is added.

## Verification

| Case | Required result |
|---|---|
| Authored geometry/import | Two distinct silhouettes, valid pivots/orientation and semantic anchors;1.35–1.65stud visible body in Room, six readable expressions, no leaf/flame carryover. |
| Solo and shared play | One timed solo shove/return loop; two observers sample the same action/toy state. A late observer joins at current phase. |
| Focus/petting | Immediate interruption, reachable care anchor, original lease rules and saved+1 opportunities unchanged; no award from autonomous play. |
| Charm | Per-owned-pet toggle survives update/rejoin fixture, confirmed state reaches peers, hidden charm has no input/headroom; failed or superseded writes do not counterfeit confirmation. |
| Board/return | Visible avatar keeps physical deck and pet near its anchored position; local garden effects suspend; exact prior roaming orbit returns. |
| Swap/leave/death | Old generation is retired once, reservations released, stale callbacks cannot resurrect rigs/actions. |
| Inputs/preferences | Desktop controls and landscape phone emulation, keyboard/gamepad descriptors, reduced effects and mute; record physical-device and real-controller limitations. |
| Regression | Native new specs plus affected greeting/camera/focus/companion/save and transaction suites; source hash/compile gate and Rojo build. |
| Budgets | Nearest6visitors+local, one toy, existing client render owner, no unbounded tasks/per-pet clocks;20cycles show no growth; warmed180frame×3 samples vs matched baseline. |

Native fixtures, injected peer snapshots and actual multi-client evidence are labeled separately. If two real clients cannot be launched, do not describe snapshot fixtures as live multiplayer. Import/model appearance and save/rejoin require their own proof before private publication.

## Status

Architecture, code and final raster reviews passed. Both authored pets are imported and render through the production factory. Single-client, phone-emulator and two-client controls passed, including the final closer camera. The verified candidate is ready for commit/push and private publication; the published version is tracked in `PLAY-BUILD.md`.

### Native integration results

- The welcome owner-transition stall is fixed: two actual pointer drops now lead to the Zivvi reveal and Meet without resizing.
- All33 imported mesh resources passed validation after a native Rojo reconnect. Invalid templates use a native recipe instead of rendering empty MeshParts. See `assets/garden-babies/IMPORT.md` for the Edit-only repair workflow.
- Camera staging and lens fitting are separate. The accepted target is6.135studs from the owner, within the unchanged seven-stud authority. A26-second actual E hold saved two naturally rolled+1 awards; releasing E ended its lease. Exact Back camera/FOV comparison had zero component error.
- Landscape phone emulation: native charm button saved OFF, Back restored roaming, Deck opened the field and Lounge returned to the same Custom camera. The44px controls remained reachable. This is not a physical-phone test.
- Two real local Studio clients each earned Zivvi through welcome controls. A45-second observation recorded follow, investigate, rest, shove, settle and a shared paired greeting. Both balances/revisions stayed6/3. A visitor saw the other avatar holding a physical deck and its companion in Board rest. The saved OFF charm reached the observer. Closing the owner client removed its actor and rendered companion; the remaining pet continued alone.
- Actual imported day and clock23 pose captures were reviewed by Astra. The clock-only capture is a controlled fixture, not the live day/night lighting. Night color/fill refinement is follow-on work.
- Astra identified an undersized close-up; Sol replaced empty aggregate volume with a bounded focused per-piece envelope. Final strict5-case coverage keeps24 pose measurements55–65% of safe height, and Astra approved the actual curious/contact/released rasters. Stage, reach and legacy behavior remain unchanged.
- Final20 actual handheld/lounge round trips had stable instance counts and unchanged wallet/revision. Final source95/mesh33 gates, native regression coverage195client/90server, Rojo build, diff checks and independent review passed. Counts exclude repeats; the cross-component suite additionally covers72 configurations.

Detailed results, known failed intermediates and evidence labels: `artifacts/garden-vertical-2026-11-08/BUILD-EVIDENCE.md`.

### Baseline and import checkpoint

- Frozen runtime1366c31, desktop1626×994, Medium preference, fixed room camera/FOV65 and ClockTime16.31: three180-frame warmed samples p95 **17.65 /17.78 /17.71ms**;2951 scene nodes,1618 parts,4 lights. Recorded in `artifacts/garden-vertical-2026-11-08/garden-baseline-1366-desktop.json`. This is a local Studio benchmark, not physical-phone evidence.
- Actual fresh welcome controls reproduced a deferred first-hatch presentation stall before this slice. Server receipt existed, but the transition relinquishing presentation ownership did not wake the cinematic. Native device resize woke it. Fix and an actual fresh starter reveal without resizing are release gates; earlier hatch fixtures did not cover this exact ownership transition.
- Astra authored and rendered separate Blender sources. The first FBX imports succeeded in Egg Drop: Zivvi14 meshes, Ovelle15. Source paws origin and measured body sizes are preserved; Studio FBX import faces negativeZ and imports gray. Adapter must rotate once and apply the authored palette. Mixed-material cuffs require a supplemental split-material import before appearance acceptance. Import success alone is not runtime acceptance.
