# Lucky Material Egg / Jelly — revised acquisition direction

Spencer chose the **Lucky Material Egg** direction. This supersedes the earned Gloss+Matte/bond milestone proposed in `JELLY-FINISH-SCOPE.md` and repeated in `JELLY-NATIVE-REVIEW.md`. Do not implement or advertise that milestone. Jelly remains a permanent account finish with free per-pet equip; Hue fruit, pigments and the8-Star Hue Egg stay separate and unchanged.

The coordinator's **initial probability proposal is Jelly10%**. Treat the numbers below as the concrete proposal for architect/economy validation, not an assertion that the current equal-roll Material Egg already implements weights. Preserve the existing16-Star Material Egg price unless the coordinator explicitly changes it; no new currency or Robux product.

## Truthful shop copy

Title: **Lucky Material Egg**

Description: **A new finish for your little friend. You won't hatch one you already own.**

When none are owned and the proposed45/45/10 weights are approved and implemented, show the current quote explicitly: **Gloss45% · Matte45% · Jelly10%**. Use the same readable odds list as the shop. Button: **Hatch16** with the existing Star icon. Jelly label: **Jelly · translucent finish**; do not call it a pet, potion, fruit or temporary power.

If retaining no duplicates, eligible weights must be renormalized and the UI must show the **actual current** chance: owning Gloss gives Matte81.82% / Jelly18.18%; owning both ordinary finishes gives Jelly100% while unowned. Consequently “10% chance” is only an initial collection state, **not a permanent banner claim**. Add short helper copy: **Owned finishes leave the pool. Your current odds are shown above.** When all are owned, show **All finishes collected** and disable purchase; no duplicate compensation currency is introduced.

For existing restricted/unknown-policy behavior, follow the authoritative policy result. A deterministic allowed offer should show **Next finish: [name]** with no luck percentage or implied random roll; use a neutral **Material Egg** heading for that offer. If policy/asset availability cannot authorize a sale, use the existing disabled/readiness treatment. Do not invent an exemption because payment is Stars; existing Stars may be Robux-funded.

Successful reveal: **Jelly unlocked** / **A translucent finish for your pets.** Actions use existing equip/keep semantics; changing finish does not consume colour or reset Hue. The preview must use the actual eligible finish, not a generic golden model presented as proof of Jelly.

## Implementation boundaries for the owner

Weighted selection is an explicit architecture change from current equal no-duplicate rolls. Keep historical receipt pools immutable and choose an unused version; pool3 already contains inactive Pearl/Speckle data and must not be silently overwritten or activated. Server quote, purchase result, policy path, owned-set filtering and displayed probabilities must agree. Decide rounding without hiding the sum or misrepresenting the authoritative chance. No production chance claim until those checks pass.

Visual verification remains separate: revised body15% / head8% native candidate and intended .25 roughness still require a valid delivered map and actual capture. Coordinator reports Image75946070025172 is the approved texture asset, with delivery propagation unresolved. Do not review a black/fallback shader as the final finish or mistake the Decal asset for its texture. No “ready” promise until actual image delivery and native material appearance succeed.
