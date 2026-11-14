# Remaining systems build — implementation and verification plan

2026-11-14 · Sol 6.1 High · awaiting independent architect review. User authorizes remaining accepted work during QA; **no publish**. Coordinator owns Studio, TODO, integration and final verification. This worker never starts Play, commits or deletes watched files. Save schema stays v11 with optional additive fields; historical ids/bits remain stable; init.client stays <=219 column-zero locals.

## 1. Bug-report sharding

Goal: independent users no longer contend on one global 400-report day key; cross-server limits for one user remain authoritative.

- `src/server/BugReportStore.lua`: 16 fixed deterministic user shards (`day_<day>_s<uid%16>`), existing cap applies per shard. Keep `dayKey(day)` as legacy helper; new `recordKey(day,userId)` and strict key parser. Freeze routing by immutable record timestamp and uid (pending retries never use current clock).
- Full lifecycle: recent reads legacy + all 16 shard keys for requested days, merges/dedupes immutable ids, sorts globally before limiting. Purge recognizes both exact legacy and shard key formats; erase traverses both using the existing owner-only `day_` list path. No report names or new personal data.
- Transition: before append, read current report day's legacy value; when it exists and contains records, **continue using that day's legacy key**. This preserves cross-server day/window/duplicate limits and existing cap through that historical day's rollout. Fresh days use stable shards. The next UTC day spreads load; this is intentionally not a live rewrite or record migration. Old-server coexistence is a deployment risk: newly published builds must replace stale servers at rollout so an old server cannot create a legacy key after new shards begin. No publish this session, so record this launch requirement explicitly.
- Tests `scripts/BugReports.spec.lua`: deterministic different-user spread; same uid in two Services shares limits/duplicates; full one shard doesn't refuse another; retry across midnight stable; ambiguous successful write dedupes immutable id; legacy-day routing and limit preservation; recent merged global order/dedupe/filter; purge and erase legacy+shards; malformed keys ignored; owner permissions unchanged.

## 2. Correct daily PlayDateDone telemetry

Goal: emit value 1 once for the transaction crossing the daily completion threshold, including same-session ambiguous-write recovery; never for pre-target or later lifetime batches.

- `src/server/PlayDateState.lua`: optional `completion={op,amount,balance}` on playDate, set when before<Target and after>=Target, retained within day and clock rollback, reset at true day rollover. Optional validator/sanitizer support; old v11 entries remain valid. Existing currency/bond reward semantics unchanged.
- `src/server/HatchProgress.lua`: expose `parkCompletion(handle,op)` proof predicate; no new required save fields.
- `src/server/init.server.lua`: single flight finalizer shared by immediate/recovered branches; read durable original completion amount/balance, clear flight/subtract once, log source only for positive original payment, event only when completion.op matches. Session flight is cleared before best-effort dispatch. Analytics cannot provide durable exactly-once delivery across crash/service failure; never claim that guarantee.
- Tests `scripts/PlayDate.spec.lua` plus focused host contract/spec: 0 emissions before target, threshold once, later batches zero, idempotent retry zero, recovery once, day rollover, expired flight no completion, future-day clock rollback preserves proof, unavailable Analytics does not alter reward or stall flush. Do not emit historical completions when loading old saves.

## 3. Multiple independent Pet Parks

Goal: the existing arrival park and a distinct approved second site run independent 9-slot playgrounds, with one owner's pet in only one park and one shared daily reward.

- `src/shared/ParkLayout.lua`: construct a layout from stable site id + center; preserve current public default fields/functions for fixtures. Add ordered Sites/ById and deterministic membership resolution (current park wins hysteresis overlap; otherwise first stable qualifying site). The second center is Astra's surveyed placement, not guessed now; only enable/mount approved geometry after collision/route evidence. Layout calculations ground each site independently.
- `src/shared/ParkPoseData.lua`: cached per-site data factory; common mesh ids/specs and local motion formulas, independently derived world anchors, roots, kerbs, colliders, benches and slide paths. No mutable global active layout.
- `src/server/ParkDirector.lua`: manager facade remains garden.park (`release/tick/schedule/snapshot`) and delegates to per-site directors. Membership transitions release old sessions before assigning new park; actor.park carries parkId. Site serials/session ids are namespaced. Each site's fairness, reservations, greeting cadence/cooldowns and duo waits are independent. Tick/sweep require exact parkId, never merely actor.park. No cross-site pair or reservation.
- `src/server/GardenState.lua`: keep single snapshot attribute; park becomes `{version=2,sites={id={slots=...}}}` with arrival legacy slots alias during migration. Actor snapshot may expose parkId for routing; no extra attributes that can arrive out of order. Flag off has unchanged absent park snapshot.
- `src/server/ParkMount.lua`: build site-named models with ParkId attributes from their own PoseData; preserve isParkPart filtering. Mount all approved sites through existing init.server call.
- `src/client/ParkClient.lua`, `ParkPetPose.lua`: per-site equipment/pose instances with cached layout/data, one facade used by RoomView/companions, own-pet ring/chip shown once at membership site; camera culling per site; late join routes exact site+slot, never first matching slot name. No per-frame instance creation. Compatibility default fixtures retained where useful.
- Tests existing ParkDirector/ParkPoseData/ParkMount/ParkClient/ParkPetPose + new multi-site fixtures: identical local slot/session names never collide; 12 actors split 6/6 all progress; one owner never assigned twice; transition mid-duo frees old slot/partner correctly; care/focus/contact/disconnect release; independent duo fairness; same owner finishes activities across sites, daily target/reward still once; flag off absent; payload under attribute size budget with 12 longest actor paths.
- Live gate coordinator: second-site continuous collision/height clearance, approaches and exterior ring, gateways and sight lines, two owners across sites then transition, late observer, 812x354 ring/chip, noon/night captures reviewed by Astra. Multi-client/device acceptance remains separate from unit fixtures.

