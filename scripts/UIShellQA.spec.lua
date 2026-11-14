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
  test("R3.1: phone sheets dim too (a clear request still dims unless ShadeClear); attachShade follows its container",function()
   local gui,host=menuGui("_ShadeR3Spec",11);table.insert(guis,gui)
   local shade=Kit.modalShade(host,"Phone",30);local owner={}
   Kit.setShadeAlpha(shade,1);Kit.shadeOpen(owner,shade)
   assert(dims(shade),"the old phone-sheet alpha 1 dims at Kit.ShadeAlpha")
   shade:SetAttribute("ShadeClear",true);Kit.setShadeAlpha(shade,1);assert(shade.BackgroundTransparency==1,"ShadeClear keeps a self-painted screen clear")
   Kit.shadeClose(owner)
   local container=Instance.new("Frame");container.Name="Root";container.Size=UDim2.fromScale(1,1);container.BackgroundTransparency=1;container.ZIndex=20
   container.Visible=false;container.Parent=host
   local key={};local dim=Kit.attachShade(key,container,{name="RootDim"})
   assert(not dim.Visible and not Kit.shadeIsOpen(key)and dim.ZIndex==19)
   container.Visible=true;assert(dim.Visible and dims(dim)and Kit.shadeIsOpen(key),"opens with its container")
   settle();local probe=Kit.screenProbe(host)
   assert(math.abs(dim.AbsolutePosition.Y-probe.AbsolutePosition.Y)<=1,"covers under the top bar")
   container.Visible=false;assert(not dim.Visible and not Kit.shadeIsOpen(key),"closes with it")
   container:Destroy();assert(not dim.Parent)
   gui:Destroy()
  end)
  test("R3.8: an overlay shade dims over a screen without covering it; How it works opens, explains stamps, closes",function()
   local gui,host=menuGui("_ShadeOverlaySpec",11);table.insert(guis,gui)
   local base=Kit.modalShade(host,"Base",30);local covered={};local owner={}
   Kit.shadeOpen(owner,base,function(c)table.insert(covered,c)end)
   local over=Kit.modalShade(host,"Over",40);local key={}
   Kit.shadeOpen(key,over,nil,{overlay=true});settle()
   assert(dims(over)and base.BackgroundTransparency==1 and Kit.dimmingShades()==1,"one dim")
   assert(#covered==0,"the screen under an overlay is not told it is covered")
   Kit.shadeClose(key);assert(dims(base))
   Kit.shadeClose(owner)
   local How=require(client.HowItWorks)
   for _,id in ipairs(How.Order)do
    local cards=How.cards(id);assert(#cards>=2 and #cards<=3,id.." has 2 or 3 cards")
    for _,card in ipairs(cards)do assert(card.title~=""and not string.find(card.title,"r3.",1,true)and card.line~="",id.." copy")end
   end
   assert(Kit.helpIdFor({tint="hatch"})=="hatch"and Kit.helpIdFor({tint="book"})=="book"and Kit.helpIdFor({tint=Kit.Sticker.cream})==nil
    and Kit.helpIdFor({tint="quests",help=false})==nil and Kit.helpIdFor({help="park"})=="park")
   local depth=Kit.shadeDepth()
   assert(How.open("quests")and How.isOpen()and How.openId()=="quests");settle()
   local panel=How.panel();assert(panel and panel:GetAttribute("HelpId")=="quests")
   assert(panel:FindFirstChild("Card_b")and panel.Card_b:FindFirstChild("StampSample"),"the stamp card is explained with a sample card")
   assert(Kit.shadeDepth()==depth+1)
   for _,node in ipairs(panel:GetDescendants())do
    if node:IsA("TextLabel")and node.Visible and node.Text~=""then assert(node.TextSize>=12,"text floor: "..node:GetFullName())end
   end
   local probe=Kit.screenProbe(panel)
   assert(panel.AbsolutePosition.X>=probe.AbsolutePosition.X and panel.AbsolutePosition.X+panel.AbsoluteSize.X<=probe.AbsolutePosition.X+probe.AbsoluteSize.X+1,"panel on screen")
   local closed;assert(How.close("done")and not How.isOpen()and How.panel()==nil and Kit.shadeDepth()==depth)
   assert(How.open("book",{onClosed=function(id)closed=id end}));How.close();task.wait();assert(closed=="book","replayable, with a close hook")
   for _,size in ipairs({Vector2.new(812,354),Vector2.new(844,390),Vector2.new(1920,1080)})do
    local g=How.layout(size.X,size.Y,How.cards("quests"))
    assert(g.panelW<=size.X-24 and g.panelH<=size.Y,tostring(size).." fits")
    assert(g.compact==(size.X<1000),tostring(size).." compact rule")
   end
   gui:Destroy()
  end)
  test("R3.2: sheetTop measures from the real screen top (no second keep-out); scrollBleed keeps tiles in place",function()
   local gui=Instance.new("ScreenGui");gui.Name="_SheetTopSpec";gui.ScreenInsets=Enum.ScreenInsets.None;gui.Parent=parent;table.insert(guis,gui)
   local host=Instance.new("Frame");host.BackgroundTransparency=1;host.Size=UDim2.fromScale(1,1);host.Parent=gui;settle()
   assert(Kit.sheetTop(host,58)==60,"a full-screen host starts the sheet 60 down")
   local lower=Instance.new("Frame");lower.BackgroundTransparency=1;lower.Position=UDim2.fromOffset(0,58);lower.Size=UDim2.new(1,0,1,-58);lower.Parent=gui;settle()
   assert(Kit.sheetTop(lower,58)==2,"a host already under the controls adds only 2")
   local scroll=Instance.new("ScrollingFrame");scroll.Position=UDim2.fromOffset(20,64);scroll.Size=UDim2.fromOffset(200,200);scroll.Parent=host
   local tile=Instance.new("Frame");tile.Size=UDim2.fromOffset(100,40);tile.Parent=scroll;settle()
   local before=tile.AbsolutePosition
   local pad=Kit.scrollBleed(scroll,4);Kit.scrollBleed(scroll,4);settle()
   assert(pad==4 and scroll.Position==UDim2.fromOffset(16,60)and scroll.Size==UDim2.fromOffset(208,208),"grown once, not twice")
   assert((tile.AbsolutePosition-before).Magnitude<1,"tiles keep their place")
   gui:Destroy()
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
    -- QA v2 R4.2: the slot's None card comes first; taking off is that card.
    local itemIndex,noneIndex
    for i,tile in ipairs(shop.tiles)do if tile.id==item.id then itemIndex=i elseif tile.id==Wardrobe.NoneId then noneIndex=i end end
    assert(noneIndex==1 and itemIndex,"None leads the slot")
    local function onItem()shop:focus(itemIndex,true)end
    local function onNone()shop:focus(noneIndex,true)end
    onItem()
    assert(shop:act()and #orders==1 and orders[1].wear==item.id)
    assert(Catalog.equippedIn(wardrobePet,shop.ctx.row.equipped,item.slot)==item.id,"worn at once")
    assert(shop.root:GetAttribute("PaneState")=="equipped"and shop.status.Text~="Saving…","no Saving… wait")
    -- QA v2 R3.5: worn = the button, disabled, reading Equipped; pressing it does nothing.
    assert(shop.action.Visible and not Kit.buttonState(shop.action).enabled and Kit.buttonState(shop.action).label.Text==UICopy.get("r4.equipped"))
    assert(not shop:act()and #orders==1,"Equipped never sends")
    shop:setContext({row={owned={item.id},equipped={}}})
    assert(Catalog.equippedIn(wardrobePet,shop.ctx.row.equipped,item.slot)==item.id,"snapshot during the save keeps it")
    assert(shop:result({id=orders[1].id,status="Rejected",reason="Busy"}))
    assert(Catalog.equippedIn(wardrobePet,shop.ctx.row.equipped,item.slot)==nil and #rolled==1 and shop.errorId==item.id,"rolled back")
    assert(UICopy.has("shop.rolledBack"))
    -- Saved keeps it and says nothing more.
    assert(shop:act()and #orders==2);assert(shop:result({id=orders[2].id,status="Saved"})and #rolled==1)
    assert(Catalog.equippedIn(wardrobePet,shop.ctx.row.equipped,item.slot)==item.id)
    -- Code review: two quick taps (None takes it off, then wear again). The first saves,
    -- the second is refused: the look rolls back to the first one's saved result, not past it.
    onNone();assert(shop:act());onItem();assert(shop:act()and #orders==4 and orders[3].wear==false and orders[3].slot==item.slot and orders[4].wear==item.id)
    assert(Catalog.equippedIn(wardrobePet,shop.ctx.row.equipped,item.slot)==item.id,"second tap worn at once")
    assert(shop:result({id=orders[3].id,status="Saved"}))
    assert(Catalog.equippedIn(wardrobePet,shop.ctx.row.equipped,item.slot)==item.id,"a superseded save keeps the newer look")
    assert(shop:result({id=orders[4].id,status="Rejected",reason="Busy"})and #rolled==2)
    assert(Catalog.equippedIn(wardrobePet,shop.ctx.row.equipped,item.slot)==nil,"rolled back to the saved take-off, not past it")
    -- And a refused first tap leaves the newer one in flight on.
    onItem();assert(shop:act());onNone();assert(shop:act()and #orders==6 and orders[6].wear==false)
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
