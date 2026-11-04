# Egg Drop product scope

Egg Drop is a tactile merge arcade game and a pet collection in one Roblox
experience. The board makes another round worth playing. The collection gives
players a reason to return. The Pocket Deck connects them. It is the game
screen, something the player can customize, and something friends can see
while the player is in a round.

The working product is on `feat/egg-drop-arcade-polish`. The older
[game design](GAME-DESIGN.md) and [pinball pitch](V2-PINBALL.md) capture
earlier ideas. The [prototype rundown](PROTOTYPE.md) describes the current
controls and behavior. This scope draws on all three, the project discussions,
Astra's code and design review, and the Roblox platform references below.

## The player experience

1. The first session opens on the Pocket Deck. The player aims, drops, and
   makes a match before they need to learn about the lounge.
2. A round builds score, chains, and hatch charge. Better placement can
   leave room for later merges. Two eggs at the maximum tier clear each
   other and reward the player for opening space.
3. Pip opens the Pocket Club. Puddle, Wick, and Orbit extend the collection
   with visible targets. Overflow resets the tray and score. Earned pets,
   hatch charge, best score, deck appearance, and companion choice carry
   forward.
4. The player can meet pets in the lounge, choose a companion in the journal,
   and customize the deck at the workbench. Nearby players can see their
   deck and companion. Returning to the board resumes the current round.
5. A returning player can choose a short score run, work toward their next
   pet, or see what their friends have collected.

## Production requirements

| Area | Direction | Evidence to advance |
|---|---|---|
| Board | Keep aim, drop, bank shots, chains, and overflow understandable. Build around a personal best and visible tier progression. Test a separate shape-aware physics wedge before deciding whether stronger shots can squeeze through a pile. | A new player can explain a match and make an intentional follow-up shot. Players replay after a hatch, and the same input produces consistent results in a physics fixture. |
| Pet collection | Establish Pip, Puddle, Wick, and Orbit as the first set. Give each a silhouette, color, idle, greeting, synth cue, and journal entry. Later variants can come from skill challenges or milestones. | A player understands their next unlock and can identify, select, and show their earned companion. A failed round still advances the collection. |
| Pocket Deck | Use a pixel LCD and physical controls in portrait and landscape. Keep left/right and A easy to reach. Use earned stickers and shell choices to express play history. | Small touch screens remain readable, controller focus returns correctly, and equipment appears consistently on the UI and held model. |
| Environment | Make the Pocket Club a compact, warm arcade with a hatchery, journal, deck workbench, and space to see other players. Give stations an action or a useful display. | Two players can see the other's companion and active deck, move around the room, and return to the board in one action. |
| Audio and accessibility | Keep original synth sounds with distinguishable contact, merge, chain, and hatch cues. Add volume controls, readable marks independent of color, and support for reduced motion before release. Audition music as its own decision. | Cues are audible on a phone speaker, large text fits, and the experience remains understandable with sound muted. |
| Progress and storage | Keep round simulation authoritative. Make scores, grants, equip permissions, and save data server owned. Keep the existing linear rank compatible while introducing stable catalog IDs. Move to versioned inventory and transactional spending before adding currencies or trades. | Save and rejoin, rapid reconnect, shutdown, failed loads, concurrent updates, and old profiles have defined outcomes. |
| Release | Publish a private Roblox build with original sound asset IDs, image API permissions, and published data stores. Check touch on physical hardware and test a shared server before opening access. | A fresh phone player can hatch Pip, visit the club, resume the board, and keep their progress across a rejoin. |

## Roblox and genre evidence

- Roblox documents early exits, play days, and intentional co-play as
  recommendation signals. Measure first drop, first merge, first hatch,
  lounge visit, and next round. Look at board replay and collection return
  separately, then look at how often friends intentionally join each other.
  [Discovery](https://create.roblox.com/docs/discovery) · [Funnel events](https://create.roblox.com/docs/production/analytics/funnel-events)
- Roblox's 2025 Replay highlights breakout collection and social games and
  documents self-expression as a platform theme. Our hypothesis is that a
  deck players can personalize and show to friends gives that trend a
  gameplay connection. It is a hypothesis for Egg Drop, not a forecast.
  [Roblox Replay](https://about.roblox.com/en-nz/newsroom/2025/12/roblox-replay-decoded-search-style)
- Sobosuba offers a benchmark for physical softness and readable chains.
  The player-facing question is whether squeezing changes decisions enough
  to justify a more expensive simulation. Keep synth ASMR cues short and
  tied to readable material changes. [Sobosuba](https://store.steampowered.com/app/1946560/sobosuba/) · [Developer physics notes](https://www.reddit.com/r/godot/comments/1vlxww3/my_softbody_physics_merging_game/)
- Roblox's device, accessibility, analytics, and event tools support mobile
  tuning and small content drops. Use platform events when there is a real
  reason to revisit, such as a new pet family or a new board challenge.
  [Cross-platform development](https://create.roblox.com/docs/projects/cross-platform) · [Accessibility](https://create.roblox.com/docs/production/publishing/accessibility) · [Experience events](https://create.roblox.com/docs/production/promotion/experience-events)

## Build sequence

| Stage | Scope |
|---|---|
| Replayable build | Scored rounds, five tiers with a max-tier clear, persistent personal best and hatch progress, four pets, journal, companion display, earned Wick sticker, and Pocket Club stations. |
| Collection alpha | Finish each family's hatch and idle polish. Add a few authored board challenges and pet milestones. Test the soft-body wedge. Make the journal and deck unlocks easier to discover. |
| Private release candidate | Add audio asset IDs and accessible settings. Check the published save path, replica load, input focus, orientation, and physical phones. Instrument the first-session funnel and replay milestones. |
| Public release | Validate the first session with fresh players, then choose a sustainable cadence of pet and board content. Use the existing roster concepts as a production backlog. |
| Expansion | Consider additional cosmetic slots, family variants, friend challenges, and events. Evaluate an economy, trading, or global boards separately when they solve a demonstrated player need. |

Before a larger lounge or spectator mode, measure the cost of sending board
parts to every client. If needed, give the owner high-rate state and send
lower-rate miniature updates to nearby spectators. Keep local test saves and
published saves distinct.
