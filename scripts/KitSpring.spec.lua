-- Studio Client. KitSpring and the presses on it (ALIVE-BUILD-PLAN-2026-11-22 step 1): exact rest after spam,
-- interruption, foreign writes, destroy, hide, Reduced Motion and the switch going off; done once; caps;
-- Kit.tween and springs hand over; buttons, tiles, toggle, tabs, boing and the wallet Star, flags on and off.
-- Usage: require(PlayerScripts.Client.ZZSpecs.KitSpring)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Kit=require(client.DeckKit);local Spring=require(client.KitSpring);local Alive=require(game:GetService("ReplicatedStorage").Shared.Alive)
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
 local screen=Instance.new("ScreenGui");screen.Name="_KitSpringSpec";screen.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;screen.ResetOnSpawn=false;screen.Parent=parent
 local gui=Instance.new("Frame");gui.Size=UDim2.fromOffset(900,600);gui.BackgroundTransparency=1;gui.Parent=screen
 local saved={reduced=Kit.reduced,effects=Kit.reducedEffects,springReduced=Spring.reduced,cap=Spring.cap,instant=Spring.Instant,bounce=Kit.Motion.bounce}
 local attrs={};for _,f in ipairs(Alive.Features)do attrs[f]=workspace:GetAttribute(Alive.attribute(f))end
 local function flag(feature,on)workspace:SetAttribute(Alive.attribute(feature),on)end
 local function flags(on)for _,f in ipairs(Alive.Features)do flag(f,on)end end
 local still=false
 Kit.reduced=function()return still end;Kit.reducedEffects=false
 local function frame(props)
  local f=Instance.new("Frame");f.Size=UDim2.fromOffset(100,50)
  for k,v in pairs(props or {})do f[k]=v end
  f.Parent=gui;return f
 end
 -- Deterministic: steps every live spring without yielding.
 local function run(seconds,each)
  for _=1,math.ceil(seconds*60)do Spring.step(1/60);if each then each()end end
 end
 local function spy()local s={count=0};function s.done(reason)s.count+=1;s.reason=reason end;return s end
 local ok,problem=xpcall(function()
  flags(true)
  test("number, Vector2, UDim and UDim2 overshoot, rest exactly on the goal and leave nothing live; done once",function()
   local f=frame();local corner=Instance.new("UICorner");corner.Parent=f
   local list={{f,"BackgroundTransparency",.35},{f,"AnchorPoint",Vector2.new(.5,.25)},{corner,"CornerRadius",UDim.new(0,17)},{f,"Position",UDim2.new(.1,33,.7,-41)}}
   for _,e in ipairs(list)do
    local s=spy();Spring.to(e[1],e[2],e[3],{frequency=4,damping=.4,done=s.done})
    assert(Spring.busy(e[1],e[2])and s.count==0,e[2])
    run(2.5);assert(e[1][e[2]]==e[3]or(e[2]=="BackgroundTransparency"and math.abs(f.BackgroundTransparency-.35)<1e-6),e[2].." rest")
    assert(not Spring.busy(e[1])and s.count==1 and s.reason=="rest",e[2].." "..tostring(s.reason))
   end
   local over=0
   f.Position=UDim2.new();Spring.to(f,"Position",UDim2.fromOffset(100,0),{damping=.4})
   run(2,function()over=math.max(over,f.Position.X.Offset)end);assert(over>105 and f.Position==UDim2.fromOffset(100,0),"overshoots, then rests")
   f:Destroy()
  end)
  test("damping 1 and bounce 0 never overshoot; a huge frame is capped",function()
   local f=frame();local most=0
   Spring.to(f,"Position",UDim2.fromOffset(100,0),{damping=1});run(2.5,function()most=math.max(most,f.Position.X.Offset)end)
   assert(most==100 and f.Position==UDim2.fromOffset(100,0))
   Kit.Motion.bounce=0;f.Position=UDim2.new();most=0
   Kit.spring(f,"Position",UDim2.fromOffset(100,0),{damping=.2});run(2.5,function()most=math.max(most,f.Position.X.Offset)end)
   Kit.Motion.bounce=saved.bounce;assert(most==100)
   f.Position=UDim2.new();Spring.to(f,"Position",UDim2.fromOffset(100,0),{frequency=1,damping=1})
   Spring.step(30);local x=f.Position.X.Offset;assert(x<30,"one 30 s hitch moves 1/20 s: "..x)
   Spring.settle(f);assert(f.Position==UDim2.fromOffset(100,0));f:Destroy()
  end)
  test("retarget keeps speed; 100 retargets end on the last goal with one done each",function()
   local f=frame();Spring.to(f,"Position",UDim2.fromOffset(300,0),{damping=.8});run(.06)
   local at=f.Position.X.Offset;Spring.to(f,"Position",UDim2.fromOffset(0,0),{damping=.8});Spring.step(1/120)
   assert(f.Position.X.Offset>=at,"still travelling forward")
   local total=0
   for i=1,100 do
    Spring.to(f,"Position",UDim2.fromOffset(if i%2==0 then 10 else 200,i),{damping=.4,done=function()total+=1 end})
    if i%3==0 then Spring.step(1/60)end
   end
   run(2.5);assert(f.Position==UDim2.fromOffset(10,100)and total==100 and not Spring.busy(f),"done "..total);f:Destroy()
  end)
  test("a foreign write cancels and stays; float32 scales and whole pixels are not foreign",function()
   local f=frame();local s=spy()
   Spring.to(f,"Position",UDim2.new(.1,7,.3,9),{done=s.done});run(.1);assert(Spring.busy(f,"Position"))
   f.Position=UDim2.fromOffset(5,5);Spring.step(1/60)
   assert(f.Position==UDim2.fromOffset(5,5)and s.reason=="foreign"and s.count==1 and not Spring.busy(f))
   Spring.to(f,"Position",UDim2.fromOffset(90,0),{damping=1});run(.1);f.Position=UDim2.fromOffset(400,0)
   Spring.to(f,"Position",UDim2.fromOffset(500,0),{damping=1});Spring.step(1/60)
   local x=f.Position.X.Offset;assert(x>=400 and x<440,"adopted at rest: "..x)
   f.Position=UDim2.fromOffset(1,2);assert(Spring.settle(f)==1 and f.Position==UDim2.fromOffset(1,2),"settle respects it too");f:Destroy()
  end)
  test("destroyed, unparented, hidden, in a hidden ancestor or a disabled gui: goal at once, dropped",function()
   local inner=Instance.new("ScreenGui");inner.Parent=parent
   local cut={
    destroy=function(f)f:Destroy()end,unparent=function(f)f.Parent=nil end,hide=function(f)f.Visible=false end,
    ancestor=function(f)f.Parent.Visible=false end,gui=function()inner.Enabled=false end}
   for name,fn in pairs(cut)do
    inner.Enabled=true
    local box=Instance.new("Frame");box.Parent=inner;local f=Instance.new("Frame");f.Parent=box
    local s=spy();Spring.to(f,"Position",UDim2.fromOffset(80,3),{damping=.4,done=s.done});run(.1);assert(Spring.busy(f),name)
    fn(f);Spring.step(1/60)
    assert(not Spring.busy(f)and f.Position==UDim2.fromOffset(80,3)and s.count==1 and(s.reason=="drop"or s.reason=="settle"),name.." "..tostring(s.reason))
    box:Destroy()
   end
   local loose=Instance.new("Frame");local s=spy()
   Spring.to(loose,"Position",UDim2.fromOffset(9,9),{done=s.done});assert(loose.Position==UDim2.fromOffset(9,9)and s.reason=="snap"and not Spring.busy(loose))
   loose:Destroy();inner:Destroy()
  end)
  test("Reduced Motion (also Motion: Low) and the switch going off mid-flight snap within a frame, from a real frame too",function()
   for _,how in ipairs({{function()still=true end,function()still=false end},{function()Kit.reducedEffects=true end,function()Kit.reducedEffects=false end},
    {function()flag("springs",false)end,function()flag("springs",true)end},{function()flag("springs",nil)end,function()flag("springs",true)end}})do
    local f=frame();local s=spy();Spring.to(f,"Position",UDim2.fromOffset(60,0),{damping=.4,done=s.done});run(.05);assert(Spring.busy(f))
    how[1]();RunService.RenderStepped:Wait();settle(1)
    assert(f.Position==UDim2.fromOffset(60,0)and s.reason=="snap"and s.count==1 and not Spring.busy(f))
    Spring.to(f,"Position",UDim2.fromOffset(5,0));assert(f.Position==UDim2.fromOffset(5,0)and not Spring.busy(f),"snaps while off")
    how[2]();f:Destroy()
   end
   flag("menus",false);local f=frame();Spring.to(f,"Position",UDim2.fromOffset(60,0),{feature="menus"});assert(f.Position==UDim2.fromOffset(60,0))
   Spring.to(f,"Position",UDim2.fromOffset(0,0));assert(Spring.busy(f),"each feature has its own switch");flag("menus",true);f:Destroy()
   Spring.Instant=true;local g=frame();Spring.to(g,"Position",UDim2.fromOffset(60,0));assert(g.Position==UDim2.fromOffset(60,0)and not Spring.busy(g));Spring.Instant=false;g:Destroy()
  end)
  test("cap: the extra ones snap; settle(root) takes only what is under it; cancel leaves it where it stands",function()
   Spring.settle();Spring.cap=function()return 3 end
   local list={};for i=1,5 do list[i]=frame();Spring.to(list[i],"Position",UDim2.fromOffset(50,0))end
   assert(Spring.count()==3 and not Spring.busy(list[4])and list[5].Position==UDim2.fromOffset(50,0))
   Spring.to(list[1],"Position",UDim2.fromOffset(70,0));assert(Spring.count()==3 and Spring.busy(list[1]),"a retarget keeps its place")
   Spring.cap=saved.cap;run(.05)
   local s=spy();Spring.settle(list[1]);assert(list[1].Position==UDim2.fromOffset(70,0)and Spring.busy(list[2])and Spring.count()==2)
   Spring.to(list[2],"Position",UDim2.fromOffset(80,0),{done=s.done});local at=list[2].Position
   assert(Spring.cancel(list[2],"Position")and list[2].Position==at and s.reason=="cancel"and s.count==1 and not Spring.cancel(list[2],"Position"))
   Spring.settle(gui);assert(Spring.count()==0);for _,f in ipairs(list)do f:Destroy()end
   assert(Spring.cap()==24 or Spring.cap()==48)
  end)
  test("delay, limit, get / set / mark, and a done or set that throws hurts nothing else",function()
   local f=frame();local value,reads=0,0
   Spring.to(f,"Virtual",10,{delay=.1,epsilon=.1,get=function()reads+=1;return value end,set=function(v)value=v end});Spring.step(1/60);assert(value==0 and reads>0)
   run(2);assert(value==10)
   Spring.to(f,"Position",UDim2.fromOffset(60,0),{frequency=.1,limit=.2});run(.25);assert(f.Position==UDim2.fromOffset(60,0)and not Spring.busy(f))
   local g=frame();local calls=0
   Spring.to(f,"Broken",1,{get=function()return 0 end,set=function()calls+=1;if calls>1 then error("spec: set throws")end end})
   Spring.to(g,"Position",UDim2.fromOffset(60,0),{damping=.4,done=function()error("spec: done throws")end})
   run(2.5);assert(g.Position==UDim2.fromOffset(60,0)and not Spring.busy(f)and not Spring.busy(g))
   -- A throw mid-flight still lands on the goal, and says so once.
   local v,throw,s=0,false,spy()
   Spring.to(f,"Once",10,{get=function()return v end,set=function(x)if throw then throw=false;error("spec: one throw")end;v=x end,done=s.done})
   run(.05);throw=true;run(.05);assert(v==10 and s.reason=="error"and s.count==1 and not Spring.busy(f),"landed at "..v);f:Destroy();g:Destroy()
  end)
  test("Kit.tween cancels a spring; a spring takes one property of a Kit tween and the rest of it lands",function()
   local f=frame();Kit.spring(f,"Position",UDim2.fromOffset(90,0),{damping=.4});run(.05)
   Kit.tween(f,.1,{Position=UDim2.fromOffset(20,0)});assert(not Spring.busy(f));task.wait(.2);assert(f.Position==UDim2.fromOffset(20,0))
   Kit.tween(f,.3,{Position=UDim2.fromOffset(200,0),Size=UDim2.fromOffset(44,55)});task.wait(.06)
   Kit.spring(f,"Position",UDim2.fromOffset(10,0),{damping=.4});assert(f.Size==UDim2.fromOffset(44,55),"its other goal is written first")
   task.wait(.4);run(2.5);assert(f.Position==UDim2.fromOffset(10,0)and f.Size==UDim2.fromOffset(44,55))
   Kit.spring(f,"Position",UDim2.fromOffset(90,0),{damping=.4});run(.05);still=true;Kit.tween(f,.1,{Position=UDim2.fromOffset(30,0)});settle()
   assert(f.Position==UDim2.fromOffset(30,0)and not Spring.busy(f),"Reduced Motion");still=false;f:Destroy()
  end)
  test("Kit.spring off: today's tween, time and style",function()
   flags(false);local f=frame();Kit.spring(f,"Position",UDim2.fromOffset(90,0),{time=.1});assert(not Spring.busy(f)and f.Position~=UDim2.fromOffset(90,0))
   task.wait(.2);assert(f.Position==UDim2.fromOffset(90,0));f:Destroy();flags(true)
  end)

  for _,on in ipairs({true,false})do
   local tag=if on then " [on]"else " [off]"
   local function wait(s)if on then run(s)else task.wait(math.max(s,.25))end end
   test("button: hit rect still, up to 2 px over, 2 px wider a side only over a ledge and 60 px; exact rest after spam"..tag,function()
    flags(on)
    for _,o in ipairs({{variant="primary",size=Vector2.new(200,56)},{variant="secondary",size=Vector2.new(120,44)},{variant="ghost",size=Vector2.new(120,44)},{variant="secondary",size=Vector2.new(40,40)}})do
     local b,s=Kit.button(gui,"Press",o);b.Position=UDim2.fromOffset(40,40);settle()
     local at,size=b.AbsolutePosition,b.AbsoluteSize
     local function exact()return s.content.Position==UDim2.fromOffset(0,0)and s.fill.Position==UDim2.fromOffset(0,0)and s.fill.Size==UDim2.new(1,0,1,0)end
     local low,wide=0,0
     local function watch()
      assert(b.AbsolutePosition==at and b.AbsoluteSize==size,"hit rect")
      low=math.min(low,s.content.Position.Y.Offset);wide=math.max(wide,s.fill.Size.X.Offset)
      assert(s.ledge==0 or s.pressed or not on or s.fill.Position.Y.Offset==s.content.Position.Y.Offset)
     end
     local function press(down)s.pressed=down;Kit.paintButton(b)end
     press(true);task.wait(Kit.Motion.pressDown+.06);watch();assert(s.content.Position.Y.Offset==s.lip,o.variant.." down")
     local wants=on and s.ledge>0 and size.X>=60
     assert(s.fill.Size.X.Offset==(if wants then 4 else 0)and s.fill.Position.X.Offset==(if wants then -2 else 0))
     press(false)
     if on then run(.36,watch)else task.wait(Kit.Motion.pressUp+.06);watch()end
     assert(exact()and not Spring.busy(s.content),o.variant.." rest by .35 s");assert(low>=-2 and(not on or low<0)and wide<=4,"over "..low)
     for i=1,60 do press(i%2==1);if i%5==0 then task.wait()end;watch()end
     press(false);task.wait(.1);wait(1.5);assert(exact()and not Spring.busy(s.content),"after spam"..tag)
     -- Disabled, hidden and destroyed mid-release.
     press(true);task.wait(.1);press(false);if on then run(.05)end;Kit.setEnabled(b,false)
     if on then assert(exact(),"disabled mid-release")end
     Kit.setEnabled(b,true);wait(.5);press(true);task.wait(.1);Kit.setEnabled(b,false);if on then assert(exact(),"disabled while pressed")end
     Kit.setEnabled(b,true);wait(.5);press(true);task.wait(.1);press(false);b.Visible=false;settle();task.wait(.15);assert(exact(),"hidden")
     b.Visible=true;press(true);task.wait(.1);press(false);b:Destroy();settle();if on then assert(exact(),"destroyed")end
    end
   end)
   test("tile: padding top is always minus bottom, the rect never moves, exact rest after spam, setTileLip and hide"..tag,function()
    flags(on)
    local tile,s=Kit.tile(gui,"Tile",{position=UDim2.fromOffset(300,60),size=UDim2.fromOffset(104,88)});settle()
    local at,size=tile.AbsolutePosition,tile.AbsoluteSize
    local function watch()
     assert(tile.AbsolutePosition==at and tile.AbsoluteSize==size,"hit rect")
     if not on or s.pressed then return end -- the down tween and today's release round each side on their own
     assert(s.pad.PaddingTop.Offset==-s.pad.PaddingBottom.Offset and s.face.AbsoluteSize==size,"top = -bottom, nothing resizes")
     assert(s.pad.PaddingTop.Offset>=-2)
    end
    local function exact()return s.pad.PaddingTop==UDim.new()and s.pad.PaddingBottom==UDim.new()and s.lipFrame.Position==UDim2.fromOffset(0,s.lip)end
    Kit.pressTile(tile,true);task.wait(.1);assert(s.pad.PaddingTop.Offset==4);Kit.pressTile(tile,false)
    if on then run(.36,watch)else task.wait(.2);watch()end;assert(exact()and not Spring.busy(s.pad),"rest by .35 s")
    for i=1,60 do Kit.pressTile(tile,i%2==1);if i%5==0 then task.wait()end;watch()end
    Kit.pressTile(tile,false);task.wait(.1);wait(1.5);assert(exact(),"after spam")
    Kit.pressTile(tile,true);task.wait(.1);Kit.pressTile(tile,false);if on then run(.04)else task.wait(.2)end;Kit.setTileLip(tile,3)
    if on then assert(exact()and not Spring.busy(s.pad),"new lip mid-release")end;wait(.5);assert(exact()and s.lip==3)
    Kit.pressTile(tile,true);task.wait(.1);Kit.pressTile(tile,false);tile.Visible=false;settle();task.wait(.15);assert(exact(),"hidden")
    tile.Visible=true;Kit.pressTile(tile,true);task.wait(.1);tile.Interactable=false;settle(2);task.wait(.15);assert(exact(),"disabled while pressed")
    tile:Destroy()
   end)
   test("toggle knob and tab pill: inside the track every frame, exact end after spam, hide and a switch mid-flight"..tag,function()
    flags(on)
    local t=Kit.toggle(gui,"Knob");t.set(true);wait(1.5);assert(t.root.Knob.Position==UDim2.fromOffset(26,4))
    for i=1,30 do t.set(i%2==0);if i%4==0 then task.wait()end end
    t.set(false);task.wait(.1);wait(1.5);assert(t.root.Knob.Position==UDim2.fromOffset(4,4));t.root:Destroy()
    local tabs=Kit.tabs(gui,{"Faceplates","Backgrounds","Balls"},520,44,16);local pill=tabs.root.Pill
    local function exact(i)local x,size=tabs.pillRect(i);return pill.Position==UDim2.fromOffset(x,4)and pill.Size==UDim2.fromOffset(size.X,size.Y)end
    assert(exact(1))
    for _,i in ipairs({3,1,2,3,3,1})do
     tabs.select(i)
     if on then run(.26,function()
      assert(pill.Position.X.Offset>=4 and pill.Position.X.Offset+pill.Size.X.Offset<=516,"in the track: "..tostring(pill.Position))
     end)else task.wait(Kit.Motion.tab+.15)end
     assert(exact(i),"tab "..i..tag)
    end
    for i=1,40 do tabs.select(i%3+1);if i%4==0 then task.wait()end end
    tabs.select(2);tabs.select(2);task.wait(.3);wait(1.5);assert(exact(2),"after spam")
    tabs.select(3);tabs.root.Visible=false;settle();task.wait(.3);assert(exact(3),"hidden")
    tabs.root.Visible=true;tabs.select(1);if on then run(.05)end;flags(not on);settle(2);tabs.select(1);task.wait(.4);run(1.5);assert(exact(1),"switched mid-flight")
    flags(on);tabs.select(2);still=true;tabs.select(3);settle(2);assert(exact(3),"Reduced Motion mid-flight");still=false;tabs.root:Destroy()
   end)
   test("boing: at most 4 px a side, a hit rect at least 96%, ends at 1; list children keep today's numbers; an owner's scale is left alone"..tag,function()
    flags(on)
    local b=Kit.tile(gui,"Key",{size=UDim2.fromOffset(300,120)});local plain=frame({Size=UDim2.fromOffset(60,60)})
    for _,e in ipairs({{b,.96},{plain,if on then .94 else .96}})do
     Kit.boing(e[1]);local scale=e[1].BoingScale;assert(math.abs(scale.Scale-e[2])<1e-4,"starts at "..scale.Scale)
     if on then run(1.5,function()
      assert(scale.Scale>=e[2]-1e-4 and(scale.Scale-1)*e[1].Size.X.Offset/2<=4.01)
     end)else task.wait(Kit.BoingTime+.15)end
     assert(math.abs(scale.Scale-1)<1e-3)
     for _=1,10 do Kit.boing(e[1])end;task.wait(Kit.BoingTime+.15);wait(1.5);assert(math.abs(scale.Scale-1)<1e-3)
    end
    local list=frame({Size=UDim2.fromOffset(200,200)});Instance.new("UIListLayout").Parent=list
    local row=Instance.new("Frame");row.Size=UDim2.fromOffset(80,20);row.Parent=list
    Kit.boing(row);assert(math.abs(row.BoingScale.Scale-.96)<1e-4 and not Spring.busy(row.BoingScale));task.wait(Kit.BoingTime+.15);assert(math.abs(row.BoingScale.Scale-1)<1e-3)
    local own=frame();local scale=Instance.new("UIScale");scale.Parent=own;Kit.boing(own);assert(scale.Scale==1 and not Spring.busy(scale))
    for _,o in ipairs({b,plain,list,own})do o:Destroy()end
   end)
   test("wallet: the text changes at once; the Star hops at most 8 px on a gain, once per .3 s, and lands exactly"..tag,function()
    flags(on)
    local w=Kit.wallet(gui,44);local home=w.star.Position;settle()
    w.set(5);w.set(25);assert(w.amount.Text=="25")
    local top=0
    if on then
     assert(Spring.busy(w.root,"KitHop"));w.set(26);w.set(27)
     run(1.5,function()top=math.max(top,home.Y.Offset-w.star.Position.Y.Offset)
      local three=w.star3D.wallet;assert(not three or three.holder.Position==w.star.Position,"both Stars move together")end)
     assert(top>=6 and top<=8,"hop "..top)
    else assert(not Spring.busy(w.root))end
    assert(w.star.Position==home)
    -- The Star moved by someone else mid-hop: the hop gives way and both Stars are still together.
    task.wait(.35);w.set(40);if on then run(.05)end;w.star.Position=home+UDim2.fromOffset(3,0);settle(2)
    local pair=w.star3D.wallet;assert(w.star.Position==home+UDim2.fromOffset(3,0)and not Spring.busy(w.root)and(not on or not pair or pair.holder.Position==w.star.Position),"together")
    w.star.Position=home;if pair then pair.holder.Position=home end
    w.set(3);assert(w.amount.Text=="3"and not Spring.busy(w.root),"never on a spend")
    task.wait(.35);w.set(50);if on then run(.05)end;flags(false);settle(2);assert(w.star.Position==home,"switched off mid-hop")
    flags(on);w.root:Destroy()
   end)
  end
  test("flags off: no Kit piece above leaves a spring live",function()
   flags(false);settle();assert(Spring.count()==0)
  end)
 end,function(e)return debug.traceback(tostring(e),2)end)
 Kit.reduced,Kit.reducedEffects,Spring.cap,Spring.Instant,Kit.Motion.bounce=saved.reduced,saved.effects,saved.cap,saved.instant,saved.bounce
 Spring.settle(screen);screen:Destroy()
 for _,f in ipairs(Alive.Features)do workspace:SetAttribute(Alive.attribute(f),attrs[f])end
 assert(ok,problem)
 return{passed=#cases,cases=cases}
end
