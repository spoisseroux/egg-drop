# Plan: player scale (the world feels bigger)

Spencer 2026-11-26 night: "should we scale up the whole world a bit? It feels tiny ... And make it easier to tweak?",
then "OK great let's scale the player then ... build out anything overnight to support that agentically".

## Goal

One number makes the world feel bigger: the player's avatar is drawn at `PlayerScale` (default **0.8** on the beta,
1 on live), so the cave, path, trees, pets and toys read 1.25x larger. Live-tweakable without a publish or a
restart: a chat command `/scale 0.75` / `/scale clear` (owner, beta or Studio) and a ConfigService value
`player_scale`. Walk speed, jump and all world coordinates stay as they are (travel times do not change).

## Changes

1. `src/shared/PlayerScale.lua` (new): the ceiling (FeatureFlags.PlayerScale and the beta place or Studio, like
   `WorldFeel`), `PlayerScale.resolve(configValue, override, ceiling)` (default 0.8 under the ceiling, 1 without; clamp
   0.6 to 1.2; non-numbers ignored), `PlayerScale.parse(message)` for `/scale <number|clear>`, and `value()` reading the
   published workspace attribute `PlayerScale`.
2. `src/server/PlayerScaleConfig.lua` (new): reads `player_scale` from ConfigService (refresh on UpdateAvailable, like
   AliveConfig), keeps the owner override from `/scale`, publishes the resolved number as the workspace attribute
   `PlayerScale`, and on a change re-scales every current character.
3. Applying it (server, `init.server.lua` spawn): before `Lounge.spawn`, wait for the appearance (CharacterAppearanceLoaded,
   up to 4 s) and `character:ScaleTo(s)`; spawn then lifts by the scaled HipHeight. An Accessory added after that
   (late appearance) triggers one deferred re-apply. Scale 1: nothing is touched.
4. The held Pocket Deck (`Lounge.setMode`): its mount offset, each piece's size and offset, and the IK grip attachments
   are multiplied by `character:GetScale()`, so a deck built after the scale fits the smaller hands; a deck that already
   exists is scaled with the character by ScaleTo.
5. Carrying a pet: the fixed stud offsets in `GardenCarePoseData` (client `PetCarePose`) and the server carry anchor
   (`init.server.lua` ~497, root + look*1.2 + (0,.3,0)) multiply by the carrier's scale. The pet itself is not scaled
   (it reads bigger in smaller arms, which is the point).
6. Not changed: WalkSpeed 14, jump, camera zoom (22), cameras that aim at root + offsets (checked in Studio first),
   ProximityPrompt and reach distances (the root drops ~0.6 studs at 0.8), IslandBounds/Dash checks.

## Edge cases

| Case | Expected |
|---|---|
| Live place, flag off | Scale 1: no ScaleTo call at all |
| `/scale 0.75` mid-session | Every character re-scales at once, decks with them |
| `/scale clear` | Back to the config value (or 0.8) |
| Appearance never loads (Studio) | Scale after the 4 s timeout |
| Hat loads late | One deferred re-apply, the hat ends at the same scale |
| Respawn | Scaled again on the new character |
| PetFocus zeroes walk/jump | Unaffected (speeds are not touched) |

## Tests

- Offline: PlayerScale resolve/clamp/parse/ceiling; Lounge deck math at s = 1 and 0.8 (offsets and sizes x s).
- Studio: avatar height at 0.8 (about 4 studs), deck in hand, carrying the Bear, den mouth and path captures with the
  avatar for scale, `/scale` 0.7 / 1 / clear live, respawn.

## Risks

- ScaleTo on a character whose appearance is still loading (accessory sizes), the deck weld order, IK grips.
- Cameras framed on the root (arrival, deck park) may sit relatively high on a smaller avatar.
