# Sleepy Nest landmark: the code wiring (Opus, 2026-11-24)

Spec: `NEST-LANDMARK-LOOK.md` (Fable). Mesh, template and data: branch `claude/nest-landmark` at `da88bee` (Model
120174604036650; the island session's `NEST-LANDMARK-BUILD-PLAN.md` holds its contract). This file is the code side;
it does not merge that branch. Beta only; live unchanged.

## Plan

- **Switch:** its own onboarding v3 part, **`Onboard.on("landmark")`** (`/onboard landmark off|on|clear`, ConfigService
  `onboard_landmark`, missing = on, under the ceiling), not the corner switch, so the beta can show the twig nest at
  the same spot (Fable: "off draws today's twig nest"). It applies only where the nest stands at the corner's spot
  (corner on and the `W7_EggsStation__` split present): `NestLandmark.applies(on, cornerSpot)`. Elsewhere the twig nest.
- **Template:** `ServerStorage.NestLandmark` (the coordinator mounts it with the merge). `EggCornerWorld` (server,
  ceiling only) copies it to `ReplicatedStorage.NestLandmark`; each client clones it for its own nest (each player's
  nest has its own state) and `PivotTo`s it onto the nest root (the template's pivot is the origin through the
  Collider's PivotOffset). A missing template, or a `LandmarkVersion` other than 1, gives a greybox with the same
  part names. `NestLandmarkData` is read when mounted; `NestLandmark.DataCopy` is its copy (version 1, same pivots).
- **Pure module `src/shared/NestLandmark.lua`:** the numbers (Block 5.6, Front 3.5, prompt (0, 1, -3.5), Bear
  (-2.9, 0, -2.0), pill 5.2, peek 5.6, pin 8.2, egg x1.3 on a base of 2.15, sign, shadow 3.3, scatter 3.0 to 4.0), the
  states (`blanket`, `moon`, `pulse`, `breath`, `sway`, `unroll`) and the switch.
- **Server (`EggCornerWorld`):** the nest's pet box is 5.6 while the landmark stands; `EggNestLight` is disabled then
  (the moon replaces it, never two); both follow `Onboard.changed("landmark")`.
- **Client (`NestClient`):** at open it decides `landmark` with the corner and the spot, and uses that nest's prompt
  point, Bear spot, egg base and scale. Drawing: the model (or greybox) and one code `NestSign` board on the bowl's front
  (tilted back 10, no post, `SignYaw` retired for it) instead of the 21 twig parts; the egg, pill, prompt, scatter and
  shadow stay code parts. Per frame (`poseLandmark`): the blanket (folded / draped with the .6 s unroll from its lower
  edge and a ripple .15 s behind the breath / slipped; dropping over .3 s at the hatch), the egg's breath (every 4.5 s),
  the moon and awning sway about their data pivots (awning +6 when ready), and the moon lantern (a client PointLight at
  `moonLight`, off by day, fading in over 3 s at dusk to #FFE9A6 range 9 at .6, gold #FFE08A range 10 pulsing 80 to
  100% when ready; a halo billboard 1.6 / 2.0; the Moon's SurfaceAppearance tint and emissive strength follow it).
  Zzz drift to -X. The pill sits fixed at 5.2. A switch flip re-opens the nest. `deps.daylight()` reads HollowClock.
- **Show me:** `ThingsTrail` takes `target.lift`; the nest's trail passes `NestClient:pinLift()` (8.2 over the root).
- **Collision:** the template's `Collider` (cylinder r 2.4, 2.75 high) stays CanCollide on the local clone: this
  client's avatar stands on the bowl and never walks through it. Every other part is no collide, no query.

## Not done here (asks)

- The Bear's curl pose on the mat is today's pet rest logic with the new `BearSpot`; its size against the eave is a
  Studio `[check]`.
- The tree-clearance and star-flush `[check]`s are Studio items.
- The moon's dusk "fades in with the lamps" is a 3 s ease toward the hour's target, not the lamps' own clock.

## Specs

`NestLandmark.spec` (9, offline): switch, data, footprint, heights, blanket, moon, breath, sway, unroll.
`NestClient.spec` (+4): the model and sign at the corner spot, the blanket through tuck / ready / the next egg, the
moon by day / dusk / ready, the switch off drawing the twig nest and a flip re-opening it. `Onboard.spec` updated for
the fifth part. `EggCornerWorld` (box size, light, template share) is server code without an offline mock: Studio.

## Code review of 443346b (GO WITH CHANGES): what changed

- **One shared model.** The server (`EggCornerWorld:buildLandmark`) places ONE copy of the template (or its greybox) at
  the nest's corner spot, on the plaza floor found with the old station left out: anchored, its `Collider` solid for
  everyone, `ModelStreamingMode` Persistent, `WorldRestCFrame` / `RestTransparency` on the moving parts and its root
  in `NestRoot`. It stands in the room while the landmark applies and is parked otherwise. A template mounted after
  boot replaces the greybox. The ReplicatedStorage copy is gone. Players without an egg see the bowl with its folded
  quilt and stand on it like everyone else; nothing is rebuilt under anyone.
- **Each client animates that copy locally** (writes to anchored parts never replicate, so each player sees their own
  nest's state): `NestClient:bindLandmark` finds it every frame (a streamed or swapped model is picked up), and
  `restLandmark` puts it back as the server left it whenever this client's nest closes. The field is
  `landmarkState` (no clash with `Client.landmarkParts`), cleared in `clear()`.
- **Moon:** a 3 s linear fade in and out (ready snaps to lit), the halo fades with it, one pcall per SurfaceAppearance
  property. Its daylight comes from HollowClock through `Client.daylightFrom`: `daylight()` (the module has it, line
  204), else `lastDaylight`, else `sample(now)`'s second value.
- **Show me pin:** `target.pinAt` puts it 8.2 straight over the bowl's centre; the prints still end at the prompt.

## Studio check R10 and Fable R10

- **Bear on the mat (kept; Fable called it LATER, but it is in and safe):** the mat is a rest anchor (`sleepy_nest`,
  exclusive) through GardenState's own nook rest: `Garden.extraRests` (nil on live: `Layout.RestAnchors` alone, the
  same table), set by `EggCornerWorld` while the landmark stands. The nest's 5.6 pet box gets a hole of radius 1.3 round
  the mat (`GardenBlockedHole` / `...Radius`, box-local): `GardenWalkability.segmentAllowed` lets a segment through
  only when its part inside the box's margin lies wholly in the hole. No attribute (live, the twig nest): as before.
  The Bear sits there with the nook rest's own pose (no new curl animation).
- **Empty nest:** the landmark never switches off. With no nest of this player's animating it, `NestClient.idleMount`
  (stepped by init's corner block) keeps its idle life: the moon by the hour, the moon and awning swaying, the folded
  quilt, the sign board on its loops, blank but for its painted moon (Fable R10 4). Only the pill, prompt and Zzz go.
- **Height:** the floor ray is an Include filter on the island's own meshes less the old station's (never the old
  EggsSign anchor), and the server looks again 3 s after boot, re-seating the landmark if the marble is elsewhere.
- **Egg:** per-look scales small 1.6, glow 1.75, rocking 1.9, ready 2.0 (`Land.EggScales`; ready's top 4.75, .45 under
  the pill). Tucked + rocking against the quilt is a Studio look.
- **Pill:** bottom edge at (0, 5.2, -1.0) nest-local as a fixed world offset (`StudsOffsetWorldSpace`), the peek at
  (0, 5.6, -1.0), never AlwaysOnTop over the landmark.
- **Ring:** the machine's front arc is 194 degrees, r 3.
