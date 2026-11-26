-- Garden Dash gate (V3-DASH-BUILD-PLAN-2026-11-22, slice S6): the static props, placed from DashCourse as ParkMount
-- places the park. Placeholder parts until the art lands (Fable): the striped start arch (its balloon is the
-- client's, DashProps), the finish arch, eight lane pads, the waiting pad with its sign beside the line, and the
-- three stepping stones. With DashProps.MaxParts in mind: both together stay under 60 parts. Everything is anchored and non-colliding, non-queryable and non-touching,
-- beside the lounge rather than inside it, so players, pets and every garden raycast pass straight through.
-- Hoops and clovers are the client's (layouts differ). Built while Dash is on; removed when it goes off.
-- Beta 17 (WORLD-ALIVE-LOOK sections 3 and 4), while the Alive `scene` switch is on (Mount.fete): the fete set
-- (DashFete) in place of the arches, slabs and pad, and the river stones (RiverStones, carved by StoneBuilder) with
-- their walkable colliders in place of the three tiles. Off (and on live): exactly the build before it.
local Shared=game:GetService("ReplicatedStorage").Shared
local Course=require(Shared.DashCourse)
local Grid=require(Shared.DashGrid)
local Mount={}
Mount.ModelName="GardenDash"
Mount.Frame=Color3.fromHex("#C9C2D6")
Mount.Banner=Color3.fromHex("#FFE68A")
Mount.Stone=Color3.fromHex("#B9B4C4")
Mount.Stripe=Color3.fromHex("#FF6B6B")
Mount.Cream=Color3.fromHex("#FFF4DC")
Mount.Wait=Color3.fromHex("#8FD3FF")
Mount.Stripes=3 -- a post
Mount.PostHeight=10.4 -- the banner is above the race camera (9 up)
-- Beta 12 U5: the posts outside eight racers 1.5 studs apart (DashGrid), the arch about 13 studs wide.
Mount.PostOut=Grid.PostOut/100
Mount.SlabWidth=Grid.StartStep/100

local function part(parent,name,size,cframe,color)
	local item=Instance.new("Part")
	item.Name=name;item.Size=size;item.CFrame=cframe;item.Color=color
	item.Anchored=true;item.CanCollide=false;item.CanQuery=false;item.CanTouch=false;item.CastShadow=false
	item.Material=Enum.Material.SmoothPlastic
	item:SetAttribute("DashPart",true)
	item.Parent=parent
	return item
end
local function frameAt(cs,lane)
	local x,y,z,yaw=Course.at(cs,false,lane)
	return CFrame.new(x,y,z)*CFrame.Angles(0,yaw,0)
end
local function arch(parent,name,at)
	part(parent,name.."Left",Vector3.new(.4,5,.4),at*CFrame.new(-2.8,2.5,0),Mount.Frame)
	part(parent,name.."Right",Vector3.new(.4,5,.4),at*CFrame.new(2.8,2.5,0),Mount.Frame)
	part(parent,name.."Banner",Vector3.new(6,.9,.3),at*CFrame.new(0,4.8,0),Mount.Banner)
end
local function startArch(parent,at)
	local each=Mount.PostHeight/Mount.Stripes
	for side=-1,1,2 do
		for k=1,Mount.Stripes do
			part(parent,"StartPost",Vector3.new(.7,each,.7),at*CFrame.new(side*Mount.PostOut,(k-.5)*each,0),if k%2==1 then Mount.Stripe else Mount.Cream)
		end
	end
	local wide=(Mount.PostOut*2+.7)/3
	for k=-1,1 do
		part(parent,"StartBanner",Vector3.new(wide,1.4,.5),at*CFrame.new(k*wide,Mount.PostHeight+.7,0),if k==0 then Mount.Cream else Mount.Stripe)
	end
end
-- The gate's spot on the ground: the waiting pad, what the server measures joins from.
function Mount.gate()
	local pad=Course.Pad
	return Vector3.new(pad.x/100,pad.y/100,pad.z/100)
end
-- The Alive `scene` switch (beta and Studio only): the fete set and the river stones. A failing read is off.
function Mount.fete()
	local ok,on=pcall(function()return require(Shared.Alive).on("scene")end)
	return ok and on==true
end
-- options (specs): {fete = bool (nil: Mount.fete()), carve, spawn (StoneBuilder's options)}.
function Mount.build(room,options)
	options=options or {}
	local fete=options.fete
	if fete==nil then fete=Mount.fete()end
	if fete then return Mount.buildFete(room,options)end
	Mount.remove(room)
	local model=Instance.new("Model");model.Name=Mount.ModelName
	local start,finish=frameAt(0),frameAt(Course.Length)
	model:SetAttribute("DashVersion",Course.Version)
	model:SetAttribute("Start",start);model:SetAttribute("Finish",finish)
	startArch(model,start);arch(model,"Finish",finish)
	-- Eight slabs side by side, one under each racer of a full heat (DashGrid's slots at the line).
	for lane=1,Course.LaneCount do
		local o=Grid.offset(0,false,lane,Course.LaneCount)/100
		part(model,"Pad_"..lane,Vector3.new(Mount.SlabWidth-.08,.08,.9),start*CFrame.new(-o,.04,-.8),if lane%2==0 then Mount.Banner else Mount.Cream)
	end
	-- The waiting pad, off the line, and its sign on the far edge from the course.
	local gate=CFrame.new(Mount.gate())
	local r=Course.Pad.r/100
	part(model,"WaitPad",Vector3.new(.16,r*2,r*2),gate*CFrame.new(0,.08,0)*CFrame.Angles(0,0,math.pi/2),Mount.Wait).Shape=Enum.PartType.Cylinder
	-- Beta 34 note: the board hangs between two posts at its ends, so no post crosses the words.
	part(model,"SignPost",Vector3.new(.25,3.35,.25),gate*CFrame.new(-1.225,1.675,-r-.4),Mount.Frame)
	part(model,"SignPost2",Vector3.new(.25,3.35,.25),gate*CFrame.new(1.225,1.675,-r-.4),Mount.Frame)
	part(model,"Sign",Vector3.new(2.2,1.2,.2),gate*CFrame.new(0,2.6,-r-.4),Mount.Banner)
	for index,stone in ipairs(Course.Stones)do
		part(model,"Stone_"..index,Vector3.new(2.2,.3,2.2),CFrame.new(stone.x/100,stone.y/100-.15,stone.z/100),Mount.Stone)
	end
	model.Parent=room
	return model
end
-- The fete set ------------------------------------------------------------------------------------------------------
local Materials={Wood=Enum.Material.Wood,Marble=Enum.Material.Marble,SmoothPlastic=Enum.Material.SmoothPlastic,
	Fabric=Enum.Material.Fabric,Slate=Enum.Material.Slate,Ground=Enum.Material.Ground}
local Shapes={Block=Enum.PartType.Block,Cylinder=Enum.PartType.Cylinder,Ball=Enum.PartType.Ball}
local function title()
	local ok,text=pcall(function()return require(Shared.UICopy).dash.title end)
	return if ok and type(text)=="string"then text else "Garden Dash"
end
-- The existing Dash title (no new words), cream on timber, on the given faces.
local function words(item,faces)
	for _,face in ipairs(faces)do
		local gui=Instance.new("SurfaceGui")
		gui.Name="Words"..face;gui.Face=Enum.NormalId[face];gui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud=60;gui.LightInfluence=1
		local label=Instance.new("TextLabel")
		label.Name="Title";label.BackgroundTransparency=1;label.Size=UDim2.fromScale(.92,.8);label.Position=UDim2.fromScale(.04,.1)
		label.Text=title();label.TextScaled=true;label.Font=Enum.Font.FredokaOne;label.TextColor3=Mount.Cream
		label.Parent=gui
		gui.Parent=item
	end
end
-- One frame's pieces and ropes (DashFete) under `parent`. The ropes hang between attachments on one invisible anchor.
local function place(parent,frame,pieces,ropes,group)
	for _,p in ipairs(pieces)do
		local item=part(parent,p.name,p.size,frame*p.at,p.colour)
		item.Shape=Shapes[p.shape]or Enum.PartType.Block
		item.Material=Materials[p.material]or Enum.Material.SmoothPlastic
		item.Transparency=p.transparency or 0
		item.CastShadow=p.shadow==true
		if p.words then words(item,p.words)end
	end
	if #ropes==0 then return end
	local anchor=part(parent,group.."Anchor",Vector3.new(.2,.2,.2),frame,Mount.Cream)
	anchor.Transparency=1
	local colour=ColorSequence.new(require(Shared.DashFete).Rope)
	local function attach(at)
		local a=Instance.new("Attachment")
		-- The attachment's axis (its X) points down, so positive CurveSize sags the rope (DashLine).
		a.CFrame=CFrame.new(at)*CFrame.Angles(0,0,-math.pi/2)
		a.Parent=anchor
		return a
	end
	for _,r in ipairs(ropes)do
		local beam=Instance.new("Beam");beam.Name=r.name
		beam.Attachment0,beam.Attachment1=attach(r.a),attach(r.b)
		beam.Width0,beam.Width1=r.width,r.width;beam.Segments=if r.sag>0 then 10 else 1;beam.FaceCamera=true
		beam.Color=colour;beam.LightEmission=0;beam.LightInfluence=1
		local curve=r.sag/.75 -- DashRing.curve: a cubic Bezier's middle drops .75 x CurveSize
		beam.CurveSize0,beam.CurveSize1=curve,-curve
		beam.Parent=anchor
	end
end
-- The river stones (WORLD-ALIVE-LOOK section 4): each walkable stone carved (StoneBuilder) over a darker wet band, a
-- moss plate on top, the company stones, the two landings in the kerb, and one invisible collider per stone and landing.
Mount.StonesName="RiverStones"
function Mount.buildStones(parent,options)
	options=options or {}
	local Stones=require(Shared.RiverStones)
	local Builder=require(script.Parent.StoneBuilder)
	local folder=Instance.new("Model");folder.Name=Mount.StonesName
	local carve={carve=options.carve,spawn=options.spawn}
	local okMoss,moss=pcall(function()return require(Shared.LifeArtR4).id(Stones.Moss.texture)end)
	for index,stone in ipairs(Stones.Rows)do
		Builder.stone(folder,Stones.band(stone),carve)
		local model=Builder.stone(folder,stone,carve)
		model:SetAttribute("Index",index)
		local M=Stones.Moss
		local plate=part(model,"Moss",Vector3.new(stone.length*M.share,.02,stone.width*M.share),
			CFrame.new(stone.x,stone.top+M.lift,stone.z+(M.upstream or 0))*CFrame.Angles(0,math.rad(stone.turn),0),M.colour)
		plate.Transparency=1
		if okMoss and moss then
			local decal=Instance.new("Decal");decal.Face=Enum.NormalId.Top;decal.Texture=moss;decal.Color3=M.colour
			decal.Transparency=M.transparency;decal.Parent=plate
		end
		-- Players walk on these (Spencer, beta 17); pets ignore the whole Dash model (PetFollow.ground) and the server's
		-- pet floor reads only the lounge.
		local centre,depth,across=Stones.collider(stone)
		local collider=part(folder,"Collider_"..index,Vector3.new(depth,across,across),CFrame.new(centre)*CFrame.Angles(0,0,math.pi/2),Mount.Stone)
		collider.Shape=Enum.PartType.Cylinder;collider.Transparency=1
		collider.CanCollide=true;collider.CanQuery=true
		collider:SetAttribute("DashPart",nil);collider:SetAttribute("StoneCollider",true)
	end
	for _,stone in ipairs(Stones.Company)do Builder.stone(folder,stone,carve)end
	-- The landings sit in the kerb (beta 18): each its own collider, so you walk lawn, landing, first stone at their tops.
	for index,stone in ipairs(Stones.Landings)do
		Builder.stone(folder,stone,carve)
		local centre,depth,across=Stones.landingCollider(stone)
		local collider=part(folder,"LandingCollider_"..index,Vector3.new(depth,across,across),CFrame.new(centre)*CFrame.Angles(0,0,math.pi/2),Mount.Stone)
		collider.Shape=Enum.PartType.Cylinder;collider.Transparency=1
		collider.CanCollide=true;collider.CanQuery=true
		collider:SetAttribute("DashPart",nil);collider:SetAttribute("LandingCollider",true)
	end
	folder.Parent=parent
	return folder
end
function Mount.buildFete(room,options)
	local Fete=require(Shared.DashFete)
	Mount.remove(room)
	local model=Instance.new("Model");model.Name=Mount.ModelName
	local start,finish=frameAt(0),frameAt(Course.Length)
	model:SetAttribute("DashVersion",Course.Version)
	model:SetAttribute("Start",start);model:SetAttribute("Finish",finish)
	model:SetAttribute("Fete",true)
	local lanes={}
	for lane=1,Course.LaneCount do lanes[lane]=Grid.offset(0,false,lane,Course.LaneCount)/100 end
	local pieces,ropes=Fete.start(Mount.PostOut,lanes)
	place(model,start,pieces,ropes,"Start")
	pieces,ropes=Fete.finish()
	place(model,finish,pieces,ropes,"Finish")
	pieces,ropes=Fete.pad(Course.Pad.r/100)
	place(model,CFrame.new(Mount.gate()),pieces,ropes,"Pad")
	Mount.buildStones(model,options)
	model.Parent=room
	return model
end
function Mount.remove(room)
	local existing=room:FindFirstChild(Mount.ModelName)
	if existing then existing:Destroy()end
end
return Mount
