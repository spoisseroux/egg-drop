**Private v583 Published 2026-11-13 — runtime 73e0b9f, committed and pushed.** Studio Output: "Published new changes in "Egg Drop" to Roblox." and Quick Links "Add publish notes to v583". [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) · Studio captures `artifacts/pet-park-2026-11-13/studio/`.
# Egg Drop — Pet Park playground, easier pet click, 3D wallet Star

New since v568: a **Pet Park playground** on the lawn by the east picnic table. Walk inside the flowered edge (or sit on a bench with the "Sit" prompt) and your pet plays on its own: swings, slide, see-saw (needs a second pet), sandbox (castle grows in 3 stages), ball corner; duo activities pair it with another player's pet. A small chip shows the **Play date** (3 activities a day = +4 Stars). Your pet has a much bigger click/tap area (whole body, 16 studs), and the wallet Star is a turning, glinting 3D Star. The tree and shrubs inside the playground are gone, and the hub marble and trim have their textures back (they had been plain white since v550).

**Passed before publish:** server specs 25/25 (ParkDirector, PlayDate, ParkMount, garden, saves), client specs 68/68 (ParkClient, ParkPetPose, PetClickTarget, WalletStar ...). Architect review + Code Reviewer GO WITH CHANGES (all applied). Solo playground cycle seen live in Studio.

**Test (two accounts):** both players stand in the playground: see-saw, sandbox together and ball toss between your two pets; one player walks out mid see-saw (the other pet hops off); sit on a bench; Play date chip reaching 3/3 and +4 Stars; Roblox chat bubbles. Also tap/click your pet from a distance, and watch the wallet Star.

**Still open:** pets land a little in front of swings/see-saw and walk back; gate orbs don't bob; the playground switch (`FeatureFlags.Park`) is on in this private build only.

## Historical v568 — play forever: collection book, stamp card, records

**Private v568 Published 2026-11-13 — runtime a8dc779, committed and pushed.** Studio Output: "Published new changes in "Egg Drop" to Roblox." and Quick Links "Add publish notes to v568". [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) · Studio captures `artifacts/play-forever-2026-11-13/studio/`.

New since v558: a **Collection book** (Pocket Menu and Companions hub): Balls, Faceplates, Wardrobe, Toys and Discoveries pages with % bars; each page pays 5 / 5 / 10 / 15 Stars at 25 / 50 / 75 / 100%, once; three full pages earn the book-only **Bookworm** faceplate (placeholder art). A **Records** page shows your lifetime numbers. The daily gift is now a **stamp card**: 4, 4, 5, 5, 6, 6, then 12 on the seventh day played, never resets. Egg odds show as percentages; in regions where paid random items are restricted, Star-priced eggs give the next item in a fixed order ("Next: ...").

**Passed before publish:** server specs 18/18 (new BookClaim, StampCard, LifetimeCounters, RestrictedEggs), client specs 64/64 (new BookView, StampCardView). Architect review + Code Reviewer GO (policy cache fix applied).

**Test:** Pocket Menu → Collection book (claim a milestone, open Records), the stamp card on the daily page and in Hatch eggs (stamp today, come back tomorrow), buy a ball theme and see the Balls page move, on desktop and phone.

**Still open:** Bookworm art; book item thumbnails; the "+12 Stars" pop briefly overlaps the stamp tagline; a slow claim can show a false timeout until the next refresh.

## Historical v558 — UI personality pass

**Private v558 Published 2026-11-13 — runtime 9586f02, committed and pushed.** Studio Output: "Published new changes in "Egg Drop" to Roblox." and Quick Links "Add publish notes to v558". [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) · Studio captures `artifacts/ui-personality-2026-11-13/studio/`.

New since v550: Fredoka One for titles, names and buttons; friendlier copy (one string table, `src/shared/UICopy.lua`); a fixed house palette with one tint per screen (peach Hatch, lilac Deck style, pink Companions, sky Quests, gold results: a dot, a squiggle under the title, a halftone fade); A/B hint caps like the deck's buttons; lips on things you press and stitched seams on panels you read; tilted sticker chips for prices, tiers and "New best"; an LCD dot grid in preview windows; boing and tab squash motion (off under Reduced Motion); your pet peeks into Hatch eggs, Deck style, results and Quests on desktop; the Star has a face (wallet eyes, results hero); empty states with a line in voice.

**Passed before publish:** all 62 previously-green client specs (new UICopy 6, KitSurfaces 8, PetPeek 10). Architect review + Code Reviewer (GO WITH CHANGES: text measuring made synchronous; tiles release a stuck press).

**Test:** Deck style (all three tabs), Hatch eggs, a round's results (win and miss: the pet hops or droops, the Star face watches the count), Quests with every daily claimed, the Wardrobe with nothing owned, all on desktop and phone (no peek on phone).

**Still open:** icon redraw (T10); phone Deck style detail pane overlaps its finish and status lines (older); Hatch/results/Quests peek positions checked only by specs so far.

## Historical v550 — round items, smiley ball themes, dusk world, garden life

**Private v550 Published 2026-11-13 — runtime 0cc2c3a, committed and pushed.** Studio Output: "Published new changes in "Egg Drop" to Roblox." and Quick Links "Add publish notes to v550". [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) · Studio captures `artifacts/batch-2026-11-13/captures/`.

