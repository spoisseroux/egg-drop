-- Studio Client. QA v2 track R4 (Wardrobe, Customize, Deck style content):
-- R4.1 hat fit lifts; R4.2 Wardrobe None cards (take-off through wearableEquip
-- itemId=false); R4.3 Customize previews (pane ZIndex, focus preview, card previews);
-- R4.4 saturated fruit tiles and the free Original colour card (hueClear, two presses);
-- R4.5 the Toys icon and "More from eggs" (no egg rows); R4.6 Deck style ball drops;
-- R3.5 Equipped / In use = the button, disabled; R3.6 tab labels keep their ink after a
-- theme repaint; R2.5 footer chips per device, explained once.
-- Usage: require(PlayerScripts.Client.ZZSpecs.R4Content)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Shared=game:GetService("ReplicatedStorage").Shared
 local Kit=require(client.DeckKit);local Art=require(client.DeckArt)
 local Wardrobe=require(client.WardrobeShop);local View=require(client.HueEggView);local Hue=require(client.HueIntent)
 local Cache=require(client.CardPreviewCache);local TabInk=require(client.TabInk);local Legend=require(client.HintLegend)
 local Toy=require(client.ToyTabIcon);local Balls=require(client.BallShop);local Plates=require(client.FaceplateShop);local Backs=require(client.BackgroundShop)
 local Catalog=require(Shared.WearableCatalog);local Pets=require(Shared.PetCatalog);local H=require(Shared.HueCatalog);local UICopy=require(Shared.UICopy)
 local Glyphs=require(client.HintGlyphs)
 local Run=game:GetService("RunService")
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function frames(n)for _=1,n or 3 do Run.Heartbeat:Wait()end end
 local wardrobePet;for _,pet in ipairs(Pets.collection)do if Catalog.hasItems(pet.id)then wardrobePet=pet.id;break end end
 local guis={}
 local function menuGui(name)
  local gui=Instance.new("ScreenGui");gui.Name=name;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.ResetOnSpawn=false;gui.Parent=parent
  local host=Instance.new("Frame");host.Name="Host";host.BackgroundTransparency=1;host.Size=UDim2.fromScale(1,1);host.Parent=gui
  table.insert(guis,gui);return gui,host
 end
 local ok,problem=xpcall(function()
  test("R4.1 pure: hat fit lifts lift the sun hat and beanie, nothing else",function()
   assert(Catalog.fitOffset("bear","sunhat").Y>=.02 and Catalog.fitOffset("bear","beanie").Y>0)
   assert(Catalog.fitOffset("bear","flowercrown")==Vector3.zero and Catalog.fitOffset("bear","tee")==Vector3.zero)
   assert(Catalog.fitOffset("ovelle","sunhat")==Vector3.zero and Catalog.fitOffset(nil,nil)==Vector3.zero)
  end)
  if wardrobePet then
   test("R4.2 / R3.5 pure: None leads each slot; worn = Equipped, disabled; take-off by slot",function()
    local item=Catalog.forPet(wardrobePet).order[1]
    local list=Wardrobe.tileList(wardrobePet,item.slot)
    assert(list[1].id==Wardrobe.NoneId and list[1].none and list[2].id~=Wardrobe.NoneId)
    assert(#Wardrobe.tileList(wardrobePet,"NoSuchSlot")==0,"no items, no None card")
    local bare={wallet=0,row={owned={item.id},equipped={}}}
    local worn={wallet=0,row={owned={item.id},equipped=Wardrobe.previewWearables(wardrobePet,{},item.id)}}
    local n=Wardrobe.noneStatus(wardrobePet,item.slot,bare);assert(n.kind=="equipped"and n.button=="Equipped"and n.enabled==false)
    n=Wardrobe.noneStatus(wardrobePet,item.slot,worn);assert(n.kind=="owned"and n.enabled and n.button==UICopy.get("r4.wardrobe.takeOff"))
    local s=Wardrobe.status(wardrobePet,item.id,worn);assert(s.kind=="equipped"and s.button=="Equipped"and s.enabled==false)
    assert(Wardrobe.status(wardrobePet,item.id,bare).button=="Wear")
    assert(select(1,Wardrobe.tileStatus(wardrobePet,Wardrobe.NoneId,bare,item.slot))=="WEARING")
    local off=Wardrobe.applyEquip(wardrobePet,worn.row.equipped,Wardrobe.NoneId,false,item.slot)
    assert(Catalog.equippedIn(wardrobePet,off,item.slot)==nil,"None empties its slot")
    assert(Catalog.equippedIn(wardrobePet,Wardrobe.replayEquips(wardrobePet,worn.row.equipped,{{petId=wardrobePet,itemId=Wardrobe.NoneId,wear=false,slot=item.slot}}),item.slot)==nil)
   end)
   test("R4.2 built: the None card takes the slot off through wearableEquip (itemId=false)",function()
    local _,host=menuGui("_R4Wardrobe")
    local orders={}
    local shop=Wardrobe.new(host,{appearance=function()return{}end,equip=function(o)table.insert(orders,o)end})
    local item=Catalog.forPet(wardrobePet).order[1]
    for i,tab in ipairs(Catalog.Tabs)do if tab.slot==item.slot then shop.tab=i end end
    shop:open(wardrobePet,{wallet=0,row={owned={item.id},equipped=Wardrobe.previewWearables(wardrobePet,{},item.id)}});frames()
    assert(shop.tiles[1].id==Wardrobe.NoneId and shop:focusedId()==item.id,"lands on the worn item")
    assert(not Kit.buttonState(shop.action).enabled and not shop:act(),"Equipped is inert")
    shop:focus(1,true);assert(shop.root:GetAttribute("PaneState")=="owned"and shop.name.Text=="None")
    assert(shop:act()and #orders==1 and orders[1].wear==false and orders[1].slot==item.slot)
    assert(Catalog.equippedIn(wardrobePet,shop.ctx.row.equipped,item.slot)==nil,"bare at once (optimistic)")
    assert(shop.root:GetAttribute("PaneState")=="equipped")
    shop:destroy()
   end)
  end
  test("R4.3 pure: a focused card previews one more fruit / original / finish / toy",function()
   local base={mainDoses={rose=1,tide=0,citrus=0,iris=0},secondaryDoses=H.emptyCounts(),finish="standard",toyId="none"}
   assert(View.previewAppearance(base,"hue","rose","main").mainDoses.rose==2 and base.mainDoses.rose==1,"base is never written")
   assert(View.previewAppearance(base,"hue","tide","secondary").secondaryDoses.tide==1)
   assert(View.previewAppearance(base,"hue","original","main").mainDoses.rose==0 and View.previewAppearance(base,"hue","reset","main").mainDoses.rose==0)
   local max={mainDoses={rose=5,tide=0,citrus=0,iris=0}};assert(View.previewAppearance(max,"hue","rose","main").mainDoses.rose==5)
   assert(View.previewAppearance(base,"materials","gloss").finish=="gloss"and View.previewAppearance(base,"materials","nope").finish=="standard")
   assert(View.previewAppearance(base,"toys","bone").toyId=="bone")
  end)
  test("R4.3 pure: card preview cache visibility and stable keys",function()
   assert(Cache.visible(100,96,0,400)and not Cache.visible(600,96,0,400))
   local a=Cache.key("pip","rose",{mainDoses={rose=1,tide=0},finish="gloss"})
   assert(a==Cache.key("pip","rose",{finish="gloss",mainDoses={tide=0,rose=1}}),"key ignores table order")
   assert(a~=Cache.key("pip","rose",{mainDoses={rose=2,tide=0},finish="gloss"}))
  end)
  test("R4.5 / R3.5 pure: Toys get the bone icon; worn charm says Equipped",function()
   assert(View.tabList()[4].icon=="toy"and Kit.VectorIcons.toy~=nil)
   for _,k in ipairs(Toy.knobs())do assert(k.X>.1 and k.X<.9 and k.Y>.1 and k.Y<.9,"knobs inside the holder")end
   local p=View.charmPane({id="ring",wearing=true},"Bear",nil);assert(p.button=="Equipped"and not p.enabled)
   assert(UICopy.has("r4.customize.moreMaterials")and UICopy.has("r4.customize.moreToys"))
  end)
  test("R3.5 pure: Deck style in use / equipped keep a disabled button",function()
   local facts={trials=0,totalWins=0,inventoryMask=1,masteryRanks={pip=0},faceplates={}}
   local plate=Plates.status("sherbet",{equipped="sherbet",wallet=0,facts=facts});assert(plate.kind=="equipped"and plate.button=="Equipped"and plate.enabled==false and plate.text=="")
   local ball=Balls.status("smileys",{owned={},equipped="smileys"});assert(ball.button=="In use"and ball.enabled==false)
  end)
  test("R4.6 pure + built: ball drops stagger in order and cut under Reduced Motion",function()
   local a,b=Balls.dropPlan(40,12,1),Balls.dropPlan(40,12,3)
   assert(a.startY<0 and a.restY==40 and a.delay==0 and b.delay>a.delay)
   local _,host=menuGui("_R4Balls")
   local well=Kit.frame(host,"Well",nil,UDim2.fromOffset(0,0),UDim2.fromOffset(100,60))
   local ball=Kit.frame(well,"Ball",nil,UDim2.fromOffset(10,40),UDim2.fromOffset(12,12))
   local moved=Balls.dropIn({ball})
   if Kit.reduced()then assert(moved==0 and ball.Position==UDim2.fromOffset(10,40))
   else assert(moved==1 and ball.Position.Y.Offset<0,"starts above the well");task.wait(Balls.Drop.time+.1);assert(ball.Position==UDim2.fromOffset(10,40),"lands")end
   for _,o in ipairs({ball.Position.X.Offset,ball.Position.Y.Offset})do assert(o%1==0,"integer offsets")end
  end)
  test("R3.6: a theme repaint no longer inks the unselected tab labels",function()
   local _,host=menuGui("_R4Tabs")
   local tabs=TabInk.guard(Kit.tabs(host,{"One","Two","Three"},480,44,16))
   tabs.select(2);tabs.select(1)
   local Themes=require(Shared.DeckThemes)
   local before=Art.getTheme()
   local other=if before==Themes.ById.copperleaf then Themes.ById.sherbet else Themes.ById.copperleaf
   Art.applyTheme(other);if before then Art.applyTheme(before)end -- each apply repaints every binding
   assert(tabs.labels[2].TextColor3==Kit.Color.soft and tabs.labels[3].TextColor3==Kit.Color.soft,"was ink-dark before the guard")
   assert(tabs.labels[1].TextColor3==Kit.color("ink"))
   assert(TabInk.colorFor(false)==Kit.Color.soft)
  end)
  test("R2.5: footer chips follow the device; the legend explains them once per screen",function()
   local _,host=menuGui("_R4Legend")
   local footer=Kit.frame(host,"Footer",nil,UDim2.fromOffset(0,0),UDim2.fromOffset(800,24))
   Legend.seen["_spec"]=nil
   local api=Legend.attach(footer,800,"_spec",{{"browse","Browse"},{"tab","Slot"},{"confirm","Buy or wear"},{"back","Back"}})
   api.build("Keyboard");local keys={};for _,b in ipairs(api.built)do keys[b.action]=b.glyph end
   assert(keys.confirm=="ENTER"and keys.back=="BKSP"and keys.browse=="WASD","keyboard never shows A")
   api.build("Gamepad");keys={};for _,b in ipairs(api.built)do keys[b.action]=b.glyph end
   assert(keys.confirm=="A"and keys.back=="B"and keys.tab=="LB")
   assert(api.open()and api.label.Visible and not api.hints.Visible and api.label.Text==UICopy.get(Glyphs.legendKey("Gamepad")))
   assert(api.dismiss()and not api.label.Visible and api.hints.Visible)
   assert(not api.open(),"once per screen per session")
   api.setLabel("confirm","Use");local found=false;for _,b in ipairs(api.built)do if b.action=="confirm"then found=b.label=="Use"end end;assert(found)
   api.build("Touch");assert(#api.built==0 and api.label.Visible,"touch: the legend line only")
   Legend.seen["_spec"]=nil
  end)
  test("R4.3 / R4.4 built: pane portrait sits above the well; cards preview; Original colour clears in two presses",function()
   local _,host=menuGui("_R4Customize")
   local sent={}
   local state={status="Ready",revision=1,nectar=0,inventoryMask=127,petHues={},hueInventory={rose=2},materialAvailable=true,materialUnlocks={gloss=true},petMaterials={},toyUnlocks={ball=true},petToys={}}
   for _,pet in ipairs(Pets.collection)do state.petHues[pet.id]={main=H.emptyCounts(),secondary=H.emptyCounts()}end
   state.petHues.pip.main.rose=2
   local intent;intent=Hue.new({id=function()return "r4"end,send=function(action,value)table.insert(sent,{action=action,value=value})end,changed=function()end})
   local view=View.new(host,intent,{appearance=function()return{}end,activePet=function()return "pip"end,delay=function()end})
   assert(view:open(state,"palette","pip"));frames()
   assert(view.portrait.Parent==view.chromeWell and view.portrait.ZIndex>view.chromeWell.ZIndex and view.viewport.ZIndex>view.portrait.ZIndex,"pane preview draws over the well")
   assert(view.hueCards.rose.CardParts.Swatch.BackgroundColor3==H.ById.rose.color,"saturated fruit tile")
   local focusOriginal
   for i,item in ipairs(view.focusables)do if item.id=="original"then focusOriginal=i end end
   assert(focusOriginal==#view.focusables,"Original colour is the last card")
   view:chromeFocusAt(focusOriginal);frames()
   assert(view.paneName.Text=="Original colour"and Kit.buttonState(view.chromeAction).enabled)
   assert(view:chromeAct()and #sent==0,"first press arms");assert(Kit.buttonState(view.chromeAction).label.Text=="Confirm reset")
   assert(view:chromeAct()and #sent==1 and sent[1].action=="hueClear"and sent[1].value.channel=="main"and sent[1].value.counts.rose==2)
   assert(intent:receive({id=sent[1].value.id,petId="pip",action="hueClear",status="Rejected",reason="Busy"})and not intent.pending)
   frames(12)
   local previews=0;for _,item in ipairs(view.focusables)do if item.button.CardParts.Swatch:GetAttribute("Preview")then previews+=1 end end
   assert(previews>0 and view.cardPreviews:liveCount()<=view.cardPreviews.live,"cards carry live previews, bounded")
   view:setTab("toys");frames()
   assert(not view.toyPanel.shop.Visible and view.moreLine.Visible and view.moreLine.Text==UICopy.get("r4.customize.moreToys"),"no egg row, one hint line")
   view:close("back");assert(view.cardPreviews.count==0,"cache freed on close")
   view:destroy()
  end)
 end,function(e)return tostring(e).." | "..debug.traceback()end)
 for _,gui in ipairs(guis)do if gui.Parent then gui:Destroy()end end
 if not ok then error(problem,0)end
 return{passed=#cases,cases=cases}
end
