-- The Hush host (HUSH-GREYBOX-BUILD-PLAN.md): builds the greybox, opens the cave, runs the passage and evacuates.
-- mount() answers nil with the build ceiling off (live): nothing made, no remote, nothing connected.
--
-- Open: the switch on (Hush.on) -> the greybox (HushGreybox rows) is built into EggDropLounge.Hush (ModelStreamingMode
-- Persistent), then the CaveBlocker stops colliding and answering rays, then `open` is true. A missing or renamed
-- blocker keeps the Hush closed with one warning. `open` is this host's own flag: the server's pet floor checks and the
-- island bounds read it (never an attribute or ConfigService on the hot path).
-- Close: the switch off, or MaxErrors errors -> everyone in the Hush or the Underway is moved onto the lawn in front of the
-- mouth with their pet (`evacuated`), and only then is `open` false, the blocker back as it was and the model gone.
--
-- The passage: the client walks into a door's trigger, fades to black and sends {kind="go", door, seq}. The server checks
-- (section 4 of the plan), waits until FadeOut after the request (and asks to stream the far side when streaming is on),
-- checks again, then in one step moves the character (PivotTo, velocity zeroed), tells the island bounds (arrived), moves
-- the pet (carry) and answers {kind="arrived", seq, at}. A refusal answers {kind="refused", seq, reason}. The client
-- never names a place: doors are fixed data. Everything runs protected; errors count toward MaxErrors.
local RunService=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage").Shared
local Hush=require(Shared.Hush)
local Rows=require(Shared.HushGreybox)
local Activity=require(Shared.GardenActivity)

local Host={};Host.__index=Host

-- d: boards (player -> board), remotes (Folder), room() -> EggDropLounge, garden (actors), carry(board, spot) -> bool,
-- arrived(player, rootPosition) (island bounds), moved(player) (Lounge.moved: bounds quiet when arrived is absent).
-- Specs may replace clock, heartbeat, remote, spawn, wait, read(board) -> view, place(board, view, cframe),
-- ground(position) -> y?, streaming() -> bool, stream(player, position), warn, petPosition(actor) -> Vector3? (default:
-- the garden's shared path sampled at server time).
function Host.mount(d)
	if not Hush.ceiling()then return nil end
	local self=setmetatable({d=d,records={},open=false,errors=0,dead=false,tickAt=-math.huge,slots={},warned={}},Host)
	self.clock=d.clock or os.clock
	self.spawn=d.spawn or task.spawn
	self.wait=d.wait or task.wait
	self.read=d.read or Host.read
	self.place=d.place or Host.place
	self.ground=d.ground or function(position)return Host.ground(self,position)end
	self.streaming=d.streaming or function()return workspace.StreamingEnabled==true end
	self.stream=d.stream or function(player,position)pcall(player.RequestStreamAroundAsync,player,position,Hush.StreamWait)end
	self.warn=d.warn or warn
	self.petPosition=d.petPosition or function(actor)
		local sample=Activity.sample(actor,workspace:GetServerTimeNow())
		return sample and sample.position
	end
	local remote=d.remote
	if not remote then
		remote=d.remotes:FindFirstChild(Hush.Remote)or Instance.new("RemoteEvent")
		remote.Name=Hush.Remote
		remote.Parent=d.remotes
	end
	self.remote=remote
	self.connections={
		remote.OnServerEvent:Connect(function(player,packet)
			if self.dead then return end
			local ok,problem=pcall(self.receive,self,player,packet)
			if not ok then self:fail(problem)end
		end),
		(d.heartbeat or RunService.Heartbeat):Connect(function()
			if self.dead then return end
			local ok,problem=pcall(self.step,self)
			if not ok then self:fail(problem)end
		end),
	}
	return self
end
-- Count an error (as IslandBoundsHost: never reset by a success); at MaxErrors the feature closes on this server.
function Host:fail(problem)
	self.errors+=1
	pcall(self.warn,"[Hush] host: "..tostring(problem))
	if self.errors<Hush.MaxErrors or self.dead then return end
	self.dead=true
	for _,connection in ipairs(self.connections)do pcall(function()connection:Disconnect()end)end
	local ok,again=pcall(self.close,self)
	if not ok then pcall(self.warn,"[Hush] close: "..tostring(again))end
end
function Host:once(key,text)
	if self.warned[key]then return end
	self.warned[key]=true
	pcall(self.warn,text)
end
function Host:room()
	if self.d.room then return self.d.room()end
	return workspace:FindFirstChild("EggDropLounge")
end

-- The character as plain values, or nil when there is none in the world. lift: root height over the feet.
function Host.read(board)
	local character=board.player.Character
	local root=character and character:FindFirstChild("HumanoidRootPart")
	local humanoid=character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or not character:IsDescendantOf(workspace)then return nil end
	local lift=humanoid.HipHeight+root.Size.Y/2+.1
	if humanoid.RigType==Enum.HumanoidRigType.R6 then
		local leg=character:FindFirstChild("Left Leg")
		if leg then lift+=leg.Size.Y end
	end
	return{character=character,root=root,humanoid=humanoid,position=root.Position,alive=humanoid.Health>0,lift=lift,
		anchored=root.Anchored,seated=humanoid.Sit or humanoid:GetState()==Enum.HumanoidStateType.Seated}
end
function Host.place(_,view,cframe)
	view.character:PivotTo(cframe)
	view.root.AssemblyLinearVelocity=Vector3.zero
	view.root.AssemblyAngularVelocity=Vector3.zero
end
-- The ground's height under a point (rays against the lounge's colliding parts), or nil.
function Host.ground(self,position)
	local room=self:room()
	if not room then return nil end
	local params=RaycastParams.new()
	params.FilterType=Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances={room}
	params.RespectCanCollide=true
	local hit=workspace:Raycast(position+Vector3.new(0,6,0),Vector3.new(0,-14,0),params)
	return hit and hit.Position.Y or nil
