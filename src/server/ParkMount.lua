-- Pet Park equipment mount (BUILD-PLAN 2026-11-13, slice K3; architect change 8). Code-mounted like
-- the deck meshes: MeshId is not scriptable, so each mesh comes from AssetService:CreateMeshPartAsync
-- (pcall, cached per id, cloned per use, Size set from the manifest because MeshSize reads 100x).
-- A mesh that fails becomes a grey box of the same size.
--
-- Built only when FeatureFlags.Park is on (the host checks the flag; build() checks it again).
-- Visual meshes: Anchored, CanCollide/CanQuery/CanTouch = false, so GardenPathPlanner,
-- GardenWalkability and every pet ground/wander raycast (RespectCanCollide + Include lounge) see
-- straight through them. Players get invisible simple colliders (CanCollide true, CanQuery false:
-- raycasts never hit a CanQuery=false part) tagged `ParkCollider`; init.server's rest-path solids
-- skip them via ParkMount.isParkPart. Benches carry Roblox Seats at the manifest anchors.
-- Moving parts (swings, see-saw beam, balls, castle stages) are created by each client
-- (ParkClient); their anchor frames are written as CFrame attributes on the PetPark model.
local AssetService=game:GetService("AssetService")
local Shared=game:GetService("ReplicatedStorage").Shared
local Flags=require(Shared.FeatureFlags)
local Park=require(Shared.ParkLayout)
local Data=require(Shared.ParkPoseData)
local Mount={}
Mount.ModelName="PetPark"
Mount.Grey=Color3.fromHex("#C9C2D6")

local cache={}
-- One resolved MeshPart per id (nil when the load failed); callers Clone it.
function Mount.meshTemplate(id)
	local hit=cache[id]
	if hit~=nil then return hit or nil end
	local ok,made=pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromUri(id),{CollisionFidelity=Enum.CollisionFidelity.Box,RenderFidelity=Enum.RenderFidelity.Automatic})
	end)
	if not ok or not made then
		ok,made=pcall(AssetService.CreateMeshPartAsync,AssetService,id)
	end
	if ok and made then cache[id]=made;return made end
	warn("Egg Drop: park mesh failed",id,made)
	cache[id]=false
	return nil
end

local function visual(part)
	part.Anchored=true;part.CanCollide=false;part.CanQuery=false;part.CanTouch=false
	part.CastShadow=true;part.Material=Enum.Material.SmoothPlastic
	part:SetAttribute("ParkPart",true)
	return part
end
-- A mesh (or its grey-box fallback) for one static entry.
function Mount.makePart(name,createMesh)
	local spec=Data.Meshes[name]
	local template=(createMesh or Mount.meshTemplate)(spec.id)
	local part
	if template then
		part=template:Clone()
		if part:IsA("MeshPart")then part.TextureID=Data.Texture end
	else
		part=Instance.new("Part");part.Color=Mount.Grey
		part.TopSurface,part.BottomSurface=Enum.SurfaceType.Smooth,Enum.SurfaceType.Smooth
		part:SetAttribute("ParkFallback",true)
	end
	part.Name=name
	return visual(part)
end
function Mount.isParkPart(part)
	return part:GetAttribute("ParkPart")==true or part:GetAttribute("ParkCollider")==true or part:GetAttribute("ParkSeat")==true
end

local function folder(parent,name)
	local node=Instance.new("Folder");node.Name=name;node.Parent=parent;return node
end

-- Builds the PetPark model under `room` (init.server passes workspace: beside the lounge, never inside it). Returns the model, or nil when the flag is
-- off / the world has no park. options: enabled (default FeatureFlags.Park), createMesh(id) ->
-- MeshPart|nil (default AssetService, cached), async (default true: meshes load in a task while
-- colliders and seats exist at once).
function Mount.build(room,options)
	options=options or {}
	local enabled=if options.enabled==nil then Flags.Park==true else options.enabled==true
	if not enabled or not Park.Enabled or typeof(room)~="Instance" then return nil end
	local existing=room:FindFirstChild(Mount.ModelName)
	if existing then existing:Destroy()end
	local layout=Data.layout()
	local model=Instance.new("Model");model.Name=Mount.ModelName
	model:SetAttribute("ParkVersion",Park.Version)
	for key,frame in pairs(layout.anchors)do model:SetAttribute(key,frame)end
	local meshes=folder(model,"Meshes")
	local colliders=folder(model,"Colliders")
	local seats=folder(model,"Seats")
	for index,box in ipairs(layout.colliders)do
		local part=Instance.new("Part")
		part.Name=box.group.."Collider"..index;part.Size=box.size;part.CFrame=box.cframe
		part.Anchored=true;part.CanCollide=true;part.CanQuery=false;part.CanTouch=false
		part.Transparency=1;part.CastShadow=false
		part:SetAttribute("ParkCollider",true)
		part.Parent=colliders
	end
	for _,spot in ipairs(layout.seats)do
		local seat=Instance.new("Seat")
		seat.Name="Bench_"..spot.bench.."_"..spot.index;seat.Size=spot.size;seat.CFrame=spot.cframe
		-- Code review: no touch-to-sit (walking through a bench seated players by accident);
		-- a "Sit" prompt seats the player on purpose.
		seat.Anchored=true;seat.CanCollide=false;seat.CanQuery=false;seat.CanTouch=false
		seat.Transparency=1;seat.CastShadow=false
		seat:SetAttribute("ParkSeat",true)
		local prompt=Instance.new("ProximityPrompt")
		prompt.Name="SitPrompt";prompt.ActionText="Sit";prompt.ObjectText="Bench"
		prompt.MaxActivationDistance=7;prompt.RequiresLineOfSight=false;prompt.HoldDuration=0
		prompt.Parent=seat
		prompt.Triggered:Connect(function(player)
			local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid and not seat.Occupant and humanoid.Health>0 and not humanoid.Sit then seat:Sit(humanoid)end
		end)
		seat.Parent=seats
	end
	model.Parent=room
	local function mountMeshes()
		for index,entry in ipairs(layout.static)do
			if not model.Parent then return end
			local part=Mount.makePart(entry.mesh,options.createMesh)
			part.Name=entry.mesh.."_"..index
			part.Size=entry.size;part.PivotOffset=CFrame.new(Data.Meshes[entry.mesh].pivot)
			part.CFrame=entry.cframe
			if entry.mesh=="Park_GateStarOrb"then
				local light=Instance.new("PointLight")
				light.Color=Color3.fromHex("#FFE68A");light.Brightness=.8;light.Range=7;light.Shadows=false
				light.Parent=part
			end
			part.Parent=meshes
		end
		model:SetAttribute("ParkMeshesReady",true)
	end
	if options.async==false then mountMeshes()else task.spawn(mountMeshes)end
	return model
end

return Mount
