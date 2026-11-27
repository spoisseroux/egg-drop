-- The Aero world kit (WORLD-PASS-2026-11-22 row 6; artifacts/world-pass-2026-11-22/reexport/PLAN.md). Client only and
-- looks only, like the rest of the Aero layer: AeroWorld builds it while Aero is on (budget level under 2) and destroys
-- it with the layer. It clones ReplicatedStorage.AeroKit's templates (the server copies them there only where the Aero
-- ceiling passes) into one local folder `AeroKit` under the room, from Shared.WorldAeroKit:
--   * crowns: the island's tree crowns as separate parts (3 shared meshes + the Hatch Tree's), each at rest on its tree,
--     WorldDressing "crown" with WorldRestCFrame and WorldPivot (the trunk top), so WindClient sways them;
--   * rest: the blob bushes the merged crown meshes also hold, static;
--   * falls (LOOK-R2 2, LOOK-R4): wet rock faces with ledges, one streaked sheet per drop and wet rocks (one vertex-coloured
--     mesh on the falls atlas), the foam rolls, lips and apron as their own part (Kit.glow), plus one
--     invisible ball per rock that the local avatar cannot walk through (pets never reach a rock:
--     build_world_aero_kit.py checks it);
--   * fountain (LOOK-R2 3): a two-tier stone fountain in the Bubble Spring's basin, an invisible column at its stem.
-- Lime crowns carry their own matte SurfaceAppearance (the lime map at roughness .92) and the attribute AeroMatteLime, so
-- AeroWorld leaves them as they are for lime. While it stands, a crown the camera is inside goes see-through (fader).
-- Hiding the merged meshes it replaces (WorldAeroKit.hides) and the Tumble sheet beams is AeroWorld's, in its own
-- records. Every visual part carries WorldMesh, so bounds queries skip it as they skip the merged meshes.
local Kit={}
Kit.Folder="AeroKit"
Kit.Templates="AeroKit"
-- The Roblox import turns each mesh by pi about Y (build_world_v7_assets.py: every island CFrame carries Ry(pi)).
Kit.Turn=CFrame.Angles(0,math.pi,0)

local function vector(list)return Vector3.new(list[1],list[2],list[3])end

-- A shared crown on its tree: the part's CFrame and Size, and the pivot it turns about. `mesh` is WorldAeroKit.meshes[name].
-- pivotToCentre is the mesh's bounds centre from its pivot in the tree's frame at scale 1, before the tree's yaw.
-- Beta 38 (TreeGrades.kit): a graded crown's `wide` widens it across (X and Z, in its own frame) on top of its scale.
function Kit.crownFrame(crown,mesh)
	local s=crown.scale
	local w=crown.wide or 1
	local scale=Vector3.new(s*w,s,s*w)
	local yaw=CFrame.Angles(0,crown.yaw,0)
	local pivot=vector(crown.pivot)
	local centre=pivot+yaw:VectorToWorldSpace(vector(mesh.pivotToCentre)*scale)
	return CFrame.new(centre)*yaw*Kit.Turn,vector(mesh.size)*scale,pivot
end
-- Beta 38: a shared trunk on its tree (WorldAeroTrunks): the part's CFrame and Size. rootToCentre is the mesh's bounds
-- centre from the tree's root in its frame at scale 1, before the yaw; `grade` the trunk's TreeGrades multiplier.
function Kit.trunkFrame(row,mesh,grade)
	local scale=row.scale*(grade or 1)
	local yaw=CFrame.Angles(0,row.yaw,0)
	local centre=vector(row.root)+yaw:VectorToWorldSpace(vector(mesh.rootToCentre)*scale)
	return CFrame.new(centre)*yaw*Kit.Turn,vector(mesh.size)*scale
end
-- Beta 38: is the trunk pack whole (every mesh of `data` a MeshPart template in `templates`)?
function Kit.trunksWhole(data,templates)
	if type(data)~="table"or type(data.meshes)~="table"or templates==nil then return false end
	local any=false
	for name in pairs(data.meshes)do
		local t=templates:FindFirstChild(name)
		if not(t and t:IsA("MeshPart"))then return false end
		any=true
	end
	return any
end
-- A part authored in place (rest, falls): at its bounds centre.
function Kit.placedFrame(mesh)
	return CFrame.new(vector(mesh.center))*Kit.Turn,vector(mesh.size)
end

local function inert(p)
	p.Anchored=true
	p.CanCollide=false
	p.CanQuery=false
	p.CanTouch=false
end

