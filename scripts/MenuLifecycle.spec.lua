-- Real LocalScript + enabled ScreenGui. Does not change global text preferences.
return function(client,parent)
 local Menu=require(client.DeckMenu);local Focus=require(client.ControllerFocus);local Gui=game:GetService("GuiService")
 local prior=Gui.SelectedObject;local root=Instance.new("Frame");root.Name="_MenuLifecycle";root.BackgroundTransparency=1;root.Size=UDim2.fromOffset(733,307);root.Parent=parent
 local cases,views={},{};local sent=0
 local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
 local function test(name,run)run();table.insert(cases,name)end
 local function make()
  local v=Menu.new(root,{close=function()end,eggs=function()sent+=1 end});table.insert(views,v)
  v:update({status="Ready",nectar=6},"pip");v:open();settle();return v
 end
 local ok,err=pcall(function()
  local menu=make()
  test("live resize and preferred-text reflow retain wallet and pinned close",function()
   local before=menu.layoutPasses;root.Size=UDim2.fromOffset(385,703);settle()
   assert(menu.layoutPasses>before and menu.wallet.Parent==menu.card and menu.nectar.Parent==menu.wallet)
   assert(menu:refreshTextPreference()and menu.closeButton.AbsoluteSize.X>=44 and menu.closeButton.AbsoluteSize.Y>=44)
  end)
  local connections=table.clone(menu.connections);local passes=menu.layoutPasses
  test("same-step teardown fences queued preference work and parent resize",function()
   local completed=false
   task.defer(function()assert(menu:refreshTextPreference()==false);completed=true end)
   menu.shade:Destroy();root.Size=UDim2.fromOffset(733,307);settle()
   assert(completed and menu.destroyed and not menu:isLive()and menu.layoutPasses==passes)
   assert(menu.wallet.Parent==nil and menu.card.Parent==nil)
  end)
  test("all external resize/scroll/preference connections disconnect",function()
   assert(#connections>0 and #menu.connections==0)
   for _,connection in ipairs(connections)do assert(not connection.Connected,"destroyed menu kept an external signal")end
  end)
  test("late providers and stale actions do not mutate detached menu or send",function()
   local state,page,top=menu.state,menu.page,menu.safeTop
   assert(menu:layout()==false and menu:layoutContents()==false and menu:refreshScrollCue()==false)
   assert(menu:update({status="Ready",nectar=999})==false and menu:setFieldObjective(false,"Playing")==false and menu:setSaveNotice({short="Retrying"})==false)
   assert(menu:activate("eggs")==false and menu:activatePage("daily")==false and menu:setPage("daily")==false and menu:open()==false and menu:close()==false)
   assert(menu.state==state and menu.page==page and menu.safeTop==top and menu.layoutPasses==passes and sent==0 and menu.wallet.Parent==nil)
  end)
  test("a replacement menu still responds without reviving prior listeners",function()
   local replacement=make();local before=replacement.layoutPasses
   root.Size=UDim2.fromOffset(568,160);settle();assert(replacement:isLive()and replacement.layoutPasses>before)
   assert(replacement.wallet.Parent==replacement.card and menu.layoutPasses==passes and #menu.connections==0)
   replacement:close();replacement.shade:Destroy();settle();assert(replacement.destroyed and #replacement.connections==0)
  end)
 end)
 for _,v in ipairs(views)do v:close();v.shade:Destroy()end
 Gui.SelectedObject=if Focus.live(prior,nil,game.Players.LocalPlayer.PlayerGui,true)then prior else nil
 root:Destroy();assert(ok,err);return cases
end
