-- The Aero world kit (WORLD-PASS-2026-11-22 row 6; artifacts/world-pass-2026-11-22/reexport/PLAN.md). Client only and
-- looks only, like the rest of the Aero layer: AeroWorld builds it while Aero is on (budget level under 2) and destroys
-- it with the layer. It clones ReplicatedStorage.AeroKit's templates (the server copies them there only where the Aero
-- ceiling passes) into one local folder `AeroKit` under the room, from Shared.WorldAeroKit:
--   * crowns: the island's tree crowns as separate parts (3 shared meshes + the Hatch Tree's), each at rest on its tree,
--     WorldDressing "crown" with WorldRestCFrame and WorldPivot (the trunk top), so WindClient sways them;
--   * rest: the blob bushes the merged crown meshes also hold, static;
--   * falls: Tumble Falls' bowed back sheets (today's falls texture) and, as one vertex-coloured mesh, the foam lips and
--     wet rocks, plus one invisible ball per rock that the local avatar cannot walk through (pets never reach a rock:
--     build_world_aero_kit.py checks it).
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
function Kit.crownFrame(crown,mesh)
	local scale=crown.scale
	local yaw=CFrame.Angles(0,crown.yaw,0)
	local pivot=vector(crown.pivot)
	local centre=pivot+yaw:VectorToWorldSpace(vector(mesh.pivotToCentre)*scale)
	return CFrame.new(centre)*yaw*Kit.Turn,vector(mesh.size)*scale,pivot
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
		if mesh.role=="rest"or mesh.role=="falls"then table.insert(names,name)end
	end
	table.sort(names)
	for _,name in ipairs(names)do
		local cframe,size=Kit.placedFrame(data.meshes[name])
		local p=clone(name)
		p.Size,p.CFrame=size,cframe
		p.Parent=folder
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
	folder.Parent=options.parent
	local handle={folder=folder,data=data,parts=parts}
	function handle.destroy()
		pcall(function()folder:Destroy()end)
	end
	return handle
end

return Kit
