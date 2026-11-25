-- Garden Dash's two places to wait (PLAY-DEN-BUILD-PLAN.md section 1, architect verdict applied). Shared and pure.
--   "meadow"  the waiting pad by the start (DashMount.gate): today's reaches and the rope ring rule, exactly.
--   "den"     the Play Den's waiting area (DenLayout.inWait: the room and the apron just out of the mouth). No clamp:
--             the rock walls are the rope. Out of it by more than Stray for StraySeconds is "Strayed"; the den closed is
--             "Closed" for anyone waiting there.
-- The server picks the anchor from where the root stands at the join (never from the client) and keeps it on the
-- director's seat or line record, so it ends with that record.
local Layout=require(script.Parent.DenLayout)
local Anchor={}
Anchor.Meadow="meadow"
Anchor.Den="den"
Anchor.Reach=1          -- a join, a promotion or the countdown: inside the waiting area grown by this much
Anchor.Stray=2          -- waiting: out by more than this ...
Anchor.StraySeconds=2   -- ... for this long leaves the line

-- `den`: the layout while the den is open, nil otherwise.
function Anchor.pick(at,den)
	if den~=nil and Layout.inWait(den,at,0)then return Anchor.Den end
	return Anchor.Meadow
end
-- A join, promotion or countdown from the den: ok, or false and why.
function Anchor.reach(den,at)
	if den==nil then return false,"Closed"end
	if Layout.inWait(den,at,Anchor.Reach)then return true end
	return false,"Far"
end
-- Waiting in the den (the line or a gather seat), one check. rec = {strayAt} kept by the caller. Returns ok, reason.
function Anchor.rule(rec,den,at,now)
	if den==nil then return false,"Closed"end
	if Layout.inWait(den,at,Anchor.Stray)then rec.strayAt=nil;return true end
	rec.strayAt=rec.strayAt or now
	if now-rec.strayAt>=Anchor.StraySeconds then return false,"Strayed"end
	return true
end
return table.freeze(Anchor)
