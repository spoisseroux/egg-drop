-- Fresh module instances avoid Edit/Play require-cache ambiguity.
return function(server)
	local shared=game.ReplicatedStorage.Shared:Clone();shared.Name="_BackgroundCatalogFixture";shared.Parent=server
	local Catalog=require(shared.AppearanceCatalog)
	local Themes=require(shared.DeckThemes)
	local Eggs=require(shared.EggCatalog)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function facts()return{rank=0,trials=0,inventoryMask=Eggs.bit("pip"),totalWins=0,masteryRanks={pip=0}}end
	test("five historic themes stay free while new themes require exact saved facts",function()
		local f=facts()
		for _,id in ipairs({"sherbet","stone","ice","brick","moss"})do assert(Catalog.canEquip("theme",id,f))end
		assert(not Catalog.canEquip("theme","honey",f));f.totalWins=1;assert(Catalog.canEquip("theme","honey",f))
		assert(not Catalog.canEquip("theme","gloaming",f));f.masteryRanks.pip=1;assert(Catalog.canEquip("theme","gloaming",f))
		assert(not Catalog.canEquip("theme","copperleaf",f));f.masteryRanks.pip=2;assert(Catalog.canEquip("theme","copperleaf",f))
	end)
	test("unowned and legacy effects cannot manufacture new rank II eligibility",function()
		local f=facts();f.masteryRanks.wick=3
		assert(not Catalog.canEquip("theme","copperleaf",f))
		f.masteryLegacyMask=1;f.masteryRanks.pip=1
		assert(not Catalog.canEquip("background","lantern",f)and not Catalog.canEquip("theme","copperleaf",f))
		f.inventoryMask=Eggs.bit("foxfire_wick");f.masteryRanks.wick=2
		assert(Catalog.canEquip("theme","copperleaf",f)and Catalog.canEquip("background","lantern",f))
	end)
	test("backgrounds and Lantern stamp distinguish High Roller from Triple Pop",function()
		local f=facts();assert(Catalog.canEquip("background","canopy",f))
		assert(not Catalog.canEquip("background","creek",f)and not Catalog.canEquip("sticker","lantern",f))
		f.trials=1;assert(Catalog.canEquip("sticker","lantern",f)and not Catalog.canEquip("background","creek",f))
		f.trials=2;assert(Catalog.canEquip("background","creek",f)and not Catalog.canEquip("sticker","lantern",f))
		f.masteryRanks.pip=2;assert(Catalog.canEquip("background","lantern",f))
	end)
	test("existing Wick and complete-trial crest locks preserve sparse and legacy behavior",function()
		local f=facts();f.inventoryMask=Eggs.bit("foxfire_wick");assert(not Catalog.canEquip("sticker","wick",f))
		f.inventoryMask=Eggs.bit("wick");assert(Catalog.canEquip("sticker","wick",f))
		f.inventoryMask=nil;f.rank=3;assert(Catalog.canEquip("sticker","wick",f))
		f.trials=3;assert(not Catalog.canEquip("sticker","club",f));f.trials=7;assert(Catalog.canEquip("sticker","club",f))
	end)
	test("raw and public HatchState facts produce the same real mastery ranks",function()
		for _,points in ipairs({2,3,9,10})do
			local raw={inventoryMask=1,totalWins=1,mastery={pip=points},masteryChallenges={},masteryLegacyMask=1}
			local fromRaw=Catalog.facts({rank=0,trials=2},raw)
			local fromPublic=Catalog.facts({rank=0,trials=2},{inventoryMask=1,totalWins=1,masteryRanks=fromRaw.masteryRanks})
			for _,id in ipairs({"honey","gloaming","copperleaf"})do
				assert(Catalog.canEquip("theme",id,fromRaw)==Catalog.canEquip("theme",id,fromPublic))
			end
			assert(Catalog.canEquip("theme","copperleaf",fromRaw)==(points>=10))
		end
	end)
	test("newly committed facts refresh eligibility without another purchase or grant",function()
		local f=facts();assert(not Catalog.describeRequirement("theme","honey",f).unlocked)
		f.totalWins=1;assert(Catalog.describeRequirement("theme","honey",f).progress==1)
		f.masteryRanks.pip=2;assert(Catalog.describeRequirement("background","lantern",f).unlocked)
		assert(f.totalWins==1 and f.masteryRanks.pip==2)
	end)
	test("all eight themes expose complete semantic palettes and readable muted/text states",function()
		local function luminance(color)
			local function c(value)return if value<=.04045 then value/12.92 else ((value+.055)/1.055)^2.4 end
			return .2126*c(color.R)+.7152*c(color.G)+.0722*c(color.B)
		end
		assert(#Themes.Order==8)
		for _,id in ipairs(Themes.Order)do
			local t=Themes.ById[id]
			for _,key in ipairs({"panel","raised","inset","ink","text","muted","line","selected","focus","accent"})do assert(typeof(t.ui[key])=="Color3",id..key)end
			for _,key in ipairs({"outside","base","dither","rail","rim","guide"})do assert(typeof(t.lcd[key])=="Color3",id..key)end
			for _,foreground in ipairs({"text","muted"})do for _,background in ipairs({"panel","raised","inset","selected"})do
				local a,b=luminance(t.ui[foreground]),luminance(t.ui[background])
				assert((math.max(a,b)+.05)/(math.min(a,b)+.05)>=4.5,id.." "..foreground.."/"..background)
			end end
		end
	end)
	shared:Destroy()
	return{passed=#cases,cases=cases,persistentWrites=false,evidence="fresh shared catalogs; derived facts only"}
end