end

-- Open and close ----------------------------------------------------------------------------------------------
function Host:build(room)
	local model=Instance.new("Model")
	model.Name=Hush.Model
	pcall(function()model.ModelStreamingMode=Enum.ModelStreamingMode.Persistent end)
	for _,row in ipairs(Rows)do
		local part=Instance.new("Part")
		part.Name=row.name
		part.Size,part.CFrame=row.size,row.cframe
		part.Anchored,part.CanCollide,part.CanTouch=true,row.collide,false
		part.CanQuery=row.collide and row.visible
		part.Transparency=if row.visible then 0 else 1
		part.CastShadow=row.shadow
		part.Material=Enum.Material.SmoothPlastic
		part.Color=Color3.fromHex(row.color)
		part.TopSurface,part.BottomSurface=Enum.SurfaceType.Smooth,Enum.SurfaceType.Smooth
		-- Bounds-based scans (rest-path solids, greeting blockers) skip it as they skip the island meshes; rays still hit.
		part:SetAttribute("WorldMesh",true)
		part:SetAttribute("HushPart",true)
		if row.light then
			local l=Instance.new("PointLight")
			l.Name="HushLight"
			l.Color,l.Range,l.Brightness,l.Shadows=Color3.fromHex(row.light.color),row.light.range,row.light.brightness,false
			l.Parent=part
		end
		part.Parent=model
	end
	model.Parent=room
	return model
end
function Host:openUp()
	local room=self:room()
	local blocker=room and room:FindFirstChild(Hush.Blocker)
	if not blocker or not blocker:IsA("BasePart")then
		self:once("blocker","[Hush] "..Hush.Blocker.." is missing; the Hush stays closed")
		return false
	end
	if not self.model then self.model=self:build(room)end
	self.blocker,self.blockerWas=blocker,{collide=blocker.CanCollide,query=blocker.CanQuery}
	blocker.CanCollide,blocker.CanQuery=false,false
	self.open=true
	return true
