# Jelly — Lucky Material Egg pool4 plan

2026-11-14 · systems Sol · PLAN ONLY · independent architect review requested

**User acquisition decision: “Lucky Material Egg outcome.” This supersedes the Gloss+Matte+bond5 earned milestone and free materialClaim proposal.** No milestone, pity, claim action or alternate wallet will be implemented. Existing PhaseA native rendering work remains separate; final appearance still requires actual native/Astra approval. Roughness upload91575369316154 was a Decal wrapper; coordinator extracted Image75946070025172. Current ContentProvider fetch failed, so the image/render capability is NOT ready or verified. No production material/template/pool changes have been made by this plan.

## Recommended numbers and honest behavior

Keep Material Egg16Stars. Append immutable **pool4**, sorted IDs `{gloss,jelly,matte}`, weights `{gloss=45,jelly=10,matte=45}`. Each purchase selects one permanently unowned finish, with weights normalized over the exact remaining eligible set. Metal stays legacy-only; future Pearl/Speckle pool3 stays inactive and unchanged. One exclusive per-pet finish, free equip/Standard restore, Hue/accessories unaffected.

| Already owned from pool4 | Next Gloss | Next Jelly | Next Matte |
| --- | ---: | ---: | ---: |
| None |45%|10%|45%|
| Gloss |—|18.1818%|81.8182%|
| Matte |81.8182%|18.1818%|—|
| Jelly |50%|—|50%|
| Gloss + Matte |—|100%|—|
| Gloss + Jelly |—|—|100%|
| Matte + Jelly |100%|—|—|
| All three |No purchase|No purchase|No purchase|

Jelly is a rare **initial** outcome; it is not always10%. No duplicates means at most3Material Eggs/48Stars from no current finishes; existing Gloss+Matte owners get Jelly guaranteed for their next16Stars. This is the ordinary remaining-outcome rule, not a pity system. No retry can reroll or duplicate ownership.

10% is recommended over5%: with5%, weights47.5/5/47.5 would make Jelly9.5238% after one common, still100% after both. From empty, Jelly arrives by purchase2 with26.3636% probability at10% versus14.0476% at5%; expected spend to Jelly is42.18 versus44.95Stars, with the same48maximum.10% gives meaningful early luck without hiding the eventual guarantee. These figures are exact weighted-without-replacement calculations, excluding pre-existing ownership; they are not a promise to a player about a particular roll. Parent may select5% before pool4 is frozen, but never silently edit a shipped/versioned weight table.

## Preserve old pools and saved proof

MaterialCatalog.CatalogVersion remains1; PoolVersion becomes4 only when code/UI/assets/tests are coherent. Pools1/2/3 and their members/order are retained exactly. Add `PoolRules[4]` with cost16, the immutable integer weights and deterministic restricted order `gloss,matte,jelly`. Older pools retain their existing equal weighting, cost16 and historical fixed ordering. New fresh quotes for old pools remain LegacyPurchaseClosed. Existing reserved old-pool purchases and receipts remain valid and settle their exact stored finish with no reroll, replacement, new pricing or eligible-set expansion. No save version/inventory bit changes.

Append Jelly to ById/displayOrder and current PaidOrder only at the coordinated pool4 activation. Do not enable Pearl/Speckle by stepping through pool3. Do not make legacy Metal a current random outcome. Existing owners retain every old finish.

## Quote and transaction contract

