# Short-video playbook: Pocket Pals: Pet Garden

Researched 19 November 2026 for a solo developer with a small budget. Covers TikTok, YouTube Shorts and Instagram Reels. Nothing was contacted, signed up for or paid.

**How to read the sources.** Most "rates" and "best practice" pages are vendor or agency blogs with a commercial interest, and many cite each other. Platform and regulator pages (Roblox, FTC, ASA, TikTok, YouTube) carry more weight. Items marked **[unverified]** come from one secondary source or sources that disagree. Items marked **[estimate]** are my own judgment, not a source.

---

## 0. Read this first: the 16+ gate decides the strategy

"Rated 16+ on Roblox" almost certainly means the game hasn't qualified yet for the **Roblox Kids (ages 5–8) and Select (ages 9–15) catalogs**. It does not mean the content is mature. `artifacts/store-listing/LISTING.md` §7 already targets a **Minimal** rating.

- Since Kids and Select launched globally on 16 June 2026, games that haven't passed evaluation "are still available to 16+ users" only. To reach under-16 players, a game needs enough **Highly Engaged Players (HEP)** from age-checked players, plus creator ID verification, 2FA, and a refundable fee or two consecutive months of Plus/Premium. Roblox staff post: [Kids and Select global launch: eligibility, Ads Manager, Expedited Review](https://devforum.roblox.com/t/roblox-kids-and-select-global-launch-upcoming-updates-to-eligibility-ads-manager-and-expedited-review/4685717). Roblox newsroom: [Kids and Select now globally available](https://about.roblox.com/newsroom/2026/06/age-based-roblox-kids-and-select-accounts-now-globally-available).
- The threshold fell from 500 to 250 on 19 August 2026. A staff update dated **19 November 2026 (today)** says Roblox will "begin lowering" it **from 250 to 100**, with no date given ([HEP threshold drops to 250, staff post with 19 Nov update](https://devforum.roblox.com/t/highly-engaged-player-threshold-drops-to-250/4820164)). Check the count in Creator Hub under **Publish Settings → Manage Audience / Audience Reach**.
- Roblox hasn't published an official definition of a "Highly Engaged Player." A third-party summary claims it means a user who made a minimum purchase anywhere on Roblox in the last 60 days ([SozAI transcript](https://sozai.app/transcript/roblox-500-highly-engaged-players-update/)). **[unverified]**
- Since 30 June 2026, social media links on a game page show only to age-checked users aged 16 and over (same staff post above).
- Ads Manager has a beta **Engagement objective** that "targets players whose sessions count toward the HEP threshold," for games not yet in Kids and Select. It may cost more than the Plays objective (same staff post). The current $5/day test uses **PLAYS** (`PLAY-BUILD.md`, 18 Nov). Consider switching the next test to Engagement.

**What this means for video [estimate]:** a cute pet game's natural TikTok audience skews young. Most of those viewers **can't join the game today**. Until the game reaches the threshold:

1. Aim the content at **16+ players**: "cozy game" fans, older teens, adults who play Roblox, and dev and gamedev audiences. Devlogs and "I made this" stories suit that audience. "Hey kids, come play" content does not, and it also creates legal risk (§3).
2. Treat the next two weeks as a **push to reach the threshold**. Every age-checked 16+ player who sticks around helps unlock the much larger under-16 audience.
3. Don't pay for big kid-audience Roblox creators yet. Their viewers would hit the 16+ wall.

---

## 1. Making your own videos

### 1.1 Formats that fit Pocket Pals

The ranges below come from one Roblox content guide, [ROLearn TikTok strategy, Mar 2026](https://rolearn.dev/guidance/roblox-tiktok-content-strategy-viral). They aren't independently verified. Use them for ranking, not as forecasts.

| Format | Why it fits | Example for Pocket Pals |
|---|---|---|
| **Satisfying loop** (ROLearn's "satisfying moments": 100K–10M views claimed) | A merge game is naturally satisfying: chains, shakes, a tidy finish | 8–12 s: ball drop → ×3 chain → TIDY WIN → Stars count up. No talking, one text line. |
| **Rare or first hatch reveal** (ROLearn's "player reactions" or "secret finds" type) | A reveal is a built-in payoff | "Hatching my first baby Bear…" with spotlight, banner, spin. End on the pet's face. |
| **Before/after** (30K–3M claimed) | Shows craft, and suits 16+ dev viewers | "Day 1 vs today": grey-box garden vs the current garden, or the old deck vs the Pocket Deck. |
| **Devlog / "I made a Roblox game solo"** | Builds an audience before and after launch with no budget ([indie devlog guide](https://gtstu.com/indie-game-devlog-audience-growth-youtube-tiktok/); DevForum devs recommend it, see [this thread](https://devforum.roblox.com/t/what-is-the-best-method-to-promote-my-game/4016948)) | Lead with the result, not "welcome back": "My pet game launched 2 days ago and has 9 players. Here's what I'm fixing." |
| **Dress-up / outfit check** | Dress to Impress showed that outfit content travels on TikTok ([Wikipedia](https://en.wikipedia.org/wiki/Dress_to_Impress_(video_game))) | "Rate my Bear's fit 1–10": Pom Beanie + Bell Collar, cut on the beat. |
| **POV skit** (100K–8M claimed) | Cheap to make with text overlays | "POV: your Bear sees you open the Pocket Deck." |
| **Glitch / blooper** (50K–5M claimed) | Honest, funny, and suits a dev account | A physics blooper from a test build, captioned "fixed it, promise." |
| **Trend riffs** | Reach comes from the sound or meme | Use only sounds that are licensed for your account type (see §1.5). |

Designing for clips matters as much as editing. Grow a Garden and Steal a Brainrot used "rare item reveals, visible reactions" ([RoWatcher, 2026](https://rowatcher.com/news/how-youtubers-and-tiktokers-move-the-charts-in-2026)). Pocket Pals already has two of those moments: the hatch reveal and the merge chain.

### 1.2 Hooks for the first 2 seconds

- Most scroll-away decisions happen within 1–3 seconds. Start **on the action**, not on a lobby or menu ([Eklipse on gaming clips](https://blog.eklipse.gg/beginner-guide-2/stream-hook-strategy-first-two-seconds.html); [ROLearn](https://rolearn.dev/guidance/roblox-tiktok-content-strategy-viral)). One vendor says Shorts viewers allow about 3–4 s. **[unverified]**
- Put **motion and a text overlay on frame 1.** Never open on a static title card.
- Hook templates for this game:
  - "This merge almost broke my game" (open mid-chain)
  - "I spent 3 months making this Bear and 9 people have met him"
  - "Which egg would you pick?" (two eggs on screen, then the hatch)
  - "Day 1 vs Day 90 of making a Roblox pet game"
  - "Rate this outfit" (Bear already dressed, beat drop)
- A/B the hook. Post 2–3 versions with different first seconds and identical bodies, then compare the 3-second retention in TikTok Studio ([hook testing method](https://blog.eklipse.gg/beginner-guide-2/tiktok-algorithm-gaming-creators.html)).
- Keep the editing fast, with roughly ≤5 s per shot. DevForum devs said one long clip with music is why their obby promo videos stalled at about 1K views ([DevForum, Jul 2025](https://devforum.roblox.com/t/how-to-promote-game-on-social-media-better/3810383)).

### 1.3 Length

- **Default 7–20 s** for satisfying, hatch and outfit clips. **20–45 s** for devlogs. **[estimate, based on retention advice above]**
- Upload limits are no longer the constraint. Shorts reportedly allows up to 3 minutes, Reels stops recommending anything over about 3 minutes to new audiences, and TikTok allows 10+ minutes ([Reap length guide 2026](https://reap.video/blog/best-video-length-youtube-shorts-reels-tiktok); [AdCreate Shorts guide](https://adcreate.com/blog/youtube-shorts-length-guide-2026)). Sources conflict on the exact Shorts cap. **[unverified]**

### 1.4 Posting cadence and accounts

- Advice ranges from 3–5 posts **per week** ([indie devlog guides](https://www.strayspark.studio/blog/devlog-marketing-build-wishlists)) to 2–3 Shorts **per day** (one DevForum dev, who said their Shorts "grew rapidly," [thread](https://devforum.roblox.com/t/what-is-the-best-method-to-promote-my-game/4016948)). ROLearn says 3–5 a day for 90 days, which is unrealistic for a solo dev who is also shipping updates.
- **Recommendation:** **1 new video per day** for 14 days, cross-posted to all three platforms, plus 1 extra hook variant on days when a clip is working. One 30-minute recording session yields 5–10 clips ([ROLearn](https://rolearn.dev/guidance/roblox-tiktok-content-strategy-viral)).
- Cross-post order: TikTok first, Shorts 2–4 h later, Reels 2–4 h after that. Remove the TikTok watermark by exporting from your editor rather than re-downloading ([ROLearn](https://rolearn.dev/guidance/roblox-tiktok-content-strategy-viral)). **[unverified: the order is opinion]**
- Don't delete slow starters. Some videos take 24–48 h to pick up. Reply to comments within the first hour (ROLearn).
- **Accounts:** run **one game account per platform** (for example @pocketpalsgame). A personal "dev" account for face-to-camera devlogs is optional. TikTok allows multiple accounts but bans using them to deceive or manipulate, and removes fake engagement. Don't run account farms or buy likes ([TikTok Integrity & Authenticity](https://www.tiktok.com/community-guidelines/en-GB/integrity-authenticity?cgversion=2025H2update)).
- Show the **game name in the same on-screen spot in every video**. Many viewers will type the name into Roblox search instead of tapping a link (§2.6). In one DevForum example, videos drew 52 profile clicks but only 26 game-link clicks ([thread](https://devforum.roblox.com/t/how-to-promote-game-on-social-media-better/3810383)).
- **Bio link:** on TikTok, a clickable bio link reportedly needs 1,000 followers or a business account. Sources conflict ([Buffer](https://buffer.com/library/how-to-put-a-link-in-tiktok-bio/)). **[unverified]** On YouTube and Instagram, put the share link in the description or bio.
- Hashtags: #roblox plus 3–5 niche tags (#robloxpets, #cozygames, #robloxdev, #gamedev, #indiedev). Skip #fyp ([ROLearn](https://rolearn.dev/guidance/roblox-tiktok-content-strategy-viral)).

### 1.5 Sound

- A TikTok **Business** account can use only the **Commercial Music Library**, not general trending sounds. Several sources say a personal account promoting a product can be held to the same rule ([Soundstripe](https://www.soundstripe.com/blogs/why-can-i-only-use-commercial-sounds-on-tiktok); [Social Media Today](https://www.socialmediatoday.com/news/tiktok-changes-rules-on-music-usage-by-businesses/577734/)).
- Safest choice: game SFX plus your own garden track or licensed CML tracks. A satisfying merge with its own pop and chime sounds doesn't need a trending song.
- The Roblox **store-page** video has stricter rules (no voice, no lyrics). See `artifacts/store-listing/VIDEO-SHOTLIST.md`. Those rules don't apply to TikTok.

### 1.6 Capture setup on PC (vertical 9:16)

1. **OBS + a vertical canvas.** Install the **Aitum Vertical** plugin. It adds a 1080×1920 canvas next to the normal 16:9 one, so a single recording produces both a trailer and a TikTok cut ([Aitum Vertical on OBS forum](https://obsproject.com/forum/threads/aitum-vertical.166504/post-666479)). Without the plugin, set the OBS output to 1080×1920 and crop and reposition the source. Don't squash 16:9 into portrait ([OBS vertical guide](https://www.videoconverterfactory.com/record-screen/obs-vertical-video.html)). 60 fps, high bitrate.
2. **Framing.** Live client: run Roblox windowed and resize the window to a tall shape, or crop a 9:16 slice from a 1440p or 4K capture. Keep the Pocket Deck or the Bear inside the centre 1080×1350 area so TikTok's caption and buttons don't cover it **[estimate]**. Studio: the **Device Simulator** (beta: File → Beta Features) can rotate phone profiles to portrait, or use a custom profile ([Device Simulator docs](https://create.roblox.com/docs/studio/device-simulator); [Test tab](https://create.roblox.com/docs/studio/test-tab)). Check whether the HUD lays out sensibly in portrait before relying on it.
3. **Roblox's own recorder** (Esc → Record → Record Video, Windows) works for quick grabs. Freecam (Shift+P, for owners and devs) works for smooth garden shots. Both are already noted in `VIDEO-SHOTLIST.md`.
4. **Studio Play + test grants** let you film wardrobe and hatch shots without spending Robux (`VIDEO-SHOTLIST.md`). Use a fresh save for a first-hatch reveal.
5. **Face cam / voice:** ROLearn claims a small face-cam overlay beats faceless content. **[unverified]** That works for devlogs on the dev account. It's optional for gameplay clips.
6. **Editor:** CapCut desktop or DaVinci Resolve, with burned-in captions (most people watch muted) and the game name in a fixed corner.
7. **Roblox Moments:** Roblox's in-app short-video feed was a 13+ beta that let viewers "jump into the game experience" from a clip ([TechCrunch, Sep 2025](https://techcrunch.com/2025/09/05/roblox-announces-short-form-video-feed-for-gameplay-clips-new-ai-tools-for-creators-and-more)). It isn't available to Kids or Select accounts ([Roblox newsroom](https://about.roblox.com/newsroom/2026/06/age-based-roblox-kids-and-select-accounts-now-globally-available)). I couldn't confirm its 2026 status or the developer capture API. Worth checking in Creator Hub.

### 1.7 Small devs who grew this way (honest picture)

- **Dress to Impress** was started by a 14-year-old developer. It spread through TikTok trends ("Pose 28", outfit challenges), then got creator amplification, and reached 250K+ average CCU by Sept 2024 ([Wikipedia](https://en.wikipedia.org/wiki/Dress_to_Impress_(video_game))). It's the best example for a dress-up game, but it's an outlier.
- **DevForum solo devs:** one says all their followers came "from YT Shorts and TikTok. No money spent at all." Another posted 500-view Shorts and got "0 joins" ([thread](https://devforum.roblox.com/t/what-is-the-best-method-to-promote-my-game/4016948)). An obby dev averaged 800–1,000 views per video for about 20 DAU ([thread](https://devforum.roblox.com/t/how-to-promote-game-on-social-media-better/3810383)).
- I found **no verified case study** of a solo dev's "I made a Roblox game" short series turning into a hit. Treat the format as cheap and cumulative, not as a launch lever.

---

## 2. Paying creators

### 2.1 Where to find them

| Channel | What it is | Fit for us |
|---|---|---|
| **Direct DM to nano and micro creators** (TikTok, YouTube, Discord) | Search your genre (cozy, pet, merge, dress-up Roblox). Check comments for real engagement and look for 2–3 uploads a week ([ROLearn partnering guide](https://rolearn.dev/guidance/partnering-with-roblox-content-creators)) | **Best value.** Small YouTubers (1–10K) sometimes play for free ([DevForum](https://devforum.roblox.com/t/what-is-the-best-method-to-promote-my-game/4016948)) |
| **TikTok One (ex-Creator Marketplace)** | TikTok's official matching. Creators must be **18+** with 1K–10K followers (TikTok's own pages disagree). Branded-content disclosure turns on automatically ([TikTok help](https://ads.tiktok.com/resources/help/article/how-creators-can-sign-up-for-tiktok-one); [CreatorIQ](https://creatoriq.com/blog/tiktok-enforcement-branded-content-disclosures)) | Good for the 18+ guarantee and disclosure handling. I found no stated brand minimum |
| **Social Seed** | Roblox-specific marketplace that connects developers with Roblox YouTubers and TikTokers ([DevForum launch post](https://devforum.roblox.com/t/marketplace-connecting-roblox-developers-to-roblox-youtubers/2798564)) | Prepaid only. The success story it cites (250→800 CCU within 60 min) comes from the site itself, and a commenter raised a conflict of interest ([thread](https://devforum.roblox.com/t/is-socialseed-good-for-promoting-games/2942279)). **[unverified]** |
| **Collabstr / CollabPals** | Creator listings with posted prices, including Roblox creators ([Collabstr Roblox](https://collabstr.com/top-influencers/roblox)) | One Roblox creator lists 10 Shorts for $50. Check each creator's real view counts |
| **Fiverr** | Mostly *editors* who make Roblox shorts (about $50) or "boost your game" gigs ([Fiverr example](https://www.fiverr.com/maulart/make-viral-roblox-youtube-shorts)) | Useful to outsource editing. **Avoid "promotion / boost player base" gigs** (bot risk, no disclosure) |
| **Upwork** | Freelance editors and UGC creators | Same as Fiverr: buy editing, not "reach" |
| **Billo (and similar UGC shops)** | You get a video **for your own account or ads**, not a post on theirs. From about $99 per video with usage rights ([Billo pricing](https://billo.app/blog/how-billo-pricing-works/)) | Low fit. Roblox gameplay is better captured by you. Their creators are mostly lifestyle UGC |
| **Backstage** | Casting site that also lists UGC creator gigs | Same as Billo. I didn't find Roblox-specific use. **[unverified]** |
| **Whop Content Rewards (clipping)** | Pay per 1,000 verified views to many "clippers" who post your footage. Median about **$1 CPM**, platform fee 7–10% (sources conflict) ([Content Rewards data, Nov 2026](https://contentrewards.com/articles/how-much-do-clippers-make); [ClipAffiliates](https://www.clipaffiliates.com/blog/clipaffiliates-vs-whop); [Whop docs](https://docs.whop.com/manage-your-business/growth-marketing/content-rewards)) | Cheapest views, but the clippers are anonymous: you can't check their age or audience. Disclosure is hard to enforce and view quality varies. Live campaigns run $1K–$10K. The minimum budget is **[unverified]**. Only consider at $500+, and only with strict rules (§3) |
| **Roblox-specific agencies** (Gamefam, Super League, Bloxbiz-type) | Brand activations at $400K–$1M+ ([RoWatcher](https://rowatcher.com/news/how-youtubers-and-tiktokers-move-the-charts-in-2026)) | Out of range |

### 2.2 Typical rates (the sources disagree; ranges are wide)

| Tier | Flat fee per short video | Source |
|---|---|---|
| Nano, 1K–10K | **$25–$200** | [Influee 2026](https://influee.co/ca/blog/tiktok-influencer-rates) |
| Nano, gaming, TikTok | **$64–$319** | [Elev8or](https://www.elev8or.io/find/tiktok-gaming-influencer-rates) |
| Nano | $150–$500 | [InfluenceFlow 2026](https://influenceflow.io/resources/influencer-pricing-benchmarks-complete-2026-guide-to-creator-rates) (high-side outlier) |
| Micro, 10K–100K | **$200–$1,500** | [Influee](https://influee.co/ca/blog/tiktok-influencer-rates) |
| Micro | $500–$5,000 | [InfluenceFlow](https://influenceflow.io/resources/influencer-pricing-benchmarks-complete-2026-guide-to-creator-rates) |
| Gaming TikTok, 10K–500K | $300–$4,000 | [Launchpoint](https://www.launchpointhq.com/guides/rates/how-much-do-gaming-tiktok-creators-charge) |
| **Roblox-specific micro** | **$50–$500 flat. A suggested first deal is $50–$200 for a 10K–50K creator** | [ROLearn](https://rolearn.dev/guidance/partnering-with-roblox-content-creators) |
| Per 1,000 views (gaming TikTok CPM) | **$6–$15** | Launchpoint, citing a 2025 Meegle report |
| Clipping CPM | **≈$1** median, $0.50–$1.50 typical | [Content Rewards](https://contentrewards.com/articles/how-much-do-clippers-make) |

Roblox-niche creators are often teens and charge less than general gaming rates. Many quote in Robux. **Expect to pay $25–$75 for a nano post and $100–$300 for a small micro post on a first deal [estimate].** Price each creator on **median views, not followers**: fee ÷ (median views ÷ 1,000) should come out at or under about $10–15 CPM ([MySocial method](https://mysocial.io/blog/how-to-determine-the-price-for-tiktok-influencers/)). ROLearn's average views by tier: nano 200–2,000 per video, micro 2,000–15,000.

### 2.3 Performance-based deals

- **Flat + CPM bonus [recommended]:** small flat fee (for example $30) plus $5–$10 per 1,000 views after 7 days, **capped**, paid from screenshots of the creator's analytics.
- **Revenue share:** 3–10% of game revenue for 30–90 days ([ROLearn](https://rolearn.dev/guidance/partnering-with-roblox-content-creators)). Hard to track. Social Seed's owner says devs and creators prefer prepaid ([thread](https://devforum.roblox.com/t/is-socialseed-good-for-promoting-games/2942279)).
- **Roblox Creator Affiliate / Creator Rewards:** an affiliate link earns up to 50% of a *new Roblox account's* Robux purchases for 6 months, capped at $100 per user ([Creator Affiliate docs](https://create.roblox.com/docs/affiliates)). Creator Rewards is a separate 35% program ([docs](https://create.roblox.com/docs/en-us/creator-rewards.md)). Creators can use these themselves as a sweetener. Pocket Pals' own links can also earn from brand-new users. Check current terms. **[unverified for 2026]**
- **Red flags:** guaranteed views or players, a large follower count with tiny views (for example 100K followers and 500 views), no sponsorship history on deals over $200 ([ROLearn](https://rolearn.dev/guidance/partnering-with-roblox-content-creators)), and middlemen asking for Robux upfront ([DevForum scam question](https://devforum.roblox.com/t/paying-a-youtuber-or-tiktoker-to-promote-my-game/1045620)).

### 2.4 Pre-screening checklist (because of the 16+ gate and child-safety rules)

- Creator is **18+**. Prefer adults whose audience skews 16+: cozy-game, dev, "Roblox but chill," dress-up or aesthetic creators. Ask for an audience age screenshot from TikTok Studio, YouTube Studio or Instagram Insights.
- Content isn't "made for kids" and doesn't target under-13s.
- Median views on the last 10 posts are steady. No viral one-hits inflating the average.

### 2.5 Brief template (keep outreach under 150 words, per [ROLearn](https://rolearn.dev/guidance/partnering-with-roblox-content-creators))

> Hi [name], I loved your [specific video]. I'm a solo dev and just launched **Pocket Pals: Pet Garden** on Roblox: hatch a baby Bear, dress it up, and play a merge-the-balls game on a little handheld. I think your [cozy/pet] viewers would like it. Offer: **$[X]** for one 15–45 s TikTok/Short of you playing it your way, plus **$[Y] per 1,000 views** after 7 days (cap $[Z]). Must-haves: the game name on screen, my tracking link in your bio or description for 7 days, the **TikTok branded content toggle / YouTube paid promotion box ON**, plus a spoken **and** on-screen "**Ad**" or "**Paid partnership with Pocket Pals**". You keep creative control. Please don't tell viewers to ask parents for Robux, and don't aim it at little kids. You need to be 18+. Interested? Happy to send early-access perks.

Deliverables to agree on: post date, format, the share link, a draft or preview **before** posting (the FTC recommends pre-approving paid posts, see §3), a 7-day analytics screenshot, and whether you may reuse the clip (usage rights cost extra, roughly 15–30% per 30 days for ad usage according to [Billo's rates guide](https://billo.app/blog/ugc-rates/)).

### 2.6 Measuring results

- **Share links (Creator Hub → Creations → Share Links → Experience Links):** unlimited per game. Make **one per creator and one per platform**. Analytics show new users who reached the game page through each link, which channels bring engaged and paying users, and a funnel by link ([Share links docs](https://create.roblox.com/docs/production/promotion/share-links); [announcement](https://devforum.roblox.com/t/analytics-track-your-off-platform-user-acquisition-with-share-links/3504691)). Data updates **daily**.
- **LaunchData perk:** a share link can pass a parameter that grants an in-game perk, such as a creator-themed hat or bonus Stars. This attributes joins and rewards the click. Keep it cosmetic and don't tie it to likes or follows (§3.4).
- **Acquisition dashboard** ([docs](https://create.roblox.com/docs/production/analytics/acquisition)): look for growth in "Home recommendations" after a push. One DevForum dev used that as the sign the algorithm picked the game up ([thread](https://devforum.roblox.com/t/this-is-how-my-game-got-on-the-algorithm-ideas/3794592)).
- **CCU before, during and after** each post, with a spike expected within 24–48 h ([ROLearn](https://rolearn.dev/guidance/partnering-with-roblox-content-creators)). Many viewers search the name rather than clicking, so share links **undercount**. Watch total new users and Search acquisition as well.
- **Audience Reach / HEP count:** for the next two weeks, this matters more than raw visits.
- Simple sheet: date, platform, video, views, 3-s retention, link visits, new users, D1 retention, cost, cost per new user.

---

## 3. Rules

### 3.1 FTC (US)

- Disclose any material connection: money, free items, Robux, early access. Put it **in the video itself, ideally both spoken and on-screen**, not only in the caption, bio or behind "more." "Ad," "Sponsored" or "Paid partnership" are fine. "sp," "collab" and "ambassador" are not. **A platform's built-in tool alone may not be enough** ([FTC Disclosures 101](https://www.ftc.gov/business-guidance/resources/disclosures-101-social-media-influencers)).
- **You (the advertiser) are responsible too.** Keep "reasonable programs to train and monitor" creators, pre-approve paid posts, monitor during the deal and for "a few months" after, and remember that outsourcing to an agency doesn't remove your liability ([FTC Endorsement Guides FAQ](https://www.ftc.gov/business-guidance/resources/ftcs-endorsement-guides-what-people-are-asking)).
- Kids: "disclosures will not work for younger children," so be "particularly careful" (same FAQ). The CARU children's-ad watchdog found Roblox's own influencer program fell short and pushed for the word "**paid**" in kid-facing disclosures ([BBB National Programs / CARU decision](https://bbbprograms.org/media/newsroom/decisions/roblox-advertising)).
- **Your own account counts too.** Your own videos promoting your own game are your own advertising and don't need an "ad" label in the FTC sense, but they must not be misleading. Don't show content that isn't in the game, and don't make fake "random player" reviews.

### 3.2 ASA / CAP (UK) and TikTok, YouTube

- UK: content is an ad when there's payment **and** brand control, or any commercial link. Use "**Ad**" or "#ad" **up front**. The ASA says "sponsored," "gifted" and "spon" are **likely not enough**. Platform labels help but an "Ad" label is still advised. Each post must stand alone. **Under-12s need enhanced, interruptive disclosure**, and an "ad" label alone likely falls short for them ([ASA: recognising ads on social media](https://www.asa.org.uk/advice-online/recognising-ads-social-media.html); [CMA/ASA 2025–26 guidance summary](https://www.rpclegal.com/snapshots/advertising-and-marketing/winter-2025/cma-and-asa-publish-updated-influencer-guidance-on-social-media-endorsements/)). **Use "Ad" (not "sponsored") so one label works in both the US and UK.**
- **TikTok:** the **Commercial content disclosure** toggle is required whenever a post promotes a brand, product or service. It shows "**Paid partnership**" for third-party deals and a commercial or promotional label for your own brand. TikTok says it doesn't change how content is recommended ([TikTok help](https://ads.tiktok.com/resources/help/article/how-to-turn-on-the-commercial-content-disclosure-setting-in-tiktok?lang=en)). **Turn it on for the game account's posts as well.** Some vendor blogs mention a new TikTok Branded Content Policy from 31 Aug 2026. **[unverified]**
- **YouTube:** creators tick "includes paid promotion." Paid placements in "made for kids" videos need a disclosure children understand, and videos flagged as paid promotion are pulled from the YouTube Kids app ([YouTube help: paid product placements for kids](https://support.google.com/youtube/answer/10502576?hl=en-IN); [Markey letter, 2020](https://www.markey.senate.gov/download/youtube-kids-ads?download=1)). **Don't mark Pocket Pals content "made for kids."** It isn't aimed at under-13s, and the game is 16+ for now.
- **Instagram:** use the Paid Partnership label **plus** "Ad" in the first line or on screen (same FTC/ASA logic).

### 3.3 Roblox's own rules

- **Advertising Standards (2023)** cover ads *on Roblox*: Sponsored Experiences, sponsored items, in-experience ads, and "independent" ads that promote off-Roblox products. Promoting in-experience purchases tied to the core game isn't covered when nothing off-Roblox is promoted ([Truth in Advertising summary](https://truthinadvertising.org/articles/roblox-revamps-its-ad-policies-after-tina-org-action); [DGLaw summary](https://dglaw.com/faced-with-increasing-pressure-roblox-adopts-new-advertising-standards); [DevForum announcement](https://devforum.roblox.com/t/simplifying-community-standards-introducing-advertising-standards/2219042)). The official help-center text returned 403 to my fetch, so I relied on these summaries.
- **2026 Advertising Integrations Policy (effective 4 May 2026):** paid brand integrations *inside* experiences must be registered, moderated and labelled, and Roblox takes a revenue share from Jan 2027 ([PocketGamer.biz, 23 Mar 2026](https://www.pocketgamer.biz/roblox-to-take-cut-of-in-game-brand-deals-from-2027-under-new-advertising-rules/); [DevForum post](https://devforum.roblox.com/t/new-advertising-policies-standards/4527365)). **I found nothing saying that a developer paying off-platform TikTok or YouTube creators to promote their own experience falls under these rules.** As read, it doesn't. **[unverified: check the current policy text in Creator Hub before a campaign]** It *would* apply if you sold or hosted someone else's brand inside Pocket Pals.
- **Rules of Conduct / Community Standards:** no "misleading content or metadata used to inappropriately drive discoverability or engagement," and no directing users off-platform ([Roblox Rules of Conduct](https://en.help.roblox.com/hc/en-us/articles/203313410-Roblox-Rules-of-Conduct); [Community Standards](https://about.roblox.com/community-standards)). In practice:
  - Don't put "follow us on TikTok for codes" prompts in-game for under-16s. Social links on the game page already show only to age-checked 16+ users (§0).
  - Don't give in-game rewards for likes, favourites or follows. A share-link LaunchData perk for *arriving* is a documented feature.
  - Don't run sponsored "giveaways" that need off-platform actions from kids.
- **Paying creators in Robux** through group payouts is common. Selling Robux for cash or trading items off-platform isn't allowed under Roblox's terms (the ToS page returned 403 to my fetch). **[unverified]** Pay in USD through the platform you hired on, or via PayPal or Wise with an invoice.
- Your own in-game copy: no "ask your parents to buy" lines. YouTube's kids policy also bans "incitement to purchase" ([Google ad protections for children and teens](https://support.google.com/adspolicy/answer/15416897?hl=en)).

### 3.4 Child safety: what to avoid

- **Don't pay minors.** TikTok One requires creators to be 18+ ([TikTok help](https://ads.tiktok.com/resources/help/article/how-creators-can-sign-up-for-tiktok-one)). Contracts with minors are generally voidable (general legal principle, not legal advice). Child-influencer earnings laws exist in **Illinois, California, Minnesota and Utah**, with trust-account set-asides. Minnesota bars under-14s from monetized content ([DGLaw/Mondaq summary](https://www.mondaq.com/unitedstates/social-media/1515150/new-laws-protecting-child-influencers-what-marketers-and-influencers-need-to-know); [TechPolicy.Press](https://techpolicy.press/the-coming-wave-of-child-influencer-regulation)). The details vary by source. **[unverified]** Simple rule: **adults only, confirmed before any offer.**
- **No DMs to accounts that look under 18,** and no private chats with players. Keep all outreach in public business channels or email.
- **COPPA:** the amended rule's compliance date was **22 April 2026**. When deciding whether a service is "directed to children," the FTC now explicitly weighs an operator's **marketing plans, representations, and user and third-party reviews** ([Federal Register, 22 Apr 2025](https://www.federalregister.gov/documents/2025/04/22/2025-05904/childrens-online-privacy-protection-rule); [BBB reminder](https://bbbprograms.org/media/insights/blog/coppa-amended)). Marketing aimed at under-13s could pull the game into child-directed analysis. Pocket Pals collects no personal data outside Roblox, so the risk is low, but **don't target under-13s in captions, hashtags (#kids, #forkids), or creator choice.**
- Don't collect emails, birthdays or handles from viewers. No "comment your Roblox username to win" giveaways.
- Don't imitate or use other games' or creators' names and art in hooks. That's misleading, and Roblox's metadata rules apply.
- Moderate comments. Delete grooming-like comments or requests to move kids to Discord or DMs.

---

## 4. Two-week plans (20 Nov – 3 Dec 2026)

Goals in order: **(1)** age-checked 16+ players who stay, to move the HEP count toward 250 (dropping to 100), **(2)** new users per channel through share links, **(3)** learn which format works. Keep the existing Roblox $5/day ads separate. Consider switching the next round to the **Engagement objective** (§0).

### Setup (day 0, about 2 h, $0)

- Create the game accounts: TikTok, YouTube channel, Instagram. Put "Roblox game • made by 1 dev" in each bio.
- Create share links in Creator Hub: `tiktok-bio`, `yt-shorts`, `ig-reels`, plus one per creator later. Optional: a LaunchData cosmetic perk.
- OBS + Aitum Vertical scene: game on the vertical canvas, game-name tag in the top-left safe area.
- One 60-minute recording session that covers the hatch on a fresh save, 5+ merge chains, a dress-up sequence, Bear petting, and day/night garden sweeps.
- A tracking sheet (§2.6).

### (a) $0: make your own

| Days | Do |
|---|---|
| 1–3 | 1 video a day on all three platforms: (1) satisfying merge chain, (2) first hatch, (3) "I made a Roblox pet game solo, 2 days after launch." Watch 3-s retention. |
| 4–7 | Repeat whichever format got the best 3-s retention, with **2 hook variants**. Add a dress-up "rate my fit" and a "Day 1 vs now." |
| 8–10 | Devlog mini-series: "Fixing what players hated, part 1–3." Reply to top comments **with video replies**. |
| 11–14 | Double down on the top two formats. Post 1–2 a day. Post a progress-update devlog to r/robloxgamedev and the DevForum *Creations Feedback* category (free, and suits the 16+ dev audience). DM 5–10 small (1–10K, adult) cozy or Roblox creators offering **free early-access perks**, with no payment and therefore no paid-disclosure overhead. Any free perk is still a material connection, so ask them to disclose. |

**Realistic outcome [estimate]:** most posts get 200–2,000 views. One breakout (10K+) in 14 videos is plausible but not likely. Based on DevForum reports (800–1K views per video giving about 20 DAU, and 500-view Shorts giving zero joins), expect **tens to a few hundred extra visits** over two weeks. Content compounds, so the main win is a library of 14+ clips and knowing which hook works.

### (b) About $100

Everything in (a), plus:

- **$60–75: 2–3 nano creators** (adult, 16+ audience, 2K–10K median views) at **$25–35 flat + $5 per 1K views after 7 days**, capped so the total stays under $100. Find them by direct DM or on Collabstr. Each gets its own share link and a cosmetic LaunchData perk.
- **$25 reserve:** if one of your own organic posts clearly outperforms, either (i) boost it with TikTok **Promote** for about 5 days at $3–5/day, targeting **18+** (Promote minimums are **[unverified]**; Ads Manager itself needs $20/ad group/day, so it's out of range, see [TikTok budgets help](https://ads.tiktok.com/help/article/budget-recommendation)), or (ii) pay a third nano creator.
- Days 1–4: find and brief creators. Days 5–9: posts go live, staggered. Days 10–14: measure, and pay bonuses from analytics screenshots.

**Realistic outcome [estimate]:** 5K–30K paid views in total. At a typical view-to-visit rate of a fraction of a percent, that's roughly **50–300 visits**, and a smaller number of returning 16+ players. The useful output is **cost per new user by channel** to compare with the $5/day Roblox ads (DevForum: about 100–200 visits per 5K Robux on older sponsor data, [thread](https://devforum.roblox.com/t/paying-a-youtuber-or-tiktoker-to-promote-my-game/1045620)).

### (c) About $500

Everything in (a), plus:

- **$200–250: one micro creator** (adult, 10K–50K followers, median views ≥10K, cozy/pet/Roblox, audience mostly 16+). Flat **$150–200** + **$5/1K views** bonus capped at $50. ROLearn's suggested first deal for this size is $50–200.
- **$150: 4–5 nano creators** at $30 flat each, plus a small CPM bonus.
- **$50–100 boost** of the best organic or creator post (with Spark-style authorization only if the creator agrees and it's disclosed). Otherwise put it into the Roblox **Engagement-objective** ads to convert the attention into threshold-qualifying sessions.
- **Not recommended yet:** a $200+ Whop clipping campaign. At about $1 CPM it would buy roughly 150–200K views, but you can't vet clipper age, audience or disclosure. The FTC holds the advertiser responsible for the network's disclosures, and many clippers target young audiences. If you try it later, require "Ad" on screen, the TikTok toggle, 18+ attestations, and no kid-targeted pages. Also confirm the minimum budget first.
- Timeline: days 1–3 brief creators; days 4–7 the micro creator posts (preview approved); days 6–10 nano posts staggered; days 11–14 measure and decide on round 2.

**Realistic outcome [estimate]:** 30K–150K paid views, so roughly **300–2,000 visits**. One well-matched creator can create a visible CCU spike for a day or two (Social Seed's self-reported 250→800 CCU case had a much larger creator, [thread](https://devforum.roblox.com/t/is-socialseed-good-for-promoting-games/2942279)). Whether it lasts depends on D1/D7 retention and whether the HEP threshold unlocks under-16 reach. **No source supports guaranteed results.**

### Decision rule after two weeks

- If cost per new user from creators is lower than the Roblox ads, run round 2 with the best creator type.
- If the HEP threshold is reached, the under-16 audience opens. Then (and only then) consider mainstream Roblox-kid creators, with child-appropriate "paid" disclosures and no incitement to buy.
- If nothing beats the Roblox ads, keep posting your own videos (cheap, compounding) and spend on Engagement-objective ads.

---

## 5. Open questions to verify before spending

1. The exact current HEP definition and when the 250→100 drop takes effect (Creator Hub → Audience Reach).
2. Whether TikTok shows commercial-labelled posts to under-18 users in your regions. I didn't find a clear answer.
3. The current Roblox Advertising Standards and Advertising Integrations Policy text (the help center blocked my fetch). Confirm that off-platform creator promotion of your own game isn't covered.
4. The TikTok Promote minimum daily budget and the bio-link eligibility for the new account.
5. Roblox Moments 2026 status and developer capture prompts.
