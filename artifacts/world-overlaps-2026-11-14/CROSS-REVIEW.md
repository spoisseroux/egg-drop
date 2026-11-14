# Independent review of other Sol's park/fetch implementation

Reviewer: Sol world lane (not the implementer), 14 November 2026. Source review only; coordinator runs Studio specs. **GO**, with no required correctness blocker found in the reviewed changes.

- `ParkDirector.lua:96` preflights same-site/idle/nonreserved actors and occupied slots before starting; release/tick/schedule/sweep/partnerSoon/greetings route park identities, with independent session ids and late-join site snapshots. Arrival legacy alias is not used for v2 routing.
- `ParkFetch.lua:41` derives membership and participants server-side; all accepted chase/return plans preflight before reservations; busy equipment/care/focus peers are not stolen. Generated transitions update expected generations. `:124` cancels host/winner interruption or expiry, removes other interrupted participants, and counts completion only once at the final stage. Original retired toy protocol stays disabled.
- `ParkThrowHost.lua:4` validates Room, selected pet, character and companion generations, integer sequence, idempotent cached acknowledgement and 3/6-second request/success timing. `init.server.lua:802` derives owner from the sending Player and refreshes that owner's authoritative garden input; no client positions/paths/winner input is accepted.
- `ParkFetchMotion` samples absolute server snapshot times; no per-frame remotes. `ParkThrowControl` has 92x48 touch target, F/R2 shortcuts, one pending intent with bounded retry, generation data from the owned actor, inactive hiding and destroy/disconnect cleanup. Integration stays inside module/existing do wiring.

Nonblocking observation: the winner compares `plan.length` rather than `plan.seconds` in ParkFetch. Incoming velocity/path shaping may make shortest length differ from first actual arrival. If the visible result is intended as a race, compare verified arrival time; all successful participants receive the same activity credit, so this is not a currency/ownership exploit.

Remaining live gates: actual two-client throw/automatic join/owner leave and late observer; phone placement/gamepad behavior; crowded clear-lane/path readability; final snapshot byte budget and service-backed Play date save/rejoin. Source and isolated fixtures cannot establish those outcomes.
