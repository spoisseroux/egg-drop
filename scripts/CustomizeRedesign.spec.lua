-- Studio Client. Customize (UI-SPEC-REDESIGN-MENUS-2026-11-12 section 2): icon tabs
-- Hue / Charm / Materials / Toys with Features hidden by Shared.FeatureFlags; the
-- Charm grid with None as the first card (None sends charm(pet, false), a shape sends
-- charm(pet, true, shape)); WEARING / Wear / Wearing states; the removed PetTab,
-- WardrobeTab, ShowCharm and HideCharm; material, toy and feature "Use now" landing
-- on the hub's Pets selector; the Features panel still constructed.
-- Usage: require(PlayerScripts.Client.ZZSpecs.CustomizeRedesign)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local View=require(client.HueEggView);local Hue=require(client.HueIntent)
 local Flags=require(game.ReplicatedStorage.Shared.FeatureFlags)
 local H=require(game.ReplicatedStorage.Shared.HueCatalog);local Pets=require(game.ReplicatedStorage.Shared.PetCatalog)
 local Run=game:GetService("RunService")
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local root=Instance.new("Frame");root.Name="_CustomizeRedesign";root.BackgroundTransparency=1;root.Size=UDim2.fromOffset(1920,1080);root.Parent=parent
 local function frames()for _=1,3 do Run.Heartbeat:Wait()end end
 local saved={charmVisible=true,charmShape="dot"}
 local sent={};local selector={};local serial=0
 local intent=Hue.new({id=function()return "unused"end,send=function()error("Customize fixture must not send hue writes")end,changed=function()end})
 local view=View.new(root,intent,{
  appearance=function()return table.clone(saved)end,activePet=function()return "pip"end,
  shapeSelectionsEnabled=function()return true end,delay=function()end,
  charm=function(petId,visible,shape)serial+=1;table.insert(sent,{petId=petId,visible=visible,shape=shape});return{seq=serial}end,
  petsSelector=function(assign)table.insert(selector,assign);return true end})
 local state={status="Ready",revision=1,nectar=128,inventoryMask=127,petHues={},hueInventory={rose=2},materialAvailable=true,materialUnlocks={gloss=true},petMaterials={},toyUnlocks={ball=true},petToys={}}
 for _,pet in ipairs(Pets.collection)do state.petHues[pet.id]={main=H.emptyCounts(),secondary=H.emptyCounts()}end
 local ok,problem=xpcall(function()
  test("pure: four icon tabs, no Features while flagged, Features joins with the flag on",function()
   local tabs=View.tabList()
   assert(Flags.Features==false,"this build ships with Features hidden")
   assert(#tabs==4 and tabs[1].id=="hue"and tabs[2].id=="charm"and tabs[3].id=="materials"and tabs[4].id=="toys")
   assert(tabs[1].icon=="drop"and tabs[2].icon=="sparkle"and tabs[3].icon=="sphere"and tabs[4].icon=="toy")
   local on=View.tabList({Features=true});assert(#on==5 and on[5].id=="features")
   for _,t in ipairs(tabs)do assert(t.id~="pet"and t.id~="wardrobe")end
  end)
  test("pure: Charm cards put None first; WEARING follows the saved state",function()
   local cards=View.charmCards({charmVisible=true,charmShape="ring"},true)
   assert(cards[1].id=="none"and cards[1].status=="No charm"and not cards[1].wearing)
   local byId={};for _,c in ipairs(cards)do byId[c.id]=c end
   assert(byId.ring.status=="WEARING"and byId.ring.tone=="accent"and byId.dot.status=="Free"and byId.pebble.status=="Free")
   local hidden=View.charmCards({charmVisible=false,charmShape="ring"},true)
   assert(hidden[1].status=="WEARING"and hidden[1].wearing)
   for _,c in ipairs(hidden)do if c.id~="none"then assert(c.status=="Free")end end
   assert(#View.charmCards({charmVisible=true,charmShape="dot"},false)==2,"older servers show None and the saved shape only")
   local v,s=View.charmRequestFor("none");assert(v==false and s==nil)
   v,s=View.charmRequestFor("pebble");assert(v==true and s=="pebble")
  end)
  test("pure: the pane says Wear, Equipped (disabled), Saving… and Try again",function()
   local wear=View.charmPane({id="ring",wearing=false},"Zivvi",nil)
   assert(wear.button=="Wear"and wear.enabled and wear.line:find("Zivvi")and wear.status=="Trying it on. Not saved yet.")
   local wearing=View.charmPane({id="ring",wearing=true},"Zivvi",nil);assert(wearing.button=="Equipped"and not wearing.enabled)
   local saving=View.charmPane({id="ring",wearing=false},"Zivvi",{retry=false});assert(saving.button=="Saving…"and not saving.enabled)
   local retry=View.charmPane({id="ring",wearing=false},"Zivvi",{retry=true});assert(retry.button=="Try again"and retry.enabled)
  end)
  test("removed names are gone and the Features panel is still constructed",function()
   for _,name in ipairs({"petTab","wardrobeTab","charmToggle","charmOff","tabRail"})do assert(view[name]==nil,name.." still exists")end
   assert(view.featurePanel and view.featurePanel.root and view.featurePanel.useNow,"FeaturePanel must stay constructed (hidden, not removed)")
   assert(client:FindFirstChild("EditorTabRail")==nil,"EditorTabRail is retired")
  end)
  test("built Customize: Kit header, icon tabs, no Features segment, setTab refuses features",function()
   assert(view:open(state,"charm","pip"));frames()
   assert(view.chromeRoot.Visible and not view.card.Visible and view:chromeActive())
   assert(view.header.title.Text=="Customize"and view.header.root:FindFirstChild("BackArrow"))
   assert(view.editorTabs.hue and view.editorTabs.charm and view.editorTabs.materials and view.editorTabs.toys and view.editorTabs.features==nil)
   assert(view.chromeTabs.root:GetAttribute("TabIcons")==true,"icons fit at 800 wide")
   assert(not view:setTab("features")and view.tab=="charm")
   for _,id in ipairs({"hue","materials","toys","charm"})do assert(view:setTab(id));frames();assert(view.chromePanel:GetAttribute("Tab")==id)end
   assert(view:getControllerFocus()==nil,"the chrome owns its focus")
  end)
  test("Charm None first, focus previews, Wear sends charm(pet,false) / charm(pet,true,shape)",function()
   saved={charmVisible=true,charmShape="dot"};view.charmRequests={};view:setTab("hue");view:setTab("charm");frames()
   assert(view.charmCards.none.Position.Y.Offset<=view.charmCards.dot.Position.Y.Offset and view.charmCards.none.Position.X.Offset<view.charmCards.dot.Position.X.Offset)
   assert(view.charmCards.dot:GetAttribute("CardStatus")=="WEARING"and view.chromePanel:GetAttribute("FocusedCard")=="dot","lands on the worn card")
   assert(view.chromeAction.Visible and not require(client.DeckKit).buttonState(view.chromeAction).enabled,"Equipped is disabled on the saved card")
   view:chromeInput(Enum.KeyCode.Left);frames()
   assert(view.chromePanel:GetAttribute("FocusedCard")=="none"and view.charmFocusId=="none"and #sent==0,"focus previews only")
   assert(view:chromeAct()and sent[#sent].visible==false and sent[#sent].shape==nil and sent[#sent].petId=="pip")
   view.charmRequests={};view:chromeInput(Enum.KeyCode.Down);frames()
   local id=view.chromePanel:GetAttribute("FocusedCard");assert(id=="ring","second row, first column is Ring")
   assert(view:chromeAct()and sent[#sent].visible==true and sent[#sent].shape=="ring")
   assert(not view:chromeAct(),"one request per press while saving")
   view.charmRequests={};saved={charmVisible=false,charmShape="dot"};view:refresh();frames()
   assert(view.charmCards.none:GetAttribute("CardStatus")=="WEARING")
   saved={charmVisible=true,charmShape="dot"};view:refresh()
  end)
  test("material, toy and feature Use now land on the hub's Pets selector",function()
   for _,case in ipairs({{view.materialPanel,{id="m1",finishId="gloss"},"Gloss"},{view.toyPanel,{id="t1",toyId="ball"},"Ball"},{view.featurePanel,{id="f1",featureId="horns"},nil}})do
    local before=#selector
    view.page="materialReceipt";view.tab="materials"
    case[1].options.useNow(case[2]);frames()
    assert(#selector==before+1,"Use now did not open the Pets selector")
    local assign=selector[#selector]
    assert(view.page=="palette"and view.tab=="pet"and assign.button=="Use here"and type(assign.choose)=="function")
    if case[3]then assert(assign.line:find(case[3]),assign.line)end
    view.materialAssignment=nil;view.toyAssignment=nil;view.featureAssignment=nil
   end
   view:close("forced")
  end)
 end,function(e)return tostring(e).." | "..debug.traceback()end)
 view:destroy();root:Destroy()
 if not ok then error(problem,0)end
 return{passed=#cases,cases=cases}
end
