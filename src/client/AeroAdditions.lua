-- The few things Aero Medium adds (WORLD-PLAN-2026-11-22 section 9; AeroWorld builds and drops them): a glass dome
-- over the egg nest, white gloss lips on the round stations, dew glints on four lawns and Roblox's own clouds. All in
-- one local folder beside the lounge: anchored, no collision, query, touch or shadow, nothing moves, nothing replicates.
-- The waterfall layers (AeroFalls) live in it too; they move, so still() and update() switch them.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Values=require(Shared:WaitForChild("WorldAero"))
local Falls=require(script.Parent:WaitForChild("AeroFalls"))
local Additions={}
Additions.Name="EggDropAero"

local function part(folder,name,shape,size,cframe)
	local p=Instance.new("Part")
	p.Name=name
	p.Anchored,p.CanCollide,p.CanQuery,p.CanTouch,p.CastShadow=true,false,false,false,false
	p.Massless=true
	p.Shape=shape
	p.Size,p.CFrame=size,cframe
	p.TopSurface,p.BottomSurface=Enum.SurfaceType.Smooth,Enum.SurfaceType.Smooth
	p.Parent=folder
	return p
end

function Additions.dome(folder)
	local spec=Values.Dome
	local p=part(folder,"EggDome",Enum.PartType.Ball,Vector3.one*spec.diameter,CFrame.new(spec.center))
	p.Material,p.Color=Enum.Material.Glass,spec.Color
	p.Transparency,p.Reflectance=spec.Transparency,spec.Reflectance
	return p
end
function Additions.lips(folder)
	local spec=Values.Lip
	for index,lip in ipairs(Values.Lips)do
		if index>Values.MaxLips then break end
		local across=(lip.radius+spec.out)*2
		-- A cylinder's axis is its X: stood up.
		local p=part(folder,"GlossLip_"..lip.name,Enum.PartType.Cylinder,Vector3.new(spec.thickness,across,across),
			CFrame.new(lip.center)*CFrame.Angles(0,0,math.pi/2))
		p.Material,p.Color,p.Reflectance=Enum.Material.SmoothPlastic,spec.Color,spec.Reflectance
	end
end
function Additions.glints(folder,groundY)
	local emitters={}
	for index,lawn in ipairs(Values.Glints)do
		if index>Values.MaxGlints then break end
		local x,z,width,depth=lawn[1],lawn[2],lawn[3],lawn[4]
		local p=part(folder,"DewLawn"..index,Enum.PartType.Block,Vector3.new(width,.2,depth),CFrame.new(x,groundY(x,z)+.3,z))
		p.Transparency=1
		local e=Instance.new("ParticleEmitter")
		e.Name="Dew"
		e.Texture=Values.GlintTexture
		e.Shape,e.ShapeStyle=Enum.ParticleEmitterShape.Box,Enum.ParticleEmitterShapeStyle.Volume
		e.Rate=Values.GlintRate
		e.Lifetime=NumberRange.new(Values.GlintLife*.6,Values.GlintLife)
		e.Speed=NumberRange.new(0)
		e.Size=NumberSequence.new(Values.GlintSize)
		e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.5,.1),NumberSequenceKeypoint.new(1,1)})
		e.Color=ColorSequence.new(Color3.new(1,1,1))
		e.LightEmission,e.LightInfluence=.5,.2
		e.Rotation=NumberRange.new(0,360)
		e.Parent=p
		table.insert(emitters,e)
	end
	return emitters
end
-- The sky's clouds, unless the place has its own.
function Additions.clouds()
	local terrain=workspace.Terrain
	if terrain:FindFirstChildOfClass("Clouds")then return nil end
	local clouds=Instance.new("Clouds")
	clouds.Name="AeroClouds"
	for key,value in pairs(Values.Clouds)do clouds[key]=value end
	clouds.Parent=terrain
	return clouds
end

-- Returns {folder, emitters, falls, still(reduced), update({level, camera, daylight}), destroy()}; everything or nothing.
-- options: parent, data (WorldV7Data), groundY, clouds=false, falls=false (fixtures).
function Additions.build(options)
	local folder=Instance.new("Folder")
	folder.Name=Additions.Name
	local clouds,falls
	local ok,emitters=pcall(function()
		Additions.dome(folder)
		Additions.lips(folder)
		local list=Additions.glints(folder,options.groundY or require(Shared:WaitForChild("HollowWorldLayout")).groundY)
		if options.falls~=false then falls=Falls.build(folder,options.data or require(Shared:WaitForChild("WorldV7Data")))end
		if options.clouds~=false then clouds=Additions.clouds()end
		folder.Parent=options.parent
		return list
	end)
	local function destroy()
		folder:Destroy()
		if clouds then clouds:Destroy()end
	end
	if not ok then destroy();error(emitters,0)end
	local still
	return{folder=folder,emitters=emitters,falls=falls,destroy=destroy,still=function(reduced)
		reduced=reduced==true
		if falls then falls.apply({reduced=reduced})end
		if reduced==still then return end
		still=reduced
		for _,emitter in ipairs(emitters)do
			emitter.Enabled=not reduced
			if reduced then emitter:Clear()end
		end
	end,update=function(state)
		if falls then falls.apply(state)end
	end}
end
return Additions
