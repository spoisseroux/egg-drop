# Jelly native probe — executable fixture

Fixture: `scripts/JellyMaterialPreview.lua`. Studio **Client** only; coordinator executes. No production source/module/catalog/save/Lighting changes.

```lua
local study = require(fixtureModule).new(clientFolder, game.Players.LocalPlayer.PlayerGui, {
    size = Vector2.new(1280, 720), palette = "both",
})
local ready = study:waitReady(15)
game:GetService("RunService").RenderStepped:Wait()
print(game:GetService("HttpService"):JSONEncode(study:report()))
study:preset(1) -- matched day/front
-- Capture then preset2 day35,3 night35,4 real blink,5 real joy,6 back160.
-- 15% fallback: study:set({alpha=.15})
-- Night only: study:set({daylight=0})
-- Stop/remove only this disposable fixture:
-- study:destroy()
```

Four columns Standard / actual Gloss / actual legacy Metal / Jelly .14-roughness proxy; two rows current Original and actual Rose body/Tide secondary. Full and phone sizes share the same actual .72 Bear scale; camera is common to every column/row, with one explicit size/aspect adjustment. For readable phone detail create a separate one-row fixture with palette `original` or `roseTide` and size812×354. No per-finish normalization. Source camera of running experience untouched.

`waitReady` returns reports without throwing if native packs/templates fail: **require nativeReady=true before labeling a capture a valid four-finish comparison**. Each row reports actual/expected body profile, AuthoredMesh backend, mesh IDs, exact part alpha, visible face/wearable/charm opacity, scale, physical bounds and conservative frustumFits. Wait one rendered frame after create/resize before final geometry reporting. Missing profile or wearable must be recorded, not described as verified.

Important compatibility findings:

- Current runtime Original is white#FFFFFF / secondary#A8A5AE (PetBaseColors), not the gold Bear referenced by the creative proposal. Fixture preserves and labels this actual Original; no invented recolor.
- Jelly currently uses real Gloss maps (roughness36/255≈.14), explicitly a preliminary proxy; final target64/255≈.25 has no authored uploaded map in this fixture. It does not create or activate BodyJelly.
- Two-tone alpha remains Overlay color blending. Per-part transparency .22 body/head/limbs/outer ears/tail and .12 muzzle/inner ears is applied **only inside this fixture after the normal visibility owner**. Hidden expression pieces remain1; visible faces/accessories/charm retain authored opacity. No global or saved alpha.
- Local day/night colors and explicit Materials.paint(daylight) permit repeatable native viewport comparisons without writing Lighting or HollowClock. A cloned Sky supplies cubemap reflection, important because ViewportFrame without Sky defaults to zero environment lighting and can misrepresent Metal. [Roblox ViewportFrame documentation](https://create.roblox.com/docs/reference/engine/classes/ViewportFrame), [viewport reflection guide](https://create.roblox.com/docs/ui/viewport-frames).
- This fixture does **not** prove actual garden shadows or full world lighting/environment behavior. No fake contact-shadow mesh is added; the floor is a reference plane. Source CastShadow is retained but worldShadowProof=false. Native workspace verification is a later coordinator gate.
- Numeric face opacity does not prove depth occlusion: inspect back160 capture for far eyes, side intersections and camera-dependent sorting. If22% fails, capture15%; if both fail, return actual frames to Astra before a production approach. No hidden camera-culling/occlusion repairs.
- Source mesh/material copies are fingerprinted from names/IDs/transforms/maps/properties and asserted unchanged after operations and destroy. Fixture lifetime has no per-frame rendering connection; only explicit set/preset/waitReady updates. Native readiness callbacks belong to this fixture's bounded queue and are cancelled by visual destruction.

No claim or production renderer code has been written. Code review and actual captures/Astra critique pending.

## Actual first run / candidate map mode

Coordinator's first production-mode run showed nativeReady=false: Bear Standard binds BodyTwoTone correctly, but Gloss/Metal/Jelly body surfaces fall back to BodyTwoTone. Source `assets/pet-materials/PetMaterialsTwoTone.model.json` marks all finish variants NativeVerified=false. This is a real existing production fallback; no assets were marked verified.

Explicit disposable probe option: `new(...,{allowUnverified=true})`, or `api:set({candidateMaps=true})` on a fresh clone of updated fixture. This uses the renderer's existing per-visual allowUnverifiedFinish flag only, with a visible UNVERIFIED CANDIDATE MAPS banner. Reports include actual body map IDs, AlphaMode and native-verified status. productionReady remains false; nativeReady now means actual requested mesh/profile available for this candidate study. Require every row.frustumFits=true separately. Do not label candidate maps as production-approved finishes.

## Astra native review and candidate v2

Astra reviewed eight actual first-run native images and returned NO-GO at22%: background stripes made the head/torso hollow with internal disc seams/back artifacts. Fixture v2 defaults to the exact next candidate: body/limbs15%, head8%, muzzle/inner ears8%, outer ears/tail12%. Opaque face/accessory/charm behavior remains. api:set can independently override alpha/headAlpha/earAlpha/secondaryAlpha; report state plus bodyTransparencies traces actual part values.

A deterministic32×32RGB constant roughness map64/255≈.25098 is staged as roughness-jelly-025.png with SHA in the adjacent JSON. It has no gamma/sRGB/ICC metadata and was generated through the existing PNG encoder without executing that encoder's asset-writing main. Coordinator uploads it and supplies an explicit image asset URI. api:useRoughness('rbxassetid://ID') or new options.roughnessId changes only BodyGloss/BodyTwoToneGloss RoughnessMap within **Jelly-only disposable template clones**; all other maps/Overlay are asserted unchanged. Standard/Gloss/Metal comparison packs stay untouched. The runtime's existing surfaces are rebound only on Jelly when their roughness ID differs. Asset loading gates nativeReady and bodyMaps must report the uploaded ID. Security or loading failure is explicit, never described as rendered proof. No .25 approval is implied until actual new native frames/Astra review; no production template marked verified.

Independent v2 code review: UI Sol GO for candidate-only fixture. Separate Jelly template clones/MaterialOwner isolate roughness edits; onlytwo named profile maps change, non-roughness fields are asserted unchanged, failed assignment is explicit, correct-map replacement is Jelly-only and its warmup ticket gates nativeReady/cancels at destroy. No production source/native flag mutation. Require actual row.bodyMaps.roughness equal uploaded ID, allfrustumFits and new native frames before creative acceptance; world shadow proof remains open.

Delivery checkpoint: upload91575369316154 is a Decal wrapper, not the image URI for SurfaceAppearance. Coordinator extracted actual Image75946070025172, but ContentProvider fetch FAILED. Do not mark ready/verified or approve the .25 native look. Recheck actual image delivery and rerun candidate nativeReady/allfrustum/map-ID/sourceUnchanged checks. User reauthorized computer use after a physical interruption; coordinator handles further native controls. No native/Astra final Jelly GO yet.
