-- True ScreenGui, fake intent transport. Eligibility fixtures do not grant profile facts.
-- Deck style Backgrounds tab (UI-SPEC-REDESIGN-MENUS 4 and 5): cards and pane under
-- the shared header; the pane's mini screen borrows the live background renderer
-- only while the tab is shown, and returns it in the same step on close.
return function(client,parent,onlySize)
 local Picker=require(client.DeckPicker);local Intent=require(client.AppearanceIntent);local Art=require(client.DeckArt)
 local Shared=game.ReplicatedStorage.Shared;local Trials=require(Shared.PocketTrials)
 local previousZ=parent.ZIndexBehavior;parent.ZIndexBehavior=Enum.ZIndexBehavior.Global
 local Gui=game:GetService("GuiService");local prior=Gui.SelectedObject;local Focus=require(client.ControllerFocus)
 local root=Instance.new("Frame");root.BackgroundTransparency=1;root.Parent=parent;local views,intents,cases={},{},{}
 local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
 local function inside(n,h)local p,s,q,t=n.AbsolutePosition,n.AbsoluteSize,h.AbsolutePosition,h.AbsoluteSize;return p.X>=q.X-1 and p.Y>=q.Y-1 and p.X+s.X<=q.X+t.X+1 and p.Y+s.Y<=q.Y+t.Y+1 end
 local function test(n,f)f();table.insert(cases,n)end
 local ok,err=pcall(function()
 for _,size in ipairs(if onlySize then {onlySize}else{Vector2.new(1649,971),Vector2.new(812,354),Vector2.new(733,307)})do
  root.Size=UDim2.fromOffset(size.X,size.Y);settle();local sent={};local intent
  local v=Picker.new(root,nil,nil,function()error("locked preview painted live casing")end,function()end,function(slot,id)intent:choose(slot,id)end,function()error("background changed setting")end)
  table.insert(views,v)
  intent=Intent.new({themeId="sherbet",stickerId="none",backgroundId="canopy",revision=0,send=function(p)table.insert(sent,table.clone(p))end,changed=function(state)v:setAppearance(state)end,delay=function()return{}end,cancel=function()end})
  table.insert(intents,intent);v:setAppearance(intent:view());v:updateClub(1,0,0,0,"On",false,false,1,true,0,{pip=0});v.customizationEntry=true;v:open("sherbet","none","Background");settle()
  local shop=v.shop;local backs=shop.backgrounds
  test(tostring(size).." Backgrounds tab: cards and pane inside the screen, the one in use marked",function()
   assert(v.active=="Background"and shop.tab==2 and backs.body.Visible and v.tabs.Background:GetAttribute("AccessibleLabel")=="Background patterns")
   -- On short phones the second row sits below the scroll window (clipped by the grid), not off the sheet.
   for _,tile in ipairs(backs.tiles)do assert(tile.button.AbsoluteSize.Y>=44);if not backs.grid or inside(tile.button,backs.grid)then assert(inside(tile.button,shop.root))end end
   if backs.grid then assert(inside(backs.tiles[1].button,backs.grid)and inside(backs.grid,shop.root))end
   assert(backs.pane.AbsoluteSize.Y>0 and inside(backs.pane,shop.root)and backs.name.Text=="Canopy")
   assert(v.choices.Background.canopy.Enabled and not v.choices.Background.creek.Enabled and #sent==0)
   assert(backs.tiles[1].status.Text=="IN USE"and backs.tiles[3].status.Text:find("Rank II",1,true))
   intent:setFallbacks({background="Unknown"});assert(v:appearanceText():find("Previous background unavailable",1,true)and v.choices.Background.canopy.Enabled and #sent==0)
   intent:setFallbacks({});assert(not v:appearanceText():find("Previous background unavailable",1,true)and #sent==0)
  end)
  test(tostring(size).." locked inspect and the real third-slot reply stay separate",function()
   local liveTheme=Art.getTheme();v:activateChoice("Background","creek");settle()
   assert(v.inspectSlot=="background"and backs:focusedId()=="creek"and v:appearanceText():find("High Roller",1,true)and #sent==0 and intent:view().confirmedBackground=="canopy")
   assert(shop.root:GetAttribute("BackgroundPaneState")=="locked"and backs.action.Visible,"trial lock offers View trials")
   v:activateChoice("Background","canopy");assert(v.inspectId==nil and backs.name.Text=="Canopy"and #sent==0)
   assert(Art.getTheme()==liveTheme)
   -- Explicit fixture facts exercise the public unlock evaluator; never sent to server.
   v:activateChoice("Background","creek");local beforeUnlock=#sent
   v:updateClub(1,Trials.HighRoller.bit,0,0,"On",false,false,1,true,1,{pip=2})
   assert(v.inspectId=="creek"and v:appearanceText()=="Available - Select to wear"and #sent==beforeUnlock and v.choices.Background.canopy.Enabled)
   assert(shop.root:GetAttribute("BackgroundPaneState")=="earned")
   shop:act(false)
   assert(#sent==1 and sent[1].slot=="background"and sent[1].id=="creek"and v.backgroundId=="creek"and v.choices.Background.canopy.Enabled)
   intent:receive({slot="background",id="creek",seq=1,status="Applied",revision=1,themeId="sherbet",stickerId="none",backgroundId="creek"})
   assert(v.choices.Background.creek.Enabled and intent:view().confirmedBackground=="creek"and shop.root:GetAttribute("BackgroundPaneState")=="inUse")
   v:back();assert(not Art.isBackgroundPreviewVisible(backs.previewHost)and #sent==1)
   v:open("sherbet","none","Background");settle();assert(v.backgroundId=="creek"and backs:focusedId()=="creek"and #sent==1)
  end)
  test(tostring(size).." the pane's live preview is borrowed only while shown",function()
   assert(Art.isBackgroundPreviewVisible(backs.previewHost),"shown tab owns the preview")
   for _,node in ipairs(backs.previewHost:GetDescendants())do if node:IsA("GuiObject")then
    assert(node.ZIndex>backs.previewHost.ZIndex,"Global preview paint depth hidden behind the well: "..node:GetFullName())
   end end
   v:shiftStyleTab(-1);settle();assert(v.active=="Shell"and not Art.isBackgroundPreviewVisible(backs.previewHost),"Faceplates releases the preview")
   v:shiftStyleTab(1);settle();assert(Art.isBackgroundPreviewVisible(backs.previewHost))
   local oldHost=backs.previewHost
   local borrowed=oldHost:FindFirstChild("PatternSurface")or oldHost:FindFirstChild("CanopyArt")
   local count=borrowed and #borrowed:GetDescendants()+1
   v:close();assert(not Art.isBackgroundPreviewVisible(oldHost)and #sent==1)
   -- No yield is allowed between releasing and destroying the temporary sheet.
   if borrowed then assert(borrowed.Parent and borrowed.Parent~=oldHost,"close deferred the renderer return")end
   v.shade:Destroy()
   if borrowed then
    assert(borrowed.Parent,"same-step shade destruction killed live renderer")
    local fresh=Picker.new(root,nil,nil,function()end,function()end,function()error("reopen sent appearance")end,function()error("reopen changed setting")end)
    table.insert(views,fresh);fresh:setAppearance(intent:view());fresh:updateClub(1,Trials.HighRoller.bit,0,0,"On",false,false,1,true,1,{pip=2})
    fresh.customizationEntry=true;fresh:open("sherbet","none","Background");settle()
    local host=fresh.shop.backgrounds.previewHost
    if host and host.Visible then
     assert(borrowed.Parent==host and #borrowed:GetDescendants()+1==count,"reborrow replaced the shared renderer")
     Art.setBackgroundPreview(oldHost,nil,nil,false)
     assert(Art.isBackgroundPreviewVisible(host)and borrowed.Parent==host,"old cleanup revoked new owner")
    end
    fresh:close();fresh.shade:Destroy();assert(borrowed.Parent,"fresh close/destroy removed returned renderer")
   end
  end)
 end
 end)
 Gui.SelectedObject=nil;for _,i in ipairs(intents)do i:destroy()end;for _,v in ipairs(views)do v:close();v.shade:Destroy()end;root:Destroy();parent.ZIndexBehavior=previousZ
 if Focus.live(prior,nil,game.Players.LocalPlayer:FindFirstChild("PlayerGui"),true)then Gui.SelectedObject=prior end
 assert(ok,err);return{passed=#cases,cases=cases}
end
