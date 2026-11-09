# Pet materials — glossy luminous Aero pass

Authorized November9,2026 after private v309 / runtime b71c702. Astra owns visual direction/actual review; Sol6.1High implements; independent Sol reviews architecture/source; root controls Studio, uploads, verification and release. Work only egg-drop feat/egg-drop-arcade-polish / place96451847774961.

## Goal and reviewed implementation

Luminous opaque vinyl/jelly babies: vivid readable night pigment, moving broad specular on rounded bodies, glossy dark eyes with visible blink-following catchlights, and stronger matching charm glow. Preserve shaded contour, hue identity, all7 rigs and existing performance bounds. Keep privatev309 as fallback until rendered acceptance.

| Component | Change / owner |
|---|---|
| Shared authored maps and small material template pack | Sol tooling generates original constant near-white albedo, body/eye roughness, nonmetal and emission masks; root uploads through Studio upload_image and authors immutable map properties into the Rojo-mapped template pack. Avoid editing122mesh resources or relying on runtime PluginSecurity setters. |
| Pet material owner | Sol adds bounded module/config. Clone authored SurfaceAppearance once per eligible MeshPart; synchronize resolved Main/Secondary to material tint without squaring hue. Probe neutral-white versus hue emission tint before choosing. Cache normal updates; no per-frame allocations. |
| PetNightSurfaces | Remove nighttime torso/hand darkening and disable flat grouped fill on working PBR; retain restrained role-fill fallback when maps unavailable or geometry is Part/SpecialMesh. No new per-pet lights/global lighting/exposure/bloom. |
| PetFace / GardenPetVisual | Keep eyes dark/nonemissive with lower roughness; restore pale eye mark from old .30 night tint and preserve eyelid/blink hiding. Protect mouth, ivory and blush. Keep expression/transparency ownership. |
| PetCharms | Imported dot can use PBR. Part/SpecialMesh Ring/Pebble must have explicit matching glow fallback; hidden/unselected forms stay hidden and outside hulls. Charm brighter than body without obscuring eyes. |
| Tests and evidence | Sol implements meaningful lifecycle/tint/fallback specs and bounded QA helpers; root checks native rendering, normal controls/visitor, ViewportFrame behavior, console and actual asset load. 2D portraits need palette/identity parity, not invented PBR. |

Astra trial body roughness .27–.36 and eye .10–.18; modest body emission and roughly2× charm contribution, calibrated in actual runtime lighting. Existing production specular .18/diffuse .28 remain fixed. Uniform maps avoid assuming shared UV direction across seven differently authored rigs. No rig deformation, economy/save, world-layout or audio change.

## Edge cases

| Case | Required result |
|---|---|
| Original, Rose5, Tide5 and mixed Main/Secondary | Saved hues unchanged; rendered colors neither squared nor accidentally reset. |
| Blink, mouth and expressions | Dark eyes/ivory protected; pale glints hide and return with lids; no floating eye marks. |
| Hidden Dot/Ring/Pebble, repeated changes | No glow from hidden parts, stale tint or duplicate surfaces. |
| Unsupported/missing/denied/slow map and native fallback geometry | Deliberate bounded readable fallback; do not mark map-less pieces as working PBR. |
| Owner, visitor, focus, hatch/3D previews | Same visual role policy, clear faces/feet/charm; 2D sprites preserve current palette logic. |
| Destroy/recreate/equip/rejoin | Existing cleanup/identity/lifecycle preserved; no reward or profile mutation. |
| Low graphics/phone | Night body/eyes legible; disclose reduced specular and emulation versus real hardware. |

## Verification and acceptance

Capture frozen v309 before runtime edits: same current garden/cameras/actual noon and midnight, all7 neutral and saturated hues, close and normal distances. Record source, measured lighting, asset/render configuration and seven-rig workload.

After source review: native source equality/compile/Rojo; material/appearance/face/charms/focus regressions plus relevant receipt/session checks; asset preload success and error-path tests. Review a camera move so real specular visibly shifts separately from the authored eye mark. Compare neutral and Rose/Tide at noon/midnight, open eyes and blink, visible/hidden forms, normal and low graphics, and actual earned controls. Pursue .60 matched night/noon body luminance without clipping or lost contour; record actual measurements rather than treating a proposed value as passed.

Keep the same seven-rig/world fixture, camera, 180 warm+180 measured frames, repeated rounds if needed for a material performance concern. No physical-phone or live multiplayer/rejoin claim from fixtures. Fix review blockers; publish only the reviewed tested slice to existing private place, then verify Published version and update evidence/rundown.

## Safe pause after neutral-roster steering

Private v316 / runtime c549451 releases only the white/light-grey baseline and active four-pet hatch roster. The material candidate was deliberately excluded, isolated from Studio, and preserved in **stash7f72106e5d3a9444c6ae4b03be975f637e2c0505** (message `wip(pets): gloss candidate awaiting native fetch and render gates`). Its selected tracked and untracked files include maps, binary four-profile pack, source modules, generators, specs and both QA fetch probes. Other unrelated untracked files were untouched. Current Studio Edit/source is the released125-module runtime, no QA objects/material pack,122 MeshParts, production entries enabled. The task HTTP server34875 was stopped. Do not drop the stash or publish it before acceptance.

Root captured frozen v309 before material edits in artifacts/pet-materials-2026-11-09/BASELINE.md, ten matching view pairs and six performance rounds. Candidate raw-URI loading failed even in an ordinary LocalScript: all four callbacks Failure despite GetAssetFetchStatus Success. The same four parented ImageLabels preloaded with callback Success and IsLoaded true. Unparented ImageLabels produced four Success callbacks / fetch statuses but IsLoaded stayed false through12seconds. Full reports are local ordinary-client-fetch-diagnostic.json and unparented-client-fetch-diagnostic.json. Do not infer denied assets or GPU-ready materials from those mismatched APIs.

Next safe action: restore the bounded stash without touching unrelated files; rebase its material-only changes on c549451; have Sol revise the raw-byte fetch check under independent review using the native findings (IsLoaded is unsuitable for unparented labels). Confirm actual processed SurfaceAppearance rendering on the two original rigs before full artistic/performance review. The prior candidate was never bound in the neutral render fixture. The user requested white Main / C8C8C8 Secondary; retain those exact neutral bases while tuning material strength, not per-species pastels.
