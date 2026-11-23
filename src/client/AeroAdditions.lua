-- The few things Aero Medium adds (WORLD-PLAN-2026-11-22 section 9; AeroWorld builds and drops them): a glass dome
-- over the egg nest, white gloss lips on the round stations, dew glints on four lawns and Roblox's own clouds. All in
-- one local folder beside the lounge: anchored, no collision, query, touch or shadow, nothing moves, nothing replicates.
-- The waterfall layers (AeroFalls) live in it too; they move, so still() and update() switch them.
-- With the garden hour on (GardenHour, GARDEN-HOUR-BUILD-PLAN-2026-11-23 slice C; artifacts/world-pass-2026-11-22/
-- GARDEN-HOUR-LOOK.md 5), update() reads the hour's one daylight instead of the one AeroWorld passes: the waterfall
-- rainbow and the dew glints show only by day (> .7), and the v7 fireflies come out at night (< .3; built the first time
-- the hour is on, so with it off nothing here is new). Off is exactly the additions before the hour.
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

-- Fireflies ---------------------------------------------------------------------------------------------------------
local Fly=Values.Fireflies
-- Bright in, a pulse every Pulse seconds of a mean life, bright out; the first and last Fade seconds fade.
function Additions.fireflyFade()
	local mean=(Fly.Life[1]+Fly.Life[2])/2
	local fade,half=Fly.Fade/mean,Fly.Pulse/2/mean
	local points={NumberSequenceKeypoint.new(0,1)}
	local t,bright=fade,true
	while t<1-fade-.02 do
		table.insert(points,NumberSequenceKeypoint.new(t,if bright then .15 else .6))
		t+=half;bright=not bright
	end
	table.insert(points,NumberSequenceKeypoint.new(1-fade,.15))
	table.insert(points,NumberSequenceKeypoint.new(1,1))
	return NumberSequence.new(points)
end
-- One clear box and one emitter an area, built off (Rate 0, Enabled false). Returns {area, box, emitter} a row.
-- All five areas or nothing: a throw partway destroys every box made so far (listed or not yet) and is raised again.
function Additions.fireflies(folder,groundY)
	local list={}
	local ok,problem=pcall(Additions.fireflyAreas,folder,groundY,list)
	if ok then return list end
	for _,item in ipairs(folder:GetChildren())do
		if string.sub(item.Name,1,9)=="Fireflies"then item:Destroy()end
	end
	error(problem,0)
end
function Additions.fireflyAreas(folder,groundY,list)
	local fade=Additions.fireflyFade()
	for _,area in ipairs(Fly.Areas)do
		local y=groundY(area.x,area.z)+Fly.Low+Fly.Band/2
		local box=part(folder,"Fireflies"..area.name,Enum.PartType.Block,Vector3.new(area.width,Fly.Band,area.depth),
			CFrame.new(area.x,y,area.z)*CFrame.Angles(0,area.yaw or 0,0))
		box.Transparency=1
		local e=Instance.new("ParticleEmitter")
		e.Name="Fireflies"
		e.Enabled=false
		e.Rate=0
		e.Texture=Fly.Texture
		e.Shape,e.ShapeStyle=Enum.ParticleEmitterShape.Box,Enum.ParticleEmitterShapeStyle.Volume
		e.EmissionDirection=Enum.NormalId.Top
		-- Any way up or level, slowing to a hover (Drag); Reach in WorldAero is how far that carries.
		e.SpreadAngle=Vector2.new(90,90)
		e.Speed=NumberRange.new(Fly.Speed)
		e.Drag=Fly.Drag
		e.Acceleration=Vector3.zero
		e.Lifetime=NumberRange.new(Fly.Life[1],Fly.Life[2])
		e.Size=NumberSequence.new(Fly.Size)
		e.Transparency=fade
		e.Color=ColorSequence.new(Fly.Color)
		e.LightEmission,e.LightInfluence=Fly.LightEmission,0
		e.Rotation,e.RotSpeed=NumberRange.new(0),NumberRange.new(0)
		e.LockedToPart=false
		e.Parent=box
		table.insert(list,{area=area,box=box,emitter=e})
	end
end
-- 0 at Spawn daylight and above, 1 at Full and below (the count follows the blend in and out).
function Additions.fireflyRamp(daylight)
	if type(daylight)~="number"or daylight~=daylight then return 0 end
	return math.clamp((Fly.Spawn-daylight)/(Fly.Spawn-Fly.Full),0,1)
