-- One server-owned fetch per playground. Requests contain intent only; lanes, participants,
-- paths and winner are chosen here. No paid rewards or client positions enter this module.
local Shared=game:GetService("ReplicatedStorage").Shared
local A=require(Shared.GardenActivity)
local Perks=require(Shared.ParkPerks)
local Fetch={};Fetch.__index=Fetch
Fetch.Radius=14;Fetch.MaxPets=3;Fetch.Speed=6;Fetch.ThrowSeconds=.9;Fetch.PickupSeconds=.7;Fetch.HomeSeconds=1
local ZERO=Vector3.zero
-- How far the ball lands: 4 studs, or 5 for a thrower whose companion's saved Speed has the longer
-- throw (Levels matter S1; the host's options.speedLevel reads the save). Everything about a throw at
-- 5 is preflighted first; any failure falls back to the plain 4 stud throw.
Fetch.Reach=Perks.Reach.normal
local function distance(a,b)return Vector2.new(a.X-b.X,a.Z-b.Z).Magnitude end
function Fetch.new(director,layout)
	return setmetatable({director=director,garden=director.garden,layout=layout,serial=0},Fetch)
end
-- Where a throw starts: the park's centre, else (code review 2026-11-26: on the Top Lawn and the Hollow the centre sits in
-- a keepout, so no lane was ever clear and the throw always answered NoLane) the nearest clear point on rings of 1.5 to
-- 6 studs about it, every 30 degrees. Pure layout data, so built once per layout; a park whose centre is clear (the
-- arrival) only ever uses the centre, exactly as before.
local homesByLayout=setmetatable({},{__mode="k"})
local function homesOf(park)
	local list=homesByLayout[park]
	if list then return list end
	list={park.Center}
	for _,r in ipairs({1.5,2.5,3.5,4.5,6})do
		for k=0,11 do
			local a=k*math.pi/6
			local x,z=park.Center.X+math.cos(a)*r,park.Center.Z+math.sin(a)*r
			local p=Vector3.new(x,park.ground(x,z),z)
			if park.inside(p,-2)and park.clearOfKeepout(p,.6)then table.insert(list,p)end
		end
	end
	homesByLayout[park]=list
	return list
end
local function laneFrom(park,home,ownerPosition)
	local axis=ownerPosition and Vector3.new(home.X-ownerPosition.X,0,home.Z-ownerPosition.Z)or Vector3.new(1,0,0)
	if axis.Magnitude<.1 then axis=Vector3.new(1,0,0)else axis=axis.Unit end
	for _,turn in ipairs({0,math.pi*.5,-math.pi*.5,math.pi})do
		local dir=Vector3.new(axis.X*math.cos(turn)+axis.Z*math.sin(turn),0,-axis.X*math.sin(turn)+axis.Z*math.cos(turn))
		local target=home+dir*4
		target=Vector3.new(target.X,park.ground(target.X,target.Z),target.Z)
		local clear=park.inside(target,-2)and park.clearOfKeepout(target,1)
		for i=0,8 do if not park.clearOfKeepout(home:Lerp(target,i/8),.6)then clear=false;break end end
		if clear then return home,target end
	end
	return nil
end
function Fetch:lane(ownerPosition)
	for _,home in ipairs(homesOf(self.layout))do
		local from,target=laneFrom(self.layout,home,ownerPosition)
		if from then return from,target end
	end
	return nil
end
-- The same lane at a longer reach (same home, same direction), or nil when it is not clear.
function Fetch:extend(home,target,reach)
	local park=self.layout
	local dir=Vector3.new(target.X-home.X,0,target.Z-home.Z)
	if dir.Magnitude<.1 then return nil end
	local far=home+dir.Unit*reach
	far=Vector3.new(far.X,park.ground(far.X,far.Z),far.Z)
	if not park.inside(far,-2)or not park.clearOfKeepout(far,1)then return nil end
	local steps=math.ceil(reach*2)
	for i=0,steps do if not park.clearOfKeepout(home:Lerp(far,i/steps),.6)then return nil end end
	return far