New since v539: smiley balls by default (no numerals), Deck style **Balls** tab (Smileys and Marbles free, Gumdrops 20, Gems 40, Planets 40, Kittens 120 with cat ears), Next/Then faces animate, goal text uses colour names/circles, results count-up blips. Round items: star (power-up) balls fill a 3-slot belt; **B** opens the item carousel and pauses the round (Swap, Pop, Magnet, Bomb); phones get an item button under A ("You have no items" when empty). Items are off in the Welcome round, guided rounds and before your first win. The faceplate now tints only the deck. Garden locked at dusk with new sky, warmer textures, 12 props removed, flat flower patches and frond bushes; brook, waterfall and bird ambience (off during rounds) and a Pocket Deck music placeholder; stations pulse an icon until used; pets sit, look at you, idle and coo more. Save is now v11 (do not roll back past 0cc2c3a).

**Passed before publish:** server specs 14/14 (HatchProgress 27, RoundItems 15, BallThemePurchase, ToyFeatureProgress 21, WorldRoutes 7, GardenGreyboxWorld 9, RunReturn 24, …); client 62/71 (7 pre-existing failures; JellyRenderOwner needs a new probe; HardwareDeck needs a live Ready round). Code Reviewer GO WITH CHANGES, all three fixes made. Re-uploaded world meshes got their precise collision rebuilt in Studio and the place saved (v550) before publishing.

**Test:** win a round, then play another to see star balls, the belt chip and B carousel (use Swap/Pop/Bomb/Magnet); Deck style → Balls (buy Gumdrops, equip); the results count-up blips; walk the dusk garden (waterfall gets louder, birds, flower patches, bushes, nothing blocks the arrival path); stations' icons; a pet sitting by you; on your phone, the item button and "You have no items".

**Still open:** desktop Items card (a small board chip stands in); hub floor glare and tan rocks vs the reference; all audio placeholders; not checked on a physical phone.

## Historical v539 — redesign: celebrations, menus, round look, 3D eggs and Star


**Private v539 Published 2026-11-13 — runtime 8d4e432, committed and pushed.** Studio Output: "Sent message to server to publish" and Quick Links "Add publish notes to v539". [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) · [Publication proof](artifacts/publish-2026-11-13/private-published-v539.jpg) · Studio captures `artifacts/redesign-2026-11-12/studio/`.

New since the QA-fix build: full-screen hatch reveal stage (spotlight, drag to spin, name plate); results screen with a 3D Star, count-up, next-egg meter, quest progress and a Hatch button; round look (no rings or yellow border, vivid eggs, tier V violet, fill line that turns amber and says "Stack too high · Merge to clear"); your Deck style background drawn in the board; Deck style screen (Faceplates | Backgrounds); Companions hub (Pets / Wardrobe / Customize) with Charm "None"; Hatch eggs as a list with a spinning 3D egg. Placeholder sounds for every new cue.

**Passed before publish:** 46/53 client specs (7 pre-existing failures unrelated to this build), all server specs (OverflowGraceLeft 6, RunReturn 24, WorldRoutes 6, HatchProgress 27, HueProgress 18, Wearable/FaceplatePurchase); every module loads; board span peak 1229/1536; two Code Reviewer passes, all findings fixed.

**Test:** a round to the fill line (Hard is fastest), a win and a missed round (results + 3D Star), Hatch eggs (3D egg, hatch), the hatch reveal (drag to spin), Companions → Customize → Charm None, Deck style Backgrounds, on your phone.

**Still open:** the Features tab and Feature Egg are hidden on purpose; fill-line coach card (needs a save field); sounds are placeholders; not yet checked on a physical phone.

## Historical — QA bug fixes after v515

**Private build Published 2026-11-12 (the publish after v515) — runtime 7e017dc, committed and pushed.** Studio Output: "Published new changes in "Egg Drop" to Roblox." [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) · [Publication proof](artifacts/qa-bugs-2026-11-12/private-published-qa-bugs.jpg) · captures in `artifacts/qa-bugs-2026-11-12/`.

Fixes from Spencer's v515 QA pass: the Pocket Menu on a fresh save explains its locked rows and the d-pad moves through them; on phones the deck, quest log, picker, results, Wardrobe and Faceplates sit below the Roblox controls and the screen is a little narrower; Wardrobe cards are no longer clipped; the "Dot" charm is called Snowflake; the hatch reveal pet fades in once loaded (no stretched/dark Bear); water flow lies flat on the river; stairs, column tops and trees render both sides; the lantern rope reaches the tree; the hub is dimmer at night.

**Passed before publish:** CompactPhone 10/10, DeckScreen 8, DeckResults 8, DeckQuests 5, DeckBoot, PetAttachments 8, WorldRoutes 6, HatchProgress 27, RunReturn 24, WearablePurchase, FaceplatePurchase. Code Reviewer GO WITH CHANGES (both changes made).

**Test:** fresh-save Pocket Menu on the phone; the round, quest log and Wardrobe tops on the phone; a hatch reveal; the river, rotunda stairs and hub at night.

**Still open:** Wardrobe item thumbnails, Charm "None" row, vase crowding, waterfall sound, redesigns from the QA pass (hatch reveal stage, egg screen, Companions menu, results screen, deck style header), Easy payout, physical-phone and save/rejoin checks.

## Historical v515 — phone deck frame, Pocket Menu, wearable fixes

**Private v515 Published 2026-11-12 — runtime 30aa1ba, committed and pushed.** Studio Output: "Published new changes in Egg Drop to Roblox", v515. [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) · [Publication proof](artifacts/publish-2026-11-12/private-published-v515.jpg).

New since v505: phones get the slim Pocket Deck frame (one wide screen between slim shoulders, A at mid height, no B on touch, centred board with icon goals on small phones; UI-SPEC-COMPACT-FRAME-2026-11-12.md section 10). MENU opens the Pocket Menu (Resume, Restart round, Quit to garden, Hatch eggs, Customize; the round pauses; Restart/Quit confirm mid-round). Quest log opens from the Daily quests card or Q. The tee's right sleeve renders; Little Hoops hang from the ear lobes; Wardrobe swatches use the pet's colours; faceplate op-id fix; sparkle-eye shine fix; odds read "1 in 3".

