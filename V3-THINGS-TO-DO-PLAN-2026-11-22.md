# Things to do: build plan (2026-11-22)

From code; nothing run. Now: Deck, Pet Park, Garden Dash. Finds, Keycap, Stats: nothing shipped until built.

**Out:** world board, fingerposts, first-race helper (slice 1), and Dash/finds **quests** (new `QuestCatalog` rows change live draws, a version bump wipes claims, and they pay Stars).

## Switch
- `FeatureFlags.ThingsToDo`: ceiling, beta place or Studio. `Shared/Things` and `server/ThingsConfig` copy Dash: `things_to_do` (tile, page, trail), `things_tips` (onboarding; needs the first). Off until config loads, then missing = on. Owner chat `/things [tips] on|off|clear`.
- **Off parity:** six tiles in 3 x 2; `How.Order`, tour, attract, snapshots unchanged; no instances, frame work or attributes; new coach ids refused.

## Menu and page
- **Page inside `MachineHub`** (`openPage`; Back returns to tiles), so `gameMenu:isOpen()` keeps every modal guard; cost: a bigger hub module.
- Seven tiles in **4 x 2**, before Settings; a third row leaves about 60 px on phones. Switch flips rebuild when closed.
- Rows refresh every .5 s while visible. Deck: "Play a round". Park: `playDate` count/target. Dash: only while `Dash.on()` and its client is alive, via new `DashClient:summary()`: gather "Race: {count} of 8", live "A race is on", else "Start a race".
- Stars text and How card d only while `Dash.prizes()`, from `snapshot.dash`.
- **Show me** closes the menu and lays prints for 20 s: async `PathfindingService`, 40 pooled local parts (no collide/query/touch). No path: destination marker only, never a line over water. Dash target is the live gate's `Start`, so moving it needs no edit. Ends within 8 studs, on death, leaving Room, a seat, a new trail or switch off. Reduced effects: no fades.

## Onboarding
Pure `ThingsTips.due(ctx)`, last branch of `CoachCards:step`. Rail line, tap, notice card with **Show me** (`run` = trail).

| Bit | Trigger | Line |
|---|---|---|
| `parkInvite` 11 | Not veteran; `gardenIntro` set, first egg done, `park` unset | Pet Park |
| `dashIntro` 12 | `Dash.on()`, first egg done; `playDate.count >= 1`, or first Ready snapshot had `gardenIntro` or veteran wins | Garden Dash, or "New in the garden" if returning; never both |
| `dashSeen` 13 | Dash row shown or joined | Clears New dot |

First egg done: `FirstSpendGuide.stage(state,{eligible=true})=="done"`, no flight. `Coach.wants` blocks veterans: add `wantsIntro`.

**All gates:** Room and `canRoam`; not `revealPending`; `anyModalOpen()` false, plus names, snack reveal, arrival hatch; no How card or tour; no greeting/focus; new `DashClient:engaged()` false (seat **including gather**, queue, card; `held()` misses gather); own actor not `park*`, in care or carried; `ParkGamesPending` 0; no `storeView.prompted`; rail empty; still 1.2 s, settled 2.5 s, focused, input within 20 s. Becoming busy cancels the line unmarked; it retries.

**Caps:** one line; two intros a session, 300 s apart; counted and saved on `onShown`.

- Tour: one added card. How `dash`: a to c, d with prizes; listed only while on.
- Attract: Dash entry follows the live gate; one beckon, none during a coach line.

## coachMask safety
Safe: append bits 11 to 13, no version bump. Old servers accept 0..2^31-1, OR-keep unknown bits and silently drop unknown ids. Fallback: client `seen` holds for the session; worst case a tip repeats next visit. Rollback keeps bits. Writes wait for the 10 s quiet window. Server refuses gated ids while Things is off. Bits never clear: retest on fresh saves.

## Worker files
New: `Things`, `ThingsConfig`, `ThingsPage`, `ThingsTips`, `ThingsTrail`.
Edit: `FeatureFlags`, `CoachMarks`, `UICopy`, server `init`, `MachineHub`, `MachineHubArt`, `CoachCards`, `NoticeCards`, `HowItWorks`, `StationAttract(Data)`, `DashClient` (two readers), `init.client` (IIFE on `clientUI.things`; column-0 stays 218/219; `openMachine` branch).

## Specs
Config/ceiling; off parity; CoachMask (old-server drop, gate); each tip gate, caps, veteran, once; hub 6/7 tiles at 568/812/desktop and focus; row states, prizes off; trail cancel/failure; How, Notice, Attract, LocalBudget. Studio: touch, gamepad, two players, localisation.

## Order
1. Switch, bits, gate, parity. 2. Page. 3. Trail. 4. Tips, How, tour. 5. Attract. Reviews each; Fable reviews captures.

## Risks and edges
- Land after Dash slices (`DashClient`).
- Four columns at 568 px: Fable decides.
- Pathfinding over bridge/steps under streaming is unmeasured: test first.
- Switch off mid-page, mid-trail or with a queued tip cancels all.
- Respawn keeps caps; rejoin resets session caps only.
