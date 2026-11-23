-- The Sleepy Nest's pure contract (ONBOARDING-V3-PLAN-2026-11-23 section 2, architect review): constants, the welcome-week
-- gift table, fail-closed counts, and the clock helpers (min(elapsed, 8 h) clamped at 0, server time only).
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.Nest)(ServerScriptService.Server)
return function(_server)
	local Nest=require(game:GetService("ReplicatedStorage").Shared.Nest)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local H=3600

	test("constants: 8 hours, a week of seven eggs, 4 Stars after",function()
		assert(Nest.Hours==8 and Nest.Seconds==8*H and Nest.WeekLength==7 and Nest.AfterWeekStars==4)
		assert(Nest.OwnedCap==20 and Nest.ToyOwnedStars==20 and Nest.FutureSlack==86400 and Nest.Charm=="nest")
	end)
	test("the welcome week: seven fixed gifts, 100 Stars face value, then 4-Star eggs forever",function()
		local kinds,total={},0
		for i,row in ipairs(Nest.Gifts)do table.insert(kinds,row.kind);total+=row.stars;assert(Nest.gift(i-1)==row,"egg "..i)end
		assert(#Nest.Gifts==Nest.WeekLength and table.concat(kinds,",")=="hat,stars,toy,stars,neck,stars,charm")
		assert(total==100,"100 Stars once per save")
		assert(Nest.Gifts[1].perPet and Nest.Gifts[5].perPet and not Nest.Gifts[3].perPet,"hat and neck are per pet")
		assert(Nest.Gifts[7].item==Nest.Charm and Nest.Gifts[7].stars==25)
		for _,n in ipairs({7,8,50,10^6})do local row=Nest.gift(n);assert(row.kind=="stars"and row.stars==4,"after the week: "..n)end
		assert(table.isfrozen(Nest.Gifts)and table.isfrozen(Nest.Gifts[1])and table.isfrozen(Nest.AfterWeek))
	end)
	test("a bad count fails closed: it reads as week done (no week gifts, no charm farming)",function()
		for _,bad in ipairs({-1,1.5,0/0,math.huge,"3",{},true})do
			assert(Nest.count(bad)==7 and Nest.gift(bad)==Nest.AfterWeek and Nest.weekDone(bad),tostring(bad))
		end
		assert(Nest.count(nil)==7,"missing n on a stored entry reads as done too; a fresh nest starts at 0 explicitly")
		assert(Nest.count(0)==0 and Nest.count(6)==6 and not Nest.weekDone(6)and Nest.weekDone(7))
		assert(not Nest.charm(6)and Nest.charm(7)and Nest.charm(30),"the Nest Charm is earned at n >= 7")
	end)
	test("ready and left: min(elapsed, 8 h), clamped at 0; ready exactly at 8 h, never before",function()
		local at=1700000000
		local e={at=at}
		assert(not Nest.ready(e,at)and Nest.left(e,at)==8*H,"just landed")
		assert(not Nest.ready(e,at+8*H-1)and Nest.left(e,at+8*H-1)==1)
		assert(Nest.ready(e,at+8*H)and Nest.left(e,at+8*H)==0,"ready at 8 h")
		assert(Nest.ready(e,at+30*86400)and Nest.left(e,at+30*86400)==0,"it waits, fully grown, as long as it takes")
		assert(not Nest.ready(e,at-600)and Nest.left(e,at-600)==8*H,"a slightly future at (another server's clock) is just landed")
		assert(Nest.grown(e,at+H)==H and Nest.grown(e,at-5)==0 and Nest.grown(e,at+9*H)==8*H)
	end)
	test("no usable egg: never ready, no time left (nil); more than a day ahead is malformed",function()
		local now=1700000000
		for _,bad in ipairs({nil,{},{at="1"},{at=0/0},{at=math.huge},{at=-math.huge},{at=now+86401},5})do
			assert(not Nest.ready(bad,now)and Nest.left(bad,now)==nil and Nest.look(bad,now)==nil and not Nest.sane(bad,now))
		end
		assert(Nest.sane({at=now+86400},now)and not Nest.ready({at=now},0/0)and Nest.left({at=now},"x")==nil)
	end)
	test("the three looks by time grown, then ready",function()
		local e={at=0}
		assert(Nest.look(e,0)=="small"and Nest.look(e,8*H/3-1)=="small")
		assert(Nest.look(e,8*H/3)=="glow"and Nest.look(e,16*H/3-1)=="glow")
		assert(Nest.look(e,16*H/3)=="rocking"and Nest.look(e,8*H-1)=="rocking")
		assert(Nest.look(e,8*H)=="ready"and Nest.progress(e,4*H)==.5 and Nest.progress(e,99*H)==1)
	end)
	test("countdown: hours above one hour, then minutes, rounded up; never 0 before ready",function()
		local function is(left,kind,value)local k,v=Nest.countdown(left);assert(k==kind and v==value,tostring(left).." "..tostring(k).." "..tostring(v))end
		is(8*H,"hours",8);is(7*H+1,"hours",8);is(7*H,"hours",7);is(H+1,"hours",2)
		is(H,"minutes",60);is(40*60,"minutes",40);is(61,"minutes",2);is(1,"minutes",1);is(.2,"minutes",1)
		is(0,"ready",nil);is(-5,"ready",nil);is(nil,"ready",nil);is(0/0,"ready",nil)
	end)
	test("the public shape names every field the builders read",function()
		for _,field in ipairs({"at","readyAt","left","ready","n","egg","week","gift","tucked","pet"})do assert(Nest.PublicShape[field],field)end
		assert(table.isfrozen(Nest)and table.isfrozen(Nest.PublicShape))
	end)
	return{passed=#cases,cases=cases}
end
