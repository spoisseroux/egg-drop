# Pocket Pals: Pet Garden. Roblox listing kit (v1 public launch)

Rewritten 17 November 2026 for v1 (source at `d7e5c3f`, private v859 published, v865 saved in Studio). It replaces the 13 and 15 November "Egg Drop" kit. Nothing here is published or uploaded. Universe **10774758591**, start place **96451847774961**. The repo, DataStore keys and folder names stay "Egg Drop".

**Everything already in `icon/`, `thumbnails/` and `raw/` is outdated.** Recapture from the shot plans in sections 6 and 7 before uploading anything.

## 1. Name

| Field | Text | Chars | Limit |
|---|---|---:|---|
| **Experience name** | **Pocket Pals: Pet Garden** | 23 | 50 (Studio's Basic Info counter; not in Roblox's docs, so check the counter) |
| In-game and icon wordmark | Pocket Pals | 11 | |

No "[NEW]", "UPDATE", emoji or hype words.

## 2. Hook (first line, 155 characters)

Roblox says the first ~160 characters show in search snippets and on mobile before the description expands.

> Pocket Pals is a cozy merge game with a pet to look after. Merge balls on your Pocket Deck to earn Stars, then spoil your plush Bear in a garden you share.

Short line for ads and social posts (71 characters): *Merge balls on your Pocket Deck, earn Stars, and spoil your plush Bear.*

## 3. Description (942 characters, limit 1,000)

Roblox's descriptions page gives a 1,000-character count. A DevForum report says some fields cut text past ~980, so this stays under 950. Recount after any edit.

```
Pocket Pals is a cozy merge game with a pet to look after. Merge balls on your Pocket Deck to earn Stars, then spoil your plush Bear in a garden you share.

HOW IT PLAYS
• Pocket Deck: drop balls and merge two of a kind into a bigger one. Finish the goals to win. Easy, Medium or Hard.
• Rounds, daily and weekly quests and a daily stamp all pay Stars.
• Your Bear follows you, reacts when you pet it, and learns tricks as your bond grows.
• Toy Egg: one of 6 toys your Bear plays with. Customization Egg: colour and material jars, and now and then a rare charm.
• Hats, collars, deck faceplates and ball themes at fixed Star prices.
• Pet Park: pets play together on the slide, swings and seesaw. Say hello to other players' pets.
• Fill the collection book as you go.

FAIR PLAY
• Every egg shows its odds before you hatch it.
• Optional Robux Star packs and passes only add Stars. Nothing you buy changes how the board plays.
• No trading.
```

**Check before pasting:**
- **Spelling:** "cozy" is US spelling, because that is what players search. "Colour" matches the in-game text (UICopy). Pick one style if the mix bothers you.
- **Bond levels:** the brief says 1 to 5, but `BondCatalog.MaxLevelShipped` is **10** in source (levels 6 to 10 were added 14 November). The copy says "learns tricks as your bond grows" with no number, so it is right either way.
- **Passes:** the 2× Stars pass (299 R$) and Star packs speed up earning, and Stars buy eggs. So don't write "no paid advantage". The draft says only what is true. Round items (Swap, Pop, Bomb, Magnet) drop in the round and are never sold.
- **Supporter:** the pass gives +1 Star per finished round. The Supporter deck shell and charm in TODO are not built, so don't mention them.
- **Not in v1, so left out:** Blip or any second pet, the Names Egg, cartridges, the Material Egg (off), the Feature Egg (`Features=false`), the Hue Egg (replaced), and the weekly shelf discount (no "% off" claims).
- **Restricted accounts:** players under `ArePaidRandomItemsRestricted` see a fixed next item, not odds. "Shows its odds" holds for everyone who gets a random roll.
- No controls in the description. Roblox's guidance says to teach them in game.

## 4. Genre and keywords

The genre can be changed **once every three months**.

| | Pick | Why |
|---|---|---|
| **Genre › subgenre** | **Puzzle › Match & Merge** | Roblox sorts by the core loop. Rounds are where all Stars come from, and Match & Merge is a smaller, closer-fitting shelf. |
| Alternative | Roleplay & avatar sim › Pet Care | Choose this if early analytics show sessions are mostly garden and park. The name already carries "Pet Garden", so pet searchers still find the game. |

