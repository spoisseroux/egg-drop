# Egg Drop: Roblox listing kit (v1 launch)

13 November 2026. Draft for Spencer to edit. Nothing here is published, and nothing in `src/` changed.

Every picture in this folder is a real Roblox Studio capture of the current build (Play mode, place 96451847774961) or is cropped from one. The only additions are a caption pill and an "EGG DROP" wordmark set in Roblox's own Fredoka One and Builder Extended fonts and the DeckKit palette. No AI images or video. To rebuild the art, run `python scripts/store_listing/build_store_listing_art.py`.

## 1. Name

The limit is 50 characters (the Studio and Creator Hub field counter is authoritative).

| Option | Characters | Note |
|---|---:|---|
| **Egg Drop** | 8 | Recommended. Short and searchable, and it matches the place name. |
| Egg Drop: Pocket Pets | 21 | Adds the pet hook for search. |
| Egg Drop 🐻 Merge & Pets | 22 | An emoji helps it stand out in lists. Check how it reads on console and in search first. |
| Egg Drop: Merge, Hatch, Dress Up | 32 | Lists the three verbs. Reads a little long on a phone tile. |

Don't add "[NEW]", "UPDATE" or hype words. Roblox treats them as clickbait and they go stale.

## 2. Hook (first ~160 characters)

Roblox shows about this much in search snippets and in the mobile app before "Read more". It is also the first line of the full description:

> Merge balls on a pocket handheld to earn Stars, then spend them on your own baby Bear in a cosy garden where it is always dusk.

(127 characters)

Shorter alternative for ads or social posts (85 characters):

> Merge balls on your Pocket Deck, earn Stars, and dress up your baby Bear in the garden.

## 3. Full description

953 characters, under the 1,000 limit. DevForum reports say text past about 980 characters can be cut, so recount after editing.

```
Merge balls on a pocket handheld to earn Stars, then spend them on your own baby Bear in a cosy garden where it is always dusk.

HOW IT PLAYS
• Pocket Deck: drop balls, merge two of a kind into a bigger one and build chains. Finish the round's goals to win Stars.
• Your Bear: meet it in your first few minutes. It follows you around the garden, reacts when you pet it and plays with its toys.
• Dress up: hats, collars and more from the Wardrobe at fixed Star prices.
• Pet Park: your pet heads for the slide, swings and sandbox. When other players are there, pets pair up and play together.
• Style your deck: faceplates, backgrounds and ball styles. Looks only.
• Daily and weekly quests, a stamp card and a collection book to fill.

FAIR PLAY
• Every egg shows its odds as percentages before you hatch it.
• Nothing you buy changes how the board plays. Optional Star packs and passes only add Stars.
• No trading.

Play on phone, tablet or computer.
```

**Honesty notes for Spencer** (check each line against the build you publish):

- "Cosmetics only, no paid advantage" is not quite true as written. The **2× Stars** pass (299 R$) and **Star packs** speed up earning Stars, and Stars buy eggs. The draft says what is true: nothing bought changes how the board plays, and purchases only add Stars. Don't write "no paid advantage" unless the passes change.
- The Supporter pass description in `StoreCatalog.lua` is "+1 Star for every finished round". TODO.md still promises a Supporter deck shell and charm, which have not been built. If those ship, the line "passes only add Stars" needs updating.
- "Always dusk" is true only while `FeatureFlags.DayNight=false`. If you turn the day/night cycle back on, change the hook.
- "Pets pair up" needs another player in the park. One player sees their own pet use the equipment alone.
- "Play on phone, tablet or computer" should match the devices you enable in Creator Hub. Gamepad focus exists in the UI, but console has not been tested, so I left it out.
- Don't list keyboard controls. Roblox's description guidance says to teach controls in game, and the deck already shows them.

## 4. Genre and subgenre

The genre can only be changed **once every three months**, so choose carefully.

| | Recommendation | Why |
|---|---|---|
| **Genre** | **Puzzle** | Roblox assigns genre by the core game loop, and the loop is the merge board. Rounds are where Stars come from. |
| **Subgenre** | **Match & Merge** | This is the exact mechanic. Players browsing merge games are the audience most likely to stay. |
| Alternative | Roleplay & avatar sim → Pet Care | Choose this if soft-launch data shows players spend most of their time in the garden and park instead of on the deck. It is a larger, more crowded browse category. |

