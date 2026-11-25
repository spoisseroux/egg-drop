-- The Play Den host (PLAY-DEN-BUILD-PLAN.md; the room from CliffDenData, step B, architect verdict applied). mount() answers nil with the build
-- ceiling off (live): nothing made, nothing connected, no attribute written, the cave blocker never touched.
--
-- The layout (DenLayout.current: the pocket, or the island's room on a `CliffDen` server) is resolved the first time the
-- den would open; none (bad CliffDenData) keeps it closed with one warning.
-- Open (the switch on, the lounge present, the Hush not open): the CaveBlocker must exist and sit on the layout's mouth
-- line (step B: the world builds it at the new mouth, closed), or the den stays closed with one warning. Then the greybox
-- (DenGreybox rows) is built into EggDropLounge.PlayDen, the pet-blocked footprints into PetRegions (GardenBlockedRegion
-- set before parenting), the blocker stops colliding and answering rays (its own values kept once), `open` is true, and
-- only then is `Den_open` written. `open` is what the pet floor checks, catch-up, the island bounds and DashHost read.
-- Close (the switch off, the Hush opening, or MaxErrors errors), in one step, never yielding: `Den_open` cleared first
-- (clients drop the prompts), then everyone whose root is in the den, its waiting area or the blocker's volume (slack 1)
-- is moved to the doorstep (held, seated or racing too: the floor is closing), then every pet in there is carried out,
-- then the blocker gets its values back, the model and the footprints are destroyed and `open` is false. Waiting den
-- racers are dropped by DashHost's own check ("Closed"). A rebuilt lounge drops all den state.
local RunService=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage").Shared
local Den=require(Shared.PlayDen)
local Layout=require(Shared.DenLayout)
local Greybox=require(Shared.DenGreybox)
local GreyboxRows=require(Shared.GreyboxRows)
local Activity=require(Shared.GardenActivity)

local Host={};Host.__index=Host
Host.Offsets=table.freeze({Vector3.zero,Vector3.new(-1.6,0,0),Vector3.new(1.6,0,0),Vector3.new(-.8,0,-2.2),Vector3.new(.8,0,-2.2),
	Vector3.new(-2.4,0,-2.2),Vector3.new(2.4,0,-2.2),Vector3.new(0,0,-4.4)})
Host.MouthSlack=3 -- the blocker's middle may sit this far off the mouth line

-- d: boards (player -> board), room() -> EggDropLounge, garden (actors), carry(board, spot) -> bool (the pet),
-- arrived(player, rootPosition) (island bounds), moved(player), hushOpen() -> bool.
-- Specs may replace layout() -> layout, why; clock, heartbeat, read(board) -> view, place(board, view, cframe),
-- petPosition(actor) -> Vector3?, attribute(name, value) (default workspace), warn.
function Host.mount(d)
	if not Den.ceiling()then return nil end
	local self=setmetatable({d=d,open=false,errors=0,dead=false,tickAt=-math.huge,warned={},slot=0},Host)
	self.clock=d.clock or os.clock
	self.read=d.read or Host.read
	self.place=d.place or Host.place
	self.warn=d.warn or warn
	self.attribute=d.attribute or function(name,value)workspace:SetAttribute(name,value)end
	self.petPosition=d.petPosition or function(actor)
		local sample=Activity.sample(actor,workspace:GetServerTimeNow())
		return sample and sample.position
	end
	pcall(self.attribute,Den.OpenAttribute,nil)
	self.connection=(d.heartbeat or RunService.Heartbeat):Connect(function()
		if self.dead then return end
		local ok,problem=pcall(self.step,self)
		if not ok then self:fail(problem)end
	end)
	return self
end
function Host:once(key,text)
	if self.warned[key]then return end
	self.warned[key]=true
	pcall(self.warn,text)
end
-- Count an error (never reset by a success); at MaxErrors the den closes on this server.
function Host:fail(problem)
	self.errors+=1
	pcall(self.warn,"[Den] host: "..tostring(problem))
	if self.errors<Den.MaxErrors or self.dead then return end
	self.dead=true
	pcall(function()self.connection:Disconnect()end)
	local ok,again=pcall(self.close,self)
	if not ok then pcall(self.warn,"[Den] close: "..tostring(again))end
end
function Host:room()
	if self.d.room then return self.d.room()end
	return workspace:FindFirstChild("EggDropLounge")
end
-- The layout, resolved once.
function Host:resolve()
	if self.resolved then return self.layout end
	self.resolved=true
	local layout,why=(self.d.layout or Layout.current)()
	self.layout=layout
	if not layout then self:once("layout","[Den] no layout ("..tostring(why).."); the den stays closed")end
	return layout
end
-- The layout while the den is open (DashHost, the pet floor chain), else nil.
function Host:live()return if self.open and not self.dead then self.layout else nil end

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
	return{character=character,root=root,humanoid=humanoid,position=root.Position,lift=lift}
end
function Host.place(_,view,cframe)
	if view.humanoid and view.humanoid.Sit then view.humanoid.Sit=false end
	view.character:PivotTo(cframe)
	view.root.AssemblyLinearVelocity=Vector3.zero
	view.root.AssemblyAngularVelocity=Vector3.zero
end

-- Pure: does the blocker sit on the layout's mouth line and span it?
function Host.blockerFits(blocker,layout)
	local at,size=blocker.Position,blocker.Size
	local m=layout.mouth
	return math.abs(at.Z-m.z)<=Host.MouthSlack and at.X-size.X/2<=m.x1+.5 and at.X+size.X/2>=m.x2-.5
end
-- Pure: is p in the blocker's box grown by slack?
function Host.inPart(part,p,slack)
	if typeof(p)~="Vector3"then return false end
	local q=part.CFrame:PointToObjectSpace(p)
	local h=part.Size/2
	return math.abs(q.X)<=h.X+slack and math.abs(q.Y)<=h.Y+slack and math.abs(q.Z)<=h.Z+slack
end
-- Is a root (or a pet) at p in the den for the close: the room, the waiting area or the blocker's volume (slack 1)?
function Host:inside(p)
	local L=self.layout
	if not L then return false end
	if Layout.inRoom(L,p,1)or Layout.inWait(L,p,1)or Layout.petFloor(L,p,true)then return true end
	local blocker=self.blocker
	return blocker~=nil and Host.inPart(blocker,p,1)
end

-- Open and close ----------------------------------------------------------------------------------------------
function Host:openUp(room)
	local layout=self:resolve()
	if not layout then return false end
	local blocker=room:FindFirstChild(Den.Blocker)
	if not blocker or not blocker:IsA("BasePart")then
		self:once("blocker","[Den] "..Den.Blocker.." is missing; the den stays closed")
		return false
	end
	if not Host.blockerFits(blocker,layout)then
		self:once("mouth","[Den] "..Den.Blocker.." is not on the mouth line; the den stays closed")
		return false
	end
	-- Held before they are parented (TierHost's rule): a throw part-way leaves nothing orphaned.
	self.builtIn=room
	if not self.model then
		self.model=GreyboxRows.build(Greybox.rows(layout),Den.Model)
		-- The world finish art's dress (lanterns, paw stones, apron), only when its den slice is in this room's World.
		local ok,problem=pcall(function()require(script.Parent.WorldFinishMount).dressDen(self.model,room)end)
		if not ok then warn("[WorldFinish] den dress: "..tostring(problem))end
	end
	self.model.Parent=room
	local regions=room:FindFirstChild("PetRegions")or room
	if not self.blocked then
		self.blocked={}
		for _,f in ipairs(Layout.footprints(layout))do
			local part=Instance.new("Part")
			table.insert(self.blocked,part)
			part.Name,part.CFrame,part.Size=Den.Blocked..f.name,f.cframe,f.size
			part.Anchored,part.CanCollide,part.CanQuery,part.CanTouch=true,false,false,false
			part.Transparency,part.CastShadow=1,false
			part:SetAttribute("GardenBlockedRegion",true) -- before parenting: the garden scene's watcher reads it on arrival
		end
	end
	for _,part in ipairs(self.blocked)do part.Parent=regions end
	if self.blocker~=blocker then
		self.blocker,self.blockerWas=blocker,{collide=blocker.CanCollide,query=blocker.CanQuery}
	end
	blocker.CanCollide,blocker.CanQuery=false,false
	self.open=true
	self.attribute(Den.OpenAttribute,true)
	return true
end
-- This player out to the doorstep, held or not (the floor is closing). True when moved.
function Host:evacuate(player,board)
	local view=self.read(board)
	if not view or not self:inside(view.position)then return false end
	self.slot=self.slot%#Host.Offsets+1
	local e=self.layout.doorstep
	local frame=CFrame.lookAt(e.at,Vector3.new(e.facing.X,e.at.Y,e.facing.Z))*CFrame.new(Host.Offsets[self.slot])
	local root=frame+Vector3.new(0,view.lift or 3,0)
	self.place(board,view,root)
	if self.d.arrived then self.d.arrived(player,root.Position)elseif self.d.moved then self.d.moved(player)end
	return true
end
-- This player's pet, if it is in the den, to the doorstep's landing.
function Host:rescuePet(player,board,k)
	local actor=self.d.garden and self.d.garden.actors and self.d.garden.actors[player.UserId]
	if not actor or not self.d.carry then return false end
	local at=self.petPosition(actor)
	if typeof(at)~="Vector3"or not self:inside(at)then return false end
	local e=self.layout.doorstep
	local frame=CFrame.lookAt(e.landing,Vector3.new(e.facing.X,e.landing.Y,e.facing.Z))
	return self.d.carry(board,(frame*CFrame.new(Host.Offsets[(k-1)%#Host.Offsets+1])).Position)==true
end
function Host:close()
	pcall(self.attribute,Den.OpenAttribute,nil)
	if self.open and self.layout then
		local k=0
		for player,board in pairs(self.d.boards)do
			if not board.closing then
				local ok,problem=pcall(self.evacuate,self,player,board)
				if not ok then pcall(self.warn,"[Den] evacuate: "..tostring(problem))end
				k+=1
				local good,why=pcall(self.rescuePet,self,player,board,k)
				if not good then pcall(self.warn,"[Den] pet: "..tostring(why))end
			end
		end
	end
	self.open=false
	if self.blocker and self.blockerWas and self.blocker.Parent then
		self.blocker.CanCollide,self.blocker.CanQuery=self.blockerWas.collide,self.blockerWas.query
	end
	self.blocker,self.blockerWas=nil,nil
	if self.model then self.model:Destroy()end
	for _,part in ipairs(self.blocked or {})do part:Destroy()end
	self.model,self.blocked,self.builtIn=nil,nil,nil
end
function Host:step()
	local now=self.clock()
	if now-self.tickAt<Den.Tick then return end
	self.tickAt=now
	local room=self:room()
	-- A rebuilt (or removed) lounge took the den's parts with it: drop the state, never touch the old parts.
	if self.builtIn and room~=self.builtIn then
		pcall(self.attribute,Den.OpenAttribute,nil)
		self.model,self.blocked,self.builtIn,self.blocker,self.blockerWas,self.open=nil,nil,nil,nil,nil,false
	end
	local hush=self.d.hushOpen and self.d.hushOpen()==true
	if hush then self:once("hush","[Den] the Hush is open; the den stays closed (one owner per blocker)")end
	local on=Den.on()and room~=nil and not hush
	if on and not self.open then self:openUp(room)
	elseif not on and(self.open or self.model)then self:close()end
end
-- The player left: nothing kept per player.
function Host:leave()end
return Host
