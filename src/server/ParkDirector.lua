-- Pet Park playground director (BUILD-PLAN 2026-11-13, slice K1). Plugged into GardenState the
-- way GardenCare is: `garden.park` exists only when FeatureFlags.Park is on (attach returns nil
-- otherwise, so the snapshot stays exactly as before).
--
-- Ownership: `actor.park` is set and cleared only here. It marks a pet whose owner stands inside
-- the kerb (or sits on a park bench), with hysteresis from the 2 Hz owner sample. GardenState
-- hands such pets to Director:tick instead of follow/wander/recall; Garden:release calls
-- Director:release, so focus, petting, care, reset and removal all free the pet's slot.
--
-- Sessions: one activity on one piece of equipment, one or two pets. Times are absolute server
-- times (walkStart, startTime = play start, endTime); clients animate from them. Duo sessions
-- record each participant's actor generation and are swept when a half changes, the same way
-- GardenState sweeps greeting pairs (a superseded half never keeps a slot).
-- No rewards here: a finished activity calls options.finished(ownerId, activityId, sessionId)
-- and the host (init.server) counts it toward Play date.
local Shared=game:GetService("ReplicatedStorage").Shared
local A=require(Shared.GardenActivity)
local Park=require(Shared.ParkLayout)
local Catalog=require(Shared.ParkActivities)
local Director={};Director.__index=Director
local ZERO=Vector3.zero
Director.GreetEvery=6
Director.GreetCooldown=45
Director.GreetReach=12
-- QA Q4: a pet queueing longer than this for a slot is not greeted (a greeting makes it ineligible,
-- so the oldest pet kept missing every slot that freed while it greeted: 89 s waits with 12 pets).
Director.GreetPatience=8
-- QA Q4: a pet whose owner just walked in comes in at the follow catch-up pace (GardenLayout.
-- CatchupSpeed), to a point inside the kerb on the owner's side, instead of strolling at 3 studs/s
-- to the far rim point on its own side.
Director.EnterSpeed=9
-- QA Q4 (2-account test: no duo ever started): with few pets in the park two pets rarely go idle
-- at the same moment, so each kept taking solos. An idle pet now waits up to DuoWait seconds for
-- another owner's pet that is about to be free (its session or rest ends within the window) when a
-- duo it could share is free or will be freed by that pet. Only while DuoWaitMembers or fewer pets
-- are in the park (a busy park pairs on its own).
Director.DuoWait=18 -- one activity (~13 s) plus the rest after it (3 s) and a short walk
Director.DuoWaitMembers=4

local function horizontal(a,b)return Vector2.new(a.X-b.X,a.Z-b.Z).Magnitude end
local function angle(a,b)return math.atan2(math.sin(b-a),math.cos(b-a))end
local function pairKey(a,b)return if a<b then a..":"..b else b..":"..a end

-- Returns the director when options.enabled is true and the active world has a park; otherwise
-- leaves garden.park nil and returns nil.
function Director.attach(garden,options)
	options=options or {}
	if options.enabled~=true or not Park.Enabled then garden.park=nil;return nil end
	local director=Director.new(garden,options)
	garden.park=director
	return director
end
function Director.new(garden,options)
	local generator=Random.new()
	return setmetatable({garden=garden,options=options,sessions={},serial=0,nextGreetAt=0,cooldowns={},
		random=options.random or function()return generator:NextNumber()end},Director)
end
function Director:clock()return(self.options.now or self.garden.options.now)()end
function Director:busy(actor)return self.options.busy~=nil and self.options.busy(actor.ownerId)==true end

-- Idle in the park and free to take a slot now.
function Director:eligible(actor,now)
	local park=actor.park
	if not park or park.session or park.state~="idle"or now<(park.nextPickAt or 0)then return false end
	if actor.mode~="Room"or actor.care or actor.pairId or actor.action=="nookApproach"or actor.action=="nookRest"then return false end
	local input=self.garden.inputs[actor.ownerId]
	if not input or not input.alive or self:busy(actor)then return false end
	return Park.inside(self.garden:position(actor,now),0)
end

-- Slot ids used by live sessions, and equipment held by an exclusive session.
function Director:occupancy()
	local slots,equipment={},{}
	for _,session in pairs(self.sessions)do
		for _,slotId in pairs(session.slots)do slots[slotId]=session.id end
		if Catalog.ById[session.activity].exclusive then equipment[session.equipment]=session.id end
	end
	return slots,equipment
