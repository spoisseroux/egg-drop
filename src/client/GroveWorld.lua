-- The Hidden Grove round the island (artifacts/qa-2026-11-28-grove: GROVE-MOCKUP, GROVE-BUILD-PLAN, ARCH-REVIEW-GROVE).
-- Client only and looks only, like the rest of the Aero layer. AeroWorld runs it inside its own lifecycle (ARCH-REVIEW-
-- GROVE 1: the same room binding and turn tokens): built in World:bind after the kit and additions while Aero is on and
-- the Alive `grove` switch is on (Shared.Grove.on), dropped in World:disable, a room change or the switch going off.
--   * the ring: Shared.WorldGrove's meshes cloned from ReplicatedStorage.GroveKit's templates (Shared.Grove.Templates;
--     the server copies them there only where the Aero and grove ceilings pass) into the workspace folder EggDropGrove,
--     never inside EggDropLounge (World:paint recolours Beams there, WindClient scans its folders). Anchored, nothing
--     collides, is queried or touched, nothing casts a shadow. A mesh with `center` stands once at its bounds centre; an
--     instanced one (giants, crowns) stands at each `instances` row (pivot, yaw, scale). With turnApplied, every part
--     takes the import's pi turn about Y after its position (AeroKit.Turn). A mesh whose maxLevel is under the budget
--     level is not built, and is taken down when the level rises (it never comes back down).
--   * the gorge falls: one flat Beam a data fall, the server sheets' look (WorldV7Data.fallTexture); still under Reduced
--     Motion.
--   * the light: GroveLight (rays, motes, bubbles, lanterns, the sun gate's SunRays multiplier).
--   * the backdrop: what the grove replaces (Shared.Grove.hides: the data's hides plus Sky Falls' server sheet and cloud
--     foam) is hidden in GroveWorld's own records on AeroWorld's writer, never in the kit's (dropKit restores all of its
--     own): parts and their Texture and Decal children by LocalTransparencyModifier 1 (Transparency has three writers),
--     WaterFlow beams and emitters by Enabled false, and the part attribute GroveHidden so WorldMotion stops stepping it.
--     Re-applied in AeroWorld's late pass (streaming re-creates parts) and put back exactly when the grove goes.
-- The data contract and its rules are Shared.Grove's; this refuses to build (and the backdrop stays) on any problem.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rules=require(Shared:WaitForChild("Grove"))
local Light=require(script.Parent:WaitForChild("GroveLight"))
local GroveWorld={}
GroveWorld.Folder=Rules.Folder
GroveWorld.Templates=Rules.Templates
GroveWorld.Turn=CFrame.Angles(0,math.pi,0)
GroveWorld.Hidden="GroveHidden" -- the part attribute WorldMotion skips
GroveWorld.Falls=table.freeze({speed=1.3,length=8})

local function vector(list)return Vector3.new(list[1],list[2],list[3])end
local function turnOf(data)return if data.turnApplied then GroveWorld.Turn else CFrame.identity end

-- Pure: a placed mesh's CFrame and Size.
function GroveWorld.placedFrame(mesh,turn)
	return CFrame.new(vector(mesh.center))*(turn or CFrame.identity),vector(mesh.size)
end
-- Pure: an instanced mesh on its row: pivotToCentre is the bounds centre from the pivot at scale 1, before the yaw.
function GroveWorld.instanceFrame(row,mesh,turn)
	local yaw=CFrame.Angles(0,row.yaw,0)
	local centre=vector(row.pivot)+yaw:VectorToWorldSpace(vector(mesh.pivotToCentre)*row.scale)
	return CFrame.new(centre)*yaw*(turn or CFrame.identity),vector(mesh.size)*row.scale