**Passed before publish:** CompactPhone 9/9, DeckScreen 8, DeckBoot 10, DeckResults 8, DeckQuests 5, RunReturn 24, FaceplatePurchase 10, WearablePurchase 11, PetAttachments 8. Live check: deck accent matches the equipped plate.

**Test:** on the phone: round HUD readability, drag-aim and A, MENU → each Pocket Menu item (Restart and Customize were not checked live), Daily quests card → quest log, results sheet; the Wardrobe (tee sleeves, hoops, swatches); a faceplate purchase.

**Still open:** physical-phone check, live save/rejoin, two-player check, restart mid-round live, Customize from the Pocket Menu live, wings drop rate (15%). Audio is with Spencer.

## Historical v505 — Bear, Pocket Deck, quests, wearables

**Private v505 Published 2026-11-12 — runtime bf5c728, committed and pushed.** Studio Output: "Published new changes in Egg Drop to Roblox", v505. [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) · [Publication proof](artifacts/publish-2026-11-12/private-published-v505.jpg).

What is in it: the plush Bear as the v1 pet (two-tone body, night glow), World 1 floating sky island with matte materials, rebuilt Pocket Deck (wide screen, in-deck results, back arrow, faceplates for Stars, retro boot), daily/weekly quests with a saved reroll, Easy/Medium/Hard (x0.8/x1/x1.5 Stars), Feature Egg horns and wings growing S1-S5 (wings flap), 13 wearables in the Wardrobe at the Care Cradle (15/30/60 Stars, save v10), a split shirt that follows the arms, compact phone layouts.

**Passed before publish:** WearablePurchase 11/11, CompactPhone 8/8, PetAttachments 8/8, HatchProgress 27/27, FaceplatePurchase 9/9 and a Play smoke test (fresh save, Space x5 earns the Bear).

**Test:** play a few rounds on each difficulty → finish daily quests and reroll one → buy a faceplate → buy and wear items in the Wardrobe → check the Bear at night → try it on a phone.

**Still open:** physical-phone layout check, live save/rejoin, two-player check, faceplate op-id reuse can report a false "Saved", Wardrobe swatches are grey for secondary-tinted items, the 3D deck faceplate texture did not load in Studio, the wings drop rate (15%) is grindy, and the left sparkle-eye shine sits close to the pupil. Audio is with Spencer (AUDIO-HANDOFF.md).

## Historical v397 — round feedback and clear rewards

**Private v397 Published — runtime b733167, committed and pushed.** Refreshed native Version History verifies **Round feedback and white zero notches - b733167**. [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) · [Publication proof](artifacts/round-juice-2026-11-09/private-published-v397-b733167.jpg) · [Screenshot gallery](artifacts/round-juice-2026-11-09/GALLERY.html) · [Verification](artifacts/round-juice-2026-11-09/VERIFY.md).

Every hue0 notch is now white on both Main/Secondary, with a dark current-dose check; saved colours, stages1–5, inventory and confirmed one-channel Reset are unchanged. Accepted Drop gives the entire device a small tap. A witnessed round ends with final-ball bounce and bounded seed/ribbon confetti, retiring on replay/leave. Recap has one exact payout breakdown and one actual-goal checklist, without redundant source cards, hints or BEST kicker. Egg shop uses three measured offers per row and accessible narrow fallback. Matte/Gloss receipts show a lit teal sample with ground shadow. All five egg families have complementary cold-load shell pieces and a120ms open-shell gap before the reward enters.

**Passed:**250 unique client cases/26 suites (preference/focus reruns overlap),40 isolated server cases/3 suites,171/171 native source matches and compiles, cold Rojo and diff checks, independent Sol source review and Astra rendered review. Actual ordinary controls completed both Bank goals:1010 points, chain9,12 Stars =6 Quest +6 Daily. A65-frame trace observed one art owner,12 confetti pieces then zero. Actual earned8-Star Toy Egg awarded Ball and applied it to Zivvi; quick replay and garden re-entry opened empty new rounds. Desktop and iPhone17Pro emulator shop navigation passed. Original Medium/Automatic/default viewport restored, QA removed, Studio Edit.

**Test:** Drop/merge feel →finish round and quick retry →scroll all five egg choices →Toy/Feature Use now at cradle →white0/current hue checks and one-fruit confirmations →Matte/Gloss readability →rejoin on phone and verify Stars/items/appearance. Physical-phone, live rejoin, current two-owner visitor behaviour, ordinary overflow and longer human fun/balance remain open. Existing EditableImage-disabled/legacy wrong-type warnings and intermittent failed egg-image fetches remain; fallbacks were tested and no security settings changed. Garnet/Ink colour trials remain design-only; versioned catalog/receipt compatibility and Ink Main night contrast are still TODO.

## Historical v389 — device, hatching and personal play

# Egg Drop — device, hatching and personal play

**Private v389 Published — runtime13afc44, committed and pushed.** Refreshed native Version History verifies **Personal toys, features and hatches - 13afc44**. [Publication proof](artifacts/device-hatch-play-2026-11-09/private-published-v389-13afc44.jpg). [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) · [Current gallery](artifacts/device-hatch-play-2026-11-09/GALLERY.html) · [Exact checks and limits](artifacts/device-hatch-play-2026-11-09/VERIFY.md).

The complete handheld now recoils together, with correct touch/aim mapping. Ended runs clear under cover before a fresh board appears; active suspended games keep their state. Larger measured type, shared scroll bounds, four-column pet cards, a horizontal halo and plain action faces replace the reported layout defects. Companion customization/switching is at the care cradle; Deck style is at the workbench. Pocket Menu keeps Hatch eggs, Pocket Trials and Settings. Exact saved-item Use now remains available without granting general editor access.

