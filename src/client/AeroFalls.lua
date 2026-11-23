-- Waterfall layers, step 1 (WORLD-PASS-2026-11-22 item 4; artifacts/world-pass-2026-11-22/WATERFALL-LOOK.md; values in
-- WorldAero.Waterfall). Built by AeroAdditions inside its folder, so the Aero switch, the budget levels and Reduced
-- Motion govern them, and dropping the folder is the whole restore: nothing outside it is written. Placed from
-- WorldV7Data.beams.sheets (the walk map's falls): strands, ribbons and lips on Tumble's two tiers, foam, rings, mist and
-- a rainbow at its pool; Sky Falls gets a strand, a ribbon and one mist.
--
-- Everything is built switched off; apply(state) turns layers on or off (never destroys them):
--   on only for the falls nearest the camera, within Radius; mist off within MistKeepOut of its point;
--   rainbow only while daylight > RainbowDaylight; level 1 keeps Level1 at Tumble only; level 2 or Reduced Motion: none,
--   and beams' TextureSpeed goes to 0 (still) until motion is back.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Values=require(Shared:WaitForChild("WorldAero"))
local Look=Values.Waterfall
local Falls={}
Falls.Name="Falls"

local UP=Vector3.new(0,1,0)
-- Columns x, y, z at position p.
local function frame(p,x,y,z)
	return CFrame.new(p.X,p.Y,p.Z,x.X,y.X,z.X,x.Y,y.Y,z.Y,x.Z,y.Z,z.Z)
end
local function vector(list)return Vector3.new(list[1],list[2],list[3])end

local function inert(p)
	p.Anchored=true
	p.CanCollide=false
	p.CanQuery=false
	p.CanTouch=false
	p.CastShadow=false
	p.Massless=true
end
local function part(folder,name,size,cframe,shape)
	local p=Instance.new("Part")
	p.Name=name
	inert(p)
	if shape then p.Shape=shape end
	p.Size,p.CFrame=size,cframe
	p.TopSurface,p.BottomSurface=Enum.SurfaceType.Smooth,Enum.SurfaceType.Smooth
	p.Transparency=1
	p.Parent=folder
	return p
end

-- One fall: its sheet's frame. t is n turned 90 degrees flat.
local function fallFrame(sheet)
	local n=vector(sheet.normal).Unit
	local t=Vector3.new(n.Z,0,-n.X).Unit
	return{name=sheet.name,top=vector(sheet.top),bottom=vector(sheet.bottom),width0=sheet.width0,width1=sheet.width1,n=n,t=t}
end

function Falls.build(folder,data)
	local root=Instance.new("Folder")
	root.Name=Falls.Name
	local layers={}
	local groups={}
	local tiers={}
	local sky
	for _,sheet in ipairs(data and data.beams and data.beams.sheets or {})do
		if Look.Tiers[sheet.name]then tiers[Look.Tiers[sheet.name]]=fallFrame(sheet)
		elseif sheet.name==Look.Sky then sky=fallFrame(sheet)end
	end

	local function add(layer)table.insert(layers,layer);return layer end
	-- An invisible holder per falls at its anchor point; attachments are placed in world terms.
	local function holder(group,at)
		local p=part(root,group.."Anchor",Vector3.new(.2,.2,.2),CFrame.new(at))
		groups[group]={anchor=at,part=p}
		return p
	end
	local function attach(p,cframe)
		local a=Instance.new("Attachment")
		a.CFrame=p.CFrame:Inverse()*cframe
		a.Parent=p
		return a
	end
	-- A flat beam down a sheet: attachments' Axis is the normal, SecondaryAxis world up (as the server's sheets).
	local function sheetBeam(group,name,fall,spec,length)
		local p=groups[group].part
		local offset=fall.n*spec.out+fall.t*spec.shift
		local back=fall.n:Cross(UP)
		local a0=attach(p,frame(fall.top+offset,fall.n,UP,back))
		local a1=attach(p,frame(fall.bottom+offset,fall.n,UP,back))
		local beam=Instance.new("Beam")
		beam.Name=name
		beam.Attachment0,beam.Attachment1=a0,a1
		beam.Width0,beam.Width1=fall.width0*spec.scale+spec.grow,fall.width1*spec.scale+spec.grow
		beam.FaceCamera=false
		beam.Texture=if name=="Ribbon"then Look.Textures.Ribbon else Look.Textures.Strand
		beam.TextureMode=Enum.TextureMode.Wrap
		beam.TextureLength=length
		beam.TextureSpeed=spec.speed
		beam.Segments=6
		beam.Color=ColorSequence.new(spec.Color)
		beam.Transparency=spec.Transparency
		beam.LightInfluence=1
		beam.LightEmission=spec.LightEmission or 0
		beam.Enabled=false
		beam.Parent=p
		return add({group=group,name=name,kind="beam",item=beam,speed=spec.speed})
	end
	-- A clear box turned to the fall's frame (t, up, n), for an emitter.
	local function box(name,size,cframe)return part(root,name,size,cframe)end
	local function emitter(group,name,host,spec)
		local e=Instance.new("ParticleEmitter")
		e.Name=name
		e.EmissionDirection=Enum.NormalId.Top
		e.Enabled=false
		e.Parent=host
		return add({group=group,name=name,kind="emitter",item=e,rate=spec.rate,rate1=spec.rate1 or spec.rate})
	end
	local function foamLike(e,look)
		e.Lifetime=look.Life
		e.Speed=look.Speed
		e.SpreadAngle=Vector2.new(look.Spread,look.Spread)
		e.Transparency=look.Transparency
		e.Color=look.Color
		e.Rotation=NumberRange.new(0,360)
		e.RotSpeed=look.RotSpeed
	end

	local lower=tiers.Lower
	if lower then
		local impact=Vector3.new(lower.bottom.X,Look.PoolTop,lower.bottom.Z)
		local n,t=lower.n,lower.t
		holder("Tumble",impact)
		for _,tierName in ipairs({"Upper","Lower"})do
			local fall=tiers[tierName]
			if not fall then continue end
			for _,strand in ipairs(Look.Strands)do sheetBeam("Tumble",strand.name,fall,strand,strand.length)end
			sheetBeam("Tumble","Ribbon",fall,Look.Ribbon,Look.Ribbon.length)
			local lip=Look.Lips[tierName]
			local roll=part(root,"Lip"..tierName,Vector3.new(lip.length,lip.thickness,lip.thickness),
				frame(fall.top+fall.n*lip.out,fall.t,UP,fall.t:Cross(UP)),Enum.PartType.Cylinder)
			roll.Material,roll.Color,roll.Reflectance=Enum.Material.SmoothPlastic,Look.LipLook.Color,Look.LipLook.Reflectance
			add({group="Tumble",name="Lip",kind="part",item=roll})
		end
		local function at(spec)
			local base=if spec.at=="ledge"then lower.top else impact
			local y=if spec.at=="ledge"then lower.top.Y+spec.up else Look.PoolTop+spec.up
			local p=base+n*spec.out
			return frame(Vector3.new(p.X,y,p.Z),t,UP,n)
		end
		for _,spec in ipairs(Look.Foam)do
			local e=emitter("Tumble",spec.name,box(spec.name.."Box",spec.box,at(spec)),spec).item
			e.Texture=Look.Textures.Foam
			e.Shape,e.ShapeStyle=Enum.ParticleEmitterShape.Box,Enum.ParticleEmitterShapeStyle.Volume
			e.Size=spec.Size
			foamLike(e,Look.FoamLook)
			e.Acceleration=Look.FoamLook.Acceleration
			e.Drag=Look.FoamLook.Drag
			e.LightEmission=Look.FoamLook.LightEmission
		end
		do
			local spec=Look.Rings
			local p=impact+n*spec.out
			local e=emitter("Tumble","Rings",box("RingsPoint",Vector3.new(.2,.2,.2),
				frame(Vector3.new(p.X,Look.PoolTop+spec.up,p.Z),t,UP,n)),spec).item
			e.Texture=Look.Textures.Ripple
			e.Orientation=Enum.ParticleOrientation.VelocityPerpendicular
			e.Lifetime=NumberRange.new(spec.life)
			e.Speed=NumberRange.new(spec.speed)
			e.SpreadAngle=Vector2.new(0,0)
			e.Size=spec.Size
			e.Transparency=spec.Transparency
			e.Color=ColorSequence.new(Color3.new(1,1,1))
			e.Rotation,e.RotSpeed=NumberRange.new(0),NumberRange.new(0)
		end
		for _,spec in ipairs(Look.Mist)do
			local layer=emitter("Tumble",spec.name,box(spec.name.."Box",spec.box,at(spec)),spec)
			layer.keepOut=impact
			local e=layer.item
			e.Texture=Look.Textures.Mist
			e.Shape,e.ShapeStyle=Enum.ParticleEmitterShape.Box,Enum.ParticleEmitterShapeStyle.Volume
			e.Size=spec.Size
			foamLike(e,Look.MistLook)
			e.ZOffset=Look.MistLook.ZOffset
		end
		do
			local spec=Look.Rainbow
			local p=groups.Tumble.part
			local foot=impact+n*spec.out+UP*spec.up
			-- Axis up for the curve; the beam faces the camera, so the other axes only need to be square.
			local a0=attach(p,frame(foot-t*spec.half,UP,n,UP:Cross(n)))
			local a1=attach(p,frame(foot+t*spec.half,UP,n,UP:Cross(n)))
			local beam=Instance.new("Beam")
			beam.Name="Rainbow"
			beam.Attachment0,beam.Attachment1=a0,a1
			beam.CurveSize0,beam.CurveSize1=spec.curve,-spec.curve
			beam.Width0,beam.Width1=spec.width,spec.width
			beam.FaceCamera=true
			beam.Segments=spec.segments
			beam.Texture=Look.Textures.Rainbow
			beam.TextureMode=Enum.TextureMode.Stretch
			beam.TextureLength=1
			beam.TextureSpeed=0
			beam.Color=ColorSequence.new(Color3.new(1,1,1))
			beam.Transparency=spec.Transparency
			beam.LightEmission,beam.LightInfluence=spec.LightEmission,0
			beam.Enabled=false
			beam.Parent=p
			add({group="Tumble",name="Rainbow",kind="beam",item=beam,speed=0,rainbow=true})
		end
	end
	if sky then
		holder("Sky",sky.top)
		local strand=Look.Strands[1]
		sheetBeam("Sky",strand.name,sky,strand,strand.skyLength)
		sheetBeam("Sky","Ribbon",sky,Look.Ribbon,Look.Ribbon.skyLength)
		local spec=Look.SkyMist
		local p=sky.top+sky.n*spec.out+UP*spec.up
		local layer=emitter("Sky","Mist",box("MistBox",spec.box,frame(p,sky.t,UP,sky.n)),spec)
		layer.keepOut=p
		local e=layer.item
		e.Texture=Look.Textures.Mist
		e.Shape,e.ShapeStyle=Enum.ParticleEmitterShape.Box,Enum.ParticleEmitterShapeStyle.Volume
		e.Size=Look.Mist[1].Size
		foamLike(e,Look.MistLook)
		e.ZOffset=Look.MistLook.ZOffset
	end
	root.Parent=folder

	local self={folder=root,layers=layers,groups=groups,state={reduced=false,level=0,camera=nil,daylight=1}}
	-- The falls the camera is at: the nearest within Radius, or none.
	local function nearest(camera)
		if typeof(camera)~="Vector3"then return nil end
		local best,bestDistance=nil,Look.Radius
		for name,group in pairs(groups)do
			local distance=(group.anchor-camera).Magnitude
			if distance<=bestDistance then best,bestDistance=name,distance end
		end
		return best
	end
	function self.wants(layer,state,near)
		if state.reduced or state.level>=2 or layer.group~=near then return false end
		if state.level>=1 and(layer.group~="Tumble"or not Look.Level1[layer.name])then return false end
		if layer.keepOut and(layer.keepOut-state.camera).Magnitude<Look.MistKeepOut then return false end
		if layer.rainbow and not(state.daylight>Look.RainbowDaylight)then return false end
		return true
	end
	-- Writes only what changed.
	function self.apply(changes)
		local state=self.state
		for key,value in pairs(changes or {})do state[key]=value end
		local near=nearest(state.camera)
		for _,layer in ipairs(layers)do
			local on=self.wants(layer,state,near)
			local item=layer.item
			if layer.kind=="beam"then
				local speed=if state.reduced then 0 else layer.speed
				if item.TextureSpeed~=speed then item.TextureSpeed=speed end
				if item.Enabled~=on then item.Enabled=on end
			elseif layer.kind=="emitter"then
				local rate=if state.level>=1 then layer.rate1 else layer.rate
				if item.Rate~=rate then item.Rate=rate end
				if item.Enabled~=on then
					item.Enabled=on
					if not on then item:Clear()end
				end
			else
				local transparency=if on then 0 else 1
				if item.Transparency~=transparency then item.Transparency=transparency end
			end
			layer.on=on
		end
	end
	-- Draw calls showing now: one per enabled beam or emitter and per visible part.
	function self.draws()
		local count=0
		for _,layer in ipairs(layers)do if layer.on then count+=1 end end
		return count
	end
	self.apply()
	return self
end
return Falls
