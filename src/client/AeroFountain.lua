-- The fountain in the Bubble Spring's basin (LOOK-R2 3; values in WorldAero.Fountain). Built by AeroAdditions inside its
-- folder, and only while the world kit stands (its stone is the kit's `W7_Kit_Fountain__kitstone`, its spot
-- WorldAeroKit.fountain), so the Aero switch, the budget levels and Reduced Motion govern it and dropping the folder is
-- the whole restore. Three emitters: a jet up from the finial, a spill off the upper bowl's rim, a splash in the basin.
-- The sound is a positional voice through AmbientAudio (its mix, ducks and the deck round's fade); removed on destroy.
--   apply(state): level 2 or Reduced Motion: nothing; level 1: the jet only, at its lower rate; beyond Radius of the
--   camera: off (fading). Only changes are written.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Values=require(Shared:WaitForChild("WorldAero"))
local Look=Values.Fountain
local Fountain={}
Fountain.Name="Fountain"

local function inert(p)
	p.Anchored,p.CanCollide,p.CanQuery,p.CanTouch,p.CastShadow,p.Massless=true,false,false,false,false,true
	p.Transparency=1
end
local function anchor(root,name,size,cframe)
	local p=Instance.new("Part")
	p.Name=name
	inert(p)
	p.Size,p.CFrame=size,cframe
	p.Parent=root
	return p
end
local function vector(list)return Vector3.new(list[1],list[2],list[3])end

-- spot: WorldAeroKit.fountain {centre, top, bowl {y, radius}, water}. ambient: AmbientAudio.shared (or nil: no sound).
function Fountain.build(folder,spot,ambient)
	local root=Instance.new("Folder")
	root.Name=Fountain.Name
	local centre=vector(spot.centre)
	local layers={}
	local function emitter(name,host,spec,texture)
		local e=Instance.new("ParticleEmitter")
		e.Name=name
		e.Texture=texture or Look.Texture
		e.Rate=spec.rate
		e.Speed,e.Lifetime=spec.Speed,spec.Life
		e.SpreadAngle=Vector2.new(spec.Spread,spec.Spread)
		e.Acceleration=spec.Acceleration
		e.Size,e.Transparency=spec.Size,spec.Transparency
		e.Color=ColorSequence.new(Look.Color)
		e.LightInfluence=1
		e.Enabled=false
		e.Parent=host
		table.insert(layers,{name=name,item=e,rate=spec.rate,rate1=spec.rate1 or spec.rate})
		return e
	end
	-- The jet: straight up from the finial, streaks along their flight.
	local jetHost=anchor(root,"JetPoint",Vector3.new(.2,.2,.2),CFrame.new(centre.X,spot.top-.05,centre.Z))
	local jet=emitter("Jet",jetHost,Look.Jet)
	jet.EmissionDirection=Enum.NormalId.Top
	jet.Orientation=Enum.ParticleOrientation.VelocityParallel
	jet.Squash=Look.Squash
	-- The spill: a thin ring at the upper bowl's lip; drops leave it outward and fall into the basin.
	local r=spot.bowl.radius
	local spillHost=anchor(root,"SpillRing",Vector3.new(r*2,.1,r*2),CFrame.new(centre.X,spot.bowl.y,centre.Z))
	local spill=emitter("Spill",spillHost,Look.Spill)
	spill.Shape,spill.ShapeStyle,spill.ShapeInOut=Enum.ParticleEmitterShape.Disc,Enum.ParticleEmitterShapeStyle.Surface,
		Enum.ParticleEmitterShapeInOut.Outward
	spill.Orientation=Enum.ParticleOrientation.VelocityParallel
	spill.Squash=Look.Squash
	-- The splash: where the spill lands, a soft white boil on the basin's water.
	local splashHost=anchor(root,"SplashRing",Vector3.new(r*2+.6,.1,r*2+.6),CFrame.new(centre.X,spot.water+.05,centre.Z))
	local splash=emitter("Splash",splashHost,Look.Splash,Look.Splash.texture)
	splash.Shape,splash.ShapeStyle=Enum.ParticleEmitterShape.Disc,Enum.ParticleEmitterShapeStyle.Surface
	splash.EmissionDirection=Enum.NormalId.Top
	root.Parent=folder

	local remove
	local self={folder=root,layers=layers,state={reduced=false,level=0,camera=nil}}
	function self.wants(layer,state)
		if state.reduced or state.level>=2 then return false,true end
		if state.level>=1 and layer.name~="Jet"then return false,true end
		if typeof(state.camera)~="Vector3"or(state.camera-centre).Magnitude>Look.Radius then return false end
		return true
	end
	function self.apply(changes)
		local state=self.state
		for key,value in pairs(changes or {})do if state[key]~=nil or key=="camera"then state[key]=value end end
		for _,layer in ipairs(layers)do
			local on,cut=self.wants(layer,state)
			local item=layer.item
			local rate=if state.level>=1 then layer.rate1 else layer.rate
			if layer.written~=rate then layer.written=rate;item.Rate=rate end
			if item.Enabled~=on then
				item.Enabled=on
				if not on and cut then item:Clear()end
			end
			layer.on=on
		end
	end
	function self.draws()
		local count=0
		for _,layer in ipairs(layers)do if layer.on then count+=1 end end
		return count
	end
	function self.destroy()
		if remove then remove();remove=nil end
	end
	self.apply()
	-- The voice last, once nothing else can throw (code review r2): a remover is never lost.
	if ambient and ambient.addVoice then
		local voice=Look.Voice
		-- LOOK-R3 3: from a random point of the clip, and the stand-in if the original loop will not load.
		local ok,result=pcall(ambient.addVoice,ambient,"fountain",{id=voice.id,parent=jetHost,volume=voice.volume,
			speed=voice.speed,min=voice.min,max=voice.max,start=Random.new():NextNumber(),fallback=voice.fallback})
		if ok then remove=result end
	end
	return self
end

return Fountain
