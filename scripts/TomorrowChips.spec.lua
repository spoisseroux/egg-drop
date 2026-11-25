-- Growth cuts (GROWTH-CUTS-LOOK 2026-11-25 section 1): the TOMORROW strip's pure rules. Live data only (no snapshot:
-- no strip, no rail line); today's stamp and a quest to claim come first and take a tap; the next stamp, a card just
-- filled reads Stamp 1, the earned pet's stamp 7 line; three new quests; Stat Eggs only with a pet, off phones; the
-- PC row drops the Stat Egg chip first when it does not fit; the garden line once a session.
-- Usage (Client): require(PlayerScripts.Client.ZZSpecs.TomorrowChips)(PlayerScripts.Client)
return function(client)
	local Chips=require(client.TomorrowChips)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local UICopy=require(Shared.UICopy)
	local Eggs=require(Shared.EggCatalog)
	local Pets=require(Shared.PetCatalog)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local BEAR=Eggs.bit("pip")
	local NO_PET={earned=false}
	local function state(extra)
		local s={stamps=1,dailyAvailable=false,inventoryMask=BEAR,statEgg={enabled=true,dailyBuys=3},
			quests={daily={{ready=false},{ready=false},{ready=false}}}}
		for k,v in pairs(extra or {})do s[k]=v end
		return s
	end
	local function ids(list)local out={};for _,chip in ipairs(list)do table.insert(out,chip.id)end;return table.concat(out,",")end

	test("no snapshot: no strip and no rail line (never a made-up number)",function()
		assert(Chips.model(nil)==nil and Chips.model("x")==nil and Chips.rail(nil)==nil)
		assert(#Chips.layout(nil,600,function()return 10 end).items==0)
	end)

	test("today's stamp waiting: gold, before the eyebrow, tappable; the rail says it is waiting",function()
		local m=Chips.model(state({dailyAvailable=true,stamps=2}),NO_PET)
		assert(ids(m.before)=="stamp"and m.before[1].today and m.before[1].color=="stars")
		assert(m.before[1].text==UICopy.get("tomorrow.stampToday",{reward=5}),m.before[1].text)
		assert(ids(m.after)=="quests,statEggs")
		assert(Chips.rail(state({dailyAvailable=true,stamps=2}))==UICopy.get("tomorrow.railToday",{reward=5}))
	end)

	test("stamp taken: the next stamp and its reward; a card just filled reads Stamp 1",function()
		local m=Chips.model(state({stamps=1}),NO_PET)
		assert(#m.before==0 and m.after[1].id=="stamp"and not m.after[1].today and m.after[1].icon=="check")
		assert(m.after[1].text==UICopy.get("tomorrow.stamp",{count=2,reward=4}),m.after[1].text)
		local full=Chips.model(state({stamps=7}),NO_PET)
		assert(full.after[1].text==UICopy.get("tomorrow.stamp",{count=1,reward=4}),"stamp 7 taken today: Stamp 1")
		assert(Chips.rail(state({stamps=1}))==UICopy.get("tomorrow.rail",{count=2,reward=4,quests=3}))
	end)

	test("next is stamp 7 and it brings the earned pet: that pet's line with the paw",function()
		local earned={Rules={blip={stamps=7}},enabled=function(id)return id=="blip"end}
		local m=Chips.model(state({stamps=6}),{earned=earned})
		local name=Pets.byId.blip and Pets.byId.blip.name
		assert(name and m.after[1].icon=="paw",tostring(m.after[1].text))
		assert(m.after[1].text==UICopy.get("tomorrow.stampPet",{pet=name,reward=12}))
		local owned=Chips.model(state({stamps=6,inventoryMask=BEAR+Eggs.bit("blip")}),{earned=earned})
		assert(owned.after[1].icon=="check"and owned.after[1].text==UICopy.get("tomorrow.stamp",{count=7,reward=12}),"already owned: plain")
		local off=Chips.model(state({stamps=6}),{earned={Rules=earned.Rules,enabled=function()return false end}})
		assert(off.after[1].icon=="check","the pet switch off: plain")
		local early=Chips.model(state({stamps=2}),{earned=earned})
		assert(early.after[1].icon=="check","not stamp 7 yet: plain")
	end)

	test("quests: ready to claim comes first (accent, tappable), else three new quests",function()
		local one=Chips.model(state({quests={daily={{ready=true},{ready=false},{claimed=true}}}}),NO_PET)
		assert(ids(one.before)=="quests"and one.before[1].today and one.before[1].color=="accent")
		assert(one.before[1].text==UICopy.get("tomorrow.claimOne"))
		local two=Chips.model(state({quests={daily={{ready=true},{ready=true},{ready=false}}}}),NO_PET)
		assert(two.before[1].text==UICopy.get("tomorrow.claim",{count=2}))
		local none=Chips.model(state({quests={daily={{claimed=true},{claimed=true},{claimed=true}}}}),NO_PET)
		assert(ids(none.after)=="stamp,quests,statEggs"and none.after[2].text==UICopy.get("tomorrow.quests",{count=3}))
		local missing=Chips.model(state({quests=false}),NO_PET)
		assert(missing.after[2].text==UICopy.get("tomorrow.quests",{count=3}),"the count is the catalogue's three pools")
		local both=Chips.model(state({dailyAvailable=true,quests={daily={{ready=true}}}}),NO_PET)
		assert(ids(both.before)=="stamp,quests"and ids(both.after)=="statEggs")
	end)

	test("Stat Eggs: only with a pet and the eggs on, never on phones",function()
		assert(ids(Chips.model(state(),NO_PET).after)=="stamp,quests,statEggs")
		assert(Chips.model(state(),NO_PET).after[3].text==UICopy.get("tomorrow.statEggs",{count=3}))
		assert(ids(Chips.model(state(),{phone=true,earned=false}).after)=="stamp,quests","phone: no Stat Egg chip")
		assert(ids(Chips.model(state({inventoryMask=0}),NO_PET).after)=="stamp,quests","no pet")
		assert(ids(Chips.model(state({statEgg=false}),NO_PET).after)=="stamp,quests","no Stat Egg snapshot")
		assert(ids(Chips.model(state({statEgg={enabled=false}}),NO_PET).after)=="stamp,quests","Stat Eggs off")
	end)

	test("PC row: from the left with three chips; too narrow drops the Stat Egg chip first and centres the rest",function()
		local measure=function(text,size)return #text*size*.5 end
		local m=Chips.model(state(),NO_PET)
		local wide=Chips.layout(m,900,measure)
		assert(not wide.dropped and #wide.items==4 and wide.items[1].kind=="eyebrow"and wide.items[1].x==Chips.Pad)
		local narrow=Chips.layout(m,320,measure)
		assert(narrow.dropped and #narrow.items==3,"Stat Eggs dropped")
		for _,item in ipairs(narrow.items)do assert(item.kind=="eyebrow"or item.chip.id~="statEggs")end
		local today=Chips.layout(Chips.model(state({dailyAvailable=true,quests={daily={{ready=true}}},statEgg=false}),NO_PET),900,measure)
		assert(#today.items==2 and today.items[1].kind=="chip"and today.items[2].kind=="chip","no tomorrow chip: no eyebrow")
		assert(today.items[1].x>Chips.Pad,"two chips centre")
		assert(Chips.Height==36 and Chips.Shrink==42 and Chips.Hit==44)
	end)

	test("garden line: after a results screen or 4 minutes in, once; entry 1 s after the count-up",function()
		assert(not Chips.railDue(nil)and not Chips.railDue({sessionFor=60}))
		assert(Chips.railDue({sawResults=true})and Chips.railDue({sessionFor=240}))
		assert(not Chips.railDue({sawResults=true,shown=true}))
		assert(Chips.entry(nil)==0 and Chips.entry(.5)==0 and Chips.entry(1.25)==1 and math.abs(Chips.entry(1.125)-.5)<1e-6)
	end)

	return {passed=#cases,cases=cases}
end
