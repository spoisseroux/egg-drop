-- Waterfall layers, step 1 (WORLD-PASS-2026-11-22 item 4; artifacts/world-pass-2026-11-22/WATERFALL-LOOK.md; values in
-- WorldAero.Waterfall). Built by AeroAdditions inside its folder, so the Aero switch, the budget levels and Reduced
-- Motion govern them, and dropping the folder is the whole restore: nothing outside it is written. Placed from
-- WorldV7Data.beams.sheets (the walk map's falls): strands, ribbons and lips on Tumble's two tiers, foam, rings, mist and
-- a rainbow at its pool; Sky Falls gets a strand, a ribbon and one mist.
--
-- Everything is built switched off; apply(state) turns layers on or off (never destroys them):
--   on only for the falls nearest the camera, within Radius; mist off within MistKeepOut of its point;
--   round 6 (Spencer: "can you improve the water fall distance too"): at level 0 the beams and lips (not the emitters
--   or the rainbow) of every falls within FarRadius stay on, so a falls seen from across the island still moves;
--   rainbow only while daylight > RainbowDaylight; level 1 keeps Level1 at Tumble only; level 2 or Reduced Motion: none.
--   Touch-only devices start at level 1 (AliveBudget starts everyone at 0); the budget can still take them to 2.
--   TextureSpeed is written once, at build: a beam that is off does not move, so nothing needs stopping.
--   Emitters switched off by Reduced Motion or the level are cleared; off by distance or the mist keep-out, they fade.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Values=require(Shared:WaitForChild("WorldAero"))
local Look=Values.Waterfall
local Falls={}
Falls.Name="Falls"
-- Read once per build; specs replace it.
function Falls.touch()
	local Input=game:GetService("UserInputService")
	return Input.TouchEnabled==true and Input.KeyboardEnabled~=true
end

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
	return{name=sheet.name,top=vector(sheet.top),bottom=vector(sheet.bottom),width0=sheet.width0,width1=sheet.width1,n=n,t=t,curve=0}
end

-- LOOK-R2 2: the white-water stack at Tumble while the world kit stands. `b`: the builder's own helpers.
function Falls.kitStack(b)
	local K=Look.Kit
	local lower,upper=b.lower,b.upper
	local impact=Vector3.new(lower.bottom.X,Look.PoolTop,lower.bottom.Z)
	local n,t=lower.n,lower.t
	b.holder("Tumble",impact)
	for _,fall in ipairs({upper,lower})do
		-- LOOK-R2 round 4: the flow beams are straight and flat on the sheet's plane, a little in front of the chutes'
		-- low bow (camera-facing curved beams drifted a chute off the sheet from the pool edge).
		local flat=table.clone(fall)
		flat.curve=0
		b.sheetBeam("Tumble","FlowA",flat,K.FlowA,K.FlowA.length).level1=true
		b.sheetBeam("Tumble","FlowB",flat,K.FlowB,K.FlowB.length).level1=false
	end
	-- LOOK-R3 1: deeper water at each foot. A static flat beam under the Apron, its map stretched once (foot-shade: image
	-- row 0 at Attachment0, the foot). The ledge pool's smaller one is dropped at level 1.
	local function shade(name,foot,fall,size,level1)
		local spec=K.PoolShade
		local p=b.groups.Tumble.part
		local out,across=fall.n,fall.t
		local a0=b.attach(p,b.frame(foot+UP*spec.up,UP,across,UP:Cross(across)))
		local a1=b.attach(p,b.frame(foot+out*size.out+UP*spec.up,UP,across,UP:Cross(across)))
		local beam=Instance.new("Beam")
		beam.Name=name
		beam.Attachment0,beam.Attachment1=a0,a1
		beam.Width0,beam.Width1=size.width,size.width
		beam.FaceCamera=false
		beam.Texture=spec.Texture
		beam.TextureMode=Enum.TextureMode.Stretch
		beam.TextureLength=1
		beam.TextureSpeed=0
		beam.Segments=1
		beam.Color=ColorSequence.new(spec.Color)
		beam.Transparency=NumberSequence.new(spec.Transparency)
		beam.LightInfluence=1
		beam.LightEmission=0
		beam.Enabled=false
		beam.Parent=p
		b.add({group="Tumble",name=name,kind="beam",item=beam,level1=level1})
	end
	shade("PoolShade",impact,lower,K.PoolShade.pool,true)
	shade("LedgeShade",Vector3.new(upper.bottom.X,lower.top.Y,upper.bottom.Z),upper,K.PoolShade.ledge,false)
	-- Fable R5: soft mist cards at the foot and over the step: camera-facing static beams from `up` to `up + tall`
	-- (a beam stands between its two attachments; FaceCamera turns its width to the camera).
	for index,card in ipairs(K.MistCards.Cards)do
		local spec=K.MistCards
		local fall=if card.at=="ledge"then upper else lower
		local foot=if card.at=="ledge"then Vector3.new(upper.bottom.X,lower.top.Y,upper.bottom.Z)else impact
		local base=foot+fall.t*card.along+fall.n*card.out
		local p=b.groups.Tumble.part
		local a0=b.attach(p,b.frame(base+UP*card.up,fall.n,fall.t,fall.n:Cross(fall.t)))
		local a1=b.attach(p,b.frame(base+UP*(card.up+card.tall),fall.n,fall.t,fall.n:Cross(fall.t)))
		local beam=Instance.new("Beam")
		beam.Name="MistCard"
		beam.Attachment0,beam.Attachment1=a0,a1
		beam.Width0,beam.Width1=card.width,card.width*.85
		beam.FaceCamera=true
		beam.Texture=spec.Texture
		beam.TextureMode=Enum.TextureMode.Stretch
		beam.TextureLength=1
		beam.TextureSpeed=0
		beam.Segments=1
		beam.Color=ColorSequence.new(spec.Color)
		beam.Transparency=NumberSequence.new(spec.Transparency)
		beam.LightInfluence=1
		beam.LightEmission=0
		beam.Enabled=false
		beam.Parent=p
		local layer=b.add({group="Tumble",name="MistCard",kind="beam",item=beam,level1=card.level1==true})
		layer.keepOut=base -- code review r5: off within MistKeepOut of its card, like every mist (a 6-stud card fills the view)
	end
	-- The apron: a flat beam on the pool, flowing out from the foot (attachments' Axis up: it lies in the water).
	do
		local spec=K.Apron
		local p=b.groups.Tumble.part
		-- Axis up (it lies in the water), SecondaryAxis t: its width runs across the pool, its map flows along n.
		local a0=b.attach(p,b.frame(impact+n*spec.from+UP*spec.up,UP,t,UP:Cross(t)))
		local a1=b.attach(p,b.frame(impact+n*spec.to+UP*spec.up,UP,t,UP:Cross(t)))
		local beam=Instance.new("Beam")
		beam.Name="Apron"
		beam.Attachment0,beam.Attachment1=a0,a1
		beam.Width0,beam.Width1=spec.width0,spec.width1
		beam.FaceCamera=false
		beam.Texture=K.Textures.Foam
		beam.TextureMode=Enum.TextureMode.Wrap
		beam.TextureLength=spec.length
		beam.TextureSpeed=spec.speed
		beam.Segments=4
		beam.Color=ColorSequence.new(spec.Color)
		beam.Transparency=spec.Transparency
		beam.LightInfluence=1
		beam.Enabled=false
		beam.Parent=p
		b.add({group="Tumble",name="Apron",kind="beam",item=beam,level1=true})
	end
	local function spot(spec)
		local base=if spec.at=="ledge"then lower.top else impact
		local y=base.Y+spec.up
		local q=base+n*spec.out
		return b.frame(Vector3.new(q.X,y,q.Z),t,UP,n)
	end
	for _,spec in ipairs(K.Emitters)do
		local layer=b.emitter("Tumble",spec.name,b.box(spec.name.."Box",spec.box,spot(spec)),spec)
		layer.level1=spec.level1==true
		if spec.keepOut then layer.keepOut=impact end
		local e=layer.item
		e.Texture=K.Textures[spec.texture]
		e.Shape,e.ShapeStyle=Enum.ParticleEmitterShape.Box,Enum.ParticleEmitterShapeStyle.Volume
		e.Lifetime,e.Speed=spec.Life,spec.Speed
		e.SpreadAngle=Vector2.new(spec.Spread,spec.Spread)
		e.Size,e.Transparency=spec.Size,spec.Transparency
		e.Acceleration=spec.Acceleration
		e.Drag=spec.Drag or 0
		e.Color=ColorSequence.new(spec.Color)
		e.LightEmission=spec.LightEmission or 0
		e.Rotation,e.RotSpeed=NumberRange.new(0,360),NumberRange.new(-20,20)
		if spec.ZOffset then e.ZOffset=spec.ZOffset end
	end
end

-- kit (WorldAeroKit, while the world kit stands, with both Tumble tiers): LOOK-R2's white-water stack replaces the
-- step-1 layers at Tumble (no strands, ribbon, lips, cloud foam, rings or rainbow): two flow beams per drop on the curve
-- the kit's chutes bow out on (CurveSize0 = curve, CurveSize1 = -curve), a flat foam apron, boil, droplets and a quieter
-- mist. AeroWorld switches the flat server beams off while the kit stands. Sky Falls keeps its step-1 layers.
-- moatY (the Hidden Grove's moat surface, while it stands; ARCH-REVIEW-GROVE 3): Sky Falls is cut short there instead
-- of running down to the old sheet's foot (y -68): its bottom and bottom width move up the sheet to that height.
function Falls.cut(fall,moatY)
	if type(moatY)~="number"or moatY~=moatY or fall.bottom.Y>=moatY or fall.top.Y<=moatY then return fall end
	local f=(fall.top.Y-moatY)/(fall.top.Y-fall.bottom.Y)
	local out=table.clone(fall)
	out.bottom=fall.top:Lerp(fall.bottom,f)
	out.width1=fall.width0+(fall.width1-fall.width0)*f
	return out
end
function Falls.build(folder,data,kit,moatY)
	local root=Instance.new("Folder")
	root.Name=Falls.Name
	local layers={}
	local groups={}
	local tiers={}
	local sky
	for _,sheet in ipairs(data and data.beams and data.beams.sheets or {})do
		if Look.Tiers[sheet.name]then
			local fall=fallFrame(sheet)
			local shaped=kit and kit.falls and kit.falls[sheet.name]
			fall.curve=shaped and shaped.curve or 0
			tiers[Look.Tiers[sheet.name]]=fall
		elseif sheet.name==Look.Sky then sky=Falls.cut(fallFrame(sheet),moatY)end
	end
	-- Kit mode is all or nothing: both tiers shaped, or today's layers.
	local kitMode=tiers.Upper and tiers.Lower and tiers.Upper.curve>0 and tiers.Lower.curve>0 or false

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
		-- A Beam lays its width along its attachments' SecondaryAxis: up (today's step-1 layers) stands it edge-on to the
		-- camera, so the kit's flow beams (spec.across) take the sheet's t.
		local side=if spec.across then fall.t else UP
		local back=fall.n:Cross(side)
		local a0=attach(p,frame(fall.top+offset,fall.n,side,back))
		local a1=attach(p,frame(fall.bottom+offset,fall.n,side,back))
		local beam=Instance.new("Beam")
		beam.Name=name
		beam.Attachment0,beam.Attachment1=a0,a1
		beam.Width0,beam.Width1=fall.width0*spec.scale+spec.grow,fall.width1*spec.scale+spec.grow
		beam.CurveSize0,beam.CurveSize1=fall.curve,-fall.curve
		-- A beam bent along its attachments' axis turns edge-on to the camera unless it faces it.
		beam.FaceCamera=fall.curve~=0
		beam.Texture=spec.Texture or(if name=="Ribbon"then Look.Textures.Ribbon else Look.Textures.Strand)
		beam.TextureMode=Enum.TextureMode.Wrap
		beam.TextureLength=length
		beam.TextureSpeed=spec.speed
		beam.Segments=if fall.curve~=0 then 14 else 6 -- enough to follow the kit chutes' curve
		beam.Color=ColorSequence.new(spec.Color)
		beam.Transparency=spec.Transparency
		beam.LightInfluence=1
		beam.LightEmission=spec.LightEmission or 0
		beam.Enabled=false
		beam.Parent=p
		return add({group=group,name=name,kind="beam",item=beam})
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
	if lower and kitMode then
		Falls.kitStack({lower=lower,upper=tiers.Upper,holder=holder,sheetBeam=sheetBeam,emitter=emitter,box=box,
			attach=attach,groups=groups,add=add,frame=frame})
	elseif lower then
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
			add({group="Tumble",name="Rainbow",kind="beam",item=beam,rainbow=true})
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
		e.Size=spec.Size
		foamLike(e,Look.MistLook)
		e.ZOffset=Look.MistLook.ZOffset
	end
	root.Parent=folder

	local self={folder=root,layers=layers,groups=groups,state={reduced=false,level=0,camera=nil,daylight=1,touch=Falls.touch()}}
	-- The level the falls draw at: the budget's, or 1 on a touch-only device.
	local function levelOf(state)return math.max(state.level,if state.touch then 1 else 0)end
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
	-- On or off, and whether the switch is Reduced Motion or the level (an emitter so switched is cleared, not faded).
	-- Round 6: the falls within FarRadius of the camera (their beams and lips draw at level 0).
	local function within(camera)
		local out={}
		if typeof(camera)~="Vector3"then return out end
		for name,group in pairs(groups)do
			if(group.anchor-camera).Magnitude<=Look.FarRadius then out[name]=true end
		end
		return out
	end
	function self.wants(layer,state,near,far)
		local level=levelOf(state)
		if state.reduced or level>=2 then return false,true end
		local keep=if layer.level1~=nil then layer.level1 else Look.Level1[layer.name]
		if level>=1 and(layer.group~="Tumble"or not keep)then return false,true end
		if layer.group~=near then
			return level==0 and far~=nil and far[layer.group]==true and layer.kind~="emitter"and not layer.rainbow
		end
		if layer.keepOut and(layer.keepOut-state.camera).Magnitude<Look.MistKeepOut then return false end
		if layer.rainbow and not(state.daylight>Look.RainbowDaylight)then return false end
		return true
	end
	-- Writes only what changed.
	function self.apply(changes)
		local state=self.state
		for key,value in pairs(changes or {})do state[key]=value end
		local near=nearest(state.camera)
		local far=within(state.camera)
		local level=levelOf(state)
		for _,layer in ipairs(layers)do
			local on,cut=self.wants(layer,state,near,far)
			local item=layer.item
			if layer.kind=="beam"then
				if item.Enabled~=on then item.Enabled=on end
			elseif layer.kind=="emitter"then
				local rate=if level>=1 then layer.rate1 else layer.rate
				if item.Rate~=rate then item.Rate=rate end
				-- Fading particles a later cut catches are cleared then.
				if item.Enabled~=on then
					item.Enabled=on
					if on then layer.fading=nil elseif cut then item:Clear()else layer.fading=true end
				elseif cut and layer.fading then
					item:Clear()
					layer.fading=nil
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
