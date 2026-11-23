-- Studio Client. Kit.arrive and Kit.artPop (ALIVE-BUILD-PLAN-2026-11-22 step 2, revision 9; QA-R2-LOOK 1): the springy rise
-- on the four screens that rise today, exact rest after open / close spam, resize mid-rise, hide, destroy,
-- Reduced Motion and the switch; phones and slide-ins get none; art pops once, on art only.
-- Usage: require(PlayerScripts.Client.ZZSpecs.KitArrive)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Kit=require(client.DeckKit);local Spring=require(client.KitSpring);local Budget=require(client.AliveBudget)
 local Alive=require(game:GetService("ReplicatedStorage").Shared.Alive);local Machine=require(client.MachineHub);local Companions=require(client.CompanionsHub)
 local RunService=game:GetService("RunService")
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 -- A frame is drawn (springs step on RenderStepped) before each heartbeat returns; 1 s at most.
 local function settle(n)
  for _=1,n or 3 do
   local drawn=false;local once=RunService.RenderStepped:Once(function()drawn=true end);local began=os.clock()
   repeat RunService.Heartbeat:Wait()until drawn or os.clock()-began>1
   if not drawn then once:Disconnect()end
  end
 end
 parent=parent:FindFirstAncestorOfClass("PlayerGui")or parent -- the suite runner passes a ScreenGui; a gui inside a gui has no layout of its own
 local gui=Instance.new("ScreenGui");gui.Name="_KitArriveSpec";gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.IgnoreGuiInset=true;gui.ResetOnSpawn=false;gui.Parent=parent
 local saved={reduced=Kit.reduced,effects=Kit.reducedEffects,level=Budget.level}
 local attrs={};for _,f in ipairs(Alive.Features)do attrs[f]=workspace:GetAttribute(Alive.attribute(f))end
 local function flags(on)for _,f in ipairs(Alive.Features)do workspace:SetAttribute(Alive.attribute(f),on)end end
 local still=false
 Kit.reduced=function()return still end;Kit.reducedEffects=false
 local function run(seconds,each)for _=1,math.ceil(seconds*60)do Spring.step(1/60);if each then each()end end end
 local rest=UDim2.fromScale(.5,.5)
 local function host(w,h)
  local f=Instance.new("Frame");f.Name="Host";f.BackgroundTransparency=1;f.Size=UDim2.fromOffset(w,h);f.Parent=gui;return f
 end
 local function pops(root)local n=0;for _,d in ipairs(root:GetDescendants())do if d.Name=="PopScale"then n+=1 end end;return n end
 local ok,problem=xpcall(function()
  flags(true)
  -- QA-R2-LOOK 1: 28 px (22 on a phone screen) at 3.0 Hz, damping .42: about 6 px past home, then exact rest.
  local RISE=if Kit.phoneScreen()then Kit.Rise.phone else Kit.Rise.offset
  test("rise: from 28 px under to the exact rest, a visible step past it, Position only",function()
   local f=host(400,300);f.AnchorPoint=Vector2.new(.5,.5);f.Position=rest
   local size,visible,high=f.AbsoluteSize,f.Visible,0
   assert(Kit.arrive(f)==true and f.Position==UDim2.new(.5,0,.5,RISE)and Spring.busy(f,"Position"))
   run(2,function()high=math.min(high,f.Position.Y.Offset)end)
   assert(f.Position==rest and high<=-3 and high>=-9 and not Spring.busy(f),"overshoot "..high)
   assert(f.AbsoluteSize==size and f.Visible==visible and #f:GetChildren()==0);f:Destroy()
  end)
  test("the root scale rides the screen's fit UIScale: .90 of the fit to exactly the fit, never past 1.03; a re-fit wins; level 2 rises only",function()
   local f=host(400,300);f.AnchorPoint=Vector2.new(.5,.5);f.Position=rest
   local fit=Instance.new("UIScale");fit.Scale=.8;fit.Parent=f
   assert(Kit.arrive(f)==true and math.abs(fit.Scale-.72)<1e-3,"from .90 of the fit: "..fit.Scale)
   local top=0;run(2,function()top=math.max(top,fit.Scale)end)
   assert(math.abs(fit.Scale-.8)<1e-6 and top>.8 and top<=.8*1.03+1e-4,"top "..top)
   Kit.arrive(f);run(.05);fit.Scale=.7;run(2);assert(math.abs(fit.Scale-.7)<1e-6,"a re-fit mid-open wins")
   Kit.arrive(f);run(.05);Spring.settle(f);assert(math.abs(fit.Scale-.7)<1e-6,"cut short: the fit exactly")
   Budget.level=function()return 2 end;Kit.arrive(f);assert(math.abs(fit.Scale-.7)<1e-6,"level 2: the rise alone");Budget.level=saved.level
   run(2)
   -- Code review: twice before a step (a close and reopen in one frame) never takes the half-grown scale for the fit.
   Kit.arrive(f);Kit.arrive(f);run(.05);Kit.arrive(f);run(2);assert(math.abs(fit.Scale-.7)<1e-6,"the fit survives a re-arrive: "..fit.Scale)
   f:Destroy()
   -- A top-left anchored screen (QuestLog, DifficultyPicker content) would grow out of its corner: it rises only.
   local corner=host(400,300);corner.Position=UDim2.new()
   local cornerFit=Instance.new("UIScale");cornerFit.Scale=1;cornerFit.Parent=corner
   assert(Kit.arrive(corner,UDim2.new())==true and cornerFit.Scale==1 and not Spring.busy(cornerFit),"rise only")
   run(2);assert(corner.Position==UDim2.new());corner:Destroy()
  end)
  test("QA-R2 press: a Kit button's only GuiObject child is its Face; the PressScale shrinks the Face, never the button; live keeps today's tree",function()
   assert(Kit.FaceOn==true,"Studio is under the springs ceiling")
   local h=host(400,200)
   local b,s=Kit.button(h,"Go",{text="Go",variant="primary"})
   local kids={};for _,c in ipairs(b:GetChildren())do if c:IsA("GuiObject")then table.insert(kids,c.Name)end end
   assert(#kids==1 and kids[1]=="Face","children "..table.concat(kids,","))
   local face=b.Face
   assert(face.Active==false and face.Selectable==false and face.ZIndex==b.ZIndex and s.fill.Parent==face and s.content.Parent==face)
   assert(b:GetAttribute("AccessibleLabel")=="Go"and b:FindFirstChildOfClass("UIScale")==nil)
   s.pressed=true;Kit.paintButton(b);task.wait(.12)
   local scale=face:FindFirstChild("PressScale");assert(scale and math.abs(scale.Scale-.95)<.01,"down to .95")
   s.pressed=false;Kit.paintButton(b)
   local top=0;run(1,function()top=math.max(top,scale.Scale)end)
   assert(top>1 and top<=1.06+1e-6 and math.abs(scale.Scale-1)<1e-6,"springs back past 1, at most 1.06: "..top)
   assert(b.Size==UDim2.fromOffset(200,56)and b:FindFirstChildOfClass("UIScale")==nil,"the hit rect never moves")
   Kit.FaceOn=false
   local live=Kit.button(h,"Live",{text="Live"})
   Kit.FaceOn=true
   assert(live:FindFirstChild("Face")==nil and live:FindFirstChild("Fill")and live:FindFirstChild("Content")and live:FindFirstChild("Edge"),"live: today's tree")
   h:Destroy()
  end)
  test("off, Reduced Motion and Motion: Low: arrive does nothing at all and says so",function()
   local f=host(400,300);f.Position=rest
   for _,how in ipairs({{function()flags(false)end,function()flags(true)end},{function()flags(nil)end,function()flags(true)end},
    {function()still=true end,function()still=false end},{function()Kit.reducedEffects=true end,function()Kit.reducedEffects=false end}})do
    how[1]();assert(Kit.arrive(f)==false and f.Position==rest and not Spring.busy(f)and Kit.artPop({f})==0);how[2]()
   end
   f:Destroy()
  end)
  test("spam, a foreign write, hide, destroy, the switch and Reduced Motion mid-rise all end at rest",function()
   local f=host(400,300);f.Position=rest
   for _=1,50 do Kit.arrive(f);run(.02)end;run(2);assert(f.Position==rest)
   Kit.arrive(f);run(.05);f.Position=UDim2.fromOffset(0,60);settle();assert(f.Position==UDim2.fromOffset(0,60),"a phone layout wins at once")
   f.Position=rest
   for name,cut in pairs({hide=function()f.Visible=false end,switch=function()flags(false)end,reduced=function()still=true end,low=function()Kit.reducedEffects=true end})do
    Kit.arrive(f);run(.05);assert(f.Position~=rest,name);cut();settle(2);assert(f.Position==rest and not Spring.busy(f),name)
    f.Visible=true;flags(true);still=false;Kit.reducedEffects=false
   end
   Kit.arrive(f);run(.05);f:Destroy();settle(2);assert(f.Position==rest and not Spring.busy(f),"destroy")
  end)

  for _,on in ipairs({true,false})do
   local tag=if on then " [on]"else " [off]"
   for _,def in ipairs({{name="MachineHub",make=function(h,log)return Machine.new(h,{closed=function(r)table.insert(log,r)end})end},
    {name="CompanionsHub",make=function(h,log)return Companions.new(h,{appearance=function()return{}end,closed=function(r)table.insert(log,r)end})end}})do
    test(def.name..": state on frame one, one screen, exact rest after open / close / open and a resize mid-rise"..tag,function()
     flags(on)
     local log={};local h=host(1280,720);local hub=def.make(h,log);local ctx={owned=1,wallet=5,state={inventoryMask=1},activeId="pip"}
     local depth=Kit.shadeDepth()
     hub:open(ctx);assert(hub:isOpen()and hub.root.Visible and hub.shade.Visible and Kit.shadeDepth()==depth+1 and Kit.shadeTop()==hub,"open on frame one")
     assert(Spring.busy(hub.root,"Position")==on and hub.root.Position.Y.Offset==(if on then RISE else 8))
     hub:close("back");assert(not hub.root.Visible and not hub.shade.Visible and Kit.shadeDepth()==depth and log[1]=="back")
     hub:open(ctx);task.wait(.02);hub:close("forced");hub:open(ctx);assert(#log==2 and log[2]=="forced"and Kit.shadeDepth()==depth+1)
     task.wait(.3);run(2);assert(hub.root.Position==rest,"rest "..tostring(hub.root.Position))
     -- Resize to a phone mid-rise, and back.
     hub:close("x");hub:open(ctx);task.wait(.03);h.Size=UDim2.fromOffset(812,354);settle()
     -- (Today's tween keeps pulling the phone layout until it lands; the spring gives way at once.)
     local phone=hub.root.Position;assert(hub.view~=nil);task.wait(.3);run(1)
     if on then assert(phone.X.Scale==0 and phone.Y.Scale==0 and hub.root.Position==phone,"the phone layout is not pulled back")end
     hub:close("x");hub:open(ctx);local at=hub.root.Position;assert(not Spring.busy(hub.root)and at.Y.Scale==0,"phones never rise");settle();assert(hub.root.Position==at and pops(hub.root)==0)
     h.Size=UDim2.fromOffset(1280,720);settle();assert(hub.view==nil and hub.root.Position==rest)
     -- Back from a child slides instead.
     hub:close("x");hub:open(ctx,{slideFrom=-Kit.SlideOffset});assert(hub.root.Position==rest and not Spring.busy(hub.root)and pops(hub.root)==0)
     hub:destroy();h:Destroy();assert(Kit.shadeDepth()==depth)
    end)
    test(def.name..": discs pop once, with the rise, and end where they were"..tag,function()
     flags(on)
     local h=host(1280,720);local hub=def.make(h,{});local ctx={owned=1,wallet=5,state={inventoryMask=1},activeId="pip"}
     hub:open(ctx)
     local entries=if def.name=="MachineHub"then hub.tileViews else hub.rows
     assert(pops(hub.root)==(if on then #entries else 0),"pops "..pops(hub.root))
     local key=entries[1].button
     assert(key.Interactable and key.Visible and key:FindFirstChildOfClass("UIScale")==nil,"the key itself never scales or hides")
     run(.56);assert(pops(hub.root)==0,"all done by .55 s")
     for _,e in ipairs(entries)do assert(e.disc:FindFirstChildOfClass("UIScale")==nil)end
     local home=entries[2].disc.Position;run(1);assert(entries[2].disc.Position==home)
     hub:setContext(ctx);hub:move(1,0);assert(pops(hub.root)==0,"no replay on a refresh or a focus move")
     h.Size=UDim2.fromOffset(1400,800);settle();assert(pops(hub.root)==0,"nor on a resize")
     hub:close("x");hub:open(ctx);run(.1);hub:close("x");settle(2);assert(pops(hub.root)==0,"cut on close")
     hub:destroy();h:Destroy()
    end)
   end
  end
  flags(true)
  test("artPop: art only (no text, viewport, scroller, canvas group, list child or scaled art), the first eight shown, none at level 2",function()
   local box=host(600,400)
   local function art(props,class)
    local f=Instance.new(class or "Frame");f.Size=UDim2.fromOffset(40,40);f.Position=UDim2.fromOffset(10,20);f.Parent=box
    for k,v in pairs(props or {})do f[k]=v end;return f
   end
   local function holding(class)local f=art();Instance.new(class).Parent=f;return f end
   local list=host(100,100);Instance.new("UIListLayout").Parent=list;local row=art();row.Parent=list
   for _,bad in ipairs({art(nil,"TextLabel"),art(nil,"TextButton"),art(nil,"ViewportFrame"),art(nil,"ScrollingFrame"),art(nil,"CanvasGroup"),holding("TextLabel"),
    holding("ViewportFrame"),holding("ScrollingFrame"),holding("CanvasGroup"),holding("UIScale"),row,art({Visible=false})})do
    assert(Kit.artPop({bad})==0,bad.ClassName.." "..tostring(bad.Visible))
   end
   local many={};for i=1,12 do many[i]=art()end
   assert(Kit.artPop(many)==8 and many[8]:FindFirstChild("PopScale")and not many[9]:FindFirstChild("PopScale"))
   assert(math.abs(many[8].PopScale.Scale-.70)<1e-4 and many[1].Position==UDim2.fromOffset(16,26),"from .70 about its centre")
   assert(Kit.artPop(many)==4,"art already popping is left alone")
   run(.56);for _,f in ipairs(many)do assert(not f:FindFirstChild("PopScale")and f.Position==UDim2.fromOffset(10,20))end
   local moved=art();Kit.artPop({moved});run(.05);moved.Position=UDim2.fromOffset(99,99);run(.6);assert(moved.Position==UDim2.fromOffset(99,99)and not moved:FindFirstChild("PopScale"))
   for _,cut in ipairs({function()flags(false)end,function()still=true end,function()box.Visible=false end})do
    local f=art();assert(Kit.artPop({f})==1);run(.05);cut();settle(2);assert(not f:FindFirstChild("PopScale")and f.Position==UDim2.fromOffset(10,20))
    flags(true);still=false;box.Visible=true
   end
   Budget.level=function()return 2 end;assert(Kit.artPop({art()})==0);Budget.level=saved.level
   assert(Kit.artPop(nil)==0,"nothing to pop");box:Destroy();list:Destroy()
  end)
 end,function(e)return debug.traceback(tostring(e),2)end)
 Kit.reduced,Kit.reducedEffects,Budget.level=saved.reduced,saved.effects,saved.level
 Spring.settle(gui);gui:Destroy()
 for _,f in ipairs(Alive.Features)do workspace:SetAttribute(Alive.attribute(f),attrs[f])end
 assert(ok,problem)
 return{passed=#cases,cases=cases}
end
