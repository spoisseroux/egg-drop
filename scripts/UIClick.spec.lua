-- Studio Client. QA v775 note 12: every UI button gives audio feedback, through one
-- shared helper (UIClick). Three parts:
--   1. pure rules (a button's kind, which kind wins a press, when a button is silent);
--   2. the helper itself on a fake audio and its own gui: it binds every button, old and
--      new, plays one sound per press, lets the owner's own kind win, and keeps disabled,
--      hidden and "none" buttons silent;
--   3. the walk: every GuiButton in the running game's menus (the garden hub, Pocket menu,
--      Companions and its Pets page, Customize, Wardrobe, Hatch eggs, Book, Deck style,
--      and whatever else is built under PlayerGui), plus a freshly built machine hub and
--      Companions screen, must be bound by the live helper, and a press on each enabled
--      one must really play a cue. Any button with no click sound fails, by name.
-- Open the menus first (or run it again with them open) so screens built on first use
-- are walked too; the result lists how many buttons each gui had.
-- Usage: require(PlayerScripts.Client.ZZSpecs.UIClick)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 -- Its own copy of the helper (the game's is running). The copy stays parented until the
 -- end: a destroyed script's deferred threads never run.
 local fresh=client.UIClick:Clone();fresh.Name="_UIClickSpecCopy";fresh.Parent=client
 local Click=require(fresh)
 local Kit=require(client.DeckKit)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local gui=Instance.new("ScreenGui");gui.Name="_UIClickSpec";gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Enabled=false
 local walkGui=Instance.new("ScreenGui");walkGui.Name="_UIClickWalk";walkGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;walkGui.DisplayOrder=-50
 local function settle(n)for _=1,n or 2 do game:GetService("RunService").Heartbeat:Wait()end end
 local function button(name,root)
  local b=Instance.new("TextButton");b.Name=name;b.Size=UDim2.fromOffset(60,44);b.Parent=root or gui;return b
 end
 local report={}
 local ok,problem=xpcall(function()
  test("pure: a button's kind, the winner of one press, and when a button is silent",function()
   assert(Click.kindOf(nil)=="confirm"and Click.kindOf("tab")=="tab"and Click.kindOf("back")=="back"and Click.kindOf("equip")=="equip")
   assert(Click.kindOf("none")==nil and Click.kindOf("bogus")=="confirm"and Click.kindOf(7)=="confirm")
   assert(Click.pick(nil,"confirm")=="confirm"and Click.pick("confirm",nil)=="confirm")
   assert(Click.pick("confirm","tab")=="tab"and Click.pick("back","confirm")=="back","the owner's kind beats the plain click")
   assert(Click.pick("tab","equip")=="equip"and Click.pick("unequip","confirm")=="unequip"and Click.pick("tab","back")=="tab")
   assert(Click.live(true,true,true)and not Click.live(false,true,true)and not Click.live(true,false,true)and not Click.live(true,true,false))
   for kind in pairs(Click.Priority)do assert(Click.kindOf(kind)==kind,kind)end
   assert(Click.Priority.equip and Click.Priority.unequip,"equip and unequip are their own kinds (note 10)")
  end)
  local calls={}
  local audio={ui=function(_,kind,token)table.insert(calls,{kind,token});return true end}
  test("the helper binds every button: those already there and those added later",function()
   gui.Parent=parent
   local early=button("Early")
   assert(not Click.started()and not Click.play("confirm"),"silent until started")
   Click.start(audio,gui)
   assert(Click.started()and early:GetAttribute(Click.Bound)==true,"existing buttons bind at once")
   local late=button("Late");local image=Instance.new("ImageButton");image.Name="LateImage";image.Parent=gui
   local nested=Instance.new("Frame");nested.Parent=gui;local deep=button("Deep",nested)
   settle()
   for _,b in ipairs({late,image,deep})do assert(b:GetAttribute(Click.Bound)==true,b.Name.." was not bound")end
   assert(gui:FindFirstChild("EggDropClickProbe"),"the Studio probe")
   local label=Instance.new("TextLabel");label.Parent=gui;settle();assert(label:GetAttribute(Click.Bound)==nil,"only buttons")
  end)
  test("one press, one sound; the owner's kind wins; disabled, hidden and 'none' are silent",function()
   local b=button("Plain");settle()
   table.clear(calls);task.wait(Click.Window+.02)
   assert(Click.press(b));assert(#calls==0,"queued, not played inside the handler");settle(3)
   assert(#calls==1 and calls[1][1]=="confirm","a plain press is one confirm, got "..#calls)
   assert(gui:GetAttribute(Click.Count)==1 and gui:GetAttribute(Click.Last)=="confirm"and gui:GetAttribute(Click.Heard)==1)
   -- A cue the audio does not play (muted, window in the background) is asked for, not heard.
   task.wait(Click.Window+.02);table.clear(calls)
   local mute=true;local real=audio.ui
   audio.ui=function(...)real(...);return not mute end
   assert(Click.press(b));settle(3)
   assert(#calls==1 and gui:GetAttribute(Click.Count)==2 and gui:GetAttribute(Click.Heard)==1,"asked, not heard")
   mute=false
   -- The press and the owner's own Wear in the same step: one sound, the equip.
   task.wait(Click.Window+.02);table.clear(calls)
   assert(Click.press(b)and Click.play("equip"));settle(3)
   assert(#calls==1 and calls[1][1]=="equip","owner kind wins: "..tostring(calls[1]and calls[1][1]).." x"..#calls)
   -- Owner first, press second (the other signal order): still the owner's kind.
   task.wait(Click.Window+.02);table.clear(calls)
   assert(Click.play("back")and Click.press(b));settle(3);assert(#calls==1 and calls[1][1]=="back")
   -- A second press inside the window is the same press.
   table.clear(calls);Click.press(b);settle(3);assert(#calls==0,"one sound per "..Click.Window.." s")
   task.wait(Click.Window+.02);table.clear(calls)
   local tab=button("Tab");tab:SetAttribute(Click.Kind,"tab");assert(Click.press(tab));settle(3);assert(calls[1][1]=="tab")
   task.wait(Click.Window+.02);table.clear(calls)
   local quiet=button("Quiet");quiet:SetAttribute(Click.Kind,"none")
   local off=button("Off");off.Interactable=false
   local inactive=button("Inactive");inactive.Active=false
   local hidden=button("Hidden");hidden.Visible=false
   for _,node in ipairs({quiet,off,inactive,hidden})do assert(not Click.press(node),node.Name.." clicked")end
   assert(not Click.press(nil)and not Click.press(gui)and not Click.play("hover"));settle(3);assert(#calls==0)
   -- Tokens are unique, so the audio's own one-token-one-cue rule never eats a click.
   local seen={}
   for _=1,3 do task.wait(Click.Window+.02);Click.press(b);settle(3)end
   for _,call in ipairs(calls)do assert(not seen[call[2]],"token reused");seen[call[2]]=true end
   assert(#calls==3)
  end)
  test("house parts name their kind: tabs play the tab cue, a header's Back plays back",function()
   local holder=Instance.new("Frame");holder.Size=UDim2.fromOffset(640,200);holder.Parent=gui
   local tabs=Kit.tabs(holder,{"One","Two"},300,44)
   for _,b in ipairs(tabs.buttons)do assert(b:GetAttribute(Click.Kind)=="tab",b.Name)end
   local header=Kit.header(holder,{title="T",width=600,onBack=function()end})
   local back
   for _,node in ipairs(header.root:GetDescendants())do if node:IsA("GuiButton")and node:GetAttribute(Click.Kind)=="back"then back=node end end
   assert(back,"the header's Back names its kind")
  end)

  -- 3. The walk, against the running game's helper.
  local probe=assert(parent:FindFirstChild("EggDropClickProbe"),"the game's click helper is not running (UIClick.start)")
  -- With the sound muted or Studio in the background the game's audio plays nothing; the
  -- walk then checks that every press asks for its cue, and says so in the result.
  local audible=probe:Invoke("audible")==true
  report.audible=if audible then 1 else 0
  test("walk: a freshly built machine hub and Companions screen are bound and click",function()
   walkGui.Parent=parent
   local Hub=require(client.MachineHub);local Companions=require(client.CompanionsHub)
   local Pets=require(game:GetService("ReplicatedStorage").Shared.PetCatalog)
   local built={}
   for _,size in ipairs({Vector2.new(1920,1080),Vector2.new(750,344)})do
    local host=Instance.new("Frame");host.BackgroundTransparency=1;host.Size=UDim2.fromOffset(size.X,size.Y);host.Parent=walkGui
    local hub=Hub.new(host,{open=function()return true end});hub:open({owned=1,wallet=20,state={}})
    table.insert(built,{name="machine hub "..tostring(size),root=host,close=function()hub:destroy()end})
    local host2=Instance.new("Frame");host2.BackgroundTransparency=1;host2.Size=UDim2.fromOffset(size.X,size.Y);host2.Parent=walkGui
    local companions=Companions.new(host2,{appearance=function()return{charmVisible=false}end,open=function()return true end,follow=function()return true end})
    companions:open({wallet=20,state={inventoryMask=127},activeId=Pets.collection[1].id})
    table.insert(built,{name="Companions "..tostring(size),root=host2,close=function()companions:close("spec")end,
     pets=function()companions:setPage("pets")end})
   end
   settle(3)
   local pressed=0
   local function audit(entry,label)
    local n=0
    for _,node in ipairs(entry.root:GetDescendants())do
     if node:IsA("GuiButton")then
      n+=1
      assert(node:GetAttribute(Click.Bound)==true,label..": "..node:GetFullName().." has no click")
      if Click.live(node.Interactable,node.Active,node.Visible)and Click.kindOf(node:GetAttribute(Click.Kind))then
       local asked,kind,heard=probe:Invoke("press",node)
       assert(asked==true,label..": "..node:GetFullName().." asked for no sound ("..tostring(kind)..")")
       assert(kind==Click.kindOf(node:GetAttribute(Click.Kind))or Click.Priority[kind],label..": "..node:GetFullName().." kind "..tostring(kind))
       if audible then assert(heard==true,label..": "..node:GetFullName().." made no sound ("..tostring(kind)..")")end
       pressed+=1
      end
     end
    end
    assert(n>0,label.." built no buttons")
    return n
   end
   for _,entry in ipairs(built)do
    report[entry.name]=audit(entry,entry.name)
    if entry.pets then
     -- The Pets row rebuilds the screen inside its own press: the page it builds is bound too.
     entry.pets();settle(3)
     report[entry.name.." Pets"]=audit(entry,entry.name.." Pets page")
    end
   end
   for _,entry in ipairs(built)do entry.close()end
   report.pressed=pressed
   assert(pressed>=20,"only "..pressed.." buttons pressed")
  end)
  test("walk: every button in the running game's menus has a click",function()
   local missing,total={},0
   local perGui={}
   for _,node in ipairs(parent:GetDescendants())do
    if node:IsA("GuiButton")and not node:IsDescendantOf(gui)then
     local top=node:FindFirstAncestorWhichIsA("LayerCollector")
     local name=top and top.Name or "?"
     -- Roblox's own guis (chat, the freecam) are not the game's menus.
     if name~="Chat"and name~="BubbleChat"and name~="Freecam"then
      total+=1;perGui[name]=(perGui[name]or 0)+1
      if node:GetAttribute(Click.Bound)~=true then table.insert(missing,node:GetFullName())end
     end
    end
   end
   assert(#missing==0,#missing.." button(s) with no click sound: "..table.concat(missing,", ",1,math.min(#missing,12)))
   -- The menus named in the note are all there to be walked.
   for _,name in ipairs({"EggDropMachineHub","EggDropCompanions","EggDropWardrobe","EggDropBook","EggDropDeck","EggDrop","EggDropOverlays"})do
    assert(parent:FindFirstChild(name),"missing gui "..name)
   end
   for name,count in pairs(perGui)do report["live "..name]=count end
   report.total=total
   assert(total>=50,"only "..total.." buttons walked")
  end)
 end,debug.traceback)
 gui:Destroy();walkGui:Destroy();fresh:Destroy()
 assert(ok,problem)
 local lines={}
 for name,count in pairs(report)do table.insert(lines,name.."="..count)end
 table.sort(lines)
 return{passed=#cases,cases=cases,buttons=table.concat(lines,"; ")}
end
