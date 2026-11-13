-- Pet Park client (BUILD-PLAN 2026-11-13, slice K3). Exists only when FeatureFlags.Park is on
-- (new() returns nil otherwise and creates nothing). Reads the `park` block of the garden snapshot
-- ({version, slots = {[slotId] = {session, activity, ownerId, ownerIds, walkStart, startTime,
-- endTime}}}) and animates LOCAL moving parts purely from server times: swings follow the swinging
-- pet's pendulum and settle after the hop, the see-saw tilts with the bob, the castle grows and
-- crumbles, balls are batted or tossed. A late joiner computes the same frame from the same times.
-- The server mounts everything static (ParkMount); these parts never replicate.
--
-- Owned by RoomView: step() runs inside RoomView's RenderStepped (no connection of its own), skips
-- equipment work while the park is far away or behind the camera, writes a part only when its frame
-- changes and allocates no instances per frame. drive() wraps PetFollow.activity for every garden
-- pet so ParkPetPose can put it on the equipment. Also the own-pet ring (soft white ground ring and
-- a small chevron, local only) and the park chip (name + Play date) while the owner is inside the kerb.
local Players=game:GetService("Players")
local AssetService=game:GetService("AssetService")
local Shared=game:GetService("ReplicatedStorage").Shared
local Flags=require(Shared.FeatureFlags)
local Park=require(Shared.ParkLayout)
local Data=require(Shared.ParkPoseData)
local UICopy=require(Shared.UICopy)
local Follow=require(script.Parent.PetFollow)
local PetPose=require(script.Parent.ParkPetPose)
local OwnerSnapshot=require(script.Parent.OwnerSnapshot)
local Client={};Client.__index=Client
Client.FarDistance=180 -- equipment frames stop updating beyond this camera distance
Client.BehindDistance=40 -- and when the park is behind the camera beyond this distance
Client.RingRadius=1.35
Client.ChipTop=64 -- phone 812 x 354: below the Roblox controls row (y < 60), clear of chat (left) and the wallet (right)
Client.Grey=Color3.fromHex("#C9C2D6")
local UP=Vector3.yAxis
local SWING_SLOTS={"swing1","swing2"}
local CASTLES={"Park_Castle1","Park_Castle2","Park_Castle3"}

local meshCache={}
local function loadMesh(id)
	local hit=meshCache[id]
	if hit~=nil then return hit or nil end
	local ok,made=pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromUri(id),{CollisionFidelity=Enum.CollisionFidelity.Box,RenderFidelity=Enum.RenderFidelity.Automatic})
	end)
	if ok and made then meshCache[id]=made;return made end
	meshCache[id]=false
	return nil
end

local function quiet(part)
	part.Anchored=true;part.CanCollide=false;part.CanQuery=false;part.CanTouch=false
	return part
end

