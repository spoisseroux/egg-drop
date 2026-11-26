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
-- skip them via ParkMount.isParkPart. Benches carry Roblox Seats at the manifest anchors (QA Q4: one
-- five-seat bench facing the playground; every mesh frame carries ParkPoseData.ImportTurn).
-- Moving parts (swings, see-saw beam, balls, castle stages) are created by each client
-- (ParkClient); their anchor frames are written as CFrame attributes on the PetPark model.
local AssetService=game:GetService("AssetService")
local Shared=game:GetService("ReplicatedStorage").Shared
local Flags=require(Shared.FeatureFlags)
local DefaultPark=require(Shared.ParkLayout)
local DataModule=require(Shared.ParkPoseData)
local function build(Park)
local Data=DataModule.forSite(Park)
local Mount={}
Mount.ModelName=if Park.Id=="arrival"then "PetPark"else "PetPark_"..Park.Id
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
	local template=if spec.id then(createMesh or Mount.meshTemplate)(spec.id)else nil
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
	model:SetAttribute("ParkId",Park.Id)
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
	-- A natural site (the Hollow): no kerb or star-orb posts in layout.static; its dressing instead (ParkHollowMount).
	-- options.carve=false (specs) builds the stones as their cylinder fallback without GeometryService.
	local dressing=if Park.Natural and Park.Dressing then folder(model,"Dressing")else nil
	if dressing then require(script.Parent.ParkHollowMount).buildStatic(dressing,Park)end
	model.Parent=room
	local function mountMeshes()
		for index,entry in ipairs(layout.static)do
			if not model.Parent then return end
			local part=Mount.makePart(entry.mesh,options.createMesh)
			part.Name=entry.mesh.."_"..index
			part.Size=entry.size;part.PivotOffset=Data.pivotOffset(entry.mesh)
			part.CFrame=entry.cframe
			if entry.mesh=="Park_GateStarOrb"then
				local light=Instance.new("PointLight")
				light.Color=Color3.fromHex("#FFE68A");light.Brightness=.8;light.Range=7;light.Shadows=false
				light.Parent=part
			end
			part.Parent=meshes
		end
		if dressing then
			-- Fable world R1 20: on the Top Lawn the stones are the hill's lip-stone kit (the path's rock), when the
			-- world finish pack is in; the Hollow keeps its carved stones.
			local kit=nil
			if Park.Terrace then
				local Finish=options.finish or require(script.Parent.WorldFinishMount)
				kit=function(row)
					return Finish.kitStone(1+row.seed%4,Vector3.new(row.x,row.y,row.z),row.size,row.yaw,options.finishEnv)
				end
			end
			require(script.Parent.ParkHollowMount).buildStones(dressing,Park,options.carve,kit)
		end
		model:SetAttribute("ParkMeshesReady",true)
	end
	if options.async==false then mountMeshes()else task.spawn(mountMeshes)end
	return model
end

return Mount
end
local Mount=build(DefaultPark)
local singleBuild=Mount.build
local cache={}
-- WORLD-FINISH-LOOK slice B: the Top Lawn (a terrace site) stands only with the island's sculpt in (workspace CliffDen,
-- set at server start before this runs): without it there is no terrace and no way up. options.cliff (specs) overrides.
local function terraceReady(options)
	if options.cliff~=nil then return options.cliff==true end
	return require(Shared.Tier).cliff()
end
-- The Paw Glade (ParkLayout.Glade, only with the Top Lawn on): the Hollow's dressing that stays and its own bench, beside
-- the parks (never in the lounge). options as Mount.build (createMesh, carve, async).
function Mount.buildGlade(room,options)
	options=options or {}
	local Glade=DefaultPark.Glade
	if not Glade or typeof(room)~="Instance"then return nil end
	local Data=DataModule.forSite(DefaultPark)
	local static,colliders,seats=Data.benchParts(Glade.bench)
	local logBox=if Glade.log then Data.logBox(Glade.log)else nil
	local function makePart(name)
		local part=Mount.makePart(name,options.createMesh)
		part.PivotOffset=Data.pivotOffset(name)
		return part
	end
	return require(script.Parent.ParkHollowMount).buildGlade(room,Glade,{static=static,colliders=colliders,seats=seats},
		logBox,makePart,options.carve,options.async)
end
function Mount.build(room,options)
	options=options or {}
	if options.siteId then
		local layout=DefaultPark.ById[options.siteId]
		if not layout then return nil end
		if layout.Id==DefaultPark.Id then return singleBuild(room,options)end
		if layout.Terrace and not terraceReady(options)then return nil end
		cache[layout.Id]=cache[layout.Id]or build(layout)
		return cache[layout.Id].build(room,options)
	end
	local primary=singleBuild(room,options)
	if not primary then return nil end
	for _,layout in ipairs(DefaultPark.Sites)do
		if layout.Id~=DefaultPark.Id and not(layout.Terrace and not terraceReady(options))then
			cache[layout.Id]=cache[layout.Id]or build(layout)
			cache[layout.Id].build(room,options)
		end
	end
	-- The glade with the Top Lawn only (code review: a Studio session without the sculpt keeps the cliff foot as it is,
	-- with neither; the Hollow comes back only with ParkTopLawn off).
	if DefaultPark.Glade and terraceReady(options)then Mount.buildGlade(room,options)end
	return primary
end
return Mount
