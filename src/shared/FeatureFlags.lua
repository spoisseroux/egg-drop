-- Build flags (redesign build plan 2026-11-13). Features=false hides the Features tab
-- and drops the Feature Egg from the hatch list; saved features keep rendering.
-- DayNight=false (batch 2026-11-13, W1) locks the garden clock to dusk: HollowClock.sample
-- returns the dusk state and the world keeps the WorldDusk lighting and sky.
return table.freeze({Features=false,DayNight=false})