1. Existing pool1–3 materialBuy quote shape remains byte-compatible: id/catalogVersion/poolVersion/eligible. All historical validators reconstruct those exact shapes. For pool4 **only**, require the exact additional fields `price=16`, `selectionMode='random'|'fixed'`; require `fixedFinishId` only for fixed mode. Random mode must omit fixedFinishId. Whitelists branch by pool version; no permissive optional-field expansion for old receipts.
2. Quote poolVersion binds price, weight table and predetermined order. Server recomputes sorted remaining IDs and compares them with quote.eligible inside the existing fenced reservation transaction. A malicious client cannot supply weights/odds or omit a remaining finish. Server validates quote.price against immutable pool rules, not caller input/current weekly shelf. This family has **no ShelfDeal** today (ShelfDeal.Kinds contains wearable/faceplate/ball); keep16Stars and add no discount/deal behavior.
3. Mode is derived from server policy: random only after explicit allowed=false restriction result; unknown/restricted uses fixed. If policy changed between disclosure and a **new** purchase, reject PolicyChanged and publish fresh state before any RNG, reservation or charge. Fixed quote.fixedFinishId must match the server's advertised next finish. This prevents showing random odds then silently selling a different predetermined outcome, or the reverse. UI never chooses its policy route.
4. For a valid new random quote, sample once with versioned cumulative integer weights over sorted eligible IDs; validate unit0<=u<1 and select by half-open intervals. Fixed mode calls versioned fixedNext and makes zero RNG calls. Store chosen finish plus exact quote in the existing reservation **before** charge/settlement. A durable reservation authorizes that recorded outcome; retries/rejoin/policy changes do not select again.
5. Exact committed receipt/id/quote proof is checked before current-pool, capability, wallet, policy, revision or ownership gates. Exact pending reservation retries likewise retain their immutable authorization/outcome; capability becoming unavailable must not strand already accepted work. Conflicting same-id quote rejects OperationConflict. New commands obey current mode/capability/revision.
6. Settlement stays existing MaterialState.apply: exactly16Stars once, permanent materialUnlocks[id]=true, one pendingMaterialResult/result ID, existing Keep/UseNow/ack/equip flow. No autoequip or separate claim. Receipt remains bounded32; pending result receipt is retained. Ambiguous reservation/settlement response uses exact stored proof, not another roll.
7. Stored receipt.quote already binds poolVersion/price/mode. For pool4 publicReceipt, expose derived poolVersion/selectionMode/quoted price (no operationId/private quote) so new MaterialIntent can match pending pool/version/mode/price/result exactly plus confirmed owner snapshot. Keep legacy public receipts compatible. Ack/equip payloads and historical costs remain unchanged.

## Disclosure and policy

Current source provides Robux-funded Stars products (`StoreCatalog`, `StoreService.policyAllowsPacks`) and spends the same Stars wallet on Material Eggs. Treat this as the existing paid-random-items path; do not invent an earned-currency exemption. PaidRandomPolicy.cached is restricted until a real false result, outages remain restricted, Stars packs remain hidden/blocked for restricted players.

