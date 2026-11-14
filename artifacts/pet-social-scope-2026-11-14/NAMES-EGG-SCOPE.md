# Names Egg and collectible pet names — scope only

2026-11-14 · Astra recommendation for discussion. **Not implemented or approved for implementation.** This adds a future feature proposal; it does not replace the active unpublished build or QA repairs. All Blip/alien concepts remain rejected and parked. No new species is selected. The separate hatch redesign still requires showing its concept before production implementation.

## The naming game

Unlock little name pieces and combine **one or two** into a wonderfully overqualified pet name: “Biscuit Bureau”, “Velvet Sidequest”, “Almost Tuesday”. Pieces are collectible; renaming is always free. No ordinary-person-name generator, free-text box or three-piece names.

The reference is Animal Crossing: New Horizons' passport titles: collect unlocked starting/ending pieces and combine them, with some supplied initially. We borrow the recombination mechanic, not its word list, art or UI. [Nookipedia: Passport title mechanic](https://nookipedia.com/wiki/Passport). The supplied [StrategyWiki title reference](https://strategywiki.org/wiki/Animal_Crossing%3A_New_Horizons/Passport_titles) returned403 in this review; no claims here depend on its unavailable contents.

**Recommended difference:** our24 pieces can occupy either position, and one piece is a valid complete name. Awkward/funny order is part of the charm; provide Swap as well as Clear second piece. Do not force grammar into prefix/suffix categories. Each selected ID may appear once in a name; two different pieces maximum. Species labels such as “Bear” remain separate and accurate.

## Original starting bank

This is an authored proposal, not an imported title list. Each cell is one atomic piece, even where a future localized form uses several words.

| Free from first owned pet | Egg pool:20 pieces |
|---|---|
| Biscuit, Puddle, Tuesday, Parade | Velvet, Sidequest, Bureau, Mooncrumb, Almost, Marmalade, Teacup, Thunderbun, Noodle, Overture, Pocketful, Moonboots, Crumpet, Detour, Waffle, Stardust, Tumble, Keepsake, Apricot, Afterparty |

Examples using at most two pieces: **Biscuit Bureau; Velvet Sidequest; Almost Tuesday; Marmalade Moonboots; Teacup Overture; Waffle Detour; Apricot Afterparty; Puddle Parade.** “Mooncrumb” alone also works. The joke should feel like a peculiar racehorse/show-animal name, not an insult aimed at the pet or owner.

Editorial pass before implementation: review the full ordered pair matrix for accidental offensive/sexual/political/impersonating phrases and language-specific problems.24 pieces produce552 ordered distinct pairs plus24 solos; review that finite set rather than assume individually safe words guarantee safe combinations. Change problematic proposed pieces before launch instead of quietly charging for unusable combinations.

## Acquisition, odds and completion

**Proposed price:8 Stars**, matching the current Toy Egg price. One purchase unlocks exactly one not-yet-owned piece from the20-piece egg pool, account-wide, forever. No rarities, duplicates, consumable naming tokens, reroll charges or paid rename. Completing the proposed pool takes20 purchases/160 Stars; the four starters are excluded from paid rolls. No new currency or Robux-specific Names Egg product.

For unrestricted accounts, all remaining eligible pieces are equally likely. Initially each has5%; with N remaining, each has1/N probability. Show the current full eligible list and exact “1 in N” wording alongside sensibly rounded percentages, explaining rounding where needed. Use the real pool, not a static decorative odds label. Receipt names the unlocked piece; **Try name** previews it with the current pet name without silently overwriting the saved name.

At full ownership: Names Egg card shows **“All name pieces collected ·24/24”**, purchase control remains visibly disabled, no Stars deducted, no fallback duplicate compensation. New versions may append pieces later with explicit revised pool/odds; retain old pool versions and receipts. No limited-time removal, expiry or completion pressure.

### Fit the actual current economy and policy implementation

