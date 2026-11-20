-- v2 Stat Snacks: the 3D snack (V2-PET-AND-SNACKS-SCOPE 2.1). Size is the number of layers (a
-- child can count it); the stat is the rune on the icing, never only the colour.
--
-- ART HOOK: Model.build is the one place a snack model is made. It builds placeholder geometry
-- (stacked rounded discs: biscuit, cream, stat-colour icing, a rune decal, sugar pearls on the
-- Feast). The production models (Fable, commit eafef32) are in assets/art-source/snacks/export/
-- (snack-{nibble,snack,feast}.fbx, biscuit.png, rune-decal-<stat>-256.png, the manifest): pieces
-- biscuit (shared texture), icing (Color = stat colour, rune decal on its top via UVs) and pearls
-- (Feast only, #FFF6E9); 1 unit = 1 stud, origin at the centre. To swap them in, upload the FBX
-- and textures, keep the MeshParts in a ReplicatedStorage pack like PetAssets, and clone them here
-- with the same contract: a Model, PrimaryPart at the centre, attributes Layers / StatId / SizeId,
-- parts named Layer<n> (bitten top down by SnackEating), all non-colliding and anchored.
local Shared=game:GetService("ReplicatedStorage").Shared
local K=require(Shared.StatEggCatalog)
local Stats=require(Shared.StatCatalog)
local Model={}
Model.Biscuit=Color3.fromHex("#E9B97C")
Model.Cream=Color3.fromHex("#FFF6E9")
Model.Atlas="rbxassetid://99900642594866"
Model.Rune={heart=Vector2.new(8,8),power=Vector2.new(80,8),energy=Vector2.new(152,8),jump=Vector2.new(224,8),speed=Vector2.new(296,8),smarts=Vector2.new(368,8)}

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

-- sizeId: nibble | snack | feast; statId: a StatCatalog id; width (studs, default the catalogue's).
function Model.build(sizeId,statId,width)
	local size=K.size(sizeId)or K.Sizes.nibble
	local stat=Stats.ById[statId]
	local color=if stat then stat.color else Color3.fromHex("#FFFFFF")
	width=width or size.width
	local model=Instance.new("Model");model.Name="StatSnack_"..size.id
	model:SetAttribute("Layers",size.layers);model:SetAttribute("StatId",statId);model:SetAttribute("SizeId",size.id)
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
	-- The rune on top of the icing (the cylinder's +X face points up after the turn).
	if stat and Model.Rune[statId]then
		local gui=Instance.new("SurfaceGui");gui.Name="Mark";gui.Face=Enum.NormalId.Right;gui.LightInfluence=0
		gui.CanvasSize=Vector2.new(64,64);gui.SizingMode=Enum.SurfaceGuiSizingMode.FixedSize;gui.Parent=icing
		local image=Instance.new("ImageLabel");image.BackgroundTransparency=1;image.Image=Model.Atlas
		image.ImageRectOffset=Model.Rune[statId];image.ImageRectSize=Vector2.new(64,64)
		image.AnchorPoint=Vector2.new(.5,.5);image.Position=UDim2.fromScale(.5,.5);image.Size=UDim2.fromScale(.78,.78);image.Parent=gui
	end
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
	camera.CFrame=CFrame.lookAt(Vector3.new(0,1.6,2.9),Vector3.new(0,.02,0))
	local angle=0
	local api={viewport=viewport,model=model}
	function api.step(dt)
		if not model.Parent then return end
		angle+=dt*1.2
		model:PivotTo(CFrame.Angles(math.rad(-12),angle,0))
	end
	function api.destroy()viewport:Destroy()end
	api.step(0)
	return api
end
return Model
