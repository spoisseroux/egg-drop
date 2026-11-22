-- Studio Client. Kit.depart (ALIVE-BUILD-PLAN-2026-11-22 step 3, revision 10): the close runs exactly as today
-- and one pooled plate paints where the screen was, only over a bare garden; it never takes input, never
-- outlives a screen opening, the switch or Reduced Motion, and only a player's own close draws it.
-- Usage: require(PlayerScripts.Client.ZZSpecs.KitDepart)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Kit=require(client.DeckKit);local Spring=require(client.KitSpring)
 local Alive=require(game:GetService("ReplicatedStorage").Shared.Alive);local Machine=require(client.MachineHub);local Companions=require(client.CompanionsHub)
 local RunService=game:GetService("RunService");local K=Enum.KeyCode
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function settle(n)for _=1,n or 2 do RunService.Heartbeat:Wait()end end
 parent=parent:FindFirstAncestorOfClass("PlayerGui")or parent -- the suite runner passes a ScreenGui; a gui inside a gui has no layout of its own
 local holder=Instance.new("Folder");holder.Name="_KitDepartSpec";holder.Parent=parent
 local gui=Instance.new("ScreenGui");gui.Name="Screens";gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.IgnoreGuiInset=true;gui.ResetOnSpawn=false;gui.Parent=holder
 local saved={reduced=Kit.reduced,effects=Kit.reducedEffects,inRoom=Kit.inRoom,top=Kit.shadeTop}
 local attrs={};for _,f in ipairs(Alive.Features)do attrs[f]=workspace:GetAttribute(Alive.attribute(f))end
 local function flags(on)for _,f in ipairs(Alive.Features)do workspace:SetAttribute(Alive.attribute(f),on)end end
 local still,room=false,true
 Kit.reduced=function()return still end;Kit.reducedEffects=false;Kit.inRoom=function()return room end
 local function plate()local g=holder:FindFirstChild("EggDropDepart");return if g and g.Enabled then g.Plate else nil,g end
 -- Sampled frame by frame: a slow Studio frame must not outlive the .12 s plate unseen.
 local function appears()for _=1,3 do if plate()then return true end;RunService.Heartbeat:Wait()end;return plate()~=nil end
 local function screen()
  local f=Instance.new("Frame");f.Name="Screen";f.Size=UDim2.fromOffset(400,300);f.Position=UDim2.fromOffset(60,40);f.BackgroundColor3=Color3.fromRGB(40,80,200)
  f.Parent=gui;Instance.new("UICorner").Parent=f;f.UICorner.CornerRadius=UDim.new(0,20);return f
 end
 local owner={};local shade
 local layer=Instance.new("Frame");layer.Size=UDim2.fromScale(1,1);layer.BackgroundTransparency=1;layer.Parent=gui
 local ok,problem=xpcall(function()
  shade=Kit.modalShade(layer,"SpecShade",1);settle()
  assert(Kit.shadeTop()==nil,"run with every menu closed")
  flags(true)
  test("the plate covers the screen's rect in its colour and radius, takes no input, and is gone in .2 s; one is pooled",function()
   local f=screen();settle();local at,size=f.AbsolutePosition,f.AbsoluteSize
   for _=1,3 do
    f.Visible=true;settle();assert(Kit.depart(f)==true and plate()==nil,"never on the closing frame");f.Visible=false
    assert(appears(),"drawn on the next heartbeat");local p,g=plate()
    assert(not p.Active and not p.Interactable and not p.Selectable and p.BackgroundColor3==f.BackgroundColor3 and g.ScreenInsets==Enum.ScreenInsets.None and g.DisplayOrder<40)
    assert(p.UICorner.CornerRadius.Offset==20 and #p:GetChildren()==1)
    local c=p.AbsolutePosition+p.AbsoluteSize/2-(at+size/2);assert(c.Magnitude<=2,"centre "..tostring(c))
    assert(p.AbsoluteSize.X<=size.X+2 and p.AbsoluteSize.X>=size.X*.95 and p.BackgroundTransparency>=.34)
    task.wait(.25);assert(plate()==nil)
   end
   local n=0;for _,c in ipairs(holder:GetChildren())do if c.Name=="EggDropDepart"then n+=1 end end;assert(n==1);f:Destroy()
  end)
  test("nothing is drawn: off, Reduced Motion, Motion: Low, a round, a hidden screen, a refused close, or a screen open",function()
   local f=screen();settle()
   local function try(before,after)
    f.Visible=true;settle();before();local took=Kit.depart(f);f.Visible=false;if after then after()end;local drawn=appears()
    flags(true);still=false;room=true;Kit.reducedEffects=false;Kit.shadeClose(owner);Kit.cutDepart();return took,drawn
   end
   local function none(took,drawn)return took==false and not drawn end
   local function late(took,drawn)return took==true and not drawn end
   assert(none(try(function()flags(false)end))and none(try(function()flags(nil)end))and none(try(function()still=true end)))
   assert(none(try(function()Kit.reducedEffects=true end))and none(try(function()room=false end))and none(try(function()f.Visible=false end)))
   local function nothing()end
   assert(late(try(nothing,function()room=false end)),"a round starts on the same frame")
   assert(late(try(nothing,function()f.Visible=true end)),"the close was refused")
   assert(late(try(nothing,function()Kit.shadeOpen(owner,shade)end)),"another screen opened")
   assert(late(try(nothing,function()Kit.shadeOpen(owner,shade);Kit.shadeClose(owner)end)),"even one that closed again")
   assert(late(try(function()Kit.shadeOpen(owner,shade)end)),"one was under it")
   assert(late(try(nothing,function()flags(false)end))and late(try(nothing,function()still=true end)))
   assert(late(try(nothing,function()f:Destroy()end))==false,"a destroyed screen may still leave its plate")
   assert(Kit.depart(nil)==false)
  end)
  test("a live plate is cut within a frame by a screen opening, the switch, Reduced Motion or a round",function()
   for _,cut in ipairs({function()Kit.shadeOpen(owner,shade)end,function()flags(false)end,function()still=true end,function()Kit.reducedEffects=true end,function()room=false end})do
    local f=screen();settle();Kit.depart(f);f.Visible=false;assert(appears(),"live")
    cut();settle();assert(plate()==nil);flags(true);still=false;room=true;Kit.reducedEffects=false;Kit.shadeClose(owner);f:Destroy()
   end
   local f=screen();settle();Kit.depart(f);f.Visible=false;assert(appears());Kit.shadeOpen(owner,shade);assert(plate()==nil,"shadeOpen cuts it at once, not a frame later");Kit.shadeClose(owner);f:Destroy()
  end)

  -- The same player close, flags on and off: state, shade, focus and onClosed in the same order.
  local function story(on,def,how)
   flags(on)
   local log={};local h=Instance.new("Frame");h.BackgroundTransparency=1;h.Size=UDim2.fromOffset(1280,720);h.Parent=gui
   local hub
   hub=def.make(h,function(reason)
    table.insert(log,table.concat({"closed",tostring(reason),"open="..tostring(hub:isOpen()),"root="..tostring(hub.root.Visible),"shade="..tostring(hub.shade.Visible),
     "stack="..tostring(Kit.shadeTop()),"ring="..tostring(hub.ring.root.Visible)}," "))
   end,function()table.insert(log,"back")end)
   hub:open({owned=1,wallet=5,state={inventoryMask=1},activeId="pip"})
   hub.root:GetPropertyChangedSignal("Visible"):Connect(function()table.insert(log,"root "..tostring(hub.root.Visible))end)
   task.wait(.1);how(hub);table.insert(log,"after root="..tostring(hub.root.Visible).." shade="..tostring(hub.shade.Visible))
   local drawn=appears();settle()
   hub:destroy();h:Destroy();Kit.cutDepart();return table.concat(log,"|"),drawn
  end
  for _,def in ipairs({{name="MachineHub",make=function(h,closed)return Machine.new(h,{closed=closed})end},
   {name="CompanionsHub",make=function(h,closed,back)return Companions.new(h,{appearance=function()return{}end,closed=closed,back=back})end}})do
   test(def.name..": B, Escape, Backspace and the close key draw a plate; the story is the same with it off",function()
    for _,how in ipairs({function(hub)hub:input(K.ButtonB)end,function(hub)hub:input(K.Escape)end,function(hub)hub:input(K.Backspace)end,function(hub)hub:back()end,
     function(hub)hub:input(K.ButtonB);hub:input(K.ButtonB)end})do
     local a,drawnOn=story(true,def,how);local b,drawnOff=story(false,def,how)
     assert(a==b,def.name.." on: "..a.." off: "..b);assert(not drawnOff);assert(drawnOn or string.find(a,"back",1,true)==nil,"plate")
    end
   end)
   test(def.name..": store, forced, machine and destroy closes never draw one",function()
    for _,reason in ipairs({"store","forced","machine","assigned"})do
     local a,drawn=story(true,def,function(hub)hub:close(reason)end);assert(not drawn,reason);assert(a==story(false,def,function(hub)hub:close(reason)end),reason)
    end
    local _,drawn=story(true,def,function(hub)hub:destroy()end);assert(not drawn)
   end)
  end
  test("Companions: Back from Pets to the hub is a page, not a close",function()
   local _,drawn=story(true,{make=function(h,closed)return Companions.new(h,{appearance=function()return{}end,closed=closed})end},function(hub)
    hub:setPage("pets");settle();hub:input(K.ButtonB);assert(hub:isOpen()and hub.page=="hub")
   end)
   assert(not drawn)
  end)
 end,function(e)return debug.traceback(tostring(e),2)end)
 Kit.shadeClose(owner);Kit.cutDepart()
 Kit.reduced,Kit.reducedEffects,Kit.inRoom=saved.reduced,saved.effects,saved.inRoom
 Spring.settle(gui);holder:Destroy()
 for _,f in ipairs(Alive.Features)do workspace:SetAttribute(Alive.attribute(f),attrs[f])end
 assert(ok,problem)
 return{passed=#cases,cases=cases}
end
