-- Studio Client. Overnight 2026-11-14 slice C (SYSTEMS-SCOPE 3.6): the weekly shelf in the UI.
--  * ShelfDeal: the week comes from the snapshot's dailyDay; quote / priceText / lines are
--    pure; with no shelf (module missing, flag off, week unknown) everything is full price.
--  * Wardrobe, Faceplates and Balls: an item on this week's shelf shows the "THIS WEEK −20%"
--    chip, the shelf price with the full price struck through, and the buy sends the shelf
--    price. Off the shelf nothing changes. ctx.week=false means "no shelf".
--  * Deluxe tier chip on Faceplates and Balls.
--  * Machine hub: the Deck style and Companions tiles carry "This week: ..." (no countdown);
--    locked tiles and a snapshot without a day keep their usual line.
-- Usage: require(PlayerScripts.Client.ZZSpecs.ShelfDeal)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Shared=game:GetService("ReplicatedStorage").Shared
 local Deal=require(client.ShelfDeal)
 local Wardrobe=require(client.WardrobeShop)
 local Plates=require(client.FaceplateShop)
 local Balls=require(client.BallShop)
 local Hub=require(client.MachineHub)
 local UICopy=require(Shared.UICopy)
 local Catalog=require(Shared.WearableCatalog)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local gui=Instance.new("ScreenGui");gui.Name="_ShelfDealSpec";gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=parent
 local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
 local Shelf=Deal.shelf()
 -- A fixed day (2026-11-16, a Monday) and the two weeks after it: both the faceplate and
 -- the ball week are covered whatever the parity.
 local days={20773,20780,20787}
 local pet=Wardrobe.firstPet()
 local ok,problem=xpcall(function()
  test("pure: week, quote, price text and lines; no shelf means full price everywhere",function()
   assert(Deal.weekOf(nil)==nil and Deal.weekOf("x")==nil and Deal.week({})==nil,"no day, no week")
   assert(Deal.weekOf("20773")==Deal.weekOf(20773)and Deal.weekOf(20773)+1==Deal.weekOf(20780),"weeks step by seven days")
   assert(Deal.week({dailyDay="20773"})==Deal.weekOf(20773))
   if Shelf and Shelf.weekOfDay then assert(Deal.weekOf(20773)==Shelf.weekOfDay(20773),"the client's week is the shelf's week")end
   assert(Deal.priceText(15)=="★ 15"and Deal.priceText(12,15)=="★ 12  <s>15</s>")
   local price,full=Deal.quote("wearable","no_such_item",15,Deal.weekOf(20773));assert(price==15 and full==nil,"off the shelf: full price")
   price,full=Deal.quote("wearable","anything",15,nil);assert(price==15 and full==nil,"no week: full price")
   price,full=Deal.quote("wearable","anything",15,false);assert(price==15 and full==nil,"week=false: full price")
   assert(#Deal.slots(nil)==0 and #Deal.slots(false)==0 and Deal.price("ball","x",nil)==nil)
   assert(Deal.lines(nil,{"wearable"},Hub.ShelfNames)==nil)
   -- A stand-in shelf: the module is looked up through Deal.shelf (Deal.override).
   Deal.override={slots=function(week)return if week==7 then {{kind="wearable",id="a",full=15,price=12},{kind="ball",id="b",full=40,price=32}}else {}end,
    price=function(kind,id,week)return if week==7 and kind=="wearable"and id=="a"then 12 elseif week==7 and kind=="ball"and id=="b"then 32 else nil end}
   price,full=Deal.quote("wearable","a",15,7);assert(price==12 and full==15)
   price,full=Deal.quote("ball","a",15,7);assert(price==15 and full==nil,"the kind matters")
   local names={wearable=function(id)return "Hat "..id end,ball=function(id)return "Ball "..id end}
   local lines=Deal.lines(7,{"wearable","ball"},names)
   assert(lines[1]==UICopy.get("shelf.line",{item="Hat a, Ball b"})and lines[2]==UICopy.get("shelf.short"))
   assert(Deal.lines(7,{"faceplate"},names)==nil and Deal.lines(8,{"wearable"},names)==nil)
   Deal.override={slots=function()error("broken shelf")end,price=function()error("broken shelf")end}
   price,full=Deal.quote("wearable","a",15,7);assert(price==15 and full==nil and #Deal.slots(7)==0,"a shelf that errors is no shelf")
   Deal.override=nil
  end)
  test("the chip: hidden by default, long text, short text when it would not fit",function()
   local frame=Instance.new("Frame");frame.Size=UDim2.fromOffset(400,100);frame.Parent=gui
   local chip=Deal.chip(frame,22)
   assert(chip.root.Visible==false and chip.root.Name=="ShelfChip")
   chip.set(true,400);assert(chip.root.Visible and chip.chip.label.Text==string.upper(UICopy.get("shelf.chip"))and chip.root:GetAttribute("Shelf")==true)
   chip.set(true,40);assert(chip.chip.label.Text==string.upper(UICopy.get("shelf.chipShort")),"narrow panes get the short chip")
   chip.set(false);assert(chip.root.Visible==false and chip.root:GetAttribute("Shelf")==false)
   frame:Destroy()
  end)
  if not Shelf then
   test("no WeeklyShelf module in this build: the shops show full prices",function()
    local item=Catalog.forPet(pet).order[1]
    local s=Wardrobe.status(pet,item.id,{wallet=0,row={owned={},equipped={}},week=Deal.weekOf(20773)})
    assert(s.price==item.price and s.full==nil)
   end)
  else
   test("Wardrobe: the shelf wearables sell at the shelf price on their week, full price off it",function()
    local seen=0
    for _,day in ipairs(days)do
     local week=Deal.weekOf(day)
     for _,slot in ipairs(Deal.slots(week))do
      if slot.kind=="wearable"and Catalog.item(pet,slot.id)then
       seen+=1
       local item=Catalog.item(pet,slot.id)
       local rich={wallet=1000,row={owned={},equipped={}},week=week}
       local s=Wardrobe.status(pet,slot.id,rich)
       assert(s.kind=="buy"and s.price==slot.price and s.full==item.price and slot.price<item.price,slot.id.." shelf price")
       assert(s.button=="★ Buy "..slot.price and s.text==UICopy.get("shelf.status"))
       local text,tone=Wardrobe.tileStatus(pet,slot.id,rich,item.slot)
       assert(text==Deal.priceText(slot.price,item.price)and tone=="stars")
       local poor=Wardrobe.status(pet,slot.id,{wallet=slot.price-1,row={owned={},equipped={}},week=week})
       assert(poor.kind=="short"and poor.price==slot.price and poor.text=="1 more Stars needed","the shortfall is against the shelf price")
       local exact=Wardrobe.status(pet,slot.id,{wallet=slot.price,row={owned={},equipped={}},week=week});assert(exact.kind=="buy")
       -- Not this week (two weeks on the shelf never repeats in the same slot): full price.
       local off=Wardrobe.status(pet,slot.id,{wallet=1000,row={owned={},equipped={}},week=false})
       assert(off.price==item.price and off.full==nil and off.text=="You have enough Stars")
       -- Owned items never show a price.
       local owned=Wardrobe.status(pet,slot.id,{wallet=0,row={owned={slot.id},equipped={}},week=week});assert(owned.kind=="owned"and owned.full==nil)
      end
     end
    end
    assert(seen>=1,"a shelf wearable was checked")
   end)
   test("Wardrobe built: chip, struck price and the order carries the shelf price",function()
    local week=Deal.weekOf(days[1]);local slot
    for _,s in ipairs(Deal.slots(week))do if s.kind=="wearable"and Catalog.item(pet,s.id)then slot=slot or s end end
    assert(slot,"a wearable on the shelf")
    local item=Catalog.item(pet,slot.id)
    local host=Instance.new("Frame");host.BackgroundTransparency=1;host.Size=UDim2.fromOffset(1280,720);host.Parent=gui
    local orders={}
    local shop=Wardrobe.new(host,{appearance=function()return{}end,buy=function(order)table.insert(orders,order)end})
    shop:open(pet,{wallet=1000,row={owned={},equipped={}},week=week});settle()
    local tabIndex;for i,tab in ipairs(shop.tabList)do if tab.slot==item.slot then tabIndex=i end end
    shop:setTab(tabIndex);settle()
    local at;for i,tile in ipairs(shop.tiles)do if tile.id==slot.id then at=i end end
    assert(at,"the shelf item has a card")
    assert(shop.tiles[at].status.RichText==true and shop.tiles[at].status.Text==Deal.priceText(slot.price,item.price),"card: shelf price, full price struck")
    for i,tile in ipairs(shop.tiles)do
     if i~=at and not tile.none and shop:statusOf(tile.id).full==nil then assert(tile.status.RichText==false,"plain cards stay plain text")end
    end
    shop:focus(at);settle()
    assert(shop.deal.root.Visible and shop.root:GetAttribute("ShelfPrice")==slot.price,"pane chip on the shelf item")
    assert(shop.deal.root.AbsoluteSize.X<=shop.viewport.AbsoluteSize.X,"the chip fits the preview well")
    shop:act();shop:act() -- confirm, then buy
    assert(#orders==1 and orders[1].itemId==slot.id and orders[1].price==slot.price,"the buy sends the shelf price")
    shop:result({id=orders[1].id,status="Refused",reason="PriceChanged"})
    assert(shop.status.Text==UICopy.get("shop.reason.priceChanged"),"a week boundary refusal reads as a price change")
    -- Another card: no chip.
    local other;for i,tile in ipairs(shop.tiles)do if not tile.none and shop:statusOf(tile.id).full==nil then other=other or i end end
    if other then shop:focus(other);settle();assert(not shop.deal.root.Visible and shop.root:GetAttribute("ShelfPrice")==nil)end
    shop:close();shop:destroy();host:Destroy()
   end)
   test("Faceplates and Balls: shelf price on the shelf week, full price off it",function()
    local kinds={}
    for _,day in ipairs(days)do
     local week=Deal.weekOf(day)
     for _,slot in ipairs(Deal.slots(week))do
      if slot.kind=="faceplate"then
       kinds.faceplate=true
       local s=Plates.status(slot.id,{wallet=1000,facts={faceplates={}},week=week})
       assert(s.kind=="buy"and s.price==slot.price and s.full==slot.full and s.text==UICopy.get("shelf.status"),slot.id)
       assert(Plates.tileStatus(slot.id,{wallet=0,facts={faceplates={}},week=week})==Deal.priceText(slot.price,slot.full))
       local off=Plates.status(slot.id,{wallet=1000,facts={faceplates={}},week=false});assert(off.price==slot.full and off.full==nil)
       assert(Plates.shortText(slot.id,{wallet=slot.price-2,week=week})[1]==UICopy.starsShort(2)[1],"shortfall against the shelf price")
      elseif slot.kind=="ball"then
       kinds.ball=true
       local s=Balls.status(slot.id,{wallet=1000,owned={},week=week})
       assert(s.kind=="buy"and s.price==slot.price and s.full==slot.full and s.text==UICopy.get("shelf.status"),slot.id)
       assert(Balls.tileStatus(slot.id,{wallet=0,owned={},week=week})==Deal.priceText(slot.price,slot.full))
       local off=Balls.status(slot.id,{wallet=1000,owned={},week=false});assert(off.price==slot.full and off.full==nil)
      end
     end
    end
    assert(kinds.faceplate and kinds.ball,"both kinds had a shelf week")
   end)
   test("Machine hub: this week's shelf on the Deck style and Companions tiles",function()
    local state={dailyDay=tostring(days[1])}
    local week=Deal.weekOf(days[1])
    local companions=Hub.shelfLines("companions",{owned=1,state=state})
    assert(companions and string.find(companions[1],"This week:",1,true)and companions[2]==UICopy.get("shelf.short"))
    for _,slot in ipairs(Deal.slots(week))do
     local name=Hub.ShelfNames[slot.kind](slot.id)
     assert(type(name)=="string"and name~="",slot.kind..":"..slot.id.." has a name")
     local tile=if slot.kind=="wearable"then "companions"else "style"
     local lines=Hub.shelfLines(tile,{owned=1,state=state})
     assert(lines and string.find(lines[1],name,1,true),name.." is on the "..tile.." tile")
    end
    for _,id in ipairs({"hatch","quests","book","settings"})do assert(Hub.shelfLines(id,{owned=1,state=state})==nil,id)end
    assert(Hub.shelfLines("style",{owned=0,state=state})==nil,"locked tiles keep their line")
    assert(Hub.shelfLines("style",{owned=1,state={}})==nil and Hub.shelfLines("style",{owned=1})==nil,"no day in the snapshot: no shelf line")
    for _,size in ipairs({Vector2.new(1280,720),Vector2.new(812,354)})do
     local host=Instance.new("Frame");host.BackgroundTransparency=1;host.Size=UDim2.fromOffset(size.X,size.Y);host.Parent=gui
     local hub=Hub.new(host,{})
     hub:open({owned=1,wallet=10,state=state});settle()
     for index,tile in ipairs(Hub.Tiles)do
      local entry=hub.tileViews[index]
      local lines=Hub.shelfLines(tile.id,{owned=1,state=state})
      if lines then
       assert(entry.button:GetAttribute("Shelf")==true and(entry.line.Text==lines[1]or entry.line.Text==lines[2]),tile.id.." shows a shelf line")
       assert(not string.find(string.lower(entry.line.Text),"left",1,true)and not string.find(entry.line.Text,":%d%d"),"no countdown")
      else
       assert(entry.button:GetAttribute("Shelf")==false and entry.line.Text==UICopy.get(tile.line),tile.id.." keeps its line")
      end
     end
     hub:setContext({state={}});settle()
     assert(hub.tileViews[2].line.Text==UICopy.get(Hub.Tiles[2].line)and hub.tileViews[2].button:GetAttribute("Shelf")==false,"the line goes back without a shelf")
     hub:destroy();host:Destroy()
    end
   end)
  end
  test("deluxe tier chips exist on Faceplates and Balls",function()
   assert(Plates.TierChip.deluxe and Plates.TierChip.deluxe[1]==UICopy.get("shelf.deluxe")and typeof(Plates.TierChip.deluxe[2])=="Color3")
   assert(Balls.TierChip.deluxe and Balls.TierChip.deluxe[1]==UICopy.get("shelf.deluxe"))
  end)
 end,function(e)Deal.override=nil;return tostring(e).." | "..debug.traceback()end)
 gui:Destroy()
 if not ok then error(problem,0)end
 return{passed=#cases,cases=cases}
end
