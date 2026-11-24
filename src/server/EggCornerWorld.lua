-- The egg corner in the world, the server (EGG-CORNER-BUILD-PLAN sections 4 and 6; EGG-CORNER-LOOK Placement rulings R2).
-- Mounted by LoungeWorldV7Art.eggCorner only under the onboarding v3 ceiling (beta and Studio): live never builds any of
-- it. mount() places the egg machine once (the ServerStorage.EggMachine template from branch claude/egg-machine, or a
-- greybox with the same part names), its `Turn` prompt anchor and the clones the client animates, then apply() follows
-- Onboard.on("corner") both ways:
--   on   the machine's prompt is station Eggs (the old EggsSign prompt loses its PocketClubStation attribute, so
--        LoungeStations drops it), the model stands in the room, pets keep off its box, the nest's box moves with the
--        nest (EggCorner.nestSpot), EggNestLight drops to +2.5 / range 8, and the old station's own parts hide
--   off  exactly as before: the old prompt, no model (parked in ServerStorage), no machine box, the nest's box at Nest.Spot
-- The server never writes a machine part after placing it (clients animate them locally from WorldRestCFrame). Hidden
-- world parts carry WorldHidden (WorldMotion leaves a hidden pulse alone) and their own values in attributes to restore.
local ServerStorage=game:GetService("ServerStorage")
local Shared=game:GetService("ReplicatedStorage").Shared
local Corner=require(Shared.EggCorner)
local Landmark=require(Shared.NestLandmark)
local Onboard=require(Shared.Onboard)
local UICopy=require(Shared.UICopy)
local World={};World.__index=World
World.Model="EggMachine"
World.Prompt="EggMachinePrompt"
World.Block="EggMachineBlock"
World.Park="EggCornerParked"
World.Moving=table.freeze({"Dial","Sprout","EggPile","DropEgg","Loose1","Loose2","Loose3","Loose4","Loose5","Loose6"})
World.Points=table.freeze({"DialPivot","SproutPivot","ChuteTop","ChuteEnd","CupSeat","GlobeLight"})
World.GlobeLight=table.freeze({color=Color3.fromHex("#FFE9A6"),range=8,night=.5})

local function v3(list)return Vector3.new(list[1],list[2],list[3])end
local function invisible(name,cframe,size)
	local p=Instance.new("Part")
	p.Name,p.Size,p.CFrame=name,size,cframe
	p.Anchored,p.CanCollide,p.CanTouch,p.CanQuery,p.CastShadow=true,false,false,false,false
	p.Transparency=1
	return p
end

-- ── The machine model ──────────────────────────────────────────────────────────────────────────────────────────
-- A greybox with the template's six names at the data's sizes (machine-local, +Z the front), until the mesh is mounted.
function World.greybox(data)
	local model=Instance.new("Model")
	model.Name=World.Model
	local function part(name,shape,size,at,color,props)
		local p=Instance.new("Part")
		p.Name,p.Shape,p.Size,p.CFrame,p.Color=name,shape,size,CFrame.new(at),color
		p.Anchored,p.CanCollide,p.CanQuery,p.CanTouch,p.CastShadow=true,false,false,false,true
		p.Material=Enum.Material.SmoothPlastic
		p.TopSurface,p.BottomSurface=Enum.SurfaceType.Smooth,Enum.SurfaceType.Smooth
		for key,value in pairs(props or {})do p[key]=value end
		p.Parent=model
		return p
	end
	local body=part("Body",Enum.PartType.Block,Vector3.new(4.2,2.95,3.8),Vector3.new(0,1.475,0),Color3.fromHex("#F4E8CF"),{CanCollide=true,CanQuery=true})
	model.PrimaryPart=body
	part("Globe",Enum.PartType.Ball,Vector3.new(3.4,3.4,3.4),Vector3.new(0,5.35,0),Color3.fromHex("#FFF8E6"),{Transparency=.62,CastShadow=false})
	local dial=v3(data.pivots.Dial)
	part("Dial",Enum.PartType.Cylinder,Vector3.new(.3,1.7,1.7),dial+Vector3.new(0,0,.15),Color3.fromHex("#FFC83C"))
	model.Dial.CFrame=CFrame.new(dial+Vector3.new(0,0,.15))*CFrame.Angles(0,math.pi/2,0) -- a cylinder's axis is X: turn it to Z
	part("Sprout",Enum.PartType.Block,Vector3.new(.9,.6,.2),v3(data.pivots.Sprout)+Vector3.new(0,.3,0),Color3.fromHex("#6FBF73"),{CastShadow=false})
	part("EggPile",Enum.PartType.Ball,Vector3.new(2.8,2.8,2.8),Vector3.new(0,4.5,0),Color3.fromHex("#FFB340"))
	local egg=part("Egg",Enum.PartType.Block,v3(data.egg.size),Vector3.new(0,5.5,0),Color3.new(1,1,1))
	local mesh=Instance.new("SpecialMesh");mesh.MeshType=Enum.MeshType.Sphere;mesh.Parent=egg
	model.WorldPivot=CFrame.new()
	model:SetAttribute("EggMachineGreybox",true)
	return model