end
-- Pure: every part the ring stands at a level: {{name, cframe, size, mesh, instance}} in a fixed order (placed meshes
-- by name, then the instances in data order).
function GroveWorld.layout(data,level)
	local turn=turnOf(data)
	local out={}
	local names={}
	for name,mesh in pairs(data.meshes)do if mesh.center then table.insert(names,name)end end
	table.sort(names)
	for _,name in ipairs(names)do
		local mesh=data.meshes[name]
		if mesh.maxLevel>=level then
			local cframe,size=GroveWorld.placedFrame(mesh,turn)
			table.insert(out,{name=name,cframe=cframe,size=size,mesh=mesh})
		end
	end
	for index,row in ipairs(data.instances)do
		local mesh=data.meshes[row.mesh]
		if mesh.maxLevel>=level then
			local cframe,size=GroveWorld.instanceFrame(row,mesh,turn)
			table.insert(out,{name=row.mesh,cframe=cframe,size=size,mesh=mesh,instance=index})
		end
	end
	return out
end
-- Pure: the lantern kind of a lantern mesh: its own `kind` if it has one, else the nearest data lantern's, else warm.
function GroveWorld.lanternKind(data,name,cframe)
	local mesh=data.meshes[name]
	if mesh.kind=="warm"or mesh.kind=="aqua"then return mesh.kind end
	if string.find(string.lower(name),"aqua",1,true)then return "aqua"end
	if string.find(string.lower(name),"warm",1,true)then return "warm"end
	local best,kind=math.huge,"warm"
	for _,lantern in ipairs(data.lanterns)do
		local d=(vector(lantern.pos)-cframe.Position).Magnitude
		if d<best then best,kind=d,lantern.kind end
	end
	return kind
end

local function inert(p)
	p.Anchored=true
	p.CanCollide=false
	p.CanQuery=false
	p.CanTouch=false
	p.CastShadow=false
end

