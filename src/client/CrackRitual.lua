-- The First Hatch (Onboard "crack", artifacts/onboarding-2026-11-26/PLAN.md, Fable FIRST-3-MINUTES item 1): the
-- player cracks the Bear's egg. Pure clock logic for HatchCinematic's per-reveal clock hold: the reveal's clock stops
-- just before each crack beat (the ASMR layer's crack1, crack2 and the creak before the pop) until a tap releases it,
-- so the beat's sound and buzz fire in the frame after the tap (HatchCinematic plays them off its own clock: never
-- twice). Untouched, each stop releases itself after Auto seconds, so nothing waits. No reward hangs on a tap: the
-- Bear is saved before this reveal plays.
local Ritual={Auto=1.1,Lead=.01}
Ritual.__index=Ritual
-- Static hook (init.client): the first accepted tap of a ritual, for the "EggTapped" event. Called once per ritual.
Ritual.onFirstTap=nil

-- events: the ASMR layer (HatchAsmr.schedule), sorted by `at`. Returns nil when there is nothing to hold on.
function Ritual.stopsFrom(events)
	local stops={}
	if type(events)~="table"then return stops end
	local pop
	for _,e in ipairs(events)do if e.layer=="pop"then pop=e.at end end
	for _,e in ipairs(events)do
		if e.layer=="crack1"or e.layer=="crack2"then table.insert(stops,e.at)
		elseif(e.layer=="creak"or e.layer=="creakLong")and pop and e.at<pop and e.at>(stops[#stops]or 0)+.05 then
			table.insert(stops,e.at)
		end
	end
	-- a creak under crack2 (at crack2 + .03) is not its own stop; keep at most three, in order
	table.sort(stops)
	local out={}
	for _,at in ipairs(stops)do if #out<3 and(#out==0 or at-out[#out]>.05)then table.insert(out,at)end end
	return out
end

-- auto (optional): this ritual's own wait before a stop lets go by itself. Onboarding v2 step 3 (the egg in the garden)
-- waits FirstHatchStory's 7 s (ONBOARDING-V2: "Ritual.Auto = 1.1 on the first hatch" was too fast for the taps to
-- matter); the reveal's own ritual keeps Ritual.Auto.
function Ritual.new(stops,clock,auto)
	if type(stops)~="table"or #stops==0 then return nil end
	return setmetatable({stops=stops,index=1,since=nil,taps=0,clock=clock or os.clock,released={},
		auto=if type(auto)=="number"and auto>0 then auto else nil},Ritual)
end
-- How long the clock has waited at the stop it is held at (0 when not held).
function Ritual:waited()return if self.since then self.clock()-self.since else 0 end
-- Is the clock held at this age? Advances past a stop when it is released (tap or Auto).
function Ritual:hold(age)
	local at=self.stops[self.index]
	if not at or age<at-Ritual.Lead then self.since=nil;return false end
	if self.released[self.index]then self.index+=1;self.since=nil;return self:hold(age)end
	local now=self.clock()
	self.since=self.since or now
	if now-self.since>=(self.auto or Ritual.Auto)then self.released[self.index]=true;self.index+=1;self.since=nil;return false end
	return true
end
-- Waiting for a tap right now (the "Tap the egg" prompt)?
function Ritual:waiting()return self.since~=nil and self.stops[self.index]~=nil end
-- The longest step the clock may take from `age` this frame: it stops at the next unreleased crack (code review of
-- the First Hatch: a 16 to 100 ms frame used to jump past the stop, so the crack played before the hold and the tap
-- released nothing). A released stop ahead does not cap.
function Ritual:cap(age,dt)
	local index=self.index
	while self.released[index]do index+=1 end
	local at=self.stops[index]
	if not at then return dt end
	local stop=at-Ritual.Lead
	if age<stop and age+dt>stop then return math.max(0,stop-age)end
	return dt
end
-- A tap: releases the stop the clock is at or running to (so an early tap is never lost); more taps before the clock
-- reaches it are taken (true) but release nothing, so mashing never cracks ahead or skips the pop (code review).
-- False only when the ritual is done.
function Ritual:tap()
	if self:done()then return false end
	if self.released[self.index]then return true end
	local index=self.index
	self.released[index]=true
	self.taps+=1
	if self.taps==1 and Ritual.onFirstTap then pcall(Ritual.onFirstTap)end
	return true
end
function Ritual:done()return self.stops[self.index]==nil end
return Ritual