end
-- The template's clone (moved to machine-local origin by its own WorldPivot) or the greybox.
function World.template(data,storage)
	storage=storage or ServerStorage
	local found=storage:FindFirstChild(World.Model)
	if found and found:IsA("Model")and found:FindFirstChild("Body")and found:FindFirstChild("Egg")then local copy=found:Clone();copy.WorldPivot=CFrame.new();return copy end -- the rbxmx carries no WorldPivotData (Rojo): the parts are machine-local, so the pivot is the origin
	return World.greybox(data)
end
-- Builds the clones and attachments on a machine-local model (before PivotTo): Loose1..6 and DropEgg from Egg (then Egg
-- goes), the named attachments on Body at the data's points, the globe light. Returns the model.
function World.dress(model,data)
	local egg=model:FindFirstChild("Egg")
	local pivot=model:GetPivot()
	local function at(list)return pivot*CFrame.new(v3(list))end
	if egg then
		for index,row in ipairs(data.loose)do
			local copy=egg:Clone()
			copy.Name="Loose"..index
			copy.CFrame=at(row.at)
			copy.Color=Color3.fromHex(data.eggTypes[row.type]or "#FFFFFF")
			copy:SetAttribute("EggType",row.type)
			copy.Parent=model
		end
		local drop=egg:Clone()
		drop.Name="DropEgg"
		drop.Size=egg.Size*Corner.dropScale(data)
		drop.CFrame=at(data.chute.top)
		drop.Transparency=1
		drop.Parent=model
		egg:Destroy()
	end
	local body=model:FindFirstChild("Body")
	if body then
		local seat=v3(data.cup)+Vector3.new(0,(data.egg.size[2]*Corner.dropScale(data))/2,0)
		local points={DialPivot=v3(data.pivots.Dial),SproutPivot=v3(data.pivots.Sprout),ChuteTop=v3(data.chute.top),
			ChuteEnd=v3(data.chute["end"]),CupSeat=seat,GlobeLight=v3(data.light)}
		for _,name in ipairs(World.Points)do
			local a=Instance.new("Attachment")
			a.Name=name
			a.Parent=body -- parented first: WorldCFrame is relative to the part
			a.WorldCFrame=pivot*CFrame.new(points[name])
		end
		local light=Instance.new("PointLight")
		light.Name="GlobeGlow"
		light.Color,light.Range,light.Brightness,light.Shadows=World.GlobeLight.color,World.GlobeLight.range,0,false
		light:SetAttribute("HollowLamp",true)
		light:SetAttribute("HollowDayBrightness",0)
		light:SetAttribute("HollowNightBrightness",World.GlobeLight.night)
		light.Parent=body.GlobeLight
	end
	for _,part in ipairs(model:GetDescendants())do
		if part:IsA("BasePart")then part.Anchored=true;part.CanTouch=false end
	end
	return model
end

-- ── The floor ──────────────────────────────────────────────────────────────────────────────────────────────────
-- The machine stands across the plaza's inlay ring (R2 1): seat it on the highest hit of the centre and 16 rays on r 2.1,
-- within .25 of the lowest. nil when nothing answers (the default Y is used).
function World.floor(room,spot)
	local meshes=room and room:FindFirstChild("World")
	if not meshes then return nil end
	local params=RaycastParams.new()
	params.FilterType=Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances={meshes}
	local best=nil
	for k=-1,15 do
		local a=k/16*math.pi*2
		local r=if k<0 then 0 else 2.1
		local hit=workspace:Raycast(Vector3.new(spot.X+math.cos(a)*r,spot.Y+6,spot.Z+math.sin(a)*r),Vector3.new(0,-10,0),params)
		local y=hit and hit.Position.Y
		if y and math.abs(y-spot.Y)<=.6 and(best==nil or y>best)then best=y end
	end
	return best