-- options: data (WorldAeroKit), templates (folder of MeshParts), parent (the room). Returns {folder, data, parts,
-- destroy} or throws (a missing template, bad data): AeroWorld catches it and keeps the merged garden.
-- LOOK-R4 round 2: the falls foam's emissive lift (WorldAero.Waterfall.Kit.FoamGlow) on its own SurfaceAppearance. A
-- missing skin or an engine without the properties leaves the foam as drawn.
function Kit.glow(part)
	local ok,Values=pcall(function()
		return require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("WorldAero"))
	end)
	local look=ok and Values.Waterfall and Values.Waterfall.Kit.FoamGlow
	local skin=part:FindFirstChildOfClass("SurfaceAppearance")
	if not(look and skin)then return false end
	-- The mask is authored on the template (build_world_aero_kit_assets.py): game scripts cannot write it.
	return pcall(function()
		skin.EmissiveStrength=look.Strength
		skin.EmissiveTint=look.Tint
	end)
end
function Kit.build(options)
	local data,templates=options.data,options.templates
	assert(type(data)=="table"and type(data.meshes)=="table"and type(data.crowns)=="table","no kit data")
	assert(templates~=nil,"no kit templates")
	local folder=Instance.new("Folder")
	folder.Name=Kit.Folder
	local parts={}
	local function clone(name)
		local template=templates:FindFirstChild(name)
		assert(template and template:IsA("MeshPart"),"kit template missing: "..tostring(name))
		local p=template:Clone()
		inert(p)
		p:SetAttribute("WorldMesh",true)
		table.insert(parts,p)
		return p
	end
	for _,crown in ipairs(data.crowns)do
		local mesh=data.meshes[crown.mesh]
		assert(mesh and mesh.pivotToCentre,"kit crown without a mesh: "..tostring(crown.mesh))
		local cframe,size,pivot=Kit.crownFrame(crown,mesh)
		local p=clone(crown.mesh)
		p.Size,p.CFrame=size,cframe
		p.CastShadow=false -- it moves
		p:SetAttribute("WorldDressing","crown")
		p:SetAttribute("WorldRestCFrame",cframe)
		p:SetAttribute("WorldPivot",pivot)
		p.Parent=folder
	end
	local names={}
	for name,mesh in pairs(data.meshes)do
		if mesh.role=="rest"or mesh.role=="falls"or mesh.role=="fountain"then table.insert(names,name)end
	end
	table.sort(names)
	for _,name in ipairs(names)do
		local cframe,size=Kit.placedFrame(data.meshes[name])
		local p=clone(name)
		p.Size,p.CFrame=size,cframe
		if string.sub(name,-#"__kitfoam")=="__kitfoam"then Kit.glow(p)end
		p.Parent=folder
	end
	-- Beta 38 (the tree grades): the trunk pack, when given whole (options.trunks = {data = WorldAeroTrunks, templates,
	-- grade(tree) -> number}): each tree's shared trunk at its grade and the landmarks' trunks as they are, static and
	-- shadowed like the island's bark. The merged W7_Trunks__bark then hides its visual (AeroWorld; its collision stays).
	local trunks=options.trunks
	local hides=table.clone(data.hides or {})
	if trunks and Kit.trunksWhole(trunks.data,trunks.templates)then
		local function cloneTrunk(name)
			local p=trunks.templates:FindFirstChild(name):Clone()
			inert(p)
			p:SetAttribute("WorldMesh",true)
			p:SetAttribute("TreeTrunk",true)
			table.insert(parts,p)
			return p
		end
		for _,row in ipairs(trunks.data.trunks)do
			local mesh=trunks.data.meshes[row.mesh]
			assert(mesh and mesh.rootToCentre,"kit trunk without a mesh: "..tostring(row.mesh))
			local cframe,size=Kit.trunkFrame(row,mesh,trunks.grade and trunks.grade(row.tree)or 1)
			local p=cloneTrunk(row.mesh)
			p.Size,p.CFrame=size,cframe
			p.Parent=folder
		end
		for name,mesh in pairs(trunks.data.meshes)do
			if mesh.role=="rest"then
				local cframe,size=Kit.placedFrame(mesh)
				local p=cloneTrunk(name)
				p.Size,p.CFrame=size,cframe
				p.Parent=folder
			end
		end
		for _,name in ipairs(trunks.data.hides or {})do table.insert(hides,name)end
		trunks=true
	else
		trunks=false
	end
	for index,rock in ipairs(data.rocks or {})do
		local ball=Instance.new("Part")
		ball.Name="RockCollision"
		ball.Shape=Enum.PartType.Ball
		ball.Size=Vector3.one*(rock.radius*2)
		ball.CFrame=CFrame.new(vector(rock.center))
		ball.Anchored,ball.CanCollide,ball.CanQuery,ball.CanTouch,ball.CastShadow=true,true,false,false,false
		ball.Transparency=1
		ball:SetAttribute("AeroKitRock",index)
		ball.Parent=folder
	end
	local spot=data.fountain
	if spot then
		local height=spot.top-spot.centre[2]
		local stem=Instance.new("Part")
		stem.Name="FountainCollision"
		stem.Shape=Enum.PartType.Cylinder
		stem.Size=Vector3.new(height,1.1,1.1) -- a cylinder lies along X: turned upright below
		stem.CFrame=CFrame.new(spot.centre[1],spot.centre[2]+height/2,spot.centre[3])*CFrame.Angles(0,0,math.pi/2)
		stem.Anchored,stem.CanCollide,stem.CanQuery,stem.CanTouch,stem.CastShadow=true,true,false,false,false
		stem.Transparency=1
		stem.Parent=folder
	end
	for _,p in ipairs(parts)do
		if string.sub(p.Name,-#"__foliage_blossom")=="__foliage_blossom"and p:FindFirstChildOfClass("SurfaceAppearance")then
			p:SetAttribute("AeroMatteLime",true)
		end
	end
	-- The fader before the folder goes in: a throw here leaves nothing in the room (code review r2).
	local fader=options.fade and Kit.fader(parts,options.fade)
	folder.Parent=options.parent
	local handle={folder=folder,data=data,parts=parts,hides=hides,trunks=trunks}
	function handle.destroy()
		if fader then fader.destroy()end
		pcall(function()folder:Destroy()end)
	end
	return handle
end

-- LOOK-R2 1: a crown the camera is inside (its box grown by Fade.Margin) goes to Fade.Camera clear, one the avatar's root is
-- inside to Fade.Root, through LocalTransparencyModifier, stepped every frame and written only on change. Off whenever
-- deps.active() is false (deck, focus, a Dash race: other owners of the property then): every crown goes straight back to
-- 0 and nothing more is written. deps: active(), camera() -> Vector3?, root() -> Vector3?, now(), connect(fn) -> conn.
Kit.Fade=table.freeze({Margin=1.5,Camera=.8,Root=.5,In=.25,Out=.4,Every=.15})
function Kit.fadeTarget(part,camera,root)
	local margin=Kit.Fade.Margin
	local function inside(point)
		if typeof(point)~="Vector3"then return false end
		local p=part.CFrame:PointToObjectSpace(point)
		local half=part.Size/2
		return math.abs(p.X)<=half.X+margin and math.abs(p.Y)<=half.Y+margin and math.abs(p.Z)<=half.Z+margin
	end
	if inside(camera)then return Kit.Fade.Camera end
	if inside(root)then return Kit.Fade.Root end
	return 0
end
function Kit.fader(parts,deps)
	local crowns={}
	for _,p in ipairs(parts)do
		if p:GetAttribute("WorldDressing")=="crown"then table.insert(crowns,{part=p,value=0,goal=0})end
	end
	local self={crowns=crowns,clock=0,open=false}
	local function settle()
		for _,c in ipairs(crowns)do
			if c.value~=0 then c.value=0;pcall(function()c.part.LocalTransparencyModifier=0 end)end
			c.goal=0
		end
	end
	function self.step(dt)
		if not deps.active()then
			if self.open then self.open=false;settle()end
			return
		end
		self.open=true
		self.clock+=dt
		if self.clock>=Kit.Fade.Every then
			self.clock=0
			local camera,root=deps.camera(),deps.root()
			for _,c in ipairs(crowns)do c.goal=Kit.fadeTarget(c.part,camera,root)end
		end
		for _,c in ipairs(crowns)do
			if c.value~=c.goal then
				local rate=Kit.Fade.Camera/(if c.goal>c.value then Kit.Fade.In else Kit.Fade.Out)
				c.value=if c.goal>c.value then math.min(c.goal,c.value+rate*dt)else math.max(c.goal,c.value-rate*dt)
				pcall(function()c.part.LocalTransparencyModifier=c.value end)
			end
		end
	end
	local link=deps.connect and deps.connect(function(dt)
		local ok=pcall(self.step,math.min(dt,.1))
		if not ok then settle()end
	end)
	function self.destroy()
		if link then link:Disconnect();link=nil end
		settle()
	end
	return self
end

return Kit
