# Before the next live update (compiled 2026-11-27 from TODO, V3-TEST-PASS, PLAY-BUILD, FeatureFlags)

Live runs the live line (v1201/v1202). The beta line is `fix/beta25-feedback` at beta 42.

## 1. Blockers
- Beta (42) notes (21) are being built now.
- Your test passes. Nothing in V3-TEST-PASS is confirmed yet (rows 1-69, Results table empty).
- A phone, gamepad, two-player and frame-rate pass, all never run on v2 and v3.
- Live saves have never run the beta code (the beta has its own saves). The live line's own fixes (G1/G2, the v1055 hotfix) must be carried across.
- Built offline but not seen in Studio or reviewed: garden hour E+F, onboarding D+E, Dash client S6+S7.

## 2. Your decisions
- **Which beta features go live.** Each module has a beta-only PlaceId gate (Alive, Levels, Dash, Aero, Things, Finds, Onboard, GardenHour, Tier, ...). Also ParkHollow, ParkTopLawn and PlayerScale 0.8.
- **Prices and rewards:** the paint-pot price (Stars, if any are ever sold); an Outfit Egg; Dash prizes (`garden_dash_prizes`, off); the Glimmer rare tier (1 in 500).
- **Store listing** text, thumbnails and icon, and ad spend.

## 3. Audio
- **Night music: none today.** Only crickets play at night, and the 1-hour day/night cycle itself is beta-only.
  - Fable's design (`artifacts/qa-2026-11-23-beta14/RACE-AND-MUSIC-LOOK.md` section 3, Route A) is a night mix of your `garden-loop.wav`: in step with the day loop, 3 LU quieter, crossfading on the garden hour. Your stems are exactly what that needs.
- **Zero ids or not uploaded:** the stork, tap, shell and crumb sounds; Aero sounds; bumble balls; crunch toys; the balloon burner. The machine sounds are silent until uploaded.
- **Placeholders:** the race song, the wind bed, the garden ambience.
- **Stand-ins:** the deck knock, trail pat, fur brush, squeak, sparkle and pop. The ASMR hatch set is uploaded but you haven't heard it.

## 4. Release steps (AGENTS.md)
1. Run the translation export and sync. This needs `ROBLOX_LOCALIZATION_KEY` or the `--emit` route. Many beta strings are unsynced.
2. Code review of everything going live.
3. Check the hash against the repo; strip ZZSpecs; stop Rojo.
4. Publish from a fresh window on the restored live world (dev window autosaves carry the beta world).
5. Set the remote switches and the PlaceId gates first.
6. Audit the store listing (description, both thumbnail sets, icon, ads).
7. Restart the servers.

## 5. After ship
- The night garden song.
- Clip and share moments: rare tier, server announcement, share prompt, invite.
- The zero-id sounds.
- Grass and ferns, painted balls.
- Tug of War and Treasure Hunt, capes, training courses.
- v4: cartridges, weekly world reskins, UGC.
