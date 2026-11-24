-- World feel (beta 14 QA W4; Shared.WorldFeel, WorldFeelClient, GardenHour.hazed): off writes nothing and the arrival
-- camera, zoom, walk speed and Atmosphere are as before; on, Fable's numbers; a locked humanoid is never unlocked.
-- Offline (scripts/run_dash_server_specs.py); fake player, StarterPlayer and humanoid.
-- Usage (Client): require(PlayerScripts.Client.ZZSpecs.WorldFeel)(PlayerScripts.Client)
return function(client)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Feel=require(Shared.WorldFeel)
	local Hour=require(Shared.GardenHour)
	local Client=require(client.WorldFeelClient)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local OFF={flags={WorldFeel=false},studio=true}
	local ON={flags={WorldFeel=true},studio=true}

	test("the numbers: about 17 degrees down at arrival (was about 25), zoom 22, walk 14 and never under 13, haze .05",function()
		local function pitch(v)return math.deg(math.atan2(v.Y,math.sqrt(v.X*v.X+v.Z*v.Z)))end
		assert(math.abs(pitch(Feel.Arrival)-16.6)<.2 and math.abs(pitch(Feel.ArrivalOff)-24.8)<.2)
		assert(Feel.MaxZoom==22 and Feel.Walk==14 and Feel.Walk>=Feel.WalkFloor and Feel.Haze==.05)
	end)
	test("off (live, or the flag off): the arrival offset and haze as before, nothing mounts",function()
		Feel.inject(OFF)
		assert(not Feel.on("feel")and not Feel.on("walk")and Feel.arrival()==Vector3.new(5,6,12)and Feel.haze()==0)
		assert(Client.mount({player={},starter={},step=false})==nil)
		Feel.inject({flags={WorldFeel=true},studio=false,place=96451847774961});assert(not Feel.on("feel"),"the live place")
		Feel.inject({flags={WorldFeel=true},studio=false,place=107705084891479});assert(Feel.on("feel"),"the beta place")
		Feel.inject(nil)
	end)
	test("on: the arrival offset and the haze; feel off alone keeps the walk test, and the other way round",function()
		Feel.inject(ON);assert(Feel.arrival()==Feel.Arrival and Feel.haze()==.05)
		Feel.inject({flags={WorldFeel=true},studio=true,feel=false});assert(Feel.arrival()==Feel.ArrivalOff and Feel.on("walk"))
		Feel.inject({flags={WorldFeel=true},studio=true,walk=false});assert(Feel.on("feel")and not Feel.on("walk"))
		Feel.inject(nil)
	end)
	test("the walk speed: written on a fresh character; a locked humanoid (0) is never touched; off puts back only its own",function()
		assert(Client.walkTarget(16,true,nil,16,true)==14 and Client.walkTarget(14,true,14,16,false)==nil)
		assert(Client.walkTarget(0,true,nil,16,true)==nil and Client.walkTarget(0,false,14,16,false)==nil,"locked")
		assert(Client.walkTarget(20,true,14,16,false)==nil,"another code's speed is left alone")
		assert(Client.walkTarget(14,false,14,16,false)==16 and Client.walkTarget(16,false,nil,16,false)==nil,"off: only what it gave")
		assert(Client.zoomTarget(128,true,128,false)==22 and Client.zoomTarget(22,true,128,true)==nil and Client.zoomTarget(10,true,10,false)==nil)
		assert(Client.zoomTarget(22,false,128,true)==128 and Client.zoomTarget(128,false,128,false)==nil)
	end)
	test("mounted: switches on write the cap and the speed; off again puts back the place's; never on writes nothing",function()
		local writes=0
		local function watched(t)
			return setmetatable({},{__index=t,__newindex=function(_,k,v)writes+=1;t[k]=v end})
		end
		local humanoid=watched({WalkSpeed=16})
		local character={FindFirstChildOfClass=function()return humanoid end}
		local player=watched({CameraMaxZoomDistance=128,Character=character})
		local starter={CameraMaxZoomDistance=128,CharacterWalkSpeed=16}
		Feel.inject({flags={WorldFeel=true},studio=true,feel=false,walk=false})
		local feel=Client.mount({player=player,starter=starter,step=false})
		assert(feel and writes==0,"both off: nothing written")
		Feel.inject(ON);feel:apply(false)
		assert(player.CameraMaxZoomDistance==22 and humanoid.WalkSpeed==14)
		humanoid.WalkSpeed=0;Feel.inject({flags={WorldFeel=true},studio=true,walk=false});feel:apply(false)
		assert(humanoid.WalkSpeed==0,"a lock is never lifted")
		humanoid.WalkSpeed=14;feel:apply(false);assert(humanoid.WalkSpeed==16,"off: the place's speed back")
		Feel.inject({flags={WorldFeel=true},studio=true,feel=false,walk=false});feel:apply(false)
		assert(player.CameraMaxZoomDistance==128)
		-- Code review: the walk test switched off while a lock (PetFocusUI) holds 0; the lock lets go and writes back the
		-- 14 it saved; the WalkSpeed watcher puts the place's speed back.
		Feel.inject(ON);humanoid.WalkSpeed=16;feel:apply(true);assert(humanoid.WalkSpeed==14)
		humanoid.WalkSpeed=0;Feel.inject({flags={WorldFeel=true},studio=true,walk=false});feel:apply(false);assert(humanoid.WalkSpeed==0)
		humanoid.WalkSpeed=14;feel:walk(humanoid,false);assert(humanoid.WalkSpeed==16,"the default, not the held 14")
		Feel.inject(nil)
	end)
	test("the haze: GardenHour.hazed adds to a copy; 0 is the very same look (a frozen hold stays as it is)",function()
		local hold=Hour.look(nil)
		assert(Hour.hazed(hold,0)==hold and Hour.hazed(hold,nil)==hold)
		local hazed=Hour.hazed(hold,.05)
		assert(hazed~=hold and math.abs(hazed.Atmosphere.Density-hold.Atmosphere.Density-.05)<1e-9 and hazed.Lighting==hold.Lighting)
	end)
	return{passed=#cases,cases=cases}
end