-- options: enabled (default FeatureFlags.Park), garden (GardenClient), park() -> park block (tests),
-- parent (default workspace), gui (default PlayerGui, the chip's parent), createMesh(id) -> MeshPart
-- (sync; default AssetService in a task), reduced() -> bool, playDate() -> {count,target,reward,done}.
function Client.new(options)
	options=options or {}
	local enabled=if options.enabled==nil then Flags.Park==true else options.enabled==true
	if not enabled or not Park.Enabled then return nil end
	local self=setmetatable({garden=options.garden,parkSource=options.park,reduced=options.reduced or function()return false end,
		playDateSource=options.playDate,guiParent=options.gui,parts={},lastHop={},ownerInside=false},Client)
	local folder=Instance.new("Folder");folder.Name="PetParkLocal"
	folder.Parent=options.parent or workspace
	self.folder=folder
	for _,name in ipairs(Data.Moving)do
		local entry={name=name,spec=Data.Meshes[name]}
		self.parts[name]=entry
		if options.createMesh then self:place(entry,options.createMesh(entry.spec.id))end
	end
	if not options.createMesh then
		task.spawn(function()
			for _,name in ipairs(Data.Moving)do
				if not self.folder then return end
				local entry=self.parts[name]
				self:place(entry,loadMesh(entry.spec.id))
			end
		end)
	end
	return self
end

-- Creates the local part for a moving mesh (a grey box when the mesh failed).
function Client:place(entry,template)
	local part
	if template then
		part=template:Clone()
		if part:IsA("MeshPart")then part.TextureID=Data.Texture end
	else
		part=Instance.new("Part");part.Color=Client.Grey;part:SetAttribute("ParkFallback",true)
	end
	quiet(part);part.Name=string.gsub(entry.name,"^Park_","");part.Size=entry.spec.size
	part.CastShadow=true;part.Material=Enum.Material.SmoothPlastic
	part.PivotOffset=Data.pivotOffset(entry.name)
	entry.part=part;entry.lastFrame=nil;entry.lastSize=entry.spec.size;entry.lastTransparency=0
	part.Parent=self.folder
end

function Client:block()
	if self.parkSource then return self.parkSource()end
	local snapshot=self.garden and self.garden.snapshot
	local park=snapshot and snapshot.park
	return if type(park)=="table"and type(park.slots)=="table"then park else nil
end
-- Slot id and entry holding `ownerId` (no allocation: at most nine slots).
function Client:slotFor(ownerId)
	local park=self:block()
	if not park then return nil,nil end
	for slotId,entry in pairs(park.slots)do
		if type(entry)=="table"and entry.ownerId==ownerId and Park.Slots[slotId]then return slotId,entry end
	end
	return nil,nil
end

local function setFrame(entry,frame)
	if entry.part and entry.lastFrame~=frame then entry.part.CFrame=frame;entry.lastFrame=frame end
end
local function setSize(entry,size)
	if entry.part and entry.lastSize~=size then entry.part.Size=size;entry.lastSize=size end
end
local function setShown(entry,shown)
	local transparency=if shown then 0 else 1
	if entry.part and entry.lastTransparency~=transparency then entry.part.Transparency=transparency;entry.lastTransparency=transparency end
end

-- Equipment frames at server time t (already delayed). Public for specs.
function Client:animate(t)
	local park=self:block()
	local slots=park and park.slots
	local roots=Data.Roots
	-- Swings.
	for _,slotId in ipairs(SWING_SLOTS)do
		local entry=slots and slots[slotId]
		local hop=Data.swingHopAt(entry)
		if hop then self.lastHop[slotId]=hop end
		local angle=Data.swingAngle(slotId,entry,t,self.lastHop[slotId])
		local part=self.parts[Data.Swings[slotId].mesh]
		if part.angle~=angle or not part.lastFrame then
			part.angle=angle
			setFrame(part,Data.frame(part.name,roots.SwingSet,Data.swingMotion(angle)))
		end
	end
	-- See-saw: one session holds both seats.
	local seesaw=slots and(slots.seesaw1 or slots.seesaw2)
	local tilt=Data.seesawTilt(seesaw,t)
	local beam=self.parts.Park_SeeSawBeam
	if beam.tilt~=tilt or not beam.lastFrame then
		beam.tilt=tilt;setFrame(beam,Data.frame("Park_SeeSawBeam",roots.SeeSaw,Data.seesawMotion(tilt)))
	end
	-- Castle.
	local sand=slots and slots.sand1
	if not(sand and Data.activityOf(sand,"sandbox"))then sand=slots and slots.sand2 end
	local stage,scaleY,scaleXZ,sink=Data.castle(sand,t)
	for k=1,3 do
		local entry=self.parts[CASTLES[k]]
		local shown=k==stage
		setShown(entry,shown)
		if shown and(entry.scaleY~=scaleY or entry.scaleXZ~=scaleXZ or entry.sink~=sink or not entry.lastFrame)then
			entry.scaleY,entry.scaleXZ,entry.sink=scaleY,scaleXZ,sink
			local scale=Vector3.new(scaleXZ,scaleY,scaleXZ)
			setSize(entry,entry.spec.size*scale)
			setFrame(entry,Data.frame(entry.name,roots.Sandbox,CFrame.new(0,-sink,0),scale))
		elseif not entry.lastFrame then
			setFrame(entry,Data.frame(entry.name,roots.Sandbox))
		end
	end
	-- Balls.
	local positionA,spinA,positionB,spinB,active=Data.balls(slots and slots.ball1,slots and slots.ball2,t)
	local ballA,ballB=self.parts.Park_BallA,self.parts.Park_BallB
	local axis=if active=="B"then Vector3.zAxis else -Vector3.zAxis -- rolling +X (ball1 east) or -X (ball2 west)
	if ballA.position~=positionA or ballA.spin~=spinA or not ballA.lastFrame then
		ballA.position,ballA.spin=positionA,spinA
		setFrame(ballA,CFrame.new(positionA)*CFrame.fromAxisAngle(axis,spinA))
	end
	if ballB.position~=positionB or ballB.spin~=spinB or not ballB.lastFrame then
		ballB.position,ballB.spin=positionB,spinB
		setFrame(ballB,CFrame.new(positionB)*CFrame.fromAxisAngle(axis,spinB))
	end
end

-- Whether the equipment is worth animating from this camera.
function Client.visibleFrom(camera)
	if typeof(camera)~="CFrame"then return true end
	local center=Park.Center
	local offset=center-camera.Position
	local distance=offset.Magnitude
	if distance>Client.FarDistance then return false end
	if distance>Client.BehindDistance and camera.LookVector:Dot(offset/distance)<-.2 then return false end
	return true
end

-- context: camera (CFrame), ownerPosition (Vector3), ownPet (visual), active (Room mode, no overlay).
function Client:step(serverNow,context)
	if not self.folder then return end
	context=context or {}
	local t=serverNow-Data.Delay
	if Client.visibleFrom(context.camera)then self:animate(t)end
	-- Owner membership with the server's hysteresis (enter 0.5 in, leave 1.5 out).
	local owner=context.ownerPosition
	self.ownerInside=typeof(owner)=="Vector3"and Park.member(owner,self.ownerInside)
	self:updateRing(context.ownPet,context.active==true and self.ownerInside,serverNow)
	self:updateChip(context.active==true and self.ownerInside)
end

-- Garden pet driver: PetFollow.activity on the server path, then the park pose on top.
function Client:drive(visual,actor,now,dt,state,reduced)
	if visual.parkPosedOrigin~=nil and visual.origin==visual.parkPosedOrigin and visual.parkBase then visual.origin=visual.parkBase end
	visual.parkPosedOrigin,visual.parkBase=nil,nil
	state=Follow.activity(visual,actor,now,dt,state,reduced)
	visual.parkPose=false
	if actor.care or actor.mode~="Room"or not PetPose.Actions[actor.action]then return state end
	local base=visual.origin
	local t=now-Data.Delay
	local slotId,entry=self:slotFor(actor.ownerId)
	local posed=false
	if entry then posed=PetPose.apply(visual,slotId,entry,t,dt,reduced)end
	if not posed then posed=PetPose.hopOff(visual,actor,t,reduced)end
	if posed then visual.parkBase=base;visual.parkPosedOrigin=visual.origin end
	return state
end

-- Own-pet ring + chevron ------------------------------------------------------------------------
function Client:makeRing()
	local ring=quiet(Instance.new("Part"))
	ring.Name="OwnPetRing";ring.Transparency=1;ring.CastShadow=false
	ring.Size=Vector3.new(Client.RingRadius*2,.05,Client.RingRadius*2)
	local surface=Instance.new("SurfaceGui")
	surface.Name="Ring";surface.Face=Enum.NormalId.Top;surface.LightInfluence=0;surface.CanvasSize=Vector2.new(200,200)
	surface.SizingMode=Enum.SurfaceGuiSizingMode.FixedSize;surface.Parent=ring
	local circle=Instance.new("Frame")
	circle.Name="Circle";circle.BackgroundTransparency=1;circle.AnchorPoint=Vector2.new(.5,.5)
	circle.Position=UDim2.fromScale(.5,.5);circle.Size=UDim2.fromScale(.9,.9);circle.Parent=surface
	local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(.5,0);corner.Parent=circle
	local stroke=Instance.new("UIStroke");stroke.Color=Color3.new(1,1,1);stroke.Thickness=10;stroke.Transparency=.3;stroke.Parent=circle
	-- A fainter halo just outside the line keeps it soft on bright grass.
	local halo=circle:Clone();halo.Name="Halo";halo.Size=UDim2.fromScale(1,1);halo.Parent=surface
	halo.UIStroke.Thickness=6;halo.UIStroke.Transparency=.75
	local anchor=quiet(Instance.new("Part"))
	anchor.Name="OwnPetChevronAnchor";anchor.Transparency=1;anchor.Size=Vector3.new(.1,.1,.1);anchor.CastShadow=false
	local board=Instance.new("BillboardGui")
	board.Name="Chevron";board.Size=UDim2.fromOffset(18,12);board.AlwaysOnTop=true;board.LightInfluence=0
	board.Adornee=anchor;board.Parent=anchor
	for _,side in ipairs({-1,1})do
		local bar=Instance.new("Frame")
		bar.Name=if side<0 then "Left"else "Right";bar.BorderSizePixel=0;bar.BackgroundColor3=Color3.new(1,1,1)
		bar.AnchorPoint=Vector2.new(.5,.5);bar.Size=UDim2.fromOffset(11,3);bar.Rotation=side*-38
		bar.Position=UDim2.new(.5,side*4,.5,0);bar.Parent=board
		local round=Instance.new("UICorner");round.CornerRadius=UDim.new(.5,0);round.Parent=bar
	end
	ring.Parent=self.folder;anchor.Parent=self.folder
	self.ring,self.chevron,self.chevronGui=ring,anchor,board
end
function Client:updateRing(pet,ownerInside,serverNow)
	local base=pet and(pet.parkBase or pet.origin)
	local show=ownerInside and typeof(base)=="Vector3"and Park.inside(base,.5)
	if not show then
		if self.ring and self.ringShown then self.ring.Parent=nil;self.chevron.Parent=nil;self.ringShown=false end
		return
	end
	if not self.ring then self:makeRing()end
	if not self.ringShown then self.ring.Parent=self.folder;self.chevron.Parent=self.folder;self.ringShown=true end
	local ground=Park.ground(base.X,base.Z)+.03
	if self.ringX~=base.X or self.ringZ~=base.Z then
		self.ringX,self.ringZ=base.X,base.Z
		self.ring.CFrame=CFrame.new(base.X,ground,base.Z)
	end
	local k=(pet.worldScale or .72)/.72
	local bob=if self.reduced()then 0 else .08*math.sin(serverNow*2.4)
	local top=pet.origin+UP*(1.75*k+bob)
	if self.chevronTop~=top then self.chevronTop=top;self.chevron.CFrame=CFrame.new(top)end
end

-- Park chip ------------------------------------------------------------------------------------
function Client:makeChip()
	local Kit=require(script.Parent.DeckKit)
	local parent=self.guiParent or Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not parent then return false end
	local gui=Instance.new("ScreenGui")
	gui.Name="EggDropPark";gui.ResetOnSpawn=false;gui.IgnoreGuiInset=true;gui.DisplayOrder=4
	gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Enabled=false
	-- Kit components read their parent's ZIndex: a transparent full-screen holder (no input).
	local holder=Instance.new("Frame");holder.Name="Holder";holder.BackgroundTransparency=1;holder.Size=UDim2.fromScale(1,1)
	holder.Active=false;holder.ZIndex=1;holder.Parent=gui
	local pill=Kit.frame(holder,"ParkChip","panel",UDim2.new(.5,0,0,Client.ChipTop),UDim2.fromOffset(0,32),999)
	pill.AnchorPoint=Vector2.new(.5,0);pill.AutomaticSize=Enum.AutomaticSize.X;pill.BackgroundTransparency=.08
	Kit.stroke(pill)
	local pad=Instance.new("UIPadding");pad.PaddingLeft=UDim.new(0,12);pad.PaddingRight=UDim.new(0,14);pad.Parent=pill
	local list=Instance.new("UIListLayout");list.FillDirection=Enum.FillDirection.Horizontal;list.VerticalAlignment=Enum.VerticalAlignment.Center
	list.Padding=UDim.new(0,8);list.SortOrder=Enum.SortOrder.LayoutOrder;list.Parent=pill
	local dot=Kit.frame(pill,"Dot",nil,UDim2.new(),UDim2.fromOffset(10,10),999)
	dot.BackgroundTransparency=0;dot.BackgroundColor3=Kit.Color.good;dot.LayoutOrder=1
	local name=Kit.text(pill,"Strong",UICopy.get("park.name"),"text",{Name="ParkName",LayoutOrder=2})
	name.AutomaticSize=Enum.AutomaticSize.X;name.Size=UDim2.fromOffset(0,24)
	local count=Kit.text(pill,"Body",UICopy.get("park.playDate",{count=0,target=3}),"soft",{Name="PlayDate",LayoutOrder=3})
	count.AutomaticSize=Enum.AutomaticSize.X;count.Size=UDim2.fromOffset(0,24)
	gui.Parent=parent
	self.chip,self.chipCount,self.chipKit=gui,count,Kit
	return true
end
function Client:playDate()
	if self.playDateSource then return self.playDateSource()end
	local snapshot=OwnerSnapshot.read()
	return snapshot and snapshot.playDate
end
function Client:updateChip(show)
	if not show then
		if self.chip and self.chip.Enabled then self.chip.Enabled=false end
		return
	end
	if not self.chip and not self:makeChip()then return end
	local date=self:playDate()
	local count=if type(date)=="table"and type(date.count)=="number"then date.count else 0
	local target=if type(date)=="table"and type(date.target)=="number"then date.target else 3
	local reward=if type(date)=="table"and type(date.reward)=="number"then date.reward else 4
	local done=type(date)=="table"and(date.done==true or count>=target)
	if self.chipCountValue~=count or self.chipDone~=done then
		self.chipCountValue,self.chipDone=count,done
		self.chipCount.Text=if done then UICopy.get("park.done",{reward=reward})else UICopy.get("park.playDate",{count=count,target=target})
		self.chipKit.paint(self.chipCount,"TextColor3",if done then "stars"else "soft")
	end
	if not self.chip.Enabled then self.chip.Enabled=true end
end

function Client:destroy()
	if self.chip then self.chip:Destroy();self.chip=nil end
	if self.folder then self.folder:Destroy();self.folder=nil end
	self.ring,self.chevron=nil,nil
end

return Client
