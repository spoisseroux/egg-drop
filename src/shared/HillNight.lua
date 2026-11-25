-- The hill's sound and night (WORLD-FINISH-LOOK section 5 "Day and night" and "Sound zones", slice F; architect review
-- applied). Shared and pure: every number here, no instances. The client modules (AmbientAudio's zones, HillNightClient,
-- GardenLife's terrace fireflies) read it.
--
-- Gate: the Alive `scene` switch (the one the den's echo already uses: its ceiling is the beta place or Studio, so live
-- never builds or runs any of this), the island's sculpt in (workspace CliffDen) and, for what stands on the hill (the
-- glow-caps, the terrace fireflies), the tier open (Tier.on). Off is the game before this build.
--
--   zone(point)            by the camera: "den" (DenLayout.inRoom, the echo's own test), "terrace" (Tier's terrace
--                          over its floor), "path" (over the cliff path's tread off the lawn, with its height 0..1), "home"
--   mix(zone, h)           the gains for that place: {water, birds, wind, music, room} in dB (room: the den's tone)
--   ease(from, goal, t)    each dB from where it was to its goal, smoothstepped over Ease seconds whatever the size;
--                          under Floor dB is silence
--   lanternLift(daylight)  1 by day to 1.5 at night (under .4); paneColour() lifts without changing the hue (code
--                          review: x1.5 clamped would turn the amber pane lemon), lightNight the lamps' share
--   capAlpha(daylight)     the glow-caps' opacity: 0 by day, up through .45 -> .35
--   glowCaps(), terraceSpots()  where the glow-caps stand and where terrace fireflies may hover
local Tier=require(script.Parent.Tier)
local Night={}
Night.Ease=.6            -- seconds for a whole change (the brief's .6 s)
Night.Floor=-40          -- dB: at or under this a gain is silence (0)
Night.Sample=.25         -- seconds between camera zone samples
-- dB per place (brief section 5). Music is never reverbed (the den's echo is on the ambience and SFX groups only).
Night.Mix=table.freeze({
	home=table.freeze({water=0,birds=0,wind=0,music=0,room=Night.Floor}),
	den=table.freeze({water=-12,birds=-12,wind=0,music=-6,room=0}),        -- home music at 50%, the room tone in
	terrace=table.freeze({water=-9,birds=0,wind=4,music=0,room=Night.Floor}),
	path=table.freeze({water=-6,birds=0,wind=4,music=0,room=Night.Floor}),  -- at the top: scaled by the height h
})
Night.Keys=table.freeze({"water","birds","wind","music","room"})
-- The path: over the tread (plan reach `PathReach` from the centre line), the camera within these of the tread, the
-- tread this far over the lawn; h = (tread - FootY) / (FloorY - FootY).
Night.PathReach,Night.PathBelow,Night.PathAbove,Night.PathLift=8,1,20,2
Night.TerraceGrow,Night.TerraceOver=2,2
-- The lanterns: panes 1 to 1.5 as daylight falls under .4; the pane's own colour takes what it can without leaving its
-- hue, the lamps' PointLights (HollowClock's HollowLamp grading) a little more at night. Fable checks both.
Night.LiftStart,Night.LiftMax=.4,1.5
Night.LightDay,Night.LightNight=.9,1.15
-- The glow-caps: unlit, shown under .4 (in over .45 -> .35). Colour under the Aero bloom threshold like the crystals
-- (#A07A3C); Fable picks the final one.
Night.CapIn,Night.CapFull=.45,.35
Night.CapColour="#7FA48C"
Night.CapStem="#CFC7B2"
Night.CapTransparency=.3

local function smoothstep(x)x=math.clamp(x,0,1);return x*x*(3-2*x)end
function Night.db(gain)return if gain<=0 then Night.Floor else math.max(Night.Floor,20*math.log10(gain))end
function Night.gain(db)return if db<=Night.Floor+1e-9 then 0 else 10^(db/20)end

-- Which place the camera is in. `den` is the open den's layout (DenLayout) or nil; `p` Tier.path() (optional).
function Night.zone(point,den,p,DenLayout)
	if typeof(point)~="Vector3"or point.X~=point.X or point.Y~=point.Y or point.Z~=point.Z then return "home",0 end
	if den~=nil and DenLayout~=nil and DenLayout.inRoom(den,point)then return "den",0 end
	if point.Y>Tier.RegionY+Night.TerraceOver and Tier.inPiece(Tier.Pieces[1],point.X,point.Z,Night.TerraceGrow)then return "terrace",1 end
	local tread=Tier.onPath(point.X,point.Z,Night.PathReach,p)
	if tread and tread>=Tier.FootY+Night.PathLift and point.Y>=tread-Night.PathBelow and point.Y<=tread+Night.PathAbove then
		return "path",math.clamp((tread-Tier.FootY)/(Tier.FloorY-Tier.FootY),0,1)
	end
	return "home",0
end
-- The dB goals for a place (the path's scale with its height).
function Night.mix(zone,h)
	local row=Night.Mix[zone]or Night.Mix.home
	local out={}
	for _,key in ipairs(Night.Keys)do
		local v=row[key]
		if zone=="path"and key~="room"then v=v*math.clamp(h or 0,0,1)end
		out[key]=v
	end
	return out
end
-- The eased mix (dB): every change takes Ease seconds, whatever its size, smoothstepped from where it started (`from`)
-- to the goal; t is the time since the goal changed. from, goal: {key=dB}.
function Night.ease(from,goal,t)
	local k=smoothstep((t or 0)/Night.Ease)
	local out={}
	for _,key in ipairs(Night.Keys)do
		local a,b=from[key]or 0,goal[key]or 0
		out[key]=a+(b-a)*k
	end
	return out
end
function Night.same(a,b)
	for _,key in ipairs(Night.Keys)do if math.abs((a[key]or 0)-(b[key]or 0))>1e-6 then return false end end
	return true
end
-- Linear gains of a dB state.
function Night.gains(state)
	local out={}
	for _,key in ipairs(Night.Keys)do out[key]=Night.gain(state[key]or 0)end
	return out
end

function Night.lanternLift(daylight)
	if type(daylight)~="number"or daylight~=daylight then return 1 end
	return 1+(Night.LiftMax-1)*smoothstep((Night.LiftStart-daylight)/Night.LiftStart)
end
-- The pane's colour lifted by `k` without leaving its hue: at most to the brightest channel's full.
function Night.paneColour(base,k)
	local top=math.max(base.R,base.G,base.B,1e-6)
	local s=math.min(k,1/top)
	return Color3.new(base.R*s,base.G*s,base.B*s)
end
-- The lamps' brightness at a lift (day 1 -> LightDay, full lift -> LightNight).
function Night.lightAt(k)
	return Night.LightDay+(Night.LightNight-Night.LightDay)*math.clamp((k-1)/(Night.LiftMax-1),0,1)
end
function Night.capAlpha(daylight)
	if type(daylight)~="number"or daylight~=daylight then return 0 end
	return smoothstep((Night.CapIn-daylight)/(Night.CapIn-Night.CapFull))
end

-- Where the glow-caps stand ({position on the floor, seed, cluster}): three beside the path's lip stones (CliffDenData's
-- `lip` collision boxes nearest a quarter, half and three quarters of the way up), one in the turn pocket on its outer
-- side, two at the lookout slab (the terrace's floor). `data` CliffDenData (optional). [check] With the path art in, the
-- drawn lip stones (WorldFinishData, server only) stand at their own spacing over the hidden lip boxes: Fable checks
-- that each cap reads as beside a stone, not in a gap.
function Night.glowCaps(data,p)
	p=p or Tier.path()
	if not p then return {}end
	local ok,d=pcall(function()return data or require(script.Parent:FindFirstChild("CliffDenData"))end)
	d=if ok then d else nil
	local out={}
	local U=p.u[#p.u]
	-- The centre line's point at arc length u, and the nearest one to (x, z).
	local function lineAt(u)
		for i=1,#p.points-1 do
			if p.u[i+1]>=u then return p.points[i]:Lerp(p.points[i+1],(u-p.u[i])/math.max(1e-6,p.u[i+1]-p.u[i]))end
		end
		return p.points[#p.points]
	end
	local function nearestLine(x,z)
		local best,bestD=p.points[1],math.huge
		for i=1,#p.points-1 do
			local a,b=p.points[i],p.points[i+1]
			local dx,dz=b.X-a.X,b.Z-a.Z
			local l2=dx*dx+dz*dz
			local t=if l2>0 then math.clamp(((x-a.X)*dx+(z-a.Z)*dz)/l2,0,1)else 0
			local q=a:Lerp(b,t)
			local dd=Vector2.new(x-q.X,z-q.Z).Magnitude
			if dd<bestD then best,bestD=q,dd end
		end
		return best
	end
	local lips={}
	for _,box in ipairs(d and d.collision and d.collision.boxes or {})do
		if box.kind=="lip"then table.insert(lips,Vector3.new(box.c[1],box.c[2]-box.s[2]/2,box.c[3]))end
	end
	local used={}
	for n,frac in ipairs({.25,.5,.75})do
		local want=lineAt(U*frac)
		local best,bestD=nil,math.huge
		for k,lip in ipairs(lips)do
			local dd=Vector2.new(lip.X-want.X,lip.Z-want.Z).Magnitude
			if not used[k]and dd<bestD then best,bestD=k,dd end
		end
		if best then
			used[best]=true
			-- A stud in from the lip stone, toward the centre line (its inner foot), on the tread there.
			local lip=lips[best]
			local c=nearestLine(lip.X,lip.Z)
			local dir=Vector3.new(c.X-lip.X,0,c.Z-lip.Z)
			local at=if dir.Magnitude>1e-3 then lip+dir.Unit*1 else lip
			local y=Tier.onPath(at.X,at.Z,1,p)or c.Y
			table.insert(out,table.freeze({position=Vector3.new(at.X,y,at.Z),seed=20261126+n,cluster=3}))
		end
	end
	-- The turn pocket: 2.8 studs from the turn point on the side away from the terrace's centre (the garden side).
	local turn=d and d.path and d.path.turn
	if type(turn)=="table"then
		local at=Vector3.new(turn[1],turn[2],turn[3])
		local away=Vector3.new(at.X-Tier.C.X,0,at.Z-Tier.C.Z).Unit
		local spot=at+away*2.8
		table.insert(out,table.freeze({position=Vector3.new(spot.X,Tier.onPath(spot.X,spot.Z,1,p)or at.Y,spot.Z),seed=20261130,cluster=3}))
	end
	for n,st in ipairs({{-31,13},{-35,18}})do
		table.insert(out,table.freeze({position=Tier.T(st[1],st[2],Tier.FloorY),seed=20261140+n,cluster=2}))
	end
	return out
end
-- Terrace firefly hover points (the floor, y FloorY): the lookout, along the Top Lawn's flower drift behind its bench,
-- under the tree spot, and the two outer corners' grass.
Night.TerraceFireflies=table.freeze({{-33,15},{-28,10},{-4,-9},{0,-10},{4,-9},{17,-10},{22,-14},{-20,-14},{28,8}})
function Night.terraceSpots()
	local out={}
	for _,st in ipairs(Night.TerraceFireflies)do table.insert(out,Tier.T(st[1],st[2],Tier.FloorY))end
	return out
end
return table.freeze(Night)
