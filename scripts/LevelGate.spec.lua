-- Level gates and medals maths (LevelGate, Medals; V3-LEVELS-BUILD-PLAN-2026-11-22 S2, S4): any owned
-- pet for a stat gate, one pet's total for a total gate, fail closed on anything malformed; medal
-- counts, slots and crossings. Pure shared data.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.LevelGate)(ServerScriptService.Server)
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Gate=require(Shared.LevelGate)
	local Medals=require(Shared.Medals)
	local Levels=require(Shared.Levels)
	local Stats=require(Shared.StatCatalog)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function row(value,changes)
		local r={};for _,stat in ipairs(Stats.Order)do r[stat]=value end
		for stat,v in pairs(changes or {})do r[stat]=v end
		return r
	end
	local ok,problem=pcall(function()
		test("valid: exactly {stat, level 2..99} or {total 7..594}",function()
			assert(Gate.valid({stat="jump",level=15})and Gate.valid({stat="heart",level=2})and Gate.valid({stat="smarts",level=99})and Gate.valid({total=7})and Gate.valid({total=594}))
			for _,bad in ipairs({{},{stat="jump"},{level=5},{stat="nope",level=5},{stat="jump",level=1},{stat="jump",level=100},{stat="jump",level=0/0},{stat="jump",level=2.5},{stat="jump",level="15"},
				{total=6},{total=595},{total=0/0},{total=60,stat="jump",level=5},{stat="jump",level=5,total=60},{stat="jump",level=5,extra=true},{total=60,extra=1}})do assert(not Gate.valid(bad))end
			assert(not Gate.valid(nil)and not Gate.valid("jump 15")and not Gate.valid(true))
		end)
		test("stat gate: any owned pet, exactly at the level; the best pet is reported",function()
			local gate={stat="jump",level=15}
			assert(not Gate.met({pip=row(1,{jump=14})},gate)and Gate.met({pip=row(1,{jump=15})},gate)and Gate.met({pip=row(1,{jump=99})},gate))
			assert(Gate.met({pip=row(1,{jump=3}),blip=row(1,{jump=15})},gate),"another pet counts")
			assert(not Gate.met({pip=row(99,{jump=14})},gate),"other stats never count")
			local p=Gate.progress({pip=row(1,{jump=3}),blip=row(1,{jump=9})},gate)
			assert(p.have==9 and p.need==15 and p.petId=="blip"and p.met==false and p.stat=="jump"and p.total==nil)
			p=Gate.progress({},gate);assert(p.have==0 and p.petId==nil and not p.met)
		end)
		test("total gate: one pet's total, never two pets added",function()
			local gate={total=150}
			assert(not Gate.met({pip=row(20),blip=row(20)},gate),"120 + 120 is not 150 on one pet")
			assert(not Gate.met({pip=row(24,{heart=29})},gate)and Gate.met({pip=row(25)},gate)and Gate.met({pip=row(1),blip=row(25)},gate))
			local p=Gate.progress({pip=row(10),blip=row(20)},gate);assert(p.have==120 and p.need==150 and p.petId=="blip"and p.total==150)
		end)
		test("fail closed: malformed gates and levels are never met; no gate always is",function()
			assert(Gate.met(nil,nil)and Gate.met({},nil))
			for _,gate in ipairs({{},{stat="jump"},{total="150"},"x",true})do assert(not Gate.met({pip=row(99)},gate))end
			for _,levels in ipairs({"x",{pip="x"},{pip={jump="99"}},{pip={jump=0/0}},{pip={jump=math.huge}},{pip={jump=-1}},{pip={jump=100}},{pip={jump=15.5}},{[1]=row(99)}})do
				assert(not Gate.met(levels,{stat="jump",level=15}))
			end
			assert(not Gate.met(nil,{stat="jump",level=15})and not Gate.met({pip={heart=99}},{total=150}),"missing stats count nothing")
		end)
		test("levels(): the snapshot, the public attribute and plain rows read the same; junk is dropped",function()
			local want=row(1,{jump=15})
			for _,pets in ipairs({{pip={level=want,xp={}}},{pip={levels=want,total=20,keeper="x"}},{pip=want}})do
				local levels=Gate.levels(pets)
				assert(Gate.met(levels,{stat="jump",level=15})and not Gate.met(levels,{stat="jump",level=16}))
			end
			local odd=Gate.levels({pip={levels={jump=15,heart="x",fake=99}},blip="x",[3]={}})
			assert(odd.pip.jump==15 and odd.pip.heart==nil and odd.pip.fake==nil and odd.blip==nil and odd[3]==nil)
			assert(next(Gate.levels(nil))==nil and next(Gate.levels("x"))==nil)
			if server then
				local S=require(server.StatState)
				local state={inventoryMask=require(Shared.EggCatalog).bit("pip"),petStats={pip={jump=Stats.xpFor(15)},blip={jump=Stats.MaxXP}}}
				local levels=Gate.levels(S.publicLevels(state).pets)
				assert(levels.pip.jump==15 and levels.blip==nil,"only owned pets")
				assert(Gate.met(levels,{stat="jump",level=15})and not Gate.met(levels,{stat="jump",level=16}))
				assert(Gate.met(Gate.levels(S.public(state,"1").pets),{stat="jump",level=15}),"the snapshot's petStats.pets")
			end
		end)
		test("listed: no gate always; a gated row only while gates are on",function()
			Levels.inject({flags={},studio=true});assert(Gate.listed(nil)and not Gate.listed({stat="jump",level=15}))
			Levels.inject({flags={LevelsMatter=true},studio=true});assert(Gate.listed(nil)and Gate.listed({stat="jump",level=15}))
			Levels.inject(nil)
			assert(Gate.Reason=="NeedsLevel")
		end)
		test("medals: 25 / 50 / 75 / 99, 24 a pet, derived from levels only",function()
			assert(Medals.PerPet==24 and table.concat(Medals.Levels,",")=="25,50,75,99")
			local want={[1]=0,[24]=0,[25]=1,[49]=1,[50]=2,[74]=2,[75]=3,[98]=3,[99]=4}
			for level,n in pairs(want)do assert(Medals.count(level)==n,level)end
			for _,odd in ipairs({0,-5,100,0/0,math.huge,25.5,"99"})do assert(Medals.count(odd)==0)end
			assert(Medals.count(nil)==0 and Medals.tier(24)==nil and Medals.tier(60).id=="bloom"and Medals.index("starbloom")==4)
			assert(Medals.earned({pip=row(99)})==24 and Medals.earned({pip=row(99),blip=row(99)})==48 and Medals.earned({pip=row(1,{jump=50,heart=25})})==3)
			assert(Medals.earned(nil)==0 and Medals.earned({})==0 and Medals.earned({pip="x"})==0 and Medals.earned({pip={fake=99}})==0)
			local slots=Medals.forPet(row(1,{heart=25,power=99}))
			assert(#slots==6 and slots[1].stat=="heart"and slots[1].count==1 and slots[1].tier.id=="sprout"and slots[1].next==50)
			assert(slots[2].tier.star and slots[2].next==nil and slots[3].count==0 and slots[3].next==25 and slots[3].tier==nil)
			-- Tiers agree with the stat tier words (StatCatalog) so the panel never says two things.
			for index,tier in ipairs(Medals.Tiers)do assert(Stats.Tiers[index+1].level==tier.level,tier.id)end
			assert(next(Medals.Badges)==nil,"badge ids are nil until Spencer makes them")
		end)
		test("crossed: every medal between two reads, in a fixed order; nothing on no change or a drop",function()
			local before={pip=row(1,{jump=24,heart=24})}
			local after={pip=row(1,{jump=25,heart=50})}
			local list=Medals.crossed(before,after)
			assert(#list==3 and list[1].stat=="heart"and list[1].tier=="sprout"and list[2].tier=="bloom"and list[3].stat=="jump"and list[3].level==25)
			assert(#Medals.crossed(after,after)==0 and #Medals.crossed(after,before)==0 and #Medals.crossed(before,nil)==0)
			assert(#Medals.crossed(nil,after)==3 and #Medals.crossed({},{blip=row(99)})==24)
		end)
	end)
	Levels.inject(nil)
	assert(ok,problem)
	return{passed=#cases,cases=cases}
end
