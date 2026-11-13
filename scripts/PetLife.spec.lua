-- Overnight 2026-11-12 pet-life presentation: deck reactions, ears/tail, petting
-- curve, idle beats. Native-recipe fixture pets in workspace; no remotes, no saves.
return function(client)
 local Visual=require(client.GardenPetVisual);local Reactions=require(client.PetReactions)
 local Pets=require(game.ReplicatedStorage.Shared.PetCatalog)
 local folder=Instance.new("Folder");folder.Name="_PetLifeSpec";folder.Parent=workspace
 local cases,views={},{};local function test(name,run)run();table.insert(cases,name)end
 local function make()local v=Visual.new(folder,Vector3.new(2100,4.025,#views*4),Pets.byId.pip,.72,nil,{native=true});table.insert(views,v);return v end
 local function piece(v,name)for _,p in ipairs(v.pieces)do if p.name==name then return p end end;error(name.." missing")end
 local ok,err=pcall(function()
  test("deck cheer hops with the pleased face and is limited to one per 1.5 s",function()
   local v={};assert(Reactions.trigger(v,"cheer",10))
   local hop,face=Reactions.sample(v,10+Reactions.HopDuration/2);assert(hop>.9 and face=="pleased")
   assert(not Reactions.trigger(v,"cheer",11.2),"cheer repeated inside 1.5 s");assert(Reactions.trigger(v,"cheer",11.6))
   local done=select(2,Reactions.sample(v,11.6+2));assert(done==nil,"cheer face never ended")
  end)
  test("a win double-hops; a loss is startled for 0.4 s, then sleepy",function()
   local v={};assert(Reactions.trigger(v,"win",0))
   local d=Reactions.HopDuration;assert(Reactions.sample(v,d*.5)>.9 and Reactions.sample(v,d*1.5)>.9 and Reactions.sample(v,d)<.05)
   assert(select(2,Reactions.sample(v,d*1.5))=="pleased")
   local l={};assert(Reactions.trigger(l,"loss",0))
   assert(select(2,Reactions.sample(l,.2))=="startled"and select(2,Reactions.sample(l,.6))=="sleepy"and Reactions.sample(l,.2)==0)
   assert(not Reactions.trigger(l,"cheer",1),"a cheer interrupted the loss beat")
   assert(select(2,Reactions.sample(l,10))==nil)
  end)
  test("Reduced Effects keeps the faces but drops the hop",function()
   local v={reducedEffects=true};Reactions.trigger(v,"cheer",0);local hop,face=Reactions.sample(v,Reactions.HopDuration/2)
   assert(hop==0 and face=="pleased")
  end)
  test("a real Bear visual lifts and shows the reaction without allocating",function()
   local v=make();v.reducedEffects=false;v:update(0)
   local count=#v.model:GetDescendants();local rest=piece(v,"Head").part.Position.Y
   Reactions.trigger(v,"cheer",os.clock()-Reactions.HopDuration/2);v:update(0)
   assert(piece(v,"Head").part.Position.Y>rest+.02,"no hop");assert(#v.model:GetDescendants()==count)
   Reactions.clear(v);v:update(0);assert(math.abs(piece(v,"Head").part.Position.Y-rest)<1e-3)
  end)
  local Motion=require(client.PetIdleMotion)
  local function run(v,expression,seconds,each)
   local dt=1/60
   for _=1,math.floor(seconds/dt)do v.time=(v.time or 0)+dt;local l,r,t=Motion.appendages(v,expression,dt);if each then each(l,r,t,v.time)end end
  end
  local function crossings(expression)
   local v={cosmeticSeed=5,time=0};run(v,expression,1.5)
   local n,last=0,nil;run(v,expression,4,function(_,_,t)if last and(last<0)~=(t<0)then n+=1 end;last=t end);return n
  end
  test("tail wags about 1 Hz on neutral, about 3 Hz when pleased or affectionate, still when sleepy",function()
   local calm,happy,fond=crossings("neutral"),crossings("pleased"),crossings("affectionate")
   assert(calm>=7 and calm<=9,"neutral crossings "..calm);assert(happy>=23 and happy<=25 and fond>=23 and fond<=25,"happy crossings "..happy)
   local v={time=0};run(v,"pleased",1);run(v,"sleepy",2);local _,_,t=Motion.appendages(v,"sleepy",1/60);assert(math.abs(t)<math.rad(.5),"sleepy tail still moving")
  end)
  test("ears perk +10 deg when curious, droop -15 deg when sleepy, and one flicks every 4-9 s",function()
   local v={time=0,cosmeticSeed=9};local l,r
   run(v,"curious",2,function(a,b)l,r=a,b end);assert(math.abs(math.max(l,r)-Motion.EarPerk)<math.rad(13)and math.min(l,r)>math.rad(9),"no perk")
   run(v,"sleepy",2,function(a,b)l,r=a,b end);assert(math.min(l,r)<math.rad(-14),"no droop")
   local w={time=0,cosmeticSeed=3};local starts={};local was=false
   run(w,"neutral",40,function(a,b,_,time)local flicking=math.abs(a-b)>math.rad(1);if flicking and not was then table.insert(starts,time)end;was=flicking end)
   assert(#starts>=4,"too few flicks "..#starts)
   for i=2,#starts do local gap=starts[i]-starts[i-1];assert(gap>=3.9 and gap<=9.1,"flick gap "..gap)end
   local twin={time=0,cosmeticSeed=3};local again={};was=false
   run(twin,"neutral",40,function(a,b,_,time)local flicking=math.abs(a-b)>math.rad(1);if flicking and not was then table.insert(again,time)end;was=flicking end)
   assert(#again==#starts and math.abs(again[1]-starts[1])<1e-6,"flicks are not seeded per pet")
  end)
  test("Reduced Effects freezes ears and tail at rest",function()
   local v={time=0,reducedEffects=true};run(v,"pleased",3,function(a,b,t)assert(a==0 and b==0 and t==0)end)
  end)
  test("real Bear ears and tail move inside the padded bounds, without allocating",function()
   local v=make();v.reducedEffects=false;v:update(0);local count=#v.model:GetDescendants()
   local ear,tail=piece(v,"EarL"),piece(v,"Tail")
   v.expression="neutral";for _=1,90 do v:update(1/60)end;local earRest=ear.part.CFrame
   v.expression="sleepy";for _=1,120 do v:update(1/60)end
   assert((ear.part.CFrame.UpVector-earRest.UpVector).Magnitude>.15,"ear did not droop")
   local seen={};v.expression="pleased";for i=1,60 do v:update(1/60);seen[i]=tail.part.Position end
   local spread=0;for i=2,#seen do spread=math.max(spread,(seen[i]-seen[1]).Magnitude)end;assert(spread>.02,"tail never wagged")
   assert(#v.model:GetDescendants()==count,"appendage motion allocated instances")
   local pad=Motion.padding(v,tail);assert(pad.X>0 and pad.Z>0,"tail padding missing")
   assert(Motion.padding(v,ear).X>Motion.padding(v,piece(v,"Head")).X,"ear padding missing")
  end)
  local Expression=require(client.PetExpression);local Affection=require(client.PetAffection);local Pico8=require(game.ReplicatedStorage.Shared.Pico8)
  test("holding builds pleased (0-1 s) then affectionate; un-clocked petting stays affectionate",function()
   assert(Expression.name({petting=true,pettingHeld=.4})=="pleased"and Expression.name({petting=true,pettingHeld=1.1})=="affectionate")
   assert(Expression.name({petting=true})=="affectionate"and Expression.name({petting=false,pettingHeld=3})=="neutral")
  end)
  test("a held pet gets PICO-8 pink hearts after 1 s; Reduced Effects and release clear them",function()
   local v=make();local fx=Affection.new(folder);fx:setPet(v);local count=#fx.folder:GetDescendants()
   fx.clock=function()return 100 end;fx:begin(false);v.petting=true
   for _=1,30 do fx:step(1/60,true,false)end;assert(v.pettingHeld and v.pettingHeld<1 and Expression.name(v)=="pleased")
   for _=1,60 do fx:step(1/60,true,false)end;assert(Expression.name(v)=="affectionate")
   local shown=0;for _,h in ipairs(fx.hearts)do if h.gui.Enabled then shown+=1;assert(h.glyph.TextColor3==Pico8[14]and h.glyph.Text=="♥")end end
   assert(shown>0,"no hearts while held");assert(#fx.folder:GetDescendants()==count,"hearts allocated per frame")
   fx:clear();assert(v.pettingHeld==nil);for _,h in ipairs(fx.hearts)do assert(not h.gui.Enabled)end
   fx.clock=function()return 200 end;fx:begin(true);for _=1,120 do fx:step(1/60,true,true)end
   for _,h in ipairs(fx.hearts)do assert(not h.gui.Enabled,"hearts under Reduced Effects")end
   fx:destroy();v.petting=false
  end)
  test("a boop squashes the body for 0.15 s; none under Reduced Effects",function()
   local v=make();v.reducedEffects=false;v:update(0);local body=piece(v,"Body");local rest=body.part.Size.Y
   v.boopAt=os.clock()-.075;v:update(0);assert(body.part.Size.Y<rest*.9,"no squash")
   v.boopAt=os.clock()-.3;v:update(0);assert(math.abs(body.part.Size.Y-rest)<1e-4,"squash outlived 0.15 s")
   v.reducedEffects=true;v.boopAt=os.clock()-.075;v:update(0);assert(math.abs(body.part.Size.Y-rest)<1e-4,"squash under Reduced Effects")
  end)
  local Beats=require(client.PetIdleBeats)
  local function beats(seed,seconds,still,eligibleAt)
   local v={petId="pip",cosmeticSeed=seed};local seen,starts,running={},{},false;local t=0
   for _=1,math.floor(seconds*30)do
    t+=1/30;local kind=Beats.step(v,1/30,if eligibleAt then eligibleAt(t)else true,still)
    if kind and not running then table.insert(seen,kind);table.insert(starts,t)end;running=kind~=nil
   end
   return seen,starts,v
  end
  test("idle beats start after 5 s idle and are at least 7 s apart (FEEL-ALIVE B2 retune)",function()
   local seen,starts=beats(77,120,false)
   assert(#seen>=5,"too few beats "..#seen);assert(starts[1]>Beats.IdleAfter and starts[1]<=Beats.IdleAfter+2.1,"first beat at "..starts[1])
   for i=2,#starts do assert(starts[i]-starts[i-1]>=Beats.Gap,"beats too close")end
  end)
  test("wave only when the owner stands still nearby; the sequence is seeded per pet",function()
   local moving=beats(77,400,false);for _,kind in ipairs(moving)do assert(kind~="wave","waved at a moving owner")end
   local a,b=beats(77,400,true),beats(77,400,true);local waves=0
   assert(#a==#b);for i=1,#a do assert(a[i]==b[i],"same pet diverged on rejoin");if a[i]=="wave"then waves+=1 end end
   assert(waves>0,"a still owner never got a wave")
   local other=beats(78,400,true);local same=#other==#a;for i=1,math.min(#a,#other)do if other[i]~=a[i]then same=false end end
   assert(not same,"different pets share one sequence")
  end)
  test("losing eligibility (carry, care, toy, focus) cancels and resets the idle clock",function()
   local seen,starts=beats(5,40,false,function(t)return not(t>4 and t<12)end)
   assert(#seen>=1 and starts[1]>12+Beats.IdleAfter,"beat ran or resumed early: "..tostring(starts[1]))
  end)
  test("the idle clock runs through wandering, but a beat only plays while the pet stands still",function()
   local v={petId="pip",cosmeticSeed=77};local kind
   for _=1,9*30 do kind=Beats.step(v,1/30,true,false,false)end;assert(kind==nil,"beat started while walking")
   for _=1,2*30 do kind=Beats.step(v,1/30,true,false,true)or kind end;assert(kind~=nil,"no beat once the pet stopped")
   assert(Beats.step(v,1/30,true,false,false)==nil,"beat kept playing while walking")
  end)
  test("a real Bear performs beats only when enabled and never while focused",function()
   local v=make();v.reducedEffects=false;v.idleBeatsEnabled=true;v.cosmeticSeed=77
   for _=1,12*30 do v:update(1/30)end;assert(v.model:GetAttribute("IdleBeat")~=nil,"no beat on an idle Bear")
   local w=make();w.reducedEffects=false;w.idleBeatsEnabled=true;w.focusPose=true
   for _=1,12*30 do w:update(1/30)end;assert(w.model:GetAttribute("IdleBeat")==nil,"beat during focus")
   local r=make();r.reducedEffects=true;r.idleBeatsEnabled=true
   for _=1,12*30 do r:update(1/30)end;assert(r.model:GetAttribute("IdleBeat")==nil,"beat under Reduced Effects")
  end)
 end)
 for _,v in ipairs(views)do v:destroy()end;folder:Destroy()
 assert(ok,err);return{passed=#cases,cases=cases}
end
