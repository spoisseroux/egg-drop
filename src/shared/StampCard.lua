-- Stamp card (PLAY-FOREVER-SCOPE-2026-11-13 section 3.5 #3, BUILD-PLAN F1). One stamp per
-- day played, claimed through the existing `daily` gift. The count never resets and a
-- missed day costs nothing. Seven stamps pay 4,4,5,5,6,6,12 = 42 a week, the same as
-- the old flat 6 x 7. No streak, no penalty, no paid element.
local Stamp={}
Stamp.Rewards=table.freeze({4,4,5,5,6,6,12})
Stamp.Length=#Stamp.Rewards

local function count(stamps)
	return if type(stamps)=="number"and stamps==stamps and stamps>=0 and stamps%1==0 then stamps else 0
end
-- Position (1..7) on the card of the stamp that would be added next.
function Stamp.position(stamps)return count(stamps)%Stamp.Length+1 end
-- The reward for the stamp being added when `stamps` are already on the save.
function Stamp.reward(stamps)return Stamp.Rewards[Stamp.position(stamps)]end
-- Stamps already on the current card (0..6).
function Stamp.onCard(stamps)return count(stamps)%Stamp.Length end

return table.freeze(Stamp)
