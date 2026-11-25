-- Garden Dash across versions (V3-DASH-BUILD-PLAN-2026-11-22, S6). Offline only (scripts/run_dash_server_specs.py), where
-- `offline` holds three trees: new (this one), base (the commit the slice starts from) and live (the published
-- build). Off-parity byte for byte as JSON, and the live build loads a new save and back.
return function(_,offline)
	local new,base,live,encode=offline.new,offline.base,offline.live,offline.encode
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
	local function open(tree,db,c)
		local H=tree.require(tree.server.HatchProgress)
		local adapter={now=function()return c.now end,guid=function()c.serial+=1;return "op"..c.serial end,random=function()return .37 end,wait=function()end,
			update=function(key,transform)local value=transform(copy(db[key]));if value then db[key]=copy(value)end;return copy(value)end}
		return H.load(1,{rank=1},adapter),H
	end
	local function dashOn(on)local Dash=new.require(new.shared.Dash);Dash.inject(if on then{flags={GardenDash=true},studio=true}else nil)end
	local RACE={kind="race",mode="fun",place=2,us=35000000,inputs=9,seed=1,prize=true}
	local function play(tree)
		local db,c,out={},{now=1700000000,serial=0},{}
		local h,H=open(tree,db,c)
		local function note(...)table.insert(out,encode({...}));table.insert(out,encode(H.public(h)));table.insert(out,encode(db))end
		note(h.status)
		for day=1,3 do
			note(H.award(h,h.nextRunSeq,8,{family="pip",day=tostring(19680+day),success=true,clean=false,score=900,chain=4,clears=2,drops=24}))
			h.nextRunSeq+=1
			note(H.command(h,"daily",nil,h.state.revision));note(H.parkPlay(h,"park"..day,4,"pip",1));note(H.coachMark(h,day))
			note(H.command(h,"hatch","meadow",h.state.revision));note(H.command(h,"ack",nil,h.state.revision))
			note(H.statEggBuy(h,"egg"..day,"pip",true,""));note(H.renew(h))
			c.now+=86400;db.player_1.hatching.lease.expiresAt=c.now+60
		end
		note(H.release(h))
		return out
	end
	test("off: every reply, snapshot and save of a three-day script is the base build's, byte for byte",function()
		dashOn(false)
		local a,b=play(base),play(new);assert(#a==#b and #a>60)
		for i=1,#a do assert(a[i]==b[i],"step "..i.."\n"..a[i].."\n"..b[i])end
	end)
	test("on, nobody racing: saves are still the base build's byte for byte; snapshots add only the dash block",function()
		dashOn(true);local b=play(new);dashOn(false);local a=play(base)
		assert(#a==#b)
		local blocks=0
		for i=1,#a do
			local stripped,n=string.gsub(b[i],'"dash":{.-"weekRibbons":%d+},',"");blocks+=n
			assert(a[i]==stripped,"step "..i.."\n"..a[i].."\n"..stripped)
		end
		assert(blocks>20)
	end)
	test("off: twelve pets in and around both parks for five minutes: every garden snapshot is the base build's",function()
		local function garden(tree)
			local Garden=tree.require(tree.server.GardenState);local Park=tree.require(tree.server.ParkDirector);local Layout=tree.require(tree.shared.ParkLayout)
			local now,seed,out,inputs=1000,9,{},{}
			local function at(id,t)
				local centre=if id%3==0 then Vector3.new(60,0,20)else Layout.Sites[id%#Layout.Sites+1].Center
				local x,z=centre.X+math.sin(id+t*.05)*6,centre.Z+math.cos(id*2+t*.03)*5
				return Vector3.new(x,Layout.ground(x,z),z)
			end
			for id=1,12 do inputs[id]={petId="pip",owned=true,alive=true,characterId=1,petGeneration=0,mode="Room",yaw=0,charmVisible=id%2==0}end
			local g=Garden.new({sharedToyEnabled=false,now=function()return now end,publish=function(s)table.insert(out,encode(s))end,validFocus=function()return true end})
			Park.attach(g,{enabled=true,random=function()seed=(seed*1103515245+12345)%2147483648;return seed/2147483648 end,finished=function()end})
			for step=1,600 do
				now+=.5
				for id,input in pairs(inputs)do
					input.anchor=at(id,now);input.position=input.anchor+Vector3.new(0,3,0)
					input.mode=if id==5 and step%120<20 then "Board"else "Room";input.alive=not(id==6 and step%200<6)
				end
				g:step(.5,table.clone(inputs))
				if step%40==0 then g:focus(2,{kind="focus",seq=step,petId="pip"})end
			end
			return out
		end
		-- The Hollow (ParkLayout, WORLD-ALIVE-LOOK 2) is a beta-or-Studio place gate and the mocks answer IsStudio true:
		-- this build is compared as a live server loads it, with the old grove (a fresh tree, ParkLayout required off Studio).
		local liveNew=offline.fresh("new")
		local RunService=offline.services.RunService;local studio=RunService.IsStudio
		RunService.IsStudio=function()return false end
		local ok,Layout=pcall(liveNew.require,liveNew.shared.ParkLayout)
		RunService.IsStudio=studio
		assert(ok and not Layout.HollowOn,"ParkLayout off Studio keeps the old grove")
		local a,b=garden(base),garden(liveNew);assert(#a==#b and #a>400)
		for i=1,#a do assert(a[i]==b[i],"snapshot "..i)end
	end)
	test("a save with races in it: the live build loads it, plays, keeps the field exactly, and this build carries on",function()
		dashOn(true);local db,c={},{now=1700000000,serial=0}
		local h,H=open(new,db,c);for i=1,3 do assert(H.dashResults(h,"f"..i,{RACE,{kind="trial",mode="trial",place=1,us=31000000,inputs=9,seed=2,prize=true}}))end
		assert(H.release(h));c.now+=1
		local field=encode(db.player_1.hatching.dash);local wallet=db.player_1.hatching.nectar
		local old,L=open(live,db,c);assert(old.status=="Ready"and old.state.nectar==wallet,old.status)
		assert(L.valid(old.state)and L.parkPlay(old,"p",1,"pip")and L.public(old).dash==nil and encode(db.player_1.hatching.dash)==field)
		assert(L.award(old,old.nextRunSeq,6,nil)and L.renew(old)and L.release(old)and encode(db.player_1.hatching.dash)==field);c.now+=1
		h,H=open(new,db,c);assert(h.status=="Ready"and H.public(h).dash.paid==3 and select(2,H.dashResults(h,"f3",{RACE}))=="AlreadySaved")
		wallet=h.state.nectar;for i=4,9 do assert(H.dashResults(h,"f"..i,{RACE}))end;assert(h.state.nectar==wallet+4 and h.state.dash.ribbons.silver==9)
		dashOn(false)
	end)
	test("1, 2, 3 and 8 worst-case results: the live build's own validity check passes and it loads, plays and keeps them",function()
		dashOn(true)
		for _,n in ipairs({1,2,3,8})do
			local db,c={},{now=1700000000,serial=0}
			local h,H=open(new,db,c);local list={}
			for i=1,n do list[i]={kind="race",mode="stats",band=5,place=8,us=120000000,inputs=1000000,seed=4294967295,prize=true}end
			assert(H.dashResults(h,"dash-"..string.rep("f",36),list))
			local L=live.require(live.server.HatchProgress);assert(L.valid(db.player_1.hatching),n.." results")
			H.release(h);c.now+=1
			local field=encode(db.player_1.hatching.dash);local old=open(live,db,c)
			assert(old.status=="Ready"and L.parkPlay(old,"p",1,"pip")and L.release(old)and encode(db.player_1.hatching.dash)==field);c.now+=1
			h=open(new,db,c);assert(h.status=="Ready"and h.state.dash.ribbons.green==n)
		end
		dashOn(false)
	end)
	test("a malformed field loads in both builds and never costs anything else in the save",function()
		for _,bad in ipairs({"x",7,true,{},{day=1,paid={}},{ribbons="x",op=5}})do
			dashOn(true);local db,c={},{now=1700000000,serial=0}
			local h,H=open(new,db,c);H.release(h);db.player_1.hatching.dash=bad;c.now+=1
			local old,L=open(live,db,c);assert(old.status=="Ready"and L.parkPlay(old,"p",1,"pip")and L.release(old)and encode(db.player_1.hatching.dash)==encode(bad));c.now+=1
			h,H=open(new,db,c);local wallet=h.state.nectar;assert(h.status=="Ready"and H.public(h).dash.paid==5 and H.dashResults(h,"f",{RACE})and h.state.nectar==wallet)
			H.release(h);c.now+=1;old=open(live,db,c);assert(old.status=="Ready")
		end
		dashOn(false)
	end)
	return{passed=#cases,cases=cases}
end
