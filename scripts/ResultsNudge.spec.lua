-- Growth cuts (GROWTH-CUTS-LOOK 2026-11-25 section 3): the results nudge and the Welcome bonus row. The Toy Egg
-- while no toy is owned, else the Customization Egg; not on sale here: the Toy Egg if a toy is left, else no line.
-- "{egg}: you have enough!" / "1 more Star" / "N more Stars" after this round's payout; the gold row first; Hatch
-- eggs turns primary only when ready in a round that paid a bonus.
-- Usage (Client): require(PlayerScripts.Client.ZZSpecs.ResultsNudge)(PlayerScripts.Client)
return function(client)
	local Nudge=require(client.ResultsNudge)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local UICopy=require(Shared.UICopy)
	local Toys=require(Shared.ToyCatalog)
	local LookEgg=require(Shared.LookEggCatalog)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function allToys()
		local unlocks={}
		for _,id in ipairs(Toys.Pools[Toys.PoolVersion])do unlocks[id]=true end
		return unlocks
	end
	local oneToy={[Toys.Pools[Toys.PoolVersion][1]]=true}

	test("which egg: Toy Egg until a toy is owned, then the Customization Egg, with the fallbacks",function()
		assert(Nudge.egg(nil)==nil)
		local first=Nudge.egg({toyUnlocks={}})
		assert(first.id=="toy"and first.cost==Toys.Cost and first.cost==20)
		local look=Nudge.egg({toyUnlocks=oneToy})
		assert(look.id=="look"and look.cost==LookEgg.Price and look.cost==12 and look.name==UICopy.get("hatch.egg.look.name"))
		assert(Nudge.egg({toyUnlocks=oneToy,restricted=true}).id=="look","restricted players still buy it (fixed next item)")
		assert(Nudge.egg({toyUnlocks=oneToy,lookAvailable=false}).id=="toy","not ready: back to the Toy Egg")
		assert(Nudge.egg({toyUnlocks=allToys(),lookAvailable=false})==nil,"nothing on sale: no line")
		assert(Nudge.egg({toyUnlocks=allToys()}).id=="look")
		assert(Nudge.egg({}).id=="toy","no toy field reads as none owned")
	end)

	test("the line: enough, one short, N short (after this round's payout)",function()
		local look={id="look",name="Customization Egg",cost=12}
		local ready=Nudge.line(look,18)
		assert(ready.ready and ready.text==UICopy.get("results.next.ready",{egg="Customization Egg"}))
		assert(Nudge.line(look,12).ready,"exactly enough")
		local one=Nudge.line(look,11)
		assert(not one.ready and one.short==1 and one.text==UICopy.get("results.next.shortOne",{egg="Customization Egg"}))
		local six=Nudge.line(look,6)
		assert(six.short==6 and six.text==UICopy.get("results.next.short",{egg="Customization Egg",count=6}))
		assert(Nudge.line(nil,50)==nil and Nudge.line(look,nil).short==12)
	end)

	test("the Welcome bonus row: first, gold, only when this receipt paid one",function()
		local row=Nudge.starterRow({starter=12,total=12})
		assert(row and row.gold and row.amount==12 and row.name==UICopy.get("results.starter.row"))
		assert(Nudge.starterRow({starter=0})==nil and Nudge.starterRow({})==nil and Nudge.starterRow(nil)==nil)
	end)

	test("Hatch eggs turns primary only when ready in a bonus round",function()
		local ready={ready=true};local short={ready=false}
		assert(Nudge.hatchPrimary(ready,{starter=12}))
		assert(not Nudge.hatchPrimary(short,{starter=12}),"not enough")
		assert(not Nudge.hatchPrimary(ready,{starter=0})and not Nudge.hatchPrimary(ready,nil),"after the bonus rounds: Replay stays primary")
	end)

	return {passed=#cases,cases=cases}
end
