-- Studio Client. Deck style (UI-SPEC-REDESIGN-MENUS-2026-11-12 section 4, mockups 04
-- and 05): one screen under the shared header with Faceplates | Backgrounds icon tabs.
-- Pure rules (tab clamp, background card and pane states), then the real DeckPicker:
-- the header never moves between tabs, Q / E (shiftStyleTab) and the tab buttons
-- switch, the Backgrounds pane borrows the live preview only while shown, Use goes
-- through onApply("background"), trial-locked "View trials" returns to the same card,
-- the shop owns focus (no native selection), and Settings / Pocket Trials stay inside
-- the picker under the header. Fake transport only; nothing is sent.
-- Usage: require(PlayerScripts.Client.ZZSpecs.DeckStyle)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Picker=require(client.DeckPicker);local Shop=require(client.FaceplateShop);local Backs=require(client.BackgroundShop)
 local Art=require(client.DeckArt);local Kit=require(client.DeckKit)
 local Trials=require(game.ReplicatedStorage.Shared.PocketTrials);local Flags=require(game.ReplicatedStorage.Shared.FeatureFlags)
 local GuiService=game:GetService("GuiService")
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local gui=Instance.new("ScreenGui");gui.Name="_DeckStyleSpec";gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=parent
 local root=Instance.new("Frame");root.BackgroundTransparency=1;root.Parent=gui
 local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
 local views={}
 local function picker(size)
  root.Size=UDim2.fromOffset(size.X,size.Y);settle()
  local f={applied={},closed={},settings=0,accepted={}}
  local v=Picker.new(root,nil,nil,function()end,function(reason)table.insert(f.closed,reason)end,function(slot,id)table.insert(f.applied,{slot,id})end,function()f.settings+=1 end)
  v.onAccepted=function(kind)table.insert(f.accepted,kind)end
  table.insert(views,v);f.v=v
  v:updateClub(1,0,0,0,"On",false,false,1,true,0,{pip=0});v:setShopState(128,{})
  return f
 end
 local ok,problem=xpcall(function()
  test("pure: flags, tab clamp and background card states",function()
   assert(Flags.Features==false and table.isfrozen(Flags))
   assert(Shop.nextTab(1,-1)==1 and Shop.nextTab(1,1)==2 and Shop.nextTab(2,1)==2 and Shop.nextTab(2,-1)==1)
   assert(#Shop.Tabs==2 and Shop.Tabs[1].label=="Faceplates"and Shop.Tabs[2].label=="Backgrounds")
   local facts={trials=0,totalWins=0,inventoryMask=1,masteryRanks={pip=0}}
   local ctx={confirmed="canopy",facts=facts}
   assert(Backs.status("canopy",ctx).kind=="inUse"and Backs.status("canopy",ctx).button==nil)
   local creek=Backs.status("creek",ctx);assert(creek.kind=="locked"and creek.button=="View trials"and creek.text:find("High Roller",1,true))
   local lantern=Backs.status("lantern",ctx);assert(lantern.kind=="locked"and lantern.button==nil and lantern.text:find("Win 10",1,true))
   assert(select(1,Backs.tileStatus("canopy",ctx))=="IN USE"and select(1,Backs.tileStatus("lantern",ctx))=="🔒 Reach Rank II")
   local unlocked={confirmed="canopy",facts={trials=Trials.HighRoller.bit,totalWins=1,inventoryMask=1,masteryRanks={pip=0}}}
   assert(Backs.status("creek",unlocked).kind=="earned"and Backs.status("creek",unlocked).button=="Use"and select(1,Backs.tileStatus("creek",unlocked))=="Earned")
   local retry={confirmed="canopy",facts=facts,chosen="creek",note="Reply delayed - Retry",retry=true}
   assert(Backs.status("creek",retry).kind=="retry"and Backs.status("creek",retry).button=="Retry")
   assert(Backs.step(1,1,0,3,2)==2 and Backs.step(2,0,1,3,2)==3 and Backs.step(3,1,0,3,2)==3)
  end)
  for _,size in ipairs({Vector2.new(1920,1080),Vector2.new(812,354)})do
   local label=tostring(size)
   test(label.." opens on Faceplates; tabs switch under a header that never moves",function()
    local f=picker(size);local v=f.v
    v.customizationEntry=true;v:open("sherbet","none");settle()
    local shop=v.shop
    assert(v:shopOpen()and v.active=="Shell"and shop.visible and shop.tab==1 and not v.card.Visible,label.." opens the Deck style screen")
    assert(v.tabs.Shell==shop.tabs.buttons[1]and v.tabs.Background==shop.tabs.buttons[2]and v.tabs.Background:GetAttribute("AccessibleLabel")=="Background patterns")
    assert(shop.plates.Visible and not shop.backgrounds.body.Visible and shop.root:GetAttribute("Tab")=="faceplates")
    assert(shop.header.compact==Kit.compactRule(size.X,size.Y)and shop.title.Text=="Deck style")
    local backAt,walletAt,titleAt=shop.backArrow.root.AbsolutePosition,shop.wallet.root.AbsolutePosition,shop.title.AbsolutePosition
    local focus=v:getControllerFocus();assert(focus and focus.target()==nil,"the shop owns focus")
    -- E / RB.
    assert(v:shiftStyleTab(1)and v.active=="Background"and shop.tab==2);settle()
    assert(not shop.plates.Visible and shop.backgrounds.body.Visible and shop.root:GetAttribute("Tab")=="backgrounds")
    assert(shop.backArrow.root.AbsolutePosition==backAt and shop.wallet.root.AbsolutePosition==walletAt and shop.title.AbsolutePosition==titleAt and shop.title.Text=="Deck style","header moved between tabs")
    assert(shop.backgrounds:focusedId()=="canopy"and shop.root:GetAttribute("BackgroundPaneState")=="inUse","lands on the background in use")
    assert(Art.isBackgroundPreviewVisible(shop.backgrounds.previewHost),"pane borrows the live preview")
    assert(focus.target()==nil and v:getControllerFocus().target()==nil)
    assert(not v:shiftStyleTab(1)and shop.tab==2,"no wrap past the last tab")
    -- Q / LB back, then a tap on the second tab.
    assert(v:shiftStyleTab(-1)and v.active=="Shell"and shop.tab==1 and shop.plates.Visible);settle()
    assert(not Art.isBackgroundPreviewVisible(shop.backgrounds.previewHost),"preview released on Faceplates")
    shop:requestTab(2);assert(v.active=="Background"and shop.tab==2)
    assert(#f.applied==0 and table.find(f.accepted,"tab"),"tabs never send")
    -- Arrows move the card focus inside the Backgrounds grid.
    assert(shop:move(1,0)and shop.backgrounds:focusedId()=="creek")
    v:close("back");assert(not shop.visible and not Art.isBackgroundPreviewVisible(shop.backgrounds.previewHost)and f.closed[#f.closed]=="back")
   end)
   test(label.." Backgrounds: locked View trials returns to the card; earned Use applies once",function()
    local f=picker(size);local v=f.v
    v.customizationEntry=true;v:open("sherbet","none","Background");settle()
    local shop=v.shop;local backs=shop.backgrounds
    assert(v.active=="Background"and shop.tab==2 and backs:focusedId()=="canopy")
    assert(not shop:act(false)and #f.applied==0,"in use: nothing to do")
    assert(backs:focusId("creek")and shop.root:GetAttribute("BackgroundPaneState")=="locked"and backs.action.Visible)
    assert(shop:act(false)and v.active=="Trials"and v.card.Visible and not shop.visible and #f.applied==0,"View trials opens Pocket Trials")
    assert(v.heading.Text=="Pocket Trials"and v:getControllerFocus().target()==v.cancel)
    v:back();settle()
    assert(v.active=="Background"and shop.visible and shop.tab==2 and backs:focusedId()=="creek","Back returns to the same card")
    backs:focusId("lantern");assert(shop.root:GetAttribute("BackgroundPaneState")=="locked"and not backs.action.Visible)
    v:updateClub(1,Trials.HighRoller.bit,0,0,"On",false,false,1,true,1,{pip=0});settle()
    backs:focusId("creek");assert(shop.root:GetAttribute("BackgroundPaneState")=="earned"and backs.action.Visible)
    assert(shop:act(false)and #f.applied==1 and f.applied[1][1]=="background"and f.applied[1][2]=="creek","Use goes through the appearance intent")
    v:setAppearance({themeId="sherbet",stickerId="none",backgroundId="creek",confirmedTheme="sherbet",confirmedSticker="none",confirmedBackground="creek",slots={background={status="Applied"}}})
    assert(v.choices.Background.creek.Enabled and shop.root:GetAttribute("BackgroundPaneState")=="inUse")
    v:setAppearance({themeId="sherbet",stickerId="none",backgroundId="lantern",confirmedTheme="sherbet",confirmedSticker="none",confirmedBackground="creek",slots={background={status="Retry",reason="NoReply"}}})
    local retried=0;v.onRetry=function(slot)assert(slot=="background");retried+=1;return true end
    backs:focusId("lantern");assert(shop.root:GetAttribute("BackgroundPaneState")=="retry"and shop:act(false)and retried==1)
    v:close("forced")
   end)
   test(label.." Settings and Pocket Trials stay inside the picker under the shared header",function()
    local f=picker(size);local v=f.v
    v.customizationEntry=false;v:open("sherbet","none","Settings");settle()
    assert(v.active=="Settings"and v.card.Visible and not v.shop.visible and not v:shopOpen())
    assert(v.header and v.header.wallet==nil and v.heading.Text=="Settings"and v.cancel==v.header.back.root and v.cancel.Selectable)
    assert(v.cancel.AbsoluteSize==Vector2.new(44,44)and v:getControllerFocus().target()==v.sound)
    assert(not v:activateTab("Background")and not v:shiftStyleTab(1),"style tabs stay closed on the Settings route")
    assert(v:changeSetting("music")and f.settings==1)
    v:showTab("Trials");assert(v.heading.Text=="Pocket Trials"and v.clubHeader.Visible and not v.sound.Visible)
    v:back();assert(not v.shade.Visible and f.closed[#f.closed]=="back")
   end)
  end
 end,function(e)return tostring(e).." | "..debug.traceback()end)
 GuiService.SelectedObject=nil
 for _,v in ipairs(views)do v:close("forced");v.shade:Destroy()end
 gui:Destroy()
 if not ok then error(problem,0)end
 return{passed=#cases,cases=cases}
end