-- options: data (WorldGrove), templates (GroveKit), parent (workspace), level, reduced, phone, fallTexture, and
-- GroveLight's: hour, daylight, camera, setSunRays, connect, now, warn. Returns {folder, data, parts, light, moatY,
-- setLevel(level), still(reduced), destroy()} or throws (bad data, a missing template): AeroWorld catches it and keeps
-- the floating island.
function GroveWorld.build(options)
	local data,templates=options.data,options.templates
	local ok,problem=Rules.validate(data)
	assert(ok,"grove data: "..tostring(problem))
	assert(templates~=nil,"no grove templates")
	local level=options.level or 0
	local folder=Instance.new("Folder")
	folder.Name=GroveWorld.Folder
	local parts,lanterns={},{}
	local built,result=pcall(function()
		for _,row in ipairs(GroveWorld.layout(data,level))do
			local template=templates:FindFirstChild(row.name)
			assert(template and template:IsA("MeshPart"),"grove template missing: "..tostring(row.name))
			local p=template:Clone()
			inert(p)
			p.Size,p.CFrame=row.size,row.cframe
			p:SetAttribute("WorldMesh",true)
			p:SetAttribute("GroveMaxLevel",row.mesh.maxLevel)
			if row.instance then p:SetAttribute("GroveInstance",row.instance)end
			p.Parent=folder
			table.insert(parts,p)
			if row.mesh.role=="lantern"then
				table.insert(lanterns,{part=p,kind=GroveWorld.lanternKind(data,row.name,row.cframe),material=p.Material,color=p.Color})
			end
		end
		-- The gorge falls: one holder at the origin, a flat beam a fall (the attachments' Axis the normal, world up second).
		local falls={}
		if #data.falls>0 then
			local anchor=Instance.new("Part")
			anchor.Name="GroveFalls"
			inert(anchor)
			anchor.Transparency=1
			anchor.Size=Vector3.new(.2,.2,.2)
			anchor.CFrame=CFrame.new()
			anchor.Parent=folder
			for _,fall in ipairs(data.falls)do
				local normal=vector(fall.normal).Unit
				local function attach(at)
					local a=Instance.new("Attachment")
					a.CFrame=CFrame.fromMatrix(vector(at),normal,Vector3.yAxis)
					a.Parent=anchor
					return a
				end
				local beam=Instance.new("Beam")
				beam.Name=fall.name
				beam.Attachment0,beam.Attachment1=attach(fall.top),attach(fall.bottom)
				beam.Width0,beam.Width1=fall.width0,fall.width1
				beam.FaceCamera=false
				if options.fallTexture then beam.Texture=options.fallTexture end
				beam.TextureMode=Enum.TextureMode.Wrap
				beam.TextureLength=GroveWorld.Falls.length
				beam.TextureSpeed=if options.reduced then 0 else GroveWorld.Falls.speed
				beam.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.4),NumberSequenceKeypoint.new(.9,.4),NumberSequenceKeypoint.new(1,.85)})
				beam.LightInfluence=1
				beam.Segments=1
				beam.Parent=anchor
				table.insert(falls,beam)
			end
		end
		local light=Light.build({parent=folder,data=data,lanterns=lanterns,level=level,reduced=options.reduced,phone=options.phone,
			hour=options.hour,daylight=options.daylight,camera=options.camera,setSunRays=options.setSunRays,connect=options.connect,
			now=options.now,warn=options.warn})
		return{falls=falls,light=light}
	end)
	if not built then
		pcall(function()folder:Destroy()end)
		error(result,0)
	end
	folder.Parent=options.parent
	local handle={folder=folder,data=data,parts=parts,light=result.light,falls=result.falls,lanterns=lanterns,
		moatY=data.moat.surfaceY,level=level,reduced=options.reduced==true}
	-- The level only rises: what it now drops is taken down (and its lantern record with it).
	function handle.setLevel(next)
		if type(next)~="number"or next<=handle.level then return end
		handle.level=next
		for i=#parts,1,-1 do
			local p=parts[i]
			if(p:GetAttribute("GroveMaxLevel")or 2)<next then
				table.remove(parts,i)
				for k=#lanterns,1,-1 do if lanterns[k].part==p then table.remove(lanterns,k)end end
				pcall(function()p:Destroy()end)
			end
		end
		handle.light.update({level=next})
	end
	function handle.still(reduced)
		reduced=reduced==true
		if reduced==handle.reduced then return end
		handle.reduced=reduced
		for _,beam in ipairs(handle.falls)do beam.TextureSpeed=if reduced then 0 else GroveWorld.Falls.speed end
		handle.light.update({reduced=reduced})
	end
	function handle.destroy()
		pcall(handle.light.destroy)
		pcall(function()folder:Destroy()end)
	end
	return handle
end

-- The backdrop the grove replaces, hidden through AeroWorld's writer: set(records, item, key, value) (World:set, which
-- keeps the first value for restore). folders: AeroWorld's watched {World, WaterFlow}. Safe to repeat (unchanged writes
-- are skipped); returns how many items it holds hidden.
function GroveWorld.hideBackdrop(set,records,folders,names)
	local count=0
	local meshes=folders.World
	local flow=folders.WaterFlow
	local wanted={}
	for _,name in ipairs(names)do wanted[name]=true end
	for _,name in ipairs(names)do
		local part=meshes and meshes:FindFirstChild(name)
		if part and part:IsA("BasePart")then
			set(records,part,"LocalTransparencyModifier",1)
			set(records,part,"@"..GroveWorld.Hidden,true)
			count+=1
			for _,child in ipairs(part:GetChildren())do
				if child:IsA("Decal")or child:IsA("Texture")then set(records,child,"LocalTransparencyModifier",1);count+=1 end
			end
		end
	end
	for _,item in ipairs(flow and flow:GetDescendants()or {})do
		if wanted[item.Name]and(item:IsA("Beam")or item:IsA("ParticleEmitter"))then
			set(records,item,"Enabled",false)
			-- WorldMotion switches the WaterFlow emitters back on when Reduced Motion goes off: it skips these.
			set(records,item,"@"..GroveWorld.Hidden,true)
			count+=1
		end
	end
	return count
end
return GroveWorld
