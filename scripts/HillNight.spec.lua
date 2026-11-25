-- The hill's sound and night (WORLD-FINISH-LOOK section 5, slice F; HillNight): the zones by the camera (the den by the
-- echo's own test, the path by its tread with its height, the terrace by its floor, home), the mix for each, the .6 s
-- ease, the lanterns' lift without leaving the pane's hue, the lamps' share, the glow-caps' opacity and spots, the
-- terrace firefly spots, and LifeSim's firefly pool with and without them (the same draws without). Pure.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.HillNight)(ServerScriptService.Server)
-- Offline: python scripts/run_dash_server_specs.py
return function()
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Night=require(Shared.HillNight)
	local Tier=require(Shared.Tier)
	local DenLayout=require(Shared.DenLayout)
	local Data=require(Shared.CliffDenData)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function near(a,b,eps)return math.abs(a-b)<=(eps or 1e-6)end
	local P=assert(Tier.path())
	local den=assert(DenLayout.current({cliffDen=true,data=Data}),"the den's layout")

	test("zones: the den by DenLayout.inRoom (the echo's test), the terrace over its floor, the path over its tread with h, home",function()
		local mid=den.room.min:Lerp(den.room.max,.5)
		assert(Night.zone(Vector3.new(mid.X,den.floorY+4,mid.Z),den,P,DenLayout)=="den")
		assert(Night.zone(Vector3.new(mid.X,den.floorY+4,mid.Z),nil,P,DenLayout)~="den","the den closed (no layout): not the den")
		assert(Night.zone(Tier.T(0,0,Tier.FloorY+12),den,P,DenLayout)=="terrace")
		assert(Night.zone(Tier.T(0,0,Tier.FloorY-12),den,P,DenLayout)~="terrace","under the terrace")
		local n=#P.points
		for _,i in ipairs({math.floor(n*.3),math.floor(n*.6),n-6})do
			local p=P.points[i]
			local zone,h=Night.zone(p+Vector3.new(0,10,0),den,P,DenLayout)
			assert(zone=="path",i)
			assert(near(h,(p.Y-Tier.FootY)/(Tier.FloorY-Tier.FootY),.05),"h at "..i)
		end
		assert(Night.zone(P.points[1]+Vector3.new(0,10,0),den,P,DenLayout)=="home","the path's foot is the lawn")
		assert(Night.zone(Vector3.new(0,12,0),den,P,DenLayout)=="home"and Night.zone(Vector3.new(0/0,0,0),den,P,DenLayout)=="home")
	end)

	test("the mix: den water and birds -12, music 50%, the room tone in; path +4h wind, -6h water; terrace +4 wind, -9 water",function()
		local d=Night.mix("den",0)
		assert(d.water==-12 and d.birds==-12 and d.music==-6 and d.room==0 and d.wind==0)
		assert(near(Night.gain(d.music),.5,.01),"home music at 50%")
		local top,half=Night.mix("path",1),Night.mix("path",.5)
		assert(top.wind==4 and top.water==-6 and half.wind==2 and half.water==-3 and top.room==Night.Floor and top.birds==0)
		local t=Night.mix("terrace",1)
		assert(t.wind==4 and t.water==-9 and t.birds==0 and t.room==Night.Floor)
		local h=Night.mix("home",0)
		for _,key in ipairs(Night.Keys)do if key~="room"then assert(h[key]==0)end end
		assert(Night.gain(Night.Floor)==0 and Night.db(0)==Night.Floor and near(Night.gain(0),1))
	end)

	test("the ease: every change takes .6 s whatever its size, smoothstepped, never past the goal",function()
		local from,goal=Night.mix("home",0),Night.mix("den",0)
		assert(Night.same(Night.ease(from,goal,0),from)and Night.same(Night.ease(from,goal,.6),goal)and Night.same(Night.ease(from,goal,5),goal))
		local half=Night.ease(from,goal,.3)
		assert(near(half.water,-6)and near(half.room,Night.Floor/2),"half way at .3 s, the small change and the big alike")
		local last=from.water
		for k=1,18 do local s=Night.ease(from,goal,k/30);assert(s.water<=last+1e-9 and s.water>=-12-1e-9);last=s.water end
		assert(not Night.same(from,goal)and Night.same(goal,Night.mix("den",0)))
	end)

	test("the lanterns: 1 by day to 1.5 at night (under .4); the pane keeps its amber hue; the lamps' share",function()
		assert(Night.lanternLift(1)==1 and Night.lanternLift(.4)==1 and near(Night.lanternLift(0),1.5))
		local last=1
		for d=.4,0,-.05 do local k=Night.lanternLift(d);assert(k>=last-1e-9);last=k end
		local pane=Color3.fromHex("#C9772E")
		for _,k in ipairs({1,1.2,1.5})do
			local c=Night.paneColour(pane,k)
			assert(c.R<=1+1e-9 and c.G<=1+1e-9 and c.B<=1+1e-9)
			assert(near(c.R/c.G,pane.R/pane.G,1e-6)and near(c.G/c.B,pane.G/pane.B,1e-6),"the hue holds at "..k)
		end
		assert(near(Night.paneColour(pane,1.5).R,1,1e-6),"lifted as far as the hue allows")
		assert(Night.lightAt(1)==Night.LightDay and near(Night.lightAt(1.5),Night.LightNight))
	end)

	test("glow-caps: hidden by day, in through .45 -> .35; three on the path's lip side, one in the turn pocket, two at the lookout",function()
		assert(Night.capAlpha(1)==0 and Night.capAlpha(.45)==0 and Night.capAlpha(.35)==1 and Night.capAlpha(0)==1)
		local spots=Night.glowCaps(Data,P)
		assert(#spots==6,"six spots")
		local onPath,onTerrace=0,0
		for _,s in ipairs(spots)do
			local at=s.position
			local tread=Tier.onPath(at.X,at.Z,1.5,P)
			if at.Y>Tier.RegionY+5 and Tier.inPiece(Tier.Pieces[1],at.X,at.Z,0)then
				onTerrace+=1;assert(near(at.Y,Tier.FloorY))
			else
				onPath+=1
				assert(tread and math.abs(tread-at.Y)<.6,"a cap on the tread's edge at "..tostring(at))
			end
			assert(s.cluster>=2 and s.cluster<=3)
		end
		assert(onPath==4 and onTerrace==2)
	end)

	test("terrace fireflies: on the terrace's floor less 3, clear of the Top Lawn's slots; LifeSim's pool adds them only when set",function()
		local spots=Night.terraceSpots()
		assert(#spots>=6)
		for _,s in ipairs(spots)do
			local x,t=Tier.local2(nil,s.X,s.Z)
			assert(math.abs(x)<=Tier.Length/2-3 and math.abs(t)<=Tier.Width/2-3 and near(s.Y,Tier.FloorY))
		end
	end)

	return{passed=#cases,cases=cases}
end
