# Remaining-build creative brief

2026-11-14 · Astra → Sol implementation · User lifted QA hold; **no publish**. New concept renders are authorized. Production Blip enablement still waits for Spencer's selection of actual renders. This document supplies implementation defaults, not rendered approval.

## Blip D/E/F: procedural concept round

Read-only review: `scripts/build_blip_v2.py` preserves topology, the Bear-sized face kit and a pale muzzle patch while warping an existing head. Its A/B/C renders (`artifacts/blip-v2-2026-11-14/blip-v2-contact-sheet.png`) retain an oversized torso relative to the head, conspicuous pale eye surrounds, stalks and angular feet. The user rejected all three as insufficiently cute, and v1 as Bear-like. This round must replace those proportions and face surfaces, not apply another scale preset to them.

**Tooling direction:** a new concept-only script may reuse v2's root-space/BVH surface placement and render helpers, but create fresh smooth rounded mesh pieces. Do not change the v1/v2 source blends or production exports. Save separate D/E/F concept blends in the new artifact folder. Preserve named attachment positions only as reference empties; no promise of production rig or wearable compatibility. No image generation, borrowed character shapes, external AI assets, exports, uploads or feature-flag changes.

### Common geometry, in Blender pet-local units

Z up, front = -Y; sole = Z0. Render alongside the existing Bear at its actual authored scale. Dimensions below are starting dimensions that Sol should implement exactly for first review; Astra will revise against renders.

| Piece | Center / shape |
|---|---|
| Body | Ellipsoid center (0,0.015,0.405), radii (0.29,0.245,0.285). Make the upper third 12% narrower for a tiny pear tummy. |
| Head baseline | Center (0,0,1.05), radii (0.55,0.37,0.45): bottom .60, crown 1.50. Rounded continuous surface; cheeks gain 5% width around z.88–1.02, crown narrows gently. Thus head occupies 60% of crown-to-sole height. |
| Hands | Centers (±.31,-.015,.48), radii (.12,.14,.17); rotate outward 12°. Short mittens nestled against tummy, no long shoulders or separated elbow. |
| Feet | Centers (±.15,-.055,.105), radii (.145,.19,.105). Round slippers, toes toward -Y, soles exactly z0. No ankle gap. |
| Cream belly | Surface-conforming oval, center x0,z.39, width .36,height .37. Follow the front body surface at a .004 offset; no floating oval plate. |
| Eyes | Centers x±.18,z.96; each visible ink oval width .24,height .34; convex depth .035. Conform/bend to the head surface, with no white ring. Inner gap .12. Keep both eyes equally sized in front view. |
| Eye shines | Two cream-white surface marks per eye: radius .034 at eye-local (-.036,+.065), radius .013 at (+.039,-.050), using eye-local X/Z. Place on the visible convex eye surface, not behind it. Both eyes use the same lighting direction; do not mirror the primary shine. |
| Mouth | Small soft U at x0,z.775, width .066,height .028; dark rounded stroke .010. No nose, muzzle, projecting snout or teeth. |
| Blush | Two soft coral ovals at x±.335,z.81; width .095,height .045; follow the cheek surface. Keep them subordinate to the eyes. |

Use enough radial segments to avoid polygonal feet, eye rims and silhouette corners in a 768px render (e.g. 24×16 ellipsoids; 32×20 head). Smooth shading; no visible faceting. This is concept geometry, not the production triangle budget. Avoid narrow necks, anatomical fingers, a pointed crown, paired circular ears or long antennae.

### Three silhouettes

**D — Pebblecap (default lead).** Head baseline above, gently squared with rounded corners (superellipsoid exponent ~2.3, never a box). One thick folded crown lobe rooted near (-.13,+.04,1.41), bending backward through (-.13,+.20,1.51) to (-.10,+.32,1.43); tube radius .105 reducing to .075, rounded end. Blend the root visually into the head; no ball at the tip and no long stem. This fold adds at most .12 to total silhouette height. No tail. Read as a heavy soft dome and small body, not a pointed droplet.

**E — Puddlecheek.** Head baseline with width radius .58; crown width reduces 14%, cheek band widens 7%, keeping the .90 head height. Two short soft cheek fins rooted at (±.48,+.01,.98), sweeping outward/back through (±.60,+.10,.88), ending (±.59,+.20,.82). Fins radii ~(.12,.095,.14), rounded flattened forms integrated into the cheeks. Nothing protrudes above the crown. No tail. Keep the forehead deep: flattening the entire head would repeat Saucer's failure.

