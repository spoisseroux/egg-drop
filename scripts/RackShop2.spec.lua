-- Rotation slice 2, lane B (ROTATION-2-BRIEF 1-5, ARCH-REVIEW-ROTATION-2 5, 7; LANE-B-INPUTS): the Toy Colour Egg and
-- the Deck Egg in Hatch eggs and Angel Wings on the Outfit Egg's sparkle pick, the client half. The tiles' gating and
-- order, each egg's request (its own price, the pet that is out, the Outfit request unchanged), the buttons' rest and
-- full lines, every refusal's kind line, the odds rows per egg (lane A's real views: ToySkins.view, DeckRack.view,
-- DailyRack.view on a wings day), the sheet's card kinds (toy, plate, ball), the reveal's stage records and words, and
-- every copy key the lanes use. Kid safety: no clock word in any of it. Pure, no screen.
-- Offline: scripts/run_dash_server_specs.py. Studio: require(PlayerScripts.Client.ZZSpecs.RackShop2)(PlayerScripts.Client).
return function(client)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Rack=require(client.RackShop)
	local Stage=require(client.GiftStage)
	local Closet=require(client.DeckCloset)
	local Daily=require(Shared.DailyRack)
	local Skins=require(Shared.ToySkins)
	local Deck=require(Shared.DeckRack)
	local Plates=require(Shared.DeckThemes)
	local Copy=require(Shared.UICopy)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local DAY=20420
	local BASE={"toy","look","stat"}
	-- A snapshot as RackState.public draws it: the outfit view, the toy and deck eggs while their switches are on.
	local function snapshot(o)
		o=o or {}
		local outfit=Daily.view("pip",o.day or DAY,{},o.mode or "random",o.wings)
		outfit.full=false
		local rack={day=o.day or DAY,price=Daily.Price,mode=outfit.mode,broken=false,outfit=outfit,pets={pip=outfit}}
		local unlocks=o.unlocks or {ball=true,bone=true,sparkler=true,wobble_top=true,squeaky_carrot=true,pocket_deck=true}
		if o.toy~=false then
			local toy=Skins.view(o.day or DAY,unlocks,o.skins or {},o.mode or "random")
			toy.price=Skins.Price;toy.broken=false;toy.full=false;toy.owned=o.skins or {};toy.worn={}
			rack.toy=toy
		end
		if o.deck~=false then
			local deck=Deck.view(o.day or DAY,o.plates or {},o.balls or {"smileys","marbles"},o.mode or "random")
			deck.price=Deck.Price;deck.closet=true
			rack.deck=deck
		end
		return {nectar=o.nectar or 500,toyUnlocks=unlocks,gifts=o.gifts,rack=rack}
	end
	local function sum(rows)
		local total=0
		for _,r in ipairs(rows)do
			local n=tonumber(string.match(r.value or "","^([%d%.]+)%%$"))
			if n then total+=n end
		end
		return total
	end

	test("the tiles: the Toy Colour Egg once a toy is owned, the Deck Egg once the Snack gift is recorded; off without their views",function()
		local s=snapshot()
		local tiles=Rack.tiles(s)
		assert(table.concat(tiles,",")=="outfit,toycolour,deck",table.concat(tiles,","))
		assert(table.concat(Rack.order(BASE,s),",")=="toy,toycolour,outfit,look,deck,stat",table.concat(Rack.order(BASE,s),","))
		local noToys=snapshot({unlocks={}})
		assert(table.concat(Rack.tiles(noToys),",")=="outfit,deck","no toy owned: no Toy Colour Egg")
		assert(not Rack.ownsToy({toyUnlocks={none=true}})and Rack.ownsToy({toyUnlocks={ball=true}}),"the default 'none' is not a toy")
		local owed=snapshot({gifts={owed=true,granted={paint=true,toy=true,outfit=true}}})
		assert(table.concat(Rack.tiles(owed),",")=="outfit,toycolour","the chain not done: no Deck Egg")
		local fed=snapshot({gifts={owed=true,granted={snack=true}}})
		assert(table.find(Rack.tiles(fed),"deck"),"the Snack gift recorded: the Deck Egg")
		local record=snapshot({gifts={owed=true,granted={},snack={kind="snack",item="x"}}})
		assert(table.find(Rack.tiles(record),"deck"),"a Snack record counts")
		assert(table.find(Rack.tiles(snapshot({gifts={owed=false}})),"deck"),"a save never owed the chain waits for nothing")
		local off=snapshot({toy=false,deck=false})
		assert(table.concat(Rack.tiles(off),",")=="outfit","rack_toys / rack_deck off: no views, no tiles")
		assert(#Rack.tiles({})==0 and Rack.order(BASE,{})==BASE,"no rack: today's list exactly")
		assert(Rack.isTile("deck")and Rack.isTile("toycolour")and Rack.isTile("outfit")and not Rack.isTile("toy"))
		assert(Rack.New.toycolour and Rack.New.deck and not Rack.New.outfit,"the New dot: the two new tiles only")
	end)

	test("the requests: each egg its id, its own price and the pet that is out; the Outfit request is slice 1's",function()
		local s=snapshot()
		local outfit=Rack.request(s.rack,s.rack.outfit,"o1",false)
		assert(outfit.egg=="outfit"and outfit.price==Daily.Price and outfit.petId=="pip"and outfit.poolKey==s.rack.outfit.poolKey,"no egg = outfit")
		local toy=Rack.request(s.rack,s.rack.toy,"t1",false,"toycolour","pip")
		assert(toy.egg=="toycolour"and toy.price==Skins.Price and toy.petId=="pip"and toy.day==DAY and toy.mode=="random"
			and toy.poolKey==s.rack.toy.poolKey,"the Toy Colour Egg: 15 Stars, its pool key")
		local deck=Rack.request(s.rack,s.rack.deck,"d1",true,"deck","pip")
		assert(deck.egg=="deck"and deck.price==Deck.Price and deck.equip==true and deck.poolKey==s.rack.deck.poolKey)
		assert(Rack.request(s.rack,s.rack.toy,"t2",false,"toycolour",nil)==nil,"no pet out: nothing sent")
		local full=table.clone(s.rack.deck);full.full=true
		assert(Rack.request(s.rack,full,"d2",false,"deck","pip")==nil,"a full shelf: refused before the send")
		local broken=table.clone(s.rack.toy);broken.broken=true
		assert(Rack.request(s.rack,broken,"t3",false,"toycolour","pip")==nil,"a malformed rack.toy: refused")
		-- the buyer: the pet that is out comes from the rack when none is given
		local sent={}
		local buyer=Rack.buyer({id=function()return "id"..(#sent+1)end,clock=function()return 0 end,send=function(r)table.insert(sent,r)end})
		local ok,r=buyer:press(s,nil,false,"toycolour")
		assert(ok and r.egg=="toycolour"and r.petId=="pip"and #sent==1)
		assert(not buyer:press(s,nil,false,"deck"),"one rack press at a time, any egg")
		assert(buyer:answer({action="rackEgg",id=r.id,status="Rejected",reason="ShelfFull"}).text==Copy.get("rack.deck.full"))
		assert(Rack.price(s,"toycolour")==15 and Rack.price(s,"deck")==60 and Rack.price(s,"outfit")==Daily.Price)
	end)

	test("the buttons: Hatch at each egg's price; resting and full say so kindly, per egg",function()
		local s=snapshot()
		assert(Rack.action(s,"toycolour").text==Copy.get("rack.hatch",{count=15})and Rack.action(s,"deck").enabled)
		local poor=snapshot({nectar=20})
		assert(Rack.action(poor,"deck").short==40 and Rack.action(poor,"toycolour").enabled)
		local rest=snapshot();rest.rack.toy.rest=true;rest.rack.deck.rest=true
		local a,b=Rack.action(rest,"toycolour"),Rack.action(rest,"deck")
		assert(not a.enabled and a.text==Copy.get("rack.toy.restButton")and a.note==Copy.get("rack.toy.rest"))
		assert(not b.enabled and b.text==Copy.get("rack.deck.restButton")and b.note==Copy.get("rack.deck.rest"))
		local full=snapshot();full.rack.deck.full=true
		assert(Rack.action(full,"deck").note==Copy.get("rack.deck.full")and not Rack.action(full,"deck").enabled)
		assert(Rack.action(snapshot({deck=false}),"deck").text==Copy.get("rack.notReady"),"no view: not ready")
	end)

	test("every refusal has a kind line, nothing charged; RackDone speaks for its own egg",function()
		local function o(reason,egg)return Rack.outcome({action="rackEgg",id="x",status="Rejected",reason=reason},egg)end
		local oops=Copy.get("rack.answer.oops")
		for _,reason in ipairs({"ClosetFull","ShelfFull","LockedToy","FromDeckEgg","RackBroken","Unowned","NotOwned","RevealPending","NotReady"})do
			local out=o(reason)
			assert(out.kind=="message"and type(out.text)=="string"and out.text~=""and out.text~=oops,reason)
		end
		assert(o("ShelfFull").text=="Your shelf is full."and o("LockedToy").text=="Get this toy from the Toy Egg")
		for _,reason in ipairs({"DayChanged","PoolChanged","PriceChanged","PolicyChanged","AlreadyOwned"})do
			assert(o(reason).kind=="refresh"and o(reason).text,reason)
		end
		for _,reason in ipairs({"Busy","Throttled","Pending","Unavailable"})do assert(o(reason).kind=="retry",reason)end
		assert(o("NeedStars").kind=="stars")
		assert(o("RackDone").text==Copy.get("rack.answer.done")and o("RackDone","toycolour").text==Copy.get("rack.toy.rest")
			and o("RackDone","deck").text==Copy.get("rack.deck.rest"))
		assert(o("InvalidRack").text==oops and o("Mystery").text==oops,"anything else: the kind fallback")
		for reason,key in pairs(Rack.Said)do assert(Copy.has(key),reason..": "..key)end
	end)

	test("the Toy Colour Egg's rows: each colour's dot, odds from the exact units adding up, a locked toy last but owned",function()
		local s=snapshot({unlocks={ball=true,bone=true,sparkler=true,wobble_top=true,squeaky_carrot=true,pocket_deck=true}})
		local odds=Rack.rows(s.rack.toy,"toycolour")
		assert(odds.label==Copy.get("rack.toy.label")and odds.per==Copy.get("rack.toy.line")and odds.egg=="toycolour")
		local real=0
		for _,r in ipairs(odds.rows)do
			if not r.info then
				real+=1
				local row=Skins.ById[r.id]
				assert(row and r.name==row.name and r.color==row.hex and r.pill==Rack.rarityName(r.rarity)and r.tap,r.id)
			end
		end
		assert(real==#s.rack.toy.items,"one row a pick")
		assert(math.abs(sum(odds.rows)-100)<1.5,"the shares add up: "..sum(odds.rows))
		-- a pick whose toy is not owned: drawn locked, 0 units, after the ones you can get, never a percent
		local picks=Skins.picks(DAY)
		local lockedToy=picks[1].toy
		-- only the other two dealt toys owned: no undealt owned toy can take the locked pick's place (ToySkins.picks)
		local unlocks={[picks[2].toy]=true,[picks[3].toy]=true}
		local some=snapshot({unlocks=unlocks})
		local list=Rack.entries(some.rack.toy)
		local seenLocked=false
		for _,e in ipairs(list)do
			if e.locked then seenLocked=true elseif seenLocked then assert(e.owned,"locked picks sit after the ones you can get")end
		end
		assert(seenLocked,"the locked pick is drawn")
		local rows=Rack.rows(some.rack.toy,"toycolour").rows
		for _,r in ipairs(rows)do
			if r.locked then assert(r.value==Copy.get("rack.toy.lockedTag"),"locked: no percent")end
		end
	end)

	test("the Deck Egg's rows and sheet: plates in their accent on the handheld, ball themes as five balls, owned 'Yours'",function()
		local s=snapshot()
		local odds=Rack.rows(s.rack.deck,"deck")
		assert(odds.label==Copy.get("rack.deck.label")and math.abs(sum(odds.rows)-100)<1.5)
		for _,r in ipairs(odds.rows)do
			if not r.info then
				local row=Deck.ById[r.id]
				assert(row and r.name==row.name,r.id)
				if row.kind=="plate"then assert(r.color==Plates.ById[r.id].accent,"a plate's dot is its accent")end
				assert(r.rarity~="legendary","no legendary in the Deck Egg")
			end
		end
		local first=s.rack.deck.items[1].id
		local sheet=Rack.sheet(s.rack.deck,{egg="deck",focus=first})
		assert(sheet.kind=="deck"and sheet.title==Copy.get("rack.deck.title")and sheet.line==Copy.get("rack.deck.line")and sheet.footer==Copy.get("rack.back"))
		local plates,balls=0,0
		for _,c in ipairs(sheet.cards)do
			assert(c.wear==nil,"no pet preview for a deck pick")
			if c.kind=="plate"then plates+=1;assert(c.plate==c.id and c.accent==Plates.ById[c.id].accent)
			elseif c.kind=="ball"then balls+=1;assert(c.ball==c.id)end
		end
		assert(plates==2 and balls==2,"2 plates and 2 ball themes a day")
		assert(sheet.cards[sheet.focus].id==first,"the tapped row's card first")
		local owned=snapshot({plates={s.rack.deck.items[1].id}})
		local card
		for _,c in ipairs(Rack.sheet(owned.rack.deck,{egg="deck"}).cards)do if c.id==first then card=c end end
		assert(card and card.owned and card.value==Copy.get("rack.yours"))
		assert(Rack.sheet(owned.rack.deck).kind=="deck","the egg is read from the view's shape when not named")
	end)

	test("the Toy Colour Egg's sheet: the toy in that colour; a locked toy says where it comes from",function()
		local picks=Skins.picks(DAY)
		local unlocks={[picks[2].toy]=true,[picks[3].toy]=true} -- no undealt owned toy to take the locked place
		local s=snapshot({unlocks=unlocks})
		local sheet=Rack.sheet(s.rack.toy,{egg="toycolour"})
		assert(sheet.kind=="toycolour"and sheet.title==Copy.get("rack.toy.title")and #sheet.cards==#s.rack.toy.items)
		local locked=0
		for _,c in ipairs(sheet.cards)do
			local row=Skins.ById[c.id]
			assert(c.kind=="toy"and c.toy==row.toy and c.skin==c.id and c.color==row.hex,c.id)
			if c.locked then locked+=1;assert(c.value==Copy.get("rack.toy.locked"))end
		end
		assert(locked>=1)
		assert(Rack.sheet(s.rack.toy).kind=="toycolour")
	end)

	test("Angel Wings: on a wings day the sparkle row and card are Angel Wings, legendary, a flat 1%",function()
		local day=DAY
		while not Daily.wingsDay(day)do day+=1 end
		local s=snapshot({day=day,wings=true})
		local v=s.rack.outfit
		assert(v.sparkle and v.sparkle.id=="angelwings"and v.sparkle.wings,"lane A deals the wings on a wings day")
		local row
		for _,r in ipairs(Rack.rows(v).rows)do if r.id=="angelwings"then row=r end end
		assert(row and row.sparkle and row.wings and row.rarity=="legendary"and row.name=="Angel Wings"and row.value=="1%",row and row.value)
		assert(row.pill==Copy.get("rack.rarity.legendary"))
		local card
		for _,c in ipairs(Rack.sheet(v,{}).cards)do if c.id=="angelwings"then card=c end end
		assert(card and card.wear=="angelwings"and card.sparkle and card.name=="Angel Wings"and card.value=="1%")
		local plain=snapshot({day=day,wings=false}).rack.outfit
		assert(not plain.sparkle or plain.sparkle.id~="angelwings","rack_wings off: the slice 1 sparkle")
	end)

	test("the reveal: each egg's stage record and words (Use it!), the Outfit Egg's unchanged",function()
		local toyRow=Skins.Rows[1]
		local r,egg=Rack.stageRecord({id="a",egg="toycolour",pet="pip",item=toyRow.id,rarity="rare"})
		assert(egg=="toycolour"and r.kind=="rackToy"and r.toy==toyRow.toy and r.item==toyRow.id)
		local result,recipe=Stage.result(r,{})
		assert(recipe=="toy"and result.toyId==toyRow.toy and result.toySkin==toyRow.id and result.rarity=="rare","the Toy Egg's reveal, in that colour")
		local text=function(key,vars)return Copy.get(key,vars)end
		local w=Stage.words(r,{text=text,itemName=toyRow.name,detail="Rare · 16.7%"})
		assert(w.primary==Copy.get("rack.toy.use")and w.primary=="Use it!"and w.sticker==Copy.get("rack.sticker.rare")and w.secondary==Copy.get("rack.reveal.later"))
		local d=Rack.stageRecord({id="b",egg="deck",pet="pip",item="aqua_pop",rarity="common",kind="plate"})
		assert(d.kind=="rackDeck"and d.deckKind=="plate")
		assert(Rack.stageRecord({id="c",egg="deck",item="gems",rarity="rare"}).deckKind=="ball","the kind from DeckRack when the record lacks it")
		local dr,drecipe=Stage.result(d,{})
		assert(drecipe=="hue"and dr.itemId=="aqua_pop"and dr.deckItem=="aqua_pop"and dr.deckKind=="plate")
		assert(Stage.words(d,{text=text}).primary==Copy.get("rack.deck.use"))
		local o=Rack.stageRecord({id="d",egg="outfit",pet="pip",item="beanie",rarity="common"})
		assert(o.kind=="rack"and Stage.words(o,{text=text}).primary==Copy.get("rack.reveal.wear"),"the Outfit Egg's Wear it!")
		assert(Rack.stageRecord({id="e",pet="pip",item="beanie"}).kind=="rack","no egg = outfit")
	end)

	test("the wiring: every egg cranks its own shell; Use it! wears the toy colour or uses the plate / ball; Outfit unchanged",function()
		local s=snapshot()
		local log={sent={},armed={},shells={},shown={},worn={},used={},equipped={}}
		local handler
		local view={isOpen=function()return false end,close=function()end}
		local mount=Rack.mount({view=view,state=function()return s end,id=function()return "r"..(#log.sent+1)end,clock=function()return 0 end,
			result={OnClientEvent={Connect=function(_,fn)handler=fn;return {Disconnect=function()end}end}},
			send=function(r)table.insert(log.sent,r)end,arm=function(id,action)table.insert(log.armed,action)end,
			snapshot=function()end,defer=function()end,petId=function()return "pip"end,
			deliver=function(open,shell)table.insert(log.shells,shell);open();return true end,
			show=function(r,options)table.insert(log.shown,{r=r,options=options});return true end,
			equip=function(petId,slot,item)table.insert(log.equipped,item)end,
			wearToy=function(toyId,skinId)table.insert(log.worn,toyId..":"..skinId)end,
			useDeck=function(kind,id)table.insert(log.used,kind..":"..id)end,
			deckArt=function()return nil end})
		assert(view.onRackEgg==mount.press)
		local function buy(egg,record)
			local done=nil
			assert(mount.press(function(o)done=o end,egg),egg)
			local r=log.sent[#log.sent]
			assert(r.egg==egg and r.petId=="pip",egg)
			record.id=r.id;record.egg=egg;record.pet="pip"
			handler({action="rackEgg",id=r.id,status="Saved",reason="Saved",rack=record})
			assert(done and done.kind=="reveal",egg..": answered")
			local shown=log.shown[#log.shown]
			shown.options.act()
			return shown
		end
		local skin=s.rack.toy.items[1].id
		local t=buy("toycolour",{item=skin,rarity="common"})
		assert(log.armed[1]=="toyBuy"and log.shells[1]=="Toy"and t.r.kind=="rackToy","the Toy Colour Egg cranks the Toy shell")
		assert(log.worn[1]==Skins.ById[skin].toy..":"..skin,"Use it! wears the colour on its toy")
		local plate
		for _,item in ipairs(s.rack.deck.items)do if item.kind=="plate"then plate=item.id;break end end
		local d=buy("deck",{item=plate,rarity="common",kind="plate"})
		assert(log.armed[2]=="lookBuy"and log.shells[2]=="Hue"and d.r.kind=="rackDeck"and d.options.resultBuilder~=nil)
		assert(log.used[1]=="plate:"..plate,"Use it! uses the plate on the existing equip path")
		local hat=s.rack.outfit.items[1].id
		local o=buy("outfit",{item=hat,rarity=s.rack.outfit.items[1].rarity})
		assert(log.armed[3]=="lookBuy"and o.r.kind=="rack"and o.options.wearAppearance~=nil and log.equipped[1]==hat,"the Outfit Egg as slice 1")
		assert(log.sent[3].price==Daily.Price and log.sent[1].price==Skins.Price and log.sent[2].price==Deck.Price)
		mount.destroy()
	end)

	test("the copy: the brief's strings, and every key the lanes and this lane use exists",function()
		local want={["rack.toy.title"]="Toy Colour Egg",["rack.toy.label"]="Today's toy colours",["rack.toy.line"]="New colours every day",
			["rack.toy.locked"]="Get this toy from the Toy Egg",["rack.toy.rest"]="You have today's colours! New colours tomorrow.",
			["rack.toy.more"]="More colours come from the Toy Colour Egg.",["rack.toy.original"]="Original",
			["rack.deck.title"]="Deck Egg",["rack.deck.label"]="Today's picks",["rack.deck.line"]="New picks every day",
			["rack.deck.rest"]="You have today's picks! New picks tomorrow.",["rack.deck.more"]="More at the Deck Egg",
			["rack.deck.promise"]="Plates you own stay yours.",["rack.deck.use"]="Use it!",["rack.deck.full"]="Your shelf is full.",
			["rack.deck.fromEgg"]="From the Deck Egg",["rack.deck.reason"]="Plates and balls come from the Deck Egg now.",
			["rack.deck.help"]="Dress up your Pocket Deck. New plates come from the Deck Egg.",
			["rack.wings.name"]="Angel Wings",["rack.wings.tab"]="Back",["rack.wings.note"]="Your own wings rest while these are on",
			["rack.back"]="Missed one? They come back."}
		for key,text in pairs(want)do assert(Copy.has(key)and Copy.get(key)==text,key..": "..tostring(Copy.has(key)and Copy.get(key)))end
		for egg,K in pairs(Rack.Kinds)do
			for field,key in pairs(K)do
				if field~="shell"and field~="press"and field~="field"then assert(Copy.has(key),egg.."."..field..": "..key)end
			end
		end
		for _,keys in pairs(Stage.Picks)do assert(Copy.has(keys.description)and Copy.has(keys.primary))end
		for name,row in pairs(Closet.Copy)do assert(Copy.has(row[1])and Copy.get(row[1])==row[2],"DeckCloset "..name)end
		for _,id in ipairs({"toycolour","deck"})do
			for _,field in ipairs({"name","line","description","per"})do assert(Copy.has("hatch.egg."..id.."."..field),id.."."..field)end
		end
		assert(Copy.get("hatch.egg.toycolour.name")=="Toy Colour Egg"and Copy.get("hatch.egg.deck.name")=="Deck Egg")
	end)

	test("kid safety: no clock word in any rack or slice 2 egg word (no countdown, timer, 'only today', 'last chance')",function()
		local bad={"hour","minute","second","{h","left","last chance","only today","today only","hurry","ends","expire","timer",
			"countdown","clock","tonight","until","before it","gone soon","don't miss","limited"}
		local scanned=0
		for _,key in ipairs(Copy.keys())do
			local mine=string.sub(key,1,5)=="rack."or string.sub(key,1,20)=="hatch.egg.toycolour."or string.sub(key,1,15)=="hatch.egg.deck."
				or string.sub(key,1,17)=="hatch.egg.outfit."
			if mine then
				scanned+=1
				local s=string.lower(Copy.get(key))
				for _,word in ipairs(bad)do assert(not string.find(s,word,1,true),key..": "..word)end
			end
		end
		assert(scanned>=60,"the rack words were scanned: "..scanned)
	end)

	return {passed=#cases,cases=cases}
end