Five original patterned eggs share registered cracking halves, bounded rays/sparkles and one-shot audio; skip, repeat-open, Reduced Motion and interruption do not duplicate results. A matching saved fruit application starts a brief bite in the live preview. All hue/items, wallet and reward authority remain on the server.

**Toy Egg: 8 earned Stars.** Unlocks one remaining Ball, Bone or Sparkler permanently; freely select a toy or None per pet at the cradle. Quiet grounded pets play briefly during ordinary garden idle, stopping for movement, carry, care or focus. Selected toys are public appearance data; visitor motion is rendered locally and is not frame-synchronized. The old shared world-ball activity and props are removed.

**Feature Egg: 32 earned Stars.** Horn buds 50%, Claws 35%, Folded wings 15%. One stored item grows that feature on one pet by one stage through five. Freely show 0 through the earned stage; all three may coexist. Features are cosmetic. Full rolled stock refuses with no debit; odds do not silently change. The four-pet new-hatch pool and all seven retained owned IDs remain unchanged.

**Verification:** 190 unique client cases/21 suites at Largest (182-case batch plus bounded shop-reopen 7 and first-row 1), backend 126/11 and affected garden 47/5 (13 overlap backend). All 169 runtime sources match native Studio and compile; final Rojo/diff checks pass. Astra asset/geometry/phone review and independent Sol source review pass. Actual earned controls covered 24-drop merging/rewards, zero-old-frame reset, Toy Egg buy/equip and full Sparkler episodes. iPhone Studio emulation covered actual Touch A/aim/Menu/hatch; seeded owner editor/feature/fruit fixtures are labeled separately.

**Still open:** physical-phone performance, live-service save/rejoin, real multi-client visitor/carry/bay contention and longer human play. Feature purchases/growth and fruit animation use isolated exact transaction/presentation tests, not a naturally earned 32-Star walkthrough in this pass. Existing EditableImage-disabled and legacy wrong-asset-type notices remain. No account/security settings changed. Garnet/Ink, gradients/Metal, stats/training, textured larger garden and replacement retired-pet designs remain on TODO. No production-readiness or proven fun/retention claim.

## Historical v370 — playful care and material eggs

# Egg Drop — playful care and material eggs

**Private v370 Published — runtime97c64d0, committed and pushed.** Refreshed native Version History verifies **Playful care and material eggs - 97c64d0**. [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) · [Publication proof](artifacts/playful-care-2026-11-09/private-published-v370-97c64d0.jpg) · [Screenshot gallery](artifacts/playful-care-2026-11-09/GALLERY.html) · [Verification](artifacts/playful-care-2026-11-09/VERIFY.md).

Companions now has Pet / Hue / Charm / Materials tabs. Hue rows show0–5 with the saved dose checked; any notch offers exactly one next fruit, or explains no stock/max. Zero does not reset; Reset Hue still targets one confirmed channel. Confirmation art retires on every exit, and decisions omit routine Saved/Review use. The first Pet row has real top inset. Solid carry arrows and playful measured supporting type replace the older treatment. Short result cards show the item and both actions together.

**Material Egg:16 earned Stars**, initially50/50 Gloss/Matte, then100% the remaining finish. Account unlocks are permanent; applying Standard/Gloss/Matte per pet is free and reversible. No duplicates or spending when complete. Metal is excluded because its native trial resembled Gloss; gradients also remain TODO. Existing pigments, facial roles and historical receipts are preserved.

Charm changes request an immediate coalesced durable save instead of waiting for the periodic12s flush. One isolated actual Ring click reached durable confirmation in117ms; this is not live-service latency evidence. Daytime coats are brighter while accepted night emission remains unchanged. Device-art shake is stronger and tier/chain based, exterior backdrop has8% garden bleed, and three original egg images replace the capsule silhouettes. Ripple relay, Bank bounce and Mirror marks add compatible two-stage objective variety.

**Passed:**219client cases/25suites at Medium;190cases/24suites at Largest, plus the29-case hatch suite at Medium;191server cases/19suites. Preference reruns overlap and must not be added.149exact source matches/compiles, cold Rojo/diff checks, independent Sol reviews and Astra rendered GO. Actual24-drop Bank/Creek rounds earned rewards; actual Stars purchased Gloss and selected it for Zivvi. Six-seed new-objective solver replay passed6/6,5/6,5/6; ordinary native completion of those new templates remains open. Final clean launch/5actualSpace presses earned the starter. QA removed,7unique native material profiles, production scripts enabled, Medium/Automatic/default viewport restored.

**Still open:** physical phone/touch, live-service save/rejoin, real multi-owner carry/bay contention, R6 controls, lowest graphics and longer human play. Existing EditableImage-disabled/legacy asset-type notices remain; no security setting changed. Dark-red/black pigments, Metal/gradients, features/stats/training and the textured garden remain on TODO. No production-readiness or proven fun/retention claim.

## Historical v358 — companion editor and luminous pets

# Egg Drop — companion editor and luminous pets

**Private v358 Published — runtime4bf7893, pushed.** Refreshed native Studio Version History marks v358 Published. [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) · [Publication proof](artifacts/companion-editor-2026-11-09/private-published-v358-4bf7893.jpg) · [Screenshot gallery](artifacts/companion-editor-2026-11-09/GALLERY.html) · [Exact checks and limits](artifacts/companion-editor-2026-11-09/VERIFY.md).

