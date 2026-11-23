-- The garden hour (GARDEN-HOUR-BUILD-PLAN-2026-11-23, slice A; look: artifacts/world-pass-2026-11-22/GARDEN-HOUR-LOOK.md):
-- a one-hour day and night, the same clock for everyone. Shared and pure, the Finds pattern with one change: a missing
-- switch is OFF. FeatureFlags.GardenHour is the build ceiling and opens only on the beta place or in Studio; the server's
-- switch (GardenHourConfig, ConfigService key `garden_hour`) reaches clients as the workspace attribute `Hour_on`; and
-- the hour also needs the Aero look on (day is WorldAero, and the Aero look is the only Lighting writer). Off is the
-- game before this build: the dusk lock, or Aero at 10.5. FeatureFlags.DayNight is never read or touched here.
--
-- Clock: s = (GetServerTimeNow() + Hour_offset) % 3600. dawn 0-360, day 360-2400, golden 2400-2880, night 2880-3600.
-- Each phase opens with a blend from the one before (90 s; night 120 s), smoothstepped; the rest is a hold, where look()
-- returns the phase's own frozen table (so a 5 s pass writes nothing). Hour_offset is a Studio and beta test seam
-- (/hour at); everywhere else it reads 0.
local RunService=game:GetService("RunService")
local Shared=script.Parent
local Flags=require(Shared.FeatureFlags)
local Aero=require(Shared.Aero)
local Day=require(Shared.WorldAero)
local Dusk=require(Shared.WorldDusk)
local Night=require(Shared.WorldNight)
local Dawn=require(Shared.WorldDawn)
local Hour={}
Hour.PlaceId=107705084891479 -- Pocket Pals Beta
Hour.Attribute="Hour_on"
Hour.OffsetAttribute="Hour_offset"
Hour.Key="garden_hour"
Hour.Period=3600
Hour.SkyThreshold=.35 -- = HollowClock.SkyThreshold: the night faces swap in below it
-- Blend applies a second, by budget level (look section 6); holds keep HollowClock's 5 s pass.
Hour.ApplyRate=table.freeze({[0]=20,[1]=10,[2]=2})
-- The night blends: haze cover added at the sky swap (peak), the total Density clamp, the key light pinch.
Hour.Cover=table.freeze({Density=.06,Haze=.5,MaxDensity=.34})
Hour.Pinch=table.freeze({depth=.45,width=.6,floor=1.1})

-- Golden is WorldDusk but for EnvironmentDiffuseScale (.25 [check]; Dusk has .35) and the new cloud and glow colours.
local Golden={Hour=Dusk.Hour,Daylight=Dusk.Daylight,Atmosphere=Dusk.Atmosphere,Grade=Dusk.Grade,Bloom=Dusk.Bloom,
	SunRays=Dusk.SunRays,Sky=Dusk.Sky,FaceSet="dusk",CloudColor=Dusk.CloudColor,PeakColor=nil,
	Clouds=table.freeze({Cover=.5,Density=.3,Color=Color3.fromHex("#FFD9E4")}),GlowWarm=Color3.fromHex("#FFC96A")}
do
	local lighting=table.clone(Dusk.Lighting)
	lighting.EnvironmentDiffuseScale=.25
	Golden.Lighting=table.freeze(lighting)
end

-- One look per phase: what HollowClock paints. Keys (slices B-F read these):
--   Phase, From (nil in a hold), Blend (nil in a hold, else the raw 0..1), Hour (= Lighting.ClockTime), Daylight,
--   Lighting, Atmosphere, Grade (SproutHollowGrade), Bloom (HollowBloom), SunRays (HollowSunRays) as property tables,
--   Sky (WorldSky: CelestialBodiesShown, SunAngularSize, MoonAngularSize, StarCount), FaceSet ("day" | "dusk" | "night";
--   Hour.skyFaces), CloudColor (W7_Backdrop__cloud*), Clouds (Terrain Clouds: Cover, Density, Color), GlowWarm (glow_warm
--   meshes), PeakColor (far peaks: nil keeps the texture, a Color3 is flat), Cover (0..1 haze cover over the sky swap).
local function hold(name,values)
	return table.freeze({Phase=name,Hour=values.Hour,Daylight=values.Daylight,Lighting=values.Lighting,
		Atmosphere=values.Atmosphere,Grade=values.Grade,Bloom=values.Bloom,SunRays=values.SunRays,Sky=values.Sky,
		FaceSet=values.FaceSet,CloudColor=values.CloudColor,Clouds=values.Clouds,GlowWarm=values.GlowWarm,
		PeakColor=values.PeakColor,Cover=0})
