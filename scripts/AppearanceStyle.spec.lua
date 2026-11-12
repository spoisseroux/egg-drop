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
  test(tostring(size).." Style two tabs and first choice fit without Equip",function()
   assert(not v.card:FindFirstChild("Apply")and not v.tabs.Club and not v.tabs.Trials and v.tabs.Background)
   local y=v.tabs.Shell.AbsolutePosition.Y
   -- Faceplates (Shell) open the glass shop screen (FaceplateDeck spec); the card hosts Background.
   for _,tab in ipairs({"Background"})do
    v:showTab(tab);settle();assert(inside(v.card,root)and inside(v.cancel,v.card)and v.cancel.AbsoluteSize==Vector2.new(44,44));assert(inside(v.scroll,v.card)and v.scroll.AbsoluteSize.Y>=44)
    assert(v.tabs.Shell.AbsolutePosition.Y==y and not v.sound.Visible and not v.clubHeader.Visible)
    local first=v.choices[tab].canopy.Parent
    assert(inside(first,v.scroll)and inside(first.Caption,v.scroll),"first row clipped "..tab);readable(first.Caption)
    for _,stroke in pairs(v.choices[tab])do local swatch=stroke.Parent;assert(swatch.AbsoluteSize.Y>=44 and swatch.Interactable);readable(swatch.Caption);reach(swatch,v.scroll)end
    v.scroll.CanvasPosition=Vector2.new(0,math.max(0,v.scroll.CanvasSize.Y.Offset-v.scroll.AbsoluteSize.Y));settle();assert(not v.moreCue.Visible)
   end
   assert(#sends==0 and #settings==0)
  end)
  test(tostring(size).." leaf modes expose existing actions and no hidden Style targets",function()
   for _,mode in ipairs({"Trials","Settings"})do
    v:showTab(mode);settle();assert(inside(v.cancel,v.card)and inside(v.scroll,v.card)and v.scroll.AbsoluteSize.Y>=44)
    assert(not v.tabs.Shell.Visible and not v.tabs.Background.Visible and not v.display.Visible)
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
   if v.saveMarker.Visible then readable(v.saveMarker)else readable(v.heading)end
   v:setAppearance(state("creek","canopy",{status="Retry",reason="NoReply"}));settle()
   assert(v.retryButton.Visible);readable(v.appearanceStatus);reach(v.appearanceStatus,v.scroll);readable(v.retryButton);reach(v.retryButton,v.scroll)
   v:close("forced");v:open("sherbet","none","Background");settle();assert(v.backgroundId=="creek"and #sends==0)
   v:setAppearance(state("creek","creek",{status="Applied"}));settle()
   assert(v.choices.Background.creek.Enabled)
   local selected=v.choices.Background.creek;local edge=selected.Parent:FindFirstChild("UIStroke")
   assert(selected.ApplyStrokeMode==Enum.ApplyStrokeMode.Border and selected.Color==Art.Amber and selected.Transparency==0 and selected.ZIndex>edge.ZIndex,"confirmed border must render above ordinary edge")
   reach(selected.Parent,v.scroll);Gui.SelectedObject=selected.Parent;settle()
   assert(Gui.SelectedObject==selected.Parent and edge.Color==Art.paletteColor("focus") and edge.Thickness>selected.Thickness and selected.Enabled and selected.Color~=edge.Color,string.format("focus must remain distinct: selected=%s target=%s edgeColor=%s expected=%s edgeWidth=%s confirmedWidth=%s confirmedEnabled=%s confirmedColor=%s",tostring(Gui.SelectedObject),tostring(selected.Parent),tostring(edge.Color),tostring(Art.paletteColor("focus")),tostring(edge.Thickness),tostring(selected.Thickness),tostring(selected.Enabled),tostring(selected.Color)))
   -- Rest border is the spec's 1 px white at 14% (UI-SPEC 2.3).
   Gui.SelectedObject=nil;settle();assert(edge.Color==Color3.new(1,1,1) and edge.Transparency>.8 and edge.Thickness<selected.Thickness)
   v:close("back");assert(closes[#closes]=="back"and #sends==0)
  end)
 end
 test("locked inspect and Trials back preserve same Style focus without request",function()
  root.Size=UDim2.fromOffset(733,307);settle();local calls=0
  local v=Picker.new(root,nil,nil,function()end,function()end,function()calls+=1 end,function()calls+=1 end);table.insert(views,v)
  -- Stickers are retired; locked Background art carries the inspect/Trials route.
  v:updateClub(0,0,0,0,"On",false,false,0);v:open("sherbet","none","Background");settle()
  assert(v:activateChoice("Background","creek")and v.trialsLink.Visible and v.previewNote.Text=="Locked preview"and calls==0)
  assert(v:activateChoice("Background","lantern")and v.previewNote.Text=="Locked preview")
  local before=calls;v.onApply=function(slot,id)assert(slot=="background"and id=="canopy")end
  assert(v:activateChoice("Background","canopy")and calls==before and v.inspectId==nil and v.previewNote.Text=="Selection applies immediately")
  v:activateChoice("Background","creek")
  local item=v.choices.Background.creek.Parent;Gui.SelectedObject=item
  local savedScroll=v.scroll.CanvasPosition;v.innerReturn={active="Background",scroll=savedScroll,focus=item};v:showTab("Trials");v:back();settle()
  assert(v.active=="Background"and v.shade.Visible and Gui.SelectedObject==item and calls==0)
  v:showTab("Shell");assert(v.inspectId==nil and v.previewNote.Text=="Selection applies immediately"and not v.trialsLink.Visible and not v.appearanceStatus.Text:find("Locked",1,true));v:close("forced");assert(not v.shade.Visible)
 end)
 end)
 Gui.SelectedObject=nil;for _,v in ipairs(views)do v:close("forced");v.shade:Destroy()end;root:Destroy()
 if Focus.live(prior,nil,game.Players.LocalPlayer:FindFirstChild("PlayerGui"),true)then Gui.SelectedObject=prior end
 assert(ok,err);return{passed=#cases,cases=cases}
end