end
function Fetch:reachOf(ownerId)
	local read=self.director.options.speedLevel
	if not read then return Fetch.Reach end
	local ok,level=pcall(read,ownerId)
	return if ok then Perks.throwReach(level)else Fetch.Reach
end
function Fetch:plan(actor,target)
	local from=self.garden:position(actor,self.director:clock())
	local sample=A.sample(actor,self.director:clock())
	local path,seconds=(self.garden.options.planPath or A.plan)(from,target,sample and sample.velocity or ZERO,Fetch.Speed,0,sample and sample.yaw or 0,nil,ZERO)
	local last=path and path[#path]
	if not last or(A.vector(last.to)-target).Magnitude>.1 then return nil end
	local length=0
	for _,leg in ipairs(path)do
		if leg.safetyStop then return nil end
		length+=(A.vector(leg.to)-A.vector(leg.from)).Magnitude
	end
	if self.garden.options.validToyPath and not self.garden.options.validToyPath(path)then return nil end
	return {path=path,seconds=seconds,target=target,length=length}
end
-- Fetch may invite a resting/cooling-down pet before the autonomous equipment
-- scheduler reclaims it. A reservation/real activity is still an absolute veto.
function Fetch:eligible(pet)
 local park=pet.park
 local input=self.garden.inputs[pet.ownerId]
 return park~=nil and park.parkId==self.layout.Id and park.state=="idle"and not park.session and not park.fetchId
  and pet.mode=="Room"and not pet.care and not pet.pairId and not self.director:busy(pet)
  and pet.action~="nookApproach"and pet.action~="nookRest"and input~=nil and input.alive and input.owned
  and self.layout.member(input.position,true)and self.layout.inside(self.garden:position(pet,self.director:clock()),0)
end
-- Who runs where for one landing point: participants, plans and the winner, or nil and why. A pet
-- with no path there stays behind; with `strict` (the longer throw) that fails the whole preflight.
function Fetch:preflight(ownerId,input,home,target,strict)
	local park=self.layout;local now=self.director:clock()
	local candidates={}
	for _,pet in pairs(self.garden.actors)do
		if self:eligible(pet)and distance(self.garden:position(pet,now),input.position)<=Fetch.Radius then table.insert(candidates,pet)end
	end
	table.sort(candidates,function(a,b)
		if(a.ownerId==ownerId)~=(b.ownerId==ownerId)then return a.ownerId==ownerId end
		local da,db=distance(self.garden:position(a,now),input.position),distance(self.garden:position(b,now),input.position)
		return if math.abs(da-db)>.001 then da<db else a.ownerId<b.ownerId
	end)
	local participants,plans,winner={}, {},nil
	for _,pet in ipairs(candidates)do
		if #participants>=Fetch.MaxPets then break end
		local plan=self:plan(pet,target)
		if strict and not plan then return nil,"NoLane"end
		if plan then
			table.insert(participants,pet.ownerId);plans[pet.ownerId]=plan
			if not winner or plan.seconds<plans[winner].seconds-.001 or(math.abs(plan.seconds-plans[winner].seconds)<=.001 and pet.ownerId<winner)then winner=pet.ownerId end
		end
	end
	if not winner then return nil,"NoIdlePets"end
	local along=target-home;local across=Vector3.new(-along.Z,0,along.X).Unit
	local companion=0
	for _,id in ipairs(participants)do
		if id~=winner then
			companion+=1
			local beside=target+across*(if companion==1 then -.9 else .9)
			beside=Vector3.new(beside.X,park.ground(beside.X,beside.Z),beside.Z)
			if not park.clearOfKeepout(beside,.6)then return nil,"NoLane"end
			local plan=self:plan(self.garden.actors[id],beside)
			if not plan then return nil,"NoLane"end
			plans[id]=plan
		end
	end
	return {participants=participants,plans=plans,winner=winner}
end
function Fetch:throw(ownerId)
	if self.session then return false,"BallOut"end
	local actor,input=self.garden.actors[ownerId],self.garden.inputs[ownerId]
	local park=self.layout;local now=self.director:clock()
	if not actor or not actor.park or actor.park.parkId~=park.Id or actor.mode~="Room"or not input or not input.alive or not park.member(input.position,true)then return false,"NotInPark"end
	local home,target=self:lane(input.position)
	if not home then return false,"NoLane"end
	local flight,why
	local reach=self:reachOf(ownerId)
	if reach>Fetch.Reach then
		local far=self:extend(home,target,reach)
		flight=far and self:preflight(ownerId,input,home,far,true)or nil
		if flight then target=far end
	end
	if not flight then flight,why=self:preflight(ownerId,input,home,target)end
	if not flight then return false,why end
	local participants,plans,winner=flight.participants,flight.plans,flight.winner
	-- Every path is preflighted before any reservation. Only now may actors transition.
	self.serial+=1
	local session={id=park.Id..":fetch:"..self.serial,ownerId=ownerId,winnerId=winner,owners=participants,plans=plans,generations={},
		expiresAt=now+45,stage="chase",home=home,landing=target,throwStart=now,landTime=now+Fetch.ThrowSeconds,phaseEnd=now+Fetch.ThrowSeconds}
	self.session=session
	for _,id in ipairs(participants)do
		local pet=self.garden.actors[id];local plan=plans[id]
		local from=self.garden:position(pet,now)
		local wait=assert(A.leg(from,from,ZERO,ZERO,Fetch.Speed,Fetch.ThrowSeconds,pet.yaw or 0));wait.duration=Fetch.ThrowSeconds
		table.insert(plan.path,1,wait)
		self.garden:transition(pet,"investigate",plan.target,0,"parkFetchChase",session.id,nil,{path=plan.path,duration=plan.seconds+Fetch.ThrowSeconds})
		pet.park.fetchId,pet.park.state=session.id,"fetch"
		session.generations[id]=pet.generation
		session.phaseEnd=math.max(session.phaseEnd,pet.endTime+Fetch.PickupSeconds)
	end
	self.garden.dirty=true
	return true,session.id
end
function Fetch:clearPet(id,session,counted)
	local actor=self.garden.actors[id]
	local park=actor and actor.park
	if not park or park.parkId~=self.layout.Id or park.fetchId~=session.id then return end
	park.fetchId=nil;park.state="idle";park.nextPickAt=self.director:clock()+3;park.waitingSince=park.nextPickAt;park.nextWanderAt=park.nextPickAt
	if actor.mode=="Room"and not actor.care and actor.generation==session.generations[id]then
		self.garden:transition(actor,"rest",self.garden:position(actor,self.director:clock()),3,"wanderPause")
	end
	if counted and self.director.options.finished then self.director.options.finished(id,"fetch",session.id)end
end
function Fetch:cancel()
	local session=self.session
	if not session then return end
	self.session=nil
	for _,id in ipairs(session.owners)do self:clearPet(id,session,false)end
	self.garden.dirty=true
end
function Fetch:release(actor)
	local session=self.session
	if not session or not actor.park or actor.park.fetchId~=session.id then return end
	if actor.ownerId==session.ownerId or actor.ownerId==session.winnerId then self:cancel();return end
	self:clearPet(actor.ownerId,session,false)
	local index=table.find(session.owners,actor.ownerId);if index then table.remove(session.owners,index)end
	session.generations[actor.ownerId]=nil
	self.garden.dirty=true
end
function Fetch:step(now)
	local session=self.session
	if not session then return end
	if now>=session.expiresAt then self:cancel();return end
	local host=self.garden.actors[session.ownerId];local hostInput=self.garden.inputs[session.ownerId]
	if not host or host.mode~="Room"or not hostInput or not hostInput.alive or not host.park or host.park.parkId~=self.layout.Id or not self.layout.member(hostInput.position,true)then self:cancel();return end
	for _,id in ipairs(table.clone(session.owners))do
		local actor,input=self.garden.actors[id],self.garden.inputs[id]
		if not actor or not input or not input.alive or not actor.park or actor.park.parkId~=self.layout.Id or actor.park.fetchId~=session.id
			or actor.mode~="Room"or actor.care or self.director:busy(actor)or actor.generation~=session.generations[id]or not self.layout.member(input.position,true)then
			if id==session.ownerId or id==session.winnerId then self:cancel();return end
			if actor then self:clearPet(id,session,false)end
			local index=table.find(session.owners,id);if index then table.remove(session.owners,index)end
			session.generations[id]=nil
		end
	end
	if now<session.phaseEnd then return end
	if session.stage=="chase"then
		local target=self.director.entryPoint(hostInput.position)
		local plans={}
		local along=target-session.landing
		local across=if along.Magnitude>.1 then Vector3.new(-along.Z,0,along.X).Unit else Vector3.xAxis
		local companion=0
		for _,id in ipairs(session.owners)do
			local destination=target
			if id~=session.winnerId then
				companion+=1;destination+=across*(if companion==1 then -.9 else .9)
				destination=Vector3.new(destination.X,self.layout.ground(destination.X,destination.Z),destination.Z)
				if not self.layout.clearOfKeepout(destination,.4)then self:cancel();return end
			end
			local actor=self.garden.actors[id];local plan=self:plan(actor,destination)
			if not plan then self:cancel();return end
			plans[id]=plan
		end
		session.stage="return";session.phaseEnd=now
		for _,id in ipairs(session.owners)do
			local actor=self.garden.actors[id];local plan=plans[id]
			self.garden:transition(actor,"investigate",plan.target,0,"parkFetchReturn",session.id,nil,{path=plan.path,duration=plan.seconds})
			session.generations[id]=actor.generation
			session.phaseEnd=math.max(session.phaseEnd,actor.endTime)
			if id==session.winnerId then session.carrier={from=actor.from,to=actor.to,path=actor.path,startTime=actor.startTime,endTime=actor.endTime,yaw=actor.yaw}end
		end
		self.garden.dirty=true
	elseif session.stage=="return"then
		session.stage="home";session.homeStart=now;session.phaseEnd=now+Fetch.HomeSeconds
		local winner=self.garden.actors[session.winnerId]
		session.drop=self.garden:position(winner,now)
		self.garden.dirty=true
	else
		self.session=nil
		for _,id in ipairs(session.owners)do self:clearPet(id,session,true)end
		self.garden.dirty=true
	end
end
function Fetch:snapshot()
	local s=self.session
	if not s then
		local laneHome=self:lane()
		local home=laneHome or self.layout.Center
		local available={};local any=false
		for _,host in pairs(self.garden.actors)do
			local input=self.garden.inputs[host.ownerId]
			if host.park and host.park.parkId==self.layout.Id and host.mode=="Room"and input and input.alive and self.layout.member(input.position,true)then
				local can=false
				for _,pet in pairs(self.garden.actors)do
					if self:eligible(pet)and distance(self.garden:position(pet,self.director:clock()),input.position)<=Fetch.Radius then can=true;break end
				end
				available[tostring(host.ownerId)]=can;any=any or can
			end
		end
		local lane=laneHome~=nil
		return {stage="idle",home=A.pack(home),ready=lane and any,laneReady=lane,availableOwners=available}
	end
	return {id=s.id,stage=s.stage,home=A.pack(s.home),landing=A.pack(s.landing),throwStart=s.throwStart,landTime=s.landTime,winnerId=s.winnerId,
		ownerIds=table.clone(s.owners),carrier=s.carrier,homeStart=s.homeStart,endTime=s.phaseEnd,drop=s.drop and A.pack(s.drop)or nil}
end
return Fetch
