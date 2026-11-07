# Egg Drop — morning handoff, November 7, 2026

> Historical overnight checkpoint. The current private build is v125 Published (runtime f813d61); see [November7 afternoon rundown](AFTERNOON-RUNDOWN.md). The overnight automation remains finished.

**Private build updated:** Studio's refreshed Version History confirms **v93 Published**, titled **Pocket Deck and Hollow experience - 24751c2**. Runtime `24751c2` is committed and pushed on `feat/egg-drop-arcade-polish`. Astra approved the final source, fixtures and11 integrated Medium renders. The same existing private place was updated; no access or account setting changed. [Publication screenshot](artifacts/ui-redesign-2026-11-07/private-published-24751c2.png).

[Open the private game](https://www.roblox.com/games/96451847774961/Egg-Drop). The account must already have access. Roblox Player on this computer is signed out; no authentication or account settings were changed.

## What changed

The new reference-backed design uses a fern handheld, pale LCD and warm graphite menu surfaces. The tray owns the center, grips stop growing with monitor width, the LEFT/RIGHT banks have boundaries and labels, and the wallet, queue, quest and remaining drops have separate roles. The case backing changes with its finish.

Opening the deck has a short original power-on sequence. It cancels when another screen owns input and does not play over a recap/menu. The recap leads with the saved nectar reward, animates counters and the transfer toward the selected egg, then offers replay or eggs. Score/best/chain/clears and the receipt are secondary details. Reveal dismissal is a corner X.

The phone follow-up uses actual available body height. Landscape Menu shows all three illustrated destinations on entry; Mastery starts with the selected family's progress; both egg choices fit. Buttons keep their touch target even when the visible hardware is small. In cramped layouts, meaningful Falling/Settle/Save status temporarily uses the quest well, then restores its goal. The decorative DROP caption stays beside A or hides when it cannot fit.

Physical destinations now have a purpose: the tree browses eggs, the Field journal inspects/equips pets and opens family goals, and the workbench opens deck style. Menu shortcuts remain. Approaching a shop never spends currency. The shared native E/X/touch prompt respects menus and pet focus. A deck visit preserves the outgoing roam camera rather than returning through a tree.

Pet focus is held until **Back**. Greet can be repeated, and holding/rubbing the pet produces a reaction. The pet hint is outside the creature. Pets remain collection/companionship/prestige; they do not produce income or paid power.

Style now shows the actual finish silhouette, keeps a complete first choice visible on phone landscape, and pins X, tabs and Equip. Preview is reversible until Equip. Journal wraps long rare names, separates portrait and family crest, and keeps Family goals visible. Both lists signal additional content with a chevron that clears at the end. These changes passed85 actual-game cases at each of Medium and Largest,60 source wrapper compilations, Rojo build, and Astra source/native-render review. Emulator touch swipes reached the final Shell and Journal choices; Club end geometry was fixture-assisted. The original Medium text preference is restored.

Save problems now appear once inside the screen being used, with distinct truthful instructions for automatic retry, session waiting or rejoin. A neutral hatch state cannot hide a profile retry. Recovery keeps the same result and pet viewport. No transaction or reward rule changed.

Switching from a pointer to a controller in Menu, Style, Journal or the ordinary egg shop acquires a safe focus target. First unfocused A focuses; the next fresh A activates. Existing native selection is preserved. Roblox's own menu keeps priority. Held/dual-pad/disconnect/race coverage is simulated; native Studio virtual-controller checks corroborated ordinary navigation.

Welcome instructions now wrap at actual preferred text size and remove optional headings before losing the current lesson. They retain aim/drop controls, the exact matching marks, or the Pip goal. The clipped Largest desktop Space instruction is fixed without moving the tray or controls. A save retry temporarily replaces the lesson, and recovery restores the correct phase.

## What the player does

A new profile begins with a short merge welcome. Matching pieces fills **6 charge**, hatches guaranteed **Pip**, and awards the welcome **6 nectar**. Six charge does not mean six drops. Returning Pip owners start in Sprout Hollow.

A field round has **24 drops**. Aim equal pieces into the highlighted **LEFT** bank to make a tier III or higher merge, then do the same on **RIGHT**. The queue shows now/next; the dispenser shows drops remaining. Contact releases the next drop with a stuck-state fallback; the final cascade gets four seconds to settle.

Complete both sides for **6 nectar**, or **8 total** with a low pile. Failure gives no base nectar, although a completed full-budget run can still satisfy skill dailies. Pressure above the line becomes meaningful after drop12 and allows2.4seconds to recover; an early sustained spawn jam can also end a run. Try again is one action away.

**Nectar buys an egg hatch. Score and chains are skill records and challenge progress, not spendable currency.** The recap uses the saved wallet and never adds its receipt twice. Choose an egg, inspect its actual odds, and press the explicit hatch action. Its outcome is committed before the cinematic.

Meet acknowledges/equips the result and opens pet focus; Play again acknowledges and returns to play. X dismisses without acknowledging, so tree/Menu can reopen that same committed result without another debit or reroll. Isolated save/recovery tests cover this; live-account rejoin remains unverified.

## Eggs, pets and mastery

**Mixed Meadow:18 nectar. Sprout Focused:24 nectar, Pip80% / Bloom Pip20%.** After seven consecutive non-rares, the next hatch guarantees a rare. This does not guarantee a missing species.

| Pet | Appearance | Meadow |
| --- | --- | ---: |
| Pip | Cream sprout chick, leaf crown, cracked shell, green slippers |35%|
| Puddle | Rounded aqua companion with fins/flippers |25%|
| Wick | Coral flame creature with a golden core |20%|
| Orbit | Lavender companion with an orbit ring and small moon |10%|
| Bloom Pip | Peach Pip with a flower above its sprout |5%|
| Foxfire Wick | Blue Wick with twin aqua foxfire flames |3%|
| Eclipse Orbit | Deep violet Orbit with a golden halo |2%|

The four families are Pip, Puddle, Wick and Orbit; rares share their family's mastery. A win earns1 mark, a clean win2 total, a duplicate1. Ranks **I/II/III require3/10/25 marks**; rankIII also needs successful clean/chain3/score500 challenges. Rewards are a family crest, outline finish and bounded flourishes. Reduced effects keeps static identity.

Daily contracts auto-credit once per Hollow day: finish2 quests **+4**, chain3 **+3**, score500 **+3**. There is a **6-nectar daily gift**, with no duplicate welcome-day gift. Hollow uses a fixed UTC−5 clock and real24-hour lighting. There are no paid eggs/luck/currency or play caps. Nursery remains deferred. Seventeen original synthesized cues are wired; a finished background-music loop is not shipped.

## Why physical destinations

Publisher examples support familiar objects for familiar services: Adopt Me uses a Nursery egg machine; Pet Simulator99 combines physical machines with inventory shortcuts. Roblox supports native keyboard/controller/touch proximity interactions. For this compact loop, the appropriate decision is an optional walk to an existing landmark plus immediate recap/Menu access. It is not evidence that physical shops cause retention. [Research and implementation evidence](WORLD-INTERACTIONS.md) · [UI references and reusable rules](UI-DESIGN-SYSTEM.md).

These follow the specific conventions verified in [Adopt Me's egg release](https://www.playadopt.me/news/garden-egg-release-notes), [Pet Simulator99's physical Supercomputer](https://www.biggames.io/post/pet-simulator-99-update-6) and [later inventory access](https://www.biggames.io/post/pet-simulator-99-update-26). They establish examples, not Roblox-wide prevalence or a reason to add another room, currency or shop.

## Evidence and limits

| Checkpoint | Verified evidence |
| --- | --- |
| UI8b49b75 / privatev69 |214 actual-game client cases across21 suites at Medium;42 separate Largest cases;34 isolated server cases;59 source wrappers; Rojo; native24-drop→saved14→Meadow18→same-ID reopen→Meet journey |
| World92df51c |127 client cases across10 suites, including15 camera lifecycle cases;34 isolated server cases;60 source wrappers; Rojo; actual walks and E; injected ButtonX verified keycode routing; native-menu priority, same-ID purchase/reopen, emulated touch browse/pet/Back |
| Phone6da2865 |98 actual-game client cases across10 suites at Medium and the same98 at Largest;60 source wrappers; Rojo; actual Studio phone-emulator tabs/choices/rotation/A; Astra source and rendered GO |
| Style/Journal a623636 |85 client cases across9 suites at each of Medium/Largest;60 selected source wrappers; Rojo; actual emulator swipes, rare-name/crest layouts and camera/glove checks; Astra GO |
| Save feedback f6d1f4f |113 client checks at each of Medium/Largest;34 isolated server cases;61 selected source wrappers; Rojo; actual partial and successful rounds, one paid duplicate hatch, same-ID reopen/ack and client-only retry presentation; Astra GO |
| Controller566a655 |30 focused checks at each of Medium/Largest plus52 targeted Largest regressions; actual virtual-controller navigation;63 complete source hashes/wrappers; Rojo; Astra GO |
| Welcome24751c2 |56 checks across6 suites at each of Medium/Largest; four root cases each cover3 phases×3 input types; actual Largest Space/A/touch accepted drops and phase-correct save recovery;63 complete source hashes/wrappers; Rojo; Astra source/render GO |

These counts overlap across slices and preferences. Do not add them as unique tests. Corrected rendering tests run in real game LocalScripts with enabled ScreenGui hosts; earlier plugin-context Largest fixture passes were superseded. Older selected-wrapper counts omitted the trivial Shared registry root; the final63 checks include every repository source. Reports in `scripts/`: UIRedesign, WorldInteractions, EmulatorReflow, StyleJournal, SaveNotice, ControllerFocus and WelcomeCoaching `-results.json`. Detailed control/fixture distinctions are in [UI-OVERNIGHT.md](UI-OVERNIGHT.md).

The final24751c2 Studio walkthrough used actual controls: welcome Pip/6 nectar;24 drops, score640/chain4/both banks; quest6+daily6 saved wallet18; Meadow spent18 once for **new Wick**, bank0, sparse inventory5 (Pip+Wick), revision5. X→Menu→Eggs retained ID `8f32a231-9a02-48a0-8612-576158de1941`, wallet and revision. After the cinematic unlocked its actions, Meet acknowledged once (revision6), opened Wick in held Scriptable focus, and Back restored Custom camera and the character Humanoid subject. The aiming helper read board state to choose real drag/release inputs. This is an automated walkthrough, not an unaided human test. [Screenshots](artifacts/ui-redesign-2026-11-07/index.html).

Known console warnings: EditableImage unavailable and external asset203785492 type mismatch. No security setting was changed to bypass them. The latest ordinary-play console has no game runtime exception. Failure-injection warnings in server fixtures are expected.

**Still unproven:** physical-phone thumb comfort, physical controller, live multiplayer visibility, real private-server disconnect/rejoin, first-time comprehension, fun and voluntary replay. Automated aiming uses board state and cannot prove those. Reconnecting intentionally starts a fresh unfinished field; saved wallet/ownership/settings/pending hatch should persist.

## Your next playtest

Use the private link while signed into the authorized account. On phone use landscape. Desktop arrows/A-D aim; Space or on-screen A drops. Try one field, read its recap, hatch, Meet, Back, and walk to each station. Preview/cancel a finish, equip one, then leave/rejoin and compare wallet, collection, companion, settings and any unacknowledged hatch. Finally try a second player.

Where the goal becomes unclear and whether you voluntarily choose another round matter more than another automated solver run. Monetization and additional pet/social purpose remain future decisions after that evidence.

You can adjust simple button offsets and hardware dimensions yourself in `src/client/DeckLayout.lua` through its named `Layout.Settings`. Save in VS Code, let Egg Drop Rojo sync, then stop/start Play. Studio Play property edits are temporary. [Small UI editing guide](UI-EDITING.md).
