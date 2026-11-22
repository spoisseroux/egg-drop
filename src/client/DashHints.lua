-- Garden Dash first-race helper (WORLD-PLAN-2026-11-22 section 4): looks only. "Hold Dash!" on the first straight, "Tap Jump
-- now!" when a press would clear the hoop. Three hints at most, and none after one clean jump. This session only:
-- nothing is saved (the race that is first is DashClient:newRacer). Pure; one per race.
local Hints={};Hints.__index=Hints
Hints.Max=3
Hints.DashAfter=.3 -- seconds after GO
Hints.DashSeconds=1.4
Hints.DashClear=90 -- ticks before a take-off spot: the straight is over, look at the hoop
Hints.JumpTicks=30 -- inside the clear window, so a press as soon as it is read is never a Trip

function Hints.new()
	return setmetatable({shown=0,time=0,done=false,hint=nil,jumpFor=nil,dashed=false},Hints)
end
function Hints:show(id)
	if self.hint==id then return end
	if self.shown>=Hints.Max then return end
	self.shown+=1
	self.hint=id
end
-- A frame: racing, ticks to the next take-off (Sim.nextJump, or nil), which jump it is, Dash held, the Predict news.
-- Returns "jump", "dash" or nil.
function Hints:step(dt,racing,ticks,jump,dashing,news)
	if self.done then return nil end
	if news=="perfect"or news=="clear"then
		self.done,self.hint=true,nil
		return nil
	end
	if not racing then self.hint=nil;return nil end
	self.time+=dt
	if ticks and ticks<=Hints.JumpTicks and ticks>0 then
		if self.jumpFor~=jump then
			self.jumpFor=jump
			self.hint=nil
			self:show("jump")
		end
	elseif self.hint=="jump"then self.hint=nil end
	if self.hint~="jump"then
		local straight=self.time>=Hints.DashAfter and self.time<=Hints.DashAfter+Hints.DashSeconds
			and(ticks==nil or ticks>Hints.DashClear)and jump==1
		if dashing then self.dashed=true end
		if straight and not self.dashed then self:show("dash")
		elseif self.hint=="dash"then self.hint=nil;self.dashed=true end
	end
	if self.hint==nil and self.shown>=Hints.Max then self.done=true end
	return self.hint
end
return Hints
