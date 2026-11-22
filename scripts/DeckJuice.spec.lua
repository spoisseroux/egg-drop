-- Deck juice, server parts (DeckJuiceCatalog, DeckJuiceState, PlayerProgress.deckJuice;
-- V3-LEVELS-BUILD-PLAN-2026-11-22 S3): known and unlocked choices only, from the save; locked or
-- unknown saved ids draw classic and are kept; newest stamp wins between two sessions; off shows
-- nothing and refuses everything. The Studio memory store only; no DataStore.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.DeckJuice)(ServerScriptService.Server)
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Catalog=require(Shared.DeckJuiceCatalog)
	local Levels=require(Shared.Levels)
	local Stats=require(Shared.StatCatalog)
	local Eggs=require(Shared.EggCatalog)
	local State=require(server.DeckJuiceState)
	local Progress=require(server.PlayerProgress)
	local Store=require(server.ProgressStore)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local ALL={track=true,gates=true,medals=true,juice=true}
	local function juice(on)Levels.inject({flags={LevelsMatter=on==true},studio=true,shipped=ALL})end
	local function save(levels)
		local row={};for stat,level in pairs(levels or {})do row[stat]=Stats.xpFor(level)end
		return{inventoryMask=Eggs.bit("pip"),petStats={pip=row}}
	end
	local ok,problem=pcall(function()
		test("catalogue: 2 pops, 2 trails, 2 starts at scope 2.1's levels; ids are unique in their kind",function()
			local want={["pop.confetti"]="power5",["pop.fizz"]="power15",["trail.bubble"]="power30",["trail.comet"]="power45",["start.ready"]="energy5",["start.lightning"]="energy20"}
			local n=0
			for _,row in ipairs(Catalog.Rows)do n+=1;assert(want[row.kind.."."..row.id]==row.gate.stat..row.gate.level and table.isfrozen(row)and #row.name>0,row.id)end
			assert(State.Throttle==.25 and Catalog.Attribute=="DeckJuice")
			assert(n==6 and #Catalog.ByKind.pop==2 and #Catalog.ByKind.trail==2 and #Catalog.ByKind.start==2 and table.concat(Catalog.Kinds," ")=="pop trail start")
			assert(Catalog.known("pop","classic")and Catalog.known("pop","fizz")and not Catalog.known("trail","fizz")and not Catalog.known("pop","nope")and not Catalog.known("hat","classic")and not Catalog.known(nil,nil)and not Catalog.known("pop",nil))
		end)
		test("choose: known and unlocked from the save; locked, unknown, unchanged and off change nothing",function()
			juice(true)
			local map,why=State.choose({},save({power=5}),"pop","confetti");assert(map and map.pop=="confetti"and why==nil)
			map,why=State.choose({},save({power=4}),"pop","confetti");assert(map==nil and why=="NeedsLevel")
			map,why=State.choose({},save({power=99}),"start","ready");assert(map==nil and why=="NeedsLevel","Energy, not Power")
			for _,pair in ipairs({{"pop","nope"},{"trail","fizz"},{"hat","confetti"},{nil,"confetti"},{"pop",nil},{"pop",{}},{1,2}})do
				map,why=State.choose({},save({power=99,energy=99}),pair[1],pair[2]);assert(map==nil and why=="Unknown")
			end
			map,why=State.choose({pop="fizz"},save({power=99}),"pop","fizz");assert(map==nil and why=="NoChange")
			map,why=State.choose(nil,save({}),"pop","classic");assert(map==nil and why=="NoChange")
			local saved={pop="fizz",trail="aurora_later",sky="later"}
			map=State.choose(saved,save({power=30}),"pop","classic");assert(map and map.pop==nil and map.trail=="aurora_later"and map.sky=="later"and saved.pop=="fizz","a copy; later builds' choices are kept")
			map=State.choose(saved,save({power=30}),"trail","bubble");assert(map.trail=="bubble"and map.pop=="fizz")
			-- an unowned pet's XP unlocks nothing
			local state=save({});state.petStats.blip={power=Stats.MaxXP}
			assert(select(2,State.choose({},state,"pop","confetti"))=="NeedsLevel")
			juice(false)
			map,why=State.choose({},save({power=99}),"pop","confetti");assert(map==nil and why=="Off")
		end)
		test("public: each kind resolved to a known, unlocked id, else classic; nothing while off",function()
			juice(true)
			local p=State.public({pop="fizz",trail="comet",start="ready"},save({power=15,energy=5}))
			assert(p.pop=="fizz"and p.trail=="classic"and p.start=="ready","comet is locked")
			p=State.public({pop="aurora_later",trail=5,sky="x"},save({power=99}));assert(p.pop=="classic"and p.trail=="classic"and p.start=="classic"and p.sky==nil)
			p=State.public(nil,save({}));assert(p.pop=="classic")
			p=State.public({pop="confetti"},{});assert(p.pop=="classic","no save, no unlocks")
			juice(false)
			assert(State.public({pop="fizz"},save({power=99}))==nil)
		end)
		test("decode: short strings kept whatever the id, bounded, junk dropped, this build's kinds first",function()
			assert(Catalog.decode(nil)==nil and Catalog.decode("x")==nil and Catalog.decode({})==nil and Catalog.decode({pop=5,trail={},[1]="x",start=""})==nil)
			local d=Catalog.decode({pop="later_id",trail=string.rep("a",32),start=string.rep("a",33),sky="x",[string.rep("k",17)]="y"})
			assert(d.pop=="later_id"and #d.trail==32 and d.start==nil and d.sky=="x"and d[string.rep("k",17)]==nil)
			local many={pop="a",trail="b",start="c"};for i=1,20 do many["k"..string.char(96+i)]="v"end
			d=Catalog.decode(many);local n=0;for _ in pairs(d)do n+=1 end
			assert(n==Catalog.KindLimit and d.pop=="a"and d.trail=="b"and d.start=="c"and d.ka=="v")
		end)
		test("profile: missing is {}, the choice saves with its stamp beside every other field, and reloads",function()
			local id=-8811001;local key="player_"..id
			Store:UpdateAsync(key,function()return{custom="kept",hatching={nectar=3},greetOff=true,greetOffAt=5}end)
			local profile=Progress.fromRecord(id,Store:GetAsync(key),true)
			assert(type(profile.deckJuice)=="table"and next(profile.deckJuice)==nil and profile.juiceChange==nil)
			assert(Progress.flushOnce(profile)==true and Store:GetAsync(key).deckJuice==nil,"nothing is written for a player who never chose")
			Progress.setSetting(profile,"deckJuice",{pop="confetti"})
			assert(profile.deckJuice.pop=="confetti"and profile.motionChange==nil and Progress.flushOnce(profile))
			local record=Store:GetAsync(key)
			assert(record.deckJuice.pop=="confetti"and type(record.deckJuiceAt)=="number"and record.deckJuiceWriter==game.JobId)
			assert(record.custom=="kept"and record.hatching.nectar==3 and record.greetOff==true and record.greetOffAt==5 and profile.juiceChange==nil)
			assert(Progress.fromRecord(id,record,true).deckJuice.pop=="confetti")
			-- back to classic saves an empty map, and a later authoritative read clears the provisional one
			Progress.setSetting(profile,"deckJuice",{});assert(Progress.flushOnce(profile)and next(Progress.fromRecord(id,Store:GetAsync(key),true).deckJuice)==nil)
			local provisional=Progress.fromRecord(id,record,true);assert(Progress.hydrate(provisional,Store:GetAsync(key))and next(provisional.deckJuice)==nil)
			-- malformed saved values never fail a load
			for _,bad in ipairs({5,"x",{pop={}},{[1]="x"}})do assert(next(Progress.fromRecord(id,{deckJuice=bad},true).deckJuice)==nil)end
		end)
		test("two sessions: the newest stamp wins, whichever saves last; an older build's save keeps the field",function()
			local id=-8811002;local key="player_"..id
			Store:UpdateAsync(key,function()return{}end)
			local a,b=Progress.fromRecord(id,{},true),Progress.fromRecord(id,{},true)
			Progress.setSetting(a,"deckJuice",{pop="fizz"});a.juiceChange.at=2000
			Progress.setSetting(b,"deckJuice",{pop="confetti"});b.juiceChange.at=1000
			assert(Progress.flushOnce(a)and Progress.flushOnce(b))
			assert(Store:GetAsync(key).deckJuice.pop=="fizz"and Store:GetAsync(key).deckJuiceAt==2000,"the older choice never overwrites")
			-- a failed profile never saves
			local failed=Progress.fromRecord(id,{},false);Progress.setSetting(failed,"deckJuice",{pop="classic"})
			Progress.flushOnce(failed);assert(Store:GetAsync(key).deckJuice.pop=="fizz")
			-- a write that does not know the field leaves it alone
			local c=Progress.fromRecord(id,{},true);Progress.setSetting(c,"greetOff",true);assert(Progress.flushOnce(c)and Store:GetAsync(key).deckJuice.pop=="fizz")
		end)
		test("a choice made while a save is in flight is saved by the next one",function()
			local id=-8811003;local key="player_"..id
			Store:UpdateAsync(key,function()return{}end)
			local profile=Progress.fromRecord(id,{},true)
			local real=Store.UpdateAsync
			Progress.setSetting(profile,"greetOff",true)
			local fine,wrong=pcall(function()
				Store.UpdateAsync=function(self,...)
					Store.UpdateAsync=real
					Progress.setSetting(profile,"deckJuice",{pop="fizz"})
					return real(self,...)
				end
				Progress.flushOnce(profile)
				assert(Store:GetAsync(key).deckJuice==nil and profile.juiceChange~=nil)
				assert(Progress.flushOnce(profile)and Store:GetAsync(key).deckJuice.pop=="fizz"and profile.juiceChange==nil)
			end)
			Store.UpdateAsync=real
			assert(fine,wrong)
		end)
	end)
	Levels.inject(nil)
	assert(ok,problem)
	return{passed=#cases,cases=cases}
end
