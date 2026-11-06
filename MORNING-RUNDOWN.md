# Egg Drop — morning handoff, November 6, 2026

Private **version41** is Published in place96451847774961, verified in Studio Version History. Implementation `f021041` and the preceding reviewed work are pushed on `feat/egg-drop-arcade-polish`. The checkout is in `C:/Users/skunk/Documents/Development/egg-drop`; Studio is Edit, connected to egg-drop Rojo34873. The unrelated suica project was not modified.

Play: https://www.roblox.com/games/96451847774961/Egg-Drop

This is a playable prototype with a complete earn/hatch/companion loop. Physical-device comfort, live persistence/multiplayer, voluntary replay and retention still need testing. It is not a production-ready commercial v1.

## What the player does

A new player opens on the merge board. Matching pieces fills the short welcome charge and hatches guaranteed **Pip**. A small aim/merge guide leads into the first field quest. Returning players who own Pip open in Sprout Hollow.

Each field gives **24 drops**. Merge tierIII or higher in the highlighted **left** bank, then the **right**. The next drop unlocks on first contact, with a stuck-state fallback. Cascades get four seconds after the last drop. Pressure above the danger line matters after drop12, with2.4seconds to recover; an earlier sustained spawn jam can also end a run.

A completed quest earns **6 nectar**, or **8** for a low pile. A failed quest earns no base nectar, but a full24-drop round can still earn daily skill-contract rewards. The recap names each reward, the played family's next mastery goal, score/best, chain and tierV clears. **Try again** is quick; **Hatch eggs** spends the bank. Score/chains support skill contracts, mastery challenges, trials and personal best; they are not a second spendable currency.

Hatches are random, committed before the reveal. The shell swells/cracks/splits into the 3D pet with original synth cues. Choose **Meet [pet]** to acknowledge/equip/greet, or **Play again** to resume play. Close keeps the committed result available. Intended rejoin behavior preserves that result; isolated recovery fixtures verify this, while a live account reconnect remains untested.

## Eggs and all seven pets

Mixed Meadow costs **18 nectar**. Sprout Focused costs **24** and rolls Pip80% / Bloom Pip20%. After seven non-rares, the next hatch guarantees a rare; it does not guarantee a missing species.

| Pet | 3D appearance | Meadow odds |
|---|---|---:|
| Pip | Cream sprout chick, leaf crown, cracked shell and little green slippers |35%|
| Puddle | Rounded aqua creature with fins/flippers |25%|
| Wick | Coral little flame creature with a golden flame/core |20%|
| Orbit | Lavender creature encircled by an orbit ring and small moon |10%|
| Bloom Pip | Peach Pip variant with a flower above its sprout |5%|
| Foxfire Wick | Blue Wick variant with twin aqua foxfire flames |3%|
| Eclipse Orbit | Deep violet Orbit variant with golden ring/halo accents |2%|

Pip, Puddle, Wick and Orbit are the four mastery families; rares share their base family's track. Wins earn1 mark, clean wins2 total, duplicates1. Ranks **I/II/III need3/10/25 marks**; III also requires successful clean, chain3 and score500 challenges. Rewards are family crests, an outline finish and bounded flourishes. Legacy duplicate sparkles remain separate. Reduced effects retains static identity and disables bursts.

## Returning tomorrow and visiting the lounge

Daily contracts auto-credit once per Hollow day: **finish2 quests +4**, **chain3 +3**, **score500 +3**. There is also a **6-nectar daily gift**; welcome day cannot claim it twice. Hollow uses fixed UTC−5 and a real24-hour lighting cycle. There is no play/drop cap, paid luck, paid egg or paid currency.

The larger lounge has orchard paths, creek/bridges, deck workbench and Field journal. The companion follows position and heading smoothly. Click it or use E/X/touch prompt to greet; the menu hides, the full pet is framed, and movement/timeout returns to roaming. Reachable stations take shortcut priority. The journal equips owned pets and opens Family goals. Leaving for the lounge pauses the board; returning resumes that round. Rejoining intentionally restarts an unfinished field.

The horizontal handheld has lower arrows/A and Menu/Lounge controls. Style & sound changes shells/stickers; Club holds SFX Full/Quiet/Off and reduced motion. Seventeen original synthesized sound cues are wired. **A finished background-music loop is not shipped.** The nursery remains deferred. Pets currently provide companionship/collection/prestige; they do not add paid power or production income.

## What changed overnight

First-field coaching; exact-ID Meet/Play acknowledgment and cancellation; authoritative itemized recaps and next mastery requirements; useful journal route and family crests; complete greeting framing with sign/bench avoidance and reliable camera restoration; shared-store save recovery and flush-before-unlock; compact controls/shop fixes. At568×160, the tray grew from16×27 to76×128, both egg recipes remain44px tall, and the24-drop strip no longer shrinks with repeated HUD updates. Recipe name/cost stays pinned after reopening.

## Evidence and limits

| Slice | Final native evidence |
|---|---|
| Greetings |35 geometry/lifetime +3 interaction +21 transaction +2 close =61 cases;72 projections across7 models; actual greetings/movement/board return|
| Save recovery |11 new shared-store/entry/default-adapter + existing UI/transaction/close =86 cases; simulated stale reads, delayed writes, pending reveal and duplicate close|
| Compact UI |10 deck +8 shop +17 hatch +7 onboarding +10 navigation +10 recap +21 transaction +2 close =85 cases; actual resized-component mouse inputs|
| Build |55 source containers compile (53 production plus2 legacy); final changed sources match checkout; Rojo builds; Edit publish tree is fixture-free|

These totals overlap; do not add them into one unique-test count. Reports are `scripts/GreetingCamera-results.json`, `SessionRecovery-results.json` and `CompactControls-results.json`, with prior slice details in `OVERNIGHT-EXPERIENCE.md`.

An actual developer-authored24-drop mouse run scored630/chain4, earned8 base+6 daily (bank6→20), bought Meadow once, hatched Wick and met it with bank2. Other overnight runs met Foxfire Wick and exercised replay/receipt fences. Solver seeds64001–64030: deliberate29/30 wins, fast random16/30, center0/30; deliberate nectar/minute1.86× fast random. Solver results and operator walkthroughs do not establish human fun or understanding.

Remaining checks: physical phone/touch/controller comfort; real private-server disconnect/rejoin; shared multiplayer visibility; genuine first-time comprehension and voluntary replay. Minimum compact scrolling still needs human feedback. Bright sun bloom needs art tuning. Existing EditableImage fallback and external asset203785492 warnings remain; no security settings were enabled to bypass them. Expected failure-injection warnings are distinct from ordinary-play errors. No final runtime Luau error was observed in ordinary play.

## Your next playtest

Open the private link while signed into the authorized Roblox account. On phone, use landscape. On desktop, arrows/A-D aim and Space drops; the on-screen A works too. Earn Pip if new, complete or retry one field, read the recap and egg odds, hatch, Meet, roam, greet and visit the journal. Try one shell/sticker and SFX setting. Then leave/rejoin and compare nectar, ownership, companion, settings and any unacknowledged reveal. Finally try a second player.

The most valuable feedback is where the goal is unclear, whether aiming feels worth doing, whether the first egg feels earned, and whether you choose another round without prompting. After that evidence, tune progression and decide the next content/social purpose for pets; monetization is still future design work.
