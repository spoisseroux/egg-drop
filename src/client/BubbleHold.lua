-- The need bubble's wrapper (BearNeeds' `bubble` dep), with the nest's hold (beta 14 QA Q2, WORLD-AND-NEST-LOOK 4): while
-- the napping egg's pill says a beat (Tucked in!, Sleep tight, A new egg...) the bubble waits, and comes back by itself
-- NestClient.BubbleAfter after it. The real NeedBubble is made the first time a bubble shows, as before.
--   make() -> a NeedBubble (set, hop, press, step, destroy); holds() -> true while the nest holds it back (nil: never).
-- With holds nil or always false every call is passed straight through: exactly the wrapper before this build.
-- state() -> {shown, held} for NestClient's own rule (the pill hides under a bubble that shows).
local Hold={};Hold.__index=Hold

function Hold.new(make,holds)
	return setmetatable({make=make,holds=holds,real=nil,icon=nil,want=false,held=false},Hold)
end
function Hold:holding()
	local holds=self.holds
	if holds==nil then return false end
	local ok,yes=pcall(holds)
	return ok and yes==true
end
-- words (onboarding v2's guide): the prompt in words beside the icon, or nil for the icon alone.
function Hold:set(icon,visible,words)
	self.icon,self.want,self.words=icon,visible==true,words
	if visible and not self.real then self.real=self.make()end
	self.held=self.want and self:holding()
	if self.real then self.real:set(icon,visible and not self.held,words)end
end
function Hold:hop()if self.real then self.real:hop()end end
function Hold:press()if self.real then self.real:press()end end
function Hold:step(dt)
	if self.want and self.real then
		local held=self:holding()
		if held~=self.held then self.held=held;self.real:set(self.icon,not held,self.words)end
	end
	if self.real then self.real:step(dt)end
end
function Hold:destroy()if self.real then self.real:destroy();self.real=nil end end
function Hold:state()return{shown=self.want and not self.held,held=self.held}end
return Hold