## 4. Shared fetch with idle pets joining

Goal: one deliberate throw invites up to three idle pets in that same park, nearest pets with thrower's eligible pet preferred; everybody sees one server-owned winner and ball path.

- New `src/server/ParkFetch.lua` + `src/shared/ParkFetchMotion.lua`: per-site fetch state, bounded home/throw/chase/return/home timeline, up to three nearest idle eligible pets within 14 studs, stable owner-id tie break, winner by verified path arrival, paths preflight before reservation. Pet busy/equipment/greeting/care/focus never interrupted by another owner's throw. Initiator leave releases its pet; host departure cancels/re-homes ball. One ball/site, no physics ownership, no client position input.
- Integrate with site Director before autonomous scheduler so fetch reservations are exclusive and actors cannot take equipment simultaneously. Equipment ball corner remains separate existing activity; fetch gets quiet lawn targets validated against site bounds, keepouts and path planner. A completed fetch counts one Play date activity per pet only when it completes required participation; cancellation/self-expiry pays zero. Existing completed-activity callback owns all credit, so no new currency path.
- `init.server.lua`: parkThrow on GardenIntent with sequence and pet/character-generation validation; separate ParkResult acknowledgement; throw rate <=1/3 s and own-turn cooldown 6 s with others; idempotent bounded result replay. Reuse intent transport, never enable retired toyStart/toyJoin/toyCancel.
- Client: one 44px+ Throw control shown inside park, touch 44px+, F keyboard and R2 gamepad only when Room/no modal/no focus; state labels localized through UICopy. Coordinator/Astra must approve final placement against current HUD. New local ball visual sampled from snapshot server times, no per-frame remotes. All wiring remains inside existing module or do block to honor client local budget.
- Tests: solo fetch; 3 eligible of 6 idle pets with stable ties and preferred own pet; busy/existing sessions not stolen; distinct site throws concurrent; no fabricated position/pet ownership/stale generation; request duplicate does not start twice; cooldown/rate rejection; one unavailable path does not reserve partial group; winner/late join ball agree; owner leaves/contact/focus/care/disconnect releases; all participants gone returns home; expired/cancelled zero credit; finish callback exactly once; missing packet fields safely rejected. Live two-client throw/join/leave capture + phone HUD/Astra review remain gates.

## 5. Blip concept tooling (after Astra brief only)

Own new `scripts/build_blip_v3.py` and a sheet helper. Build procedural original D/E/F studies from Astra's brief, concept-only saved .blend + renders/contact sheet beside Bear at equal scale, 96/48 px silhouettes/expressions. No production export/import/refits, PetRigDefinitions or SecondPet flip until Spencer picks. Astra reviews actual renders and may require proportion iterations.

## Order and review gates

Independent architect review of this plan first. Implement reports + completion telemetry, code review/fix; then multi-site infrastructure once Astra's site brief exists, review/fix; fetch interaction follows same reviewed contract; concept tooling can run after creative brief. Coordinator runs Studio specs and visual gates, records exact results and pending live debt. No publish or commit is authorized to this worker.

### Creative-brief reconciliation
Astra exact CREATIVE-BRIEF.md supersedes the preliminary Call control: one Throw only, F/R2/touch. No new Call button/key or parkCall remote. Walking away and existing focus/contact control release participation. Second site stays survey-only until coordinator supplies exact verified site. Blip D/E/F exact geometry/material/camera values in creative brief govern first render pass.

### Independent review and final architecture updates
World Sol architect GO WITH CHANGES; required legacy reads fail closed, immutable report id dedup precedes caps, recovered Play date payment uses durable original amount/balance, exact site identities extend all matching/sweep paths, fetch generations update after own transitions. Coordinator prioritized concept renders first, delegated reports/onboarding client integration, and supplied surveyed development grove center (-38,-46). Choreography rotates PI, east gateway stays east independently. Fetch winner compares actual planned arrival seconds; completed return, not elapsed park time, owns credit. Welcome server integration added against independently reviewed ONBOARDING-PLAN and assigned modules. See SYSTEMS-PROGRESS for delivered state and test evidence.
