-- Real LocalScript and enabled ScreenGui; run Medium/Largest. Optional one-root bounded run.
return function(client,parent,onlySize)
 local Picker=require(client.DeckPicker)
 local Catalog=require(game.ReplicatedStorage.Shared.EggCatalog);local Gui=game:GetService("GuiService")
 local Focus=require(client.ControllerFocus);local Art=require(client.DeckArt);local prior=Gui.SelectedObject
 assert(parent:IsA("ScreenGui"),"real ScreenGui required")
 local root=Instance.new("Frame");root.Name="_AppearanceStyle";root.BackgroundTransparency=1;root.Parent=parent
 local views,cases={},{}
 local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
 local function test(name,run)run();table.insert(cases,name)end
 local function inside(n,h)local p,s,q,t=n.AbsolutePosition,n.AbsoluteSize,h.AbsolutePosition,h.AbsoluteSize;return p.X>=q.X-1 and p.Y>=q.Y-1 and p.X+s.X<=q.X+t.X+1 and p.Y+s.Y<=q.Y+t.Y+1 end
 local function readable(n)assert(n.TextFits,string.format("%s text=%q size=%s bounds=%s",n:GetFullName(),n.Text,tostring(n.AbsoluteSize),tostring(n.TextBounds)));assert(not n.TextScaled)end
 local function reach(n,scroll)
  local top=n.AbsolutePosition.Y-scroll.AbsolutePosition.Y+scroll.CanvasPosition.Y
  local max=math.max(0,scroll.CanvasSize.Y.Offset-scroll.AbsoluteSize.Y)
  scroll.CanvasPosition=Vector2.new(0,math.clamp(top,0,max));settle();assert(n.AbsolutePosition.Y>=scroll.AbsolutePosition.Y-1 and n.AbsolutePosition.Y<scroll.AbsolutePosition.Y+scroll.AbsoluteSize.Y,"unreachable top "..n.Name)
  scroll.CanvasPosition=Vector2.new(0,math.clamp(top+n.AbsoluteSize.Y-scroll.AbsoluteSize.Y,0,max));settle();assert(n.AbsolutePosition.Y+n.AbsoluteSize.Y<=scroll.AbsolutePosition.Y+scroll.AbsoluteSize.Y+1,"unreachable bottom "..n.Name)
 end
 local ok,err=pcall(function()
 for _,size in ipairs(if onlySize then {onlySize}else {Vector2.new(1649,971),Vector2.new(733,307),Vector2.new(568,160),Vector2.new(385,703)})do
  root.Size=UDim2.fromOffset(size.X,size.Y);settle()
  local sends,settings,closes={},{},{}
  local v=Picker.new(root,nil,nil,function()error("preview must not paint hardware")end,function(reason)table.insert(closes,reason)end,function(slot,id)table.insert(sends,{slot,id})end,function(key)table.insert(settings,key)end)
  table.insert(views,v);v:updateClub(1,0,5,900,"On",false,false,Catalog.bit("pip"),true);v:open("sherbet","none");settle()
  test(tostring(size).." Deck style: two icon tabs, cards reachable, no Equip on the card",function()
   -- Faceplates and Backgrounds are one Deck style screen (redesign 4) under the shared header.
   assert(not v.card:FindFirstChild("Apply")and not v.tabs.Club and not v.tabs.Trials and v.tabs.Background and v.tabs.Shell)
   local shop=v.shop;local back=shop.backArrow.root.AbsolutePosition
   for _,tab in ipairs({"Background","Shell"})do
    v.customizationEntry=true;v:showTab(tab);settle()
    assert(shop.visible and not v.card.Visible and not v.sound.Visible and not v.clubHeader.Visible)
    -- Sub-pixel tolerance: the centred, scaled panel lands on half pixels at odd widths.
    assert((shop.backArrow.root.AbsolutePosition-back).Magnitude<=.5 and shop.backArrow.root.Size==UDim2.fromOffset(44,44),"header back moved on "..tab)
    -- 44 hit frames in panel units; the regular screen scales as a whole (UIScale), like Wardrobe.
    -- The 568x160 fixture leaves a 100 px sheet under the Roblox controls: the tab row (y 64..108)
    -- cannot fit, so there only the hit size and the left/right edges are checked.
    local short=shop.view~=nil and shop.view.H<112
    for _,b in pairs(v.tabs)do
     assert(b.Size.Y.Offset>=44,"tab hit under 44 on "..tab)
     if short then assert(b.AbsolutePosition.X>=shop.root.AbsolutePosition.X-1 and b.AbsolutePosition.X+b.AbsoluteSize.X<=shop.root.AbsolutePosition.X+shop.root.AbsoluteSize.X+1)
     else assert(inside(b,shop.root),"tab outside the screen on "..tab)end
    end
    local tiles=if tab=="Background"then shop.backgrounds.tiles else shop.tiles
    -- Panel units: at 385x703 the regular screen scales to ~0.43 as a whole (cards were scaled there before too).
    for _,tile in ipairs(tiles)do
     assert(tile.button.Size.Y.Offset>=44,"card under 44 (panel units) "..tile.id.." on "..tab)
     assert(tile.button.Interactable,"card not interactable "..tile.id.." on "..tab)
    end
    readable(tiles[1].name)
   end
   assert(#sends==0 and #settings==0)
  end)
  test(tostring(size).." leaf modes expose existing actions and no hidden Style targets",function()
   for _,mode in ipairs({"Trials","Settings"})do
    v:showTab(mode);settle();assert(inside(v.cancel,v.card)and inside(v.scroll,v.card)and v.scroll.AbsoluteSize.Y>=44)
    assert(not v.shop.visible and v.card.Visible)
    if mode=="Trials"then
     assert(v.clubHeader.Visible and not v.sound.Visible and v.reward.Text:find("Pocket Trials",1,true));for _,row in ipairs(v.rows)do readable(row.title);readable(row.status);reach(row.frame,v.scroll)end;readable(v.reward);reach(v.reward,v.scroll)
    else for _,n in ipairs({v.sound,v.music,v.motion})do assert(n.Visible and n.AbsoluteSize.Y>=44);readable(n);reach(n,v.scroll)end end
   end
   assert(#settings==0 and #sends==0)
  end)
  test(tostring(size).." latest pending and definitive checks survive resize and reopen without writes",function()
   local function state(bg,confirmed,status)return{themeId="sherbet",stickerId="none",backgroundId=bg,confirmedTheme="sherbet",confirmedSticker="none",confirmedBackground=confirmed,slots={background=status}}end
   v:showTab("Background");v:setAppearance(state("creek","canopy",{status="Pending"}));settle()
   assert(v.choices.Background.canopy.Enabled and not v.choices.Background.creek.Enabled)
   assert(v.shop.backgrounds.tiles[1].status.Text=="IN USE")
   v:setAppearance(state("creek","canopy",{status="Retry",reason="NoReply"}));settle()
   v.shop.backgrounds:focusId("creek");settle()
   assert(v.shop.root:GetAttribute("BackgroundPaneState")=="retry"and v.shop.backgrounds.action.Visible and v.shop.backgrounds.status.Text:find("Retry",1,true))
   v:close("forced");v:open("sherbet","none","Background");settle();assert(v.backgroundId=="creek"and #sends==0)
   v:setAppearance(state("creek","creek",{status="Applied"}));settle()
   assert(v.choices.Background.creek.Enabled and v.shop.backgrounds:focusedId()~=nil)
   local creek=v.shop.backgrounds.tiles[2];assert(creek.id=="creek"and creek.status.Text=="IN USE")
   -- Focus is the shop's ring (2.5 px white), distinct from the selected card's accent outline.
   v.shop.backgrounds:focusId("creek");settle()
   assert(v.shop.ring.target==creek.button and creek.stroke.Thickness==2)
   v:close("back");assert(closes[#closes]=="back"and #sends==0)
  end)
 end
 test("locked inspect and Trials back preserve same Style focus without request",function()
  root.Size=UDim2.fromOffset(733,307);settle();local calls=0
  local v=Picker.new(root,nil,nil,function()end,function()end,function()calls+=1 end,function()calls+=1 end);table.insert(views,v)
  -- Stickers are retired; locked Background art carries the inspect/Trials route.
  v:updateClub(0,0,0,0,"On",false,false,0);v:open("sherbet","none","Background");settle()
  local backs=v.shop.backgrounds
  assert(v:activateChoice("Background","creek")and backs.action.Visible and v:appearanceText():find("Locked",1,true)and calls==0)
  assert(v:activateChoice("Background","lantern")and v:appearanceText():find("Locked",1,true))
  local before=calls;v.onApply=function(slot,id)assert(slot=="background"and id=="canopy")end
  assert(v:activateChoice("Background","canopy")and calls==before and v.inspectId==nil and v:appearanceText()=="Select to wear immediately.")
  v:activateChoice("Background","creek");assert(backs:focusedId()=="creek")
  assert(v.shop:act(false)and v.active=="Trials"and v.innerReturn~=nil and calls==0)
  v:back();settle()
  assert(v.active=="Background"and v.shade.Visible and backs:focusedId()=="creek"and calls==0)
  v:showTab("Shell");assert(v.inspectId==nil and v:appearanceText()=="Select to wear immediately."and not v:appearanceText():find("Locked",1,true));v:close("forced");assert(not v.shade.Visible)
 end)
 end)
 Gui.SelectedObject=nil;for _,v in ipairs(views)do v:close("forced");v.shade:Destroy()end;root:Destroy()
 if Focus.live(prior,nil,game.Players.LocalPlayer:FindFirstChild("PlayerGui"),true)then Gui.SelectedObject=prior end
 assert(ok,err);return{passed=#cases,cases=cases}
end
