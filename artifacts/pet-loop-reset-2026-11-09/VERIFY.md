# Pet loop reset — verification record

2026-11-09 · Scope: [PET-LOOP-RESET.md](../../PET-LOOP-RESET.md). [Visual gallery](GALLERY.md). This record separates actual Studio input, isolated tests, source rigs and read-only layout fixtures. **Published private build: v250 (a3fce0c), confirmed in refreshed Studio Version History after tests, reviewed commit and push.** [Publication proof](private-published-v250-a3fce0c.png).

## Final checks

| Area | Evidence | Result / scope |
|---|---|---|
| Integrated source | Root's fresh final native source check | **104 sources exact and compiling; final Rojo build passed.** Independent source GO and Astra visual GO were reported by root. The earlier 103-source `integration-compile-first.json` contains a corrected in-flight syntax error and is not the final gate. |
| Largest Hue | [final-phone-largest-hue-verified.json](final-phone-largest-hue-verified.json) | HueEggView **13**, HueIntent **12**, all pass; JSON explicitly records Largest. UI uses constructed state; intent tests inject transport, with no wallet writes. |
| Fresh uncached Largest modules | [final-uncached-largest-client.json](final-uncached-largest-client.json) | HueEggView **13**, FocusCharacterVisibility **3**, PetNightStudy **2**, PetLoopResetPresentation **3**, all pass. Covers owner-local mask restoration, night roles, opaque transition and gait suppression. |
| Medium Hue | [final-hue-ui-medium.json](final-hue-ui-medium.json), [final-phone-hue-largest-tests.json](final-phone-hue-largest-tests.json) | HueEggView **13**, HueIntent **12**, HuePalette **4** pass. The latter file's actual preference is **Medium**, despite its filename. |
| Deck / collection UI | [final-deck-reset-client.json](final-deck-reset-client.json) | Medium: PocketDeckAim **3**, JellyUnderlay **3**, ThemeLCD **9**, CompanionCrest **7**, MenuPolish **9**, JournalPurpose **3**, all pass. Crest cases verify archived rank has no visible progression output. |
| Server regressions | [final-reset-server-regressions.json](final-reset-server-regressions.json) | HueProgress **15**, HueHost **3**, HatchProgress **21**, PetAppearance **8**, SessionRecovery **8**, SessionHost **2**, GardenIntentHost **3**, PetLoopResetGarden **5** pass. Isolated stores/callback fixtures are not live persistence-service outage proof. |
| Corrected contact host fixture | [final-pet-contact-host.json](final-pet-contact-host.json) | **4 pass** through actual host callbacks with controlled positive RNG and private test actor/store. Supersedes the stale version-4 fixture failure retained in the preceding regression log; no production failure remains outstanding from that entry. |

Final Hue coverage includes generic purchase/held stock, separate assignment, close/rejoin preservation, legacy v2/v3/v4 migration and 24-slot proof, exact retries/lost replies, takeover fences, all six canonical mixes, independent accent and neutral reset. Layout roots include 1649×971, 749×381, 350×703 and 568×210. Passing fixture roots are not a claim of physical-device testing.

## Actual input and saved-state evidence

- **Center-angle round:** [final-angle-round-actual-controls.json](final-angle-round-actual-controls.json) records 24 accepted native-control drops. Its last immediate sample is 650 during Settling; the [settled Largest recap](final-angle-round-earned-recap-largest.png) shows 670 and +14 Stars. [final-earned-held-hue-purchase.json](final-earned-held-hue-purchase.json) independently retains the saved +14 receipt, then a single 8-Star purchase (**20→12**) with held stock.
- **Buy → close/reopen → assign:** [actual-held-close-reopen-and-rose-apply.json](actual-held-close-reopen-and-rose-apply.json) retains the same purchase/token at balance 10, then applies Rose I with no further debit. [actual-second-hue-and-independent-accent.json](actual-second-hue-and-independent-accent.json) records the next 8-Star purchase (**10→2**), Tide I and retained Rose accent.
- **Free mix / reset:** [actual-earned-free-mix-and-reset.json](actual-earned-free-mix-and-reset.json) records Rose:Tide at revision 10, then Original body / Default accent at revision 11. Balance stays 2; learned Rose I and Tide I remain.
- **Final care input:** the actual ~14-second hold visibly reacted ([reaction frame](final-actual-hold-pet-reaction.png)); [final-actual-focus-care-input.json](final-actual-focus-care-input.json) and [opportunity result](final-actual-petting-opportunity.json) retain **6 Stars, careCount 0**. The random opportunity awarded nothing. Do not infer an observed award from this gesture; positive award wire proof comes from the controlled host fixture above.