end

-- ── Mount and apply ────────────────────────────────────────────────────────────────────────────────────────────
-- deps (specs): storage (template folder), on() (the switch), data (WorldV7Data), changed (a signal), floor(spot).
function World.mount(room,deps)
	deps=deps or {}
	local self=setmetatable({room=room,d=deps,hidden={},connections={}},World)
	local data=Corner.machineData()
	self.data=data
	self.world=deps.data -- nil: WorldV7Data
	local spot=Corner.Spot
	local y=(deps.floor or World.floor)(room,spot)or spot.Y
	self.frame=Corner.frame(y)
	local model=World.dress(World.template(data,deps.storage),data)
	model.Name=World.Model
	pcall(function()model.ModelStreamingMode=Enum.ModelStreamingMode.Persistent end)
	model:PivotTo(self.frame)
	model:SetAttribute("EggMachine",true)
	for _,name in ipairs(World.Moving)do
		local part=model:FindFirstChild(name)
		if part then part:SetAttribute("WorldRestCFrame",part.CFrame)end
	end
	self.model=model
	-- The prompt anchor: built at boot (the scene cache sees it), station Eggs only while the corner is on.
	local anchor=invisible(World.Prompt,Corner.promptFrame(y),Vector3.new(2,.6,.2))
	local prompt=Instance.new("ProximityPrompt")
	prompt.Name="TurnEggs"
	prompt.ActionText,prompt.ObjectText=UICopy.get("r5.station.Eggs.turn"),""
	prompt.UIOffset=Vector2.new(72,-16)
	prompt.KeyboardKeyCode,prompt.GamepadKeyCode=Enum.KeyCode.E,Enum.KeyCode.ButtonX
	prompt.ClickablePrompt,prompt.RequiresLineOfSight,prompt.HoldDuration=true,false,0
	prompt.Exclusivity=Enum.ProximityPromptExclusivity.OnePerButton
	prompt.MaxActivationDistance=Corner.Reach
	prompt.Enabled=false
	prompt.Parent=anchor
	anchor.Parent=room
	self.prompt=prompt
	local park=ServerStorage:FindFirstChild(World.Park)or Instance.new("Folder")
	park.Name=World.Park
	park.Parent=ServerStorage
	self.park=park
	model.Parent=park
	self.on=nil
	local function on()
		if deps.on then return deps.on()==true end
		return Corner.on()
	end
	self:apply(on())
	local changed=deps.changed or Onboard.changed("corner")
	table.insert(self.connections,changed:Connect(function()task.defer(function()if not self.destroyed then self:apply(on())end end)end))
	-- The landmark's switch moves only the nest's box and the light.
	pcall(World.shareLandmark,deps.storage)
	local landmarkChanged=deps.landmarkChanged or Onboard.changed("landmark")
	table.insert(self.connections,landmarkChanged:Connect(function()task.defer(function()
		if not self.destroyed then self:nestBox(self.on);self:light(self.on)end
	end)end))
	return self
end

