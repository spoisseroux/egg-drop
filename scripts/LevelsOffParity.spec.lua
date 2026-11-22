-- "Levels matter" off (its flag, or the runtime switch) is the game before it (V3-LEVELS-BUILD-PLAN-2026-11-22). Goldens were read from
-- 90ae236 (v1054, the commit this build starts from): 200 shelf weeks, Book pages, shop lists and prices, egg and toy prices, snapshot
-- and save keys. With the flag on, the shelf, the Book and everything on sale before keep the same
-- ids and prices (levels only ever add).
-- Isolated adapters only; no DataStore or user writes.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.LevelsOffParity)(ServerScriptService.Server)
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Levels=require(Shared.Levels)
	local Shelf=require(Shared.WeeklyShelf)
	local Wear=require(Shared.WearableCatalog)
	local Variants=require(Shared.WearableVariants)
	local Plates=require(Shared.DeckThemes)
	local Balls=require(Shared.BallThemes)
	local Book=require(Shared.BookCatalog)
	local Toys=require(Shared.ToyCatalog)
	local Eggs=require(Shared.EggCatalog)
	local Stats=require(Shared.StatCatalog)
	local H=require(server.HatchProgress)
	local S=require(server.StatState)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
	local ALL={track=true,gates=true,medals=true,juice=true}
	local function levels(on)Levels.inject({flags={LevelsMatter=on~=false},studio=true,shipped=ALL,switch=on~="switch"})end
	local OFF={false,"switch"}
	local function keys(t)local out={};for k in pairs(t)do table.insert(out,tostring(k))end;table.sort(out);return table.concat(out," ")end

	local GOLD={
		shelfBase=2811,shelfHash=3485999808,
		shelfFirst="wearable:beanie_mint:40:32,wearable:heart:100:80,ball:midnight:250:200,wearable:bellcollar_silver:100:80,wearable:bowtail:100:80,faceplate:liquid_chrome:100:80",
		wear="beanie:40 beanie_mint:40 beanie_butter:40 beanie_grape:40 sunhat:100 sunhat_cocoa:100 sunhat_peach:100 flowercrown:250 tee:40 tee_berry:40 tee_forest:40 tee_tangerine:40 hoodie:250 beads:40 bellcollar:100 bellcollar_silver:100 bellcollar_rose:100 ring:40 starstud:100 sparkle:100 sleepy:40 blep:40 heart:100 happy:40 lash:40 blush:40 partyhat:40 bowtail:100 acorn:100 bands:40 specs:40 round:40 w:40",
		balls="smileys:0 marbles:0 gumdrops:40 gems:100 planets:100 kittens:250 bubbles:100 pea_soup:40 pocket_grey:40 amber:100 deep_sea:100 bubblegum:100 midnight:250",
		plates="sherbet:0 stone:0 ice:0 brick:0 moss:0 honey:0 gloaming:0 copperleaf:0 aqua_pop:40 lime_gel:40 sorbet_sky:40 liquid_chrome:100 tidepool:100 aurora_glass:100 prism_flare:250 night_orb:250 grape_soda:40 rose_chrome:100 cloud_glass:40 lagoon:100 dewy_meadow:100",
		book={balls="gumdrops gems planets kittens bubbles pea_soup pocket_grey amber deep_sea bubblegum midnight",
			faceplates="aqua_pop lime_gel sorbet_sky liquid_chrome tidepool aurora_glass prism_flare night_orb grape_soda rose_chrome cloud_glass lagoon dewy_meadow"},
		bookTotals="balls=11 faceplates=13 wardrobe=46 toys=9 charms=6 pets=2 discoveries=17",
		toys="ball bone pocket_deck sparkler squeaky_carrot wobble_top",
		statEgg="boughtToday cycleIndex dailyBuys enabled free freeLimit misses mode pityLeft poolVersion pouch pouchSize price quotes",
		petStats="bonus pets",
		public="ballThemes bond book catalogVersion charmUnlocks coachMask dailyAvailable dailyBonus dailyDay faceplates featureCatalogVersion featurePoolVersion featureStock finishInventory hueInventory hueMigrationAcknowledged hues inventoryMask legacyHuePresets lookAvailable lookCharmMisses lookFound lookPoolVersion lookSelectionMode mastery masteryChallenges masteryDetails masteryLegacyMask masteryRanks materialAvailable materialCatalogVersion materialPoolVersion materialSelectionMode materialUnlocks misses names nectar nextFixed petCount petDay petFeatures petFinish petHues petMaterials petStats petToys petWearables playDate quests restricted revision shelfWeek stampCard stampDay stampReward stamps starterClaimed statEgg stats status todayEarned totalWins toyCatalogVersion toyPoolVersion toyUnlocks",
		saved="ballThemes book charmUnlocks dailyClaimDay epoch featureReceiptOrder featureReceipts featureStock hueAssignments hueInventory hueItemReceipts hueMigrationAcknowledged hueReceiptOrder inventoryMask lastAwardSeq lease mastery masteryChallenges masteryLegacyMask materialReceiptOrder materialReceipts materialUnlocks migrated misses names nectar operationSeq petCount petDay petFeatures petHues petMaterials petStats petToys petWearables quests revision stamps stats statsSeed totalWins toyReceiptOrder toyReceipts toyUnlocks version welcomeCredited",
	}
	local function shelf()
		local base=Shelf.week(1700000000);assert(base==GOLD.shelfBase)
		local out={}
		for week=base,base+199 do
			-- computed fresh from the live pools, never the module's memo of another switch
			for _,slot in ipairs(Shelf.compute(week,Shelf.pools))do table.insert(out,slot.kind..":"..slot.id..":"..slot.full..":"..slot.price)end
		end
		assert(#out==600 and table.concat(out,",",1,6)==GOLD.shelfFirst,"the first two shelves: "..table.concat(out,",",1,6))
		assert(Shelf.hash(0,0,table.concat(out,","))==GOLD.shelfHash,"a shelf week moved")
		for week=base,base+20 do for _,slot in ipairs(Shelf.slots(week))do assert(not(Variants.ById[slot.id]and Variants.ById[slot.id].gate),slot.id)end end
	end
	local function book()
		local totals={}
		for _,page in ipairs(Book.PageOrder)do
			local ids={};for _,item in ipairs(Book.Pages[page].items)do table.insert(ids,item.id)end
			table.insert(totals,page.."="..#ids)
			if GOLD.book[page]then assert(table.concat(ids," ")==GOLD.book[page],page)end
		end
		-- The Pets page opens with the second pet's flag; every other page is fixed.
		assert(table.concat(totals," ")==GOLD.bookTotals,table.concat(totals," "))
	end
	local function priced(list,price)local out={};for _,id in ipairs(list)do table.insert(out,id..":"..(price(id)or 0))end;return table.concat(out," ")end
	local function wearList(pet,ungatedOnly)
		local out={}
		for _,item in ipairs(Wear.forPet(pet).order)do if not(ungatedOnly and item.gate)then table.insert(out,item.id..":"..item.price)end end
		return table.concat(out," ")
	end
	local function eggs()
		assert(table.concat(Toys.Pools[Toys.PoolVersion]," ")==GOLD.toys and Toys.Cost==20 and Toys.PoolVersion==3)
		assert(Eggs.ById.meadow.cost==18 and Eggs.ById.sprout.cost==24)
		assert(require(Shared.LookEggCatalog).Price==12 and require(Shared.NameCatalog).Price==8)
		local egg=require(Shared.StatEggCatalog);assert(egg.Price==15 and egg.DailyBuys==3 and egg.FreeLimit==10 and egg.PouchSize==12)
	end
	local function fixture(seed,start)
		local db,c={},{now=start or 1700000000,serial=0}
		local adapter={now=function()return c.now end,guid=function()c.serial+=1;return "op"..c.serial end,random=function()return .1 end,wait=function()end,
			update=function(key,transform)local value=transform(copy(db[key]));if value then db[key]=copy(value)end;return copy(value)end}
		if seed then db.player_1=seed end
		return H.load(1,{rank=1},adapter),db,c
	end
	local ok,problem=pcall(function()
		for _,off in ipairs(OFF)do test("off ("..tostring(off).."): 200 shelf weeks, every Book page, every shop list and price, toys and eggs are the live build's",function()
			levels(off)
			shelf();book();eggs()
			for _,pet in ipairs({"pip","blip"})do assert(wearList(pet)==GOLD.wear,pet)end
			assert(priced(Balls.Order,Balls.price)==GOLD.balls and priced(Plates.Order,Plates.price)==GOLD.plates)
			assert(priced(Balls.listed({}),Balls.price)==GOLD.balls and priced(Plates.listed({}),Plates.price)==GOLD.plates and priced(Balls.listed(nil),Balls.price)==GOLD.balls)
			for _,tab in ipairs(Wear.Tabs)do
				local a,b=Wear.inTab("pip",tab.slot),Wear.shopTab("pip",tab.slot,{})
				assert(#a==#b);for index,item in ipairs(a)do assert(b[index]==item and item.gate==nil)end
			end
		end)end
		test("on: the shelf, the Book, toys and eggs are unchanged; every ungated id keeps its place and price",function()
			levels(true)
			shelf();book();eggs()
			for _,pet in ipairs({"pip","blip"})do assert(wearList(pet,true)==GOLD.wear,pet)end
			assert(priced(Balls.Order,Balls.price)==GOLD.balls and priced(Plates.Order,Plates.price)==GOLD.plates)
			local listed=Balls.listed({});assert(#listed==#Balls.Order+#Balls.Gated and listed[#Balls.Order+1]=="tangerine_pop")
			for _,id in ipairs(Balls.Order)do assert(Balls.ById[id].gate==nil,id)end
			for _,id in ipairs(Plates.Order)do assert(Plates.ById[id].gate==nil,id)end
			for _,item in ipairs(Wear.forPet("pip").order)do if not item.variant then assert(item.gate==nil,"a base design is never gated")end end
			local gated,all=0,0;for _,item in ipairs(Wear.forPet("pip").order)do all+=1;if item.gate then gated+=1 end end
			assert(gated==14 and gated*3<=all,"at most a third of the Wardrobe")
			for _,tab in ipairs(Wear.tabsFor("pip"))do assert(Wear.inTab("pip",tab.slot)[1].gate==nil,"the first row of "..tab.id)end
		end)
		for _,off in ipairs(OFF)do test("off ("..tostring(off).."): snapshot and save keys are the live build's, and a save with the new fields loads, plays and keeps them",function()
			levels(off)
			local h,db,c=fixture()
			assert(h.status=="Ready"and keys(H.public(h).statEgg)==GOLD.statEgg and keys(H.public(h).petStats)==GOLD.petStats)
			assert(keys(H.public(h))==GOLD.public,keys(H.public(h)))
			assert(keys(db.player_1.hatching)==GOLD.saved,keys(db.player_1.hatching))
			assert(H.parkPlay(h,"p1",1,"pip"))
			assert(db.player_1.hatching.medalEggsUsed==nil and db.player_1.deckJuice==nil)
			local seed=copy(db.player_1)
			seed.hatching.medalEggsUsed=3;seed.hatching.petStats={pip={jump=Stats.xpFor(99)}};seed.hatching.lease={token="",expiresAt=0}
			seed.hatching.petWearables={pip={owned={"beanie","beanie_rose"},equipped={Hat="beanie_rose"}}}
			seed.hatching.ballThemes={owned={"smileys","marbles","tangerine_pop"},equipped="tangerine_pop"}
			seed.hatching.faceplates={"sky_fizz","aqua_pop"} -- a plate this build has no row for
			seed.deckJuice={pop="fizz"};seed.deckJuiceAt=7;seed.deckJuiceWriter="w"
			local h2,db2=fixture(seed,c.now+200)
			assert(h2.status=="Ready"and H.public(h2).statEgg.free==0 and keys(H.public(h2).statEgg)==GOLD.statEgg)
			assert(H.parkPlay(h2,"p2",1,"pip"))
			local saved=db2.player_1
			assert(saved.hatching.medalEggsUsed==3 and saved.deckJuice.pop=="fizz"and saved.deckJuiceAt==7 and saved.deckJuiceWriter=="w")
			assert(saved.hatching.petWearables.pip.equipped.Hat=="beanie_rose"and saved.hatching.ballThemes.equipped=="tangerine_pop"and #saved.hatching.faceplates==2)
		end)end
		test("on: the snapshot adds one key (statEgg.medalEggs); nothing else moves and nothing new is saved by playing",function()
			levels(true)
			local h,db=fixture()
			assert(keys(H.public(h))==GOLD.public)
			local egg=H.public(h).statEgg;assert(egg.medalEggs==0);egg.medalEggs=nil;assert(keys(egg)==GOLD.statEgg)
			assert(H.parkPlay(h,"p1",1,"pip")and db.player_1.hatching.medalEggsUsed==nil and db.player_1.deckJuice==nil)
			assert(keys(S.publicLevels(h.state))=="pets v","the public attribute is unchanged")
		end)
	end)
	Levels.inject(nil)
	assert(ok,problem)
	return{passed=#cases,cases=cases}
end