Current Roblox genres for reference: Action, Adventure, Education, Entertainment, Obby & platformer, Party & casual, Puzzle (Escape Room, Match & Merge, Word), RPG, Roleplay & avatar sim (Animal Sim, Dress Up, Life, Morph Roleplay, Pet Care), Shooter, Shopping, Simulation, Social, Sports & racing, Strategy, Survival, Utility & other.

## 5. Keywords

Roblox does not use tags or hashtags for ranking, and they use up description characters, so keep them **out of the description**. The words below are already worked into the name, hook and body. Use them for Sponsored ads targeting or when writing update notes:

merge, merge game, ball merge, puzzle, pet, cute pet, baby bear, teddy bear, dress up, pet care, garden, cozy, handheld, pocket, hatch, egg, collection, playground, pet park, chill

## 6. Icon (512 × 512)

Roblox asks for a square image of at least 512 × 512. Some lists show it at about 150 × 150, so check every option at that size. `icon/icon-options-preview.png` shows each option at both sizes.

| File | What it is | Verdict |
|---|---|---|
| `icon/icon-a-hatch-spotlight.png` | The Bear in the hatch-reveal spotlight (black and gold), with the EGG DROP wordmark | **Recommended.** It is the strongest silhouette at 150 px and shows the hatch moment. The dark background stands out among Roblox's bright icons. |
| `icon/icon-b-garden-sparkler.png` | The dressed Bear (Pom Beanie and Bell Collar) holding its Sparkler in the dusk garden | Warm and cute. The white bear on a light sky is low in contrast at 150 px. |
| `icon/icon-c-pocket-deck-bear.png` | The Pocket Deck mid-round with a Bear sticker badge | Shows the merge game. The deck UI is too small to read at 150 px. |
| `icon/*-notext.png` | The same three without the wordmark | For A/B testing, or if you'd rather keep text off the icon. |

The wordmark is set in Builder Extended Bold, the in-game celebration font ("TIDY WIN!", "LITTLE WONDER!"), with a cream fill, ink outline and a Stars-gold underline. The game has no Egg Drop logo of its own. Its only wordmark art is the **Pocket Deck** mark (`assets/deck/shell/wordmark.png`), which would mislabel the game on an icon, so I didn't use it.

The in-game Bear currently renders **white** (its hue is "original", rank 0). The yellow-to-pink body in `pet-bear.blend` doesn't show in Studio, so the icon matches what players see. If the authored gradient is meant to ship, fix it in game first, then recapture.

## 7. Thumbnails (1920 × 1080, up to 10)

`thumbnails/` holds the captioned versions. `thumbnails/originals/` holds each one without a caption (`NN-name.png`) and the untouched Studio capture it came from (`NN-name__studio-capture.jpg`). All files are under 3 MB. Roblox doesn't publish rules for text on thumbnails, so captions are one short line in the game's own pill style, kept at the top because player-count metadata can cover the bottom edge. Video rules forbid ads and subjective claims, and the captions follow that rule too.

| # | File | Caption | Shows |
|---|---|---|---|
| 1 | `01-pocket-deck-round.png` | Merge balls on your Pocket Deck | A round mid-merge: chain ×3, a pink merge just landed, goals 1/2 |
| 2 | `02-results-stars.png` | Win rounds, earn Stars | TIDY WIN! results with the spinning 3D Star (**staged, see below**) |
| 3 | `03-hatch-bear.png` | Hatch your own baby Bear | The welcome hatch reveal: "A new little wonder!", BEAR, Meet Bear |
| 4 | `04-garden-dusk.png` | Roam the dusk garden together | Avatar and Bear walking into the dusk garden: trees, gazebo, toy pads |
| 5 | `05-pet-park.png` | Your pet plays in the Pet Park | The Bear at the bottom of the park slide, with the climbing tower and seesaw |
| 6 | `06-dress-up.png` | Dress your Bear up | The Bear in Pom Beanie and Bell Collar beside the bear statue at sunset |
| 7 | `07-wardrobe.png` | Hats, collars and more, at fixed prices | Wardrobe, Hat tab, Pom Beanie preview |
| 8 | `08-deck-style.png` | Style your deck. Looks only. | Deck style faceplates with the Liquid Chrome preview |
| 9 | `09-hatch-odds.png` | Odds shown before every hatch | Hatch eggs with Toy Egg odds of 34 / 33 / 33 % |
| 10 | `10-ball-styles.png` | Ball styles: just for looks | The Balls tab with the Kittens preview |

The suggested **order** leads with gameplay (1, 3, 4, 5), then dress-up and fairness. For **home-page personalization**, turn on 1, 3, 4 and 5 (Roblox needs at least two active).