**F — Pillowbud.** Head base radii (.51,.37,.45), gently squared exponent ~2.25. Modify its *continuous* upper contour into two unequal broad crown lobes: left high point (-.20,0,1.56), right high point (+.22,0,1.50), center saddle z1.46. Use a smooth vertex deformation or unified mesh, not two ear balls pasted on. The saddle is shallow; no ear pits. Small rear nub centered (0,+.27,.42), radii (.10,.12,.10), no spiral. The tall broad crown must distinguish this from D's backward fold and E's lateral fins.

### Material and render package

- Mint `#94DFB7`; warm cream `#FFF0D2`; eye/mouth ink `#24313B`; blush `#E98F99`. Body roughness .36, IOR 1.45, metallic 0; eye roughness .12. Avoid emission on bodies/eyes and glossy forehead hotspots. Eye highlights are deliberate geometry/material marks as well as ordinary lighting.
- Neutral world `#DCE1DE`, ground `#B9C5BE`, broad soft key from camera-left/front, weaker fill from camera-right, restrained rear rim. Standard color transform with neutral exposure; keep mint recognizable. Do not rely on overexposure to hide shapes.
- Orthographic cameras targeting (0,0,.80): front (0,-5,.95), three-quarter (3.6,-5,2.0), side (5,0,1.0). Use matching orthographic scale 2.05 across all variants and Bear. Front is nearly level, not an overhead baby-photo trick.
- Produce 768px transparent or neutral-backed singles for each view; a clearly labeled D/E/F+Bear contact sheet; true 96px and 48px tiles plus 3× nearest-neighbor enlargements; and black silhouette comparisons. Output must make the actual small tile visible, not only an enlargement. Charm off, wearables off, neutral expression first.
- Include one second sheet with green garden-like ground/background and the same small-scale pets. Label it **procedural backdrop**, not Studio evidence. Preserve Bear's actual materials when rendering its reference. Never recolor Bear to help Blip win.

Astra reviews the actual files for baby proportions, visible two-tone palette, eye friendliness, silhouette distinction and resemblance risks. Revise failed geometry before showing a chosen lead as “ready.” Spencer then selects from renders; production rig/refits/import remain separate.

## Second park: precise survey default and visual layout

**Updated default after live ground survey: Roblox XZ (-38,-46)**. Use existing 16×11 radii, yielding bounds X[-54,-22], Z[-57,-35]. Coordinator reports the 18×13 survey ellipse at step 2 has zero missing hits and ground heights 4.333–4.835, avoiding the high spots at the earlier (-42,-52) candidate. This lies on the west-bank lawn north of the hub, away from the arrival park at (36,66), hub menus and blocked knoll. Keep the same relative equipment layout initially to preserve validated choreography; do not mirror the slide or swing physics merely for visual variation. Connect a 4-stud gateway on the east side toward the existing path; retain another hub-facing (+Z) approach if equipment and kerb clearance permit. Put the bench facing inward from the welcoming side, preserving the current 9.57-stud five-seat design and equipment clearances.

**Layout development approved at the shifted center; clearing/camera verification remains.** Read-only source sampling of the larger 18×13 ellipse gives 688 grass/meadow, 32 path-class and 7 bark samples, with zero rock samples. Bark clusters are near (-36,-52) and (-50,-42); identify the actual objects and relocate those obstructions outside the equipment/camera envelope. Do not infer seven trees from seven cells. Path samples are on the east/southeast edge (roughly X[-26,-20], Z[-49,-37]); retain that through-route, interrupt the kerb at the gateway and do not cover it with equipment or a bench. Keep trunks/canopies outside the complete equipment-and-camera envelope, not merely outside the kerb. No relocation of cave entrance, stream, rest dais or existing through-path. The east-bank (59,-30) site remains a fallback only if these modest clearing constraints fail.

Mount existing equipment art and the same low cream/pink boundary language. Distinguish the second park with one restrained mint/lilac accent on existing reusable trim only if palette tooling supports it safely; no new landmark sculpture. Show an overhead annotated plan and actual seated-height desktop/phone views before accepting. Surface/height/collision, two-park membership and independent slot identities require implementation validation. Source: `src/shared/ParkLayout.lua`, `src/shared/HollowWorldLayout.lua`, `assets/world/world-v7-walk.json` and `artifacts/qa-prep-2026-11-14/CREATIVE-NEXT.md`.

