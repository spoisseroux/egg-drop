-- The world finish art (WORLD-FINISH-LOOK.md lanes C to E; WORLD-FINISH-ART-BUILD.md): the den's shell, floor, mouth
-- surround and apron, the cliff path and the terrace, from the beta-only pack ServerStorage.WorldFinish
-- (assets/world/WorldFinish.rbxmx, mounted by default.project.json alone) and WorldFinishData (generated, server only).
--
--   Mount.world(world, env)        LoungeWorldV7Art.meshes, after CliffDenSwap.apply when the sculpt is in ("den" mode),
--                                  before the attribute loop. Per slice, all or nothing: the pack's Version must be
--                                  WorldFinishData.version, WorldFinishData.cliffDen must be CliffDenData.version, the
--                                  slice must be packed with every template, and every part it hides, replaces or
--                                  overlays must be in the clone. Then it clones everything first (fixed parts,
--                                  instances, collision boxes, tufts) and only then hides: the pack parts it replaces
--                                  are destroyed (a re-cut copy with the same name takes their place, so CliffDenData.parts,
--                                  WorldMotion and the Aero named surfaces still apply), a colliding tile it overlays
--                                  stays, invisible and colliding (its hulls never move), under a visual copy; one the
--                                  re-cut left nothing of (`hideVisual`) just goes invisible and keeps colliding. Sets
--                                  World:WorldFinish_<slice> = true.
--   Mount.dressDen(model, room)    DenHost, right after GreyboxRows.build and before the model is parented: only when
--                                  the den slice is in the room's World. The lanterns become the iron lantern (the row
--                                  keeps its PointLight), the Dash gate's paw stones the flat stone, the apron slabs are
--                                  hidden (they keep colliding) under the drawn apron.
-- Every art part is anchored and visual only (no collision, query or touch). No pack, no art: the beta as before; live
-- never has the pack or the sculpt.
local ServerStorage=game:GetService("ServerStorage")
local Mount={}
Mount.Pack="WorldFinish"
Mount.Slices={"den","path","terrace"}
Mount.BoxPrefix="W7C_CD_Box_" -- CliffDenSwap's collision boxes (CameraClamp world, pets' rays)

local function cframe(t)return CFrame.new(t[1],t[2],t[3],t[4],t[5],t[6],t[7],t[8],t[9],t[10],t[11],t[12])end
local function vector(t)return Vector3.new(t[1],t[2],t[3])end
local Turn=CFrame.Angles(0,math.pi,0) -- the Roblox FBX import turns each mesh by pi about Y (AeroKit.Turn)

local function still(part)
	part.Anchored=true;part.CanCollide=false;part.CanQuery=false;part.CanTouch=false
	return part
end

function Mount.data(env)
	if env and env.data~=nil then return env.data end
	local ok,data=pcall(function()return require(script.Parent.WorldFinishData)end)
	return if ok then data else nil
end
local function cliffVersion(env)
	if env and env.cliffVersion~=nil then return env.cliffVersion end
	local ok,data=pcall(function()return require(game:GetService("ReplicatedStorage").Shared.CliffDenData)end)
	return ok and type(data)=="table"and data.version or nil
end

-- The pack and the slice's data when the slice can mount, else nil and why.
function Mount.ready(name,env)
	env=env or {}
	local data=Mount.data(env)
	local pack=(env.storage or ServerStorage):FindFirstChild(Mount.Pack)
	if not pack then return nil,nil,"no pack" end
	local version=pack:FindFirstChild("Version")
	if type(data)~="table"or not version or version.Value~=data.version then return nil,nil,"the pack and WorldFinishData disagree" end
	if data.cliffDen~=cliffVersion(env)then return nil,nil,"WorldFinishData was cut against another sculpt" end
	local slice=data.slices and data.slices[name]
	if type(slice)~="table"or slice.packed~=true then return nil,nil,"not packed" end
	for _,template in ipairs(slice.templates or {})do
		if not pack:FindFirstChild(template)then return nil,nil,"the pack is missing "..template end
	end
	return pack,slice
