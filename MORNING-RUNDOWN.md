# Egg Drop — November 9 morning build

**Private v309 Published · runtime b71c702 · feat/egg-drop-arcade-polish.** The reviewed code is committed and pushed. Refreshed Studio Version History confirms “Spring Meadow and shared resting - b71c702.” Only the existing private Egg Drop place was updated; access and account settings are unchanged.

[Play the private game](https://www.roblox.com/games/96451847774961/Egg-Drop) · [Publication proof](C:/Users/skunk/Documents/Development/egg-drop/artifacts/spring-meadow-2026-11-09/private-published-v309-b71c702.png) · [New garden gallery and films](C:/Users/skunk/Documents/Development/egg-drop/artifacts/spring-meadow-2026-11-09/GALLERY.md) · [Models, hatching and shared play](C:/Users/skunk/Documents/Development/egg-drop/artifacts/aero-garden-2026-11-09/GALLERY.md) · [Exact current evidence](C:/Users/skunk/Documents/Development/egg-drop/artifacts/spring-meadow-2026-11-09/VERIFY.md) · [Remaining work](C:/Users/skunk/Documents/Development/egg-drop/TODO.md)

## What shipped

The item-egg build and the follow-on garden pass are both in the private game. Astra directed the original assets and reviewed the actual models, night views, gait and shared-play film. Sol 6.1 High implemented the systems; fixes passed independent source review before publication.

- **All seven babies have authored models.** Zivvi and Ovelle keep their existing baby forms. Tikket, Nuum, Vezzi, Kiprik and Nolli replace the five legacy forms, with new portraits, neutral base coats, expressive face pieces, planted steps and loosely bouncing charms. Existing ownership and pigment remain attached to the same permanent pet identities.
- **The garden is now 37.5% larger:** 160 × 176 studs, with a dry loop beyond the former south boundary, rounded lavender spring shelves, a cyan fall and another gathering lawn. Two babies can settle five studs apart for six seconds, then resume their normal behavior; walking and petting interrupt safely. The existing supported creek crossing, curved nook, physical shops and glass-accented ball-return gate remain in place. Nearby scenery moves within a fixed budget; day/night and warm lantern lighting remain. The expansion adds **64 parts** while retaining four managed lights.
- **Two pets can return a ball together.** Walk near the gate with your pet and use Start; another nearby player can Join during the three-second window. Pets approach, face one another, play a five-second exchange and resume their normal behavior. A solo return also works. This activity grants no Stars, items or stats.
- **Dot, Ring and Pebble charms are free options.** Journal → the pet’s Customize icon → Charm. Hide/show is saved per pet; a hidden charm stays hidden when its shape changes. Charm color follows Secondary pigment. The old client’s visibility requests preserve newer shapes.
- **Hatching is more saturated and animated:** a cobalt/lagoon stage, patterned shell split and bounded droplets/prisms. The receipt and save rules remain authoritative. Short-landscape pet focus now keeps its helper above the face and feet.
- **Care rewards work through sustained contact.** Hold/rub the focused pet, or hold the supported keyboard contact control. The pet reacts; valid continued contact can earn +1 Star, capped at five care Stars per Hollow day. Back exits the held pet view. Simply opening focus grants nothing.

These are Blender design renders of the five new bodies; the gallery also has the actual uploaded Roblox models and measured night views.

![Five new original baby designs](C:/Users/skunk/Documents/Development/egg-drop/assets/garden-babies/new-five-2026-11-09/five-babies-gallery.png)

Two actual local players and their earned pets at the new spring, under controlled noon lighting. Walking was automated through Studio; the initial camera heading was staged.

![Two players at Spring Meadow](C:/Users/skunk/Documents/Development/egg-drop/artifacts/spring-meadow-2026-11-09/two-earned-companions-spring-actual.png)

The accepted saturated hatch presentation, reached through ordinary starter drops in the earlier v297 phone-emulator test, is retained in v309:

![Earned starter hatch on the phone emulator](C:/Users/skunk/Documents/Development/egg-drop/artifacts/aero-garden-2026-11-09/actual-phone-largest-earned-hatch.png)

## The player loop and rewards

1. New players aim and merge on the welcome board for guaranteed **Zivvi and 6 Stars**. Returning accounts keep their existing collection and purchases.
2. Play unlimited **24-drop rounds**. Bank Pair, Creek Crossing and Lantern Chain rotate. Use the center launch angle and read the active goal; later goals require different merge locations or a continued chain. Complete both goals for **6 Stars**, or **8** with the low-pile bonus. Failed rounds can still finish eligible skill contracts. Score and chain support those goals and personal bests; they are not separate spendable currencies.
3. Spend earned Stars in the single Hatch eggs grid: **Companion Egg 18**, **Hue Egg 8**. The hatch tree opens the same shop without buying anything. Journal and deck-style stations retain fast menu shortcuts.
4. Companion odds are **Zivvi 35%, Ovelle 25%, Tikket 20%, Nuum 10%, Vezzi 5%, Kiprik 3%, Nolli 2%**. After seven consecutive common outcomes, the next roll is rare-only at 50/30/20. A duplicate companion says Already owned and grants nothing.
5. Hue Eggs grant a saved **Rose, Tide, Citrus, Iris or Reset jar**, each at 20%. Store it or use it immediately. Jars stack; closing or reopening never rerolls the result. Journal → Customize → Hue selects the pet and Main/Secondary channel. Each hue has five dose notches; repeated doses deepen it, different hues mix, and a Reset jar clears only the selected channel. Every use asks for confirmation.
6. The optional daily gift is **6 Stars**. Contracts are **Win 2 rounds +4, Chain 3 merges +3, Score 500 +3** under their completed-round rules. The Hollow day rolls at **05:00 UTC**. Family mastery/prestige is frozen: no new ranks, marks or overhead level badges. Earned deck cosmetics remain, including Honey at one saved win, Gloaming at three, and Copperleaf/Lantern background at ten.

No paid luck, daily play cap, new currency, nursery or public release was added. Clothing/stat eggs, battles and further minigames remain future scope.

## What was tested

- **124 of 124 runtime sources** exactly matched native Studio and compiled without errors; the Rojo build passed. Seven templates contain **122 validated uploaded mesh resources**.
- **198 server cases across21 suites** passed for the garden continuation, retaining transaction, hue, session and contact regressions. **91 focus cases across six client suites** passed again; final art also passed a fresh13-case native geometry check. The prior broader client union is292 cases/36 suites; those were not all rerun for the world-only expansion. Counts exclude duplicate reruns/preferences.
- Ordinary tutorial drops earned Zivvi and opened the new hatch/Meet path. A separate 30-second contact hold produced **two Saved care-Star receipts**, without injecting a reward.
- Previous accepted controls crossed the creek both ways and demonstrated nook rest. In the final expansion, **two ordinary local players** crossed both new dry limbs, gathered and returned to the hub. Across1,437 quarter-second samples, pets stayed at floor height and below18stud/s. Eight logged rests scheduled six seconds;30 samples showed both anchors occupied five studs apart. Walking and focus interrupted rests. Replicated avatar roots batched, so their server trace does not certify smooth avatar velocity; the recording separately shows running. This is local automated navigation, not a live multiplayer/physical-phone test.
- **Actual local two-client Start/Join action 322** showed the ball passing both directions; both owners stayed at six Stars with unchanged hue stock, inventory and profile revision. Separate ordinary controls saved Pebble → Hide → Ring while hidden → Show; the visitor observed the same appearance pair.
- Final Spring **iPhone13 landscape emulation / Largest /749×388**, at controlled noon and midnight, keeps charm, face, hands, feet and Back clear. It is not a physical phone test.
- Matched synthetic seven-rig world comparisons stayed around18ms elapsed frame time. Noon rig CPU changed1.1579→1.1482ms. The initial midnight three-round increase was **10.41%**, triggering investigation; one declared repeat retained **all six** final rounds, with combined1.1066→1.2106ms (**+9.40%, about0.104ms**). Cause is not isolated. No source changes or favorable-sample replacement occurred between those six rounds. This is desktop fixture performance, not phone/service-scale proof.

![Actual two-client return contact sheet](C:/Users/skunk/Documents/Development/egg-drop/artifacts/aero-garden-2026-11-09/actual-relocated-two-pet-return-contact.jpg)

[Watch the actual return](C:/Users/skunk/Documents/Development/egg-drop/artifacts/aero-garden-2026-11-09/actual-relocated-two-pet-return.mp4).

The final expansion's separate recording demonstrates route/rest/focus behavior. Its new paired-Join attempt missed native timing/input, so the earlier accepted paired return above remains separate evidence.

![Final garden walkthrough storyboard](C:/Users/skunk/Documents/Development/egg-drop/artifacts/spring-meadow-2026-11-09/walk-evidence/walk-storyboard.png)

[Watch the new garden approach](C:/Users/skunk/Documents/Development/egg-drop/artifacts/spring-meadow-2026-11-09/walk-evidence/01-west-out.mp4) · [Two resting pets at night](C:/Users/skunk/Documents/Development/egg-drop/artifacts/spring-meadow-2026-11-09/walk-evidence/02-separated-night-rests.mp4) · [Phone focus at night](C:/Users/skunk/Documents/Development/egg-drop/artifacts/spring-meadow-2026-11-09/phone-largest-spring-focus-midnight-actual.png).

## New original music drafts

The currently liked in-game music stays the default. These two original local drafts are ready to audition; they have not been uploaded or substituted into the game. Deterministic loop/seam, mono and loudness checks passed; subjective listening is still yours to judge.

**Creek With One Shoe** — quirky garden cue, 92 BPM, 62.61-second loop:

![Creek With One Shoe](C:/Users/skunk/Documents/Development/egg-drop/assets/concepts/music/overnight-aero-2026-11-09/creek-with-one-shoe.mp3)

**Pocket Skip** — brighter handheld cue, 120 BPM, 48-second loop:

![Pocket Skip](C:/Users/skunk/Documents/Development/egg-drop/assets/concepts/music/overnight-aero-2026-11-09/pocket-skip.mp3)

## What to try in the morning

Play a round, hatch/store a Hue jar, apply it to Main and inspect Secondary separately. Choose Ring or Pebble, hide/show it, then leave and rejoin to check the same appearance and inventory. Follow the south trail to the new spring, approach either resting spot and try petting/Back there. Walk the creek bridge, approach the nook, and try the toy with another player. Pet a baby for around30 seconds and judge the reaction, sound and Star feedback. On your phone, check the lowest controls, scrolling and focus framing. Tell me which movements, materials or screens still feel wrong and which music draft you prefer.

**Open limitations:** the standalone Roblox Player is signed out; the browser Play attempt reached a download fallback, so no fresh live save/rejoin is claimed. The browser connection later failed during the v309 server-list refresh; the last server census belongs to v297, not v309. Native Studio Version History does independently confirm v309 Published. Sign in to Roblox Player when convenient for live checks. Physical phone, service-scale latency and longer human fun/pacing tests remain open. Night bodies are readable but flatter than noon; the proposed .60 brightness target was not met, and individual Vezzi teeth remain weak. A narrow gray horizon strip and old outer-boardwalk pet support remain art/navigation debt. One earlier tool-assisted focus obstruction is unattributed; current ordinary desktop/phone focus was clear. Known EditableImage-access and old asset-type warnings remain; no security setting changed.

Studio was left in Edit with production entries enabled, temporary QA objects removed, normal desktop emulation and the original Medium text preference restored. The overnight automation runs only through 9 AM Eastern, then starts no new changes. This build is a tested private prototype; it is not a production-readiness or retention claim.