Round results use readable dark ink, a better Stars emblem and already-open scrolling details; the obsolete selected-egg progress area and Details button are gone. **Companions** replaces Journal entry routes with Pet / Hue / Charm tabs, square live owned-pet previews, a fixed live preview and independently scrolling choices. Main and Secondary remain separate, and item use still asks for confirmation. Charm On / Off is explicit; Ring is one original continuous torus. The editor has a bare X and no Stars/carry footer. Closing the physical machine returns the confirmed pet to your arms; the down arrow sets it down safely. Forced cleanup remains separate.

Pets are brighter at night through pet-local emissive PBR surfaces, with darker eyes, visible catchlights and a more luminous charm. Day/night and the garden's global lighting are unchanged. All seven retained designs render with this treatment; the Companion Egg still offers four pets and preserves already-owned retired pets.

**Passed:**161 client cases/20 suites at both Medium and Largest (overlapping preference runs),145 server cases/15 suites,144 exact native source matches and zero compile errors, Rojo build, independent Sol source review and Astra visual review. Ordinary earned Studio controls covered welcome, pickup, walking, placement, saved Ring, X→carry, set-down, overflow receipt and hatch route. Seven-owned previews/positive14-Star receipt and material lineups are labeled fixtures. Six paired seven-pet material rounds showed stable frame time and +0.132ms pet CPU p95. Test objects removed; Medium/Automatic/default viewport restored.

**Still open:** physical phone, live-service save/rejoin, live visitor/bay contention, R6 owner controls, dedicated owned-editor baseline performance comparison and longer human play. Test-enabled-session Focus interference has no established cause; clean ordinary sessions pass. Existing EditableImage/legacy wrong-asset-type notices remain. No production-readiness or fun/retention claim.

## Historical v344 — carry and care machine

**Private v344 Published — Carry and care machine - 5b829e6.** Runtime is committed and pushed; refreshed native Studio Version History shows Published. [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) · [Publication proof](artifacts/carry-machine-2026-11-09/private-published-v344-5b829e6.png) · [Screenshots and walking film](artifacts/carry-machine-2026-11-09/GALLERY.html) · [Exact tests and limits](artifacts/carry-machine-2026-11-09/VERIFY.md).

Tap your pet, choose **Pick up**, walk to the **Field journal** and use **Place [pet]**. The original cradle opens the live Hue/Charm editor. Pick up again, set down on clear dry ground, or close to resume following. Owned-pet switching asks for confirmation and changes the public pet only after exact saved proof; existing menu shortcuts remain.

Astra accepted the earned R15/Zivvi walk-turn-stop and the actual Largest iPhone17Pro emulator editor. The arms remain a supported cradle while the legs walk. Compact Charm keeps the complete live pet and all three choices visible. Unsafe set-down preserves the hold; deck/close paths release their exact bay.

**Verification:** prior full301-case/36-suite checkpoint retained; final145 server cases/15 suites and45 affected cases/7 suites at actual Largest pass (overlapping reruns, not new independent counts). All142 runtime sources match and compile; Rojo passes. Native controls covered earned pickup, walking, placement, Ring saving, pickup/set-down and close/deck interruptions. Medium/default viewport restored; clean Edit/production entries enabled; QA removed.

**Open checks:** the separate two-player Studio launcher refused to start because Studio is out of date. Actual visitor carry, real R6 controls, physical phone and live-service save/rejoin remain unverified. Isolated two-owner/receipt/lease tests and synthetic R6 geometry are labeled separately. Owned-pet switching is verified through isolated exact-save/UI cases rather than a naturally earned second-pet walkthrough. Minor redundant Charm copy may stay hidden after size-only return to desktop until refresh. The larger textured garden and expanded item systems remain on TODO; no public release or economy changes.

## Historical v326 — complete pets and live Customize

# Egg Drop � complete pets and live Customize

**Private v326 Published � Whole pets and live Customize - 3c6b61b.** Runtime is committed and pushed, verified in refreshed native Studio Version History. [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) � [Publication proof](artifacts/care-feedback-2026-11-09/private-published-v326-3c6b61b.png) � [Care gallery with recordings](artifacts/care-feedback-2026-11-09/GALLERY.html) � [Verification](artifacts/care-feedback-2026-11-09/VERIFY.md).

Complete semantic pets remain visible while authored meshes load. Customize now idles, blinks and moves the charm, with exact five-notch result swatches. Reset consumes one jar for one explicitly confirmed Main or Secondary channel. Accepted merges nudge the device art while aim and hit targets stay fixed. Quieter coo poses use existing approved original family audio; four new original auditions remain local.

181 native cases across 23 suites, 132 source matches and zero compile errors, Rojo build, actual earned controls and Largest phone-emulator customization pass. Six paired seven-rig performance rounds show no measured CPU regression in the isolated warmed Studio workload. Accelerated coo playback passed, but a 160-second ordinary roam produced no coo; normal frequency remains unverified. Physical phone, live-service rejoin and human fun remain open. Carry/machine and original garden are next, not included in v326.

## Historical v316 � neutral companions

# Egg Drop — neutral companions

**Private v316 Published — Neutral companions and four-pet pool - c549451.** Runtime c549451 is pushed and verified in refreshed native Version History. [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) · [Publication proof](artifacts/pet-materials-2026-11-09/private-published-v316-c549451.png) · [Scope and verification](NEUTRAL-ROSTER.md) · [Exact hue chart](artifacts/pet-materials-2026-11-09/current-hue-palette.png).

Undyed bodies start white; paws, charms and secondary accents start light grey. Existing Main/Secondary hue items and doses remain; hands/cuffs now follow Secondary. New Companion Eggs offer Zivvi, Ovelle, Tikket and Nuum. Vezzi/Kiprik/Nolli remain usable if already owned, with preserved stable IDs and receipts. The absent rare pool suspends the rare guarantee without erasing saved progress.