end

-- Tuft rows ({x, y, z, kind, yaw, scale}, WorldDressing bushes) from WorldAssets.Dressing, as Art.dressing places them.
local function tufts(rows,env)
	local out={}
	if #rows==0 then return out end
	local assets=(env.storage or ServerStorage):FindFirstChild("WorldAssets")
	local templates=assets and assets:FindFirstChild("Dressing")
	if not templates then return out end
	local ok,Dressing=pcall(function()return require(game:GetService("ReplicatedStorage").Shared.WorldDressing)end)
	if not ok then return out end
	for _,row in ipairs(rows)do
		local template=templates:FindFirstChild(Dressing.BushKinds[row[4]])
		if template then
			local cf,size=Dressing.bushPlacement(row)
			local bush=still(template:Clone())
			bush.CastShadow=false;bush.Size,bush.CFrame=size,cf
			bush:SetAttribute("WorldDressing","bush")
			bush:SetAttribute("WorldRestCFrame",cf)
			table.insert(out,bush)
		end
	end
	return out
end

-- Aero kit crowns (the terrace's one tree): clones of ServerStorage.AeroKit templates, when the kit is there.
local function crowns(rows,env)
	local out={}
	local kit=#rows>0 and(env.storage or ServerStorage):FindFirstChild("AeroKit")
	if not kit then return out end
	for _,row in ipairs(rows)do
		local template=kit:FindFirstChild(row.template)
		if template then
			local crown=still(template:Clone())
			crown.CastShadow=false;crown.Size,crown.CFrame=vector(row.size),cframe(row.cframe)
			table.insert(out,crown)
		end
	end
	return out
end

function Mount.world(world,env)
	env=env or {}
	local mounted={}
	for _,name in ipairs(Mount.Slices)do
		local pack,slice,why=Mount.ready(name,env)
		if not slice then
			if why~="no pack"and why~="not packed"then warn("[WorldFinish] "..name..": "..tostring(why))end
			continue
		end
		-- A slice whose re-cuts carry an earlier slice's cuts mounts only on top of it (the path's on the den's).
		local problem=if slice.requires and world:GetAttribute("WorldFinish_"..slice.requires)~=true then "needs "..slice.requires else nil
		local seen,destroy,overlay={},{},{}
		local function claim(n,list)
			if seen[n]then problem="named twice: "..n;return end
			seen[n]=true
			local target=world:FindFirstChild(n)
			if not target then problem="the world has no "..n;return end
			table.insert(list,target)
		end
		for _,n in ipairs(slice.hide or {})do claim(n,destroy)end
		-- colliding pack parts the re-cut left nothing of: invisible, still colliding (their hulls never move)
		for _,n in ipairs(slice.hideVisual or {})do claim(n,overlay)end
		local replaced={}
		for _,row in ipairs(slice.fixed)do
			if row.replaces then claim(row.replaces,destroy);replaced[row.name]=world:FindFirstChild(row.replaces)end
			if row.overlays then claim(row.overlays,overlay)end
		end
		-- boxes of these kinds that CliffDenSwap built go (the slice brings its own: the lip stones' replace the lip's)
		for _,kind in ipairs(slice.hideBoxes or {})do
			local prefix=Mount.BoxPrefix..kind.."_"
			for _,child in ipairs(world:GetChildren())do
				if string.sub(child.Name,1,#prefix)==prefix then table.insert(destroy,child)end
			end
		end
		if problem then warn("[WorldFinish] "..name..": "..problem.."; left as it is");continue end
		-- Clone everything first.
		local made={}
		for _,row in ipairs(slice.fixed)do
			local part=still(pack[row.name]:Clone())
			part.Size,part.CFrame=vector(row.size),cframe(row.cframe)
			-- a re-cut copy keeps whatever the pack part carried (code review 4); Art.meshes then sets its own on top
			local old=replaced[row.name]
			if old then for key,value in pairs(old:GetAttributes())do part:SetAttribute(key,value)end end
			table.insert(made,part)
		end
		for _,row in ipairs(slice.instances or {})do
			local part=still(pack[row.template]:Clone())
			part.Size,part.CFrame=vector(row.size),cframe(row.cframe)
			table.insert(made,part)
		end
		for i,b in ipairs(slice.boxes or {})do
			local p=Instance.new("Part")
			p.Name=Mount.BoxPrefix..tostring(b.kind).."_F"..i
			p.Anchored=true;p.CanCollide=true;p.CanQuery=true;p.CanTouch=false;p.CastShadow=false
			p.Transparency=1;p.Material=Enum.Material.SmoothPlastic
			local r=b.r
			p.Size=vector(b.s)
			p.CFrame=if r then CFrame.new(b.c[1],b.c[2],b.c[3],r[1],r[2],r[3],r[4],r[5],r[6],r[7],r[8],r[9])else CFrame.new(b.c[1],b.c[2],b.c[3])
			table.insert(made,p)
		end
		for _,bush in ipairs(tufts(slice.tufts or {},env))do table.insert(made,bush)end
		-- the kit crowns are part of the slice (code review E2): all of them, or the slice waits
		local got=crowns(slice.kitCrowns or {},env)
		if #got<#(slice.kitCrowns or {})then warn("[WorldFinish] "..name..": the Aero kit crowns are missing; left as it is");continue end
		for _,crown in ipairs(got)do table.insert(made,crown)end
		-- ropes: each span sags in four segments between its stakes' tops (the Dash ring's rope look)
		local R=slice.rope
		for i,span in ipairs(slice.ropes or {})do
			local a,b=vector(span[1]),vector(span[2])
			local function at(t)return a:Lerp(b,t)-Vector3.new(0,R.sag*4*t*(1-t),0)end
			for k=1,4 do
				local p,q=at((k-1)/4),at(k/4)
				local seg=still(Instance.new("Part"))
				seg.Name="W7_F_Rope"..i.."_"..k;seg.Shape=Enum.PartType.Cylinder
				seg.Material=Enum.Material.Fabric;seg.Color=Color3.fromHex(R.color);seg.CastShadow=false
				seg.Size=Vector3.new((q-p).Magnitude+.04,R.width,R.width)
				seg.CFrame=CFrame.lookAt((p+q)/2,q)*CFrame.Angles(0,math.pi/2,0)
				table.insert(made,seg)
			end
		end
		-- Then hide and show.
		for _,old in ipairs(destroy)do old:Destroy()end
		for _,tile in ipairs(overlay)do tile.Transparency=1 end -- still colliding: its hulls never move
		for _,part in ipairs(made)do part.Parent=world end
		world:SetAttribute("WorldFinish_"..name,true)
		world:SetAttribute("WorldFinishTriangles",(world:GetAttribute("WorldFinishTriangles")or 0)+(slice.triangles or 0))
		table.insert(mounted,name)
	end
	return mounted
end

-- The den greybox's dress (see the header). Returns the number of rows it changed, or 0.
function Mount.dressDen(model,room,env)
	env=env or {}
	local world=room and room:FindFirstChild("World")
	if not(model and world and world:GetAttribute("WorldFinish_den")==true)then return 0 end
	local pack,slice=Mount.ready("den",env)
	local dress=slice and slice.dress
	if not dress then return 0 end
	local L=dress.lantern
	local made,hide,recolour={},{},{}
	local function add(template,cf,size)
		local part=still(pack[template]:Clone())
		part.Size,part.CFrame=size,cf
		part:SetAttribute("WorldMesh",true) -- as GreyboxRows marks every den part (code review 5: RoomView's blockers)
		table.insert(made,part)
		return part
	end
	for _,row in ipairs(model:GetChildren())do
		local lamp=string.match(row.Name,"^W7D_Lantern(%d+)$")
		if lamp then
			for template,t in pairs(L)do add(template,row.CFrame*CFrame.new(vector(t.offset))*Turn,vector(t.size))end
			table.insert(hide,row)
			for _,suffix in ipairs({"Cap","Base"})do
				local extra=model:FindFirstChild(row.Name..suffix)
				if extra then table.insert(hide,extra)end
			end
			local light=row:FindFirstChildOfClass("PointLight")
			if light then light.Shadows=false end
			-- A wall lamp hangs from the shelf over it on a cord (its bracket goes).
			local bracket=model:FindFirstChild("W7D_LanternBracket"..lamp)
			if bracket and dress.ledgeY then
				table.insert(hide,bracket)
				local at=row.CFrame.Position
				local top=at.Y+(L.W7_F_Lantern__cage.offset[2]+L.W7_F_Lantern__cage.size[2]/2)
				local length=dress.ledgeY-top
				if length>.05 then
					local cord=still(Instance.new("Part"))
					cord.Name="W7D_LanternCordF"..lamp;cord.Material=Enum.Material.Fabric;cord.Color=Color3.fromHex("#3A3028")
					cord.Size=Vector3.new(.06,length,.06);cord.CFrame=CFrame.new(at.X,top+length/2,at.Z)
					cord.CastShadow=false;cord:SetAttribute("WorldMesh",true)
					table.insert(made,cord)
				end
			end
		elseif string.match(row.Name,"Paw$")then
			local P=dress.paw
			local scale=vector(P.size)
			local size=vector(P.unit)*scale
			local at=CFrame.new(row.CFrame.Position-Vector3.new(0,row.Size.Y/2+P.sink,0))*row.CFrame.Rotation
			local part=add("W7_F_Stone__flat",at*CFrame.new(vector(P.offset)*scale)*Turn,size)
			part.Color=Color3.fromHex(P.color)
			table.insert(hide,row)
		elseif string.match(row.Name,"^W7D_Apron")or row.Name=="W7D_FrameThreshold"then
			-- the drawn apron (W7_F_DenApron__dirt_path) and the floor's own threshold show instead (Fable world R1 5);
			-- the slabs keep colliding
			table.insert(hide,row)
		elseif string.match(row.Name,"^W7D_bay%d+Deck$")then
			-- Fable world R1 6: the propped Deck's body (its back fills CAM-DEN-BACK) takes the stump's dark wood
			table.insert(recolour,row)
		end
	end
	for _,row in ipairs(hide)do row.Transparency=1 end
	for _,row in ipairs(recolour)do row.Color=Color3.fromHex("#5C4330");row.Material=Enum.Material.Wood end
	for _,part in ipairs(made)do part.Parent=model end
	return #hide+#recolour
end

-- The terrace greybox's dress (TierHost, right after GreyboxRows.build, before parenting): only with the terrace slice
-- in the room's World. Its visible faces, skirts, balustrades and rims go invisible and keep colliding (the invisible
-- walls do the safety; the drawn cap, face and lip stones show instead); the clumps, pads and pole go (the outcrops and
-- the tree replace them). The floor slab stays: the cap lies 0.05 over it. Returns the number of rows it changed.
function Mount.dressTier(model,room,env)
	env=env or {}
	local world=room and room:FindFirstChild("World")
	if not(model and world and world:GetAttribute("WorldFinish_terrace")==true)then return 0 end
	local _,slice=Mount.ready("terrace",env)
	local dress=slice and slice.dressTier
	if not dress then return 0 end
	local hide,remove={},{}
	for _,n in ipairs(dress.hide or {})do
		local row=model:FindFirstChild(dress.prefix..n)
		if row then table.insert(hide,row)end
	end
	for _,n in ipairs(dress.remove or {})do
		local row=model:FindFirstChild(dress.prefix..n)
		if row then table.insert(remove,row)end
	end
	for _,row in ipairs(hide)do row.Transparency=1 end
	for _,row in ipairs(remove)do row:Destroy()end
	return #hide+#remove
end

return Mount
