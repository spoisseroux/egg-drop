# Pet Park (playground) v1: build plan (2026-11-13)

## Spencer's direction (2026-11-13, replaces the fetch design in PET-PARK-V1-SCOPE-2026-11-13.md section 2.2-2.3)

> "You stand around the park, like parents around a playground with their children, watching and chatting, and
> there's 'slots' and your pet will randomly go on a swing, go on a slide, etc., play with other people's pets, go on
> a see-saw, play with a ball, sand pit, build a sand castle. There should be single and duo activities that randomly
> match with another player's pet if one is in there. This is separate from toys outside of the playground.
> I'll test with a second account."

Kept from the scope (not contradicted): location A (east picnic lawn on the arrival path, raycast first; fallback B
the Toy Lawn), ankle-high kerb with two gateways (no fence), benches with Roblox `Seat`s around the edge, Roblox
default chat with bubbles, 12 players per server (Creator Hub setting, Spencer), server-owned pet actors on the
existing curve/snapshot model, own-pet ring on your screen only, a daily "Play date" +4 Stars (your pet did 3
playground activities; no Stars for idling), distance tiers for pet rendering. Dropped: Throw/Call verbs, the park
ball post and fetch, quick chat (Roblox chat covers it; revisit if players without text chat ask).

## The loop

1. Owner walks into the playground (inside the kerb, or seated on a park bench). Their pet is "in the park".
2. The server's playground director gives each idle park pet an activity every few seconds from free **slots**:
   solo slots (swing, slide, sandbox castle, ball bounce) and duo slots (see-saw, sandbox together, ball toss,
   double swing side by side). A duo slot only starts when two idle park pets can fill it; otherwise pets take solo
   slots. Pairing prefers pets of different owners.
3. An activity runs 8-20 s (walk there, play, a happy finish), then the pet wanders/rests briefly and picks again.
4. The owner watches from the edge or a bench, chats with Roblox chat. Leaving the kerb ends the pet's activity at
   once (pet runs back to its owner, the slot frees).
5. Personal toys (Ball/Bone/Sparkler) stay outside: inside the park the pet uses park equipment only.

## Equipment (v1)

| Equipment | Slots | Kind | Pet action |
|---|---|---|---|
| Swing set (2 swings) | 2 | solo each (two pets side by side = shared swing beat) | sit, pendulum swing, hop off |
| Slide | 1 queue of 1 (ladder + slide) | solo | climb, sit, slide down, tumble-roll, happy bounce |
| See-saw | 2 seats | **duo only** | bob up and down in counter-phase |
| Sandbox | 2 spots | solo (build a castle) or duo (build one castle together) | dig/pat, castle grows in 3 stages, crumbles after |
| Ball corner | 2 spots | solo (bounce/chase) or duo (toss back and forth) | roll/bat ball |

All equipment is original low-poly art in the island's dusk palette (Astra direction), anchored, non-colliding for
pets (pets are visuals), players can stand around it; benches have `Seat`s.

## Slices

| Slice | Owns |
|---|---|
| K1 Server director | new `src/shared/ParkLayout.lua` (kerb ellipse, gateways, equipment anchors and slot poses, raycast heights recorded from Studio), new `src/shared/ParkActivities.lua` (activity catalogue: id, kind solo/duo, equipment, slot ids, phase timeline durations), new `src/server/ParkDirector.lua` plugged into `GardenState` like `self.care` (membership from the 2 Hz owner sample, slot reservations, duo matching, timelines, release on leave/owner exit/pet busy, sandbox castle stage state), snapshot block `park = {slots = {slotId -> {activityId, ownerIds, startTime, phase times, castleStage}}}` on its own attribute if the payload is large, `FeatureFlags.Park`; Play date counter + once-a-day award (versioned additive save field; HatchProgress change reviewed on its own). |
| K2 Equipment art | Blender: swing set, slide, see-saw, sandbox (+ 3 castle stages), ball corner, kerb segments + 2 gateway posts, 2-3 benches with seats; low-poly, palette texture; upload via Open Cloud; Studio placement on the raycast lawn (or code-mounted like WorldAssets). |
| K3 Client | new `src/client/ParkClient.lua` (reads the park block, drives equipment motion: swing pendulum, see-saw tilt, castle stages, ball arcs, all from server times), new `src/client/ParkPetPose.lua` (+ `src/shared/ParkPoseData.lua`): per-activity Bear poses on the real rig (sit-swing, climb, slide, see-saw bob, dig/pat, bat ball, cheer), own-pet ring, a tiny park chip (name + Play date 0/3) shown only inside the kerb, distance tiers in `GardenPetVisual` (ObserverCap 6 / ObserverDistance 72). |

