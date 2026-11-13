-- Flat ground flower patches for World 1 v7 (batch 2026-11-13, W1). Client only, nothing replicates.
-- One thin invisible anchored part per patch (WorldDressing.Flowers), lying on the fitted ground plane with an
-- upward-facing Decal on its Top face: flowers read as part of the grass, not as billboards. A 4 Hz pass parks
-- patches beyond the cull distance (90 studs on touch phones, 150 elsewhere) by unparenting whole patches.
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local World=require(Shared:WaitForChild("HollowWorldLayout"))
local Dressing=require(Shared:WaitForChild("WorldDressing"))

local Flowers={}
Flowers.Interval=.25

local Controller={};Controller.__index=Controller

-- Builds the patch parts (unparented). Kinds without an uploaded texture are skipped.
function Flowers.build(options)
	options=options or {}
	local textures=options.textures or Dressing.Textures
	local patches={}
	for index,entry in ipairs(Dressing.Flowers)do
		if index>Dressing.MaxFlowers then break end
		local kind=Dressing.Kinds[entry[6]]
		local texture=textures[kind]
		if type(texture)~="string"or texture==""then continue end
		local part=Instance.new("Part")
		part.Name="FlowerPatch_"..kind
		part.Anchored,part.CanCollide,part.CanQuery,part.CanTouch=true,false,false,false
		part.CastShadow,part.Transparency=false,1
		part.Material=Enum.Material.SmoothPlastic
		part.Size=Vector3.new(entry[4],Dressing.Thickness,entry[4])
		part.CFrame=Dressing.flowerCFrame(entry)
		local decal=Instance.new("Decal")
		decal.Name="Flowers"
		decal.Face=Enum.NormalId.Top
		decal.Texture=texture
		decal.Parent=part
		table.insert(patches,{part=part,position=part.Position})
	end
	return patches
end

function Flowers.cullDistance(touch)
	return if touch then Dressing.CullPhone else Dressing.CullDesktop
end

function Controller:cull(origin)
	local limit=self.distance*self.distance
	local shown=0
	for _,patch in ipairs(self.patches)do
		local d=patch.position-origin
		local visible=d.X*d.X+d.Z*d.Z<=limit
		local parent=if visible then self.folder else nil
		if patch.part.Parent~=parent then patch.part.Parent=parent end
		if visible then shown+=1 end
	end
	self.shown=shown
	return shown
end

function Controller:step(dt)
	if self.destroyed then return end
	self.elapsed+=dt
	if self.elapsed<Flowers.Interval then return end
	self.elapsed=0
	local camera=workspace.CurrentCamera
	if camera then self:cull(camera.CFrame.Position)end
end

function Controller:destroy()
	if self.destroyed then return end
	self.destroyed=true
	if self.connection then self.connection:Disconnect()end
	for _,patch in ipairs(self.patches)do patch.part:Destroy()end
	table.clear(self.patches)
	self.folder:Destroy()
	if Flowers.controller==self then Flowers.controller=nil end
end

function Flowers.new(options)
	options=options or {}
	local folder=Instance.new("Folder")
	folder.Name=options.name or "EggDropGroundFlowers"
	local touch=options.touch
	if touch==nil then touch=UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled end
	local self=setmetatable({folder=folder,patches=Flowers.build(options),distance=options.distance or Flowers.cullDistance(touch),
		elapsed=0,shown=0},Controller)
	folder.Parent=options.parent or workspace
	if options.auto then
		self.connection=RunService.Heartbeat:Connect(function(dt)self:step(dt)end)
		local camera=workspace.CurrentCamera
		if camera then self:cull(camera.CFrame.Position)end
	end
	return self
end

-- Started once by HollowClock.start (v7 world only).
function Flowers.start()
	if World.WorldVersion~="v7"then return nil end
	if Flowers.controller and not Flowers.controller.destroyed then return Flowers.controller end
	Flowers.controller=Flowers.new({auto=true})
	return Flowers.controller
end

return Flowers
