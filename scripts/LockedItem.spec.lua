-- Studio Client. Level-gated shop items (LockedItem, V3-LEVELS-BUILD-PLAN-2026-11-22 S2) and the
-- Wardrobe that shows them, with gates on and off.
--  * info: nil when ungated, owned or off; needs / short / count / ratio / colour for a stat and a
--    total gate; best owned pet; a malformed gate is never met.
--  * the chip keeps the longest words that fit and goes when met; the bar and the lock follow.
--  * Wardrobe on: a locked card keeps its price, try-on works, the button trains, the server's
--    NeedsLevel shows; met = Buy. Off: gated cards are gone unless owned, and an owned one is worn
--    and taken off as any item. Desktop, 844 x 390 and 667 x 375.
-- Usage: require(PlayerScripts.Client.ZZSpecs.LockedItem)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Shared=game:GetService("ReplicatedStorage").Shared
 local Locked=require(client.LockedItem)
 local Shop=require(client.WardrobeShop)
 local Levels=require(Shared.Levels)
 local Catalog=require(Shared.WearableCatalog)
 local Stats=require(Shared.StatCatalog)
 local UICopy=require(Shared.UICopy)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function on()Levels.inject({flags={LevelsMatter=true},studio=true,shipped={gates=true,track=true,medals=true,juice=true}})end
 local function off()Levels.inject({flags={},studio=true})end
 parent=parent:FindFirstAncestorOfClass("PlayerGui")or parent -- a gui inside a gui has no layout of its own
 local shops={} -- closed whatever happens
 local gui=Instance.new("ScreenGui");gui.Name="_LockedItemSpec";gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=parent
 local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
 local function state(levels)return{petStats={pets={pip={level=levels}}}}end
 local jump=Locked.levels(state({heart=1,power=1,energy=1,jump=14,speed=1,smarts=1}))
 local limeJump
 local ok,problem=xpcall(function()
  test("pure: off, owned and ungated items have no info",function()
   off();assert(Locked.info({gate={stat="jump",level=30}},jump)==nil and not Locked.on())
   on();assert(Locked.info({},jump)==nil and Locked.info(nil,jump)==nil and Locked.info({gate={stat="jump",level=30}},jump,true)==nil)
  end)
  test("pure: a stat gate and a total gate read the best owned pet",function()
   on()
   local info=Locked.info({gate={stat="jump",level=30}},jump)
   assert(not info.met and info.have==14 and info.need==30 and info.petId=="pip"and info.stat=="jump"and info.count=="14/30"and math.abs(info.ratio-14/30)<1e-6)
   assert(info.needs==UICopy.get("shop.needs.stat",{name=UICopy.get("stats.name.jump"),level=30})and info.line==info.needs.." · 14/30")
   assert(info.color==Stats.ById.jump.color and Locked.trainText(info)==UICopy.get("shop.train",{name=UICopy.get("stats.name.jump")}))
   local route=Locked.route(info);assert(route.stat=="jump"and route.petId=="pip")
   local total=Locked.info({gate={total=150}},jump)
   assert(total.total==150 and total.have==19 and total.color==Locked.Mint and total.needs==UICopy.get("shop.needs.total",{count=150}))
   assert(Locked.trainText(total,"Bear")==UICopy.get("shop.train",{name="Bear"})and Locked.trainText(total,nil)==UICopy.get("stats.open"))
   assert(Locked.info({gate={stat="jump",level=14}},jump).met and Locked.info({gate={stat="jump",level=14}},{}).met==false)
   local bad=Locked.info({gate={stat="nope",level=3}},jump);assert(not bad.met and bad.needs==UICopy.get("shop.reason.needsLevel"))
   -- A level past the gate never counts past it.
   assert(Locked.info({gate={stat="jump",level=10}},jump).count=="10/10")
  end)
  test("the chip keeps the longest words that fit, the bar fills, the lock shows only while locked",function()
   on()
   local frame=Instance.new("Frame");frame.Size=UDim2.fromOffset(300,60);frame.Parent=gui
   local chip=Locked.chip(frame,20);assert(not chip.root.Visible)
   local info=Locked.info({gate={stat="jump",level=30}},jump)
   chip.set(info,300);assert(chip.root.Visible and chip.label.Text==info.needs and chip.root:GetAttribute("Met")==false and chip.stroke.Color==Stats.ById.jump.color)
   chip.set(info,90);assert(chip.label.Text==info.short and chip.root.Size.X.Offset<=90)
   chip.set(Locked.info({gate={stat="jump",level=5}},jump),300);assert(chip.root:GetAttribute("Met")==true and not chip.root.Visible,"met: nothing is needed any more")
   chip.set(info,300);assert(chip.root.Visible,"and it can come back")
   chip.set(nil);assert(not chip.root.Visible)
   local bar=Locked.bar(frame,0,30,100,5)
   bar.set(info);assert(bar.root.Visible and math.abs(bar.fill.Size.X.Scale-14/30)<1e-3)
   bar.set(Locked.info({gate={stat="jump",level=5}},jump));assert(not bar.root.Visible)
   local mark=Locked.mark(frame,18);assert(not mark.root.Visible);mark.set(true);assert(mark.root.Visible and mark.veil.Visible)
   frame:Destroy()
  end)
  for _,item in ipairs(Catalog.forPet("pip",math.huge).order)do if item.gate and item.gate.stat=="jump"and item.gate.level==30 then limeJump=item.id end end
  assert(limeJump,"a Jump 30 recolour")
  for _,size in ipairs({Vector2.new(1280,720),Vector2.new(844,390),Vector2.new(667,375)})do
   test(tostring(size).." Wardrobe on: the locked card, the way to train, then Buy",function()
    on()
    local host=Instance.new("Frame");host.BackgroundTransparency=1;host.Size=UDim2.fromOffset(size.X,size.Y);host.Parent=gui
    local trained
    local shop=Shop.new(host,{appearance=function()return{}end,train=function(route)trained=route end,buy=function()end});table.insert(shops,shop)
    shop:open("pip",{wallet=500,row={owned={},equipped={}},week=false,levels=jump});settle()
    assert(shop:showItem(limeJump)and shop:focusedId()==limeJump,"showItem lands on the card")
    assert(shop:statusOf(limeJump).kind=="locked"and shop.root:GetAttribute("PaneState")=="locked")
    local tile=shop.tiles[shop.index]
    assert(tile.chip.root.Visible and tile.lock.root.Visible and tile.status.Text=="","the chip stands where the price would")
    assert(string.find(tile.button:GetAttribute("AccessibleLabel"),UICopy.get("shop.needs.stat",{name=UICopy.get("stats.name.jump"),level=30}),1,true))
    local tp,ts,cp,cs=tile.button.AbsolutePosition,tile.button.AbsoluteSize,tile.chip.root.AbsolutePosition,tile.chip.root.AbsoluteSize
    local k=shop.scale.Scale
    assert(cp.X>=tp.X+6*k-.5 and cp.X+cs.X<=tp.X+ts.X-6*k+.5 and cp.Y+cs.Y<=tp.Y+ts.Y-6*k+.5,"the chip is 6 px inside its card")
    -- The bar: 8 px, 10 px clear of the button, under its 13 px line.
    local line,bar,key=shop.status,shop.lockBar.root,shop.action
    assert(line.TextSize==13 and bar.Size.Y.Offset==8 and bar.Position.Y.Offset+8+10<=key.Position.Y.Offset and line.Position.Y.Offset+line.Size.Y.Offset<=bar.Position.Y.Offset,"bar "..bar.Position.Y.Offset.." line "..line.Position.Y.Offset.." key "..key.Position.Y.Offset)
    assert(shop.lockBar.root.Visible and shop.action:GetAttribute("AccessibleLabel")==UICopy.get("shop.train",{name=UICopy.get("stats.name.jump")}))
    assert(string.find(shop.root:GetAttribute("PreviewWearables"),limeJump,1,true),"try-on still works")
    assert(shop:act()and trained.stat=="jump"and trained.petId=="pip"and shop.pending==nil,"nothing is bought")
    -- A stale client: the server refuses.
    shop.pending={id="op",action="wearableBuy",petId="pip",itemId=limeJump}
    shop:result({id="op",status="Rejected",reason="NeedsLevel"});assert(shop.status.Text==UICopy.get("shop.reason.needsLevel"),shop.status.Text)
    -- The level is met: Buy, no lock, no bar.
    shop:setContext({levels=Locked.levels(state({jump=30})),row={owned={},equipped={}}});shop:focus(shop.index,true)
    assert(shop:statusOf(limeJump).kind=="buy"and not shop.lockBar.root.Visible and not shop.tiles[shop.index].lock.root.Visible and not shop.tiles[shop.index].chip.root.Visible)
    -- Without a train route the button does nothing.
    shop.callbacks.train=nil;shop:setContext({levels=jump});assert(shop:act()==false)
    shop:destroy();host:Destroy()
   end)
   test(tostring(size).." Wardrobe off: gated cards are gone; an owned one is worn and taken off",function()
    off()
    local host=Instance.new("Frame");host.BackgroundTransparency=1;host.Size=UDim2.fromOffset(size.X,size.Y);host.Parent=gui
    local shop=Shop.new(host,{appearance=function()return{}end,equip=function()end});table.insert(shops,shop)
    shop:open("pip",{wallet=500,row={owned={limeJump},equipped={}},week=false});settle()
    local slot=Catalog.forPet("pip",math.huge).byId[limeJump].slot
    local plain,owned=Shop.tileList("pip",slot,{}),Shop.tileList("pip",slot,{limeJump})
    assert(#owned==#plain+1,"only the owned one is added")
    for _,item in ipairs(plain)do assert(item.gate==nil,tostring(item.id))end
    assert(Shop.status("pip",limeJump,{wallet=999,row={owned={},equipped={}}}).kind=="invalid","never sold")
    assert(shop:showItem(limeJump));local tile=shop.tiles[shop.index]
    assert(tile.chip==nil and tile.lock==nil and shop.lockBar==nil and shop:statusOf(limeJump).kind=="owned")
    assert(shop:act()and shop:statusOf(limeJump).kind=="equipped","worn")
    assert(Catalog.equippedIn("pip",Shop.applyEquip("pip",{[Catalog.forPet("pip",math.huge).byId[limeJump].keys[1]]=limeJump},Shop.NoneId,false,slot),slot)==nil,"taken off")
    -- The switch flips while the shop is open: the cards come back with their chips.
    on();shop:setContext({levels=jump,row={owned={},equipped={}}});settle()
    assert(shop:showItem(limeJump)and shop.tiles[shop.index].chip~=nil)
    shop:destroy();host:Destroy()
   end)
  end
 end,function(e)return tostring(e).." | "..debug.traceback()end)
 Levels.inject(nil)
 for _,shop in ipairs(shops)do pcall(function()shop:destroy()end)end
 gui:Destroy()
 if not ok then error(problem,0)end
 return{passed=#cases,cases=cases}
end