end
function Host:close()
	if self.open then
		local moved={}
		for player,board in pairs(self.d.boards)do
			if not board.closing then
				local ok,result=pcall(self.evacuate,self,player,board)
				if not ok then pcall(self.warn,"[Hush] evacuate: "..tostring(result))
				elseif result then moved[player]=true end
			end
		end
		-- Code review 1: a pet still in the Hush whose owner is not (a reset, a respawn home) comes out too, or it would be
		-- left on nothing once the model goes and the pet floors close.
		for player,board in pairs(self.d.boards)do
			if not board.closing and not moved[player]then
				local ok,problem=pcall(self.rescuePet,self,player,board)
				if not ok then pcall(self.warn,"[Hush] pet: "..tostring(problem))end
			end
		end
	end
	self.open=false
	if self.blocker and self.blockerWas then
		self.blocker.CanCollide,self.blocker.CanQuery=self.blockerWas.collide,self.blockerWas.query
	end
	self.blocker,self.blockerWas=nil,nil
	if self.model then self.model:Destroy();self.model=nil end
	for _,rec in pairs(self.records)do rec.flight=nil end
end
function Host:step()
	local now=self.clock()
	if now-self.tickAt<Hush.Tick then return end
	self.tickAt=now
	for player,rec in pairs(self.records)do
		if self.d.boards[player]~=rec.board then self.records[player]=nil end
	end
	local on=Hush.on()
	if on and not self.open then self:openUp()
	elseif not on and(self.open or self.model)then self:close()end
end

-- The passage -------------------------------------------------------------------------------------------------
function Host:record(player,board)
	local rec=self.records[player]
	if not rec or rec.board~=board then
		rec={board=board,seq=0,lastAt=-math.huge,windowAt=-math.huge,count=0}
		self.records[player]=rec
	end
	return rec
end
function Host:fire(player,packet)
	local ok,problem=pcall(self.remote.FireClient,self.remote,player,packet)
	if not ok then pcall(self.warn,"[Hush] fire: "..tostring(problem))end
end
-- Pure over the board: why this player cannot take a passage through `door` now (nil when they can). `again`: the check
-- before the move, which skips the in-flight and cooldown rules; `anywhere`: the owner's /hush go and home.
function Host:refusal(player,board,door,rec,view,now,again,anywhere)
	if not self.open or self.dead then return "Closed"end
	if board.closing or self.d.boards[player]~=board then return "Left"end
	if board.mode~="Room"then return "Busy"end
	if board.dashHeld then return "Racing"end
	if board.careHeld or board.careEquip then return "Carried"end
	local state=board.nursery and board.nursery.state
	if state and state.lastHatch~=nil then return "Hatching"end
	if not view or not view.alive then return "NoCharacter"end
	if view.seated or view.anchored then return "Seated"end
	if not anywhere and not Hush.inBox(door.trigger,view.position,Hush.Slack)then return "Far"end
	local actor=self.d.garden and self.d.garden.actors[player.UserId]
	-- As a snack feed (init.server.lua): a pet in the park, in care, racing or holding the toy is busy.
	if actor and(actor.park or actor.care or actor.dash or actor.toyReservation)then return "PetBusy"end
	if not again then
		if rec.flight then return "Busy"end
		if now-rec.lastAt<Hush.Cooldown then return "Cooldown"end
	end
	return nil
end
function Host:receive(player,packet)
	local board=self.d.boards[player]
	if not board then return end
	local now=self.clock()
	local rec=self:record(player,board)
	if now-rec.windowAt>=1 then rec.windowAt,rec.count=now,0 end
	rec.count+=1
	if rec.count>Hush.Rate then return end
	if type(packet)~="table"or packet.kind~="go"then return end
	local door=type(packet.door)=="string"and Hush.Doors[packet.door]or nil
	local seq=packet.seq
	if not door or type(seq)~="number"or seq~=seq or seq%1~=0 or seq<=rec.seq or seq>1e9 then return end
	rec.seq=seq
	self:start(player,board,rec,door,seq,now,false)
