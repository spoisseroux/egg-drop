# Private v685 QA follow-up — five focused fixes

Astra direction, 2026-11-14. Prepare unpublished changes while Spencer tests **private v685**. No publish or live-place change is authorized by this brief. Preserve the accepted native hatch choreography and v3 music. The question about a Smash-style pet intro is answered below; it is not an instruction to rebuild it.

## Actual evidence reviewed

Viewed `native-review/second-park-native.png` and `jelly-garden-comparison.png`, plus contact sheets extracted from the actual native Bear, hue and material MP4s at two frames per second. The extracted inspection sheets are in this folder. These are existing-build evidence, not new mockups.

- The Bear sequence starts with the spotted egg, reveals a dim then fully lit Bear, and follows with the expressive pose and receipt. It does not show the old Smash-style title-impact sequence.
- The hue card already says **“Rose fruit” while the egg is still closed**. The revealed jar visibly contains a pink fruit form with a green leaf.
- The material card already says **“Jelly unlocked!” before the egg opens**, then reveals a pointed star/snowflake form. Source inspection confirms `MaterialFinishPreview` upgrades its spherical fallback by cloning `Bear__CharmDot`; its name `ProductionFinishSphere` does not make that mesh round.
- The grove image shows the orange through-path squeezed directly against the park's east gateway/fence area. The replacement path should wrap around that footprint with a clear approach.

I cannot hear the MP4/audio files through my available tools. Audio direction below is a specification; no listening approval is claimed.

## 1. Subtle rarity sound differences, after the reveal

Keep the familiar opening/anticipation and shell-pop timing identical across tiers. Let the small **post-reveal finish** carry the distinction. No rarity hint while the egg is closed, no louder jackpot blast, no additional waiting time.

| Authored presentation tier | Finish character |
|---|---|
| Neutral / Common | Current short rounded finish; one soft resolved ping/body. |
| Uncommon | Same body, one faint upper shimmer about 80–120 ms later; approximately the same overall level. |
| Rare | Same body with a clear but short two-note upward answer, about 120–160 ms apart, then a soft tail. Total added answer at most 450 ms; no sustained fanfare. |

Use canonical authored rarity metadata where it exists: FeatureCatalog Common/Uncommon/Rare and the actual pet rare designation. For material rewards, **author an explicit presentation mapping: Jelly → Rare; Gloss/Matte/Standard → Common**; legacy or unknown materials may use Neutral. This is a fixed artistic classification, not a calculation from the currently remaining pool. Unknown Toy/Hue/items are Neutral unless they already have explicit canonical metadata. Do not infer rarity from conditional odds, ownership, price, colour brightness, earned status or duplicate status. Do not introduce Epic/Legendary labels.

Keep crack/body loudness steady, accent peak no more than roughly 1 dB above the existing finish and comfortably below clipping; differentiated rhythm/timbre matters more than loudness. Do not globally change playback speed of a combined timed hatch file, which would move its shell pop. Use a scheduled accent or correctly aligned variants. Preserve mute, ducking, skip, reduced-motion and replay/receipt lifecycle behavior; a skip must not dump queued notes into a burst. The rarity cue accompanies the actual disclosed result only. Supply matched Common/Uncommon/Rare short auditions for listening, stating which tiers are genuinely used by each reward family.

## 2. Mystery heading until the result is visible

Before the hero is visibly revealed, replace item identity with a neutral, localized heading such as **“A little surprise”** and neutral anticipation copy. The existing item/result name, material name, unlock wording and item-specific description must not appear above or below a still-closed egg. Include accessibility labels and result-specific button text in the disclosure audit.

Switch to the truthful result heading on the shared choreography's **hero-visible reveal beat**, never from an unrelated timer or before the geometry is visible. It is acceptable to wait for the existing receipt beat if that is the host's coherent ownership point. On Skip/Reduced Motion, go directly to the settled visible item and its real title together. An already-settled reopened receipt may show the title immediately. Keep the receipt action's current safe timing; do not expose a clickable action earlier just to match the title.

Acceptance: side-by-side native frames immediately before opening, first visible hero and settled receipt for Toy, Hue and Material, including a slow-loading/fallback preview. No result identity should precede the actual reveal.

## 3. Pigment jars contain pigment, never fruit

