-- Run with the game viewport foreground: live WindowFocusReleased ownership is retained.
-- A window=false failure diagnostic requires restoring foreground and rerunning this fixture.
-- Real LocalScript client host. Gesture fixtures use a deterministic clock and fake callbacks,
-- not synthetic native input; root separately verifies mouse/touch/Gamepad1 and actual sound.
return function(client,parent)
 local Focus=require(client.PetFocusUI);local Room=require(client.RoomView);local Notice=require(client.SaveNotice)
 local Gui=game:GetService("GuiService");local Players=game:GetService("Players");local previous=Gui.SelectedObject
 local cases,uis,visuals={}, {},{};local host=Instance.new("ScreenGui");host.Name="_DirectPetting";host.Parent=Players.LocalPlayer.PlayerGui
 local folder=Instance.new("Folder");folder.Name="_DirectPettingModels";folder.Parent=workspace
 local function test(name,run)run();table.insert(cases,name)end
 local function touch(x,y)return{UserInputType=Enum.UserInputType.Touch,Position=Vector3.new(x+12,y+8,0)}end
 local function gesture()
  local t,own,accept=0,true,true;local count={tap=0,rub=0,start=0,stop=0}
  local f=setmetatable({active=true,root={AbsolutePosition=Vector2.new(12,8)},hit={Position=UDim2.fromOffset(40,40),Size=UDim2.fromOffset(200,100)},glove={},helper={Visible=false},back={Visible=false},
   clock=function()return t end,canOwnInput=function()return own end,callbacks={canReact=function()return own end,greet=function()count.tap+=1;return accept end,pet=function()count.rub+=1;return accept end,
    petContact=function(active)if active then count.start+=1 else count.stop+=1 end;return false end}},Focus)
  return f,count,function(dt)t+=dt end,function(value)own=value end,function(value)accept=value end
 end
 local function rub(f,input)local moved=touch(85,80);f:movePointer(moved,false);return moved end
 local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
 local ok,problem=pcall(function()
  test("press records candidate and release emits exactly one accepted tap",function()
   local f,c,advance=gesture();local i=touch(70,80);assert(f:beginPointer(i));assert(c.tap==0 and c.rub==0 and c.start==0)
   advance(.1);f:endPointer(i);f:endPointer(i);assert(c.tap==1 and c.rub==0 and c.start==0 and not f.pointer and f.focusLessonRetired)
   assert(f.glove.Position==UDim2.fromOffset(70,80),"safe inset applied twice")
  end)
  test("cumulative9px begins one rub with no release tap or repeated cue",function()
   local f,c,advance=gesture();local i=touch(70,80);f:beginPointer(i)
   for _,x in ipairs({73,76,79})do advance(.02);f:movePointer(touch(x,80),false)end
   assert(c.rub==1 and c.start==1 and c.tap==0)
   for n=1,30 do advance(.05);f:movePointer(touch(if n%2==0 then 100 else 80,80),false)end
   f:endPointer(i);assert(c.rub==1 and c.start==1 and c.stop==1 and c.tap==0)
  end)
  test("one inactivity deadline stops and held motion cannot resurrect contact",function()
   local f,c,advance=gesture();local i=touch(70,80);f:beginPointer(i);rub(f,i);assert(c.start==1)
   advance(.23);assert(not f:checkContactDeadline());advance(.02);assert(f:checkContactDeadline());assert(c.stop==1 and not f.pointer)
   f:movePointer(touch(100,80),false);f:endPointer(i);assert(c.start==1 and c.tap==0)
   local fresh=touch(70,80);f:beginPointer(fresh);rub(f,fresh);assert(c.start==2);f:cancelPointer();assert(c.stop==2)
  end)
  test("coalesced release motion is consumed without tap or purr onset",function()
   local f,c=gesture();local i=touch(70,80);f:beginPointer(i);i.Position=touch(90,80).Position;f:endPointer(i);assert(c.tap==0 and c.rub==0 and c.start==0 and not f.pointer)
  end)
  test("canceled short release is cleanup and never a tap",function()
   local f,c=gesture();local i=touch(70,80);f:beginPointer(i);i.UserInputState=Enum.UserInputState.Cancel;f:endPointer(i);assert(c.tap==0 and c.rub==0 and c.start==0 and not f.pointer)
  end)
  test("blur clears stale opener leases without resurrecting held contact",function()
   local f,c=gesture();local i=touch(70,80);f:beginPointer(i);rub(f,i);f.heldTouches={[i]=true};f.openingMouse=true;f.openingTouches={[i]=true};f.openingADevice=Enum.UserInputType.Gamepad1
   f:loseWindowFocus();assert(not f.pointer and not f.openingMouse and not f.openingADevice and next(f.heldTouches)==nil and c.stop==1)
   local mouse={UserInputType=Enum.UserInputType.MouseButton1,Position=touch(70,80).Position};assert(not f:beginPointer(mouse));f:gainWindowFocus();assert(f:beginPointer(mouse));f:cancelPointer();assert(c.start==1)
  end)
  test("a stationary long hold does not become tap or rub",function()
   local f,c,advance=gesture();local i=touch(70,80);f:beginPointer(i);advance(1);f:endPointer(i);assert(c.tap==0 and c.rub==0 and c.start==0)
  end)
  test("same held touch cannot begin again when GuiObject reentry repeats InputBegan",function()
   local f,c=gesture();local i=touch(70,80);assert(f:beginPointer(i));rub(f,i);f:movePointer(touch(400,80),false)
   i.Position=touch(100,80).Position
   for _=1,6 do assert(not f:beginPointer(i));f:movePointer(i,false)end
   assert(c.start==1 and c.stop==1 and c.tap==0 and not f.pointer and f.retiredTouches[i])
   local foreign=touch(90,80);f:endPointer(foreign);assert(not f:beginPointer(i)and f.retiredTouches[i])
   f:endPointer(i);assert(not f.retiredTouches[i]);local fresh=touch(70,80);assert(f:beginPointer(fresh));f:endPointer(fresh)
   assert(c.start==1 and c.stop==1 and c.tap==1)
  end)
  test("retired touch never overwrites or ends a different active finger",function()
   local f,c=gesture();local a,b=touch(70,80),touch(70,80)
   f:beginPointer(a);rub(f,a);f:movePointer(touch(400,80),false);assert(f.retiredTouches[a])
   assert(f:beginPointer(b));rub(f,b);assert(c.start==2 and f.pointer==b)
   assert(not f:beginPointer(a));f:endPointer(a);assert(f.pointer==b and c.stop==1)
   f:endPointer(b);assert(c.stop==2 and c.tap==0 and not f.pointer)
  end)
  test("mouse primary stays retired across reentry and unrelated touch until button release",function()
   local f,c=gesture();local a={UserInputType=Enum.UserInputType.MouseButton1,Position=touch(70,80).Position}
   f:beginPointer(a);f:movePointer({UserInputType=Enum.UserInputType.MouseMovement,Position=touch(90,80).Position},false)
   f:movePointer({UserInputType=Enum.UserInputType.MouseMovement,Position=touch(400,80).Position},false)
   local repeatBegin={UserInputType=Enum.UserInputType.MouseButton1,Position=touch(100,80).Position}
   assert(f.retiredMouse and not f:beginPointer(repeatBegin));f:endPointer(touch(100,80));assert(not f:beginPointer(repeatBegin))
   f:endPointer(a);assert(not f.retiredMouse and f:beginPointer(repeatBegin));f:endPointer(repeatBegin)
   assert(c.start==1 and c.stop==1 and c.tap==1)
  end)
  test("touch retirement survives blur and reframe until its matching physical end or cancel",function()
   for _,cancel in ipairs({false,true})do
    local f,c=gesture();local a=touch(70,80);f:beginPointer(a);rub(f,a);f:loseWindowFocus();f:gainWindowFocus()
    assert(not f:beginPointer(a)and f.retiredTouches[a]);f:cancelPointer();assert(f.retiredTouches[a])
    if cancel then a.UserInputState=Enum.UserInputState.Cancel end
    f:endPointer(a);assert(not f.retiredTouches[a]);assert(f:beginPointer(touch(70,80)));f:cancelPointer()
    assert(c.start==1 and c.stop==1 and c.tap==0)
   end
  end)
  test("unrelated pointer cannot adopt or end an owned touch",function()
   local f,c=gesture();local a,b=touch(70,80),touch(90,80);f:beginPointer(a);assert(not f:beginPointer(b)and not f:pointerMatches(b));f:endPointer(b);assert(f.pointer==a and c.tap==0);f:endPointer(a);assert(c.tap==1)
  end)
  test("rejected rub never starts purr or synthesizes release tap",function()
   local f,c,_,_,accept=gesture();accept(false);local i=touch(70,80);f:beginPointer(i);rub(f,i);f:endPointer(i);assert(c.rub==1 and c.start==0 and c.tap==0)
  end)
  test("failed or muted purr attempt remains consumed through the same held gesture",function()
   local f,c,advance=gesture();local i=touch(70,80);f:beginPointer(i);rub(f,i)
   for _=1,10 do advance(.05);f:movePointer(touch(95,80),false)end
   assert(c.start==1 and c.rub==1);f:cancelPointer();f:cancelPointer();assert(c.stop==1)
  end)
  test("opening touch and mouse are drained before a fresh press",function()
   local f,c=gesture();local i=touch(70,80);f.openingTouches={[i]=true};assert(not f:beginPointer(i));f:endPointer(i);assert(c.tap==0)
   assert(f:beginPointer(touch(70,80)));f:cancelPointer()
   local mouse={UserInputType=Enum.UserInputType.MouseButton1,Position=i.Position};f.openingMouse=true;assert(not f:beginPointer(mouse));f:endPointer(mouse);assert(f:beginPointer(mouse));f:cancelPointer();assert(c.start==0)
  end)
  test("modal/native ownership loss cancels contact before another reaction",function()
   local f,c,_,own=gesture();local i=touch(70,80);f:beginPointer(i);rub(f,i);own(false);f:movePointer(touch(95,80),false);f:endPointer(i)
   assert(c.start==1 and c.stop==1 and c.tap==0 and not f.pointer and not f:beginPointer(i))
  end)
  local root=Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart");assert(root and workspace.CurrentCamera)
  local function room()
   local events={start=0,stop=0,cue=0,greet=0}
   local r=setmetatable({focusing=true,mode="Room",pet={greet=function()events.greet+=1 end},shownPet={cue="pet"},
    greetingCamera={root=root,camera=workspace.CurrentCamera},overlayOpen=function()return false end,reduceEffects=function()return true end,
    audio={setPurr=function(_,active)if active then events.start+=1 else events.stop+=1 end;return false end,play=function()events.cue+=1 end}},Room)
   return r,events
  end
  test("Room contact owns one voice attempt and one held grin without state writes",function()
   local r,c=room();local shot=r.greetingCamera;assert(r:setPetContact(true));assert(r.pet.petting and r.petContactActive and c.start==1)
   r:setPetContact(true);assert(c.start==1);r:setPetContact(false);r:setPetContact(false);assert(not r.pet.petting and c.stop==1 and r.greetingCamera==shot)
   r.focusUI={contactValid=function()return true end};r.removingCharacter=Players.LocalPlayer.Character
   assert(not r:setPetContact(true)and c.start==1)
   r.removingCharacter=nil;assert(r:setPetContact(true));r.removingCharacter=Players.LocalPlayer.Character
   assert(not r:contactEligible(r.contactContext));r:updatePetContact(.1)
   assert(not r.petContactActive and not r.pet.petting and c.stop==2 and r.greetingCamera==shot)
   r.removingCharacter=nil;r.focusUI.windowActive=false;assert(not r:setPetContact(true)and not r:reactPet(false)and c.start==2)
   r.focusUI.windowActive=true;assert(r:setPetContact(true)and c.start==3);r:setPetContact(false)
  end)
  test("reduced rub grants static affection without species audio or camera recapture",function()
   local r,c=room();local shot=r.greetingCamera;assert(r:reactPet(true));assert(r.pet.affection>0 and c.cue==0 and c.greet==0 and r.greetingCamera==shot)
   r.lastReactionAt=-math.huge;assert(r:reactPet(false));assert(c.cue==1 and c.greet==0)
   r.greetingCamera.root={};assert(not r:setPetContact(true)and c.start==0)
  end)
  local function ui()
   local count={back=0,greet=0};local v=Focus.new(host,{back=function()count.back+=1 end,greet=function()count.greet+=1;return true end,pet=function()return true end,petContact=function()end,canReact=function()return true end,canOwnInput=function()return true end})
   table.insert(uis,v);return v,count
  end
  test("only Back is selected and carried A drains before fresh native activation",function()
   local v,c=ui();v:setActive(true);Gui.SelectedObject=v.back;settle();assert(not v.greet and not v.panel:FindFirstChild("Greet")and v.back.AbsoluteSize.Y>=44)
   local input={KeyCode=Enum.KeyCode.ButtonA,UserInputType=Enum.UserInputType.Gamepad1};v.openingADevice=input.UserInputType
   assert(v:handleMove(Enum.UserInputState.Begin,input)==Enum.ContextActionResult.Sink)
   assert(v:handleMove(Enum.UserInputState.End,input)==Enum.ContextActionResult.Sink and not v.openingADevice)
   assert(v:handleMove(Enum.UserInputState.Begin,input)==Enum.ContextActionResult.Pass and c.back==0)
   assert(v:handleGreet(Enum.UserInputState.Begin)==Enum.ContextActionResult.Sink and c.greet==1)
   assert(v:handleBack(Enum.UserInputState.Begin)==Enum.ContextActionResult.Sink and c.back==1);v:setActive(false)
  end)
  test("first shown lesson retires on exit and save recovery never resurrects it",function()
   local v=ui();v.root.Size=UDim2.fromOffset(733,307);settle()
   local m=Instance.new("Model");local body=Instance.new("Part");body.Size=Vector3.new(2,2,2);body.Anchored=true;body.Parent=m;m.Parent=folder
   local camera={WorldToScreenPoint=function(_,p)return Vector3.new(v.root.AbsolutePosition.X+350+p.X*20,v.root.AbsolutePosition.Y+150-p.Y*20,20+p.Z)end}
   v:setActive(true);v:update(camera,{model=m},false);assert(v.helper.Visible and v.focusLessonStarted);v:setActive(false);v:setActive(true);v:update(camera,{model=m},false);assert(not v.helper.Visible)
   v:setSaveNotice(Notice.resolve("Retrying",{status="Ready"}));v:update(camera,{model=m},false);settle();assert(v.helper.Visible and v.helper.Text:find("retry",1,true)and v.helper.TextFits)
   v:setSaveNotice(nil);v:update(camera,{model=m},false);assert(not v.helper.Visible)
   v:retireRoamHint();v:setActive(false);v:update(nil,nil,true);assert(not v.hint.Visible)
   v:setSaveNotice(Notice.resolve("Temporary",{status="Ready"}));v:update(nil,nil,true)
   local context=string.format("active=%s window=%s owns=%s core=%s textbox=%s notice=%s retired=%s hint=%q gui=%s",tostring(v.active),tostring(v.windowActive),tostring(v:canOwnInput()),tostring(Gui.MenuIsOpen),tostring(game:GetService("UserInputService"):GetFocusedTextBox()),tostring(v.saveNotice and v.saveNotice.short),tostring(v.roamHintRetired),v.hint.Text,tostring(v.gui.Enabled))
   assert(v.hint.Visible,"passive Temporary notice hidden: "..context)
   v:setSaveNotice(nil);v:update(nil,nil,true);assert(not v.hint.Visible,"retired roam hint resurrected: "..context);m:Destroy()
  end)
  test("projected small pet retains44px target without including crest or floor FX",function()
   local m=Instance.new("Model");local body=Instance.new("Part");body.Size=Vector3.new(.1,.1,.1);body.Parent=m;m.Parent=folder
   local camera={WorldToScreenPoint=function(_,p)return Vector3.new(200+p.X,100+p.Y,20)end}
   local p,s=Focus.projectBounds(camera,m,{AbsolutePosition=Vector2.zero,AbsoluteSize=Vector2.new(400,250)});assert(p and s.X>=44 and s.Y>=44);m:Destroy()
  end)
  test("all seven muted reduced faces hold a readable grin with no body movement",function()
   local Pets=require(game.ReplicatedStorage.Shared.PetCatalog)
   for _,pet in ipairs(Pets.collection)do local family=pet.family or pet.id;local module=if family=="pip"then client.PipVisual elseif family=="puddle"then client.PuddleVisual else client.BonusPetVisual
    local v=require(module).new(folder,Vector3.new(2000,4,0),pet,.72);table.insert(visuals,v);v.reducedEffects=true;v:update(2)
    local mouth=v.model:FindFirstChild("Smile")or v.model.Mouth;local width=mouth.Size.X;local frame=v.model.PrimaryPart.CFrame
    v.affection=.9;v:update(0);assert(mouth.Size.X>width and v.model.PrimaryPart.CFrame==frame,pet.id.." reduced grin missing")
    v.petting=true;v:update(2);assert(mouth.Size.X>width and v.model.PrimaryPart.CFrame==frame);v.petting=false;v:update(0);assert(math.abs(mouth.Size.X-width)<.0001);v:destroy()
   end
  end)
 end)
 Gui.SelectedObject=nil;for _,v in ipairs(uis)do v:destroy()end;for _,v in ipairs(visuals)do v:destroy()end;host:Destroy();folder:Destroy()
 if require(client.ControllerFocus).live(previous,nil,Players.LocalPlayer.PlayerGui,true)then Gui.SelectedObject=previous end
 assert(ok,problem);return{passed=#cases,cases=cases}
end
