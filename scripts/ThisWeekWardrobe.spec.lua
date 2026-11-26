-- Studio Client. "This week" in the Wardrobe (ThisWeek.lua; GARDEN-PLAY-BRIEF-2 section 8): pure rules only.
--  * With the switch on and a week from the snapshot, the first tab is "This week" (UICopy thisWeek.tab), on the
--    pick's own slot, holding only the pick (no None card). No week, or the switch off: no tab, the tabs as before.
--  * The pick's pane: full price (no struck price), the stated cycle ("Back every 8 weeks"), never a countdown.
--  * Another week's weekly item is not sold; one the pet owns still resolves, wears and stays in its slot tab.
-- Usage: require(PlayerScripts.Client.ZZSpecs.ThisWeekWardrobe)(PlayerScripts.Client)
return function(client)
 local Shared=game:GetService("ReplicatedStorage").Shared
 local Shop=require(client.WardrobeShop)
 local Catalog=require(Shared.WearableCatalog)
 local ThisWeek=require(Shared.ThisWeek)
 local UICopy=require(Shared.UICopy)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local pet="pip"
 local week=ThisWeek.Anchor -- row 1: Plum Party Hat, 60 Stars
 local function on()assert(ThisWeek.inject({on=true,studio=true,flags={ThisWeek=true}}))end
 local ok,problem=xpcall(function()
  test("the tab: last in line with the switch on and a week; none without either",function()
   on()
   local tabs=Shop.tabsFor(pet,{},week)
   local item=Catalog.forPet(pet,math.huge).byId["partyhat_plum"]
   local last=tabs[#tabs]
   assert(last.id=="thisweek"and last.thisWeek=="partyhat_plum"and last.slot==item.slot,last.id)
   assert(tabs[1].id~="thisweek","the Wardrobe never opens on the sale tab")
   assert(Shop.tabLabel(last)==UICopy.get("thisWeek.tab")and UICopy.get("thisWeek.tab")=="This week")
   for i=2,#tabs do assert(tabs[i].thisWeek==nil,"one This week tab")end
   assert(Shop.tabsFor(pet,{})[1].id~="thisweek","no week: no tab")
   ThisWeek.inject({on=false,studio=true,flags={ThisWeek=true}})
   assert(Shop.tabsFor(pet,{},week)[1].id~="thisweek","switch off: no tab")
   assert(#Shop.tabsFor(pet,{},week)==#Shop.tabsFor(pet,{}),"off: the tabs as before")
  end)
  test("the tab's cards: the pick alone, no None card",function()
   on()
   local tab=Shop.thisWeekTab(pet,week)
   local list=Shop.tileList(pet,tab.slot,{},tab)
   assert(#list==1 and list[1].id=="partyhat_plum"and not list[1].none)
  end)
  test("the pane: full price, the stated cycle, no struck price and no countdown words",function()
   on()
   local item=Catalog.forPet(pet,week).byId["partyhat_plum"]
   -- The server's week decides, whatever the device clock says (review B37).
   local status=Shop.status(pet,"partyhat_plum",{wallet=500,row={owned={},equipped={}},thisWeek=week})
   assert(status.kind=="buy"and status.price==item.price and status.price==60 and status.full==nil,status.kind)
   assert(status.text==UICopy.get("thisWeek.status",{weeks=8})and status.fit[2]==UICopy.get("thisWeek.statusShort",{weeks=8}))
   for _,word in ipairs({"last","left","ends","hurry","only","%d+ days?"})do
    assert(not string.find(string.lower(status.text),word),"no pressure words: "..word)
   end
   assert(Shop.status(pet,"partyhat_plum",{wallet=500,row={owned={},equipped={}},thisWeek=week+1}).kind=="invalid","another server week: not sold")
   assert(Shop.status(pet,"partyhat_plum",{wallet=500,row={owned={},equipped={}},thisWeek=false}).kind=="invalid","server off: not sold")
  end)
  test("bought stays owned: another week's item the pet owns resolves, wears and stays in its slot tab",function()
   on()
   local id=if ThisWeek.pick(ThisWeek.week()).id=="bands_sherbet"then "specs_bluebell"else "bands_sherbet"
   local item=Shop.item(pet,id)
   assert(item and item.weekly==true,"an owned weekly id resolves")
   local owned=Shop.status(pet,id,{wallet=0,row={owned={id},equipped={}}})
   assert(owned.kind=="owned"and owned.button=="Wear")
   local unowned=Shop.status(pet,id,{wallet=500,row={owned={},equipped={}},thisWeek=week})
   assert(unowned.kind=="invalid","not this week: not sold")
   local found=false;for _,card in ipairs(Shop.tileList(pet,item.slot,{id}))do if card.id==id then found=true end end
   assert(found,"listed in its slot tab")
  end)
 end,debug.traceback)
 ThisWeek.inject(nil)
 if not ok then error(problem,0)end
 return{passed=#cases,cases=cases}
end
