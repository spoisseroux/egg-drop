# Carry and care-machine prototype

Authorized November 9, 2026; follows private v326 / 3c6b61b. This is the bounded second pet-care slice. Astra authors creative assets, UI composition and poses; Sol 6.1 High implements runtime. Root owns native Studio verification and private release. Only Egg Drop place96451847774961.

## Goal and proposed implementation

From petting, Pick up returns the normal walking camera and cradles the owner's equipped baby. Walk to the existing Journal service location, place the pet on one care-machine bay, customize with the released Hue/Charm controls, then pick up or safely set down. Other players see the same single companion. Existing fast menu customization remains available during the prototype.

- Server GardenState and a focused carry coordinator own explicit Carried/Docked/Placed transitions, bounded one-bay claims, character/pet/actor/claim generations, reach and support checks. No physical pet network ownership or saved world transforms.
- Host routes validate identity, typed finite sequences, current mode, actor reach and exact current claim. Equip becomes a staged, serialized operation using the existing companion ID/stamp/writer fields, with exact persisted-winner proof. A late saved equip changes following truth, but cannot reclaim an expired bay or displace its next occupant.
- GardenClient/RoomView/RoomCompanions render the public state on the existing visual identity. Petting contact ends once on a successful carry response; camera and movement return once. Clear avatar carry pose on every exit and support both R6 and R15.
- The existing Journal station becomes the single machine route. Astra supplies original enamel/aqua geometry and cradle/dock pose profiles. Station input priority remains centralized; no overlapping E/X prompts. Compact >=44px Pick up/Set down and current Hue/Charm sheet preserve phone/controller access.
- Change pet explicitly names the owned target and confirms activation. Failed/uncommitted save preserves the old pet; committed save is authoritative even after bay expiry. No new currencies, inventories, egg pools or migrations in this slice.

## Edges and expected behavior

| Case | Expected |
|---|---|
| Two owners place at once | One exact claim; loser keeps holding and can use ordinary controls. |
| Duplicate/stale pickup, release or claim packet | Original outcome or rejection; no duplicate pet or eviction of another generation. |
| Water, unsupported or obstructed set-down | Keep holding with clear feedback. Essential paths remain dry. |
| Death, disconnect, character/equipped-pet replacement | Release only the matching hold/bay; next actor follows normally. |
| Open deck/menu, close editor, walk away | Explicit safe follow transition; no stranded attachment or camera. |
| Late successful equip after bay expiry | Saved new pet follows; never roll back save or seize the bay from its current owner. |
| Load gate completes while carried/docked | Complete model and pose remain stable; interaction identity and ownership survive. |
| Mute/reduced motion/Largest text | Quiet/reduced presentation and reachable controls, no hidden required action. |

## Verification and boundaries

Plan/source reviews precede implementation/release. Native unit/host cases cover lifetime, contention, exact replay, supported placement, interruption and delayed equip. Run existing reward/receipt/lease regression suites unchanged except justified obsolete fixtures. Actual Studio button walkthroughs include pickup/place/edit/pickup/set-down and two local owners, with R6/R15, seven original identities and short-landscape Largest text composition. Record source equality/compile/Rojo, console, wallet invariance, screenshots and motion; Astra critiques actual footage. Fixtures and emulator coverage are labeled separately from physical phone or live-service rejoin.

Garden basin/terrace/water textures follow as another reviewed slice. Swimming/training, finish materials, expanded pigments and Feature/Stat Eggs remain subsequent approved phases with their own data/behavior gates. No public release, paid luck, nursery, play caps or account/privacy changes.

## Review / implementation / evidence

Independent architecture review: **GO WITH CHANGES**. User's existing explicit build authorization covers these routine implementation corrections; no extra confirmation is needed.

| Initial plan | Reviewed adjustment and reason |
|---|---|
| Use existing equip operation | Existing equip publishes before autosave. Add a staged, serialized companion operation and verify the exact persisted winner. Retry ambiguous saves under the same operation. Do not report an autosave-dirty mark as durable success. |
| Extend GardenState modes | Explicitly exclude held/docked actors from movement resets, greetings, toys and wandering. Existing normalization handles only Focus and would otherwise immediately cancel a hold. |
| Safely release on interruption | Capture validated last/current dry anchors. The old fallback can be over water; it is not valid support proof. A blocked deliberate set-down must retain the hold. |
| Render one held pet | Read the live holder transform each frame, suppress floor foot planting and preserve carry pose through authored-rig swap. End contact/focus exactly once only after accepted pickup; rejection keeps focus. |
| One machine bay | Keep Journal's single existing prompt/root. Astra proposes pad(11.75,5.18,-4.20), to be checked against actual bridge/wet/support geometry before final placement. Old Journal remains visible behind/left. |

No carry/machine runtime was implemented before this review. Architecture gate now permits the bounded implementation above. Actual tests and visual acceptance remain required before commit/publication.

Save-seam review further requires the active writer lease check inside the save transaction, not only before yielding. A committed-then-error retry keeps its immutable operation; it never writes a rollback. Exact prior proof can be recognized without mutation. A revoked writer cannot overwrite after takeover. Native tests must pair these cases with bay expiry/new occupancy.

Native baseline checks find dry Floor topY4.0 at the proposed pad, apron and both apron sides. Astra defines the dock(11.75,5.18,-4.20) as the pet sole/cushion-top datum, not the physical part center. Full hull/path/bridge clearance remains a release gate.

## Resumed native review — November 9 afternoon

Ordinary earned controls reached pickup, walking, Place at Journal, saved Ring selection, pickup again, refused obstructed set-down and supported set-down after moving to dry ground. Opening the deck while carrying released care ownership and reached Board without a retained bay. These are local Studio controls, not live-service persistence.

The actual R15 uses AnimationConstraint joints rather than Motor6D. A first adapter correction engaged the arms, but Astra's moving footage found the run animation still swinging hands through the pet. The reviewed correction owns carried shoulder/elbow rotations relative to bind frames while preserving the captured animator transforms for exact restoration. The final 548-frame/18.33-second earned R15/Zivvi walk-turn-stop has Astra motion GO. Its lower tracking camera is an explicitly labeled inspection fixture; the underlying carry and movement use actual controls.

Native Largest text exposed a separate short-landscape machine-editor overflow. Keep the first hue row, full live Charm portrait, shape controls and pinned exits visible together; Astra authored concise compact copy and a two-column composition. Final verification is required after that correction. A real two-client launch was attempted, but the separate Studio launcher refused to start because this installed Studio is out of date. Preserve that limitation; isolated two-owner contention/lease tests are not a replacement for live visitor evidence.