**Keywords** (Roblox doesn't rank tags or hashtags, so keep them out of the description; use them for ad targeting and update notes): merge, merge game, ball merge, drop and merge, puzzle, pocket, handheld, pet, cute pet, plush, teddy bear, bear, pet care, pet park, garden, cozy, dress up, hatch, egg, toys, collection, chill, all ages.

## 5. Icon brief (512 × 512) — new concept

**All 11 files in `icon/` are outdated.** They show the old held pose from before the v850 garden grip, the Pom Beanie over the wordmark, and the hatch light from before R5. Don't upload them.

**Concept, "Bear and its deck":** the plush Bear fills about 70% of the frame in a three-quarter front view. It holds its **Pocket Deck toy** in the two-paw hold, tilted so the green shell and A button face the camera. Behind it is a soft warm cream-peach background (the reveal card colour from v850) with a slightly blurred garden. Large shapes only: Bear head, deck, two paws. At about 150 px it should read as "a bear holding a little game".

**Variants for A/B testing** (Roblox shows one icon per locale; swap it by hand and compare click-through in Analytics):
- **A (lead):** no text.
- **B:** "POCKET PALS" in Builder Extended Bold with a cream fill and ink outline, along the bottom 20% and clear of the deck.
- **C:** the same as A with a Rose hue jar applied (a 17% outcome, common enough to be fair).

**Shot plan (coordinator, Studio Play, nothing saved):**
1. Use a fresh test save. Fund it with `EggDropStoreTestGrant` (Studio only). Hatch Toy Eggs until the Pocket Deck toy comes out, then **Give to Bear**. Leave the Bear **unhued** (what new players see), with no wardrobe items.
2. Hide every ScreenGui, the player avatar and nameplates. Use `Lighting` as published (DayNight=false, dusk). Add a temporary `DepthOfFieldEffect` (FocusDistance on the Bear, InFocusRadius ~4, FarIntensity ~0.6).
3. Scripted camera: FOV 30, 6–8 studs from the Bear, lens at the Bear's chest height and pitched up 5°. Turn the Bear 25–30° off camera.
4. Wait for the idle hold pose, not a play beat. Capture at least 1080 px tall, crop a centred square, and downscale to 512 (and 1024 as a spare) with Lanczos.
5. Check at 150 × 150 next to three Pet Care top icons. If the white Bear sinks into the cream background, darken it toward peach (`#F2C9A8`) or lift the rim light. Don't recolour the Bear.
6. Restore everything and stop Play.

No AI images. Only add the wordmark (variant B) on top of a real capture.

## 6. Thumbnails (1920 × 1080, up to 10) — new shot list

**Retire the whole current `thumbnails/` set.** These must not ship under any circumstances:

| Old file | Why |
|---|---|
| `09-hatch-odds.png` | Shows the **Material Egg** and **Hue Egg** (neither is sold in v1), the Toy Egg at 8 Stars, and 3 toys |
| `12-item-reveal.png` | Shows the **Jelly finish** from the Material Egg |
| `02-results-stars.png` | Staged numbers on an old results screen |
| `01`, `08`, `10` | The deck layout from before v834 (A/B, wings and controls panel all changed). `10` also shows Kittens before the monotone themes. |
| `03`, `11` | The old reveal light, the old held pose, and a capture fixture |
| `04`–`07` | 13 November captures. `04`'s caption is out of date, and wardrobe prices before the 40/100/250 ladder are unverified |
| `raw/results-tidy-win-WITH-CREATOR-PASSES.jpg` | Shows the creator's pass rows. Never use it. |

**Setup for every shot.** Studio Test, **Local Server**, 1 or 2 players. Local test players shouldn't own the passes; confirm there are no pass rows on results, otherwise stop and don't stage numbers. Device emulator: a custom **1920 × 1080 touch device**, so captures are native 16:9 and show the phone UI, not the keyboard hints. If the capture tool still returns letterboxed frames, crop to 16:9 and note the scale factor. Fund with `EggDropStoreTestGrant`. Put the caption pill in the **top third**, because player counts cover the bottom edge. Captions describe what is on screen only, with no claims. Keep each file under 3 MB (PNG or JPG). Don't save or publish the place.

| # | Caption | Exactly what shows | Camera / setup |
|---|---|---|---|
| 1 | Merge balls on your Pocket Deck | A Medium round on the v859 deck: a merge just landing (pop and score tick), chain ×3 or more, goals 1 of 2 ticked, Win pays visible. Default faceplate, Smileys balls. | Deck camera as the game sets it. Play 8–12 drops first, then capture on the merge frame. No tutorial or coach card on screen. |
| 2 | Your Bear, your pocket pal | The Bear in the garden holding its Pocket Deck toy (garden grip), the avatar beside it, and the dusk trees behind. | GUIs hidden. Scripted camera, FOV 40, 10 studs, at Bear height. Same staging as the icon (section 5). |
| 3 | A garden full of pets | Two players' Bears in the shared garden, one wearing a hat, the avatars walking toward the toy lawn. | **2 players.** GUIs hidden. A high three-quarter shot (FOV 50, about 25 studs back, 12 up) over the gazebo path. |
| 4 | Pets play together in the Pet Park | Two Bears on the park equipment at once: one at the bottom of the slide, one on the swing or seesaw. The park chip "Pets playing 2/…" in the corner is fine. | **2 players**, both inside the park kerb. Wait for a paired activity. Wide shot, FOV 45, from the park entrance. |
| 5 | Odds shown before every hatch | Hatch eggs with **Toy Egg (20 Stars)** and **Customization Egg (12 Stars)** only, the Customization Egg selected, its odds table as the build shows it (hues 17% each, Gloss and Matte jars, Jelly jar 6%, 2% per missing charm) and the pity line. | Fresh save, so charms are still missing and the pity row shows. Hatch eggs open at full size. Capture **after** the Toy Egg odds fix (checklist, Policy). |
| 6 | Hatch toys for your Bear | A Toy Egg reveal: one toy (Wobble Top or Squeaky Carrot) on the warm cream reveal card with **Give to Bear** and **Store** buttons. | A live hatch from the Hatch eggs screen, not a fixture. Capture once the toy has settled. |
| 7 | Colours and materials | Customize with the Bear wearing the **Tide or Citrus** hue and the **Gloss** material, and the jar cards visible. | Hatch Customization Eggs until you have one hue and Gloss. **Don't show Jelly or a charm here.** They are rare outcomes (6% and 2%), and this flag comes from the brief. |
| 8 | Dress up at fixed Star prices | The Wardrobe Hat tab with an item previewed on the Bear and its price pill on the 40/100/250 ladder. | Wardrobe open. Preview only; buying isn't needed. |
| 9 | Style your deck | Deck style › Balls with a monotone theme previewed (Midnight or Deep Sea) and the price shown. | Deck style open from the Pocket menu. |
| 10 | Fill your collection book | A Book page partly filled (Toys or Wardrobe), with its page milestone visible. | Own 2–3 toys and one wardrobe item so the page isn't empty. |

**Order:** 1, 2, 4, 3, 5, 6, 7, 8, 9, 10. **Home-page personalization:** activate 1, 2, 4 and 3 (Roblox needs at least 2 and suggests 2 to 5).
**Alternate for slot 10:** the Bear doing a bond trick with its level-up toast ("Happy hop"). Stage the bond XP in Studio only.

**Video:** `VIDEO-SHOTLIST.md` predates v1. Its rules and setup still apply, but rebuild its shots from the table above. Roblox allows 3 uploads a month, rejected ones count, and no voice or lyrics are allowed.

## 7. Maturity and compliance questionnaire

Answer for the most mature content a player can meet, counting only content you made. Target: **Minimal**, which is open to Kids (5–8) and Select (9–15) once the extra requirements in section 8 are met. Take the full questionnaire, not "Content May Vary" (16+).

**Part 1, app type:** Game.

**Part 2, IARC:**

| Question | Answer | Basis |
|---|---|---|
| Violence, blood, fear, sexual content, language, controlled substances, crude humour | No | Balls merge, pets play. Chat is Roblox's own, filtered. |
| Gambling (real or simulated) | No | No wagering. Paid random items are declared under purchases instead. |
| **Users can buy digital goods** | **Yes** | Developer products (Star packs) and passes (2× Stars, Supporter) |
| **Purchases can include random items the buyer doesn't know in advance** | **Yes** | The **Toy Egg** (20 Stars) and **Customization Egg** (12 Stars) roll a random item. Stars can be bought with Robux, so both are **paid random items** under Roblox's policy. |
| Cash-convertible rewards or NFTs | No | Roblox doesn't support them. |
| Users interact or exchange content | Yes | Default Roblox text chat. No trading. |
| Blocking, reporting, chat moderation | Yes | Roblox's own |
| Interaction limited to invited friends | No, unless you turn private servers on (then Yes) | |
| Shares location | No | |

**Part 3, Roblox:** social hangout No; free-form creation No; sensitive issues No; cross-experience content No; generative AI interaction No; media sharing No; continuous media feed No.

**How the eggs meet the paid random items policy (verified in source):**

| Rule (paid random items page) | Toy Egg | Customization Egg |
|---|---|---|
| Every outcome with odds as a %, before purchase, summing to 100% | Equal odds over the toys you don't own yet (no duplicates). **Gap:** 6 toys show 17/17/17/17/16/16% (whole-percent rounding by `OddsText.list`). The policy allows rounding only to 4+ places past the first non-zero digit, with a "may not total 100%" note. **Show 16.67% (and 33.33% with 3 left) plus the note.** | Exact integer table that sums to 100: hues 17% each, Gloss/Matte 10–13%, Jelly 6%, 2% per missing charm. Compliant. |
| Update odds as the remaining outcomes change | Yes (the pool shrinks as you collect) | Yes (charm rows only for missing charms) |
| Explain pity before purchase and update odds while it's active | n/a | Explained: "If 14 eggs pass without a charm, the next one is a charm", plus a countdown row. **Gap:** on the pity egg the rows still show 2% per charm. Show the guaranteed split (100% ÷ missing charms) on that egg. |
| `ArePaidRandomItemsRestricted` | Fixed next toy in a published order (`ToyCatalog.PaidOrder`), shown before purchase | Fixed order (`fixedNext`): the jar held fewest, with a charm on every 12th egg, shown before purchase |
| Star packs for restricted players | Hidden. `PaidRandomPolicy` fails closed if PolicyService doesn't answer. | Same |
| Trading of outcomes | No trading in the game | Same |

Resubmit the questionnaire whenever an update changes any answer, for example a new egg, trading or voice.

## 8. Creator Hub steps for Spencer (in order)

**Spencer** = only he can do it (his account, consent, terms or moderation). **Coordinator** = can do it through Open Cloud with an API key and Spencer's explicit go-ahead for that call.

| # | Step | Who |
|---|---|---|
| 1 | Finish the launch checklist (section 9) and publish the launch build | Coordinator (with Spencer's go) |
| 2 | **Maturity and compliance questionnaire** (section 7) | **Spencer** |
| 3 | **Name and description:** Configure › Basic info, or Studio Experience Settings › Basic Info | Spencer, or coordinator (see note) |
| 4 | **Genre and subgenre** (section 4; locked for 3 months) | **Spencer** (Creator Hub only, as far as I could find) |
| 5 | **Icon upload** (Places › start place › Icon; goes through moderation) | **Spencer** |
| 6 | **Thumbnails upload**, in order; activate 2 to 5 | **Spencer** |
| 7 | Video (optional; 3 a month) | **Spencer** |
| 8 | Max players **12** | Coordinator: Place `serverSize`, scope `universe.place:write` |
| 9 | Devices: Computer, Phone and Tablet on; Console and VR off | Coordinator: Universe `desktopEnabled`/`mobileEnabled`/`tabletEnabled`/`consoleEnabled`/`vrEnabled`, scope `universe:write` |
| 10 | Voice chat off; text chat default | Coordinator: `voiceChatEnabled=false` |
| 11 | Private servers: off (the simplest questionnaire answer) | Coordinator: a `privateServerPriceRobux` mask clears it (the docs say this closes active private servers) |
| 12 | Localization: auto-translate on; translate the name and description | Coordinator for the strings table (the `sync_localization.py` flow); **Spencer** for any toggle that needs terms |
| 13 | **Managed Pricing decision** (a one-time opt-in; regional prices 30–100% of base, automatic price tests) | **Spencer.** Before saying yes: the shop shows hard-coded prices (`StoreCatalog.price` → `StoreView`), and Roblox asks you to fix hard-coded prices first. So enabling it needs a code change to read live prices. Simplest for launch: leave it **off**. |
| 14 | Pass icons (passes still use the default image) | **Spencer** uploads; art is open work |
| 15 | **Audience › Public.** This is the launch. | **Spencer** |
| 16 | Kids and Select (optional, later) | **Spencer:** age-checked and verified account (ID if 18+), 2FA, a refundable per-game fee or 2+ consecutive months of Roblox Plus/Premium, then an evaluation (250 unique plays from highly engaged players in 60 days, plus a safety review). The live page didn't state the fee; the old kit's 1,000 R$ is unconfirmed. |

**Name and description through Open Cloud:** the v2 **Universe** resource's `displayName` and `description` **can't be set directly**. The docs say each is "updated by updating the root place's name/description". So the route is `PATCH /cloud/v2/universes/10774758591/places/96451847774961` with `displayName`/`description` and scope **`universe.place:write`**. The Place docs don't mark those fields read-only, but they don't explicitly confirm that a write works either. Test it once with Spencer's go, or have him paste them in Basic Info, which is safer. **Visibility** (`universe:write`) could technically go public by API, but going public stays Spencer's step.

## 9. Launch checklist

☐ = open. Reconciled with TODO.md's LAUNCH CHECKLIST lines and its "v1 public launch" section.

**Build and save**
- ☐ **`FeatureFlags.TestFreshSaves=false`**. It is `true` today, and while it is on every publish wipes progress and Robux purchases.
- ☐ Launch namespace: with the flag off the game uses `EggDropLaunchV1`. Confirm it is empty, or that its old test records are acceptable. No wipe is authorized.
- ☐ Confirm the flags: `Park=true`, `DayNight=false` (dusk), `Features=false`, `SecondPet=false`, `PseudoLocale=false`, `MaterialCatalog.EnablePurchases=false`, `LookEggCatalog.EnablePurchases=true`.
- ☐ **No ZZSpecs or test content ships.** `src/server/ZZSpecs` and `src/client/ZZSpecs` are in the Rojo tree (not ignored in `default.project.json`). Remove or exclude them from the launch place, along with the Studio spec copies, `ServerStorage.Baseplate_RetiredByGreybox`, any greybox and capture helpers. Test grants stay `IsStudio()`-gated; confirm that.
- ☐ **Close the `hueBuy` server path** (`HatchProgress.lua:657` still accepts it). First move HueProgress, HueClear, HueHost and RestrictedEggs off it. Keep `HueState` able to read old receipts.
- ☐ **Rollback floor:** the launch uses a fresh DataStore, so nothing rolls back below the launch build. Never roll the private place back past **v806** without first publishing `LookEggCatalog.EnablePurchases=false` (v775 and older servers reject `lookBuy`/`finishUse`/`finishClear` receipts).
- ☐ Shard the bug-report day keys (`day_<n>_<k>`) before public traffic.

**Policy**
- ☐ **Toy Egg odds precision:** 16.67% / 33.33% plus the "may not total 100%" note (section 7). **Blocker.**
- ☐ Customization Egg pity: show the guaranteed charm split on the pity egg.
- ☐ Questionnaire submitted with paid random items = Yes.

**Server and live tests** (published place, signed-in players)
- ☐ **12 players** per server.
- ☐ **Real-purchase test:** each pass and each Star pack once with real Robux. Starter can only be bought once. Stars land after a rejoin. Analytics events fire.
- ☐ **Second-account test:** shared garden, Pet Park pairing, Say hello, and a restricted-style check where possible.
- ☐ **Mobile-data test:** a real phone on cellular (not Wi-Fi). Check the deck feel with the ghost ball, joining, the first session through to the first hatch, heat and text size. iPhone and Android.
- ☐ Live save and rejoin, plus a toy test with two players.
- ☐ All SFX and music load in the published place.

**Listing**
- ☐ Name, description, genre, icon, thumbnails (new captures only), translations synced, then audience public, then soft launch. Watch D1 and D7.

## Sources (checked live 17 November 2026)

[Paid random items](https://create.roblox.com/docs/production/monetization/paid-random-items) (odds format, rounding, pity, restricted users) · [Randomized virtual items policy](https://create.roblox.com/docs/production/monetization/randomized-virtual-items-policy) · [Content maturity](https://create.roblox.com/docs/production/promotion/content-maturity) · [Kids and Select](https://create.roblox.com/docs/production/publishing/kids-and-select) · [Descriptions](https://create.roblox.com/docs/production/publishing/descriptions) · [Genres](https://create.roblox.com/docs/production/publishing/experience-genres) · [Thumbnails and videos](https://create.roblox.com/docs/production/publishing/thumbnails) · [Icons](https://create.roblox.com/docs/production/publishing/experience-icons) · [Managed Pricing](https://create.roblox.com/docs/production/monetization/managed-pricing) · [Open Cloud Universes](https://create.roblox.com/docs/cloud/reference/features/universes) · [Open Cloud Places](https://create.roblox.com/docs/cloud/reference/features/places).

**Not verified:** the 50-character name limit (only a third-party summary; use the field counter); the Kids and Select fee amount; whether a Place PATCH really renames the universe; whether genre can be set by API; whether the questionnaire wording in Creator Hub matches the docs exactly; and how "Minimal" is assigned until it is submitted. The docs pages show no last-updated dates.
