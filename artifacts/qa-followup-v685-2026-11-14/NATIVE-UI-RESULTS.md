# Unpublished native UI results

Private phone QA remains **v685**. These source changes and captures have not been published. No server restart or cloud localization change was made for this follow-up.

## Actual images

- [Disclosure timing](native/disclosure-contact.png): actual Toy/Hue/Material renderer at 0.7s, 1.25s and 3.1s. Mystery headings precede the existing 2.2s item receipt beat; truthful names appear at receipt.
- [Four pigment jars](native/final-jars-contact.png): Rose, Tide, Citrus and Iris. Stable saved IDs and recolouring behavior are unchanged.
- [Final production finish samples](native/final-finishes-contact.png): round Gloss, Matte and Jelly under the same source-backed camera, lighting and owned garden reflection environment.
- [Round fallback and ready sample](native/fallback-ready-native.png): labeled component fixture using the real production preview module; the opaque loading fallback is explicitly unverified. It is not a proposed player screen.

Updated [Toy](native/toy-hatch-updated.mp4), [Hue](native/hue-hatch-updated.mp4) and [Jelly Material](native/material-hatch-updated.mp4) movies each use 39 actual renderer frames at 12 fps, followed by a one-second held receipt. Their audio is a matched PCM soundtrack, not a recording of Studio output; Material includes the Rare answer. Silent cropped GIFs are alongside them. [Manifest](native/animation-manifest.json).

Full native frames are alongside the contact sheets. Contact sheets crop and uniformly resize the captures; no geometry, colours, text or rendering were edited. Receipts are synthetic and no purchase, grant or acknowledgment was sent. Hatch ages are time-stepped through the real presentation code. These images establish appearance and disclosure, not an end-to-end transaction or phone texture delivery.

## Engine checks

Targeted cases passed across fresh Play runs: HatchIdentity **3**, HatchDisclosure **4**, and MaterialFinishPreview **10** (including independent owners, cancellation, timeout, late/incomplete/replaced Sky sources and teardown). The first material run had the original seven cases; the later ten-case run includes the shared environment amendment.

Final UI/audio source was then restarted together and **100 client cases passed**: HatchRarityCue5, HatchRarityAudio3, HatchNativeCinematic1, HatchNativeHost2, HueItemReveal5, HatchDisclosure4, MaterialFinishPreview10, LoopAudio16, AmbientAudio7, HueEggView15, HueSwatchInspection9, FirstSpendReconcile2, FirstSpendToyHost3, HatchIdentity3, HatchCinematic10 and FirstSpendGuide5. [Raw results](native/native-test-results.json). HatchCinematic includes legacy fixture geometry checks; this does not claim that all those pets have new native art. The world path remains a separate pending check.

`native/final-swatch-readbacks.json` records the actual ordinary-client previews: `ProductionPBR`, `BoundSixFaceSky`, source `WorldSky`, Core mesh `97136732817875`, and the exact verified BodyGloss/BodyMatte/BodyJelly profiles. Gloss/Matte transparency is zero; Jelly is `0.15000000596046449`. Readiness records completed geometry and verified material binding; it does not assert arrival of every GPU texture on another device.

## Review

Sol independently approved the visual implementation and shared-Sky amendment. Astra approved the actual delayed headings, four pigment jars and final source-backed material comparison: [visual review](UI-VISUAL-REVIEW.md). The initial flat Gloss/Matte frames and disposable Sky diagnostic are retained as diagnostic history; use the **final** finish contact sheet for the current result.

The existing native pet egg opening, hop and wave remain the approved choreography. This slice does not add the older Smash-style intro.

## Rarity audio delivery

An ordinary LocalScript ran the actual BoardAudio and native Material hatch at its normal real-time clock. The existing finish asset `103058048084589` loaded with duration `0.0799773s`. Jelly played the unchanged Material body at speed/gain1, then both separately owned Rare notes were accepted at ages **2.32395s** and **2.47336s**, gain0.035, speeds1 and1.189207. Gloss played the same Material body and no accent. [Native readback](native/real-rarity-audio-readback.json); the disposable bootstrap is archived alongside it. This verifies scheduling and engine playback acceptance, not subjective listening.

[Common Material audition](audio/material-common-matched.mp3) and [Rare Material audition](audio/material-rare-matched.mp3) share the same opening and body. The local report/review confirms exact source prefixes, unchanged original assets and bounded combined peaks. Feature Common/Uncommon/Rare auditions are also available, clearly labeled as examples for the currently disabled Feature Egg. Toy/Hue outcomes without authored rarity stay Neutral. Current garden/deck music remains v3.

Local localization CSV regenerated with **592 strings** using a separate review-file output, preserving the unrelated existing hardcoded-strings CSV. Cloud sync remains for a future authorized publish.
