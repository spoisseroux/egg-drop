# Beta (12) QA, Spencer, 2026-11-23: triage (Opus)

Source: `C:\Users\skunk\Documents\obsidian-spencer\pocketpals\v3 qa pass 23 nov 2026.md` (6 phone screenshots in the vault root, `Pasted image 20261123114352..115602.png`). Standing look rule from today: ambient life and world dressing realistic and textured so the pets stand out (memory `ambient-realistic-textured`).

## Passed
- Row 4 blue garden: good. Row 5 footprints and tips: worked. Row 9 island edges: good for now. Row 16 day/night: looks good.

## W. World (sent to the island re-export session, local_a0f7d8a7)
- W1 Trees: proper leaf meshes; he clips into crowns.
- W2 Lime crowns less glossy. (The fruit he may have seen is the Dewdrop fruit, looks only.)
- W3 Waterfall: still awful after beta (10). Full rework, Fable from scratch.
- W4 Meadow bubble fountain -> a regular fountain with a splash sound that grows as you get close.

## L. Garden life (row 7)
- L1 Butterflies: wings snap between two poses; softer, slower flutter, less eye-catching; realistic textures; at night they become fireflies (today they just hide).
- L2 Petals read as explosions; want ambient drift spread over the garden, not bursts at a crown; greener (leaves?).
- L3 Birds: cuter, more realistic, textured.

## S. Sound
- S1 Intermittent "toilet flush" sound, new, hated. Best guess: the wind rustle (`AmbientAudio.RustleId` 131058187750745, swells with gusts). Confirm with `/alive wind off`, then replace or remove.
- S2 A soft notification sound when a new tip comes in.

## U. UI
- U1 Notification text a smidge lower in its card.
- U2 Pet tag (name + "Heart 1"): dead space right of the name, too little bottom padding, heart capsule tighter. "Heart 1" is the stat tag; explain or drop it.
- U3 Dash mode picker: crude. Spotlight the active pet with a run animation, stats to the right.
- U4 Dash HUD: the sprint and jump symbols are unreadable; new icons.
- U5 Dash start: pets overlap; wider start line; show every racer's name at once.
- U6 Dash results: sparse, not exciting, unclear what to do next (podium, prizes, pet moment, clear next step).
- U7 Deck results: "See you tomorrow" strip borderline unreadable; right-hand buttons have dead space, compact them. A thoughtful Pocket Deck UI pass for the Egg Drop game in general.
- U8 "Menus don't look any different": by design, row 1 only made them springy; the look change is the v3 colour and material rework (S15).

## O. Onboarding and nest
- O1 The sleeping egg is not understood. Explain it in plain words on the nest and the first tuck-in ("The Bear's egg naps for 8 hours. Come back to hatch a gift.").
- O2 Nest model crude: Fable remodel. Move it to the plaza (one nest, where everyone passes)?

## G. Gameplay
- G1 Pets teleport to their player when too far away or stuck.
- G2 Garden finds (row 6): not seen. Check in Studio (needs ~1 min of walking; beta has no `garden_finds` config so it should be on).
- G3 Dewdrop fruit (row 15): not seen; looks only. Check in Studio; make them easier to notice.
- G4 Garden Dash: other players see racing pets run the course (pets are server-side). His question: how to handle it.

## T. Test tooling
- T1 "Should we reset the progress on keehar01 to test?" (row 11 needs a new save). No reset command exists. Option: a beta-only owner command that starts a fresh save and keeps the old one as a backup.
