-- Real LocalScript + enabled ScreenGui, Medium/Largest. Optional one-root run.
return function(client,parent,onlySize)
 assert(parent:IsA("ScreenGui")and parent.Enabled,"enabled ScreenGui required")
 local Catalog=require(game.ReplicatedStorage.Shared.FieldObjectives);local Copy=require(client.FieldQuestText)
 local Quest=require(client.BoardQuestHUD);local Layout=require(client.DeckLayout);local Art=require(client.DeckArt)
 local Menu=require(client.DeckMenu);local Focus=require(client.ControllerFocus);local Gui=game:GetService("GuiService")
 local prior=Gui.SelectedObject;local root=Instance.new("Frame");root.Name="_FieldQuestLayout";root.BackgroundTransparency=1;root.Parent=parent
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function settle()game:GetService("RunService").Heartbeat:Wait();game:GetService("RunService").Heartbeat:Wait()end
 local function public(id,step,progress)
  local d=Catalog.create(id,17)
  return{sequence=71,templateId=d.id,title=d.title,dynamics={id=d.dynamics.id,label=d.dynamics.label},goals=d.goals,
   step=step,progress=progress or 0,target=if step==3 then 0 else d.goals[step].target,complete=step==3}
 end
 local function fit(label)
  assert(label.TextFits,string.format("%s %q box%s bounds%s",label.Name,label.Text,tostring(label.AbsoluteSize),tostring(label.TextBounds)))
  assert(not label.TextScaled)
 end
 local function inside(node,host)
  local p,s,q,t=node.AbsolutePosition,node.AbsoluteSize,host.AbsolutePosition,host.AbsoluteSize
  return p.X>=q.X-1 and p.Y>=q.Y-1 and p.X+s.X<=q.X+t.X+1 and p.Y+s.Y<=q.Y+t.Y+1
 end
 local ok,err=pcall(function()
 for _,size in ipairs(if onlySize then {onlySize}else {Vector2.new(1649,971),Vector2.new(733,307),Vector2.new(568,160),Vector2.new(385,703)})do
  root.Size=UDim2.fromOffset(size.X,size.Y);settle()
  local service=game:GetService("TextService");local short=size.X>=size.Y*1.2 and size.Y<280
  local cap=if short then 12 else 14
  local line=math.ceil(service:GetTextSize("Next",12,Enum.Font.Gotham,Vector2.new(1000,100)).Y)+4
  local mark=service:GetTextSize("III",12,Enum.Font.GothamBold,Vector2.new(1000,100));local diameter=math.max(18,math.ceil(math.max(mark.X,mark.Y))+6)
  local wallet=math.ceil(service:GetTextSize("0",18,Enum.Font.GothamBold,Vector2.new(1000,100)).Y)+4
  local l=Layout.resolve(size,11.8/19.8,{utilityWidth=service:GetTextSize("Lounge",cap,Enum.Font.GothamBold,Vector2.new(1000,100)).X+14,lineHeight=line,
   queueHeight=math.max(line+diameter+10,line*2+8),walletLineHeight=wallet,countWidth=service:GetTextSize("24/24",12,Enum.Font.Gotham,Vector2.new(1000,100)).X+4})
  local compact=l.short or l.dense or l.quest.h<60
  local host=Art.frame(root,"QuestWell",Art.Ink,UDim2.fromOffset(l.quest.x,l.quest.y),UDim2.fromOffset(l.quest.w,l.quest.h),2)
  local quest=Quest.new(host)
  test(tostring(size).." every active goal count expiry complete and save recovery fits",function()
   local noneHeight=quest:preferredHeight(l.quest.w,l.quest.h,compact,Copy.NoField)
   host.Size=UDim2.fromOffset(l.quest.w,noneHeight);settle();quest:update(0,"Playing",true,compact,Copy.NoField);settle()
   fit(quest.title);assert(not quest.title.Text:lower():find("loading",1,true)and not quest.progress.Visible)
   for _,id in ipairs(Catalog.Order)do
    local maximum=l.quest.h;local firstHeight
    for _,state in ipairs({{1,0,"Playing"},{2,0,"Playing"},{2,if id=="lantern_chain"then 1 else 0,"Playing"},{2,0,"Playing"},{3,0,"Playing"},{3,0,"Settling"}})do
     local view=public(id,state[1],state[2]);local h=quest:preferredHeight(l.quest.w,maximum,compact,view)
     if firstHeight then assert(h==firstHeight,"passive quest footprint moved across objective states")else firstHeight=h end
     host.Size=UDim2.fromOffset(l.quest.w,h);settle();quest:update(view.step-1,state[3],true,compact,view);settle()
     fit(quest.title);assert(inside(quest.title,host))
     for _,node in ipairs({quest.progress,quest.dynamics})do if node.Visible then fit(node);assert(inside(node,host))end end
     local copy=Copy.describe(view,state[3]);local meaning=quest.title:GetAttribute("AccessibleLabel")
     assert(meaning:find(copy.instruction,1,true),"instruction lost in preferred fallback")
     if state[3]=="Playing"and state[1]<3 then
      if id=="creek_crossing"and state[1]==1 then assert(quest.title.Text:lower():find("center",1,true)or quest.title.Text:lower():find("mid",1,true))end
      if id=="lantern_chain"then assert(quest.title.Text:find(state[2].."/2",1,true),"actual count lost")end
     end
     quest.host.Visible=false;quest:update(view.step-1,state[3],true,compact,view);assert(quest.host.Visible);fit(quest.title)
    end
   end
   quest:update(0,"Playing",true,compact,false);settle();assert(quest.title.Text:find("Loading",1,true)or quest.title.Text:find("loading",1,true));fit(quest.title)
  end)
  test(tostring(size).." Menu exposes metadata without replacing live actions or selection",function()
   local sends=0;local menu=Menu.new(root,{close=function()end,eggs=function()sends+=1 end})
   menu:update({status="Ready",nectar=6},"pip");menu:open();local action=menu.destinations[1].button;Gui.SelectedObject=action
   for _,id in ipairs(Catalog.Order)do
    local view=public(id,1,0);menu:setFieldObjective(view,"Playing");settle()
    assert(menu.playHint.Text:find(view.title,1,true)and menu.playHint.Text:find("1.",1,true)and menu.playHint.Text:find("2.",1,true))
    if id~="bank_pair"then assert(menu.playHint.Text:find(view.dynamics.label,1,true))end
    assert(menu.destinations[1].button==action and Gui.SelectedObject==action and sends==0)
    assert(menu.closeButton.AbsoluteSize.X>=44 and menu.closeButton.AbsoluteSize.Y>=44)
   end
   menu:close();menu.shade:Destroy()
  end)
  host:Destroy()
 end
 end)
 Gui.SelectedObject=if Focus.live(prior,nil,game.Players.LocalPlayer.PlayerGui,true)then prior else nil
 root:Destroy();assert(ok,err);return cases
end
