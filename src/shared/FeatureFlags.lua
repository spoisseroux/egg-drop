-- Build flags (redesign build plan 2026-11-13). Features=false hides the Features tab
-- and drops the Feature Egg from the hatch list; saved features keep rendering.
-- DayNight=false (batch 2026-11-13, W1) locks the garden clock to dusk: HollowClock.sample
-- returns the dusk state and the world keeps the WorldDusk lighting and sky.
-- Park=false (Pet Park K1, 2026-11-13) leaves GardenState without a ParkDirector: no playground
-- membership, slots or Play date, and the garden snapshot exactly as before. ON for the private
-- two-account test build (2026-11-13); confirm with Spencer before any public publish.
return table.freeze({Features=false,DayNight=false,Park=true})
