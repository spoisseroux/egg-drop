-- The Hollow's edge (WORLD-ALIVE-LOOK section 2, "What you see instead of a kerb"): ParkMount builds this in place of
-- the kerb and the star-orb posts when the site is natural. Data from ParkLayout (Park.Dressing); parts and decal plates
-- only, the equipment meshes are unchanged. Every part is Anchored with no collision, query or touch, CastShadow off
-- (Fable's common rule), and tagged ParkPart so the rest-path and raycast filters skip it like the rest of the park.
-- Players collide with the log through its ParkPoseData collider (one box), never with these visuals.
--
-- Stones use the stone builder of section 4: a Ball cut by 5 to 7 leaning Blocks with GeometryService:IntersectAsync
-- (seeded per stone, Slate, SmoothingAngle 0), scaled to the stone's size; if the call throws, two stacked Cylinders.
local GeometryService=game:GetService("GeometryService")
local Shared=game:GetService("ReplicatedStorage").Shared
local Dressing=require(Shared.WorldDressing)
local Hollow={}

local WOOD=Color3.fromHex("#6B4E37")
local function hex(value)return Color3.fromHex(value)end
local function visual(part,name,parent)
	part.Name=name
	part.Anchored=true;part.CanCollide=false;part.CanQuery=false;part.CanTouch=false;part.CastShadow=false
	part.TopSurface,part.BottomSurface=Enum.SurfaceType.Smooth,Enum.SurfaceType.Smooth
	part:SetAttribute("ParkPart",true)
	part.Parent=parent
	return part
end
local function cylinder(name,size,cframe,colour,material,parent)
	local part=Instance.new("Part");part.Shape=Enum.PartType.Cylinder
	part.Size=size;part.CFrame=cframe;part.Color=colour;part.Material=material
	return visual(part,name,parent)
end
-- A flat, upward decal plate (Transparency 1 part, Decal on Top), as WorldDressingClient draws the ground plates.
local function plate(name,size,cframe,texture,colour,transparency,parent)
	if type(texture)~="string"or texture==""then return nil end
	local part=Instance.new("Part");part.Size=size;part.CFrame=cframe;part.Transparency=1;part.Material=Enum.Material.SmoothPlastic
	local decal=Instance.new("Decal");decal.Name="Ground";decal.Face=Enum.NormalId.Top;decal.Texture=texture
	decal.Color3=colour or Color3.new(1,1,1);decal.Transparency=transparency or 0;decal.Parent=part
	return visual(part,name,parent)
end

-- Texture id for a LifeArtR4 key (nil while pending: that plate is skipped).
function Hollow.art(key)
	local ok,id=pcall(function()return require(Shared.LifeArtR4).id(key)end)
	return if ok then id else nil
end

-- The stone builder: a unit dome (footprint 1 across, .5 high) cut into facets, then sized to the stone.
-- Returns the PartOperation, or nil when GeometryService refuses.
function Hollow.carve(row)
	local rng=Random.new(row.seed)
	local ball=Instance.new("Part");ball.Shape=Enum.PartType.Ball;ball.Size=Vector3.one*1.5
	ball.CFrame=CFrame.new(0,.5-.75,0) -- only a .5 dome shows above y = 0
	local cutters={}
	local floor=Instance.new("Part");floor.Size=Vector3.new(4,4,4);floor.CFrame=CFrame.new(0,2,0)
	table.insert(cutters,floor)
	local count=rng:NextInteger(5,7)
	local start=rng:NextNumber(0,math.pi*2)
	for k=1,count do
		local theta=start+(k-1)*math.pi*2/count+rng:NextNumber(-.25,.25)
		local near=.5*rng:NextNumber(.85,1)
		local lean=math.rad(rng:NextNumber(8,20))
		local block=Instance.new("Part");block.Size=Vector3.new(4,4,4)
		-- Local +X points out at theta, tipped up by `lean`; the block's near face is the plane x = near.
		block.CFrame=CFrame.Angles(0,theta,0)*CFrame.Angles(0,0,lean)*CFrame.new(near-2,0,0)
		table.insert(cutters,block)
	end
	local ok,result=pcall(function()
		return GeometryService:IntersectAsync(ball,cutters,{SplitApart=false,CollisionFidelity=Enum.CollisionFidelity.Box,
			RenderFidelity=Enum.RenderFidelity.Automatic})
	end)
	ball:Destroy();for _,part in ipairs(cutters)do part:Destroy()end
	local stone=ok and type(result)=="table"and result[1]
	if not stone then return nil end
	for index=2,#result do result[index]:Destroy()end
	return stone
end

-- One stone, sitting on its lawn point sunk .1, turned by yaw. `carve` false (specs) skips GeometryService.
function Hollow.stone(row,parent,carve)
	local colour=hex(row.colour)
	local base=CFrame.new(row.x,row.y-.1,row.z)*CFrame.Angles(0,row.yaw,0)
	local stone=if carve~=false then Hollow.carve(row)else nil
	if stone then
		stone.UsePartColor=true;stone.Color=colour;stone.Material=Enum.Material.Slate
		pcall(function()stone.SmoothingAngle=0 end)
		stone.Size=row.size
		stone.CFrame=base*CFrame.new(0,row.size.Y*.5,0)
		return visual(stone,row.name,parent)
	end
	-- Fallback: two stacked cylinders, the footprint's width then 80% of it.
	local model=Instance.new("Model");model.Name=row.name
	local low,high=row.size.Y*.6,row.size.Y*.4
	local upright=CFrame.Angles(0,0,math.pi*.5)
	cylinder("Base",Vector3.new(low,row.size.X,row.size.X),base*CFrame.new(0,low*.5,0)*upright,colour,Enum.Material.Slate,model)
	cylinder("Top",Vector3.new(high,row.size.X*.8,row.size.X*.8),base*CFrame.new(0,low+high*.5,0)*upright,colour,Enum.Material.Slate,model)
	model:SetAttribute("ParkFallback",true)
	model.Parent=parent
	return model
end

-- Everything but the stones (cheap, synchronous): ground plates, the flower drift, the log, the stumps, the column.
function Hollow.buildStatic(folder,Park)
	local D=Park.Dressing
	for _,row in ipairs(D.plates)do
		plate(row.name,Vector3.new(row.size.X,Dressing.Thickness,row.size.Y),
			CFrame.new(row.x,row.y+row.lift,row.z)*CFrame.Angles(0,row.yaw,0),Hollow.art(row.art),hex(row.colour),row.transparency,folder)
	end
	-- The flower drift uses the beta's redrawn flowers (the Hollow is beta-only), else today's.
	for _,row in ipairs(D.flowers)do
		local kind=Dressing.Kinds[row.kind]
		local texture=(Dressing.TexturesR2 and Dressing.TexturesR2[kind])or Dressing.Textures[kind]
		plate("HollowFlowers_"..kind,Vector3.new(row.size,Dressing.Thickness,row.size),
			CFrame.new(row.x,row.y+Dressing.Lift+Dressing.Thickness*.5,row.z)*CFrame.Angles(0,row.yaw,0),texture,nil,Dressing.TransparencyR2 or 0,folder)
	end
	-- The fallen log along the rim, sunk .25, its length along `heading`; the lighter end cap at the +X end.
	local log=D.log
	local frame=CFrame.new(log.x,log.y+log.diameter*.5-log.sink,log.z)*CFrame.Angles(0,log.heading-math.pi*.5,0)
	cylinder("HollowLog",Vector3.new(log.length,log.diameter,log.diameter),frame,hex(log.colour),Enum.Material.Wood,folder)
	cylinder("HollowLogCap",Vector3.new(.06,log.diameter*.9,log.diameter*.9),frame*CFrame.new(log.length*.5+.02,0,0),hex(log.cap),Enum.Material.Wood,folder)
	-- The stump circle: upright cylinders with a pale cut top.
	local upright=CFrame.Angles(0,0,math.pi*.5)
	for index,stump in ipairs(D.stumps)do
		local at=CFrame.new(stump.x,stump.y,stump.z)*CFrame.Angles(0,index*1.9,0)
		cylinder("HollowStump",Vector3.new(stump.height,stump.diameter,stump.diameter),at*CFrame.new(0,stump.height*.5-.05,0)*upright,WOOD,Enum.Material.Wood,folder)
		cylinder("HollowStumpTop",Vector3.new(.04,stump.diameter*.92,stump.diameter*.92),at*CFrame.new(0,stump.height-.05+.02,0)*upright,
			hex(log.cap),Enum.Material.Wood,folder)
	end
	-- The fallen column, leaned 20 degrees, 60% under the sand, one gold band.
	local column=D.column
	local axis=CFrame.new(column.x,column.y,column.z)*CFrame.Angles(0,column.heading-math.pi*.5,0)*CFrame.Angles(0,0,column.lean)
	cylinder("HollowColumn",Vector3.new(column.length,column.diameter,column.diameter),axis,hex(column.colour),Enum.Material.Marble,folder)
	cylinder("HollowColumnBand",Vector3.new(column.bandWidth,column.diameter+.06,column.diameter+.06),axis*CFrame.new(column.length*.22,0,0),
		hex(column.band),Enum.Material.Metal,folder)
end

-- The stones (GeometryService yields: ParkMount calls this inside its mesh task).
function Hollow.buildStones(folder,Park,carve)
	for _,row in ipairs(Park.Dressing.stones)do
		if not folder.Parent then return end
		Hollow.stone(row,folder,carve)
	end
end

return Hollow
