-- Studio probe for pets going up (WORLD-FINISH-LOOK section 5 probes 4 and 5; slice A). Run through Studio MCP
-- execute_luau on the SERVER in Play mode (Clients and Servers, 1 to 3 players, each with a pet out), beta place or
-- Studio, tier open (/tier on), /tierpets and /catchup not off. It walks every player's character up and down the cliff
-- path with Humanoid:MoveTo along CliffDenData's centre line (real walking, real collision), samples each pet from the
-- garden snapshot every frame and prints PASS / FAIL per climb and per check, then the numbers. It changes no save; it
-- flips /tier and /den off and back on (overrides on this server; /tier clear, /den clear after) for probe 5.
--   probe 4  every pet point on the path: within .8 of the tread under it (a ray, so the drawn collision is measured),
--            in the middle 3 studs (+.15), never past the lip (half width - .5); the pet on the terrace within 6 s of
--            its owner; no stall over 2 s while more than 10 route studs behind; catch-up hops counted (allowed, never
--            onto the flight)
--   probe 5  owner and pet at the turn, on the flight, on the Top Lawn's bench side and in the den: /tier off (and
--            /den off for the den) moves both to the lawn; then everything back on
-- Settings: CLIMBS climbs (and as many descents), SPEED the owners' WalkSpeed during the walk (16 = default).
local CLIMBS,SPEED,PROBE5=10,16,true
local Players=game:GetService("Players")
local HttpService=game:GetService("HttpService")
local RunService=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local SSS=game:GetService("ServerScriptService")
local Shared=RS:WaitForChild("Shared")
local Tier=require(Shared.Tier)
local Pets=require(Shared.TierPets)
local Activity=require(Shared.GardenActivity)
local DenLayout=require(Shared.DenLayout)
local folder=RS:WaitForChild("GardenState")
local P=assert(Tier.path(),"no CliffDenData path")
local U=P.u[#P.u]
local out={}
local function say(line)table.insert(out,line);print(line)end
local function flat(a,b)return Vector2.new(a.X-b.X,a.Z-b.Z).Magnitude end
local room=workspace:FindFirstChild("EggDropLounge")
local params=RaycastParams.new();params.RespectCanCollide=true
params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={room}

if workspace:GetAttribute(Tier.Attribute)~=true then say("FAIL the tier is closed (Tier_on): /tier on first");return table.concat(out,"\n")end
if not Pets.on()then say("FAIL the pets' switch is off (TierPets_on): /tierpets on");return table.concat(out,"\n")end

local function actorOf(player)
	local ok,data=pcall(function()return HttpService:JSONDecode(folder:GetAttribute("Snapshot"))end)
	return ok and data and data.actors and data.actors[tostring(player.UserId)]or nil
end
local function petOf(player)
	local actor=actorOf(player)
	local sample=actor and Activity.sample(actor,workspace:GetServerTimeNow())
	return sample and sample.position,actor
end
local function rootOf(player)
	local c=player.Character
	return c and c:FindFirstChild("HumanoidRootPart"),c and c:FindFirstChildOfClass("Humanoid")
end
local players={}
for _,player in ipairs(Players:GetPlayers())do
	if petOf(player)then table.insert(players,player)end
	if #players==3 then break end
end
if #players==0 then say("FAIL no player with a pet in the garden snapshot");return table.concat(out,"\n")end
say(string.format("players %d, climbs %d, walk speed %d, path %.1f studs",#players,CLIMBS,SPEED,U))

-- The owner's way: lawn by the foot -> the centre line -> the terrace (inside, by the Top Lawn) and back.
local LAWN=Vector3.new(-12,4.6,-84)
local TOP=Tier.T(20,10,Tier.FloorY)
local function waypoints(up)
	local list={}
	if up then
		table.insert(list,P.points[1])
		for i=2,#P.points,2 do table.insert(list,P.points[i])end
		table.insert(list,P.points[#P.points]);table.insert(list,TOP)
	else
		table.insert(list,P.points[#P.points])
		for i=#P.points-1,1,-2 do table.insert(list,P.points[i])end
		table.insert(list,P.points[1]);table.insert(list,LAWN)
	end
	return list
end
local function walk(player,list)
	local root,humanoid=rootOf(player)
	if not root or not humanoid then return false end
	for _,at in ipairs(list)do
		humanoid:MoveTo(at)
		local t0=os.clock()
		while os.clock()-t0<4 and flat(root.Position,at)>1.5 do RunService.Heartbeat:Wait()end
	end
	return true
end

-- Probe 4 -------------------------------------------------------------------------------------------------------
local function tread(at)
	local hit=Pets.project(at,P)
	local top=hit and hit.tread+Pets.RayAbove or at.Y+6
	local ray=workspace:Raycast(Vector3.new(at.X,top,at.Z),Vector3.new(0,-12,0),params)
	return hit,ray and ray.Position.Y
end
local function climb(k,up)
	local rec={}
	for _,player in ipairs(players)do
		local root,humanoid=rootOf(player)
		humanoid.WalkSpeed=SPEED
		local _,actor=petOf(player)
		rec[player]={off=0,lane=0,lip=0,stall=0,hops=0,flightHop=0,seq=actor and actor.hop and actor.hop.seq or 0,
			last=nil,lastMove=os.clock(),ownerTop=nil,lag=nil,done=false}
	end
	for i,player in ipairs(players)do
		task.delay((i-1)*1.0,function()walk(player,waypoints(up));rec[player].done=true end)
	end
	local t0=os.clock()
	while os.clock()-t0<45 do
		RunService.Heartbeat:Wait()
		local all=true
		for _,player in ipairs(players)do
			local r=rec[player]
			local root=rootOf(player)
			local pet,actor=petOf(player)
			if not root or not pet then continue end
			local seq=actor.hop and actor.hop.seq or 0
			if seq~=r.seq then
				r.seq=seq;r.hops+=1
				if Pets.zone(pet)=="path"and Pets.onFlight(Pets.project(pet,P).u,P)then r.flightHop+=1 end
			end
			if Pets.zone(pet)=="path"then
				local hit,floor=tread(pet)
				if floor then r.off=math.max(r.off,math.abs(pet.Y-Pets.Sole-floor))end
				r.lane=math.max(r.lane,math.abs(hit.lateral))
				if math.abs(hit.lateral)>hit.half-.5 then r.lip+=1 end
				local gap=Pets.routeDistance(pet,root.Position)or 0
				if r.last and(pet-r.last).Magnitude>.02 then r.lastMove=os.clock()end
				if gap>10 then r.stall=math.max(r.stall,os.clock()-r.lastMove)else r.lastMove=os.clock()end
			else r.lastMove=os.clock()end
			r.last=pet
			if up then
				local ownerUp=Pets.zone(root.Position-Vector3.new(0,3,0))=="terrace"and Tier.inPiece(Tier.Pieces[1],root.Position.X,root.Position.Z,-3)
				if ownerUp and not r.ownerTop then r.ownerTop=os.clock()end
				if r.ownerTop and not r.lag and Pets.zone(pet)=="terrace"then r.lag=os.clock()-r.ownerTop end
				if not r.lag then all=false end
			elseif Pets.zone(pet)~="lawn"then all=false end
			if not r.done then all=false end
		end
		if all then break end
	end
	for i,player in ipairs(players)do
		local r=rec[player]
		local ok=r.off<=.8 and r.lane<=Pets.Lane+.15 and r.lip==0 and r.stall<=2 and r.flightHop==0 and(not up or(r.lag and r.lag<=6))
		say(string.format("%s %s %d pet %d: off-tread %.2f, lane %.2f, lip %d, stall %.1f s, hops %d (on the flight %d)%s",
			if ok then "PASS"else "FAIL",if up then "climb"else "descent",k,i,r.off,r.lane,r.lip,r.stall,r.hops,r.flightHop,
			if up then string.format(", terrace %.1f s after its owner",r.lag or -1)else ""))
	end
end
for k=1,CLIMBS do
	climb(k,true)
	task.wait(1.5)
	climb(k,false)
	task.wait(1.5)
end

-- Probe 5 -------------------------------------------------------------------------------------------------------
if PROBE5 then
	local TierConfig=require(SSS.Server.TierConfig)
	local DenConfig=require(SSS.Server.DenConfig)
	local player=players[1]
	local den=DenLayout.current()
	local spots={
		{"turn",Pets.pointAt(Pets.turnU(P),0,P),"/tier"},
		{"flight",P.points[#P.points-3],"/tier"},
		{"bench",Tier.T(0,-6,Tier.FloorY),"/tier"},
		{"den",den and Vector3.new((den.room.min.X+den.room.max.X)/2,den.floorY,den.room.min.Z+5)or nil,"/den"},
	}
	for _,s in ipairs(spots)do
		local name,at,command=s[1],s[2],s[3]
		if not at then say("SKIP probe 5 "..name..": no den layout");continue end
		local root=rootOf(player)
		root.Parent:PivotTo(CFrame.new(at+Vector3.new(0,3,0)))
		task.wait(6) -- the pet follows (or hops) up
		local pet=petOf(player)
		local petUp=pet and(if name=="den"then DenLayout.inRoom(den,pet,0)else Pets.zone(pet)~="lawn")
		if command=="/tier"then TierConfig.command("/tier off")else DenConfig.command("/den off")end
		task.wait(1.5)
		pet=petOf(player);root=rootOf(player)
		local ownerDown=root and Pets.zone(root.Position-Vector3.new(0,3,0))=="lawn"and not(den and DenLayout.inRoom(den,root.Position-Vector3.new(0,3,0),0))
		local petDown=pet and Pets.zone(pet)=="lawn"and not(den and DenLayout.inRoom(den,pet,0))
		say(string.format("%s probe 5 %s: pet was up %s; owner moved %s, pet moved %s",
			if petUp and ownerDown and petDown then "PASS"else "FAIL",name,tostring(petUp),tostring(ownerDown),tostring(petDown)))
		-- Back on (an override on this server; "/tier clear" and "/den clear" hand it back to the config afterwards).
		if command=="/tier"then TierConfig.command("/tier on")else DenConfig.command("/den on")end
		task.wait(2)
	end
end
return table.concat(out,"\n")