**Capture notes. Read these before uploading:**

- **Resolution:** Studio's viewport is 2107 × 893 and the capture tool returns it at 1920 × 813. Each thumbnail is a 16:9 crop (1445 × 813) scaled up 1.33× with Lanczos and light sharpening, so they are a little soft. For crisp versions, play the published place at 1920 × 1080 and screenshot the same moments.
- **Results screen (2) is staged.** Your account owns both passes in Studio, so the real screen showed a "+7" pass row and "★ 13". For the thumbnail I hid that row and set the text to what a player without passes earns for this round (Round win 5, Tidy +1, Total ★ 6, wallet 103), which is what `HeatPayout` computes. The unedited capture is `raw/results-tidy-win-WITH-CREATOR-PASSES.jpg`. Re-shoot it from an account without passes if you'd rather not use a staged screen.
- **Win pays on the round (1):** for the same reason I held the board's `WinPays` attribute at the no-pass value (Easy 5–6) while capturing. Without that it showed 11–13.
- **Pet Park (5)** shows one pet. Studio Play has one client, so pets pairing up wasn't captured (see the video shot list).
- The Pocket Deck shots are the guided **Easy** first round on the default Scout faceplate with Smileys balls.
- Studio-only staging: GUIs hidden for the world shots, a scripted camera, my avatar hidden for the Bear portrait, 140 test Stars from `EggDropStoreTestGrant`, and a Pom Beanie, Bell Collar, Toy Egg (Sparkler) and Liquid Chrome preview bought or previewed with those Stars. Everything was restored and Play was stopped. The place was not saved or published.
- More raw captures (pocket menu, companions, collection book, park wide shot, more garden angles) are in `raw/`.

## 8. Video

Roblox videos must be uploaded by you. Uploads are free, limited to 3 a month, and each one is reviewed. See `VIDEO-SHOTLIST.md`.

## 9. Maturity and compliance questionnaire

