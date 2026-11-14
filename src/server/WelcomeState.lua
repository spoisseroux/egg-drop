-- Server-only Welcome timing. This owns no reward, DataStore, task or remote.
-- Call input() before processing ANY real play gesture. tryDemo() callback must
-- be synchronous/non-yielding; server processing order resolves the input race.
local Welcome={SkipAfter=3,ReplayAfter=8,DemoAfter=25}
Welcome.__index=Welcome
function Welcome.new(generation)
	return setmetatable({generation=generation,active=false,activeSeconds=0,idleSeconds=0,
		inputEpoch=0,drops=0,interacted=false,demoUsed=false,replayUsed=false,grantPending=false,alive=true},Welcome)
end
function Welcome:step(dt,active)
	if not self.alive then return end
	active=active==true
	if not active or not self.active then self.idleSeconds=0 end
	self.active=active
	if active and type(dt)=="number"and dt==dt and dt>0 then
		-- Host supplies elapsed server time; cap one frame after a stall.
		dt=math.min(dt,.5)
		self.activeSeconds+=dt;self.idleSeconds+=dt
	end
end
function Welcome:input()
	if not self.alive then return end
	self.inputEpoch+=1;self.idleSeconds=0;self.interacted=true
end
function Welcome:acceptedDrop()
	self.drops+=1;self.idleSeconds=0
end
function Welcome:replayDue()
	if not self.alive or not self.active or self.drops>0 or self.replayUsed or self.idleSeconds<Welcome.ReplayAfter then return false end
	self.replayUsed=true;return true
end
function Welcome:demoTicket()
	if not self.alive or not self.active or self.grantPending or self.drops>0 or self.demoUsed or self.idleSeconds<Welcome.DemoAfter then return nil end
	return {generation=self.generation,epoch=self.inputEpoch}
end
function Welcome:tryDemo(ticket,drop)
	if not ticket or not self:demoTicket()or ticket.generation~=self.generation or ticket.epoch~=self.inputEpoch then return false end
	-- No yield before or inside drop(). It rechecks phase/ownership and normal
	-- drop acceptance. Marking only accepted drops allows a busy tray to settle.
	if drop()~=true then return false end
	self.demoUsed=true;self:acceptedDrop();return true
end
function Welcome:canSkip(generation)
	return self.alive and self.active and self.generation==generation and self.activeSeconds>=Welcome.SkipAfter and not self.grantPending
end
function Welcome:requestGrant(source,generation)
	if not self.alive or self.generation~=generation or self.grantPending then return false end
	if source=="skip"then if not self:canSkip(generation)then return false end
	elseif source~="charge"then return false end
	self.grantPending=true;self.grantSource=source;return true
end
-- Leave this set through Retrying. Release only on a permanent noncommitted
-- rejection; host proves ownership/receipt separately after every yielding call.
function Welcome:grantRejected()if self.alive then self.grantPending=false end end
function Welcome:destroy()self.alive=false;self.active=false;self.inputEpoch+=1 end
function Welcome:snapshot()
	return {generation=self.generation,activeSeconds=self.activeSeconds,skipReady=self:canSkip(self.generation),
		grantPending=self.grantPending,demoUsed=self.demoUsed,inputEpoch=self.inputEpoch}
end
return Welcome
