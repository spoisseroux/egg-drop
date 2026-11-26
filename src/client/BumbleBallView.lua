-- Bumble balls: one ball's drawn state on this client (GARDEN-PLAY-BRIEF section 1 "Networking feel"). Pure apart from
-- the shared sim: no instances, so the specs drive it with fake clocks.
--   predict(record)  my kick: drawn from this frame, no blend; the record waits for the server's answer
--   receive(record)  a broadcast: someone else's kick blends in over Balls.Blend from where the ball is drawn (joining
--                    the arc part-way along); my own accepted kick keeps the prediction's timing when it matches; a newer
--                    record that lands while mine is in flight is held until my answer
--   refuse(record)   my kick refused: blend to the server's record over Balls.Correct
--   step(now, clock) the drawn position, its fade scale, whether it still moves, the plan's events since last step
-- A gap over Balls.FadeGap is never a slide: shrink, move, grow over Balls.Fade. A late packet costs a later start,
-- never a stutter: the offset decays from wherever the ball was drawn. When a plan ends somewhere other than the
-- server's rest spot (a device rounding differently), it blends to the server's over Balls.Correct.
local Shared=game:GetService("ReplicatedStorage").Shared
local Balls=require(Shared.BumbleBalls)
local Motion=require(Shared.BallMotion)
local View={};View.__index=View
View.Pending=2.5        -- my kick's answer is given up on after this (seconds, clock)
View.Recent=.35         -- a broadcast this young plays its kick sound

function View.new(id,world)
	return setmetatable({id=id,world=world,offset=Vector3.zero,blendAt=0,blendFor=0,cursor=0},View)
end
local function same(a,b)
	return(a.origin-b.origin).Magnitude<1e-4 and(a.velocity-b.velocity).Magnitude<1e-4 and a.kind==b.kind
end
View.same=same

-- Adopt `record`. how: "instant" (no blend), "blend" (Balls.Blend) or "correct" (Balls.Correct).
function View:set(record,now,clock,how)
	local plan=Motion.plan(record,self.world)
	local target=Motion.at(plan,now-record.startTime)
	self.record,self.plan=record,plan
	self.cursor=math.max(0,now-record.startTime)
	self.restFix=record.rest~=nil and(plan.rest-record.rest).Magnitude>Balls.Keep
	self.fixed=false
	if not self.drawn then self.drawn=target;self.offset=Vector3.zero;return "keep"end
	local gap=(self.drawn-target).Magnitude
	local mode=Balls.blendMode(gap)
	if mode=="keep"then self.offset=Vector3.zero
	elseif mode=="fade"then self.offset=Vector3.zero;self.fadeAt,self.fadeFrom=clock,self.drawn
	else
		self.offset=self.drawn-target;self.blendAt=clock
		self.blendFor=if how=="instant"then .05 elseif how=="correct"then Balls.Correct else Balls.Blend
	end
	return mode
end

function View:predict(record,now,clock,seq)
	self.pending={seq=seq,record=record,at=clock}
	self.deferred=nil
	return self:set(record,now,clock,"instant")
end

-- A broadcast kick. Answers the cue to play: "kick", "bunt" or nil.
function View:receive(record,me,now,clock)
	local pending=self.pending
	if pending then
		if record.by==me and record.seq==pending.seq then
			self.pending,self.deferred=nil,nil
			if self.record==pending.record and same(pending.record,record)then
				-- Accepted as sent: keep the prediction's clock (the same path, so the same rest spot), take n and rest.
				pending.record.n=record.n
				pending.record.rest=record.rest
				self.restFix=record.rest~=nil and(self.plan.rest-record.rest).Magnitude>Balls.Keep
			else
				self:set(record,now,clock,"correct")
			end
			return nil
		end
		if not self.deferred or record.n>self.deferred.n then self.deferred=record end
		return nil
	end
	if self.record and record.n<=self.record.n then return nil end
	self:set(record,now,clock,"blend")
	if record.bunt then return "bunt"end
	if record.kind~="home"and now-record.startTime<View.Recent then return "kick"end
	return nil
end

-- My kick refused (seq matches): the server's record over Balls.Correct.
function View:refuse(seq,record,now,clock)
	if not self.pending or self.pending.seq~=seq then return false end
	self.pending,self.deferred=nil,nil
	self:set(record,now,clock,"correct")
	return true
end

-- A joiner's (or a re-enabled client's) snapshot: ignored while my kick is in flight.
function View:state(record,now,clock)
	if self.pending then return false end
	if self.record and record.n<self.record.n then return false end
	self:set(record,now,clock,"blend")
	return true
end

-- My answer never came (a dropped server, a refused packet): whatever came meanwhile, over Balls.Correct.
function View:expire(now,clock)
	if not self.pending or clock-self.pending.at<View.Pending then return false end
	local deferred=self.deferred
	self.pending,self.deferred=nil,nil
	if deferred then self:set(deferred,now,clock,"correct")end
	return true
end

-- drawn position, fade scale (1 = full size), active (moving, blending or fading), events since the last step.
function View:step(now,clock)
	local record=self.record
	if not record then return nil,1,false,{}end
	local t=now-record.startTime
	local target,_,moving=Motion.at(self.plan,t)
	if self.restFix and not moving then
		target=record.rest
		if not self.fixed then
			self.fixed=true
			local from=self.drawn or target
			self.offset=from-target;self.blendAt=clock;self.blendFor=Balls.Correct
		end
	end
	local offset=Balls.offset(self.offset,clock-self.blendAt,self.blendFor)
	if offset.Magnitude<1e-4 then self.offset=Vector3.zero;offset=Vector3.zero end
	local drawn=target+offset
	local scale=1
	if self.fadeAt then
		local s,arrived=Balls.fade(clock-self.fadeAt,Balls.Fade)
		scale=s
		if not arrived then drawn=self.fadeFrom end
		if clock-self.fadeAt>=Balls.Fade then self.fadeAt,self.fadeFrom=nil,nil end
	end
	local events={}
	if t>self.cursor then
		for _,event in ipairs(self.plan.events)do
			if event.t>self.cursor and event.t<=t then table.insert(events,event)end
		end
		self.cursor=t
	end
	self.drawn=drawn
	return drawn,scale,moving or offset~=Vector3.zero or self.fadeAt~=nil,events
end
return View