end
-- Owner test (beta and Studio, init's chat block): "/hush go" (to the Hush) and "/hush home" (back to the Underway)
-- from wherever you stand, with every other check. The client is told to fade first.
function Host.parse(message)
	if type(message)~="string"then return nil end
	local verb=string.match(string.lower(message),"^%s*/hush%s+(%a+)%s*$")
	if verb=="go"then return "north"end
	if verb=="home"then return "home"end
	return nil
end
function Host:command(board,message)
	local id=Host.parse(message)
	if not id or self.dead or not board or board.closing then return false end
	local player=board.player
	local rec=self:record(player,board)
	self:fire(player,{kind="out",seq=0})
	return self:start(player,board,rec,Hush.Doors[id],0,self.clock(),true)
end
function Host:start(player,board,rec,door,seq,now,anywhere)
	local view=self.read(board)
	local reason=self:refusal(player,board,door,rec,view,now,false,anywhere)
	if reason then
		self:fire(player,{kind="refused",seq=seq,reason=reason})
		return false
	end
	rec.flight,rec.lastAt=seq,now
	local character=view.character
	self.spawn(function()
		local ok,problem=pcall(self.fly,self,player,board,rec,door,seq,now,character,anywhere)
		if rec.flight==seq then rec.flight=nil end
		if not ok then
			self:fail(problem)
			self:fire(player,{kind="refused",seq=seq,reason="Error"})
		end
	end)
	return true
end
function Host:fly(player,board,rec,door,seq,startedAt,character,anywhere)
	if self.streaming()then self.stream(player,door.arrival.Position)end
	local left=Hush.FadeOut-(self.clock()-startedAt)
	if left>0 then self.wait(left)end
	local view=self.read(board)
	local reason=self:refusal(player,board,door,rec,view,self.clock(),true,anywhere)
	if not reason and view.character~=character then reason="NoCharacter"end
	if not reason and rec.flight~=seq then reason="Busy"end
	if reason then
		self:fire(player,{kind="refused",seq=seq,reason=reason})
		return
	end
	local at=self:move(player,board,view,door.arrival,door.landing,door.id)
	self:fire(player,{kind="arrived",seq=seq,at=at,region=door.to})
end
-- One step: the character, the island bounds, the pet. Answers the root's new position.
function Host:move(player,board,view,arrival,landing,slotKey)
	local slot=(self.slots[slotKey]or 0)%#Hush.ArrivalOffsets+1
	self.slots[slotKey]=slot
	local offset=Hush.ArrivalOffsets[slot]
	local frame=arrival*CFrame.new(offset)
	local root=frame+Vector3.new(0,view.lift or 3,0)
	self.place(board,view,root)
	if self.d.arrived then self.d.arrived(player,root.Position)
	elseif self.d.moved then self.d.moved(player)end
	local spot=landing+arrival:VectorToWorldSpace(offset)
	local y=self.ground(spot)
	if type(y)=="number"then spot=Vector3.new(spot.X,y+.025,spot.Z)end
	if self.d.carry then self.d.carry(board,spot)end
	return root.Position
end
-- Switch off with this player in the Hush or the Underway: out onto the lawn in front of the mouth, held or not (the
-- ground they stand on is about to go). Never waits.
function Host:evacuate(player,board)
	local view=self.read(board)
	if not view or Hush.regionAt(view.position)==nil then return false end
	local rec=self.records[player]
	if rec then rec.flight=nil end
	self:move(player,board,view,Hush.Evacuation.arrival,Hush.Evacuation.landing,"evacuation")
	self:fire(player,{kind="evacuated"})
	return true
end
-- Closing: this player's pet, if it is in the Hush, to the evacuation landing.
function Host:rescuePet(player,board)
	local actor=self.d.garden and self.d.garden.actors[player.UserId]
	if not actor then return false end
	local at=self.petPosition(actor)
	if typeof(at)~="Vector3"or Hush.regionAt(at)~="hush"then return false end
	local slot=(self.slots.evacuation or 0)%#Hush.ArrivalOffsets+1
	self.slots.evacuation=slot
	local arrival=Hush.Evacuation.arrival
	local spot=Hush.Evacuation.landing+arrival:VectorToWorldSpace(Hush.ArrivalOffsets[slot])
	local y=self.ground(spot)
	if type(y)=="number"then spot=Vector3.new(spot.X,y+.025,spot.Z)end
	return self.d.carry~=nil and self.d.carry(board,spot)==true
end
-- The player left: forget them.
function Host:leave(board)
	local player=board.player
	if player and self.records[player]and self.records[player].board==board then self.records[player]=nil end
end
return Host