end
local Holds={
	dawn=hold("dawn",Dawn),
	day=hold("day",{Hour=Day.Hour,Daylight=Day.Daylight,Lighting=Day.Lighting,Atmosphere=Day.Atmosphere,Grade=Day.Grade,
		Bloom=Day.Bloom,SunRays=Day.SunRays,Sky=Day.Sky,FaceSet=Day.FaceSet,CloudColor=Day.CloudColor,Clouds=Day.Clouds,
		GlowWarm=Day.Surfaces.glow_warm.Color,PeakColor=nil}),
	golden=hold("golden",Golden),
	night=hold("night",Night),
}
Hour.Holds=table.freeze(Holds)

-- start, stop (s), blend (seconds of the blend in from the phase before).
Hour.Phases=table.freeze({
	table.freeze({name="dawn",start=0,stop=360,blend=90}),
	table.freeze({name="day",start=360,stop=2400,blend=90}),
	table.freeze({name="golden",start=2400,stop=2880,blend=90}),
	table.freeze({name="night",start=2880,stop=3600,blend=120}),
})
local Previous={dawn="night",day="dawn",golden="day",night="golden"}
-- The sun and moon hand over at these hours; the bent ClockTime path puts them on the sky swap.
local Handoff={night=18,dawn=6}

-- Gate ----------------------------------------------------------------------------------------------------------------
-- Specs pass env = {flags, place, studio}; the game passes nothing.
function Hour.testing(env)
	env=env or {}
	local studio=env.studio
	if studio==nil then studio=RunService:IsStudio()end
	return(env.place or game.PlaceId)==Hour.PlaceId or studio==true
end
function Hour.ceiling(env)
	env=env or {}
	if(env.flags or Flags).GardenHour~=true then return false end
	return Hour.testing(env)
end
-- Pure: a switch value. Anything but a boolean (missing, malformed) is OFF.
function Hour.resolve(configValue,override,ceiling)
	if ceiling==nil then ceiling=Hour.ceiling()end
	if not ceiling then return false end
	if type(override)=="boolean"then return override end
	return configValue==true
end
-- Server only (GardenHourConfig): the resolved value server checks read. Off until it is set.
local switch=false
function Hour.setSwitch(value)
	if not RunService:IsServer()then return false end
	switch=value==true
	return true
end
-- Ceiling, switch (missing = off) and the Aero look.
function Hour.on()
	if not Hour.ceiling()then return false end
	if RunService:IsServer()and not switch then return false end
	return workspace:GetAttribute(Hour.Attribute)==true and Aero.on()
end
function Hour.changed()return workspace:GetAttributeChangedSignal(Hour.Attribute)end
function Hour.offsetChanged()return workspace:GetAttributeChangedSignal(Hour.OffsetAttribute)end

-- Clock ---------------------------------------------------------------------------------------------------------------
local function finite(value)return type(value)=="number"and value==value and math.abs(value)<math.huge end
-- Seconds added to server time: the Hour_offset attribute in Studio and on the beta, else 0.
function Hour.offset(env)
	if not Hour.testing(env)then return 0 end
	local value=workspace:GetAttribute(Hour.OffsetAttribute)
	return if finite(value)then value else 0
end
function Hour.time()return workspace:GetServerTimeNow()+Hour.offset()end
local function seconds(t)
	if not finite(t)then t=Hour.time()end
	return t%Hour.Period
end
local function smooth(f)return f*f*(3-2*f)end