125 native source matches / zero compile errors, isolated Rojo build and148 native fixture cases across15 suites pass. Ordinary welcome controls earned the white Zivvi reveal. An actual follow-up focus attempt did not establish focus with the controller emulator visible; do not count it as passed. Physical-phone and live-rejoin limits remain. The separate gloss/night-material experiment is preserved locally and **not included in v316**.

## Historical v309 — Spring Meadow and Aero babies

**Private v309 Published — Spring Meadow and shared resting - b71c702.** Runtime b71c702 is committed and pushed; refreshed native Studio Version History verifies Published. [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) · [Proof](artifacts/spring-meadow-2026-11-09/private-published-v309-b71c702.png) · [Gallery](artifacts/spring-meadow-2026-11-09/GALLERY.md) · [Verification](artifacts/spring-meadow-2026-11-09/VERIFY.md) · [Morning handoff](MORNING-RUNDOWN.md).

The garden now has **160 ×176 studs /37.5% more floor area**, a dry south loop, spring landmark and gathering lawn with two separate six-second pet resting spots. Existing shops, ten spawns, bridge, nook, shared return, all seven babies and item-egg rules remain. No client runtime, schema, economy or reward change in the extension. Astra art/motion/Largest-phone focus and independent Sol source review have GO.

**124 native source matches/zero compile errors; Rojo;198 server cases/21 suites;91 focus cases/six suites;13 final geometry cases** pass. Actual local two-owner routes/rest/focus and unchanged wallets are recorded. Synthetic performance initially triggered a10.41% midnight rig-CPU increase; the declared repeat retained all six final rounds, combined+9.40% (~0.104ms). Phone/service-scale performance is unproved.

Standalone Roblox Player still requires user sign-in for live rejoin; no live VM/profile test ran. The browser connection failed on the v309 census refresh, so no new server census is claimed. Publication itself is native-verified. Physical phone, longer human play, flatter night shading, narrow gray far horizon and old outer-boardwalk pet support remain limits. No access/security/public-release changes.

## Historical v297 — Aero babies and shared garden

**Private v297 Published — Aero babies and shared garden - `2e9da43`.** Runtime commit `2e9da43` is pushed; publication is verified in refreshed native Studio Version History. [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) · [Publication proof](artifacts/aero-garden-2026-11-09/private-published-v297-2e9da43.png) · [Current gallery](artifacts/aero-garden-2026-11-09/GALLERY.md) · [Exact verification and limits](artifacts/aero-garden-2026-11-09/VERIFY.md).

The item-egg economy from v274 continues unchanged. Explore the usable creek bridge and curved rest nook on the existing **160 × 128** floor. Five replacement babies — **Tikket, Nuum, Vezzi, Kiprik and Nolli** — retain all saved identities/ownership; Zivvi and Ovelle retain their original bodies. All seven share saved Main/Secondary pigments, protected faces and expressive planted motion.

Journal → Customize offers free **Dot / Ring / Pebble** and saved visibility. Published source has `SelectionsEnabled=true` and `PetCharmVersion=2`, with old-client visibility compatibility and opaque future-shape retention. On the clear lawn beyond the benches, **Start a return**, then another nearby owner can **Join return** during the three-second window. Pets approach at their own validated pace and perform a five-second send/return. The toy gives **no rewards**, spends nothing and changes no inventory.

**Evidence:** 123 native source matches / zero compile errors, Rojo build, **172 server cases / 19 suites** and **292 client cases / 36 suites** without duplicate reruns. Ordinary two-client Start / Join / release has Astra film GO; both owners' wallets and inventories stayed unchanged. Actual two-way bridge walking, nook rest, continuous-care Saved awards and short-landscape Largest phone-emulator focus were observed. Medium text and clean Edit were restored before publication. The 6:11 AM post-publication census found one Team Create edit server and no gameplay writer. Night is readable but flatter, with weak individual Vezzi teeth.

Live join was attempted through the authenticated browser but reached Download Roblox while the standalone player was signed out; no live VM/profile test ran. Signing in to the standalone player remains the prerequisite, not a reproduced game or DataStore fault. Physical-phone performance, live save/rejoin, service-scale latency and longer human play remain untested.

The liked music remains default; two new original local listening drafts are in the gallery, with technical approval and subjective listening pending. Nursery, battling, clothing/stat eggs, new currency and public release remain deferred. [Remaining work](TODO.md) · [Current handoff](OVERNIGHT-AERO.md).

## Historical private v274 handoff — retained item-egg rules

# Egg Drop — item eggs and Aero companions

**Private v274 Published — Item eggs and Aero companions — `bb8c60b`.** Verified in refreshed Studio Version History. [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) · [Publication proof](artifacts/item-eggs-aero-2026-11-09/private-published-v274-bb8c60b.png) · [Screenshots and walking films](artifacts/item-eggs-aero-2026-11-09/GALLERY.md) · [Exact verification and limits](artifacts/item-eggs-aero-2026-11-09/VERIFY.md).

