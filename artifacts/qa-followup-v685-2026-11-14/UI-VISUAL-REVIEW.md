# Native UI follow-up review

Astra, 2026-11-14. Reviewed actual Roblox captures `native/disclosure-contact.png`, `native/jars-and-finishes-contact.png` and `native/material-receipt.png`. These are visual findings, not listening approval or a release authorization.

**GO: disclosure timing, pigment jar silhouettes and round Jelly material sample.**

- Toy, Hue and Material headings remain “A little surprise” while the egg is closed and at the first visible item frame, then change to the truthful result at the settled receipt. The name no longer spoils the closed egg.
- Rose, Tide, Citrus and Iris jars read as containers of colour, with consistent jar/lid geometry and no fruit, leaf or stem. “Rose jar” and the corresponding colour names match the new art.
- Jelly now appears as a round teal sample with “Material for your pet” copy, rather than a star-shaped charm. Coordinator's native readback confirms the genuine EggCore mesh, verified BodyJelly profile and production opacity. The visual no longer implies a pet or charm was awarded.

**Initial capture finding, resolved by the shared-Sky diagnostic below:** Gloss and Matte did not visibly differ in the first native capture. Both displayed virtually the same cyan sphere and broad highlight. Correct profile attributes alone did not establish a meaningful material preview.

Keep geometry, colour, camera and lighting identical between finishes. Test reduced ambient fill and a stronger off-axis key; investigate a shared reflection environment only if supported by the actual Viewport renderer. Verify the roughness maps and their rendered effect. Do not paint a fake highlight onto Gloss, alter its colour to create a distinction or change production pet materials to make the preview pass. Capture the same-size Gloss/Matte pair again. If the renderer cannot express the difference, report that limitation and discuss an honest preview treatment rather than labeling indistinguishable images visually verified.

These requested lighting checks do not reopen the accepted title/jar/spherical-sample fixes. Runtime audio, world-path acceptance and final native regression checks remain separate.

## Shared reflection environment diagnostic — GO

Viewed the actual `native/diagnostic-sky-contact.png`, made in disposable Play with the existing garden `WorldSky` cloned into each finish ViewportFrame. The coordinator confirms the same camera, lighting, geometry and production profiles were retained across all three samples; only the shared six-face environment was added.

**Creative GO for this shared-Sky solution.** Gloss now has a compact, crisp white glint. Matte remains diffuse without that bright point. Jelly has a gentler highlight and softer body. These distinctions are readable at the shown receipt size and come from the real finish under a common environment, rather than different colours or painted highlights. No further art refinement is required.

The diagnostic is not yet source implementation. Sol should carry this exact common environment into the preview owner's lifetime, with the same round fallback/cancellation guarantees, then the coordinator should capture source-backed native parity. No new assets, per-finish fake decorations or production material edits are needed. This closes the visual-direction concern; release and regression validation remain with the coordinator.

## Final source-backed native parity — GO

Viewed `native/final-finishes-contact.png` and `native/final-jars-contact.png` from the coordinator's fresh Play run of the actual updated runtime source, without diagnostic mutations. **Final visual GO for the UI fixes.** The shipped-source candidate reproduces the accepted distinction: compact bright Gloss reflection, diffuse Matte, softer Jelly, all on a round sample under the same environment. All four jars retain the clean pigment-only shape and truthful colour-jar names. Earlier disclosure timing GO remains unchanged.

Coordinator reports the 10-case native MaterialFinishPreview suite passing and `final-swatch-readbacks.json` confirming ProductionPBR, BoundSixFaceSky/WorldSky, the real EggCore mesh, correct verified BodyGloss/BodyMatte/BodyJelly profiles and Jelly transparency about 0.15. These support the observed parity; the visual assessment above comes from the actual images. No further UI art changes requested. Audio, world-path review, release authorization and publication remain separate.
