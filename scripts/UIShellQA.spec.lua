-- Studio Client. QA 2026-11-13 Q2 UI shell: one full-screen shade at a time (Kit
-- shade stack), Wardrobe / Book / Customize slide in like the Pets page, Wardrobe
-- card previews (lazy, cached, colour-tile fallback), optimistic Wardrobe equip with
-- rollback + toast, and the modal cursor (alt-tab focus restore).
-- Usage: require(PlayerScripts.Client.ZZSpecs.UIShellQA)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Kit=require(client.DeckKit)
 local Hub=require(client.CompanionsHub)
 local Wardrobe=require(client.WardrobeShop)
 local Book=require(client.BookView)
 local Cursor=require(client.ModalCursor)
 local Pets=require(game.ReplicatedStorage.Shared.PetCatalog)
 local Catalog=require(game.ReplicatedStorage.Shared.WearableCatalog)
 local UICopy=require(game.ReplicatedStorage.Shared.UICopy)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 -- BackgroundTransparency is a float32, so compare the shade alpha with a tolerance.
 local function dims(shade)return math.abs(shade.BackgroundTransparency-Kit.ShadeAlpha)<1e-4 end
 local function settle(n)for _=1,n or 3 do game:GetService("RunService").Heartbeat:Wait()end end
 -- Menu guis use CoreUISafeInsets, as in init.client.
 local function menuGui(name,order)
  local gui=Instance.new("ScreenGui");gui.Name=name;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets
  gui.DisplayOrder=order;gui.ResetOnSpawn=false;gui.Parent=parent
  local host=Instance.new("Frame");host.Name="Host";host.BackgroundTransparency=1;host.Size=UDim2.fromScale(1,1);host.Parent=gui
  return gui,host
 end
 local wardrobePet
 for _,pet in ipairs(Pets.collection)do if Catalog.hasItems(pet.id)then wardrobePet=pet.id;break end end
 local guis={}
 local ok,problem=xpcall(function()
  test("pure: cover rect reaches the probed screen from an inset parent",function()
   local p,s=Kit.coverRect(Vector2.new(0,-58),Vector2.new(1920,1080),Vector2.new(0,0))
   assert(p==UDim2.fromOffset(0,-58)and s.X.Offset>=1920 and s.Y.Offset>=1080)
  end)
  test("shade stack: only the top shade dims; covered callbacks fire; closing uncovers",function()
   local gui,host=menuGui("_ShadeStackSpec",11);table.insert(guis,gui)
   local a=Kit.modalShade(host,"A",30);local b=Kit.modalShade(host,"B",40)
   local log={};local ownerA,ownerB={},{}
   Kit.shadeOpen(ownerA,a,function(c)table.insert(log,{"a",c})end)
   assert(a.Visible and dims(a) and Kit.dimmingShades()==1)
   Kit.shadeOpen(ownerB,b,function(c)table.insert(log,{"b",c})end)
   assert(dims(b) and a.BackgroundTransparency==1 and Kit.dimmingShades()==1,"one dim, not two")
   assert(log[1][1]=="a"and log[1][2]==true and a:GetAttribute("ShadeCovered")==true)
   -- Re-opening the lower one (a refresh under a child) keeps its place.
   Kit.shadeOpen(ownerA,a);assert(a.BackgroundTransparency==1 and dims(b))
   Kit.shadeClose(ownerB);assert(not b.Visible and dims(a) and log[#log][1]=="a"and log[#log][2]==false)
   Kit.shadeClose(ownerA);assert(not a.Visible and Kit.dimmingShades()==0)
   gui:Destroy()
  end)
  test("shades cover the whole screen, above the top-bar inset",function()
   local gui,host=menuGui("_ShadeCoverSpec",11);table.insert(guis,gui)
   local shade=Kit.modalShade(host,"Cover",30);Kit.shadeOpen(shade,shade);settle()
   local probe=Kit.screenProbe(host);assert(probe and shade:GetAttribute("CoversScreen"))
   assert(math.abs(shade.AbsolutePosition.Y-probe.AbsolutePosition.Y)<=1 and math.abs(shade.AbsolutePosition.X-probe.AbsolutePosition.X)<=1,"shade starts at the screen corner")
   assert(shade.AbsoluteSize.X>=probe.AbsoluteSize.X and shade.AbsoluteSize.Y>=probe.AbsoluteSize.Y,"shade spans the screen")
   Kit.shadeClose(shade);gui:Destroy()
  end)
  test("hub -> Wardrobe -> Book: one dim, parent panels hidden, Back uncovers and slides in from the left",function()
   local hubGui,hubHost=menuGui("_HubShadeSpec",11);local wGui,wHost=menuGui("_WardrobeShadeSpec",12);local bGui,bHost=menuGui("_BookShadeSpec",13)
   table.insert(guis,hubGui);table.insert(guis,wGui);table.insert(guis,bGui)
   local hub=Hub.new(hubHost,{appearance=function()return{}end})
   local shop=Wardrobe.new(wHost,{appearance=function()return{}end})
   local book=Book.new(bHost,{send=function()end})
   local state={inventoryMask=127,nectar=40,petWearables={}}
   assert(hub:open({wallet=40,state=state,activeId=wardrobePet or Pets.collection[1].id}));settle()
   assert(hub.root.Visible and hub.shade.Visible and hub.root.Parent==hubHost,"panel is the shade's sibling now")
   assert(Kit.dimmingShades()==1)
   if wardrobePet then
    shop:open(wardrobePet,{wallet=40,row={owned={},equipped={}}});settle()
    assert(Kit.dimmingShades()==1 and hub.shade.BackgroundTransparency==1 and not hub.root.Visible,"Wardrobe hides the hub and its dim")
    assert(shop.root.Visible and dims(shop.shade))
    book:open({wallet=40,revision=1});settle()
    assert(Kit.dimmingShades()==1 and not shop.root.Visible and book.root.Visible,"three screens, one dim")
    book:close("back");settle()
    assert(shop.root.Visible and dims(shop.shade) and Kit.dimmingShades()==1)
    shop:close();settle()
   end
   assert(hub.root.Visible and dims(hub.shade) and Kit.dimmingShades()==1,"Back uncovers the hub")
   hub:close("back");assert(not hub.shade.Visible and not hub.root.Visible and Kit.dimmingShades()==0)
   shop:destroy();book:destroy();hub:destroy()
  end)
  test("slide: Pets move shared by Wardrobe / Book / Customize; header stays; Reduced Motion cuts",function()
   local gui,host=menuGui("_SlideSpec",11);table.insert(guis,gui)
   local body=Kit.frame(host,"Body",nil,UDim2.new(),UDim2.fromOffset(400,300))
   local header={root=Kit.frame(body,"Header",nil,UDim2.fromOffset(0,0),UDim2.fromOffset(400,40))}
   local item=Kit.frame(body,"Item",nil,UDim2.fromOffset(20,60),UDim2.fromOffset(100,40))
   local moved=Kit.slideIn(body,Kit.SlideOffset,Kit.headerSkip(header))
   if Kit.reduced()then assert(moved==0 and item.Position==UDim2.fromOffset(20,60),"Reduced Motion is a cut")
   else
    assert(moved==1 and header.root.Position==UDim2.fromOffset(0,0),"header never slides")
    assert(item.Position.X.Offset>20,"starts to the right")
    -- A second slide mid-flight finishes from the first goal, never from a half-way spot.
    Kit.slideIn(body,-Kit.SlideOffset,Kit.headerSkip(header))
    task.wait(Kit.Motion.screen+.1);assert(item.Position==UDim2.fromOffset(20,60),"settles home")
   end
   gui:Destroy()
  end)
  if wardrobePet then
   test("Wardrobe cards: pure framing / key / visibility rules",function()
    assert(select(1,Wardrobe.cardFraming("Hat"))=="head"and select(1,Wardrobe.cardFraming("Tail"))=="tail"and select(1,Wardrobe.cardFraming("Shirt"))=="body")
    assert(Wardrobe.cardKey("pip","beanie",nil)=="pip:beanie:"and Wardrobe.cardKey("pip","beanie",Color3.new(1,0,0))~=Wardrobe.cardKey("pip","beanie",nil))
    assert(Wardrobe.cardVisible(100,96,0,400)and not Wardrobe.cardVisible(600,96,0,400)and Wardrobe.cardVisible(-90,96,0,400))
   end)
   test("Wardrobe cards: visible cards get a cached 3D preview, built one per frame",function()
    local gui,host=menuGui("_WardrobePreviewSpec",12);table.insert(guis,gui)
    local shop=Wardrobe.new(host,{appearance=function()return{}end})
    shop:open(wardrobePet,{wallet=0,row={owned={},equipped={}}});settle(1)
    local first=shop.previewCount or 0;assert(first<=2,"about one build per frame")
    settle(#shop.tiles+4)
    local built=0
    for _,tile in ipairs(shop.tiles)do
     if tile.preview then built+=1;assert(tile.swatch:FindFirstChild("CardPreview")and tile.swatch:GetAttribute("Preview"))
      assert(tile.swatch.TierDot.ZIndex>tile.preview.viewport.ZIndex,"tier dot stays on top")
     elseif tile.preview==false then assert(tile.swatch.BackgroundTransparency<1,"fallback keeps the colour tile")end
    end
    assert(built>0 or #shop.tiles==0,"previews landed")
    assert(shop:livePreviews()<=Wardrobe.CardPreviewLive and shop.previewCount<=Wardrobe.CardPreviewCache,"bounded")
    -- Code review: a card scrolled off screen gives its ViewportFrame up.
    local list=shop.list
    if list.AbsoluteCanvasSize.Y>list.AbsoluteWindowSize.Y+220 then
     list.CanvasPosition=Vector2.new(0,list.AbsoluteCanvasSize.Y);settle(3)
     assert(not shop.tiles[1].preview and not shop.tiles[1].swatch:FindFirstChild("CardPreview"),"off-screen card detached")
     list.CanvasPosition=Vector2.zero;settle(3)
    end
    local count=shop.previewCount
    local tab=shop.tab;shop:shiftTab(1);settle(4);shop:setTab(tab);settle(3)
    local reused=0;for _,tile in ipairs(shop.tiles)do if tile.preview then reused+=1 end end
    assert(reused>=built,"cards come back from the cache") -- a card still sliding in may build after the first count;assert(shop.previewCount<=count+8)
    shop:close();assert(next(shop.previews)==nil,"cache freed on close")
    shop:destroy();gui:Destroy()
   end)
   test("Wardrobe equip is optimistic: worn at once, a snapshot in flight keeps it, a refusal rolls back with a toast",function()
    local gui,host=menuGui("_WardrobeOptimisticSpec",12);table.insert(guis,gui)
    local orders,rolled={},{}
    local shop=Wardrobe.new(host,{appearance=function()return{}end,equip=function(o)table.insert(orders,o)end,rolledBack=function(o)table.insert(rolled,o)end})
    local item=Catalog.forPet(wardrobePet).order[1]
    local tabIndex=1;for i,tab in ipairs(Catalog.Tabs)do if tab.slot==item.slot then tabIndex=i end end
    shop.tab=tabIndex
    shop:open(wardrobePet,{wallet=0,row={owned={item.id},equipped={}}});settle()
    for i,tile in ipairs(shop.tiles)do if tile.id==item.id then shop:focus(i,true)end end
    assert(shop:act()and #orders==1 and orders[1].wear==item.id)
    assert(Catalog.equippedIn(wardrobePet,shop.ctx.row.equipped,item.slot)==item.id,"worn at once")
    assert(shop.root:GetAttribute("PaneState")=="equipped"and shop.status.Text~="Saving…","no Saving… wait")
    shop:setContext({row={owned={item.id},equipped={}}})
    assert(Catalog.equippedIn(wardrobePet,shop.ctx.row.equipped,item.slot)==item.id,"snapshot during the save keeps it")
    assert(shop:result({id=orders[1].id,status="Rejected",reason="Busy"}))
    assert(Catalog.equippedIn(wardrobePet,shop.ctx.row.equipped,item.slot)==nil and #rolled==1 and shop.errorId==item.id,"rolled back")
    assert(UICopy.has("shop.rolledBack"))
    -- Saved keeps it and says nothing more.
    assert(shop:act()and #orders==2);assert(shop:result({id=orders[2].id,status="Saved"})and #rolled==1)
    assert(Catalog.equippedIn(wardrobePet,shop.ctx.row.equipped,item.slot)==item.id)
    -- Code review: two quick taps (take off, wear again). The first saves, the second is
    -- refused: the look rolls back to the first one's saved result, not past it.
    assert(shop:act()and shop:act()and #orders==4 and orders[3].wear==false and orders[4].wear==item.id)
    assert(Catalog.equippedIn(wardrobePet,shop.ctx.row.equipped,item.slot)==item.id,"second tap worn at once")
    assert(shop:result({id=orders[3].id,status="Saved"}))
    assert(Catalog.equippedIn(wardrobePet,shop.ctx.row.equipped,item.slot)==item.id,"a superseded save keeps the newer look")
    assert(shop:result({id=orders[4].id,status="Rejected",reason="Busy"})and #rolled==2)
    assert(Catalog.equippedIn(wardrobePet,shop.ctx.row.equipped,item.slot)==nil,"rolled back to the saved take-off, not past it")
    -- And a refused first tap leaves the newer one in flight on.
    assert(shop:act()and shop:act()and #orders==6)
    assert(shop:result({id=orders[5].id,status="Rejected",reason="Busy"})and #rolled==3)
    assert(Catalog.equippedIn(wardrobePet,shop.ctx.row.equipped,item.slot)==nil,"the newer tap (take off) stays on")
    assert(shop:result({id=orders[6].id,status="Saved"})and shop.pending==nil and #shop.equips==0)
    assert(Catalog.equippedIn(wardrobePet,shop.ctx.row.equipped,item.slot)==nil)
    shop:destroy();gui:Destroy()
   end)
  end
  test("modal cursor: pure wanted state",function()
   local b,i=Cursor.wanted(true,Enum.MouseBehavior.LockCurrentPosition,false)
   assert(b==Enum.MouseBehavior.Default and i==true)
   b,i=Cursor.wanted(true,Enum.MouseBehavior.Default,true);assert(b==nil and i==nil)
   b,i=Cursor.wanted(false,Enum.MouseBehavior.LockCenter,false);assert(b==nil and i==nil,"closed: the camera owns the mouse")
  end)
  test("modal cursor: window focus restores the cursor while a screen is open; RMB is sunk only then",function()
   local focused=Instance.new("BindableEvent")
   local input={MouseBehavior=Enum.MouseBehavior.LockCurrentPosition,MouseIconEnabled=false,WindowFocused=focused.Event}
   local bound,unbound=0,0
   local actions={BindActionAtPriority=function(_,name,_,_,_,kind)assert(name==Cursor.Action and kind==Enum.UserInputType.MouseButton2);bound+=1 end,
    UnbindAction=function()unbound+=1 end}
   local open=true
   local c=Cursor.new({isOpen=function()return open end,input=input,actions=actions,parent=parent})
   focused:Fire();task.wait()
   assert(input.MouseBehavior==Enum.MouseBehavior.Default and input.MouseIconEnabled==true and c.refocused==1)
   assert(c.button and c.button.Visible and c.button.Modal and bound==1)
   input.MouseBehavior=Enum.MouseBehavior.LockCurrentPosition;c:step();assert(input.MouseBehavior==Enum.MouseBehavior.Default,"camera cannot re-capture under a menu")
   open=false;c:step();assert(not c.button.Visible and unbound==1)
   input.MouseBehavior=Enum.MouseBehavior.LockCenter;focused:Fire();task.wait()
   assert(input.MouseBehavior==Enum.MouseBehavior.LockCenter,"no menu: left alone")
   c:destroy();focused:Destroy()
  end)
 end,function(e)return tostring(e).." | "..debug.traceback()end)
 for _,gui in ipairs(guis)do if gui.Parent then gui:Destroy()end end
 assert(ok,problem)
 return{passed=#cases,cases=cases,evidence="client fixtures in inset ScreenGuis; captures still needed for the live overlays"}
end
