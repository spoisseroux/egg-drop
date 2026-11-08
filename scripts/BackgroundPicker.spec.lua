-- True ScreenGui, fake intent transport. Eligibility fixtures do not grant profile facts.
return function(client,parent,onlySize)
 local Picker=require(client.DeckPicker);local Intent=require(client.AppearanceIntent);local Art=require(client.DeckArt)
 local Shared=game.ReplicatedStorage.Shared;local Themes=require(Shared.DeckThemes);local Trials=require(Shared.PocketTrials)
 local previousZ=parent.ZIndexBehavior;parent.ZIndexBehavior=Enum.ZIndexBehavior.Global
 local Gui=game:GetService("GuiService");local prior=Gui.SelectedObject;local Focus=require(client.ControllerFocus)
 local root=Instance.new("Frame");root.BackgroundTransparency=1;root.Parent=parent;local views,intents,cases={},{},{}
 local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
 local function inside(n,h)local p,s,q,t=n.AbsolutePosition,n.AbsoluteSize,h.AbsolutePosition,h.AbsoluteSize;return p.X>=q.X-1 and p.Y>=q.Y-1 and p.X+s.X<=q.X+t.X+1 and p.Y+s.Y<=q.Y+t.Y+1 end
 local function fit(n)assert(n.TextFits,n.Name.." "..n.Text.." "..tostring(n.AbsoluteSize).." "..tostring(n.TextBounds))end
 local function test(n,f)f();table.insert(cases,n)end
 local ok,err=pcall(function()
 for _,size in ipairs(if onlySize then {onlySize}else{Vector2.new(1649,971),Vector2.new(733,307),Vector2.new(568,160),Vector2.new(385,703)})do
  root.Size=UDim2.fromOffset(size.X,size.Y);settle();local sent={};local intent
  local v=Picker.new(root,nil,nil,function()error("locked preview painted live casing")end,function()end,function(slot,id)intent:choose(slot,id)end,function()error("background changed setting")end)
  table.insert(views,v)
  intent=Intent.new({themeId="sherbet",stickerId="none",backgroundId="canopy",revision=0,send=function(p)table.insert(sent,table.clone(p))end,changed=function(state)v:setAppearance(state)end,delay=function()return{}end,cancel=function()end})
  table.insert(intents,intent);v:setAppearance(intent:view());v:updateClub(1,0,0,0,"On",false,false,1,true,0,{pip=0});v:open("sherbet","none","Background");settle()
  test(tostring(size).." actual third category fits with complete first choice and neutralX",function()
   assert(v.active=="Background"and v.tabs.Background.Visible and v.tabs.Background:GetAttribute("AccessibleLabel")=="Background patterns")
   for _,tab in pairs(v.tabs)do assert(tab.AbsoluteSize.Y>=44 and inside(tab,v.card));fit(tab)end
   assert(v.cancel.AbsoluteSize==Vector2.new(44,44)and inside(v.cancel,v.card)and v.scroll.AbsoluteSize.Y>=44)
   local first=v.choices.Background.canopy.Parent;assert(inside(first,v.scroll)and inside(first.Caption,v.scroll));fit(first.Caption)
   assert(v.choices.Background.canopy.Enabled and not v.choices.Background.creek.Enabled and #sent==0)
   intent:setFallbacks({background="Unknown"});assert(v.appearanceStatus.Text:find("Previous background unavailable",1,true)and v.choices.Background.canopy.Enabled and #sent==0)
   intent:setFallbacks({});assert(not v.appearanceStatus.Text:find("Previous background unavailable",1,true)and #sent==0)
  end)
  test(tostring(size).." locked preview/no-op reselect and real third-slot reply stay separate",function()
   local liveTheme=Art.getTheme();v:activateChoice("Background","creek");settle()
   assert(v.inspectSlot=="background"and v.previewNote.Text=="Locked preview"and v.appearanceStatus.Text:find("High Roller",1,true)and #sent==0 and intent:view().confirmedBackground=="canopy")
   v:activateChoice("Background","canopy");assert(v.inspectId==nil and v.previewName.Text=="Canopy"and #sent==0)
   v:showTab("Shell");v:activateChoice("Shell","honey");settle()
   assert(v.screen.BackgroundColor3==Themes.ById.honey.lcd.base and v.shell.BackgroundColor3==Themes.ById.honey.shell and Art.getTheme()==liveTheme and #sent==0)
   v:activateChoice("Shell","sherbet");assert(v.screen.BackgroundColor3==Themes.ById.sherbet.lcd.base and #sent==0)
   -- Explicit fixture facts exercise the public unlock evaluator; never sent to server.
   v:showTab("Background");v:activateChoice("Background","creek");local beforeUnlock=#sent
   v:updateClub(1,Trials.HighRoller.bit,0,0,"On",false,false,1,true,1,{pip=2})
   assert(v.inspectId=="creek"and v.previewNote.Text=="Available preview"and v.appearanceStatus.Text=="Available - Select to wear"and not v.trialsLink.Visible and #sent==beforeUnlock and v.choices.Background.canopy.Enabled)
   v:activateChoice("Background","creek")
   assert(#sent==1 and sent[1].slot=="background"and sent[1].id=="creek"and v.backgroundId=="creek"and v.choices.Background.canopy.Enabled)
   intent:receive({slot="background",id="creek",seq=1,status="Applied",revision=1,themeId="sherbet",stickerId="none",backgroundId="creek"})
   assert(v.choices.Background.creek.Enabled and intent:view().confirmedBackground=="creek")
   v:back();assert(not Art.isBackgroundPreviewVisible(v.backgroundPreview)and #sent==1)
   v:open("sherbet","none","Background");settle();assert(v.backgroundId=="creek"and #sent==1)
  end)
  test(tostring(size).." fully clipped inspected preview yields shared motion owner",function()
   if v.display.Visible then
    v.scroll.CanvasPosition=Vector2.zero;settle();assert(v.backgroundPreview.Visible and Art.isBackgroundPreviewVisible(v.backgroundPreview))
    local layers=0
    for _,node in ipairs(v.backgroundPreview:GetDescendants())do if node:IsA("GuiObject")then
     layers+=1;assert(node.ZIndex>v.backgroundPreview.ZIndex and node.ZIndex<v.previewName.ZIndex and node.ZIndex<v.cancel.ZIndex,"Global preview paint depth hidden behind chrome or over name/X: "..node:GetFullName())
    end end
    assert(layers>0,"visible preview has no live shared art")
    v.scroll.CanvasPosition=Vector2.new(0,math.max(0,v.scroll.CanvasSize.Y.Offset-v.scroll.AbsoluteSize.Y));settle()
    local top=v.display.Position.Y.Offset+v.backgroundPreview.Position.Y.Offset-v.scroll.CanvasPosition.Y
    if top+v.backgroundPreview.Size.Y.Offset<=0 then assert(not v.backgroundPreview.Visible and not Art.isBackgroundPreviewVisible(v.backgroundPreview))end
    v.scroll.CanvasPosition=Vector2.zero;settle();assert(Art.isBackgroundPreviewVisible(v.backgroundPreview))
   else assert(not Art.isBackgroundPreviewVisible(v.backgroundPreview))end
   local oldHost=v.backgroundPreview
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
    fresh:open("sherbet","none","Background");settle()
    if fresh.backgroundPreview.Visible then
     assert(borrowed.Parent==fresh.backgroundPreview and #borrowed:GetDescendants()+1==count,"reborrow replaced the shared renderer")
     Art.setBackgroundPreview(oldHost,nil,nil,false)
     assert(Art.isBackgroundPreviewVisible(fresh.backgroundPreview)and borrowed.Parent==fresh.backgroundPreview,"old cleanup revoked new owner")
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