Order: K1 + K2 in parallel (different files), then K3 (needs K1's snapshot and K2's models). Then two-account test
with Spencer's second account, captures and film, code review, private publish.

## Rules

- Server owns everything that every viewer must agree on (who is on which slot, when each phase starts, castle
  stage); clients only animate from server times. No new per-frame remotes; no client-sent positions.
- Activities never start for a pet that is being petted, docked, greeting, napping or outside the park.
- A pet never holds a slot after its owner leaves the kerb or the server; slots self-expire at timeline end.
- Duo matching is random among eligible pairs, prefers different owners, and never pairs a pet with itself.
- No Stars for time in the park; Play date is once a day and server-awarded.
- Reduced Motion: equipment still moves (it is content) but camera-free; no extra particles.

## Edge cases

| Case | Expected |
|---|---|
| One player alone | Pet cycles solo slots (swing, slide, sandbox, ball); see-saw waits |
| Two players | Duo slots get used often; pets of the same owner never pair (one pet each anyway) |
| 12 pets, 9 slots | Extra pets mingle/greet on the lawn and wait for a slot |
| Owner sits on a bench | Pet stays in the park |
| Owner leaves mid-swing | Pet hops off, runs to owner; slot frees; duo partner finishes solo or ends |
| Partner leaves mid see-saw | Remaining pet hops off gracefully |
| Late joiner | Sees current slots mid-phase from the snapshot (times are absolute) |

## Tests

Server specs: `ParkDirector` (membership, slot exclusivity, duo pairing only with two eligible pets, prefers
different owners, release on leave/exit/busy, timelines end and free, castle stages, no starts when busy),
`PlayDate` (3 activities, once a day, additive save field), payload size with 12 actors. Client specs: `ParkClient`
(equipment motion from times, late join mid-phase), `ParkPetPose` (each activity pose valid on the real rig, no
allocation per frame). Studio: one-account solo cycle capture; two-account session with Spencer filmed (see-saw duo,
sandbox duo). Phone HUD capture 812x354.

## Not in v1

Tug, follow-the-leader, park-only toy, a resident park pet for empty servers, quick chat.

## Architect review changes (2026-11-13)

1. **Exempt park pets from the recalls:** `Garden:sync` (~line 206, owner moved > 0.65 studs sends non-follow Room
   pets home) and `decide` (~line 388, recall beyond 22 studs) must skip `actor.park`, like care.
2. **Greeting and wander skip park pets.**
3. **Hook:** one field `actor.park` set only by ParkDirector; in `decide()` right after the `actor.care` check:
   `if actor.park then self.park:tick(actor,input,now) continue end`; the director's schedule runs once after that
   loop, before `greeting`; `Garden:release` calls `self.park:release(actor)` (focus, reset, removal all go through
   release). Duos reuse the existing `pairs` generation check so a half-left pair is swept.
4. **Save:** no version bump; do NOT add to `Lifetime.Counters` (every name is required). Optional
   `playDate = {day, count}` valid when missing; `stats.parkGames` already exists and is incremented. Award through
   `HatchProgress.transact`, signature keyed by day; count only finished activities (kerb in/out can't farm).
5. **Membership hysteresis:** enter ~0.5 studs inside the kerb, leave ~1.5 studs outside (2 Hz samples).
6. **Snapshot:** park block stays inside the one `Snapshot` attribute (two attributes can arrive out of order);
   castle stage derived from `startTime`, not stored; measure payload with 12 pets at longest paths.
7. **Scheduler:** `waitingSince` per idle park pet, oldest first; oldest takes a free duo slot if an idle pet of a
   different owner waits (pairs with the oldest such), else a free solo slot; no same equipment twice in a row.
8. **Equipment:** code-mounted with `CreateMeshPartAsync` in `pcall` (grey box fallback), behind `FeatureFlags.Park`;
   visual meshes `CanCollide/CanQuery/CanTouch=false` (else `planPath` raycasts treat them as ground) plus invisible
   simple colliders for players; moving parts animated client-side only.
9. **Testing:** Studio local server with 2 players covers duos, partner leaving and late join; the director is
   specced with an injected clock and fake owners; the second-account session covers chat, real DataStore Play date
   and the 12-player cap.
10. **Flag off = v568 exactly:** `self.park` nil and the snapshot unchanged (spec it).