Repository facts: `src/shared/StoreCatalog.lua` configures Robux Star packs and paid boosts; therefore spending Stars cannot simply be assumed to mean earned-only acquisition. `src/server/PaidRandomPolicy.lua` treats unknown/restricted policy as restricted, and `src/server/HatchProgress.lua` publishes fixed-next outcomes for restricted accounts. `src/shared/ToyCatalog.lua` already models permanent account unlocks, remaining-only odds, preserved pool versions and an append-only fixed order.

**Proposal:** use that established Names-equivalent path. Restricted or unknown-policy accounts see **“Next: Velvet ·8 Stars”** (the first unowned piece in an explicit stable acquisition order) and receive that exact deterministic piece, with no random draw. Unrestricted accounts see the current eligible odds. The server pins policy mode, pool version, eligible ownership and cost in the quote; if policy/ownership changes before commit, refresh the offer before any debit rather than deliver an unshown outcome. Preserve existing Star-pack restrictions. Do not add a client-only policy check or invent an earned/purchased balance split. These are integration requirements based on existing code, not a claim of platform-policy or legal certification.

Durable idempotent transaction must atomically debit and unlock with one receipt identity. Rapid requests, retries, reconnects and concurrent stale quotes cannot double-charge or grant a duplicate. All-owned stale requests refuse without debit. Use additive stable-ID sets, **not the already bounded pet inventory bitmask**; final storage shape requires architect review.

## Name wardrobe

Location: **Companions → selected pet → Name**. Main panel shows actual pet preview, live proposed full name, two piece slots, owned-piece grid, Swap/Clear, **Save name** and Cancel. Selecting an unowned piece shows how to obtain it, without a surprise purchase. Keep the existing house UI style and current QA button/shortfall conventions.

Ownership is account-wide; equipped name is stored per owned pet ID. The same unlocked piece can be used on several pets. Saved name is one or two validated owned IDs; rename is free and does not consume pieces. Empty slots revert to default species name (e.g. Bear), always available free. Existing saves begin with default species names and gain the four free starters idempotently when eligible. No random automatic rename and no pet ownership migration.

Preview updates locally; Save commits through owner-validated persistence, shows pending/saved truthfully, and only then updates public name revision. Cancel leaves the original untouched. A failed save leaves the proposed name editable. Future pet species reuse this system without requiring any Blip work.

**Display and localization default:** a chosen name is a proper name built from canonical authored display pieces, shown consistently to all viewers; do not machine-translate it differently for each observer. Localize category/help/controls and provide localized explanations of pieces where useful, while stored identity remains IDs. Future authored alternate-language name banks need a separate curated release. Starter and piece names follow existing localization-export infrastructure with explicit proper-name treatment, rather than changing spelling in saved data.

Fit at 812×354: allow two lines in the name editor/card, preserve minimum text size, and show full name in inspect detail. Short world prompt may ellipsize, but never make two different names indistinguishable in the detailed card. Author piece lengths against the real available width; no marquee, giant overhead name cloud or shrinking text below the existing12px floor. Use platform-safe plain text rendering; no RichText interpolation, markup, Unicode control characters or client-sent raw name strings. Owner display names remain Roblox-provided data and follow their existing handling.

## V1 boundary and acceptance

V1 includes24 pieces/4 free, one8-Star egg, no-dupe unlocks, deterministic restricted offers, free per-pet one/two-piece naming, default fallback, name preview/save/cancel, and public equipped names for future visitor cards. No trading/gifting, name auctions, rarity tiers, leaderboards, custom text, rename fees, new species or new paid product.

Before implementation: architect reviews transaction/schema/policy paths; creative review validates the full pair matrix and actual phone fit. Later tests cover ownership spoofing, >2/same-piece/unknown IDs, retries/concurrent purchase, policy transition, full pool, old receipt load, missing fields, rename failure/rejoin, correct per-pet isolation, public revision and localization. Two real accounts verify a saved name reaches another observer; synthetic fixtures must be labeled fixtures. **This document does not authorize building the feature.**