Keep the recognizable compact clear jar, pale lid and existing palette colours. Replace the fruit/leaf/seed silhouette with a **single rounded mass of coloured pigment**, with a gently curved fill surface and a restrained highlight. No literal fruit inside, fruit-shaped blob, leaf, stem or floating decorative fruit label. At phone size it should read as colour in a jar, not food or a tiny collectible pet.

The awarded object is a colour/pigment jar. Update visible/accessibility names and instructions that call it “fruit” to truthful jar/colour wording within this affected flow, while retaining stable saved item IDs and economy/receipt behavior. Example final heading: **“Rose colour”** or the project's established localized **“Rose jar”** convention; use one consistent naming rule across hatch, inventory and use action. Do not rename the underlying save identity as an art fix. Preserve the advertised current recolouring behavior.

Acceptance: all four current jar colours rendered at native receipt size; a neutral jar shape across colours, and a text search verifying that old edible-fruit wording is not left in these affected player flows.

## 4. Materials use an honest round PBR swatch

Use a dedicated smooth **round sample sphere** with valid mesh UVs and the actual verified production finish profile. An existing proven round Core mesh may be reused if it is genuinely spherical and supports the material correctly; do not reuse a charm, pet body with appendages, pointed star or snowflake. Keep the existing simple teal body colour, consistent light, soft ground shadow and approximately 70% viewport occupancy so the finish is easy to compare.

No eyes, ears, bow, jewellery, pet pedestal or attachment loop. This is a material sample, not an awarded pet/charm. The settled heading names the finish; the supporting copy should clearly say **“Material for your pet”** or the existing equivalent. Jelly must use the actual production Jelly opacity/SurfaceAppearance behavior; Gloss and Matte must stay visibly distinct under the same camera/light. Do not solve Jelly with a flat translucent overlay and call it production PBR.

During asset loading, retain the round fallback and replace it only with another round swatch. No sphere-to-star shape change. An unverified fallback must not report ProductionPBR readiness. Preserve cancellation/late-load safety and do not create a second lifecycle owner.

Acceptance: actual native Gloss/Matte/Jelly swatches side by side, plus fallback→ready frames. Confirm the real mesh is round, correct production profile is bound, and the title arrives after the reveal.

## 5. Curve the through-path around the grove park

Keep the grove park center/equipment and its open gateway. Reroute the orange path around the **east/outside edge** of the grove footprint, joining the existing approach at both ends with one broad, smooth curve. Use the site geometry/coordinates rather than guessing left/right from the screenshot. Preserve current path width; retain at least a two-stud grass buffer between the through-path edge and the closed kerb/fence wherever the gateway apron is not present.

The primary east gate gets a short, broad connecting apron from the new curve. Do not put the through-path under a fence, swing or bench, narrow the gate with a sharp turn, or produce a fork that visually sends walkers through equipment. Keep the secondary opening passable. Match the existing path material, colour and height; no new decorative edging, paving theme or furniture. Prefer one clean path silhouette with smooth joins to overlapping thin patches.

Acceptance: actual overhead and normal avatar-height views show the entire route and both joins. Walk the through-route and enter/leave the main gateway without touching park equipment. Check ground heights/collision, no raised lip or gap, no new coplanar flicker, and no path cutting into nearby tree/building/cliff footprints. Coordinate with the world's existing path/collision generation so a rebuild preserves it.

## The Smash-style question

**Current v685 uses the newer native pet reveal: spotted egg opening, centered Bear emergence, a hop/expressive greeting, then its receipt. It does not retain the older Smash-style impact/name-slam intro.** The actual reviewed contact sheet supports that distinction. QA can continue on v685 while these five fixes are prepared; this brief does not replace that published build.

If Spencer later requests more theatrical pet entrances, a bounded follow-up could add a short silhouette hold, one impact pose and one name-card entrance within the existing native scene, preserving skip and Reduced Motion. That is an option to discuss, not work authorized by his question. Do not restore the old Smash presentation or redesign all item hatches in this slice.

## Handoff and evidence

Sol UI/hatch lane owns rarity cue policy, disclosure timing, jar shape/copy and the spherical finish sample. Sol world lane owns the grove path only. Coordinator owns Studio validation, actual captures, localization sync before any future authorized publish, and release decisions. Do not claim these fixes are live before they are integrated and later published with authorization. Astra reviews the actual new images for the four visual fixes and can review audio implementation evidence honestly; Spencer's listening determines whether the rarity accents sound right.
