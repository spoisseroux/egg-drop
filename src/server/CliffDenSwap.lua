-- The cliff path, the Play Den and the terrace top (CLIFF-DEN-ISLAND-SCOPE, architect review): the beta's island sculpt.
-- At server start only, on the beta place (or in Studio), the island's carved parts are swapped for the beta pack's
-- copies and new pieces in the world clone, before LoungeWorldV7Art parents it. Never at runtime: WorldMotion,
-- EggCornerWorld's floor list and AeroWorld's paint records are all built once from what arrives.
--
-- The pack is ServerStorage.WorldBeta (mounted by default.project.json only; live builds from launch.project.json and
-- never has it): WorldBeta.WorldV7 holds W7_CD_* (carved copies and new art) and W7C_CD_* (invisible collision), and
-- WorldBeta's `Version` attribute must equal CliffDenData.version, or nothing is swapped (a stale pack falls back to
-- the live island whole). Two layers (FeatureFlags.CliffDen): "den" swaps the sculpt and sets the attribute CliffDen =
-- true on workspace and the world model; "pocket" swaps only the cave's bars out of the palette. Both have the bars as
-- their own part, which Swap.bars hides while the Play Den is open.
local ServerStorage=game:GetService("ServerStorage")
local Shared=game:GetService("ReplicatedStorage").Shared
local Tier=require(Shared.Tier)
local Flags=require(Shared.FeatureFlags)
local Den=require(Shared.PlayDen)

local Swap={}
Swap.PlaceId=107705084891479 -- Pocket Pals Beta
Swap.Attribute="CliffDen"
Swap.Pack="WorldBeta"

-- The tier's ceiling (code review): FeatureFlags.Tier and the beta place or Studio. Studio sessions of the live place
-- count, as for the tier: Studio evidence of the live island is taken without the WorldBeta pack mounted.
function Swap.allowed(env)
	env=env or {}
	return Tier.ceiling({flags=env.flags,place=env.place,studio=env.studio})
end

-- Which layer: "den" (FeatureFlags.CliffDen, the sculpt: DenLayout's room) or "pocket" (only the cave's bars split out;
-- no layout reads it since step A's pocket was retired, so that layer keeps the den and the terrace closed).
function Swap.mode(env)
	return if((env and env.flags)or Flags).CliffDen==false then "pocket" else "den"
end

-- world: the clone of ServerStorage.WorldAssets.WorldV7, not yet parented. Returns CliffDenData and the layer ("den" or
-- "pocket") when applied, else nil. Only "den" sets CliffDen (DenLayout's room). env (specs): {flags, place, studio,
-- storage, data, workspace}
function Swap.apply(world,env)
	env=env or {}
	if not Swap.allowed(env)then return nil end
	local storage=env.storage or ServerStorage
	local pack=storage:FindFirstChild(Swap.Pack)
	local source=pack and pack:FindFirstChild("WorldV7")
	if not source then return nil end
	local data=env.data
	if data==nil then
		local module=Shared:FindFirstChild("CliffDenData")
		local ok,found=pcall(function()return module and require(module)end)
		data=ok and found or nil
	end
	if type(data)~="table"or type(data.swap)~="table"or type(data.pocket)~="table"or pack:GetAttribute("Version")~=data.version then
		warn("[CliffDen] the WorldBeta pack and CliffDenData disagree; the live island stays")
		return nil
	end
	local mode=Swap.mode(env)
	local pairs_=if mode=="den"then data.swap else data.pocket
	-- All or nothing: every part to show must be in the pack before the clone is touched.
	for _,pair in ipairs(pairs_)do
		if pair.show and not source:FindFirstChild(pair.show)then
			warn("[CliffDen] WorldBeta is missing "..tostring(pair.show).."; the live island stays")
			return nil
		end
	end
	for _,pair in ipairs(pairs_)do
		if pair.hide then
			local old=world:FindFirstChild(pair.hide)
			if old then old:Destroy()end
		end
		if pair.show then source[pair.show]:Clone().Parent=world end
	end
	if mode=="den"then
		Swap.boxes(world,data.collision and data.collision.boxes)
		world:SetAttribute(Swap.Attribute,true)
		;(env.workspace or workspace):SetAttribute(Swap.Attribute,true)
	end
	return data,mode
end

-- The den's and the path's collision (Studio R1: no island mesh collides near them, their convex hulls filled the
-- room and bridged the path): invisible boxes in the world clone, named W7C_CD_Box_<kind>_<n> (W7C: the camera clamp's
-- "world", never a floor of the egg corner's), WorldMesh set with the rest by LoungeWorldV7Art (the pets' ground rays).
Swap.BoxPrefix="W7C_CD_Box_"
function Swap.boxes(world,boxes)
	if type(boxes)~="table"then return 0 end
	for i,b in ipairs(boxes)do
		local p=Instance.new("Part")
		p.Name=Swap.BoxPrefix..tostring(b.kind).."_"..i
		p.Anchored=true;p.CanCollide=true;p.CanQuery=true;p.CanTouch=false;p.CastShadow=false
		p.Transparency=1;p.Material=Enum.Material.SmoothPlastic
		p.Size=Vector3.new(b.s[1],b.s[2],b.s[3])
		local r=b.r
		p.CFrame=CFrame.new(b.c[1],b.c[2],b.c[3],r[1],r[2],r[3],r[4],r[5],r[6],r[7],r[8],r[9])
		p.Parent=world
	end
	return #boxes
end

-- The cave's bars (Studio R12: open, the den read as a cage): hidden while workspace Den_open is true (DenHost writes it
-- after opening, clears it first on close), shown otherwise. The world owns them, as it owns the closer. Returns the
-- connection, or nil when the world has no bars part (no pack: the live island's bars stay in its palette).
function Swap.bars(world,data,env)
	local name=type(data)=="table"and data.bars
	local part=name and world:FindFirstChild(name)
	if not part then return nil end
	local ws=(env and env.workspace)or workspace
	local function sync()part.Transparency=if ws:GetAttribute(Den.OpenAttribute)==true then 1 else 0 end
	sync()
	return ws:GetAttributeChangedSignal(Den.OpenAttribute):Connect(sync)
end

return Swap
