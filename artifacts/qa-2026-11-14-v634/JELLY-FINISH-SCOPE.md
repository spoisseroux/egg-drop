# Jelly finish — v1 creative scope

Spencer explicitly wants a rare semi-transparent material in v1. **Feature direction requested; acquisition numbers and rendering treatment below are recommendations, not approved or implemented facts.** This is a finish for existing pets, not a new species, paid product, currency or pet naming system. All alien/Blip work remains parked.

## Appearance default

Display name **Jelly**; internal proposed ID `jelly`. Read as a solid little tinted resin toy with a little light passing through it. Preserve existing silhouette, body/secondary Hue pigments, huge legible eyes and shaded contact with the ground. No ghost particles, invisibility, glowing outline or refractive distortion. Do not use “Glass” if the actual runtime cannot show refraction.

- Start preview at body/limbs/outer ears **22% transparency**, muzzle/belly/inner ears **12% transparency**, roughness equivalent .22–.28, metallic0. Retain current tint values; no forced mint or whitened recolour. These are art targets, not proof that Roblox's existing material setup supports them unchanged.
- Eyes, whites, pupils, catchlights, nose and mouth stay fully opaque and retain expression/blink. Wearables and floating charms retain their authored opacity/material; nothing globally fades the whole model. Preserve the existing secondary palette on charms.
- Night: no extra emission beyond the existing bounded night treatment; translucency must not erase shading or make the torso look hollow. Ground shadow remains readable. Selecting Original colour does not remove the finish; selecting Standard finish does not reset Hue.
- Keep this mutually exclusive with Gloss/Matte/Metal through the existing per-pet finish selection, while remaining additive to Hue, two-tone colouring, wearables, face choice and charm. No independent second finish stack or global transparency modifier.

`src/client/PetMaterials.lua` owns finish surfaces and deliberately excludes authored eye/mouth textures from body finishes; `PetMaterialConfig.lua` has Standard/Gloss/Matte/Metal mappings only. `src/shared/MaterialCatalog.lua` has permanent account unlocks and per-pet equip, current paid pool2 Gloss/Matte at16 Stars, with unused future pool3 data. **Jelly does not already exist.** Transparency must be integrated with the actual renderer's hidden-part/expression/night owners, rather than overwriting every part's Transparency each frame. Existing finish receipts/pools remain valid. Do not silently activate unrelated Pearl/Speckle candidates.

## Actual render proof before deciding final opacity

Sol should create isolated procedural previews using the real Bear meshes and current palette: Standard / actual existing Gloss / actual existing Metal (label it Metal, do not invent a gold finish) / proposed Jelly. Fixed camera, identical exposure/lighting; front and three-quarter at both full and phone size. Include original golden Bear plus one Rose/Tide two-tone example, garden daylight and current night, and a dark/cream striped background behind Jelly so its **actual** transparency is visible. Also include one wearable and one charm. A source alpha value or catalog name is not visual proof.

Review after rendering: face remains opaque/readable; far eye does not show through back of head; torso does not expose ugly intersecting inner limbs; outlines retain mass; belly remains distinct; accessories do not ghost; background visibly but gently shows through; no sorting pop, dark internal seam or missing shadow. If22% exposes mesh intersections, test15% body rather than approving broken geometry. If even15% fails the intended resin read, revise the material approach before production. Do not call a glossy opaque Bear “translucent.” Native Studio proof is required after any Blender concept because transparency/sorting/material response can differ.

**Actual critique status: pending new Jelly renders.** Existing gold-looking Bear previews are not evidence of this finish and have not been approved as Jelly.

## Acquisition recommendation — existing finish progression, no new monetization

**Recommended default: a deterministic finish milestone. Unlock Gloss and Matte, and reach bond level 5 with any owned pet; then claim Jelly free once.** Label it “Special finish” with the three visible requirements, not an undisclosed “rare chance.” This makes it an uncommon earned style through the existing finish collection plus pet care. The exact milestone is a proposal, not Spencer's approval.

Keep Jelly in the existing permanent account finish-unlock/per-pet equip system. Free equip/unequip; ownership never consumes Hue fruit or resets body/secondary colour. Existing Material Egg costs 16 Stars and its active no-duplicate equal-probability pool remains Gloss/Matte; starting with neither, collecting both costs 32 Stars. Existing owners get credit immediately. Bond progression supplies the non-purchase component. Claim is server-validated and idempotent, with one entitlement and no charge; current bond and unlock state remain authoritative across devices/rejoin.

The **8-Star Hue Egg, four fruit probabilities, inventories and policy path remain unchanged**. Jelly composes with Hue appearance; it is not a fifth fruit or a grafted random bonus. Existing Material Egg receipt pools also remain immutable. Adding a weighted rare outcome would require deliberate changes to equal-roll/no-duplicate architecture and quote/policy disclosure, so it is outside this recommended v1 slice. The earlier floated 5% Hue bonus/20-purchase guarantee is withdrawn from this recommendation.

Preserve current restricted/unknown-policy handling for existing egg purchases. The new milestone itself uses no random roll and has the same requirements for every account. Existing Stars can be Robux-funded; do not claim a policy exemption merely because the interface spends Stars. This is compatibility direction, not a legal conclusion. No new SKU, currency, random table, pity counter or direct Jelly price.

V1 includes one finish, one permanent unlock, existing per-pet finish equip, appearance replication, portrait/reveal/visitor consistency, and real rendered proof. It excludes trading, consumable transparency potions, new species, new currency, new SKU, rarity power bonuses, separate names and unrelated finish-pool expansion. No publish.
