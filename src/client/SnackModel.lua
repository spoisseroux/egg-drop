-- v2 Stat Snacks: the 3D snack (V2-PET-AND-SNACKS-SCOPE 2.1). Size is the number of layers (a
-- child can count it); the stat is the icon on the icing, never only the colour.
--
-- Model.build is the one place a snack model is made. Production (2026-11-19, Sol): Fable's meshes
-- (commit eafef32, assets/art-source/snacks/export/) are uploaded and kept in
-- ReplicatedStorage.SnackAssets (assets/snacks/SnackAssets.rbxmx, built by
-- scripts/build_bunny_assets.py): one Model per size with pieces Biscuit (biscuit.png on its UVs,
-- every layer in one mesh), Icing (Color = the stat colour, the stat's Pocket Buddies icon on a sugar
-- topper, Model.topper) and Pearls (Feast only, #FFF6E9);
-- 1 unit = 1 stud at the template's size, origin at the centre. If the pack or a mesh resource is
-- missing, the placeholder discs below stand in. The contract for both: a Model, its pivot at the
-- centre, attributes Layers / StatId / SizeId / SnackBackend, parts carrying SnackLayer (bitten top
-- down by SnackEating: icing and pearls first, the biscuit last), all non-colliding and anchored.
local Shared=game:GetService("ReplicatedStorage").Shared
local K=require(Shared.StatEggCatalog)
local Stats=require(Shared.StatCatalog)
local Model={}
Model.Biscuit=Color3.fromHex("#E9B97C")
Model.Cream=Color3.fromHex("#FFF6E9")
Model.Atlas="rbxassetid://113812710946093" -- the Pocket Buddies atlas (StatsPanel.Atlas)
Model.PearlColor=Color3.fromHex("#FFF6E9")
Model.Icon={heart=Vector2.new(8,8),power=Vector2.new(80,8),energy=Vector2.new(152,8),jump=Vector2.new(224,8),speed=Vector2.new(296,8),smarts=Vector2.new(368,8)}

local function disc(model,name,diameter,height,y,color,layer)
	local part=Instance.new("Part")
	part.Name=name;part.Shape=Enum.PartType.Cylinder
	-- A cylinder's axis is X: turn it upright.
	part.Size=Vector3.new(height,diameter,diameter)
	part.CFrame=CFrame.new(0,y,0)*CFrame.Angles(0,0,math.rad(90))
	part.Color=color;part.Material=Enum.Material.SmoothPlastic
	part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=false;part.Massless=true
	part.TopSurface=Enum.SurfaceType.Smooth;part.BottomSurface=Enum.SurfaceType.Smooth
	part:SetAttribute("SnackLayer",layer)
	part.Parent=model
	return part
end

-- Spencer 2026-11-20: the piped icon read too faint on the icing, so the stat sits on a sugar
-- topper: a cream disc with an ink rim on the icing's crown, the stat's Pocket Buddies icon decal
-- on it (dark icon on cream reads on every icing colour). Real parts, not a SurfaceGui: a
-- ViewportFrame (the reveal, the pouch) does not draw SurfaceGuis. Bitten with the icing.
Model.IconDecal={heart="rbxassetid://129048015089227",power="rbxassetid://80599387426424",energy="rbxassetid://86725484809476",
	jump="rbxassetid://81760178125384",speed="rbxassetid://102860653332242",smarts="rbxassetid://109890466035862"}
Model.TopperScale=.62
Model.Ink=Color3.fromHex("#15143A")
function Model.topper(model,topY,icingWidth,statId,layer)
	local mark=Model.IconDecal[statId];if not mark then return nil end
	local d=icingWidth*Model.TopperScale;local t=math.max(d*.07,.004)
	local rim=disc(model,"TopperRim",d*1.12,t*.8,topY+t*.2,Model.Ink,layer)
	local plate=disc(model,"Topper",d,t,topY+t*.45,Model.Cream,layer)
	local decal=Instance.new("Decal");decal.Name="Mark";decal.Texture=mark;decal.Face=Enum.NormalId.Right;decal.Parent=plate
	return plate,rim
end

-- Mesh resources by size and piece (assets/snacks/snack-studio-import.json). Rojo live sync can
-- create the pack's MeshParts without their mesh resource; then the client makes its own copy of
-- each piece once with AssetService:CreateMeshPartAsync (Model.warm) and clones that.
Model.MeshIds={
	nibble={Biscuit="rbxassetid://123522428105057",Icing="rbxassetid://105538924874011"},
	snack={Biscuit="rbxassetid://121232393235156",Icing="rbxassetid://113816195081338"},
	feast={Biscuit="rbxassetid://72678333941841",Icing="rbxassetid://77911324217998",Pearls="rbxassetid://140176400239898"},
}
Model.BiscuitTexture="rbxassetid://76061535908073"
local function healthy(part)return part~=nil and part:IsA("MeshPart")and part.MeshId~=""and part.MeshSize.X>0 end
local warmed,warming,lastWarm={},false,-math.huge
-- Builds the runtime copies of any template piece without its resource, in the background. One
-- pass at a time; a size that failed (a mesh download error) is tried again on a later call.
function Model.warm()
	-- At most one pass every 10 s, so a failing download is never retried per snack built.
	if warming or os.clock()-lastWarm<10 then return end
	warming,lastWarm=true,os.clock()
	task.spawn(function()
		local pack=game:GetService("ReplicatedStorage"):FindFirstChild("SnackAssets")
		local AssetService=game:GetService("AssetService")
		for sizeId,pieces in pairs(Model.MeshIds)do
			local size=K.size(sizeId);local template=pack and pack:FindFirstChild(size.name)
			local made={}
			for piece,id in pairs(pieces)do
				local source=template and template:FindFirstChild(piece)
				if warmed[sizeId]or not source then
					-- Ready already, or no template piece to size it by: nothing to fetch.
				elseif healthy(source)then made[piece]=source
				else
					local ok,part=pcall(function()return AssetService:CreateMeshPartAsync(Content.fromUri(id),{CollisionFidelity=Enum.CollisionFidelity.Box,RenderFidelity=Enum.RenderFidelity.Automatic})end)
					if ok and part then
						part.Name=piece;part.Size=source.Size;part.CFrame=source.CFrame
						if piece=="Biscuit"then part.TextureID=Model.BiscuitTexture end
						made[piece]=part
					end
				end
			end
			local complete=not warmed[sizeId];for piece in pairs(pieces)do if not made[piece]then complete=false end end
			if complete then warmed[sizeId]=made end
		end
		warming=false
	end)
end

-- The production pieces for a size ({Biscuit=, Icing=, Pearls=} MeshParts at template size), only
-- when every piece has its mesh resource; nil while they load (the placeholder stands in).
function Model.template(sizeId)
	local size=K.size(sizeId);if not size or not Model.MeshIds[size.id]then return nil end
	if warmed[size.id]then return warmed[size.id]end
	local pack=game:GetService("ReplicatedStorage"):FindFirstChild("SnackAssets")
	local template=pack and pack:FindFirstChild(size.name)
	local pieces={}
	for piece in pairs(Model.MeshIds[size.id])do
		local part=template and template:FindFirstChild(piece)
		if not healthy(part)then Model.warm();return nil end
		pieces[piece]=part
	end
	warmed[size.id]=pieces
	return pieces
end
local function production(template,size,statId,color,width)
	local model=Instance.new("Model");model.Name="StatSnack_"..size.id
	local biscuit=template.Biscuit
	-- Template biscuits are the catalogue widths (0.20 / 0.25 / 0.30); scale to the asked width.
	local scale=width/math.max(biscuit.Size.X,1e-3)
	local base,icing
	for _,source in pairs(template)do
		do
			local part=source:Clone()
			part.Size=source.Size*scale;part.CFrame=CFrame.new(source.Position*scale)*source.CFrame.Rotation
			part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=false;part.Massless=true
			part.Material=Enum.Material.SmoothPlastic
			if part.Name=="Biscuit"then part.Color=Color3.new(1,1,1);part:SetAttribute("SnackLayer",1);base=part
			elseif part.Name=="Icing"then
				part.Color=color;part:SetAttribute("SnackLayer",size.layers)
				icing=part
			else part.Color=Model.PearlColor;part:SetAttribute("SnackLayer",size.layers)end
			part.Parent=model
		end
	end
	if icing then Model.topper(model,icing.Position.Y+icing.Size.Y/2,math.min(icing.Size.X,icing.Size.Z),statId,size.layers)end
	model.PrimaryPart=base
	base.PivotOffset=base.CFrame:Inverse()
	model:SetAttribute("SnackBackend","Production")
	return model
end

-- sizeId: nibble | snack | feast; statId: a StatCatalog id; width (studs, default the catalogue's).
-- options.placeholder forces the disc stand-in (specs).
function Model.build(sizeId,statId,width,options)
	local size=K.size(sizeId)or K.Sizes.nibble
	local stat=Stats.ById[statId]
	local color=if stat then stat.color else Color3.fromHex("#FFFFFF")
	width=width or size.width
	local template=not(options and options.placeholder)and Model.template(size.id)or nil
	if template then
		local made=production(template,size,statId,color,width)
		made:SetAttribute("Layers",size.layers);made:SetAttribute("StatId",statId);made:SetAttribute("SizeId",size.id)
		return made
	end
	local model=Instance.new("Model");model.Name="StatSnack_"..size.id
	model:SetAttribute("Layers",size.layers);model:SetAttribute("StatId",statId);model:SetAttribute("SizeId",size.id)
	model:SetAttribute("SnackBackend","Placeholder")
	local h=width*.2
	local y=-(size.layers*h+(size.layers-1)*h*.45)/2+h/2
	local base
	for layer=1,size.layers do
		local biscuit=disc(model,"Layer"..layer,width,h,y,Model.Biscuit,layer)
		base=base or biscuit
		if layer<size.layers then
			disc(model,"Cream"..layer,width*.9,h*.45,y+h*.72,Model.Cream,layer)
			y+=h*1.45
		end
	end
	local icing=disc(model,"Icing",width*.86,h*.3,y+h*.6,color,size.layers)
	-- The icon on top of the icing (the cylinder's +X face points up after the turn).
	if stat then Model.topper(model,icing.Position.Y+h*.15,width*.86,statId,size.layers)end
	if size.id=="feast"then
		for i=1,8 do
			local a=(i-1)/8*math.pi*2
			local pearl=Instance.new("Part");pearl.Name="Pearl"..i;pearl.Shape=Enum.PartType.Ball
			pearl.Size=Vector3.one*width*.1;pearl.Color=Model.Cream;pearl.Material=Enum.Material.SmoothPlastic
			pearl.CFrame=CFrame.new(math.cos(a)*width*.4,y+h*.8,math.sin(a)*width*.4)
			pearl.Anchored=true;pearl.CanCollide=false;pearl.CanTouch=false;pearl.CanQuery=false;pearl.CastShadow=false;pearl.Massless=true
			pearl:SetAttribute("SnackLayer",size.layers);pearl.Parent=model
		end
	end
	model.PrimaryPart=base
	-- Pivot at the centre of the stack, upright (the base part itself is turned on its side, and a
	-- model with a PrimaryPart pivots on it).
	base.PivotOffset=base.CFrame:Inverse()
	return model
end

-- A small spinning preview in a ViewportFrame (the reveal, the pouch's selected snack).
-- Returns {viewport, model, step(dt), destroy()}.
function Model.viewport(parent,sizeId,statId,props)
	local viewport=Instance.new("ViewportFrame")
	viewport.Name="SnackViewport";viewport.BackgroundTransparency=1;viewport.Ambient=Color3.fromRGB(200,200,210)
	viewport.LightColor=Color3.new(1,1,1);viewport.LightDirection=Vector3.new(-1,-2,-1)
	for key,value in pairs(props or {})do viewport[key]=value end
	viewport.Parent=parent
	local world=Instance.new("WorldModel");world.Parent=viewport
	local model=Model.build(sizeId,statId,1)
	model.Parent=world
	local camera=Instance.new("Camera");camera.FieldOfView=30;camera.Parent=viewport;viewport.CurrentCamera=camera
	-- Spencer 2026-11-20: a higher camera and the top tipped toward it, so the topper reads.
	camera.CFrame=CFrame.lookAt(Vector3.new(0,2.05,2.6),Vector3.new(0,.02,0))
	local angle=0
	local api={viewport=viewport,model=model}
	function api.step(dt)
		if not model.Parent then return end
		angle+=dt*1.2
		model:PivotTo(CFrame.Angles(math.rad(16),angle,0))
	end
	function api.destroy()viewport:Destroy()end
	api.step(0)
	return api
end
-- Ready the production meshes early so the first snack shown is already the real one.
if game:GetService("RunService"):IsRunning()then task.defer(function()for id in pairs(Model.MeshIds)do Model.template(id)end end)end
return Model