-- Pure: {phase, from, s (0..3600), f (s / 3600), blend (raw 0..1, nil in a hold), k (smoothstepped blend, 1 in a hold),
-- daylight}. `t` is server time plus offset (Hour.time()); nil reads the clock.
function Hour.phase(t)
	local s=seconds(t)
	local at=Hour.Phases[#Hour.Phases]
	for _,phase in ipairs(Hour.Phases)do
		if s<phase.stop then at=phase;break end
	end
	local into=s-at.start
	local daylight=Holds[at.name].Daylight
	local out={phase=at.name,s=s,f=s/Hour.Period,k=1,daylight=daylight}
	if into<at.blend then
		out.from=Previous[at.name]
		out.blend=into/at.blend
		out.k=smooth(out.blend)
		local a=Holds[out.from].Daylight
		out.daylight=a+(daylight-a)*out.k
	end
	return out
end
-- Night finds read the phase, not daylight (look section 1).
function Hour.isNight(t)return seconds(t)>=2880 end
-- True inside a blend window (the client's 20 Hz apply); false in holds.
function Hour.Blending(t)return Hour.phase(t).blend~=nil end

-- The point (in k) where the stepped things (sky faces, stars, sun and moon size, far peaks) change: where daylight
-- crosses SkyThreshold in the night blends, the middle elsewhere. The haze cover peaks and the sun and moon hand over here.
function Hour.stepAt(phase,from)
	if phase=="night"or from=="night"then
		local a,b=Holds[from].Daylight,Holds[phase].Daylight
		return(a-Hour.SkyThreshold)/(a-b)
	end
	return .5
end

local function mix(a,b,k)
	if type(a)=="number"then return a+(b-a)*k end
	return Color3.new(a.R+(b.R-a.R)*k,a.G+(b.G-a.G)*k,a.B+(b.B-a.B)*k)
end
local function blendSection(a,b,k)
	local out={}
	for key,value in pairs(b)do
		local other=a[key]
		out[key]=if type(value)=="number"or typeof(value)=="Color3"then mix(other,value,k)else value
	end
	return out
end
-- Wrapped distance between two hours.
local function hours(a,b)return math.abs((a-b+12)%24-12)end

-- Pure: the look table at `t` (nil reads the clock). In a hold, the phase's own frozen table. `reduced` (Reduced Motion)
-- steps ClockTime once at the sky step instead of sliding it; colours and brightness still blend.
function Hour.look(t,reduced)
	local at=Hour.phase(t)
	if not at.blend then return Holds[at.phase]end
	local a,b,k=Holds[at.from],Holds[at.phase],at.k
	local step=Hour.stepAt(at.phase,at.from)
	local side=if k>=step then b else a
	local out={Phase=at.phase,From=at.from,Blend=at.blend,Daylight=at.daylight,
		Lighting=blendSection(a.Lighting,b.Lighting,k),Atmosphere=blendSection(a.Atmosphere,b.Atmosphere,k),
		Grade=blendSection(a.Grade,b.Grade,k),Bloom=blendSection(a.Bloom,b.Bloom,k),SunRays=blendSection(a.SunRays,b.SunRays,k),
		Clouds=blendSection(a.Clouds,b.Clouds,k),CloudColor=mix(a.CloudColor,b.CloudColor,k),GlowWarm=mix(a.GlowWarm,b.GlowWarm,k),
		Sky=side.Sky,FaceSet=side.FaceSet,PeakColor=side.PeakColor,Cover=0}
	-- ClockTime always moves forward (night to dawn through 24). The night blends bend the path so the sun and moon
	-- hand over (18.0, 6.0) exactly at the sky swap, under the thickest haze.
	local from,to=a.Hour,b.Hour
	if to<from then to+=24 end
	local handoff=Handoff[at.phase]
	local clock
	if reduced then
		clock=if k>=step then b.Hour else a.Hour -- the ends exactly (31.1 % 24 is not 7.1)
	else
		if handoff then
			local mid=handoff
			if mid<from then mid+=24 end
			clock=if k<=step then from+(mid-from)*k/step else mid+(to-mid)*(k-step)/(1-step)
		else
			clock=from+(to-from)*k
		end
		clock%=24
	end
	out.Lighting.ClockTime=clock
	out.Hour=clock
	if handoff then
		-- Haze cover: sin(pi u), u warped so its peak (u = .5) sits on the step.
		local u=if k<=step then .5*k/step else .5+.5*(k-step)/(1-step)
		local cover=math.sin(math.pi*u)
		out.Cover=cover
		out.Atmosphere.Density=math.min(out.Atmosphere.Density+Hour.Cover.Density*cover,Hour.Cover.MaxDensity)
		out.Atmosphere.Haze+=Hour.Cover.Haze*cover
		-- The key light pinch around the handoff, never under the floor.
		local pinch=1-Hour.Pinch.depth*math.max(0,1-hours(clock,handoff)/Hour.Pinch.width)
		out.Lighting.Brightness=math.max(out.Lighting.Brightness*pinch,Hour.Pinch.floor)
	end
	return out
end

-- The six faces for a look's FaceSet (dusk falls back to day until the painted dusk faces are uploaded).
function Hour.skyFaces(faceSet,data)
	local sky=data and data.sky
	if not sky then return nil end
	return sky[faceSet]or sky.day
end

return table.freeze(Hour)
