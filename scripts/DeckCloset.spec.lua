-- Deck style as a closet (rotation slice 2, lane D; ROTATION-2-BRIEF 2 "Deck style with the switch on", ARCH-REVIEW-
-- ROTATION-2 6 and 7). The pure rules FaceplateShop (Shell) and BallShop (Balls) share (DeckCloset): which rows come
-- from the Deck Egg (the brief's 12 plates and 11 ball themes, nothing else), what an unowned one says and offers, the
-- earned and level-goal rows untouched, no weekly-shelf deal while on, the footer's words, and the switch (rack and its
-- deck part; a build without the deck part is today's shop).
-- Offline: scripts/run_dash_server_specs.py (client). Studio: require(PlayerScripts.Client.ZZSpecs.DeckCloset)(Client).
return function(client)
	local Closet=require(client.DeckCloset)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Plates=require(Shared.DeckThemes)
	local Balls=require(Shared.BallThemes)
	local Rack=require(Shared.DailyRack)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function same(list,expected)
		local seen={}
		for _,id in ipairs(list)do assert(not seen[id],"duplicate "..id);seen[id]=true end
		for _,id in ipairs(expected)do assert(seen[id],"missing "..id);seen[id]=nil end
		local extra=next(seen);assert(extra==nil,"not in the brief: "..tostring(extra))
	end
	local PlateTiers={common={"aqua_pop","lime_gel","sorbet_sky","grape_soda"},
		rare={"liquid_chrome","tidepool","aurora_glass","rose_chrome","lagoon","dewy_meadow"},showcase={"prism_flare","night_orb"}}
	local BallTiers={common={"gumdrops","pea_soup","pocket_grey"},rare={"gems","planets","bubbles","amber","deep_sea","bubblegum"},
		showcase={"kittens","midnight"}}
	local function flat(tiers)local out={};for _,tier in pairs(tiers)do for _,id in ipairs(tier)do table.insert(out,id)end end;return out end

	test("the Deck Egg's rows: the brief's 12 plates and 11 ball themes, each in its tier",function()
		local plates,balls=Closet.eggIds("plate"),Closet.eggIds("ball")
		assert(#plates==12 and #balls==11,"12 plates and 11 themes: "..#plates.." / "..#balls)
		same(plates,flat(PlateTiers));same(balls,flat(BallTiers))
		for tier,ids in pairs(PlateTiers)do for _,id in ipairs(ids)do assert(Plates.ById[id].tier==tier,id)end end
		for tier,ids in pairs(BallTiers)do for _,id in ipairs(ids)do assert(Balls.ById[id].tier==tier,id)end end
		assert(#Closet.eggIds("background")==0 and not Closet.fromEgg("plate","nope")and not Closet.fromEgg("ball",nil))
	end)

	test("stays earned or sold: starters, the Book plates and the level-goal rows never say Deck Egg",function()
		for _,id in ipairs({"sherbet","stone","ice","brick","moss","honey","gloaming","copperleaf","cloud_glass","bookworm","stargazer","sky_fizz","storm_glass"})do
			assert(Plates.ById[id],"catalogue "..id)
			assert(not Closet.fromEgg("plate",id),id)
			assert(Closet.status("plate",id,false,true)==nil,id)
		end
		for _,id in ipairs({"smileys","marbles","tangerine_pop"})do
			assert(Balls.ById[id],"catalogue "..id)
			assert(not Closet.fromEgg("ball",id),id)
			assert(Closet.status("ball",id,false,true)==nil,id)
		end
		-- Every catalogue row is one or the other: sold at a fixed price with no gate is the egg's, the rest keep their rules.
		for id,theme in pairs(Plates.ById)do
			assert(Closet.fromEgg("plate",id)==(Plates.price(id)~=nil and theme.gate==nil),id)
		end
		for id,entry in pairs(Balls.ById)do
			assert(Closet.fromEgg("ball",id)==(Balls.price(id)~=nil and entry.gate==nil),id)
		end
	end)

	test("on: an unowned egg row says From the Deck Egg with one button; owned rows and the switch off are untouched",function()
		for _,kind in ipairs({"plate","ball"})do
			for _,id in ipairs(Closet.eggIds(kind))do
				local s=Closet.status(kind,id,false,true)
				assert(s and s.kind=="egg"and s.enabled==true,kind.." "..id)
				assert(s.text==Closet.copy("fromEgg")and s.button==Closet.copy("go"))
				assert(s.price==nil,"no price on an egg row")
				assert(Closet.status(kind,id,true,true)==nil,"owned: wearable as before")
				assert(Closet.status(kind,id,false,false)==nil and Closet.status(kind,id,false,nil)==nil,"off: today's shop")
			end
		end
		local text,role=Closet.tileStatus();assert(text==Closet.copy("tile")and role=="soft")
		assert(Closet.copy("fromEgg")~=""and Closet.copy("go")~=""and Closet.copy("nope")=="")
	end)

	test("no weekly-shelf deal in the closet; off, the shelf week passes through",function()
		local week={id=1}
		assert(Closet.week(true,week)==false)
		assert(Closet.week(false,week)==week and Closet.week(nil,week)==week and Closet.week(nil,nil)==nil)
	end)

	test("the words: the footer's promise, the refusal, and never a clock or a fixed-price promise",function()
		assert(Closet.promise(false,"Fixed prices. No random plates.")=="Fixed prices. No random plates.","off: today's footer")
		local on=Closet.promise(true,"Fixed prices. No random plates.")
		assert(on==Closet.copy("promise")and on~="")
		assert(Closet.reason("FromDeckEgg")==Closet.copy("reason")and Closet.reason("NeedStars")==nil and Closet.reason(nil)==nil)
		for name in pairs(Closet.Copy)do
			local text=string.lower(Closet.copy(name))
			for _,banned in ipairs({"fixed price","random","only today","last chance","left","hour","minute","tomorrow","hurry"})do
				assert(not string.find(text,banned,1,true),name..": "..banned)
			end
		end
	end)

	test("the switch: the rack and its deck part; a build without the deck part is today's shop",function()
		assert(Closet.resolve(true)==true and Closet.resolve(false)==false,"an explicit flag wins")
		assert(Rack.inject({flags={DailyRack=true},studio=true}),"inject needs Studio (or the offline mocks)")
		if Rack.Attributes.deck==nil then
			-- Before lane A's switch: DailyRack.on("deck") is an unknown part, so off.
			assert(Closet.on()==false and Closet.resolve(nil)==false)
		else
			assert(Rack.inject({flags={DailyRack=true},studio=true,deck=true}))
			assert(Closet.on()==true and Closet.resolve(nil)==true,"rack and deck on")
			assert(Rack.inject({flags={DailyRack=true},studio=true,deck=false}))
			assert(Closet.on()==false,"deck off")
			assert(Rack.inject({flags={DailyRack=true},studio=true,rack=false,deck=true}))
			assert(Closet.on()==false,"the rack off closes nothing")
			assert(Rack.inject({flags={DailyRack=false},studio=false,place=0,deck=true}))
			assert(Closet.on()==false,"over the build ceiling")
		end
		Rack.inject(nil)
	end)

	return {passed=#cases,cases=cases}
end