end
function Director:freeSlots(activity,usedSlots,usedEquipment)
	if activity.exclusive and usedEquipment[activity.equipment]then return nil end
	local free={}
	for _,set in ipairs(activity.slotSets)do
		local open=true
		for _,slotId in ipairs(set)do if usedSlots[slotId]then open=false;break end end
		if open then table.insert(free,set)end
	end
	if #free==0 then return nil end
	return free[math.floor(self.random()*#free)+1]
end

-- Preflight every participant's walk, then reserve the slots and start the approach.
function Director:start(activity,slotIds,actors,now)
	local planner=self.garden.options.planPath or A.plan
	local plans,arrive={},now
	for index,actor in ipairs(actors)do
		local slot=Park.Slots[slotIds[index]]
		local sample=A.sample(actor,now)
		local from=self.garden:position(actor,now)
		local path,seconds=planner(from,slot.approach,sample and sample.velocity or ZERO,Park.WalkSpeed,0,sample and sample.yaw or actor.yaw or 0,nil,ZERO)
		local last=path and path[#path]
		if not last or(A.vector(last.to)-slot.approach).Magnitude>=.1 then return false end
		for _,leg in ipairs(path)do if leg.safetyStop then return false end end
		plans[index]={path=path,seconds=seconds,slot=slot}
		arrive=math.max(arrive,now+seconds)
	end
	local startTime=arrive+Catalog.StartBuffer
	if activity.period and not activity.exclusive then
		-- Two swings side by side share one beat.
		for _,other in pairs(self.sessions)do
			if other.activity==activity.id and other.endTime>startTime then startTime=Catalog.alignedStart(activity,startTime,other.startTime);break end
		end
	end
	self.serial+=1
	local session={id=self.serial,activity=activity.id,equipment=activity.equipment,ownerIds={},slots={},generations={},
		walkStart=now,startTime=startTime,endTime=startTime+activity.duration}
	self.sessions[session.id]=session
	for index,actor in ipairs(actors)do
		local plan=plans[index]
		local wait=startTime-(now+plan.seconds)
		if wait>.0001 then
			local last=plan.path[#plan.path]
			local hold=assert(A.leg(plan.slot.approach,plan.slot.approach,ZERO,ZERO,Park.WalkSpeed,wait,last.yaw+last.turn))
			hold.duration=wait;table.insert(plan.path,hold)
		end
		self.garden:transition(actor,"investigate",plan.slot.approach,0,Catalog.ApproachAction,nil,nil,{path=plan.path,duration=startTime-now})
		table.insert(session.ownerIds,actor.ownerId)
		session.slots[actor.ownerId]=plan.slot.id
		session.generations[actor.ownerId]=actor.generation
		local park=actor.park
		park.session,park.slotId,park.state=session.id,plan.slot.id,"approach"
		park.started=(park.started or 0)+1
	end
	self.garden.dirty=true
	return true
end

-- The play path: an optional pivot to the slot heading, then a hold at the phase point or a timed
-- move when the phase point changes (down the slide chute). Consecutive holds at one point merge
-- into one leg (phases come from the park block, not the path), which keeps the snapshot small.
function Director:play(actor,session,now)
	local activity=Catalog.ById[session.activity]
	local slot=Park.Slots[session.slots[actor.ownerId]]
	local sample=A.sample(actor,now)
	local position=slot.approach
	local yaw=sample and sample.yaw or actor.yaw or 0
	local path,spent={},0
	local turn=angle(yaw,slot.yaw)
	if math.abs(turn)>=.12 then
		spent=math.min(activity.phases[1].duration*.5,math.max(.12,math.abs(turn)*1.5/12))
		table.insert(path,{from=A.pack(position),to=A.pack(position),v0={0,0,0},v1={0,0,0},duration=spent,yaw=yaw,turn=turn,turnDuration=spent,pivot=true})
	end
	yaw=slot.yaw
	for index,step in ipairs(activity.phases)do
		local target=slot[step.at or "approach"]or slot.approach
		local duration=if index==1 then step.duration-spent else step.duration
		local delta=target-position
		local previous=path[#path]
		if delta.Magnitude>.01 then
			local leg=assert(A.leg(position,target,ZERO,ZERO,math.max(Park.WalkSpeed,3*delta.Magnitude/duration+.01),duration,yaw))
			leg.duration=duration;table.insert(path,leg)
			yaw=math.atan2(delta.X,delta.Z)
		elseif previous and not previous.pivot and previous.turn==0 and(A.vector(previous.from)-position).Magnitude<.001 and(A.vector(previous.to)-position).Magnitude<.001 then
			previous.duration+=duration
		else
			local leg=assert(A.leg(position,position,ZERO,ZERO,Park.WalkSpeed,duration,yaw))
			leg.duration=duration;table.insert(path,leg)
		end
		position=target
	end
	self.garden:transition(actor,"play",position,0,activity.action,nil,nil,{path=path,duration=session.endTime-now})
	-- The play path is anchored to the session clock, not to this (up to 0.5 s late) tick.
	actor.startTime,actor.endTime=session.startTime,session.endTime
	actor.from,actor.yaw=A.pack(slot.approach),slot.yaw
	session.generations[actor.ownerId]=actor.generation
	actor.park.state="play"
end

-- counted=false frees a session without a Play date credit (self-expiry).
function Director:finish(session,now,counted)
	if self.sessions[session.id]~=session then return end
	self.sessions[session.id]=nil;self.garden.dirty=true
	for _,ownerId in ipairs(session.ownerIds)do
		local actor=self.garden.actors[ownerId]
		local park=actor and actor.park
		if park and park.session==session.id then
			park.session,park.slotId,park.state,park.last=nil,nil,"idle",session.equipment
			park.nextPickAt=now+Catalog.RestAfter;park.waitingSince=park.nextPickAt;park.nextWanderAt=park.nextPickAt
			if counted~=false then
				park.finished=(park.finished or 0)+1
				self.garden:transition(actor,"rest",self.garden:position(actor,now),Catalog.RestAfter,"wanderPause")
				if self.options.finished then self.options.finished(ownerId,session.activity,session.id)end
			end
		end
	end
end

-- Remove one participant from a session. A duo with a solo variant continues as that solo on
-- the same timeline (the left slot stays locked to the session); the see-saw partner hops off.
function Director:drop(session,ownerId,now)
	local index=table.find(session.ownerIds,ownerId)
	if index then table.remove(session.ownerIds,index)end
	session.slots[ownerId]=nil;session.generations[ownerId]=nil
	self.garden.dirty=true
	if #session.ownerIds==0 then self.sessions[session.id]=nil;return end
	local activity=Catalog.ById[session.activity]
	if activity.kind~="duo"then return end
	if activity.solo then session.activity=activity.solo;return end
	self.sessions[session.id]=nil
	for _,id in ipairs(session.ownerIds)do
		local other=self.garden.actors[id]
		local park=other and other.park
		if park and park.session==session.id then
			park.session,park.slotId,park.state,park.last=nil,nil,"hop",session.equipment
			park.nextPickAt=now+Catalog.HopOffSeconds+Catalog.RestAfter;park.waitingSince=park.nextPickAt;park.nextWanderAt=park.nextPickAt
			self.garden:transition(other,"rest",self.garden:position(other,now),Catalog.HopOffSeconds,Catalog.HopOffAction)
		end
	end
end

-- Called by Garden:release (focus, petting, care, reset, removal, leaving the park).
function Director:release(actor)
	local park=actor.park
	if not park or not park.session then return end
	local now=self:clock()
	local session=self.sessions[park.session]
	park.session,park.slotId=nil,nil
	if park.state=="approach"or park.state=="play"then park.state="idle"end
	park.nextPickAt=math.max(park.nextPickAt or 0,now+2);park.waitingSince=park.nextPickAt
	if session then park.last=session.equipment;self:drop(session,actor.ownerId,now)end
end

-- The pet's owner left the kerb, the server or Room mode: free everything, run back to the owner.
function Director:leave(actor,input,now)
	self.garden:release(actor)
	actor.park=nil
	if input and input.alive and actor.mode=="Room"then
		actor.idleSince,actor.wanderCount,actor.nextWanderAt=now,0,nil
		self.garden:transition(actor,"follow",input.anchor,.5)
	end
end

-- End a greeting a park pet took part in; park pets stay in the park, others resume as usual.
function Director:endGreeting(actor,now)
	local pair=self.garden.pairs[actor.pairId]
	if not pair then actor.pairId=nil;return end
	self.garden.pairs[pair.id]=nil
	for _,id in ipairs(pair.owners)do
		local member=self.garden.actors[id]
		if member and member.pairId==pair.id then
			member.pairId=nil
			if member.park then
				member.park.nextWanderAt=now+1.5
				self.garden:transition(member,"rest",self.garden:position(member,now),1.5,"wanderPause")
			else
				local input=self.garden.inputs[id]
				if input then self.garden:resume(member,input,pair.prior[id])end
			end
		end
	end
end

-- Where a pet joining its owner walks to: two studs toward the centre from an owner well inside,
-- else the point at 0.75 of the way out on the owner's ray; clear of equipment and benches.
function Director.entryPoint(ownerPosition)
	local target
	if Park.inside(ownerPosition,-2.5)then
		local toCentre=Vector3.new(Park.Center.X-ownerPosition.X,0,Park.Center.Z-ownerPosition.Z)
		local step=if toCentre.Magnitude>2 then toCentre.Unit*2 else ZERO
		local x,z=ownerPosition.X+step.X,ownerPosition.Z+step.Z
		target=Vector3.new(x,Park.ground(x,z),z)
	else
		target=Park.toward(ownerPosition,.75)
	end
	if Park.clearOfKeepout(target,.3)then return target end
	for _,scale in ipairs({.6,.45,.3,.15})do
		local candidate=Park.toward(ownerPosition,scale)
		if Park.clearOfKeepout(candidate,.3)then return candidate end
	end
	return target
end

-- The pet is outside the kerb while its owner is in the park: walk in beside the owner.
function Director:enter(actor,input,now)
	local from=self.garden:position(actor,now)
	local target=Director.entryPoint(input.position)
	local sample=A.sample(actor,now)
	local velocity=sample and sample.velocity or ZERO
	local yaw=sample and sample.yaw or actor.yaw or 0
	local speed=math.clamp(horizontal(from,target)/2,Park.WalkSpeed,Director.EnterSpeed)
	local planner=self.garden.options.planPath or A.plan
	local path,seconds=planner(from,target,velocity,speed,0,yaw,nil,ZERO)
	local last=path and path[#path]
	local valid=last~=nil and(A.vector(last.to)-target).Magnitude<.1
	if valid then for _,leg in ipairs(path)do if leg.safetyStop then valid=false;break end end end
	-- Pets are visuals and the park lawn is flat: the plain curve planner always reaches the point.
	if not valid then path,seconds=A.plan(from,target,velocity,speed,0,yaw,nil,ZERO)end
	self.garden:transition(actor,"investigate",target,0,"wander",nil,nil,{path=path,duration=seconds})
	actor.park.nextWanderAt=now+seconds+1
end

-- Idle park pets wander inside the kerb (never to the nook anchors) and pause between strolls.
function Director:mingle(actor,input,now)
	local park=actor.park
	-- QA Q4: a pet left outside the kerb (it was trailing its owner, resting, or wandered out) comes
	-- in at once, whatever it was doing, unless it is already walking in.
	local here=self.garden:position(actor,now)
	if not Park.inside(here,-1)then
		local heading=A.vector(actor.to)
		local walkingIn=actor.action=="wander"and now<actor.endTime and heading~=nil and Park.inside(heading,-1)
		if not walkingIn then self:enter(actor,input,now)end
		return
	end
	if actor.action=="wander"and now>=actor.endTime then
		self.garden:transition(actor,"rest",self.garden:position(actor,now),math.max(1,(park.nextWanderAt or now)-now),"wanderPause")
		return
	end
	if now<actor.endTime and actor.behavior~="follow"then return end
	if now<(park.nextWanderAt or 0)then return end
	park.nextWanderAt=now+3+self.random()*3
	local position=here
	local target
	do
		for _=1,6 do
			local heading=self.random()*math.pi*2
			local radius=3+self.random()*5
			local x,z=position.X+math.cos(heading)*radius,position.Z+math.sin(heading)*radius
			local candidate=Vector3.new(x,Park.ground(x,z),z)
			if Park.inside(candidate,-2)and Park.clearOfKeepout(candidate,.5)then
				if self.garden.options.validWander then candidate=self.garden.options.validWander(input,candidate,position)end
				if typeof(candidate)=="Vector3"then target=candidate;break end
			end
		end
	end
	if target then self.garden:transition(actor,"investigate",target,0,"wander")
	elseif actor.action~="wanderPause"or now>=actor.endTime then self.garden:transition(actor,"rest",position,1.5,"wanderPause")end
end

-- GardenState:decide hands every actor with actor.park here instead of its own branches.
function Director:tick(actor,input,now)
	local park=actor.park
	if actor.mode~="Room"or not input or not input.alive or not Park.member(input.position,true)then self:leave(actor,input,now);return end
	if actor.pairId then
		if now>=actor.endTime then self:endGreeting(actor,now)end
		return
	end
	if self:busy(actor)then
		-- Being petted: give up the slot at once, hold still, and pick nothing until it ends.
		if park.session then
			self.garden:release(actor)
			self.garden:transition(actor,"rest",self.garden:position(actor,now),1,"wanderPause")
		end
		park.nextPickAt=math.max(park.nextPickAt or 0,now+1);park.waitingSince=park.nextPickAt
		return
	end
	if actor.action=="nookApproach"or actor.action=="nookRest"then
		if now<actor.endTime then return end
		actor.restAnchorId=nil
	end
	local session=park.session and self.sessions[park.session]
	if park.session and not session then park.session,park.slotId,park.state=nil,nil,"idle"end
	if session then
		if now>=session.endTime then self:finish(session,now)
		elseif park.state=="approach"and now>=session.startTime then self:play(actor,session,now)end
		return
	end
	if park.state=="hop"then
		if now<actor.endTime then return end
		park.state="idle"
	end
	self:mingle(actor,input,now)
end

-- Runs once per decide, after the actor loop and before the global greeting.
function Director:schedule(now,ordered)
	local garden=self.garden
	-- Membership: owners entering the kerb; pets that went to care/Board lose membership.
	for _,actor in ipairs(ordered)do
		local input=garden.inputs[actor.ownerId]
		if actor.park then
			if not input or actor.care or(actor.mode~="Room"and actor.mode~="Focus")then self:release(actor);actor.park=nil end
		elseif input and input.alive and input.owned and actor.mode=="Room"and not actor.care and Park.member(input.position,false)then
			actor.park={state="idle",since=now,nextPickAt=now+1,waitingSince=now+1,nextWanderAt=now}
		end
	end
	-- Sweep: a participant whose actor vanished, lost membership or changed generation leaves
	-- its session; a session past its end (no tick finished it) frees itself without credit.
	for id,session in pairs(self.sessions)do
		for _,ownerId in ipairs(table.clone(session.ownerIds))do
			local actor=garden.actors[ownerId]
			local park=actor and actor.park
			if not park or park.session~=id or actor.generation~=session.generations[ownerId]then
				if park and park.session==id then park.session,park.slotId,park.state,park.last=nil,nil,"idle",session.equipment end
				if self.sessions[id]==session then self:drop(session,ownerId,now)end
			end
		end
		if self.sessions[id]==session and now>=session.endTime+2 then self:finish(session,now,false)end
	end
	-- Oldest waiting pet first: a duo with the oldest idle pet of another owner, else a solo.
	local waiting={}
	for _,actor in ipairs(ordered)do if self:eligible(actor,now)then table.insert(waiting,actor)end end
	table.sort(waiting,function(a,b)
		if a.park.waitingSince==b.park.waitingSince then return a.ownerId<b.ownerId end
		return a.park.waitingSince<b.park.waitingSince
	end)
	local usedSlots,usedEquipment=self:occupancy()
	local taken={}
	local members=0
	for _,actor in ipairs(ordered)do if actor.park then members+=1 end end
	for _,first in ipairs(waiting)do
		if taken[first]then continue end
		local park=first.park
		for _,kind in ipairs({"duo","solo"})do
			if kind=="solo"then
				local hold=members<=Director.DuoWaitMembers and self:partnerSoon(first,now,usedSlots,usedEquipment,taken)
				if park.partnerWaitUntil and(now>=park.partnerWaitUntil or not hold)then
					-- Code review: the window ran out (or the partner went away), so this pass falls
					-- back to a solo and the wait is cleared; a later pass may hold for a partner again.
					park.partnerWaitUntil=nil
				elseif hold then
					-- Hold for the partner (it mingles meanwhile); after the window it takes a solo.
					park.partnerWaitUntil=park.partnerWaitUntil or now+Director.DuoWait
					break
				end
			end
			local choices={}
			for _,id in ipairs(Catalog.Order)do
				local activity=Catalog.ById[id]
				if activity.kind~=kind or activity.equipment==first.park.last then continue end
				local slots=self:freeSlots(activity,usedSlots,usedEquipment)
				if not slots then continue end
				if kind=="solo"then table.insert(choices,{activity=activity,slots=slots,actors={first}});continue end
				for _,second in ipairs(waiting)do
					if second~=first and not taken[second]and second.ownerId~=first.ownerId and second.park.last~=activity.equipment then
						table.insert(choices,{activity=activity,slots=slots,actors={first,second}});break
					end
				end
			end
			local started=false
			while #choices>0 and not started do
				local pick=table.remove(choices,math.floor(self.random()*#choices)+1)
				if self:start(pick.activity,pick.slots,pick.actors,now)then
					started=true
					for _,actor in ipairs(pick.actors)do taken[actor]=true;actor.park.partnerWaitUntil=nil end
					for _,slotId in ipairs(pick.slots)do usedSlots[slotId]=true end
					if pick.activity.exclusive then usedEquipment[pick.activity.equipment]=true end
				end
			end
			if started then break end
		end
		-- Code review: a pet whose paths all failed waits 2 s instead of replanning every decide
		-- (a pet holding for a duo partner is not a failure).
		if not taken[first]and not(park.partnerWaitUntil and now<park.partnerWaitUntil)then park.nextPickAt=math.max(park.nextPickAt or 0,now+2)end
	end
	self:greetings(now,ordered,taken)
end

-- QA Q4: another owner's park pet that will be free to pick within DuoWait seconds (its session
-- ends, or its rest/hop/greeting ends), with a duo the two could share: free now, or held only by
-- that pet's own session, and not on either pet's last equipment.
function Director:partnerSoon(first,now,usedSlots,usedEquipment,taken)
	for _,other in pairs(self.garden.actors)do
		local park=other.park
		if not park or other==first or other.ownerId==first.ownerId or taken[other]then continue end
		if other.mode~="Room"or other.care or self:busy(other)then continue end
		local session=park.session and self.sessions[park.session]
		local freeAt
		if session then
			freeAt=session.endTime+Catalog.RestAfter
		else
			freeAt=math.max(park.nextPickAt or now,if other.pairId then other.endTime or now else now)
			if park.state=="hop"then freeAt=math.max(freeAt,other.endTime or now)end
		end
		if freeAt-now>Director.DuoWait then continue end
		local otherLast=if session then session.equipment else park.last
		for _,id in ipairs(Catalog.Order)do
			local activity=Catalog.ById[id]
			if activity.kind~="duo"or activity.equipment==first.park.last or activity.equipment==otherLast then continue end
			local holder=usedEquipment[activity.equipment]
			if holder and holder~=true and(not session or holder~=session.id)then continue end
			if holder==true then continue end -- started this round by someone else
			local open=false
			for _,set in ipairs(activity.slotSets)do
				local free=true
				for _,slotId in ipairs(set)do
					local by=usedSlots[slotId]
					if by and(by==true or not session or by~=session.id)then free=false;break end
				end
				if free then open=true;break end
			end
			if open then return true end
		end
	end
	return false
end

-- Park greetings: every 6 s, one pair of idle, slot-free park pets within 12 studs; the same
-- pair waits 45 s. Uses GardenState's paired greeting so clients play the same greet.
function Director:greetings(now,ordered,taken)
	if now<self.nextGreetAt then return end
	self.nextGreetAt=now+Director.GreetEvery
	for key,expires in pairs(self.cooldowns)do if expires<=now then self.cooldowns[key]=nil end end
	local idle={}
	for _,actor in ipairs(ordered)do
		local park=actor.park
		if park and not taken[actor]and not park.session and park.state=="idle"and not(park.partnerWaitUntil and now<park.partnerWaitUntil)
			and now-(park.waitingSince or now)<Director.GreetPatience
			and actor.mode=="Room"and not actor.care and not actor.pairId
			and actor.action~="nookApproach"and actor.action~="nookRest"and not self:busy(actor)and Park.inside(self.garden:position(actor,now),0)then
			table.insert(idle,actor)
		end
	end
	for i=1,#idle do
		for j=i+1,#idle do
			local a,b=idle[i],idle[j]
			local key=pairKey(a.ownerId,b.ownerId)
			if self.cooldowns[key]then continue end
			if horizontal(self.garden:position(a,now),self.garden:position(b,now))>Director.GreetReach then continue end
			self.garden:greetPair(a,b,now)
			self.cooldowns[key]=now+Director.GreetCooldown
			return
		end
	end
end

-- Snapshot block, inside the one GardenState snapshot. Keyed by slot id; a duo appears under
-- both of its slots with the same session id. Castle stage and phases derive from startTime.
function Director:snapshot()
	local slots={}
	for _,session in pairs(self.sessions)do
		for _,ownerId in ipairs(session.ownerIds)do
			slots[session.slots[ownerId]]={session=session.id,activity=session.activity,ownerId=ownerId,ownerIds=table.clone(session.ownerIds),
				walkStart=session.walkStart,startTime=session.startTime,endTime=session.endTime}
		end
	end
	return {version=Park.Version,slots=slots}
end

return Director