**Exact clearing approved after coordinator's Blender object survey:** remove `Tree_02_tall` at XZ(-50,-42), `Tree_03_blossom` at (-36,-52), `Bush_06` at (-30.656,-41.128), `Bush_09` at (-48.518,-44.494) and `Bush_22` at (-35.177,-53.191) from the world build, matching the first park's declutter approach. This supersedes relocation wording above for these five objects only. Preserve other planting, cave, path, water and rest landmarks; do not broaden clearing without new evidence.

## Accepted shared fetch: one action, optional participation

Playground equipment remains the shipped spectator loop. The later accepted shared-fetch follow-up is an additional slice, not restoration of every old control in the original proposal.

- One **Throw** action appears only when the owner is inside a park, the ball is home and a safe fetch lane exists. Touch uses one 44px-or-larger button above the jump control; keyboard F; gamepad R2. No second confirmation, join button, targeting overlay or new Call control by default. Clear “Ball is out”/cooldown feedback replaces an active button while unavailable.
- One ball per park. The server selects up to three eligible idle pets in that same park, preferring the thrower's eligible pet; no interrupting occupied swings, slide, seesaw, care or paired play. Idle nearby pets join automatically. Keep the throw lane clear of equipment, benches, gateways and avatars' main approach; if unavailable, do not offer Throw.
- Server chooses landing/winner and existing snapshot timing. Winner carries the ball back; companions hop alongside. Solo works. Owner departure/cancelled activity returns the ball home and releases all reservations. Never pull pets across parks.
- Warm feedback is one fading pill, e.g. “They’re on it.” Keep the accepted Play date reward rules; no new currency or passive Stars, and no reward inflation by awarding incomplete/cancelled throws. HUD layout must preserve Roblox chat/thumbstick/jump space.

## World-overlap visual rule for implementation review

Prefer removing duplicate/internal coplanar faces and giving adjacent authored surfaces a single owner. At visible borders, preserve the intended stair riser, trim lip, arch depth and bridge silhouette. Do not scatter arbitrary offsets across whole meshes or hide real seams under decorative clutter. Where a decorative overlay genuinely needs depth, use one explicit consistent small offset normal to its surface, with a named reason and enough separation to survive distant camera precision; inspect for floating edges at grazing angle. Exact per-mesh treatment depends on Sol's scan/plan and must be reviewed before blanket edits.

Evidence acceptance: same camera before/after for each repaired mesh family, near and far, plus grazing angles in day/dusk/night. Confirm removed faces were not visible backsides, walking surfaces or silhouette boundaries. Visual approval does not substitute for rebuilding/validating affected collision. This document approves the seam treatment principle; no particular mesh repair is yet reviewed.

## First actual concept review

Inspected `artifacts/blip-v3-2026-11-14/raw/`: D front/three-quarter/side; E and F front/three-quarter; BEAR front. These are actual procedural renders, not production models or Studio captures.

- **F becomes the creative lead**, superseding D as the initial written default: continuous unequal crown lobes create the most cohesive soft silhouette, with no separate animal ears, muzzle or antennae. The new large low eyes, tucked body, small mouth and cream belly are a clear improvement over v2. This is Astra's recommendation for the upcoming selection, not Spencer's selection.
- D has a strong face but its crest introduces more resemblance risk and its first render had an overexposed white crown plus visible shading bands. Reduce highlight clipping and inspect smooth normals/ring density. E has a distinct broad outline, but its fins read as drooping ears and show segmented root/tip seams; keep as an honest alternative rather than calling it the lead.
- **Comparison-sheet blocker:** the first `BEAR-front.png` includes loose eye/mouth pieces near the lower-left and wing/attachment pieces behind the body. Isolate the actual base pet, hide alternate-face/attachment objects, and rerender. Do not alter Bear's real materials or proportions.
- D's first images and E/F's first images have markedly different brightness/gloss. Finalize common lighting and equivalent material values for all three before showing the choice sheet. Retain two deliberate eye shines, but control additional specular blobs so the face stays intentional. Neutral and grass comparison backgrounds must be identical across candidates.
- Final 96px/48px contact sheets, silhouettes and corrected reference still await review. Do not label the set approved for production.