## Solver evidence

[24 policy runs](angle-initial-24-policy-comparisons.json) use the production solver and legal cooldown/contact timing: goal-aware **12/12 wins**, fast-center **0/12** (four seeds per template across three templates). [Nine exact legal replays](angle-nine-legal-replays.json) match accepted aim/time/tier traces, all with 24 drops and no persistent writes. This is a bounded deterministic comparison, not a population win-rate estimate. The [lane-C manifest](angle-lane-c-freeze.json) records center-angle-v1, **±35° / speed 10**.

## Evidence corrections and limits

- Earlier `final-phone-*-largest` captures/tests followed an unsuccessful text-setting click. Their Medium preference must not be relabeled. The explicitly verified Largest JSON and final `*-LAYOUT-FIXTURE` captures are the final accessibility evidence.
- `final-desktop-largest-hue-ui.json` retains an earlier held-swatches layout failure; final HueEggView 13 passes supersede it. Earlier client logs also retain corrected fixture/in-flight failures; preserve them as history, not outstanding production failures.
- Source-rig night studies and Colors/Mix/held-egg layout fixtures do not grant ownership, spend Stars or prove earned grades. Owner-local hiding tests do not prove another client's view. Tests here do not establish public-service save reliability, real mobile hardware behavior or measured production frame performance.
- **PASS — actual two-client replicated pose and local mask:** [public trace](final-two-client-focus-public-trace.json) records **400 samples /43.6003 seconds** across Room→Focus, with public `from==to` unchanged at approximately **(20.5929, 4.025, −4.08545)**. [Visitor pose and mask](final-two-client-visitor-pose-and-mask.json) records the visitor rig pivot unchanged at approximately **(19.1926, 4.467, −21.9926)** during focus and after Back. Observer sees owner LocalTransparencyModifier **0**; owner sees **1 during focus→0 after**, with focus **true→false**. This proves the sampled public pose and local-only mask behavior; the two records describe separate sampled encounters.
- **Actual movement:** [68 gait samples over ~4 seconds](final-two-client-walking-gait-samples.json) cover ~18 studs travel and Y **4.467→4.59699** (~.13-stud range). [24 idle samples near the creek](final-actual-idle-wander-samples.json) show only rest/follow. Do not claim live wandering was observed there; native planner5 and host3 ground/intent guards provide separate bounded test proof.
- **Capture limit:** the Studio execution helper reset the fixed-camera setup and background screenshots were stale. No fixed-observer-camera visual film or frame-by-frame continuity claim is made. This is actual two-client pose/mask telemetry, not a successful fixed-camera capture.

Documentation-only handoff: no runtime, Studio state or publication changed while preparing these notes.

## Final integration checkpoint

Independent source review GO on final HueEggView EB92AFCD… and the owner-local visibility lifecycle; Astra visual GO on final night focus, bank boundaries, Largest desktop held/Colors and Largest short landscape phone Colors. Final 104 runtime sources matched the filesystem and compiled; Rojo build/egg-drop-reset-final.rbxlx and git diff checks passed. All local multiplayer clients were ended. Original Medium text preference was restored and verified by final-restored-medium-check.json; main Studio is in Edit, desktop, on Egg Drop.

The clean final Play console retained the existing inaccessible EditableImage warning (sprite fallback is active) and four ContentId 203785492 asset-type warnings, which are not referenced by repository source. No account/security setting was changed. Fault-injection suites intentionally log simulated save errors; those are recorded separately from normal-play warnings. No new runtime exception remained.
