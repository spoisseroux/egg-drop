-- Studio Client. Overnight 2026-11-14 slice B (SYSTEMS-SCOPE 2.5, 2.6): the Wardrobe's tabs and
-- recolour variants.
--  * Only slot tabs with at least one item for the pet are shown (Ankle stays hidden until an
--    anklet exists); Q / E cycle the visible tabs only; the Tab attribute is the tab's id.
--  * The new tabs' labels come from UICopy (variants.tab.*).
--  * Tab strip: every label fits its segment with room to spare. When equal segments cannot
--    hold the labels (ten tabs on the 812 x 354 phone sheet) the strip scrolls sideways, the
--    track is wider than the bar, and the front tab is always scrolled into view.
--  * A variant is its own card, right after its base, with its colour on the swatch and a
--    colour dot; its pane note names the base; the preview signature keeps the variant id.
--  * Taking a slot off still works for a slot whose tab is hidden (pure applyEquip).
-- Usage: require(PlayerScripts.Client.ZZSpecs.WardrobeTabs)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Shared=game:GetService("ReplicatedStorage").Shared
 local Shop=require(client.WardrobeShop)
 local Kit=require(client.DeckKit)
 local Catalog=require(Shared.WearableCatalog)
 local UICopy=require(Shared.UICopy)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local gui=Instance.new("ScreenGui");gui.Name="_WardrobeTabsSpec";gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=parent
 local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
 local pet=Shop.firstPet()
 local ctx={wallet=500,row={owned={},equipped={}},week=false}
 local ok,problem=xpcall(function()
  test("pure: visible tabs are the slots with items, in catalogue order; empty tabs are hidden",function()
   local tabs=Shop.tabsFor(pet)
   assert(#tabs>=1 and #tabs<=#Catalog.Tabs)
   local last=0
   for _,tab in ipairs(tabs)do
    assert(#Catalog.inTab(pet,tab.slot)>0,tab.id.." is shown with no items")
    local at=0;for i,all in ipairs(Catalog.Tabs)do if all.id==tab.id then at=i end end
    assert(at>last,"catalogue order");last=at
   end
   for _,tab in ipairs(Catalog.Tabs)do
    if #Catalog.inTab(pet,tab.slot)==0 then
     for _,shown in ipairs(tabs)do assert(shown.id~=tab.id,tab.id.." is empty but shown")end
    end
   end
   -- A pet with nothing to sell keeps every tab (the screen still has a bar and the empty line).
   assert(#Shop.tabsFor("no_such_pet")==#Catalog.Tabs and #Shop.tabsFor(nil)==#Catalog.Tabs)
   assert(Shop.tabKey(tabs)~=""and Shop.tabKey(tabs)==Shop.tabKey(Shop.tabsFor(pet)))
  end)
  test("pure: the new tabs' labels are UICopy strings; older tabs keep the catalogue label",function()
   for _,tab in ipairs(Catalog.Tabs)do
    local label=Shop.tabLabel(tab)
    assert(type(label)=="string"and label~="",tab.id)
    if UICopy.has("variants.tab."..tab.id)then assert(label==UICopy.get("variants.tab."..tab.id),tab.id)else assert(label==tab.label,tab.id)end
   end
   for _,id in ipairs({"eyewear","cheek","wrist","ankle"})do assert(UICopy.has("variants.tab."..id),id)end
  end)
  test("pure: the tab strip holds every label; it scrolls when equal segments cannot",function()
   local ten={"Hat","Shirt","Neck","Ears","Eyes","Mouth","Tail","Eyewear","Cheek","Wrist"}
   local function widest(labels,size)
    local w=0;for _,l in ipairs(labels)do w=math.max(w,Kit.measure(l,"Strong",size).X)end;return w
   end
   -- Desktop bar (800) and the phone bar at 812 x 354 (Shop.compactGrid).
   local phoneBar=Shop.compactGrid(812,300).gw
   for _,case in ipairs({{800,16},{phoneBar,if phoneBar<400 then 12 else 14},{320,12}})do
    local plan=Shop.tabStrip(ten,case[1],case[2],false)
    assert(plan.segment>=widest(ten,case[2])+Shop.TabPad-.01,"a label has no room at "..case[1])
    if plan.scroll then assert(plan.track>case[1],"a scrolling track is wider than its bar")
    else assert(plan.track==case[1]and math.abs(plan.segment-(case[1]-8)/#ten)<.01)end
    assert(math.abs(plan.track-(#ten*plan.segment+8))<.5,"track = segments + the 4 px insets")
   end
   assert(Shop.tabStrip(ten,phoneBar,14,false).scroll==true,"ten tabs scroll on the 812 x 354 phone")
   assert(Shop.tabStrip({"Hat","Shirt","Neck"},800,16,false).scroll==false,"three tabs never scroll")
   -- While Roblox auto-translates, segments keep 35% headroom for the longer word.
   local plain,translated=Shop.tabStrip(ten,5000,16,false),Shop.tabStrip(ten,700,16,true)
   assert(not plain.scroll and translated.segment>=widest(ten,16)*(1+Shop.TabHeadroom)+Shop.TabPad-1)
  end)
  test("pure: revealing a tab scrolls just far enough, never past either end",function()
   local plan={track=848,segment=84,scroll=true}
   assert(Shop.tabReveal(1,plan,528,200)==0,"first tab: back to the start")
   assert(Shop.tabReveal(10,plan,528,0)==848-528,"last tab: to the end")
   local x=Shop.tabReveal(5,plan,528,0);assert(x==0,"a tab already in view does not move")
   local seven=Shop.tabReveal(7,plan,528,0)
   assert(seven>0 and 4+6*84>=seven and 4+7*84<=seven+528,"tab 7 is inside the window")
  end)
  for _,size in ipairs({Vector2.new(1280,720),Vector2.new(812,354)})do
   test(tostring(size).." built: tabs are the visible ones, Q / E cycle them, the strip keeps the front tab in view",function()
    local host=Instance.new("Frame");host.BackgroundTransparency=1;host.Size=UDim2.fromOffset(size.X,size.Y);host.Parent=gui
    local shop=Shop.new(host,{appearance=function()return{}end})
    shop:open(pet,ctx);settle()
    local tabs=Shop.tabsFor(pet)
    assert(#shop.tabs.buttons==#tabs and shop.root:GetAttribute("TabCount")==#tabs,"one tab button per visible tab")
    assert(shop.root:GetAttribute("Tab")==tabs[1].id)
    for i,label in ipairs(shop.tabs.labels)do
     assert(label.Text==Shop.tabLabel(tabs[i]),"label "..i)
     assert(label.TextFits,"tab label "..label.Text.." is cut at "..tostring(size))
    end
    -- E walks every visible tab once, then stops at the last; Q walks back.
    for i=2,#tabs do
     assert(shop:shiftTab(1)==true and shop.root:GetAttribute("Tab")==tabs[i].id,"E to "..tabs[i].id)
     assert(#shop.tiles>=2,tabs[i].id.." has a None card and an item")
     if shop.tabStripFrame then
      settle()
      local strip=shop.tabStripFrame;local button=shop.tabs.buttons[i]
      local left=button.AbsolutePosition.X;local right=left+button.AbsoluteSize.X
      assert(left>=strip.AbsolutePosition.X-1 and right<=strip.AbsolutePosition.X+strip.AbsoluteSize.X+1,tabs[i].id.." tab is outside the strip window")
     end
    end
    assert(shop:shiftTab(1)==false,"E stops at the last visible tab")
    for i=#tabs-1,1,-1 do assert(shop:shiftTab(-1)==true and shop.root:GetAttribute("Tab")==tabs[i].id)end
    assert(shop:shiftTab(-1)==false)
    assert(shop.root:GetAttribute("TabsScroll")==(shop.tabStripFrame~=nil))
    if size.X<1000 and #tabs>=10 then assert(shop.tabStripFrame~=nil,"ten tabs scroll on the phone")end
    if shop.tabStripFrame then
     local strip=shop.tabStripFrame
     assert(strip.CanvasSize.X.Offset>strip.AbsoluteSize.X and strip.ScrollingDirection==Enum.ScrollingDirection.X)
     assert(strip.AbsolutePosition.X+strip.AbsoluteSize.X<=shop.list.AbsolutePosition.X+shop.list.AbsoluteSize.X+1,"the strip stays over the grid")
    end
    shop:close();shop:destroy();host:Destroy()
   end)
  end
  test("variants are their own cards after their base, in their own colour, with a colour dot",function()
   local variants={}
   for _,item in ipairs(Catalog.forPet(pet).order)do if item.variant then table.insert(variants,item)end end
   if #variants==0 then return end -- catalogue without variants (lane K not landed): nothing to show
   local host=Instance.new("Frame");host.BackgroundTransparency=1;host.Size=UDim2.fromOffset(1280,720);host.Parent=gui
   local shop=Shop.new(host,{appearance=function()return{}end})
   shop:open(pet,ctx);settle()
   local variant=variants[1]
   local tabIndex;for i,tab in ipairs(shop.tabList)do if tab.slot==variant.slot then tabIndex=i end end
   assert(tabIndex,"the variant's slot has a tab");shop:setTab(tabIndex);settle()
   local baseAt,variantAt
   for i,tile in ipairs(shop.tiles)do if tile.id==variant.base then baseAt=i elseif tile.id==variant.id then variantAt=i end end
   assert(baseAt and variantAt and variantAt>baseAt,"the variant card follows its base")
   local tile=shop.tiles[variantAt]
   local colour=Shop.variantColor(variant)
   assert(colour~=nil and tile.variantColor==colour and tile.button:GetAttribute("Variant")==true)
   assert(tile.button:GetAttribute("VariantColor")==colour:ToHex())
   local dot=tile.swatch:FindFirstChild("VariantDot")
   assert(dot and dot.BackgroundColor3==colour and dot:FindFirstChild("VariantRing"),"colour dot with its ring")
   assert(shop.tiles[baseAt].swatch:FindFirstChild("VariantDot")==nil and shop.tiles[baseAt].variantColor==nil,"a base card has no dot")
   assert(tile.name.Text==variant.name and tile.status.Text=="★ "..variant.price,"its own name and price")
   shop:focus(variantAt);settle()
   assert(shop.name.Text==variant.name and shop.root:GetAttribute("FocusedItem")==variant.id)
   -- The preview wears the variant id (not its base), so beanie and beanie_mint differ.
   local signature=shop.root:GetAttribute("PreviewWearables")
   assert(string.find(signature,variant.id,1,true),"preview signature keeps the variant id: "..tostring(signature))
   assert(Shop.previewSignature(pet,{[variant.keys[1]]=variant.base})~=Shop.previewSignature(pet,{[variant.keys[1]]=variant.id}))
   assert(Shop.previewSignature(pet,{[variant.keys[1]]="no_such_item"})=="","an unknown id is dropped")
   -- Owning the base does not own the variant.
   shop:setContext({row={owned={variant.base},equipped={}}});settle()
   assert(shop:statusOf(variant.id).kind=="buy"and shop:statusOf(variant.base).kind=="owned")
   shop:close();shop:destroy();host:Destroy()
  end)
  test("pure: a variant's note names its base; a base item's note is unchanged; bad colours are ignored",function()
   for _,item in ipairs(Catalog.forPet(pet).order)do
    if item.variant then
     local base=Catalog.item(pet,item.base)
     local note=Shop.note(pet,item.id,{})
     local baseNote=Shop.note(pet,item.base,{})
     -- An exclusion note (open crown, neutral-only mouth) outranks the recolour line.
     assert(note==UICopy.get("variants.note",{item=base.name})or note==baseNote,item.id.." note: "..note)
    end
   end
   assert(Shop.variantColor(nil)==nil and Shop.variantColor({variant=true,color="not a colour"})==nil)
   assert(Shop.variantColor({variant=false,color="#FF0000"})==nil,"a base item has no variant colour")
   assert(Shop.variantColor({variant=true,color="#7FE0CF"})==Color3.fromHex("#7FE0CF"))
  end)
  test("pure: taking off a slot works for any slot, shown as a tab or not",function()
   for _,tab in ipairs(Catalog.Tabs)do
    local keys=Catalog.slotKeys(pet,tab.slot)
    local worn={};for _,key in ipairs(keys)do worn[key]="anything"end
    worn.Other="kept"
    local after=Shop.applyEquip(pet,worn,Shop.NoneId,false,tab.slot)
    for _,key in ipairs(keys)do assert(after[key]==nil,tab.id.." "..key.." not taken off")end
    assert(after.Other=="kept")
   end
  end)
 end,function(e)return tostring(e).." | "..debug.traceback()end)
 gui:Destroy()
 if not ok then error(problem,0)end
 return{passed=#cases,cases=cases}
end
