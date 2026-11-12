-- Real LocalScript/ScreenGui: semantic action states, isolated previews, cached
-- finishes and assigned faces. Does not touch appearance intents or save data.
return function(client,parent)
 assert(parent:IsA("ScreenGui")and parent.Enabled,"enabled ScreenGui required")
 local Art=require(client.DeckArt);local Themes=require(game.ReplicatedStorage.Shared.DeckThemes)
 local Gui=game:GetService("GuiService");local prior=Gui.SelectedObject;local old=Art.getTheme()
 local root=Instance.new("Frame");root.Name="_SharedFinish";root.Size=UDim2.fromOffset(500,260);root.Parent=parent
 local cases={};local baseline=Art.themeStats().nodes
 local function test(name,run)run();table.insert(cases,name)end
 local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
 local ok,err=pcall(function()
  local panel=Art.frame(root,"Sheet","panel",UDim2.fromOffset(0,0),UDim2.fromOffset(500,260));Art.panel(panel,16)
  local preview=Art.frame(panel,"Preview",Art.Ink,UDim2.fromOffset(12,12),UDim2.fromOffset(140,90))
  local action=Instance.new("TextButton");action.Name="Action";action.Text="Meet Wick";action.Size=UDim2.fromOffset(200,44);action.Position=UDim2.fromOffset(12,150);action.Parent=panel
  Art.button(action,10);Art.type(action,"Action",true);Art.control(action,true,true)
  local secondary=Instance.new("TextButton");secondary.Name="Back";secondary.Text="Back";secondary.Size=UDim2.fromOffset(200,44);secondary.Position=UDim2.fromOffset(240,200);secondary.Parent=panel
  Art.button(secondary,10);Art.type(secondary,"Action",true);Art.control(secondary,false,true)
  local counter=Art.text(panel,"Exact","1000000",UDim2.fromOffset(240,150),UDim2.fromOffset(180,44),"text",18)
  Art.type(counter,"Counter");counter.TextWrapped=false
  local heading=Art.text(panel,"Heading","A new friend",UDim2.fromOffset(170,12),UDim2.fromOffset(300,44),"text",24);Art.type(heading,"Heading")
  test("assigned faces retain measured targets and distinguish exact Roman marks",function()
   settle();assert(action.Font==Art.SheetFont.Action and heading.Font==Art.SheetFont.Heading and counter.Font==Enum.Font.RobotoMono)
   for _,label in ipairs({action,heading,counter})do assert(label.TextFits,label.Name.." "..tostring(label.TextBounds))end
   assert(action.AbsoluteSize.Y>=44 and Art.actionHeight(action,200)>=44)
   for _,mark in ipairs({"I","II","III","IV","V"})do counter.Text=mark;settle();assert(counter.TextFits and counter.TextBounds.X>0)end
   counter.Text="1000000"
  end)
  for _,id in ipairs(Themes.Order)do test(id.." hot theme paints actual primary, disabled and restored states",function()
   local t=Themes.ById[id];Art.applyTheme(t);settle()
   assert(action.BackgroundColor3==t.ui.accent and action.TextColor3==t.ui.ink)
   assert(panel.BackgroundColor3==t.ui.panel and panel:FindFirstChildOfClass("UIGradient").Rotation==100)
   action.Interactable=false;settle();assert(action.BackgroundColor3==t.ui.raised and action.TextColor3==t.ui.muted)
   action.Interactable=true;settle();assert(action.BackgroundColor3==t.ui.accent and action.TextColor3==t.ui.ink)
   assert(action.TextFits and counter.TextFits and action.AbsoluteSize.Y>=44)
  end)end
  test("locked finish preview never changes confirmed sheet or control colors",function()
   local confirmed=Themes.ById.brick;Art.applyTheme(confirmed)
   Art.finish(preview,Themes.ById.gloaming,"face");settle()
   assert(Art.getTheme()==confirmed and panel.BackgroundColor3==confirmed.ui.panel and action.BackgroundColor3==confirmed.ui.accent)
   local gradient=preview:FindFirstChildOfClass("UIGradient");local stops=gradient.Color.Keypoints
   assert(preview.BackgroundColor3==Color3.new(1,1,1)and #stops==3 and stops[1].Value==Themes.ById.gloaming.highlight and stops[3].Value==Themes.ById.gloaming.shell)
  end)
  test("repeated themes, previews and state paints allocate no nodes or sequences",function()
   local count=#root:GetDescendants();local gradient=preview:FindFirstChildOfClass("UIGradient")
   local writes=0;local listener=gradient:GetPropertyChangedSignal("Color"):Connect(function()writes+=1 end)
   local before=Art.themeStats()
   for _=1,20 do assert(not Art.applyTheme(Themes.ById.brick));Art.finish(preview,Themes.ById.gloaming,"face");Art.control(action,true,true)end
   settle();listener:Disconnect()
   assert(writes==0 and #root:GetDescendants()==count and Art.themeStats().writes==before.writes)
   assert(gradient==preview:FindFirstChildOfClass("UIGradient"))
  end)
  test("controller focus keeps an outer light stroke and inner dark keyline",function()
   Gui.SelectedObject=action;settle()
   local border=action:FindFirstChildOfClass("UIStroke");local keyline=action.FocusKeyline:FindFirstChildOfClass("UIStroke")
   -- Native selection may be unavailable without a gamepad/navigation mode.
   if Gui.SelectedObject==action then
    assert(border.Thickness==2,"selected outer thickness="..tostring(border.Thickness))
    assert(border.Color==Art.paletteColor("focus"),"selected outer color="..tostring(border.Color).." expected="..tostring(Art.paletteColor("focus")))
    assert(keyline.Transparency==0,"selected inner transparency="..tostring(keyline.Transparency))
   end
   Gui.SelectedObject=secondary;settle()
   assert(keyline.Transparency==1,"focus transfer selected="..tostring(Gui.SelectedObject).." old inner transparency="..tostring(keyline.Transparency))
   if Gui.SelectedObject==secondary then assert(secondary.FocusKeyline:FindFirstChildOfClass("UIStroke").Transparency==0,"new target did not receive inner focus")end
   Gui.SelectedObject=nil;settle();assert(keyline.Transparency==1,"cleared selection="..tostring(Gui.SelectedObject).." inner transparency="..tostring(keyline.Transparency))
  end)
 end)
 Gui.SelectedObject=nil;root:Destroy();settle()
 local cleaned=Art.themeStats().nodes
 Art.applyTheme(old or Themes.ById[Themes.Default])
 if prior and prior.Parent then Gui.SelectedObject=prior end
 assert(ok,err);assert(cleaned==baseline,"destroyed finish bindings survived")
 return{passed=#cases,cases=cases,preference=Gui.PreferredTextSize.Name}
end