1. Aim the welcome board for guaranteed Zivvi and6Stars. Then play unlimited24-drop field rounds: complete both goals for6Stars, or8 with the low-pile bonus; eligible contracts add their stated rewards.
2. Hatch eggs is one grid: **Companion Egg18Stars** or **Hue Egg8Stars**. Companion odds remain35/25/20/10/5/3/2percent across the seven stable identities; after7common rolls the next is rare-only50/30/20. Duplicates say Already owned and grant nothing. Existing paid legacy receipts remain recoverable.
3. A Hue Egg rolls Rose/Tide/Citrus/Iris/Reset at20%each. The exact jar and wallet debit save before reveal. Duplicate jars stack. Store, Use now and closing/reopening never reroll or charge twice.
4. Journal → each pet's Customize icon → Hue has separate **Main/Secondary** targets, four0–5dose bars and counted jars. Five equal doses fully dye a channel; other hues mix using vivid authored anchors. Confirmation shows pet, channel, dose and stock changes. Reset consumes one jar and restores only the chosen channel. Original-color reset refuses without spending. Charm visibility/shape editing is in this page, not petting.
5. All7identities display applied coats in world/portrait/hatch/visitors. Wallet, held stock, tokens and receipts are owner-private; applied doses are cosmetic public descriptors. Historical entitlements/tokens migrate without repeating grants.
6. Roots and foot planting update smoothly; expressive poses sample15times/sec. Faster facing, anchored support feet, modest weight transfer and independent charm bounce replace sliding. Night is brighter without white clipping, but surfaces remain flatter than noon.

Family mastery remains frozen. The optional daily gift is6Stars; contracts retain Win2rounds+4, Chain3+3, Score500+3. No play cap, paid luck, new currency, nursery or public release. The currently liked music stays default; two new original listening drafts are saved separately.

**Evidence:**112source matches/compiles, Rojo build,102server cases and143client cases at actual Medium/Largest; these are repeated preferences, not extra independent cases. Actual earned Iris purchase/store/cancel/use and phone-emulator menu paths passed. Physical phone, fresh service-backed save/rejoin, live multiplayer/latency and long human play remain open. Current overnight work is [TODO](TODO.md) and [OVERNIGHT-AERO](OVERNIGHT-AERO.md).

## Historical v250 handoff

# Egg Drop — pet loop reset

**Private v250 Published — Pet loop reset and angle aim - a3fce0c.** Confirmed in refreshed Studio Version History after reviewed commit/push and tests. [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) · [Publication proof](artifacts/pet-loop-reset-2026-11-09/private-published-v250-a3fce0c.png). Accepted runtime: [PET-LOOP-RESET.md](PET-LOOP-RESET.md).

[Reset gallery](artifacts/pet-loop-reset-2026-11-09/GALLERY.md) · [Exact verification and limits](artifacts/pet-loop-reset-2026-11-09/VERIFY.md) · [Economy/save rules](HATCH-LOOP.md).

## Current loop

1. Aim and merge on the welcome board for guaranteed **Zivvi**, then Meet or explore Sprout Hollow. Zivvi/Ovelle retain stored IDs `pip`/`puddle`; sparse veteran ownership and pending receipts stay intact.
2. Open the PocketDeck for unlimited **24-drop rounds**. Bank Pair, Creek Crossing and Lantern Chain rotate. Read the active goal, use the fixed center launch and keep the pile low. Aim maps symmetrically to **±35 degrees at speed 10**; all input paths use the same server-derived spawn/vector. Thin region-threshold lines replace filled/highlighted regions.
3. Both goals earn **6 Stars**, or **8** with the low-pile bonus. Full-budget failed rounds may earn their eligible skill contracts. Recap shows the exact saved amount and selected egg progress. Unfinished rounds survive lounge visits; returning after a completed saved round starts a fresh field. Reconnect starts a new physical board.
4. Hatch tree or Menu → Hatch eggs → **Companion eggs** offers Mixed Meadow (18 Stars) and Sprout Focused (24). Selection is free; only explicit Hatch spends. Close/reopen preserves the exact committed result. A duplicate says **Already owned**, grants nothing and does not change equip unless Meet is chosen. Rare duplicates still resolve the rare guarantee.
5. **Hue Egg** costs **8 Stars** and creates one saved, unassigned held item. Close/reopen retains it. After hatching, choose an actually owned supported Zivvi/Ovelle and one hue, then explicitly **Apply to [pet]**. That exact token advances one hue grade, at most III, without a second debit. No second purchase while stock is held; no purchase when supported owned pets have no further eligible grade.
6. **Colors** is free: learned Body and Accent picks, six two-base Mix recipes, Original body / Default accent, and **Reset to original colors**. Reset preserves grades, unlocks, held stock and charm visibility. Previewing never saves or spends. Body tint strengths are **.65 / .84 / 1.0**, with vivid Rose `#FF327A`, Tide `#008DFF`, Citrus `#FFCC00`, Iris `#9350FF`; protected face roles remain authored.

## Collection and return goals

Seven stable catalog identities remain. Meadow odds are **35/25/20/10/5/3/2%** for Zivvi, Ovelle, Wick, Orbit, Bloom Pip, Foxfire Wick and Eclipse Orbit. Focused is **80% Zivvi /20% Bloom Pip**. After seven non-rare companion hatches, the next is rare-only; this does not guarantee a missing common. Hue Eggs have no rarity roll, pity effect or companion inventory bit.

**Family mastery is frozen.** No new round/hatch marks, challenges, promotions or overhead rank badges; no active Family goals route. Historical marks, receipts and cosmetic entitlements are retained. New saved-win cosmetic gates are **Gloaming at 3 wins**, **Copperleaf and Lantern background at 10**, with old earned entitlements still valid. Honey remains 1 saved win; independent Pocket Trials and other achievement cosmetics remain separate.

Stars are the existing `nectar` wallet one-for-one. Welcome credit is 6; the optional daily gift is 6. Contracts are Win 2 rounds +4, Chain 3 +3 and Score 500 +3 under their valid completed-round rules. Hollow rollover is fixed **05:00 UTC**, with no daily play cap or paid luck.

## Focus, motion and current evidence

Pet focus pauses the server's sampled public actor; a covered owner-local shot never becomes public movement or reach proof. Back restores the current public actor and roaming view, not a stale staged root. The owner avatar is locally masked only for its private shot. Back and labeled Hide/Show charm retain independent targets. Walking drives visible gait; focus, rest and reduced motion suppress it. Night uses the reviewed shaded-head treatment with restrained torso lighting; source-rig comparisons are labeled separately.

