-- Studio Client. Deck style (UI-SPEC-REDESIGN-MENUS-2026-11-12 section 4, mockups 04
-- and 05): one screen under the shared header with Faceplates | Backgrounds | Balls icon tabs
-- (Balls: batch 2026-11-13 R1, ball themes bought and equipped through the hatching save).
-- Pure rules (tab clamp, background card and pane states), then the real DeckPicker:
-- the header never moves between tabs, Q / E (shiftStyleTab) and the tab buttons
-- switch, the Backgrounds pane borrows the live preview only while shown, Use goes
-- through onApply("background"), a trial lock has no button (Pocket Trials retired, QA
-- Q5), the shop owns focus (no native selection), and Settings stays inside the picker
-- under the header. Fake transport only; nothing is sent. Every case runs with Levels matter off (the
-- three-tab screen exactly as it was); the last ones turn it on for the Effects tab and a gated theme.
-- Usage: require(PlayerScripts.Client.ZZSpecs.DeckStyle)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Picker=require(client.DeckPicker);local Shop=require(client.FaceplateShop);local Backs=require(client.BackgroundShop)
 local Balls=require(client.BallShop);local BallThemes=require(game.ReplicatedStorage.Shared.BallThemes)
 local Art=require(client.DeckArt);local Kit=require(client.DeckKit)
 local Trials=require(game.ReplicatedStorage.Shared.PocketTrials);local Flags=require(game.ReplicatedStorage.Shared.FeatureFlags)
 local Levels=require(game.ReplicatedStorage.Shared.Levels);local UICopy=require(game.ReplicatedStorage.Shared.UICopy)
 local function parts(gates,juice)Levels.inject({flags={LevelsMatter=gates or juice},studio=true,shipped={track=true,gates=gates,medals=true,juice=juice}})end
 parts(false,false)
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
   assert(Shop.nextTab(1,-1)==1 and Shop.nextTab(1,1)==2 and Shop.nextTab(2,1)==3 and Shop.nextTab(3,1)==3 and Shop.nextTab(2,-1)==1)
   assert(#Shop.Tabs==3 and Shop.Tabs[1].label=="Faceplates"and Shop.Tabs[2].label=="Backgrounds"and Shop.Tabs[3].label=="Balls"and Shop.Tabs[3].icon=="smiley")
   assert(Picker.TabOrder[3]=="Balls")
   local facts={trials=0,totalWins=0,inventoryMask=1,masteryRanks={pip=0}}
   local ctx={confirmed="canopy",facts=facts}
   -- QA v2 R3.5: in use keeps the button, disabled.
   assert(Backs.status("canopy",ctx).kind=="inUse"and Backs.status("canopy",ctx).button=="In use"and Backs.status("canopy",ctx).enabled==false)
   -- QA Q5: no "View trials" (Pocket Trials are retired); the rule text stays.
   local creek=Backs.status("creek",ctx);assert(creek.kind=="locked"and creek.button==nil and not creek.enabled and creek.text:find("High Roller",1,true))
   local lantern=Backs.status("lantern",ctx);assert(lantern.kind=="locked"and lantern.button==nil and lantern.text:find("Win 10",1,true))
   assert(select(1,Backs.tileStatus("canopy",ctx))=="IN USE"and select(1,Backs.tileStatus("lantern",ctx))=="🔒 Reach Rank II")
   local unlocked={confirmed="canopy",facts={trials=Trials.HighRoller.bit,totalWins=1,inventoryMask=1,masteryRanks={pip=0}}}
   assert(Backs.status("creek",unlocked).kind=="earned"and Backs.status("creek",unlocked).button=="Use"and select(1,Backs.tileStatus("creek",unlocked))=="Earned")
   local retry={confirmed="canopy",facts=facts,chosen="creek",note="Reply delayed - Retry",retry=true}
   assert(Backs.status("creek",retry).kind=="retry"and Backs.status("creek",retry).button=="Retry")
   assert(Backs.step(1,1,0,3,2)==2 and Backs.step(2,0,1,3,2)==3 and Backs.step(3,1,0,3,2)==3)
  end)
  test("pure: Balls cards and pane (IN USE, Owned, price, short), free themes always owned",function()
   local ctx={owned={"smileys","marbles"},equipped="smileys",wallet=100}
   assert(Balls.status("smileys",ctx).kind=="inUse"and Balls.status("smileys",ctx).button=="In use"and Balls.status("smileys",ctx).enabled==false)
   assert(Balls.status("marbles",ctx).kind=="owned"and Balls.status("marbles",ctx).button=="Use")
   assert(Balls.status("marbles",{owned={},equipped="smileys"}).kind=="owned","free themes need no purchase")
   local gems=Balls.status("gems",ctx);assert(gems.kind=="buy"and gems.price==100 and gems.button=="★ Buy 100")
   local kittens=Balls.status("kittens",ctx);assert(kittens.kind=="short"and kittens.price==250 and kittens.text=="150 more Stars needed")
   assert(select(1,Balls.tileStatus("smileys",ctx))=="IN USE"and select(1,Balls.tileStatus("marbles",ctx))=="✓ Owned"and select(1,Balls.tileStatus("gumdrops",ctx))=="★ 40")
   assert(Balls.status("nope",ctx).kind=="invalid"and Balls.step(1,1,0,6,2)==2 and Balls.step(2,0,1,6,2)==4 and Balls.step(6,1,1,6,2)==6)
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
    assert(v:shiftStyleTab(1)and v.active=="Balls"and shop.tab==3 and shop.balls.body.Visible and shop.root:GetAttribute("Tab")=="balls");settle()
    assert(not shop.backgrounds.body.Visible and shop.balls:focusedId()=="smileys","Balls lands on the theme in use")
    assert(shop.backArrow.root.AbsolutePosition==backAt and shop.title.Text=="Deck style","header moved on the Balls tab")
    assert(not v:shiftStyleTab(1)and shop.tab==3,"no wrap past the last tab")
    assert(v:shiftStyleTab(-1)and shop.tab==2)
    -- Q / LB back, then a tap on the second tab.
    assert(v:shiftStyleTab(-1)and v.active=="Shell"and shop.tab==1 and shop.plates.Visible);settle()
    assert(not Art.isBackgroundPreviewVisible(shop.backgrounds.previewHost),"preview released on Faceplates")
    shop:requestTab(2);assert(v.active=="Background"and shop.tab==2)
    assert(#f.applied==0 and table.find(f.accepted,"tab"),"tabs never send")
    -- Arrows move the card focus inside the Backgrounds grid.
    assert(shop:move(1,0)and shop.backgrounds:focusedId()=="creek")
    v:close("back");assert(not shop.visible and not Art.isBackgroundPreviewVisible(shop.backgrounds.previewHost)and f.closed[#f.closed]=="back")
   end)
   test(label.." Backgrounds: a trial lock has no button (Pocket Trials retired); earned Use applies once",function()
    local f=picker(size);local v=f.v
    v.customizationEntry=true;v:open("sherbet","none","Background");settle()
    local shop=v.shop;local backs=shop.backgrounds
    assert(v.active=="Background"and shop.tab==2 and backs:focusedId()=="canopy")
    assert(not shop:act(false)and #f.applied==0,"in use: nothing to do")
    assert(backs:focusId("creek")and shop.root:GetAttribute("BackgroundPaneState")=="locked"and not backs.action.Visible)
    assert(not shop:act(false)and v.active=="Background"and shop.visible and #f.applied==0,"a trial lock opens nothing")
    assert(v.active=="Background"and shop.visible and shop.tab==2 and backs:focusedId()=="creek","focus stays on the card")
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
   test(label.." Balls: Use equips an owned theme, Buy needs a confirm, replies update the cards",function()
    local f=picker(size);local v=f.v
    v:setShopState(100,{},{owned={"smileys","marbles"},equipped="smileys"},7)
    v.customizationEntry=true;v:open("sherbet","none","Balls");settle()
    local shop=v.shop;local balls=shop.balls
    local sent={};balls.callbacks.send=function(action,payload)table.insert(sent,{action,payload})end
    assert(v.active=="Balls"and shop.tab==3 and balls:focusedId()=="smileys"and shop.root:GetAttribute("BallPaneState")=="inUse")
    assert(not shop:act(false)and #sent==0,"in use: nothing to do")
    -- Use: one equip request; the Saved reply moves IN USE.
    assert(balls:focusId("marbles")and shop:act(false)and #sent==1 and sent[1][1]=="ballThemeEquip"and sent[1][2].themeId=="marbles")
    assert(not shop:act(false)and #sent==1,"one request in flight")
    assert(shop:result({kind="ballTheme",id=sent[1][2].id,status="Saved"})and balls.ctx.equipped=="marbles"and shop.root:GetAttribute("BallPaneState")=="inUse")
    -- QA Q2.4 optimistic: Use is IN USE at once (no "Applying"), a snapshot in flight
    -- cannot flip it back, and a refusal rolls back to the previous theme.
    local shown={};balls.callbacks.equipped=function(id)table.insert(shown,id)end
    assert(balls:focusId("smileys")and shop:act(false)and #sent==2 and balls.ctx.equipped=="smileys"and shown[1]=="smileys")
    -- The compact layout has no status line (statusLabel is nil there); check it only where it exists.
    assert(shop.root:GetAttribute("BallPaneState")=="inUse"and(balls.statusLabel==nil or not balls.statusLabel.Text:find("Applying",1,true)))
    v:setShopState(100,{},{owned={"smileys","marbles"},equipped="marbles"},7);assert(balls.ctx.equipped=="smileys","snapshot during the save keeps the choice")
    assert(shop:result({kind="ballTheme",id=sent[2][2].id,status="Rejected",reason="Busy"})and balls.ctx.equipped=="marbles"and shown[2]=="marbles"and balls.errorId=="smileys")
    table.remove(sent,2);balls.callbacks.equipped=nil
    assert(#f.applied==0,"ball themes never go through the deck appearance slots")
    -- Buy (round 3): the press opens the confirm dialog; its yes sends theme + fixed price.
    local Confirm=require(client.ConfirmDialog)
    local function yes()Confirm.accept();task.wait();task.wait()end
    assert(balls:focusId("gems")and shop.root:GetAttribute("BallPaneState")=="buy")
    assert(shop:act(false)and #sent==1 and Confirm.isOpen())
    yes();assert(#sent==2 and sent[2][1]=="ballThemeBuy"and sent[2][2].themeId=="gems"and sent[2][2].price==100 and sent[2][2].equip==true)
    assert(not shop:result({kind="ballTheme",id="other",status="Saved"}),"a reply for another press is ignored")
    assert(shop:result({kind="ballTheme",id=sent[2][2].id,status="Rejected",reason="NeedStars"})and balls.errorId=="gems")
    assert(shop:act(false));yes();assert(#sent==3)
    assert(shop:result({kind="ballTheme",id=sent[3][2].id,status="Saved"})and table.find(balls.ctx.owned,"gems")and balls.ctx.equipped=="gems")
    v:setShopState(20,{},{owned={"smileys","marbles","gems"},equipped="gems"},8)
    assert(select(1,Balls.tileStatus("gems",balls.ctx))=="IN USE"and balls.ctx.revision==8)
    balls:focusId("kittens");assert(shop.root:GetAttribute("BallPaneState")=="short"and not shop:act(false)and #sent==3,"not enough Stars: no request")
    -- The pane draws the theme on a small board and its five goal circles.
    assert(#balls.board.balls==#Balls.Pile and balls.board.themeId=="kittens")
    assert(balls.circles[1].circle.BackgroundColor3==Color3.fromHex(BallThemes.ById.kittens.ramps[1].body))
    assert(balls.circles[1].circle.Size.X.Scale<balls.circles[5].circle.Size.X.Scale,"circles step in size")
    v:close("forced")
   end)
   test(label.." Settings stays inside the picker under the shared header; no Pocket Trials page (QA Q5)",function()
    local f=picker(size);local v=f.v
    v.customizationEntry=false;v:open("sherbet","none","Settings");settle()
    assert(v.active=="Settings"and v.card.Visible and not v.shop.visible and not v:shopOpen())
    assert(v.header and v.header.wallet==nil and v.heading.Text=="Settings"and v.cancel==v.header.back.root and v.cancel.Selectable)
    assert(v.cancel.AbsoluteSize==Vector2.new(44,44)and v:getControllerFocus().target()==v.sound)
    assert(not v:activateTab("Background")and not v:shiftStyleTab(1),"style tabs stay closed on the Settings route")
    assert(v:changeSetting("music")and f.settings==1)
    assert(v:showTab("Trials")==false and v.active=="Settings"and v.heading.Text=="Settings"and v.sound.Visible,"Trials is not a page any more")
    v:back();assert(not v.shade.Visible and f.closed[#f.closed]=="back")
   end)
  end
  test("Levels off: three tabs, today's lists, and a gated theme only shows (and equips) once owned",function()
   parts(false,false)
   assert(Shop.tabList()==Shop.Tabs and Shop.nextTab(3,1)==3)
   assert(table.concat(BallThemes.listed({}),",")==table.concat(BallThemes.Order,",")and #Shop.order({faceplates={}})==21)
   local levels={pip={power=99}}
   assert(Balls.status("tangerine_pop",{owned={},wallet=999,levels=levels}).kind=="invalid","never sold while off")
   assert(Balls.status("tangerine_pop",{owned={"tangerine_pop"},equipped="smileys"}).kind=="owned"and Balls.status("tangerine_pop",{owned={"tangerine_pop"},equipped="tangerine_pop"}).kind=="inUse")
   local f=picker(Vector2.new(1920,1080));local v=f.v
   assert(v.shop.effects==nil and #v.shop.tabs.buttons==3 and v.shop.balls.grid==nil and #v.shop.balls.tiles==#BallThemes.Order,"today's grid")
   v:setShopState(128,{},{owned={"tangerine_pop"},equipped="smileys"},1)
   assert(#v.shop.balls.tiles==#BallThemes.Order+1 and v.shop.balls.tiles[#v.shop.balls.tiles].chip==nil and v.shop.balls.grid,"an owned gated theme is still listed")
   v:close("forced")
  end)
  for _,size in ipairs({Vector2.new(1920,1080),Vector2.new(812,354),Vector2.new(667,375)})do
   local label=tostring(size)
   test(label.." gated ball theme: chip, bar and the way to its training; below the level nothing is sent",function()
    parts(true,false)
    local f=picker(size);local v=f.v;local shop=v.shop;local balls=shop.balls
    local sent,trained={},{}
    balls.callbacks.send=function(action,payload)table.insert(sent,{action,payload})end
    shop.callbacks.train=function(route)table.insert(trained,route)end
    v.customizationEntry=true;v:open("sherbet","none","Balls");settle()
    balls:setContext({wallet=100,owned={},equipped="smileys",levels={pip={power=4}}})
    assert(balls:focusId("tangerine_pop"),"listed");settle()
    local tile=balls.tiles[balls.index]
    assert(shop.root:GetAttribute("BallPaneState")=="locked"and tile.chip.root.Visible and tile.lock.root.Visible and tile.status.Text=="","the chip, no price")
    do
     local k=shop.scale.Scale;local c,b=tile.chip.root,tile.button
     assert(c.AbsolutePosition.Y+c.AbsoluteSize.Y<=b.AbsolutePosition.Y+b.AbsoluteSize.Y-6*k+.5 and c.AbsolutePosition.X+c.AbsoluteSize.X<=b.AbsolutePosition.X+b.AbsoluteSize.X-6*k+.5,"at the card's bottom, 6 px in")
     assert(tile.name.AbsolutePosition.Y+tile.name.AbsoluteSize.Y<=c.AbsolutePosition.Y+.5,"under the name")
    end
    assert(balls.lockBar.root.Visible and balls.lockChip.root.Visible and Kit.buttonState(balls.action).label.Text==UICopy.get("shop.train",{name="Power"}))
    assert(balls.grid and balls.grid.CanvasPosition.Y+balls.grid.AbsoluteWindowSize.Y>=tile.button.Position.Y.Offset+tile.button.Size.Y.Offset-1,"scrolled into view")
    assert(shop:act(false)and #sent==0 and trained[1].stat=="power"and trained[1].petId=="pip")
    -- Met: the same card buys; a refusal from an older save reads the save again.
    balls:setContext({levels={pip={power=10}}})
    assert(shop.root:GetAttribute("BallPaneState")=="buy"and not tile.lock.root.Visible and not tile.chip.root.Visible and not balls.lockBar.root.Visible and not balls.lockChip.root.Visible and tile.status.Text=="★ 40","met: the price, no chip")
    -- A level that came in with a snapshot repaints the tile with no focus change (and plates the same way).
    balls:setContext({levels={pip={power=9}}});assert(tile.chip.root.Visible);balls:setContext({levels={pip={power=25}}});assert(not tile.chip.root.Visible)
    for _,plate in ipairs(shop.tiles)do
     if plate.chip then
      shop:setContext({levels={pip={energy=1}}});assert(plate.chip.root.Visible and plate.lock.root.Visible,plate.id)
      shop:setContext({levels={pip={energy=99}}});assert(not plate.chip.root.Visible and not plate.lock.root.Visible,plate.id)
     end
    end
    local Confirm=require(client.ConfirmDialog)
    assert(shop:act(false)and Confirm.isOpen());Confirm.accept();task.wait();task.wait()
    assert(#sent==1 and sent[1][1]=="ballThemeBuy"and sent[1][2].themeId=="tangerine_pop"and sent[1][2].price==40)
    assert(shop:result({kind="ballTheme",id=sent[1][2].id,status="Rejected",reason="NeedsLevel"})and #sent==2 and sent[2][1]=="snapshot"and balls.errorText==UICopy.get("shop.reason.needsLevel"))
    v:close("forced")
   end)
   test(label.." Effects tab: last tab, locked cards, optimistic Use, back to the owner's tabs",function()
    parts(true,true)
    local f=picker(size);local v=f.v;local shop=v.shop
    local Effects=require(client.EffectsShop);local Juice=require(game.ReplicatedStorage.Shared.DeckJuiceCatalog)
    local folder=Instance.new("Folder")
    v:setShopState(128,{},{owned={},equipped="smileys"},1)
    assert(#Shop.tabList()==4 and #shop.tabs.buttons==4 and shop.effects,"four tabs")
    local sent,trained={},{}
    shop.effects.callbacks.send=function(kind,id)table.insert(sent,kind.."."..id)end
    shop.effects.callbacks.board=function()return folder end
    shop.callbacks.train=function(route)table.insert(trained,route)end
    shop.effects:setContext({levels={pip={power=15,energy=4}}})
    v.customizationEntry=true;v:open("sherbet","none","Balls");settle()
    assert(v:shiftStyleTab(1)and shop.tab==4 and shop.effects.body.Visible and not shop.balls.body.Visible and shop.root:GetAttribute("Tab")=="effects");settle()
    assert(not v:shiftStyleTab(1)and shop.tab==4,"no wrap")
    assert(#shop.effects.tiles==9 and shop.effects:focusedItem().id=="classic"and shop.root:GetAttribute("EffectPaneState")=="inUse"and not shop:act(false))
    -- every card sits inside its grid
    for _,tile in ipairs(shop.effects.tiles)do
     assert(tile.button.AbsoluteSize.X>=60 and tile.name.TextFits~=nil and tile.status.TextSize>=11,tile.item.id)
     if tile.lock then assert(math.abs(tile.lock.veil.BackgroundTransparency-.45)<1e-3 and tile.lock.root.Size.X.Offset==23,"45% picture, 16 px lock")end
    end
    assert(shop:move(1,0)and shop.effects:focusedItem().id=="confetti"and shop.root:GetAttribute("EffectPaneState")=="owned")
    assert(shop:act(false)and #sent==1 and sent[1]=="pop.confetti"and shop.root:GetAttribute("EffectPaneState")=="inUse","optimistic")
    folder:SetAttribute(Juice.Attribute,game:GetService("HttpService"):JSONEncode({pop="confetti",trail="classic",start="classic"}));task.wait()
    assert(shop.effects.pending.pop==nil and shop.effects.ctx.choice.pop=="confetti")
    assert(shop:move(1,0)and shop:act(false)and shop:move(-1,0)and shop.effects:focusId("pop","classic")and shop:act(false)and #sent==1,"one send per gap")
    task.wait(Effects.SendGap+.15);assert(#sent==2 and sent[2]=="pop.classic","the last choice wins")
    assert(shop.effects:focusId("trail","comet")and shop.root:GetAttribute("EffectPaneState")=="locked"and shop.effects.tiles[shop.effects.index].chip.root.Visible)
    do
     local comet=shop.effects.tiles[shop.effects.index]
     shop.effects:setContext({levels={pip={power=45,energy=4}}});assert(not comet.chip.root.Visible and not comet.lock.root.Visible,"met: no chip is left")
     shop.effects:setContext({levels={pip={power=15,energy=4}}});assert(comet.chip.root.Visible)
    end
    assert(shop:act(false)and trained[1].stat=="power"and #sent==2)
    assert(shop.effects:focusId("start","ready")and shop:act(false)and trained[2].stat=="energy")
    -- the demo runs on the real renderers and stops with the tab
    local e=shop.effects
    for _,item in ipairs(e.list)do e:focusId(item.kind,item.id);for k=0,12 do e:stepDemo(100+k*.16)end end
    assert(shop:requestTab(3)and shop.tab==3 and v.active=="Balls"and shop.balls.body.Visible and not e.body.Visible and e.demoLink==nil,"back to Balls")
    assert(shop:requestTab(4)and shop.tab==4)
    assert(shop:requestTab(1)and v.active=="Shell"and shop.plates.Visible and not e.body.Visible,"and to Faceplates")
    assert(shop:requestTab(4));parts(false,false);v:setShopState(128,{},{owned={},equipped="smileys"},2)
    assert(shop.effects==nil and shop.tab==1 and #shop.tabs.buttons==3 and shop.plates.Visible,"the switch flipped off under it")
    v:close("forced");folder:Destroy();parts(false,false)
   end)
  end
  parts(false,false)
  -- Play-forever F2: the book-only Bookworm plate joins the grid once the book grants it.
  test("Bookworm: hidden until owned, then a 22nd card (21 sold plates already scroll) that equips",function()
   local Themes=require(game.ReplicatedStorage.Shared.DeckThemes)
   assert(#Shop.order({faceplates={}})==21 and Shop.order({faceplates={"bookworm"}})[22]=="bookworm")
   local host=Instance.new("Frame");host.BackgroundTransparency=1;host.Size=UDim2.fromOffset(1920,1080);host.Parent=gui
   local equipped={}
   local shop=Shop.new(host,{equip=function(id)table.insert(equipped,id)end})
   shop:setContext({facts={faceplates={}},wallet=0})
   assert(#shop.tiles==21 and shop.grid and shop.grid:IsA("ScrollingFrame"),"21 plates: a scrolling grid")
   shop:setContext({facts={faceplates={"bookworm"}}})
   assert(#shop.tiles==22 and shop.grid and shop.grid:IsA("ScrollingFrame"),"owned: one more card in the scrolling grid")
   assert(shop.grid:FindFirstChild("Tile_bookworm"))
   shop:open(Themes.Default,1);settle()
   assert(shop:focusId("bookworm")and shop.root:GetAttribute("FocusedPlate")=="bookworm")
   assert(select(1,Shop.tileStatus("bookworm",shop.ctx))=="From the book")
   assert(shop.tiles[22].status.Text=="From the book")
   shop:act(true);assert(equipped[1]=="bookworm","an owned book plate equips like any other")
   -- Stargazer (Discoveries 100%): the second book-only plate follows Bookworm on the grid.
   assert(#Themes.BookOnly==2 and Themes.BookOnly[2]=="stargazer"and Themes.isBookOnly("stargazer")and Themes.price("stargazer")==nil)
   assert(#Shop.order({faceplates={"stargazer"}})==22 and Shop.order({faceplates={"stargazer"}})[22]=="stargazer")
   local both=Shop.order({faceplates={"stargazer","bookworm"}});assert(#both==23 and both[22]=="bookworm"and both[23]=="stargazer")
   shop:setContext({facts={faceplates={"bookworm","stargazer"}}})
   assert(#shop.tiles==23 and shop.grid:FindFirstChild("Tile_stargazer")and shop.tiles[23].status.Text=="From the book")
   shop:close();host:Destroy()
  end)
 end,function(e)return tostring(e).." | "..debug.traceback()end)
 GuiService.SelectedObject=nil
 for _,v in ipairs(views)do v:close("forced");v.shade:Destroy()end
 gui:Destroy();Levels.inject(nil)
 if not ok then error(problem,0)end
 return{passed=#cases,cases=cases}
end
