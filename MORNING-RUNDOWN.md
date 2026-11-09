# Egg Drop — November 9 morning build

**Private v297 Published · runtime 2e9da43 · feat/egg-drop-arcade-polish.** The reviewed code is committed and pushed. Refreshed Studio Version History confirms “Aero babies and shared garden - 2e9da43.” Only the existing private Egg Drop place was updated; access and account settings are unchanged.

[Play the private game](https://www.roblox.com/games/96451847774961/Egg-Drop) · [Publication proof](artifacts/aero-garden-2026-11-09/private-published-v297-2e9da43.png) · [Full gallery and films](artifacts/aero-garden-2026-11-09/GALLERY.md) · [Exact test evidence](artifacts/aero-garden-2026-11-09/TEST-INDEX.md) · [Remaining work](TODO.md)

## What shipped

The item-egg build and the follow-on garden pass are both in the private game. Astra directed the original assets and reviewed the actual models, night views, gait and shared-play film. Sol 6.1 High implemented the systems; fixes passed independent source review before publication.

- **All seven babies have authored models.** Zivvi and Ovelle keep their existing baby forms. Tikket, Nuum, Vezzi, Kiprik and Nolli replace the five legacy forms, with new portraits, neutral base coats, expressive face pieces, planted steps and loosely bouncing charms. Existing ownership and pigment remain attached to the same permanent pet identities.
- **The garden has purposeful activity spaces:** a supported creek crossing, curved rest nook and a low glass-accented ball-return gate on the clear bench apron. Nearby scenery moves within a fixed update budget; day/night and warm lantern lighting remain. The main floor is still 160 × 128 studs: this is a more usable and lively layout, not a larger map footprint.
- **Two pets can return a ball together.** Walk near the gate with your pet and use Start; another nearby player can Join during the three-second window. Pets approach, face one another, play a five-second exchange and resume their normal behavior. A solo return also works. This activity grants no Stars, items or stats.
- **Dot, Ring and Pebble charms are free options.** Journal → the pet’s Customize icon → Charm. Hide/show is saved per pet; a hidden charm stays hidden when its shape changes. Charm color follows Secondary pigment. The old client’s visibility requests preserve newer shapes.
- **Hatching is more saturated and animated:** a cobalt/lagoon stage, patterned shell split and bounded droplets/prisms. The receipt and save rules remain authoritative. Short-landscape pet focus now keeps its helper above the face and feet.
- **Care rewards work through sustained contact.** Hold/rub the focused pet, or hold the supported keyboard contact control. The pet reacts; valid continued contact can earn +1 Star, capped at five care Stars per Hollow day. Back exits the held pet view. Simply opening focus grants nothing.

These are Blender design renders of the five new bodies; the gallery also has the actual uploaded Roblox models and measured night views.

![Five new original baby designs](C:/Users/skunk/Documents/Development/egg-drop/assets/garden-babies/new-five-2026-11-09/five-babies-gallery.png)

## The player loop and rewards

1. New players aim and merge on the welcome board for guaranteed **Zivvi and 6 Stars**. Returning accounts keep their existing collection and purchases.
2. Play unlimited **24-drop rounds**. Bank Pair, Creek Crossing and Lantern Chain rotate. Use the center launch angle and read the active goal; later goals require different merge locations or a continued chain. Complete both goals for **6 Stars**, or **8** with the low-pile bonus. Failed rounds can still finish eligible skill contracts. Score and chain support those goals and personal bests; they are not separate spendable currencies.
3. Spend earned Stars in the single Hatch eggs grid: **Companion Egg 18**, **Hue Egg 8**. The hatch tree opens the same shop without buying anything. Journal and deck-style stations retain fast menu shortcuts.
4. Companion odds are **Zivvi 35%, Ovelle 25%, Tikket 20%, Nuum 10%, Vezzi 5%, Kiprik 3%, Nolli 2%**. After seven consecutive common outcomes, the next roll is rare-only at 50/30/20. A duplicate companion says Already owned and grants nothing.
5. Hue Eggs grant a saved **Rose, Tide, Citrus, Iris or Reset jar**, each at 20%. Store it or use it immediately. Jars stack; closing or reopening never rerolls the result. Journal → Customize → Hue selects the pet and Main/Secondary channel. Each hue has five dose notches; repeated doses deepen it, different hues mix, and a Reset jar clears only the selected channel. Every use asks for confirmation.
6. The optional daily gift is **6 Stars**. Contracts are **Win 2 rounds +4, Chain 3 merges +3, Score 500 +3** under their completed-round rules. The Hollow day rolls at **05:00 UTC**. Family mastery/prestige is frozen: no new ranks, marks or overhead level badges. Earned deck cosmetics remain, including Honey at one saved win, Gloaming at three, and Copperleaf/Lantern background at ten.

No paid luck, daily play cap, new currency, nursery or public release was added. Clothing/stat eggs, battles and further minigames remain future scope.

## What was tested

- **123 of 123 runtime sources** exactly matched native Studio and compiled without errors; the Rojo build passed. Seven templates contain **122 validated uploaded mesh resources**.
- **172 server cases across 19 suites; 292 client cases across 36 suites.** These are unique latest per-suite results, not inflated counts from repeated preferences, frames or reruns. The original 197-case client matrix was checked at actual Medium/Largest; later targeted cases extend the union. Not every later case was rerun at both preferences.
- Ordinary tutorial drops earned Zivvi and opened the new hatch/Meet path. A separate 30-second contact hold produced **two Saved care-Star receipts**, without injecting a reward.
- Actual Humanoid walks crossed the creek both ways with the follower. A separate approach showed the nook’s six-second rest and automatic return.
- **Actual local two-client Start/Join action 322** showed the ball passing both directions; both owners stayed at six Stars with unchanged hue stock, inventory and profile revision. Separate ordinary controls saved Pebble → Hide → Ring while hidden → Show; the visitor observed the same appearance pair.
- Actual **iPhone 13 landscape emulation, Largest text, 749 × 389 effective viewport**, passed the focused-pet visual review. It is not a physical phone test.
- A controlled seven-rig comparison used the same current world and measured light. Median round p95 rig CPU changed **1.3901 → 1.1926 ms by day** and **1.3280 → 1.2820 ms at midnight**. Overall frame time stayed near 17.8 ms. This isolates synthetic rig rendering; it is not a full historical-place benchmark or phone performance claim.

![Actual two-client return contact sheet](C:/Users/skunk/Documents/Development/egg-drop/artifacts/aero-garden-2026-11-09/actual-relocated-two-pet-return-contact.jpg)

[Watch the actual return](C:/Users/skunk/Documents/Development/egg-drop/artifacts/aero-garden-2026-11-09/actual-relocated-two-pet-return.mp4).

## New original music drafts

The currently liked in-game music stays the default. These two original local drafts are ready to audition; they have not been uploaded or substituted into the game. Deterministic loop/seam, mono and loudness checks passed; subjective listening is still yours to judge.

**Creek With One Shoe** — quirky garden cue, 92 BPM, 62.61-second loop:

![Creek With One Shoe](C:/Users/skunk/Documents/Development/egg-drop/assets/concepts/music/overnight-aero-2026-11-09/creek-with-one-shoe.mp3)

**Pocket Skip** — brighter handheld cue, 120 BPM, 48-second loop:

![Pocket Skip](C:/Users/skunk/Documents/Development/egg-drop/assets/concepts/music/overnight-aero-2026-11-09/pocket-skip.mp3)

## What to try in the morning

Play a round, hatch/store a Hue jar, apply it to Main and inspect Secondary separately. Choose Ring or Pebble, hide/show it, then leave and rejoin to check the same appearance and inventory. Walk both bridge directions, approach the nook, and try the toy with another player. Pet a baby for around 30 seconds and judge the reaction, sound and Star feedback. On your phone, check the lowest controls, scrolling and focus framing. Tell me which movements, materials or screens still feel wrong and which music draft you prefer.

**Open limitations:** the standalone Roblox Player here is signed out. The authenticated browser’s Play attempt reached a download fallback and did not launch a live game, so no fresh service-backed save/rejoin result is claimed. Sign in to Roblox Player when convenient for that check. Physical phone, service-scale multiplayer/latency and longer human fun/pacing tests remain open. Night faces and silhouettes are readable but flatter than noon; the proposed .60 brightness trial target was not met. One tool-assisted camera obstruction remains unattributed; a clean ordinary-input fresh-spawn Meet was clear. Known Studio warnings about inaccessible EditableImage and an old asset-type mismatch remain; no security setting was changed.

Studio was left in Edit with production entries enabled, temporary QA objects removed, normal desktop emulation and the original Medium text preference restored. The overnight automation runs only through 9 AM Eastern, then starts no new changes. This build is a tested private prototype; it is not a production-readiness or retention claim.
