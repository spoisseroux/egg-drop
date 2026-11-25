-- Flat ground flower patches for World 1 v7 (batch 2026-11-13, W1). Client only, nothing replicates.
-- One thin invisible anchored part per patch (WorldDressing.Flowers), lying on the fitted ground plane with an
-- upward-facing Decal on its Top face: flowers read as part of the grass, not as billboards. A 4 Hz pass parks
-- patches beyond the cull distance (90 studs on touch phones, 150 elsewhere) by unparenting whole patches.
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local World=require(Shared:WaitForChild("HollowWorldLayout"))
local Dressing=require(Shared:WaitForChild("WorldDressing"))
local CliffDressing=require(Shared:WaitForChild("CliffDenDressing"))

local Flowers={}
Flowers.Interval=.25

local Controller={};Controller.__index=Controller

-- QA-R2-LOOK 6: the patches redrawn to sit in the graded lawn, on the beta place only (Alive's place ceiling for
-- "life", read once); everywhere else today's textures. Per kind: an R2 id if there is one, else today's id.
-- Answers the texture table and the Decal transparency. `beta` overrides the place check (specs).
function Flowers.textures(beta)
	if beta==nil then
		local ok,on=pcall(function()return require(Shared:WaitForChild("Alive")).ceiling("life")end)
		beta=ok and on==true
	end
	if not beta then return Dressing.Textures,0 end
	local out={}
	for _,kind in ipairs(Dressing.Kinds)do
		local r2=Dressing.TexturesR2 and Dressing.TexturesR2[kind]
		out[kind]=if type(r2)=="string"and r2~=""then r2 else Dressing.Textures[kind]
	end
	return out,Dressing.TransparencyR2 or 0
end
-- The natural park sites (the Hollow, beta and Studio: ParkLayout's place switch); none on live. The Hollow brings its
-- own flower drift, so the old patches whose centre falls inside its circle (8 today: by the log, on the slide's toe,
-- by the see-saw, in the palm) are not drawn there.
function Flowers.naturalParks()
	local ok,Park=pcall(function()return require(Shared:WaitForChild("ParkLayout"))end)
	local out={}
	if ok and type(Park)=="table"then for _,site in ipairs(Park.Sites or {})do if site.Natural then table.insert(out,site)end end end
	return out
end
-- Builds the patch parts (unparented). Kinds without an uploaded texture are skipped, and patches inside a natural park.
-- options (specs): textures, transparency, beta, parks (the natural sites; default Flowers.naturalParks()).
function Flowers.build(options)
	options=options or {}
	local textures,transparency=options.textures,options.transparency or 0
	if not textures then textures,transparency=Flowers.textures(options.beta)end
	local parks=options.parks or Flowers.naturalParks()
	local patches={}
	local cliff=options.cliffDen
	if cliff==nil then cliff=workspace:GetAttribute(CliffDressing.Attribute)==true end
	for index,entry in ipairs(Dressing.Flowers)do
		if index>Dressing.MaxFlowers then break end
		local inside=false
		for _,site in ipairs(parks)do if site.inside(Vector3.new(entry[1],0,entry[3]),0)then inside=true;break end end
		if inside then continue end
		-- The beta's sculpt: patches over the terrace top or in the cliff path's corridor are skipped.
		if cliff and CliffDressing.skip(entry[1],entry[3],true)then continue end
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
		decal.Transparency=transparency
		decal.Parent=part
		table.insert(patches,{part=part,position=part.Position})
	end
	return patches
end

-- Beta 14 QA W3 row 7 (GARDEN-LIFE-BUILD-PLAN section 4): texture on the ground (GroundDressing: leaf litter under the
-- largest crowns, mown and clover lawn patches, frayed path edges). Static plates culled with the flowers, at every budget
-- level; only while the Alive `scene` switch is on (the beta place and Studio: its ceiling; never on live). A texture still
-- pending upload (LifeArtR4 id nil) builds no plate for it. options (specs): scene (boolean, else Alive.on("scene")),
-- art(key) -> id?, groundY(x, z).
function Flowers.sceneOn(options)
	if options and options.scene~=nil then return options.scene==true end
	local ok,on=pcall(function()return require(Shared:WaitForChild("Alive")).on("scene")end)
	return ok and on==true
end
function Flowers.groundPlates(options)
	options=options or {}
	local plates={}
	if not Flowers.sceneOn(options)then return plates end
	local Ground=require(Shared:WaitForChild("GroundDressing"))
	local art=options.art or function(key)return require(Shared:WaitForChild("LifeArtR4")).id(key)end
	local groundY=options.groundY or World.groundY
	local Look=Ground.Look
	local function plate(name,row,size,texture,colour,look)
		if type(texture)~="string"or texture==""then return end
		local x,z=row[1],row[3]
		local okY,y=pcall(groundY,x,z)
		if not okY or type(y)~="number"or y~=y then y=row[2]end
		local part=Instance.new("Part")
		part.Name=name
		part.Anchored,part.CanCollide,part.CanQuery,part.CanTouch=true,false,false,false
		part.CastShadow,part.Transparency=false,1
		part.Material=Enum.Material.SmoothPlastic
		part.Size=size
		part.CFrame=CFrame.new(x,y+look.lift,z)*CFrame.Angles(0,row[5],0)
		local decal=Instance.new("Decal")
		decal.Name="Ground"
		decal.Face=Enum.NormalId.Top
		decal.Texture=texture
		decal.Color3=colour or Color3.new(1,1,1)
		decal.Transparency=look.transparency
		decal.Parent=part
		table.insert(plates,{part=part,position=part.Position,ground=true})
	end
	for _,row in ipairs(Ground.Litter)do
		plate("GroundLitter",row,Vector3.new(row[4],Dressing.Thickness,row[4]),art(Look.litter.texture),nil,Look.litter)
	end
	for _,row in ipairs(Ground.Lawn)do
		local b=row[6]=="b"
		plate("GroundLawn",row,Vector3.new(row[4],Dressing.Thickness,row[4]),art(if b then Look.lawn.b else Look.lawn.a),
			if b then Look.lawn.colourB else Look.lawn.colourA,Look.lawn)
	end
	for _,row in ipairs(Ground.Fray)do
		plate("GroundFray",row,Vector3.new(row[4],Dressing.Thickness,Look.fray.depth),art(Look.fray.texture),nil,Look.fray)
	end
	return plates
end
-- The ground plates follow the `scene` switch: built on, destroyed off (the flowers are untouched).
function Controller:syncGround(options)
	local on=Flowers.sceneOn(options)
	if on==(self.ground~=nil)then return end
	if on then
		self.ground=Flowers.groundPlates(options)
		for _,plate in ipairs(self.ground)do table.insert(self.patches,plate)end
	else
		for i=#self.patches,1,-1 do
			if self.patches[i].ground then self.patches[i].part:Destroy();table.remove(self.patches,i)end
		end
		self.ground=nil
	end
	local camera=workspace.CurrentCamera
	if camera then self:cull(camera.CFrame.Position)end
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
	if self.sceneLink then self.sceneLink:Disconnect()end
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
	self:syncGround(options)
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
	-- Beta 14: the ground plates follow the `scene` switch (only where its ceiling passes: never on live).
	pcall(function()
		local Alive=require(Shared:WaitForChild("Alive"))
		if not Alive.ceiling("scene")then return end
		local controller=Flowers.controller
		controller.sceneLink=Alive.changed("scene"):Connect(function()controller:syncGround()end)
	end)
	return Flowers.controller
end

return Flowers
