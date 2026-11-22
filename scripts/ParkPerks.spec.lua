-- Garden perks (ParkPerks; V3-LEVELS-BUILD-PLAN-2026-11-22 S1) and the longer throw (ParkFetch): looks
-- from public levels; the throw is the server's, from saved Speed, 5 studs with a fall back to 4 on any
-- failed preflight; off, or with no host seam, is exactly the 4 stud throw.
-- Real director and fetch modules with fake owners and an injected clock.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.ParkPerks)(ServerScriptService.Server)
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Perks=require(Shared.ParkPerks)
	local Levels=require(Shared.Levels)
	local Stats=require(Shared.StatCatalog)
	local Park=require(Shared.ParkLayout)
	local Garden=require(server.GardenState)
	local Director=require(server.ParkDirector)
	local Fetch=require(server.ParkFetch)
	local A=require(Shared.GardenActivity)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local ALL={track=true,gates=true,medals=true,juice=true}
	local function track(on)Levels.inject({flags={LevelsMatter=on==true},studio=true,shipped=ALL})end
	local function keys(t)local out={};for k in pairs(t)do table.insert(out,k)end;table.sort(out);return table.concat(out," ")end
	local function fixture(count,speed)
		local c={now=1000,inputs={}}
		for id=1,count do
			local at=Park.Center+Vector3.new((id-1)*.4,0,0)
			c.inputs[id]={petId="pip",owned=true,alive=true,characterId=1,petGeneration=0,mode="Room",anchor=at,position=at+Vector3.new(0,3,0),yaw=0}
		end
		c.garden=Garden.new({now=function()return c.now end,sharedToyEnabled=false})
		c.garden:sync(c.inputs)
		local options={enabled=true,random=function()return .1 end}
		if speed~=nil then options.speedLevel=if type(speed)=="function"then speed else function()return speed end end
		c.director=Director.attach(c.garden,options)
		for _,site in pairs(c.director.sites)do site.nextGreetAt=math.huge end
		local ordered={};for _,actor in pairs(c.garden.actors)do table.insert(ordered,actor)end
		c.director:schedule(c.now,ordered)
		for _,actor in pairs(c.garden.actors)do actor.park.nextPickAt=0 end
		return c
	end
	local function flat(a,b)return Vector2.new(a.X-b.X,a.Z-b.Z).Magnitude end
	-- How far the ball of owner 1's throw lands from the park centre.
	local function thrown(c)
		local done,why=c.director:throw(1);assert(done,tostring(why))
		local s=c.director.fetch.session
		assert(flat(s.home,Park.Center)<.001)
		return flat(s.landing,s.home),s
	end
	local function near(a,b)return math.abs(a-b)<.001 end
	local ok,problem=pcall(function()
		test("rows: six perks at scope 2.1's levels; only Jump and Speed; frozen",function()
			local want={swingCheer="jump5",swingHigh="jump10",slideSpin="jump20",seesawHop="jump40",longThrow="speed5",catchHop="speed20"}
			local n=0
			for _,row in ipairs(Perks.Rows)do n+=1;assert(want[row.id]==row.stat..row.level and table.isfrozen(row),row.id)end
			assert(n==6 and Perks.Reach.normal==4 and Perks.Reach.long==5)
		end)
		test("forLevels and fromPublic: exactly at the level; malformed reads nothing; off reads nothing",function()
			track(true)
			assert(keys(Perks.forLevels({jump=4,speed=4}))==""and keys(Perks.forLevels({jump=5}))=="swingCheer"and keys(Perks.forLevels({jump=20,speed=5}))=="longThrow slideSpin swingCheer swingHigh")
			assert(keys(Perks.forLevels({jump=99,speed=99}))=="catchHop longThrow seesawHop slideSpin swingCheer swingHigh"and keys(Perks.forLevels({heart=99}))=="")
			for _,odd in ipairs({"99",0/0,math.huge,100,-1,5.5})do assert(keys(Perks.forLevels({jump=odd,speed=odd}))=="")end
			assert(keys(Perks.forLevels(nil))==""and keys(Perks.forLevels("x"))=="")
			local public={v=1,pets={pip={levels={jump=10},total=20},blip="x"}}
			assert(keys(Perks.fromPublic(public,"pip"))=="swingCheer swingHigh"and keys(Perks.fromPublic(public,"blip"))==""and keys(Perks.fromPublic(public,"nope"))==""and keys(Perks.fromPublic(nil,"pip"))=="")
			assert(Perks.throwReach(5)==5 and Perks.throwReach(4)==4 and Perks.throwReach(nil)==4 and Perks.throwReach("9")==4)
			track(false)
			assert(keys(Perks.forLevels({jump=99,speed=99}))==""and keys(Perks.fromPublic(public,"pip"))==""and Perks.throwReach(99)==4)
		end)
		test("the longer throw: saved Speed 5 lands at 5 studs along the same lane; the thrower's level only",function()
			track(true)
			local c=fixture(1,5);local far,s=thrown(c);assert(near(far,5),far)
			local plain=fixture(1);local four,p=thrown(plain);assert(near(four,4))
			local a,b=(s.landing-s.home),(p.landing-p.home)
			assert(near(a.X/5,b.X/4)and near(a.Z/5,b.Z/4),"same direction")
			assert(Park.inside(s.landing,-2)and Park.clearOfKeepout(s.landing,1))
			c=fixture(1,4);assert(near(thrown(c),4))
			c=fixture(2,function(id)return if id==2 then 99 else 1 end);assert(near(thrown(c),4),"another pet's Speed does not count")
			c=fixture(3,20);far=thrown(c);assert(near(far,5),"three pets")
			-- It still finishes, once, like any fetch.
			for _=1,40 do c.now+=.5;for _,site in pairs(c.director.sites)do site.fetch:step(c.now)end end
			assert(c.director.fetch.session==nil)
		end)
		test("off, no seam, a throwing seam or a malformed level: the plain 4 stud throw",function()
			track(false);local c=fixture(1,99);assert(near(thrown(c),4),"off")
			track(true)
			c=fixture(1);assert(near(thrown(c),4),"no seam")
			c=fixture(1,function()error("save not loaded")end);assert(near(thrown(c),4))
			for _,odd in ipairs({"99",0/0,-1,100,math.huge})do c=fixture(1,odd);assert(near(thrown(c),4),tostring(odd))end
			c=fixture(1,function()return nil end);assert(near(thrown(c),4))
		end)
		test("any failed preflight at 5 falls back to 4: lane, landing spot, beside spot, path",function()
			track(true)
			local function layout(c,overrides)c.director.fetch.layout=setmetatable(overrides,{__index=c.director.fetch.layout})end
			local function past(limit)return function(point)return flat(point,Park.Center)>limit end end
			-- the lane or its end is not clear past 4.5 studs
			local c=fixture(1,99);local beyond=past(4.5)
			layout(c,{clearOfKeepout=function(p,r)return not beyond(p)and Park.clearOfKeepout(p,r)end});assert(near(thrown(c),4),"lane")
			c=fixture(1,99);layout(c,{inside=function(p,inset)return not(inset==-2 and beyond(p))and Park.inside(p,inset)end});assert(near(thrown(c),4),"outside the kerb")
			-- only the beside spots (5.08 studs out) are blocked
			c=fixture(3,99);local beside=past(5.02)
			layout(c,{clearOfKeepout=function(p,r)return not beside(p)and Park.clearOfKeepout(p,r)end});assert(near(thrown(c),4),"beside spot")
			-- no path to 5
			local function pathTo(limit)local far=past(limit);return function(from,target,...)if far(target)then return {},0 end;return A.plan(from,target,...)end end
			c=fixture(1,99);c.garden.options.planPath=pathTo(4.5);assert(near(thrown(c),4),"path")
			c=fixture(3,99);c.garden.options.planPath=pathTo(5.02);assert(near(thrown(c),4),"a path to a beside spot")
			-- one of three pets cannot reach 5: everyone plays at 4
			c=fixture(3,99);local calls=0
			c.garden.options.planPath=function(from,target,...)
				if flat(target,Park.Center)>4.5 then calls+=1;if calls==2 then return {},0 end end
				return A.plan(from,target,...)
			end
			local far,s=thrown(c);assert(near(far,4)and #s.owners==3,"strict at 5")
			-- and when 4 fails too the reason is today's, with nothing reserved
			c=fixture(1,99);c.garden.options.planPath=function()return {},0 end
			local done,why=c.director:throw(1);assert(not done and why=="NoIdlePets"and c.director.fetch.session==nil)
			for _,actor in pairs(c.garden.actors)do assert(actor.park.fetchId==nil)end
			c=fixture(1,99);layout(c,{clearOfKeepout=function()return false end})
			done,why=c.director:throw(1);assert(not done and why=="NoLane")
			assert(Fetch.Reach==4)
		end)
		test("the host seam reads the save: a Speed XP becomes the level the throw uses",function()
			track(true)
			local S=require(server.StatState)
			local state={inventoryMask=require(Shared.EggCatalog).bit("pip"),petStats={pip={speed=Stats.xpFor(5)}}}
			local c=fixture(1,function()return Stats.levelFor(S.xp(state,"pip","speed"))end);assert(near(thrown(c),5))
			state.petStats.pip.speed-=1
			c=fixture(1,function()return Stats.levelFor(S.xp(state,"pip","speed"))end);assert(near(thrown(c),4))
		end)
	end)
	Levels.inject(nil)
	assert(ok,problem)
	return{passed=#cases,cases=cases}
end
