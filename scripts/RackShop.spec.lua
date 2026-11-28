-- The Outfit Egg in Hatch eggs, the client half (RackShop, GiftShop.aim, GiftChain, TeachLessons, GiftStage; ROTATION-
-- BRIEF sections 3 and 4, ARCH-REVIEW-ROTATION 1, 2, 7-12; switch daily_rack): the request binds what the player saw and
-- has a fresh id per press, a retry resends the very same request; every answer is handled kindly (a reveal, a fresh
-- snapshot, a kind line, the Stars card); the odds rows and the Today's picks sheet (order, rarity pills, owned marks,
-- the gift pinned first, the focus, 2/4 across and 6/8 live previews); the onboarding pointer's path (tile -> odds row
-- -> the sheet -> Hatch free!); the Outfit gift first in the chain; the Paint Egg's odds under look_daily / look_nopity.
-- Never a clock in any of the copy. Pure, no screen; the snapshot views are lane A's (DailyRack.view).
-- Offline: scripts/run_dash_server_specs.py. Studio: require(PlayerScripts.Client.ZZSpecs.RackShop)(PlayerScripts.Client).
return function(client)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Rack=require(client.RackShop)
	local GiftShop=require(client.GiftShop)
	local Chain=require(client.GiftChain)
	local Lessons=require(client.TeachLessons)
	local Stage=require(client.GiftStage)
	local Daily=require(Shared.DailyRack)
	local LookEgg=require(Shared.LookEggCatalog)
	local OddsText=require(Shared.OddsText)
	local Copy=require(Shared.UICopy)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local DAY=20420
	local function snapshot(owned,mode,over)
		local view=Daily.view("pip",DAY,owned or {},mode or "random")
		view.full=false
		local s={nectar=100,rack={day=DAY,price=Daily.Price,mode=view.mode,broken=false,outfit=view,pets={pip=view}}}
		for k,v in pairs(over or {})do s[k]=v end
		return s,view
	end

	test("the snapshot: the tile only with `rack`; the view is the pet that is out unless another is named",function()
		local s,view=snapshot()
		assert(Rack.on(s)and Rack.view(s)==view and Rack.view(s,"pip")==view)
		assert(not Rack.on({})and not Rack.on({rack=true})and Rack.view({})==nil,"off: no tile")
	end)

	test("the request: what the player saw, bound (day, price, mode, pool key), its own id; nil when it cannot be bought",function()
		local s,view=snapshot()
		local r=Rack.request(s.rack,view,"req-1",false)
		assert(r.id=="req-1"and r.egg=="outfit"and r.petId=="pip"and r.day==DAY and r.price==Daily.Price and r.mode=="random"
			and r.poolKey==view.poolKey and r.equip==false)
		assert(Rack.request(s.rack,view,"",false)==nil and Rack.request(s.rack,view,string.rep("x",101),false)==nil,"the id's length")
		local rest=table.clone(view);rest.rest=true
		assert(Rack.request(s.rack,rest,"a")==nil,"resting: nothing to buy")
		local full=table.clone(view);full.full=true
		assert(Rack.request(s.rack,full,"a")==nil,"the closet full: refused before the send")
		local broken=table.clone(s.rack);broken.broken=true
		assert(Rack.request(broken,view,"a")==nil)
		local nokey=table.clone(view);nokey.poolKey=nil
		assert(Rack.request(s.rack,nokey,"a")==nil)
	end)

	test("the button: Hatch at the price, short of Stars the card, resting and closet full say so kindly",function()
		local s=snapshot()
		local a=Rack.action(s)
		assert(a.enabled and a.text==Copy.get("rack.hatch",{count=Daily.Price}))
		local poor=snapshot(nil,nil,{nectar=3})
		assert(Rack.action(poor).short==Daily.Price-3 and not Rack.action(poor).enabled)
		local rest=snapshot();rest.rack.outfit.rest=true
		local b=Rack.action(rest)
		assert(not b.enabled and b.text==Copy.get("rack.restButton")and b.note==Copy.get("rack.rest"))
		local full=snapshot();full.rack.outfit.full=true
		assert(not Rack.action(full).enabled and Rack.action(full).note==Copy.get("rack.answer.full"))
	end)

	test("the buyer: a fresh id per press, one press out, other ids ignored, a retry resends the very same request",function()
		local sent,n,now={},0,0
		local buyer=Rack.buyer({id=function()n+=1;return "id"..n end,clock=function()return now end,send=function(r)table.insert(sent,r)end})
		local s=snapshot()
		local ok,first=buyer:press(s)
		assert(ok and first.id=="id1"and #sent==1)
		assert(not buyer:press(s),"a second press while one is out: refused (never two eggs)")
		assert(buyer:answer({action="rackEgg",id="other",status="Saved"})==nil,"another id: not this press's")
		assert(buyer:answer({action="wearableEquip",id="id1",status="Saved"})==nil,"another action")
		local o=buyer:answer({action="rackEgg",id="id1",status="Rejected",reason="Busy"})
		assert(o.kind=="retry"and buyer:busy())
		assert(buyer:resend()and #sent==2 and sent[2]==first and sent[2].id=="id1","the same request, the same id")
		o=buyer:answer({action="rackEgg",id="id1",status="Retrying",reason="Retrying"})
		assert(o.kind=="retry")
		-- the save landed meanwhile: the replay answers AlreadySaved with its record
		o=buyer:answer({action="rackEgg",id="id1",status="Saved",reason="AlreadySaved",rack={id="id1",item="beanie",rarity="common",pet="pip",day=DAY}})
		assert(o.kind=="reveal"and o.replay==true and o.record.item=="beanie"and o.view and not buyer:busy())
		local ok2,second=buyer:press(s)
		assert(ok2 and second.id=="id2","the next press: a new id")
		-- too many busy answers: a kind line, the press ends
		for _=1,Rack.Tries do assert(buyer:answer({action="rackEgg",id="id2",status="Rejected",reason="Throttled"}).kind=="retry")end
		o=buyer:answer({action="rackEgg",id="id2",status="Rejected",reason="Throttled"})
		assert(o.kind=="message"and o.text==Copy.get("rack.answer.busy")and not buyer:busy())
		-- no answer: resend (the same id) after Timeout, then let go
		local ok3,third=buyer:press(s);assert(ok3)
		assert(buyer:check(now+1)==nil)
		now+=Rack.Timeout
		local before=#sent
		assert(buyer:check(now).kind=="retry"and #sent==before+1 and sent[#sent].id==third.id)
		for _=2,Rack.Tries do now+=Rack.Timeout;buyer:check(now)end
		now+=Rack.Timeout
		assert(buyer:check(now).kind=="message"and not buyer:busy())
	end)

	test("the answers: every reason handled kindly, nothing charged but a reveal",function()
		local function kind(reason,status)return Rack.outcome({action="rackEgg",id="x",status=status or "Rejected",reason=reason})end
		assert(kind("DayChanged").kind=="refresh"and kind("DayChanged").text==Copy.get("rack.answer.day"))
		for _,r in ipairs({"PoolChanged","PriceChanged","PolicyChanged"})do
			assert(kind(r).kind=="refresh"and kind(r).text==Copy.get("rack.answer.changed"),r)
		end
		assert(kind("RackDone").kind=="message"and kind("RackDone").text=="All picked for today — new picks tomorrow")
		assert(kind("ClosetFull").text==Copy.get("rack.answer.full")and kind("NeedStars").kind=="stars")
		assert(kind("RevealPending").text==Copy.get("rack.answer.reveal"))
		for _,r in ipairs({"Busy","Throttled","Pending","Unavailable"})do assert(kind(r).kind=="retry",r)end
		assert(kind(nil,"Retrying").kind=="retry")
		assert(kind("RackBroken").kind=="message"and kind("InvalidRack").text==Copy.get("rack.answer.oops"))
		assert(kind("AlreadySaved","Saved").kind=="refresh","saved long ago (not the last): a fresh snapshot")
		local saved=Rack.outcome({status="Saved",reason="Saved",rack={item="tee",rarity="rare"}})
		assert(saved.kind=="reveal"and saved.replay==false)
	end)

	test("the odds rows: unowned first by rarity, the sparkle pick after them, owned last as Yours; the odds add up",function()
		local _,fresh=snapshot()
		local owned={fresh.items[1].id,fresh.items[2].id}
		local _,view=snapshot(owned)
		local odds=Rack.rows(view)
		assert(odds.label==Copy.get("rack.label")and odds.per==Copy.get("rack.line"))
		local rows={}
		for _,r in ipairs(odds.rows)do if not r.info then table.insert(rows,r)end end
		assert(#rows==#view.items+(if view.sparkle then 1 else 0))
		local seenOwned,seenSparkle,lastRank=false,false,0
		local chances={}
		for _,r in ipairs(rows)do
			assert(r.tap==true and r.pill==Copy.get("rack.rarity."..r.rarity)and type(r.color)=="string")
			if r.owned then seenOwned=true;assert(r.value==Copy.get("rack.yours"))
			else
				assert(not seenOwned,"owned ones last")
				if r.sparkle then seenSparkle=true;assert(r.rarity=="legendary")
				else
					assert(not seenSparkle,"the sparkle pick after the picks")
					assert(Rack.Rank[r.rarity]>=lastRank,"common first");lastRank=Rack.Rank[r.rarity]
				end
			end
		end
		-- the values are OddsText.list over the exact units, in the shown order
		local list=Rack.entries(view)
		for i,e in ipairs(list)do chances[i]=if e.owned then 0 else e.units/view.total end
		local texts=OddsText.list(chances)
		for i,r in ipairs(rows)do if not r.owned then assert(r.value==texts[i],r.id..": "..r.value.." vs "..texts[i])end end
		local whole=0
		for _,r in ipairs(rows)do local n=tonumber(string.match(r.value,"^(%d+)%%$"));if n then whole+=n end end
		assert(whole==100 or odds.rounded,"whole percents add up (or the rounded note shows)")
		if odds.rounded then assert(odds.rows[#odds.rows].info and odds.rows[#odds.rows].id=="rounded")end
		-- restricted players never roll: the next pick only
		local _,fixed=snapshot(nil,"fixed")
		local f=Rack.rows(fixed)
		assert(f.restricted and #f.rows==1 and f.rows[1].id==fixed.next and f.label==Copy.get("hatch.next.label"))
		-- every pick owned: the egg rests and says so
		local all={};for _,item in ipairs(fresh.items)do table.insert(all,item.id)end
		local _,done=snapshot(all)
		assert(done.rest and Rack.rows(done).note==Copy.get("rack.rest"))
	end)

	test("the sheet: the rows' order, rarity pills, Yours, the gift pinned first at 100%, the focus, 2/4 across, 6/8 live",function()
		local _,fresh=snapshot()
		local _,view=snapshot({fresh.items[1].id})
		local sheet=Rack.sheet(view,{focus=view.items[3].id,phone=false})
		assert(sheet.title==Copy.get("rack.title")and sheet.line=="New picks every day"and sheet.footer=="Missed one? They come back.")
		assert(sheet.columns==4 and sheet.live==8 and sheet.button==Copy.get("rack.close"))
		local rows=Rack.rows(view).rows
		for i,c in ipairs(sheet.cards)do
			assert(c.id==rows[i].id and c.value==rows[i].value and c.wear==c.id,"the same order as the rows")
			assert(c.pillColor==Rack.Pill[c.rarity])
		end
		assert(sheet.cards[sheet.focus].id==view.items[3].id,"the tapped row's card")
		local last=sheet.cards[#sheet.cards]
		assert(last.owned and last.value==Copy.get("rack.yours"))
		local phone=Rack.sheet(view,{phone=true,gift="beanie"})
		assert(phone.columns==2 and phone.live==6 and phone.button==Copy.get("rack.gotIt"))
		assert(phone.cards[1].gift and phone.cards[1].id=="beanie"and phone.cards[1].value=="100%"and phone.cards[1].pill==Copy.get("rack.gift"))
		local beanies=0;for _,c in ipairs(phone.cards)do if c.id=="beanie"then beanies+=1 end end
		assert(beanies==1,"the gift is never listed twice")
		assert(Rack.sheet(nil,{gift="beanie",petId="pip"}).cards[1].id=="beanie","no rack view yet: the gift alone")
	end)

	test("a preview wears the item over the pet's look: its slot emptied first, nothing saved",function()
		local base={wearables={Hat="partyhat",Other="kept"},body="rose"}
		local a=Rack.wearing(base,"pip","beanie")
		assert(a.wearables.Hat=="beanie"and a.wearables.Other=="kept"and a.body=="rose")
		assert(base.wearables.Hat=="partyhat","the look itself untouched")
	end)

	test("the onboarding pointer: the Outfit tile, an odds row, the sheet's button, then Hatch free!; Paint unchanged",function()
		local ctx={gift="outfit",selected="outfit"}
		assert(GiftShop.Tile.outfit=="outfit")
		assert(GiftShop.aim(ctx)=="tile")
		ctx.picked=true;assert(GiftShop.aim(ctx)=="odds","picked: an odds row (Tap to see today's picks!)")
		ctx.sheetOpen=true;assert(GiftShop.aim(ctx)=="sheet","the sheet up: its button")
		ctx.sheetOpen=false;ctx.oddsDone=true;assert(GiftShop.aim(ctx)=="hatch","closed: Hatch free!")
		assert(GiftShop.route({gift="outfit",selected="outfit"})=="gift","Hatch free! works at any step")
		assert(GiftShop.aim({gift="paint",selected="look",picked=true})=="hatch","the Paint gift as before")
		assert(GiftShop.mode("outfit",{gifts={owed=true,ready="outfit",granted={}}},{"toy","outfit","look"})=="outfit")
		assert(GiftShop.mode("outfit",{gifts={owed=true,ready="outfit",granted={}}},{"toy","look"})==nil,"the rack off: no tile, no gift mode")
		assert(Copy.get("rack.teach.odds")=="Tap to see today's picks!")
	end)

	test("the chain: the Outfit gift first (the tuck's place), the deck lesson may follow it before the Paint gift",function()
		local f=Chain.facts({nectar=0,totalWins=0,coachMask=0,stats={rounds=0},toyUnlocks={},gifts={owed=true,granted={},ready="outfit"}})
		assert(Chain.next(f)=="outfit"and Chain.giftOf("outfit",f)=="outfit"and Chain.shopGift(f,nil)=="outfit")
		assert(Chain.rules(false).exempt.outfit and Chain.rules(true).exempt.outfit)
		local after=Chain.facts({nectar=0,totalWins=0,coachMask=0,stats={rounds=0},toyUnlocks={},gifts={owed=true,granted={outfit=true}}},
			{teach=true,deckNext=true})
		assert(Chain.next(after)=="deck","after the Outfit gift: the deck invite")
		local paint=Chain.facts({nectar=0,totalWins=0,coachMask=0,stats={rounds=2},toyUnlocks={},gifts={owed=true,granted={outfit=true},ready="paint"}})
		assert(Chain.next(paint)=="paint","then the Paint gift")
		local off=Chain.facts({nectar=0,totalWins=0,coachMask=0,stats={rounds=0},toyUnlocks={},gifts={owed=true,granted={}}},{teach=true,deckNext=true})
		assert(Chain.next(off)==nil,"off (no outfit record, no paint): as before")
		local l=Lessons.facts({gifts={owed=true,granted={outfit=true}},stats={rounds=0},toyUnlocks={},petHues={}},{teach=true})
		assert(l.outfitSeen and Lessons.ready("deck",l,{}),"the deck lesson opens after the Outfit gift")
		local unseen=Lessons.facts({gifts={owed=true,granted={outfit=true},unseen={kind="outfit"}},stats={rounds=0},toyUnlocks={},petHues={}},{teach=true})
		assert(not unseen.outfitSeen and not Lessons.ready("deck",unseen,{}),"its card not seen yet: not yet")
	end)

	test("the reveal: the gift and a paid egg play on the hatch stage, worn on the pet, with its rarity and keys",function()
		local function text(key,vars)local s=key;for k,v in pairs(vars or {})do s..="|"..k.."="..tostring(v)end;return s end
		local look={wearables={Hat="beanie"}}
		local r,recipe=Stage.result({kind="rack",id="op1",item="tee_berry",rarity="rare",pet="pip"},{wearAppearance=look})
		assert(recipe=="hue"and r.wearableId=="tee_berry"and r.itemId=="tee_berry"and r.wearPet=="pip"and r.rarity=="rare"and r.wearAppearance==look)
		local w=Stage.words({kind="rack",item="tee_berry",rarity="rare"},{text=text,itemName="Berry Tee",detail="Rare · 6%"})
		assert(w.sticker=="rack.sticker.rare"and w.name=="Berry Tee"and w.detail=="Rare · 6%"and w.primary=="rack.reveal.wear"and w.secondary=="rack.reveal.later")
		local g=Stage.words({kind="outfit",item="beanie"},{text=text,pet="Bear",itemName="Pom Beanie"})
		assert(g.sticker=="onbGift.card.from|pet=Bear"and g.detail=="rack.gift.per"and g.primary=="rack.gift.cute"and g.secondary==nil,"worn already: one key")
		assert(Copy.get("rack.gift.per")=="A gift: 100%"and Copy.get("rack.gift.note")=="New picks every day!")
	end)

	test("the Paint Egg's odds: today's table off; look_daily's splash at 23%, the rest 15; look_nopity: no guarantee, no count",function()
		local missing=LookEgg.missing(nil)
		local off=Rack.lookTable({})
		assert(off.day==nil and not off.noPity and off.splash==nil)
		for i,row in ipairs(LookEgg.odds(missing)or {})do assert(off.rows[i].percent==row.percent)end
		local daily=Rack.lookTable({lookDay=DAY})
		local splash=LookEgg.splashOf(DAY)
		assert(daily.day==DAY and daily.splash==splash)
		for _,row in ipairs(daily.rows)do
			if LookEgg.kind(row.id)=="hue"then assert(row.percent==(if row.id==splash then LookEgg.Splash else 15),row.id)end
		end
		local nearPity=LookEgg.PityAt-1
		assert(Rack.lookTable({lookCharmMisses=nearPity}).due,"pity on: the guaranteed charm")
		local none=Rack.lookTable({lookCharmMisses=nearPity,lookNoPity=true})
		assert(none.noPity and not none.due and none.left==nil,"no pity: never guaranteed, no 'charm in N'")
		local rows={{id=splash,name="Splash",value="23%"},{id="charm",name="Charms",value="2%"},{id="pity",name="x",value="",info=true}}
		local sheet=Rack.paintSheet(rows,{lookDay=DAY},{petId="pip"})
		assert(#sheet.cards==2 and sheet.cards[1].paint==splash and sheet.cards[1].pill==Copy.get("rack.splash")and sheet.cards[2].kind=="charm")
		assert(sheet.line==Copy.get("rack.paintDaily")and Rack.paintSheet(rows,{},{}).line==Copy.get("rack.paintLine"))
		assert(Rack.paintSheet(rows,{},{}).cards[1].pill==nil,"look_daily off: no splash pill")
	end)

	test("kid safety: no clock in any rack word (no countdown, timer, hours, minutes, 'left', 'last chance', 'only today')",function()
		for _,key in ipairs(Copy.keys())do
			if string.sub(key,1,5)=="rack."or key=="hatch.egg.outfit.line"or key=="hatch.egg.outfit.description"then
				local s=string.lower(Copy.get(key))
				for _,bad in ipairs({"hour","minute","second","{h","left","last chance","only today","hurry","ends","expire","timer"})do
					assert(not string.find(s,bad,1,true),key..": "..bad)
				end
			end
		end
	end)

	return {passed=#cases,cases=cases}
end
