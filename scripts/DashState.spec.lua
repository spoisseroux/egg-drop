-- Garden Dash save field (V3-DASH-BUILD-PLAN-2026-11-22, S6): repair per subfield, fail closed, the daily cap, clock
-- rollback, wallet cap, ribbons, cups, best and title. Pure tables only.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.DashState)(ServerScriptService.Server)
return function(server)
	local S=require(server.DashState)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local DAY="19680"
	local function race(place,more)
		local r={kind="race",mode="fun",place=place or 1,us=35000000,inputs=12,seed=7,prize=true}
		for key,value in pairs(more or {})do r[key]=value end
		return r
	end
	local function trial(us,prize)return{kind="trial",mode="trial",place=1,us=us,inputs=9,seed=3,prize=prize~=false}end
	local function write(state,id,results,day)return S.apply(state,{id=id,results=results},day or DAY)end
	test("a first race: 2 Stars whatever the place, one ribbon, a receipt and the proof",function()
		for place,id in ipairs({"gold","silver","bronze","green","green","green","green","green"})do
			local state={nectar=10}
			assert(write(state,"op"..place,{race(place)})and state.nectar==12 and state.dash.paid==1 and state.dash.day==DAY)
			assert(state.dash.ribbons[id]==1 and state.dash.weekRibbons==1,id)
			assert(S.committed(state,"op"..place)and not S.committed(state,"other"))
			local receipt=S.receipt(state,"op"..place)
			assert(receipt.stars==2 and receipt.balance==12 and receipt.place==place and receipt.seed==7 and S.receipt(state,"other")==nil)
		end
	end)
	test("five races a day are paid, the sixth is a ribbon and 0 Stars; the next day pays again",function()
		local state={nectar=0}
		for i=1,7 do assert(write(state,"a"..i,{race(2)}))end
		assert(state.nectar==10 and state.dash.paid==5 and state.dash.ribbons.silver==7 and S.receipt(state,"a7").stars==0)
		assert(write(state,"b",{race(2)},"19681")and state.nectar==12 and state.dash.paid==1)
		local batch={nectar=0}
		local eight={};for i=1,8 do eight[i]=race(i)end
		assert(write(batch,"c",eight)and batch.nectar==10 and S.receipt(batch,"c").stars==10)
	end)
	test("clock rollback: a later saved day is kept and still counts; it never starts again",function()
		local state={nectar=0,dash={day="19690",paid=4,ribbons={}}}
		for i=1,4 do assert(write(state,"r"..i,{race(1)}))end
		assert(state.nectar==2 and state.dash.day=="19690"and state.dash.paid==5)
	end)
	test("what does not pay: too few inputs, unfinished, too slow, prizes off, a Time Trial",function()
		for _,odd in ipairs({{inputs=2},{us="none"},{us=60000001},{prize=false}})do
			local r=race(1,odd);if odd.us=="none"then r.us=nil end
			local state={nectar=0};assert(write(state,"x",{r})and state.nectar==0 and state.dash.paid==0)
			local ribbon=S.ribbon(r)
			if odd.us=="none"then assert(ribbon=="green","an unfinished seated pet still gets the Finisher ribbon")
			elseif odd.us then assert(ribbon=="gold")
			else assert(ribbon==nil,"no ribbon for idle racers, none with prizes off")end
		end
		local slow=race(1,{us=60000000});local state={nectar=0};assert(write(state,"x",{slow})and state.nectar==2,"exactly 2x Gold still pays")
		local banded=race(1,{mode="stats",band=1,us=68000000});state={nectar=0};assert(write(state,"x",{banded})and state.nectar==2)
		state={nectar=0};assert(write(state,"x",{trial(29000000)})and state.nectar==0 and state.dash.paid==0 and state.dash.cups==7)
	end)
	test("a full wallet pays 0 and stays valid",function()
		local state={nectar=S.Wallet-1};assert(write(state,"x",{race(1)})and state.nectar==S.Wallet-1 and S.receipt(state,"x").stars==0)
	end)
	test("cups OR together once each, best only improves; prizes off still keeps the best",function()
		local state={nectar=0}
		assert(write(state,"1",{trial(34000000)})and state.dash.cups==1 and state.dash.best==34000000)
		assert(write(state,"2",{trial(31000000)})and state.dash.cups==3 and state.dash.best==31000000)
		assert(write(state,"3",{trial(34900000)})and state.dash.cups==3 and state.dash.best==31000000)
		assert(write(state,"4",{trial(29000000,false)})and state.dash.cups==3 and state.dash.best==29000000)
		assert(S.pointless(state,trial(29000000,false))and not S.pointless(state,trial(29000000)),"the gold cup is still owed")
		assert(S.pointless(state,trial(32000000))and S.pointless(state,trial(nil))and S.pointless(state,race(1,{prize=false}))and not S.pointless(state,race(1)))
	end)
	test("the title is derived: five ribbons this week, gone on Monday",function()
		local state={nectar=0}
		for i=1,5 do assert(not S.public(state,DAY).title);assert(write(state,"t"..i,{race(8)}))end
		assert(S.public(state,DAY).title and S.marks(state,DAY).title)
		assert(not S.public(state,"19695").title and S.public(state,"19695").ribbons.green==5)
	end)
	test("malformed fields are repaired one by one and fail closed: a bad day or paid is five paid today",function()
		local bad={false,true,"x",5,0/0,math.huge,{},{1,2},{day=19680,paid=0},{day="19680"},{paid=0},{day="19680",paid=-1},{day="19680",paid=6},{day="019680",paid=0},{day="19680",paid=1.5},{day="19680",paid="0"}}
		for _,value in ipairs(bad)do
			local state={nectar=0,dash=value}
			assert(write(state,"m",{race(1)}),"never refuses a save")
			assert(state.nectar==0 and state.dash.paid==5 and state.dash.ribbons.gold==1)
			assert(write(state,"n",{race(1)},"19681")and state.nectar==2,"it recovers the next day")
		end
		local state={nectar=0,dash={day=DAY,paid=2,week="x",weekRibbons=3,ribbons={gold=-1,silver=4,bronze="x",green=0/0},cups=9,best=0/0,op={},receipt={op="x",stars=99},extra=1}}
		local read=S.read(state)
		assert(read.paid==2 and read.week==nil and read.weekRibbons==0 and read.ribbons.gold==0 and read.ribbons.silver==4 and read.ribbons.bronze==0 and read.ribbons.green==0)
		assert(read.cups==0 and read.best==nil and read.op==nil and read.receipt==nil and read.extra==nil)
		assert(S.read(nil).paid==0 and S.read({}).closed==nil)
		for _,odd in ipairs({1,"x",{},{dash=1}})do S.public(if type(odd)=="table"then odd else {},DAY)end
	end)
	test("results are checked before they are written; nothing malformed is ever applied",function()
		for _,odd in ipairs({{place=0},{place=9},{place=1.5},{inputs=-1},{inputs=0/0},{us=0},{us=120000001},{us=0/0},{seed=-1},{prize=1},{mode="stats"},{mode="stats",band=6},{mode="x"},{kind="x"},{kind="trial"}})do
			local state={nectar=0};assert(not write(state,"x",{race(1,odd)})and state.dash==nil and state.nectar==0)
		end
		local nine={};for i=1,9 do nine[i]=race(1)end
		for _,list in ipairs({{},nine,"x"})do assert(not S.apply({nectar=0},{id="x",results=list},DAY))end
		assert(not S.apply({nectar=0},{id="",results={race(1)}},DAY)and not S.apply({nectar=0/0},{id="x",results={race(1)}},DAY)and not S.apply({nectar=0},{id="x",results={race(1)}},"today"))
		assert(S.digest({race(1)})~=S.digest({race(2)})and S.digest({race(1)})==S.digest({race(1)}))
	end)
	test("the owner's snapshot never carries the seed",function()
		local state={nectar=0};write(state,"x",{race(1)})
		local public=S.public(state,DAY);assert(public.last.stars==2 and public.last.seed==nil and public.seed==nil and public.paid==1 and public.limit==5)
	end)
	return{passed=#cases,cases=cases}
end
