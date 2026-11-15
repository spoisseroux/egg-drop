# Spencer's pre-publish QA

**Private v685 is now published for phone QA.** [Open Egg Drop](https://www.roblox.com/games/96451847774961/), signed into the owner/test account with access. Mobile/tablet are enabled; the universe remains PRIVATE. This is a fresh-save QA build. Runtime is the reviewed70e0440 checkpoint; current72-second v3 music is retained by Spencer’s explicit selection. [Actual animations, Jelly and new visuals](native-review/README.md). Public release is still on hold.

Mark each item **OK / change / bug**, with the item number and a screenshot or short note. These are human acceptance checks; the existing automated test results do not mark them passed for you.

## 1. First visit and hatch animation

- [ ] **01 · Fresh-player flow.** Play the welcome round, get Bear, meet Bear, open the first Toy Egg and choose Give to Bear. Is the route understandable without outside instructions? After Give, Bear should play with the toy when safely idle, without reopening a menu or needing another command. Walking away or choosing another route should cancel the guide naturally.
- [ ] **02 · Bear hatch.** Watch a full reveal without skipping. Bear should emerge forward, centered, growing/fading into view, then express excitement with its eyes/face/body. Its feet should feel grounded once it lands; it should not look like it rises through the floor. Is the entrance, hop/wave and overall pacing good enough to ship?
- [ ] **03 · Shell breakup.** The two lower shell pieces stay on their respective sides. Pieces shrink, move back and dissolve quickly; they should not cross through each other, linger motionless, or obscure Bear/the item.
- [ ] **04 · Item/cosmetic hatch.** Watch Toy and at least one hue/material cosmetic reveal. Each result should emerge centrally from the same egg language, look large/readable, and demonstrate the actual item appropriately. Confirm receipt text and action match what was unlocked. Pets get extra character animation; items share the reusable entrance.
- [ ] **05 · Hatch sound and controls.** Listen to Bear, Toy and a cosmetic hatch. Does each feel exciting without being harsh or drowning out the moment? Try skipping once, then confirming the receipt once: neither should accidentally activate the other. Reopening a saved receipt should not replay a purchase or grant.
- [ ] **06 · Reduced Motion / sound settings.** Repeat a reveal with Reduced Motion and sound disabled. It should settle with a brief fade, retain readable results/actions, and respect mute. Test closing/reopening a menu during loading; no stuck dark stage or ghost animation.

Current screenshots show **receipt endpoints**, not the full animation: [Bear receipt](hatch-production/native-final-bear-receipt.jpg), [Toy receipt](hatch-production/native-final-toy-receipt.jpg), [real first-toy play](hatch-production/native-final-first-toy-play.jpg). The earlier two-item “115 px” image was a temporary sizing test placed over unrelated game UI. It is **not a proposed game screen** and is not a design to approve.

[Listen to the four active hatch cues](audio/qa-hatch-sounds/hatch-cues-review.mp3): Bear (0:00), Toy (0:05), Hue (0:08.7), Material (0:12.4). These are the existing sound assets at source gain, separated by silence; assess their timing/volume against music in Studio. Feature Egg is currently hidden and is omitted.

## 2. Pocket Deck and menus

- [ ] **07 · Phone hardware.** In a landscape phone viewport, the Pocket Deck shell, screen, arcs and background should look intact, with no duplicate/misaligned layers. Repeat on desktop; retain the same design.
- [ ] **08 · Quests during a round.** Open Quests from the lower-left region, read them, close and resume the same round. The board should retain its state and regain controls. Try mouse/touch and your usual keyboard/gamepad controls.
- [ ] **09 · Results transition.** Finish a win and a loss. Results should enter the same handheld/LCD framing, without swapping to another shell or camera. Check wallet top clearance and the rotating Star from several angles: no doubled surface/striping.
- [ ] **10 · Results navigation and payout.** Use all four directions to move between result actions/difficulty. “Hatch eggs” should open the general egg store. A qualifying zero-goal loss (score at least 100, at least 3 merges and 6 drops) earns +1 Star; an idle/instant loss should not. Check that wallet change and result text agree.
- [ ] **11 · Help and daily stamps.** Read Hatch eggs and Companions help through the last card. No clipped words/giant illustrations hiding text. Hearts should be explained as bond that unlocks tricks. The daily stamp should be discoverable in Quests; it tracks played days, not eggs opened. Try the stamp once and confirm it cannot be claimed twice that day.
- [ ] **12 · Focus controls.** Focus/pet Bear: Back, bond/heart card and Pickup should have consistent height and safe gaps; the bond card belongs left of Pickup. Test Pickup and Back on phone without another control blocking them.
- [ ] **13 · Preview loading and edges.** Visit Hatch eggs, Companions, toys, faceplates and backgrounds. No gray/untextured flash masquerading as a completed preview; corners remain rounded and borders intact. Scroll to the first/last entries and open/close quickly. No cropped faces/items or square spill outside the wells.
- [ ] **14 · Prices and insufficient Stars.** At low balance, Buy/Hatch remains visible, styled and disabled. The shortfall must match the actual price, including the discounted weekly shelf. No missing/transparent purchase button and no debit from disabled input. Check a normal affordable purchase later as well.
- [ ] **15 · Notification placement.** Trigger care/item/unlock feedback with a menu open, on desktop and phone, with chat/topbar visible. Notifications should use one quiet rail clear of Roblox controls and remain above the menu. No center-screen pileup or overlap with wallet/phone controls.
- [ ] **16 · Menu personality and Moonpond.** Let the preview Bear idle: occasional small reactions should feel alive without constantly interrupting. Button sounds should be restrained. Preview/equip the new free Moonpond background; it should stay inside the display and not recolor the real case.

## 3. World and Pet Parks

- [ ] **17 · World appearance.** Walk the aqueduct/spring, colonnade, rotunda, bridge, station trim and both park approaches. Look while moving the camera for flickering/overlapping faces, new gaps, missing vegetation where it should remain, or changed colors.
- [ ] **18 · Walkability.** Walk the stairs, bridge edges and both park entrances. No invisible box walls, catching on steps, falls through visible floors or blocked approach to an activity. The collision export was repaired and tested; this pass checks how traversal actually feels.
- [ ] **19 · Both parks.** Visit the arrival park and the second grove across the garden. Activities should be reachable and independent; Bear should approach, play, finish and return normally. No long unexplained wait, clipping between participants, teleporting or permanent busy state.
- [ ] **20 · Fetch and Play date.** Try a shared fetch, including solo play. The daily Games counter means **completed activities**, not number of pets/players. It should show activity/saving truthfully, then move one step after completion. Complete 3 activities: the +4-Star daily completion pays once. Leaving halfway should not count an unfinished activity.

## 4. Lucky Jelly finish

- [ ] **21 · Appearance.** Look at Jelly on Bear in a menu and in the garden, facing front/back/side, near water and contrasting scenery. Check the one-color and two-tone look. Is it visibly semi-transparent and appealing? Eyes/mouth/accessories must remain readable and opaque. No water stripe slicing through the head, vanishing face, or confusing inside-out limbs.
- [ ] **22 · Offer and receipt.** Material Egg costs **16 Stars**. For a random offer with none of these finishes owned: **Gloss 45% / Jelly 10% / Matte 45%**. Already-owned outcomes disappear and the remaining chances change. Restricted/unknown-policy offers show the exact next fixed outcome instead. Confirm the receipt and equipped result match; do not spend repeatedly just to force Jelly for visual QA.

We can stage Jelly and the necessary balances as a **temporary Studio-only QA fixture** for these checks; no Robux purchase or grinding is required. A fixture is not proof of real acquisition/persistence. [Phone Material Egg offer](jelly-native/native-final-phone-material-odds.jpg); [appearance and native-world review](JELLY-NATIVE-REVIEW.md).

## 5. Music and mix

- [ ] **23 · Garden tune and timbre.** Review the new melodic audition when delivered. More tune/continuity than v3; softer, transformed rubber/bubble sounds blended into the music. Does it retain the quirky garden feeling without becoming foreground MIDI or a string of obvious sound-effect samples? Listen on headphones and phone speakers.
- [ ] **24 · Deck and transitions.** Compare the Deck arrangement with the garden. They should feel related but distinct. Enter/leave a round, hatch, open menus and use music/SFX controls. No overlapping music owners, abrupt volume jumps or a hatch fighting the background. Listen across the full loop seam once the chosen full version is built.

V3 is a **working build**, not accepted final music. Spencer's latest feedback: right direction, too sparse/not melodic enough, samples too distinct/raw. V4 is an audition until heard and reviewed; current uploaded masters remain unchanged during audition work.

[Garden v4 listening draft — 27 seconds](audio/revision-4-melodic/garden-melodic-audition-27s.mp3): connected original melody, softened recording-derived instrument and quiet harmony; no separate raw squeak/plop hits. [Files, mono/seam/diagnostic and measurements](audio/revision-4-melodic/README.md). This is a local audition, not the music currently playing in Studio. Deck adaptation waits for the garden voice/tune feedback.

## 6. Feature scope decisions, separate from game QA

- [ ] **25 · Names Egg proposal.** Is this the naming game you want: one or two collectible pieces such as “Biscuit Bureau”, “Almost Tuesday”, “Marmalade Moonboots”; pieces can go in either slot, rename/swap freely, no ordinary-person-name generator? Proposed 4 free starters + 20 unlockable pieces, 8-Star no-dupe egg. [Full proposal](../pet-social-scope-2026-11-14/NAMES-EGG-SCOPE.md). **Not implemented and not a blocker to publishing the existing fixes.**
- [ ] **26 · Visitor pet proposal.** Approach/tap another real player's pet, inspect its public name/look/owner, optionally say Hello for a brief wave; owner can disable greetings. No foreign pickup/rub/feed/spend or rewards. [Full proposal](../pet-social-scope-2026-11-14/VISITOR-PET-SCOPE.md). **Not implemented; a separate v1 feature decision.**

Blip and every rejected alien design stay disabled and on the TODO. There is no alien design selection to make in this pass.

## 7. Release checks I own, and what needs another person/device

These are not extra visual design choices for Spencer to untangle.

- [ ] **27 · Physical devices and controls.** After an authorized private QA publish, play on a real iPhone and Android: touch/drag targets, text size, notches/topbar, loading, audio, low graphics, frame rate and heat during a longer session. Check the supported keyboard/gamepad and avatar configurations too. Emulator screenshots do not pass this item.
- [ ] **28 · Human balance and longer play.** Complete the new field objectives with ordinary inputs. Does earning Stars feel fair relative to egg/wardrobe prices? Check meaningful loss rewards, quest/stamp pacing, time to a desired cosmetic, and whether repeated rounds/garden play stay enjoyable. Solver/test completions do not answer those questions.
- [ ] **29 · Real multiplayer and load.** Two accounts first: visitor appearance, shared toys/parks, carry/care/bay contention, leaving/rejoining during an action. Then a 6–8-player session for sustained frame rate, sound clutter, busy stations and stuck reservations; verify the intended 12-player server configuration separately. Names/visitor Hello are not present in this build.
- [ ] **30 · Public listing and promises.** Review the final title, icon, thumbnails, description and supported devices after captures are refreshed for the current hatch/results/odds. Existing [listing kit](../store-listing/LISTING.md) is a draft with older captures, not final launch approval. Complete the actual Creator Hub maturity/content questions against the shipped features. Resolve optional future bundles/private-server/Premium scope before advertising it. Current in-game Supporter/Starter copy promises Stars; old TODO shell/charm promises are separate unfinished scope, not implemented perks.

- **Before the next authorized private publish:** finish music choice/integration if changed; review/fix any failures above; rerun affected tests/builds; verify clean runtime source, correct place, native physics, and absence of debug overlays/QA grants. Regenerate localization into the dedicated review output and sync cloud strings at publish time. Record exact build/revision/evidence. Do not spend real currency or submit a fake bug report to test storage.
- **Actual physical device and two-account pass:** Private v685 is available now for physical-phone, real-account/rejoin and published-service observations. Studio coverage remains separate from those results. This authorized private QA publish is separate from public launch; public release is still held.
- **After that private QA publish, before public launch:** two real accounts verify the existing visitor appearance, both parks/shared actions and no stuck reservations on owner leave/rejoin. Check save/rejoin for purchases/equipment/stamps, current and historical receipt recovery, slow loading, real phone touch/safe areas/audio, bug-report persistence using a clearly identified test only if authorized, and actual Creator Analytics delivery. Sweep all reachable SFX, coos and ambience plus Purr, not just the new music/hatch cues. Check translated text on a long-string locale. Studio fixtures cannot certify these services.
- **Before public launch:** set the fresh-save test flag off so a future update cannot reset progress; verify the intended launch save namespace is actually the intended starting state. Turning the flag off selects `EggDropLaunchV1`; it does not empty older records, and no destructive wipe is authorized. Confirm Park/features, intended audience/access and 12-player server setting. Check all **2 passes + 5 products**, Dashboard/source price and description agreement, paid-random restrictions and receipt/retry behavior using appropriate authorized test flows. Reconcile remaining v1 scope (Names/visitor Hello if desired for v1). Plan a coherent rollout/drain of older game servers so report/material/save writers run the intended build. Publish only after explicit authorization.

[Read-only release-gate audit](RELEASE-GATES-AUDIT.md) records the source evidence and distinguishes active requirements from obsolete TODO notes.

Platform references checked November 14: [Roblox paid-random disclosures and per-user treatment](https://create.roblox.com/docs/production/monetization/paid-random-items), [Roblox publishing and public release guidance](https://create.roblox.com/docs/production/publishing/publish-games-and-places). The actual Creator Hub/account setup must still be checked; this packet does not certify it.

Already verified by the implementation team: 56 server + 36 client suite histories green, 23 collision/upload pipeline tests, 301 runtime files matching Studio, 498 compiling script containers, 20,920 matching fresh-build collision rays, and an actual first-toy Give/play. These support the checks; they do not replace your taste, physical-device or real-service QA.