end
-- Is the camera within keep studs of this box?
function Additions.nearBox(box,camera,keep)
	if typeof(camera)~="Vector3"then return false end
	local p=box.CFrame:PointToObjectSpace(camera)
	local half=box.Size/2
	local dx,dy,dz=math.max(math.abs(p.X)-half.X,0),math.max(math.abs(p.Y)-half.Y,0),math.max(math.abs(p.Z)-half.Z,0)
	return math.sqrt(dx*dx+dy*dy+dz*dz)<keep
end

-- The daylight the additions follow: the garden hour's (its server clock, the same on every client) while it is on,
-- else `today` (what AeroWorld passes: the clock's lastDaylight). Returns hourOn, daylight.
function Additions.daylight(today,hour)
	if hour and hour.on()==true then
		local at=hour.phase(hour.time())
		if type(at)=="table"and type(at.daylight)=="number"then return true,at.daylight end
	end
	return false,today
end

-- Returns {folder, emitters, falls, still(reduced), update({level, camera, daylight}), destroy(), fireflies()};
-- everything or nothing. options: parent, data (WorldV7Data), groundY, clouds=false, falls=false, hour (GardenHour; a
-- fixture in specs), kit (WorldAeroKit while the world kit stands: the falls layers fit its bowed sheets and lips).
function Additions.build(options)
	local folder=Instance.new("Folder")
	folder.Name=Additions.Name
	local clouds,falls
	local groundY=options.groundY or require(Shared:WaitForChild("HollowWorldLayout")).groundY
	local ok,emitters=pcall(function()
		Additions.dome(folder)
		Additions.lips(folder)
		local list=Additions.glints(folder,groundY)
		if options.falls~=false then falls=Falls.build(folder,options.data or require(Shared:WaitForChild("WorldV7Data")),options.kit)end
		if options.clouds~=false then clouds=Additions.clouds()end
		folder.Parent=options.parent
		return list
	end)
	local function destroy()
		folder:Destroy()
		if clouds then clouds:Destroy()end
	end
	if not ok then destroy();error(emitters,0)end
	local hour=options.hour
	if hour==nil then hour=require(Shared:WaitForChild("GardenHour"))end
	-- still: Reduced Motion (nil until the first still()); today: the daylight AeroWorld last passed; on and daylight:
	-- the hour's.
	local state={still=nil,level=0,camera=nil,today=nil,on=false,daylight=nil}
	local flies
	local function levelOf()return if type(state.level)=="number"then state.level else 0 end
	-- Glints and fireflies to what the state wants; only changes are written. cut: Reduced Motion just came on (clear).
	local function paint(cut)
		local reduced=state.still==true
		local glints=not reduced and(not state.on or state.daylight>Values.GlintDaylight)
		for _,emitter in ipairs(emitters)do
			if emitter.Enabled~=glints then emitter.Enabled=glints end
			if cut then emitter:Clear()end
		end
		-- A build that throws is cleaned up and not tried again this session (the update pass runs every 5 s).
		if state.on and not flies and not reduced and levelOf()<2 and not Additions.firefliesFailed then
			local built,result=pcall(Additions.fireflies,folder,groundY)
			if built then flies=result else
				Additions.firefliesFailed=true
				warn("[Aero] fireflies not built: "..tostring(result))
			end
		end
		if not flies then return end
		local ramp=if state.on and not reduced then Additions.fireflyRamp(state.daylight)else 0
		local level=levelOf()
		for _,fly in ipairs(flies)do
			local count=if level>=2 then 0 elseif level>=1 then fly.area.count1 else fly.area.count
			local rate=count*ramp/Fly.Life[2]
			local on=rate>0 and not Additions.nearBox(fly.box,state.camera,Fly.CameraKeepOut+Fly.Reach)
			local e=fly.emitter
			-- Compared with what was last written (Rate is stored as a float32, so reading it back never matches).
			if fly.rate~=rate then fly.rate=rate;e.Rate=rate end
			if e.Enabled~=on then e.Enabled=on end
			if cut then e:Clear()end
			fly.on=on
		end
	end
	return{folder=folder,emitters=emitters,falls=falls,destroy=destroy,state=state,
	fireflies=function()return flies end,
	still=function(reduced)
		reduced=reduced==true
		if falls then falls.apply({reduced=reduced})end
		if reduced==state.still then return end
		state.still=reduced
		paint(reduced)
	end,update=function(changes)
		changes=changes or {}
		if changes.level~=nil then state.level=changes.level end
		if changes.camera~=nil then state.camera=changes.camera end
		if changes.daylight~=nil then state.today=changes.daylight end
		state.on,state.daylight=Additions.daylight(state.today,hour)
		if falls then
			local forward=table.clone(changes)
			forward.daylight=state.daylight
			falls.apply(forward)
		end
		paint(false)
	end}
end
return Additions