Fresh integration matched and compiled **104 sources**. Verified Largest Hue suites passed **13+12**, with fresh uncached presentation suites **13+3+2+3**. Native controls completed 24 drops, settled at **670 /+14 Stars**, then bought a held Hue Egg **20→12**. Actual buy/reopen/apply, independent accent, free mix and reset records are linked in VERIFY. The final ~14-second care input reacted but awarded **0 Stars**; do not count it as observed award proof.

Actual two-client telemetry passed public-pose continuity and owner-only avatar masking through focus/Back. Walking samples showed about .13 studs vertical range over ~18 studs travel. These are pose/mask samples, **not a fixed-camera visual film**. The observed idle sample near the creek showed only rest/follow; safe wander has planner/host test coverage, not live proof from that sample. Physical phone comfort, live-service save/rejoin, latency and longer human play remain unverified. Nursery, additional base forms and public release remain deferred.

## Historical publication records — superseded rules

The records below describe older published builds. Their mastery, old directional Hue purchase and region-fill behavior do not override the accepted reset above.

### Private v241 — 2026-11-08

**Private v241 Published — Stars and Hue Eggs - 7145db9**, verified in refreshed Studio Version History after tests, reviewed commit and push. [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) · [Publication proof](artifacts/hue-eggs-2026-11-08/private-published-v241-7145db9.png) · [Hue gallery](artifacts/hue-eggs-2026-11-08/GALLERY.md).

145unique Largest client cases and59isolated server cases passed;60Medium checks repeated successfully. Actual desktop earned purchases, duplicate-click single charging, independent free selections, fresh phone-emulator swipe/earn route and actual two-client same-rig palette propagation passed. Physical phone, private-client rejoin and live latency remain unverified. [Hue screenshots](artifacts/hue-eggs-2026-11-08/GALLERY.md) · [Exact Hue evidence](artifacts/hue-eggs-2026-11-08/BUILD-EVIDENCE.md).

The v241 Hue flow selected pet/direction before purchase and used subtle 12%/23%/35% tints. That historical flow is replaced by the generic held Hue Egg and vivid .65/.84/1.0 grades above.

### Private v232 — 2026-11-08

Previous checkpoint: **private v232 — Softer babies and smooth movement - 355fad7**, confirmed in refreshed Studio Version History after tests, commit and push. [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) · [Publication proof](artifacts/pet-softening-2026-11-08/private-published-v232-355fad7.png). This supersedes private v225. Nursery, paid products and public release remain deferred.

The latest pass softens Zivvi and Ovelle into neutral porcelain/pebble babies, replaces Ovelle's suspended arms with attached mittens, and adds seeded blinks, breathing, slow gaze and a softly independent Dot bounce. Shared follow paths ease through turns and braking. The PocketDeck backdrop is stronger, its A-adjacent caption is removed, and both bank overlays sit behind the jelly colors. **114 unique native client /98 isolated server checks passed**, alongside actual desktop/phone-emulator controls and a two-client Studio session with saved charm propagation and leave cleanup. [Current screenshots](artifacts/pet-softening-2026-11-08/GALLERY.md) · [Exact evidence and live movement limits](artifacts/pet-softening-2026-11-08/BUILD-EVIDENCE.md).

## Prior published v180 verification and limits

Final:81runtime sources matched/compiled, Rojo build and diff check passed. Companion client61 and isolated server69 passed; completed/live-return regression21 passed. Earlier slices have their own named layout, appearance, solver, audio and lifecycle suites in the evidence. These repeats are not summed as new coverage.

Actual final controls completed welcome → Pip →24-drop Bank660/chain4 →Saved+12 wallet6→18 →18Meadow Wick →X/reopen sameID/revision →Meet →Back →fresh Creek0/24 with no old recap. Actual foreground29-second petting saved two+1 awards with one purr voice; emulated touch, muted/reduced eligibility, same-finger leave/reentry and window interruption were checked. Source-rendered seven-pet night lineup is a lighting/rig fixture, not seven owned/live peers.

288 production-solver comparisons included72 fast-center rounds, all overflowed and won0; objective-aware policy won24/24 for each template. Nine legal winning traces replayed exactly. These are automated policies, not proof of human difficulty, fun or retention. A rejected lateral-chain experiment is retained as nonshipping evidence.

Short final desktop Room sample:180frames after30warm-up, p95 17.850ms, no new Room node growth; existing62-node arcade FX benchmarks stayed pooled. Engine playback events verify sound ownership/loading/looping, not an audible mix/seam judgment. Optional EditableImage remains unavailable under unchanged settings; tested native GUI spans render the LCD. Known external asset203785492 warnings remain.

Still needed: your physical-phone comfort/performance check, live multiplayer, actual private-client save/rejoin and longer human play/balance/audio testing. This is a private playable prototype, not a production-readiness or proven-retention claim.

[Before/after gallery](artifacts/living-world-2026-11-07/GALLERY.md) · [Exact build/test notes](artifacts/living-world-2026-11-07/BUILD-EVIDENCE.md) · [Accepted design and boundaries](LIVING-WORLD-AND-ARCADE-PASS.md) · [Full economy/save rules](HATCH-LOOP.md).

## Simple layout edits

Tune small layout values in `src/client/DeckLayout.lua` Settings; `src/shared/DeckThemes.lua` holds palettes and `src/client/DeckArt.lua` shared design roles. Restart Play after changes and inspect desktop plus phone emulation. Dragging generated UI during Play is temporary; source/Rojo is the saved version. Keep44px input targets and screen clearance.
