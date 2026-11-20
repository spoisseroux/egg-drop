-- v2 pet names, client side: NameScreen's pure rules (tabs, keys, slots, the Names Egg card),
-- PetNameText (own and other players' names) and PetNameplates' show rule.
-- Run (Client): require(game.Players.LocalPlayer.PlayerScripts.Client.ZZSpecs.NameScreen)(game.Players.LocalPlayer.PlayerScripts.Client)
return function(client)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Names=require(Shared.NameCatalog)
	local UICopy=require(Shared.UICopy)
	local Screen=require(client.NameScreen)
	local Text=require(client.PetNameText)
	local Plates=require(client.PetNameplates)
	local HttpService=game:GetService("HttpService")
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local starters=Names.starterIds()
	local function names(extra)
		local owned=table.clone(starters)
		for _,id in ipairs(extra or {})do table.insert(owned,id)end
		local remaining=Names.remaining(owned)
		return {owned=owned,petNames={},remaining=remaining,mode="random",price=8,quoteKey=Names.quoteKey("random",remaining,0)}
	end

	test("counts: All 6/52 on day one; Stats holds the keeper tiers (22); Book 4",function()
		local c=Screen.counts(names())
		assert(c.all.owned==6 and c.all.total==52 and c.starter.owned==6 and c.starter.total==6)
		assert(c.egg.total==20 and c.stat.total==22 and c.book.total==4 and c.egg.owned==0)
		c=Screen.counts(names({"velvet","speedy","sprout"}))
		assert(c.all.owned==9 and c.egg.owned==1 and c.stat.owned==2)
	end)

	test("keys: owned first, then locked with what they need",function()
		local tiles=Screen.tiles(names({"speedy"}),"stat",{"speedy"})
		assert(tiles[1].id=="speedy"and tiles[1].owned and tiles[1].slot==1 and tiles[1].lock==nil)
		local byId={};for _,t in ipairs(tiles)do byId[t.id]=t end
		assert(byId.zoomies.lock==UICopy.get("names.lock.stat",{stat="SPEED",level=10}))
		assert(byId.sprout.lock=="TOTAL 60"and byId.champion.lock=="ANY STAT 99")
		local book=Screen.tiles(names(),"book",{})
		assert(#book==4 and book[2].lock=="BOOK 10")
		assert(#Screen.tiles(names(),"all",{})==52)
	end)

	test("slots: tap fills the next slot, a third replaces the second, tap again removes; swap; same",function()
		local s=Screen.toggle({},"biscuit");assert(#s==1 and s[1]=="biscuit")
		s=Screen.toggle(s,"parade");assert(s[2]=="parade")
		s=Screen.toggle(s,"puddle");assert(#s==2 and s[1]=="biscuit"and s[2]=="puddle")
		s=Screen.toggle(s,"biscuit");assert(#s==1 and s[1]=="puddle")
		assert(Screen.swap({"a","b"})[1]=="b"and #Screen.swap({"a"})==1)
		assert(Screen.same({"a","b"},{"a","b"})and not Screen.same({"a","b"},{"b","a"})and Screen.same(nil,{}))
	end)

	test("Names Egg card: real odds per piece (random), the fixed next piece (restricted), all collected",function()
		local n=names()
		local odds=Screen.eggOdds(n)
		local cells=0;for _,row in ipairs(odds.rows)do if not row.info then cells+=1;assert(row.value=="5%")end end
		assert(cells==20 and not odds.restricted)
		n.mode="fixed";n.next="velvet"
		odds=Screen.eggOdds(n)
		assert(odds.restricted and odds.rows[1].id=="velvet"and odds.rows[1].name=="Next: Velvet")
		local all=table.clone(starters);for _,id in ipairs(Names.EggOrder)do table.insert(all,id)end
		local full=names();full.owned=all;full.remaining={}
		assert(Screen.eggOdds(full).empty==UICopy.get("names.egg.all")and not Screen.eggAction(full,100).enabled)
		assert(Screen.eggAction(names(),7).need==1 and Screen.eggAction(names(),8).enabled)
		-- Odds with 17 left: 1 in 17, 5.882% each, with the rounding note.
		local some=names({"velvet","sidequest","bureau"})
		odds=Screen.eggOdds(some)
		assert(odds.rows[1].value=="5.882%"and odds.rounded)
	end)

	test("PetNameText: own name or species; another player's board ids; unknown ids show the species",function()
		local state={names={petNames={pip={"biscuit","sprout"}}}}
		local text,named=Text.own(state,"pip");assert(text=="Biscuit Sprout"and named)
		text,named=Text.own(state,"blip");assert(text=="Bunny"and not named)
		local board=Instance.new("Folder")
		board:SetAttribute(Names.Attribute,HttpService:JSONEncode({v=1,pets={pip={"velvet"}}}))
		text,named=Text.ofBoard(board,"pip");assert(text=="Velvet"and named)
		board:SetAttribute(Names.Attribute,HttpService:JSONEncode({v=1,pets={pip={"velvet","from_a_later_build"}}}))
		text,named=Text.ofBoard(board,"pip");assert(text=="Bear"and not named)
		board:SetAttribute(Names.Attribute,"[]");assert(select(2,Text.ofBoard(board,"pip"))==false)
		board:SetAttribute(Names.Attribute,"not json");assert(Text.ofBoard(board,"pip")=="Bear")
		board:Destroy()
	end)

	test("nameplates: other players' tags only when named, near and in the garden; width fits the longest name",function()
		assert(Plates.showOther(true,10,"Room")and not Plates.showOther(true,Plates.NearRange+1,"Room"))
		assert(not Plates.showOther(false,5,"Room")and not Plates.showOther(true,5,"Board"))
		local w=Plates.width("Thunderbun Afterparty")
		assert(w>Plates.width("Hmm")and w<260)
	end)

	test("every names.* copy key the screen reads exists",function()
		for _,key in ipairs({"names.title","names.open","names.save","names.saving","names.saved","names.swap","names.clear","names.slots.empty",
			"names.slots.hint","names.shows.title","names.shows.where","names.footer.free","names.footer.account","names.egg.key","names.egg.buy",
			"names.egg.all","names.reveal.use","names.reveal.done","names.reveal.sticker","names.reveal.line","names.unlocked","names.reason.default",
			"names.reason.PoolChanged","names.hint.stat","names.hint.egg","hatch.reveal.kind.name"})do
			assert(UICopy.has(key),"missing "..key)
		end
		for _,tab in ipairs(Screen.Tabs)do assert(UICopy.has("names.tab."..tab))end
	end)

	print(("[NameScreen] %d passed: %s"):format(#cases,table.concat(cases," | ")))
	return #cases
end