Answer for the **most mature content a player can see**, and only for content you made (not players' avatar items). Target rating: **Minimal**, which keeps Kids (5–8) and Select (9–15) open, subject to their requirements below.

The first question decides whether you get "Content May Vary" (16+ only) or fill in the full questionnaire. **Take the full questionnaire**, because an all-ages audience needs a Minimal or Mild rating.

**Part 1, app type:** Game.

**Part 2, IARC questions:**

| Topic | Answer | Basis |
|---|---|---|
| Violence | No | No combat. Balls merge, nothing is hurt. |
| Blood and gore | No | |
| Fear | No | Nothing scary. The dusk garden is calm. |
| Sexuality, suggestiveness or dating | No | |
| Gambling (playable or unplayable) | No | Paid random items are **not** gambling here. They are disclosed under purchases. |
| Language | No | No profanity. Players' chat is Roblox's own and filtered. |
| Controlled substances | No | |
| Crude humour | No | |
| **Digital purchases** | **Yes**: developer products (Star packs), game passes (2× Stars, Supporter) and **randomized items** | Eggs cost Stars, and Stars can be bought with Robux, so every egg counts as a paid random item. Answer yes, and make sure the items meet the Randomized Virtual Items Policy (see checklist). |
| Cash-convertible rewards or NFTs | No | |
| Player-to-player communication | Yes | Default Roblox text chat in the garden and park. |
| Blocking, reporting, chat moderation | Yes | Roblox provides these. |
| Invite-only access | Yes only if you turn on **private servers**, otherwise No | |
| Shares precise location | No | |
| Prohibited content (extremist symbols, criminal techniques and the rest) | No | |

**Part 3, Roblox questions:**

| Question | Answer | Basis |
|---|---|---|
| Social hangout (primary activity is chatting) | No | The core is the deck and pet care. Chat is secondary. |
| Free-form user creation (drawing or writing on surfaces) | No | |
| Sensitive social, political or religious issues | No | |
| Cross-experience content | No | |
| AI interaction (players talk to generative AI) | No | |
| Media sharing with in-game tools | No | There is no in-game capture or share feature. |
| Continuous media feed or autoplay | No | Background music isn't a media feed. Re-check if you ever add a video or feed. |

If an update changes any answer, update the questionnaire and resubmit.

## 10. What you must do in Creator Hub

Creator Dashboard → Egg Drop (universe 10774758591):

1. **Configure → Basic info:** name, description (section 3), genre and subgenre (section 4). Choose the genre carefully, since it is locked for 3 months.
2. **Icon:** upload one option from section 6. It goes through moderation before others see it.
3. **Thumbnails:** upload up to 10 in the order from section 7. Activate 2 to 5 of them for home-page personalization.
4. **Video:** record and upload yourself (`VIDEO-SHOTLIST.md`). It counts toward the monthly quota of 3, and rejected videos count too.
5. **Maturity and compliance questionnaire:** section 9.
6. **Places → Start place → Settings:** set **max players to 12** (Pet Park scope recommendation) and leave server fill on Roblox's default (fill servers before opening new ones).
7. **Devices:** Computer, Phone and Tablet. Leave Console off until a gamepad pass is done. VR off.
8. **Communication:** keep default text chat. No voice chat is needed.
9. **Private servers:** decide. Off is simplest. If on, answer "invite-only: yes" in the questionnaire.
10. **Social links:** optional (YouTube, Discord, X and so on). I couldn't confirm the current rules for who sees social links in this pass. Check the Creator Hub field notes before adding a community link aimed at kids.
11. **Localization:** turn on **automatic translation** (text capture and auto-translate) for the top languages, and translate the name and description in the experience's Localization page. TODO.md also says to check that longer strings don't clip in the UI first.
12. **Monetization:** pass and product icons. The passes still use Roblox's default image (TODO). Decide on Managed Pricing, which means accepting its terms.
13. **Audience → Public:** switch from private or friends to public at launch. **This step is the launch.**
14. **Kids and Select (if you want under-13s to find it):** a Minimal or Mild rating, an age-verified account (government ID if you're 18+), 2FA on, and either 2 consecutive months of Roblox Plus or Premium or the refundable 1,000 Robux fee per game, then pass the evaluation. These rules changed during 2026, so read the live page before starting.

## 11. Launch checklist

From TODO.md's LAUNCH CHECKLIST and the v1 public launch section, plus what this pass found. ☐ = not done or not verified.

**Build flags (src/shared/FeatureFlags.lua). Today they read `{Features=false, DayNight=false, Park=true, TestFreshSaves=true}`:**
- ☐ **`TestFreshSaves=false`**. While true, every publish wipes progress. This must be off before going public.
- ☐ Confirm **`Park=true`** with Spencer for the public build (the flag comment says confirm before any public publish).
- ☐ Confirm `DayNight=false` (always dusk) is intended, because the hook says "always dusk".
- ☐ `Features=false` hides the Feature Egg. Confirm that's intended for v1.

**Policy:**
- ☐ Paid random items: odds as percentages summing to 100 % on every egg. The Toy Egg shows 34/33/33 % today. Check Material and Hue too.
- ☐ Every outcome gives something: check what a **duplicate** item-egg result grants (companions refund 50 %; Toy, Material and Hue duplicates are unverified).
- ☐ `ArePaidRandomItemsRestricted` players can't buy Star packs, and TODO says to gate **egg purchases** too where required.
- ☐ Maturity questionnaire filled in (section 9), including paid random items.

**Server and save:**
- ☐ 12 players per server in Creator Hub.
- ☐ Live save and rejoin on the published place with a signed-in standalone player.
- ☐ Live purchase test of each pass and pack.
- ☐ Two-player garden and Pet Park duo test with a second account.
- ☐ Physical iPhone and Android: touch, frame rate, heat, text size, first session to first hatch.
- ☐ Studio-only leftovers: delete or keep `ServerStorage.Baseplate_RetiredByGreybox`. Make sure no greybox or `ZZSpecs` content ships. The Studio test hooks are already gated by `IsStudio()`.

**Listing:**
- ☐ Name, description, genre, icon, thumbnails, video.
- ☐ Automatic translation on, and strings checked for clipping.
- ☐ Audience public. Soft launch, then read D1 and D7 retention in the Creator Dashboard.

## Sources

Roblox Creator Hub docs, read 13 November 2026: [thumbnails and videos](https://create.roblox.com/docs/production/publishing/thumbnails), [experience icons](https://create.roblox.com/docs/production/publishing/experience-icons), [genres](https://create.roblox.com/docs/production/publishing/experience-genres), [descriptions](https://create.roblox.com/docs/production/publishing/descriptions), [content maturity](https://create.roblox.com/docs/production/promotion/content-maturity), [publish experiences](https://create.roblox.com/docs/production/publishing/publish-experiences-and-places), [Kids and Select](https://create.roblox.com/docs/production/publishing/kids-and-select). The 50 and 1,000 character limits come from third-party summaries of the Creator Hub fields ([example](https://rolearn.dev/guidance/roblox-game-seo-title-description-tags)). Confirm them against the live field counters.
