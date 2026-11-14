# Revision 2 timing polish — accepted base, 14 November 2026

## Native200-pixel receipt sizing correction

Actually inspected `hatch-production/native-item-receipt-size.png`: two200×200 native Scene cells show settled Wobble Top and Ball at3.1s. The floor's exposed side edge is fixed. Its remaining faint horizon is acceptable in this corrected view; no further floor redesign is requested. The toys occupy only about45pixels vertically, so they read too small despite looking large in the earlier full-screen viewport.

**Bounded item-only adjustment:** target settled longest projected dimension110–120pixels in a200-pixel square (55–60% of the cell), with neither projected width nor height exceeding70%. Keep proportions and the tip/contact point planted. In `HatchDisplayItem`, the current initial3D normalization is `.60 * H / size.Y`; use `1.45 * H / max(size.X,size.Y,size.Z)` as the initial generic normalization, then retain the existing swept-frustum fit as the final authority. This is an approximately2.4× size increase for these two toys, not a per-item special case.

Keep the camera angle8° and current field-of-view conventions. For item scenes, start the fixed camera aim at floor+.95H so the contact point reads around78–82% of cell height and the settled object around52–55% of cell height. Let the existing envelope-based camera distance accommodate the full egg, opening shell, item overshoot and signature wobble; fit takes priority over hitting the exact pixel target. Recompute after normalization, and inspect actual200-pixel cells because larger stand-alone screenshots are misleading. Do not add a late receipt-only camera, timed zoom, new clock or resize discontinuity. The borrowed receipt must reuse the same Scene and pose.

Leave accepted Bear normalization/framing untouched. Existing NativeItemArt2D already uses a70%-wide art area; do not apply this3D geometry multiplier to fruit UI art or host-built2D cosmetics. Use the shared geometry path for toy/feature objects so future payloads benefit without catalog-specific multipliers. One corrected Wobble Top/Ball200-pixel screenshot and the existing full-motion egg/hero fit checks close this adjustment.

Spencer clarified that the newer animations are “way better” and only need tightening. **Keep revision2.** Retain its stage, camera, source smile, large eyes, blink, grounded scale/fade and hop. The coordinator reports the refinements accepted with changes; do not reopen the earlier idea-permission gate. This is timing/staging polish, not another redesign.

## Coordinates and shared entrance

Use stage-local axes: R = screen-right horizontal, F = horizontal direction from egg toward camera, U = world-up. Derive F from the camera/egg relationship, not hard-coded world±Z. E is the original egg center projected onto the display floor. H is the final **display** height of the payload. Keep the existing camera fixed. All positions below are relative to E.

- Payload first becomes visible at E, already floor-anchored, scale .72. Travel only **+.08H F** while scaling .72→1.03→1.00 over .38s. Opacity reaches1 after .20s. No lateral drift or rise from below the floor. At every pose recompute the transformed minimum foot/contact-point height; maintain floor+.005H except the explicit pet hop. The slight forward travel clarifies that the reward comes out of the opened egg.
- Lower shell halves keep their own side throughout: left R<0, right R>0. Move each outward an additional .28H R with its original sign, and backward .10H F; outward roll≤20°. Never swap destinations or rotate across the center. Starting .15s after separation, shrink each to .05 of its initial scale and fade to0 over .35s. Scale about each piece's own center, not the shared egg center. Cull once invisible.
- Cap moves +.20H U, +.18H R, −.12H F, then shrinks/fades with the same timing. Keep it behind the payload and clear of the face. No shell may linger during the settled receipt or sweep across the toy handle.
- **All shell pieces and the inner glow core are gone by1.55s.** The core fades before the payload becomes fully opaque. Do not leave a bright overlapping shell silhouette behind the pet.

## Tightened timeline

| Time | Common / pet beat |
|---|---|
| 0–.65 | Short display hold and the existing two unequal rocks; shorten the pauses, not the shapes. |
| .65–.95 | Existing readable crack/gather; one crisp crack sound. |
| .95–1.18 | Shell splits on its own side; cap clears; brief soft opening swish. |
| 1.10–1.48 | Centered, slightly forward floor-anchored fade/scale entrance. |
| 1.48–1.85 | Curious look toward viewer; one existing full blink, source smile intact. Shells finish vanishing by1.55. |
| 1.85–2.35 | Existing crouch/hop/landing, apex+.10H; joy eyes .95 and source smile. Keep shadow on floor; no extra bounce. |
| 2.35–2.95 | Two small quick greeting waves and head counter-tilt. Existing ear perk/tail motion only. |
| 2.65 | Receipt/title/actions fully legible and ready according to existing lifecycle; do not wait through an ornamental tail before the action becomes available. |
| 2.95–4.40 | Settled pleased pose, eye scale .90; comfortable hold. No shell motion remains. |

Retain the current phone panel and reward text. Retiming sound follows the visible event: crack≈.78, opening≈1.02, soft arrival≈1.22, short original happy flourish at hop≈1.95, soft landing≈2.28. Do not add a second large flourish at receipt appearance. Preserve music duck/mute and cancellation ownership.

## Items and cosmetics share the reveal

Use the same first1.48s and shell path for every payload. Then apply **one category-specific motion** from1.50–2.20s, reveal receipt by2.20, and hold to3.10s. Wobble Top has its existing restrained wobble and planted tip; fruit turns15°; wearable is shown on a correctly scaled preview bust; finish uses the real preview pet; a deck cosmetic uses the unchanged device shell. Do not force non-pet rewards through the pet hop/wave, invent new purchasable outcomes, or imply direct-purchase items come from eggs.

Reduced motion keeps the existing brief fade/static happy pose, no shell flight/hop/rock. Shared cleanup, skip, receipt, readiness and input behavior remain authoritative. No new clocks. A native preview must confirm the forward direction and same-side shell travel in the actual camera, not only source coordinates.

## Final visual check

Inspect emergence around1.1–1.5s, shell-clear frame1.55, hop apex, first fully readable receipt and settled item. Check no floor clip, no crossing halves, no handle/face occlusion, and no faint shell remains. Show the actual final preview once ready; no additional creative permission gate is requested by this brief.