-- The old station's parts this place can hide now: the interim list, plus W7_EggsStation__* once the split is there.
function World:stationParts()
	local meshes=self.room:FindFirstChild("World")
	local out={}
	if not meshes then return out end
	for _,name in ipairs(Corner.Hide)do
		local part=meshes:FindFirstChild(name)
		if part and part:IsA("BasePart")then table.insert(out,part)end
	end
	for _,part in ipairs(meshes:GetChildren())do
		if part:IsA("BasePart")and string.sub(part.Name,1,#Corner.SplitPrefix)==Corner.SplitPrefix then table.insert(out,part)end
	end
	return out
end
function World.hide(part,hidden)
	if hidden then
		if part:GetAttribute("WorldHidden")==true then return end
		part:SetAttribute("CornerWas",string.format("%s|%s|%s|%s",part.Transparency,tostring(part.CanCollide),tostring(part.CanQuery),tostring(part.CastShadow)))
		part:SetAttribute("WorldHidden",true)
		part.Transparency=1
		part.CanCollide=false
		part.CanQuery=false -- only after CanCollide is off
		part.CastShadow=false
	else
		if part:GetAttribute("WorldHidden")~=true then return end
		local was=part:GetAttribute("CornerWas")
		local t,c,q,s=string.match(type(was)=="string"and was or "","^([^|]+)|(%a+)|(%a+)|(%a+)$")
		part.Transparency=tonumber(t)or 0
		part.CanCollide=c=="true"
		part.CanQuery=q~="false"
		part.CastShadow=s~="false"
		part:SetAttribute("WorldHidden",nil)
		part:SetAttribute("CornerWas",nil)
	end
end

-- The nest's pet box at the nest's spot (destroyed and made again: the scene cache learns parts only when they arrive,
-- and every reader checks part.Parent). Built only where LoungeWorldV7Art.collision built one.
-- The Sleepy Nest landmark stands here now (NestLandmark): the corner on, the station split out, its own switch on.
function World:landmark(on)
	local landmarkOn=if self.d.landmark then self.d.landmark()==true else Landmark.on()
	return Landmark.applies(landmarkOn,on==true and Corner.split(self.world))
end
function World:nestBox(on)
	local regions=self.room:FindFirstChild("PetRegions")
	local old=regions and regions:FindFirstChild("SleepyNest")
	if not old then return end
	local spot=Corner.nestSpot(on,Corner.split(self.world))
	local Nest=require(Shared.Nest)
	-- The landmark's bowl is wider: pets keep Landmark.Block / 2 + .35 off its middle (NEST-LANDMARK-LOOK 2).
	local block=if self:landmark(on)then Landmark.Block else Nest.Block
	if math.abs(old.Position.X-spot.X)<.01 and math.abs(old.Position.Z-spot.Z)<.01 and math.abs(old.Size.X-block)<.01 then return end
	local y=old.Position.Y
	local box=old:Clone()
	box.CFrame=CFrame.lookAt(Vector3.new(spot.X,y,spot.Z),Vector3.new(Nest.Facing.X,y,Nest.Facing.Z))
	box.Size=Vector3.new(block,1,block)
	box:SetAttribute("GardenBlockedRegion",true)
	old:Destroy()
	box.Parent=regions
end
function World:light(on)
	local lights=self.room:FindFirstChild("Lights")
	local fixture=lights and lights:FindFirstChild("EggNestLight")
	local light=fixture and fixture:FindFirstChildOfClass("PointLight")
	if not light then return end
	local Layout=require(Shared.HollowWorldLayout)
	local offset,range=Corner.light(on)
	fixture.CFrame=CFrame.new(Layout.Stations.Eggs.Position+offset)
	light.Range=range
	-- The landmark's moon lantern replaces this light (NEST-LANDMARK-LOOK 4: never two).
	light.Enabled=not self:landmark(on)
end
-- The landmark's template for the clients (beta only: this module only runs under the ceiling). Each client clones it.
function World.shareLandmark(storage,replicated)
	storage=storage or ServerStorage
	replicated=replicated or game:GetService("ReplicatedStorage")
	local template=storage:FindFirstChild(Landmark.Template)
	if not template or replicated:FindFirstChild(Landmark.Template)then return replicated:FindFirstChild(Landmark.Template)end
	local copy=template:Clone()
	copy.Parent=replicated
	return copy
end
function World:apply(on)
	on=on==true
	if self.destroyed or self.on==on then return end
	self.on=on
	local room=self.room
	local sign=room:FindFirstChild("EggsSign")
	local old=sign and sign:FindFirstChildOfClass("ProximityPrompt")
	if old then old:SetAttribute("PocketClubStation",if on then nil else "Eggs");old.Enabled=not on end -- a client that joins after the swap never owned it, so LoungeStations never disables it
	self.prompt:SetAttribute("PocketClubStation",if on then "Eggs"else nil)
	self.model.Parent=if on then room else self.park
	local block=room:FindFirstChild(World.Block)
	if on and not block then
		local regions=room:FindFirstChild("PetRegions")or room
		local box=invisible(World.Block,self.frame*CFrame.new(0,.5,0),Corner.Block)
		box:SetAttribute("GardenBlockedRegion",true) -- before it is parented: the scene hook reads it on arrival
		box.Parent=regions
	elseif not on then
		local found=room:FindFirstChild(World.Block,true)
		if found then found:Destroy()end
	end
	self:nestBox(on)
	self:light(on)
	for _,part in ipairs(self:stationParts())do World.hide(part,on)end
end
function World:destroy()
	if self.destroyed then return end
	self:apply(false)
	self.destroyed=true
	for _,connection in ipairs(self.connections)do connection:Disconnect()end
	if self.model then self.model:Destroy()end
end
return World
