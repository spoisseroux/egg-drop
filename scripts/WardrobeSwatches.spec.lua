-- The Wardrobe's colour selector (lane C of the daily rack; ROTATION-BRIEF 2, ARCH-REVIEW-ROTATION 13). The equip queue
-- (WardrobeSwatches): one equip in flight, the last tap waiting behind it and replacing any earlier waiting tap, sent
-- when the one in flight answers (saved or refused), dropped when it would change nothing; any other answer is not its.
-- The row's layout (28 px, 8 px gap, centred, a sideways canvas when it does not fit) and labels; the swatches it draws
-- are the owned colours alone (WearableCatalog.swatchRow) and each one is an id the equip path accepts.
-- Offline: scripts/run_dash_server_specs.py (client). Studio: require(PlayerScripts.Client.ZZSpecs.WardrobeSwatches)(Client).
return function(client,offline)
	local Swatches=require(client.WardrobeSwatches)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Wear=require(Shared.WearableCatalog)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function order(id,item)return {id=id,itemId=item,wear=item,slot="Hat",petId="pip"}end

	test("one in flight: the first tap is sent, the next ones wait in one slot, the last tap wins",function()
		local q=Swatches.new()
		assert(not q:busy())
		local a=order("a","beanie_sky")
		local send,dropped=q:tap(a);assert(send==a and dropped==nil and q:busy())
		local b=order("b","beanie_gold")
		send,dropped=q:tap(b);assert(send==nil and dropped==nil,"waits")
		local c=order("c","beanie_mint")
		send,dropped=q:tap(c);assert(send==nil and dropped==b,"c replaces b: b is never sent")
		local open=q:open();assert(#open==2 and open[1]==a and open[2]==c,"shown: a, then the last tap")
		local nextOrder,mine=q:settle("b");assert(nextOrder==nil and mine==false,"not the one in flight")
		nextOrder,mine=q:settle("a");assert(mine and nextOrder==c,"a answered: the last tap goes")
		assert(q.inflight==c and q.queued==nil)
		nextOrder,mine=q:settle("c");assert(mine and nextOrder==nil and not q:busy(),"done")
		assert(#q:open()==0)
	end)

	test("a waiting tap that changes nothing is dropped; a refusal still sends the last tap",function()
		local q=Swatches.new()
		q:tap(order("a","beanie_sky"));q:tap(order("b","beanie"))
		local nextOrder=q:settle("a",function()return false end)
		assert(nextOrder==nil and not q:busy(),"back to what is worn: nothing sent")
		q:tap(order("c","beanie_sky"));q:tap(order("d","beanie_gold"))
		nextOrder=q:settle("c",function(o)return o.itemId=="beanie_gold"end)
		assert(nextOrder and nextOrder.id=="d","refused or saved, the answer frees the slot")
		q:clear();assert(not q:busy()and #q:open()==0)
		assert(q:tap(nil)==nil and not q:busy(),"a bad tap is ignored")
	end)

	test("layout: 28 px swatches 8 px apart, centred when they fit, a wider canvas when they do not",function()
		assert(Swatches.Size==28 and Swatches.Gap==8)
		local xs,canvas=Swatches.layout(3,200)
		assert(#xs==3 and canvas==200)
		assert(xs[2]-xs[1]==36 and xs[3]-xs[2]==36)
		assert(xs[1]==math.floor((200-(3*36-8))/2),"centred")
		xs,canvas=Swatches.layout(8,176)
		assert(xs[1]==0 and canvas==8*36-8 and canvas>176,"scrolls sideways on a phone pane")
		local none,width=Swatches.layout(0,120);assert(#none==0 and width==120)
		assert(Swatches.label({name="Sky Pom Beanie"},true)=="Sky Pom Beanie, wearing"and Swatches.label({name="X"},false)=="X")
	end)

	test("what the row draws: owned colours of the focused base only, each one wearable through the equip path",function()
		local W=offline.new.require(offline.new.server.WearableState)
		local owned={"beanie","beanie_sky","beanie_rainbow","tee","beanie_rose"}
		local state={inventoryMask=1,petWearables={pip={owned=owned,equipped={}}}}
		local Eggs=require(Shared.EggCatalog)
		if not Eggs.isOwned(state.inventoryMask,"pip")then state.inventoryMask=Eggs.bit("pip")end
		local row=Wear.swatchRow("pip","beanie",owned)
		assert(row and #row==4,"base, egg colour, sparkle pick, owned gated colour")
		for _,item in ipairs(row)do
			assert(table.find(owned,item.id),"only owned colours")
			assert(item.slot=="Hat")
			local result=W.equipResult(state,"pip","Hat",item.id)
			assert(result and result.equipped.Hat==item.id,"review 13: equips "..item.id)
		end
		assert(Wear.swatchRow("pip","tee",owned)==nil,"a single colour: no row")
	end)

	return {passed=#cases,cases=cases}
end