Verified official Roblox guidance requires numerical per-outcome odds before indirect-currency purchase, updates remaining no-duplicate odds, and explicitly permits a disclosed predetermined non-random alternative. [Paid random items policy](https://create.roblox.com/docs/production/monetization/paid-random-items), [PolicyService](https://create.roblox.com/docs/reference/engine/classes/PolicyService/GetPolicyInfoForPlayerAsync).

Show every **actual current remaining** outcome and percentage at the Material Egg purchase surface before activating Buy.10/45/45 and50/50 are exact integers;18.1818/81.8182 use four decimal places and sum100%. Existing whole-percent OddsText.format would misleadingly show18/82 here; add a backward-compatible precise-list helper used only by Material disclosure, preserving other egg formatting. With arbitrary future fractions, use a reviewed rounding/remainder rule at4+decimal places and explicit rounded wording if totals cannot be exact. No “rare10%” badge is shown when current chance is18.1818% or100%.

For restricted/unknown accounts, show **“Next: <actual item>”** / guaranteed, before purchase, in published Gloss→Matte→Jelly order; hide luck/percentage language and make no RNG call. Current `NextItemText` already consumes server `nextFixed.material`; extend this exact owner. Policy-service failure must never expose a random UI while the server sells fixed. No new direct Robux SKU/trading/product/discount/pity.

## Components and ownership proposal

- **Systems**: MaterialCatalog versioned weights/rules/odds/roll/fixedNext/cost helpers; MaterialState conditional quote validation/receipt semantics; HatchProgress random/fixed quote route, old reservation recovery and public serializer; server host material capability/proof ordering; MaterialIntent exact pool4 quote/proof; MaterialPanel literal outcome list if parent confirms ownership. New catalog/progression/host tests, frozen historical fixtures. No earned-claim module/action.
- **Systems rendering** after native acceptance: PetMaterials/PetMaterialConfig/GardenPetVisual one visibility owner and explicit body/face/accessory classification; production BodyJelly/BodyTwoToneJelly native templates use only the approved roughness/map/opacity treatment. Existing Gloss/Matte two-tone NativeVerified=false gap is a separate actual finding to resolve with real evidence, not to bypass globally. No production hatch redesign.
- **UI Sol sole writer**: UICopy/init.client/HueEggView/EggHatchView actual purchase controls and receipt routes, precise Material odds/price/mode disclosure, NextItemText if needed, localized Lucky/Special copy approved by Astra. Preserve219locals and Welcome/first-spend navigation contracts. Proposed shared OddsText precise helper needs explicit file ownership before code.
- **Coordinator**: source/asset/native evidence, actual Policy emulator matrix and Studio tests; activates pool4 only when every paid finish has verified one/two-tone templates and actual rendering ready. Since Catalog.available currently checks all PaidOrder, availability must fail closed for new purchases when Jelly/maps missing, yet accept durable old work before this gate. No partial pool activation that silently reroutes odds.
- **Astra**: quick copy direction distinguishing initial rarity from changing conditional odds/guaranteed last outcome, and actual final look critique. No creative approval of numerical transaction code is required; numerical architecture is independently reviewed by Sol.

## Compatibility / release gate

Old v11 saves/receipts/reservations round-trip unchanged; new known Jelly unlock/receipt uses existing fields. Old servers cannot validate a new finish/pool4 quote: replace/drain old server code before exposing pool4 and ensure current client bundle. No mixed-version claim. Keep pending old purchases recoverable before capability checks. While staged, keep live/current pool2 behavior; add inactive pool4 data until native approval and coordinated source activation. No publish from this task.

## Test and verification plan

- Catalog golden test: literal pools1/2/3 and old equal odds/selection unchanged; pool3 future candidates never current. All8ownership subsets produce exact weights/conditional table; restricted order is Gloss,Matte,Jelly; legacy Metal ownership does not remove current outcomes; invalid/NaN/negative/1 RNG rejects. Boundary tests at0/.45/.55/nextrepresentable values and two-outcome normalized intervals; one remaining returns100%; no Monte Carlo proof needed.
- Transaction fixtures: legacy pool1 and2 stored reservations resume their exact preselected outcome across pool4 without RNG; historical pool3 validator unchanged; new old-pool quote rejects. Old/new receipt and v11 round-trip. Pool4 price/eligible/mode/fixed-target tampering rejects before RNG/write. Stale revision/policy/ownership rejects new commands with refresh; exact saved proof still wins when wallet/capability/policy changed. Ambiguous before/after reservation and before/after settlement rejoin retries charge once/roll once/same result, retain pending receipt through32eviction; duplicate UseNow/Keep/equip unchanged.
- Policy fixtures: explicit allowed random; restricted/unknown/outage no RNG, predetermined next advertised and granted; policy flips between screen/quote/reserve refuses new sale and refreshes; accepted reservation finalizes stored outcome without reroll. Stars product gate unchanged and other egg policy tests remain green. No undisclosed reroute.
- GUI/native: allconditional sets before purchase at640×360,812×354,1280×720, preferred text size/pseudo locale; fractions sum100% and full itemized text is reachable, one remaining says100% or guaranteed rather thanrare; disabled/pending sendszero commands; exact16Star shortfall, no shelf discount. Final Jelly native day/night/original+RoseTide, face/accessories opaque, head/internal seams, slow orbit/back view/frustum/roughness ID/source unchanged. Existing material receipts can reveal/use Jelly using current flow after render approval, no new cinematic code.
- Re-run MaterialProgress/Host/Intent/Editor/FinishPreview, RestrictedEggs/PaidRandomPolicy/Store, existing save/schema and PetMaterials/Expressions; client entry/local budget and Welcome/first-spend regressions. Independent code review before coordinator actual service-backed reconnect/Policy emulator/native acceptance and any later separately authorized publish.

Architect questions: Does pool4-only quote strengthening preserve historical receipt/reservation validation and proof-first retry semantics? Are weighted no-duplicate intervals/mode disclosure/restricted order exact? Are capability and rollout gates sufficient without activating pool3 or changing unrelated economy?

Additional fail-closed execution check: current HatchProgress private isRestricted compares `handle.restricted==true`; normal host supplies cachedtrue before exposing the board, but an uninitialized library handle would appear allowed. Bind both public disclosure and selection to **explicit false only** (`handle.restricted~=false` means restricted), initialize new handle as restricted, and make isolated fixtures that intend an allowed random purchase setfalse explicitly. This is default hardening, not a change to the normal resolved production policy path. Architect should review the shared helper's impact on existing egg families; all RestrictedEggs/Store policy regressions must pass.
