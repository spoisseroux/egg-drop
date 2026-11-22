-- Garden Dash and the garden (V3-DASH-BUILD-PLAN-2026-11-22, S6): a racing pet leaves the parks and greetings, refuses
-- focus, care and hello, stays put, survives a respawn, and is a normal pet again the moment the race lets it go.
-- Isolated GardenState + ParkDirector with fake owners; no Players, remotes or saves.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.DashGating)(ServerScriptService.Server)
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Garden=require(server.GardenState)
	local Park=require(server.ParkDirector)
	local Care=require(server.GardenCare)
	local CareHost=require(server.GardenCareHost)
	local Hello=require(server.PetHello)
	local Rules=require(Shared.PetHelloRules)
	local Layout=require(Shared.ParkLayout)
	local Contact=require(server.PetContact)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function fixture(count,inPark)
		local c={now=1000,inputs={},seed=7}
		for id=1,count do
			local x,z=if inPark then Layout.Center.X+id*.8-2 else 40+id*2,if inPark then Layout.Center.Z else 10
			local y=Layout.ground and Layout.ground(x,z)or 4
			c.inputs[id]={petId="pip",owned=true,alive=true,characterId=1,petGeneration=0,mode="Room",yaw=0,charmVisible=true,
				anchor=Vector3.new(x,y,z),position=Vector3.new(x,y+3,z),carryPosition=Vector3.new(x,y+3,z)}
		end
		c.garden=Garden.new({sharedToyEnabled=false,now=function()return c.now end,publish=function(snapshot)c.snapshot=snapshot end,validFocus=function()return true end})
		Park.attach(c.garden,{enabled=true,random=function()c.seed=(c.seed*1103515245+12345)%2147483648;return c.seed/2147483648 end,finished=function()end})
		function c:step(seconds)for _=1,math.floor(seconds*2+.5)do self.now+=.5;self.garden:step(.5,table.clone(self.inputs))end end
		c:step(.5)
		return c
	end
	local function focus(c,seq)return c.garden:focus(1,{kind="focus",seq=seq,petId="pip",characterId=1,petGeneration=0})end
	test("a tagged pet stands still: no follow, wander or recall, even when its owner walks off; its snapshot says so",function()
		local c=fixture(1);c.garden:setRacer(1,"race-1");local actor=c.garden.actors[1];local at=c.garden:position(actor,c.now)
		c.inputs[1].position+=Vector3.new(30,0,0);c.inputs[1].anchor+=Vector3.new(30,0,0);c:step(20)
		assert(c.garden:position(actor,c.now)==at and actor.action=="dash"and c.snapshot.actors["1"].dash=="race-1")
		c.garden:setRacer(1,nil);assert(actor.dash==nil and actor.behavior=="follow"and c.garden.racers[1]==nil)
		c:step(30);assert((c.garden:position(actor,c.now)-c.inputs[1].anchor).Magnitude<6 and c.snapshot.actors["1"].dash==nil)
	end)
	test("it frees its park slot and membership at once, never rejoins while racing, and plays again after",function()
		local c=fixture(3,true);local playing=false
		for _=1,80 do c:step(.5);local p=c.garden.actors[1].park;if p and p.session then playing=true;break end end
		assert(playing,"no park session to leave")
		c.garden:setRacer(1,"r");assert(c.garden.actors[1].park==nil)
		for _=1,60 do c:step(.5);local a=c.garden.actors[1];assert(a.park==nil and a.pairId==nil and a.action=="dash")end
		for _,session in pairs(c.garden.park.sessions)do assert(not table.find(session.ownerIds,1))end
		local busy=false;for _=1,60 do c:step(.5);local p=c.garden.actors[2].park;if p and p.session then busy=true end end
		assert(busy,"the others keep playing")
		c.garden:setRacer(1,nil);c:step(2);assert(c.garden.actors[1].park)
	end)
	test("greetings skip it, and a greeting it was in ends for both",function()
		local c=fixture(2);c:step(1);local greeted=c.garden:greetPair(c.garden.actors[1],c.garden.actors[2],c.now);assert(greeted)
		c.garden:setRacer(1,"r");assert(c.garden.actors[1].pairId==nil and c.garden.actors[2].pairId==nil)
		for _=1,60 do c:step(.5);assert(c.garden.actors[1].pairId==nil and c.garden.actors[2].pairId==nil)end
	end)
	test("focus, care and hello refuse it; the same requests work before and after",function()
		local c=fixture(1);local garden=c.garden
		local care=Care.new(garden,{now=function()return c.now end,place=function()return c.inputs[1].anchor end,result=function()end});garden.care=care
		local seq=0
		local function pickup()seq+=1;local a=garden.actors[1];return care:request(1,{kind="carePickup",seq=seq,petId="pip",characterId=1,petGeneration=0,actorGeneration=a.generation})end
		garden:setRacer(1,"r");c.now+=1
		assert(not focus(c,1));local r=pickup();assert(r and r.status=="Rejected"and r.reason=="Racing",r and tostring(r.reason))
		assert(not Rules.free(garden.actors[1],c.now+10))
		garden:setRacer(1,nil);c:step(5);assert(Rules.free(garden.actors[1],c.now+10)and focus(c,2));garden:reset(garden.actors[1],c.inputs[1])
		c.now+=1;r=pickup();assert(r and r.status=="Accepted",r and tostring(r.reason))
	end)
	test("a hello that was running is withdrawn when the race takes the pet",function()
		local c=fixture(1);c:step(5);local published={}
		local hello=Hello.new({now=function()return c.now end,garden=c.garden,viewer=function()return c.garden:position(c.garden.actors[1],c.now)end,
			publish=function(id,value)published[id]=value or "cancelled"end})
		local a=c.garden.actors[1]
		local packet=nil
		hello.active[1]={id=1,from=2,at=c.now,petId=a.petId,petGeneration=a.petGeneration,characterId=a.characterId,generation=a.generation}
		hello:step();assert(hello.active[1]);c.garden:setRacer(1,"r");hello:step();assert(hello.active[1]==nil and published[1]=="cancelled"and packet==nil)
	end)
	test("a respawn keeps the seat: the new actor is born tagged and never decides a thing",function()
		local c=fixture(2,true);c.garden:setRacer(1,"r");c.inputs[1].alive=false;c:step(.5);assert(c.garden.actors[1]==nil)
		c.inputs[1].alive=true;c.inputs[1].characterId=2;c:step(.5)
		local a=c.garden.actors[1];assert(a.dash=="r"and a.park==nil);c:step(10);assert(a.park==nil)
		c.garden:setRacer(1,nil);assert(a.dash==nil)
	end)
	test("leaving, or a tag for somebody with no pet out, is harmless",function()
		local c=fixture(1);c.garden:setRacer(9,"r");c.garden:setRacer(9,nil);c.garden:setRacer(1,"r");local input=c.inputs[1];c.garden:remove(1);assert(c.garden.racers[1]==nil,"a tag never outlives its player");c.inputs[1]=input
		c:step(2);assert(c.garden.actors[1].dash==nil)
	end)
	test("the Deck is never blocked: the pet goes to the board rest as always once the host lets it go",function()
		local c=fixture(1);c.garden:setRacer(1,"r");c.inputs[1].mode="Board";c:step(.5);c.garden:setRacer(1,nil);c:step(1)
		assert(c.garden.actors[1].mode=="Board"and c.garden.actors[1].behavior=="rest")
	end)
	test("switching companion is refused while racing only",function()
		local host=setmetatable({d={garden={actors={}},canProgress=function()return true end,inventory=function()return 0 end}},CareHost)
		local board={mode="Room",profile={},nursery={state={}},dashHeld=true}
		local ok,why=host:switch(board,"pip");assert(not ok and why=="Racing");board.dashHeld=nil
		ok,why=host:switch(board,"pip");assert(not ok and why=="NotOwned")
	end)
	test("a pet being stroked is let go: the contact sees the conflict",function()
		local state={mode="Room",closing=false,conflict=true,alive=true,owned=true}
		assert(not Contact.valid(setmetatable({},Contact),{petId="pip"},state))
	end)
	return{passed=#cases,cases=cases}
end
