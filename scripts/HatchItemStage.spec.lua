-- Studio Client. The v2 Pop-Out Stage (V2-HATCH-REDESIGN-2026-11-19 and Revision 1): the
-- per-tier clock and the Rare jackpot, photosensitivity (no full-screen flash), Reduced Motion,
-- layout on phone and PC, disclosure, the result card (odds tray, pity, Hatch another), the
-- toy lid and the iris, the mirrored receipt actions and the scene loan. A synthetic scene; no
-- purchase, remote, save or sound.
-- Usage: require(PlayerScripts.Client.ZZSpecs.HatchItemStage)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Stage=require(client.HatchItemStage);local Rarity=require(client.HatchRarityCue)
 local GuiService=game:GetService("GuiService")
 local Kit=require(client.DeckKit);local Copy=require(game:GetService("ReplicatedStorage").Shared.UICopy)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local gui=Instance.new("ScreenGui");gui.Name="_HatchItemStageSpec";gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=parent
 local stages={}
 local R=Rarity.Base.ready;local J=Rarity.Jackpot
 local function fakeScene(record)
  local s={ready=true,root=Instance.new("Frame")}
  function s:borrow(seat)record.borrows+=1;self.root.Parent=seat;return self end
  function s:release(token)assert(token==self);record.releases+=1;self.root.Parent=nil end
  function s:setBare(bare,hideHero)record.bare={bare,hideHero}end
  function s:layout()record.layouts+=1 end
  function s:setSpin(radians)record.spin=radians;record.spins=(record.spins or 0)+1;return radians~=0 end
  function s:setVeil(amount)record.veil=amount end
  return s
 end
 local function open(w,h,extra)
  local record={borrows=0,releases=0,layouts=0,skips=0,closes=0,acts={},again=0}
  local host=Instance.new("Frame");host.Size=UDim2.fromOffset(w,h);host.BackgroundTransparency=1;host.Parent=gui
  local use=Instance.new("TextButton");use.Name="UseNow";use.Text="Use now";use.Parent=host
  local keep=Instance.new("TextButton");keep.Name="Action";keep.Text="Store";keep.Parent=host
  local options={scene=fakeScene(record),kind="toy",tier="Neutral",cover=false,owns=function()return true end,reduced=function()return false end,
   name=function()return "Squeaky Carrot"end,detail=function()return "Choose a pet for this toy."end,lid=false,
   onSkip=function()record.skips+=1 end,onClose=function()record.closes+=1 end,
   actions=function()return {{source=use,primary=true,act=function()table.insert(record.acts,"use")end},{source=keep,primary=false,act=function()table.insert(record.acts,"store")end}}end}
  for key,value in pairs(extra or {})do options[key]=value end
  local stage=Stage.show(host,options);table.insert(stages,stage)
  if stage.connection then stage.connection:Disconnect();stage.connection=nil end
  return stage,record,use,keep,host
 end
 local function at(stage,age)stage:updateExternal(age,nil);stage:step(1/30)end
 local ok,problem=pcall(function()
  test("timeline: Common and Uncommon keep today's beats; the name lands exactly on the receipt beat",function()
   for _,tier in ipairs({"Common","Uncommon","Neutral"})do
    local B=Rarity.timing(tier,"item",false).burst;assert(B==.98)
    local s=Stage.sample(0,false,tier);assert(s.bloom==0 and s.burstAge<0 and s.slide==0 and not s.named and not s.input and s.stamp==0)
    assert(Stage.sample(B-.01,false,tier).bloom==0 and Stage.sample(B+.03,false,tier).bloom>0 and Stage.sample(B+.41,false,tier).bloom==0,"one bloom, at the burst")
    assert(Stage.sample(B+.27,false,tier).slide==0 and Stage.sample(B+.28+.34,false,tier).slide>.99,"the well slides to its seat after the pop")
    assert(not Stage.sample(R-.001,false,tier).named and Stage.sample(R,false,tier).named and Stage.sample(R,false,tier).input)
    assert(not Stage.sample(R+Stage.SettleAfter-.01,false,tier).settled and Stage.sample(R+Stage.SettleAfter,false,tier).settled)
    assert(not Stage.sample(R+Stage.SettleAfter+Stage.AgainLock-.01,false,tier).againLive and Stage.sample(R+Stage.SettleAfter+Stage.AgainLock,false,tier).againLive,"Hatch another is locked 0.4 s after the card settles")
    assert(Stage.sample(1.2,false,tier).shock==nil and Stage.sample(1.2,false,tier).rainbow==0,"no jackpot outside Rare")
   end
   -- The camera: a 4% push in over the shakes; Uncommon pulls back 6% at the burst.
   assert(Stage.sample(.9,false,"Common").cam>1.03 and Stage.sample(1.2,false,"Uncommon").cam<1)
  end)
  test("the Rare jackpot: wind-up, freeze, burst at 1.72, cannons, the stamp at 2.30, the name at 3.15",function()
   local T=Rarity.timing("Rare","item",false);assert(T.burst==J.burst and T.ready==J.name)
   local wind=Stage.sample(1.3,false,"Rare");assert(wind.orbit>0 and wind.orbitRadius<132 and wind.orbitRadius>92 and wind.shafts>0 and wind.bloom==0 and wind.burstAge<0)
   assert(Stage.checkerSpeed(.5,"Rare")==8 and Stage.checkerSpeed(1.59,"Rare")>40 and Stage.checkerSpeed(1.65,"Rare")<6,"the checker speeds up, then the freeze runs it at one tenth")
   assert(Stage.orbitSpeed(1.0)<Stage.orbitSpeed(1.55)and Stage.orbitSpeed(1.65)<.3)
   local burst=Stage.sample(J.burst+.1,false,"Rare")
   assert(burst.punch>0 and burst.shake>0 and burst.shake<=3 and burst.shock and burst.shock.width<10 and burst.shock.width>=2 and burst.rainbow>0)
   assert(Stage.sample(J.burst+.6,false,"Rare").shock==nil and Stage.sample(J.burst+.6,false,"Rare").rainbow==1,"the shockwave is gone in 0.5 s; the rainbow stays")
   local fall=Stage.sample(J.stamp+.06,false,"Rare");assert(fall.stamp==1 and fall.stampScale>1 and fall.stampScale<2.6)
   assert(math.abs(Stage.sample(J.stamp+.12,false,"Rare").stampScale-1)<1e-6,"the stamp lands at full size")
   assert(not Stage.sample(J.name-.01,false,"Rare").named and Stage.sample(J.name,false,"Rare").named)
   -- Disclosure (R1.1): the stamp is the first tier word, and only after the burst.
   for t=0,J.burst-.01,.01 do assert(Stage.sample(t,false,"Rare").stamp==0,"RARE! before the burst at "..t)end
   for t=0,.29,.01 do assert(Stage.sample(t,true,"Rare").stamp==0)end
   -- Cannons: bottom corners, up and in, gone by the card's rest.
   local x,y=Stage.cannon(3,-1,.3,844,390,1);assert(x>0 and y<390,"the left cannon fires up and in")
   local x2=Stage.cannon(3,1,.3,844,390,1);assert(x2<844)
   assert(Stage.cannon(3,-1,Stage.Cannon.life+.01,844,390,1)==nil and J.cannonR+Stage.Cannon.life<J.duration,"every piece has landed before the clock ends")
   assert(Stage.Pool.burst+Stage.Pool.cannon+Stage.Pool.orbit<=94,"the R1.3 budget")
  end)
  test("photosensitivity: no full-screen flash, one bloom, and at most 3 alternations a second (sampled at 60 Hz)",function()
   for _,tier in ipairs({"Common","Uncommon","Rare","Neutral"})do
    local T=Rarity.timing(tier,"item",false)
    local blooms,signs,lastBloom,lastDir=0,{},0,0
    for i=0,math.ceil(T.duration*60)do
     local t=i/60;local s=Stage.sample(t,false,tier)
     assert(s.flash==nil,"no full-screen flash lane")
     assert(s.bloom<=.6+1e-9 and s.bloomR<=1,"the bloom stays in the well: 60% at most, 150 px")
     if s.bloom>0 and lastBloom==0 then blooms+=1 end
     local dir=if s.bloom>lastBloom+1e-9 then 1 elseif s.bloom<lastBloom-1e-9 then -1 else 0
     if dir~=0 and lastDir~=0 and dir~=lastDir then table.insert(signs,t)end
     if dir~=0 then lastDir=dir end
     lastBloom=s.bloom
     assert(s.rainbow==0 or s.rainbow>=Stage.sample(math.max(0,t-1/60),false,tier).rainbow,"the rainbow ramps once and stays")
    end
    assert(blooms==1,tier.." blooms "..blooms.." times")
    for k=1,#signs do local n=0;for m=k,#signs do if signs[m]-signs[k]<1 then n+=1 end end;assert(n<=3,tier.." alternates more than 3 times in a second")end
   end
   assert(Stage.sample(J.burst+.01,false,"Rare").shake<=3 and Stage.sample(J.burst+.01,true,"Rare").shake==0)
  end)
  test("Reduced Motion: a 0.6 s cross-fade (Rare 0.9), no camera, bloom, shake or flying confetti; the stamp fades in at full size",function()
   local a,b=Stage.sample(.05,true,"Common"),Stage.sample(.6,true,"Common")
   assert(a.reduced and a.fade>0 and a.fade<1 and not a.input and not a.named and b.input and b.named and b.settled)
   for _,s in ipairs({a,b,Stage.sample(.5,true,"Rare")})do
    assert(s.bloom==0 and s.shake==0 and s.cam==1 and s.tip==0 and s.punch==0 and s.shock==nil and s.burstAge==math.huge and s.stillStones and s.orbit==0)
   end
   local stamp=Stage.sample(.55,true,"Rare");assert(stamp.stamp>0 and stamp.stampScale==1 and stamp.rainbow==.6,"RARE! fades in at full size; the rainbow is drawn still")
   assert(not Stage.sample(.89,true,"Rare").input and Stage.sample(.9,true,"Rare").input)
   assert(Stage.checkerSpeed(1,"Rare",true)==0 and Stage.raySpeed(1,"Rare",true)==0,"patterns are still")
   local reduced=open(844,390,{reduced=function()return true end,tier="Rare"});at(reduced,.05)
   assert(not reduced:isSettled()and not reduced.shock.Visible)
   at(reduced,.95);assert(reduced:isSettled()and reduced.name.Text=="SQUEAKY CARROT"and reduced.raysImage.Rotation==0)
   for _,o in ipairs(reduced.pieces)do assert(not o.Visible)end
   local still=0;for _,o in ipairs(reduced.orbit)do if o.Visible then still+=1 end end;assert(still==12,"twelve stones sit in a ring")
  end)
  test("burst confetti: rune stones and four-point sparkles; Common stays in the well, Rare reaches the edges",function()
   assert(Stage.confetti(1,10,-.01,0,100,1)==nil)
   local x1,y1=Stage.confetti(3,30,.3,1,190,1);local x2,y2=Stage.confetti(3,30,.3,1,190,1);assert(x1==x2 and y1==y2,"deterministic")
   for i=1,6 do for t=0,1,.05 do local x,y=Stage.confetti(i,6,t,0,190,1);if x then assert(math.abs(x)<=190 and math.abs(y)<=190,"Common left the well")end end end
   local far=0;for i=1,30 do local x,y=Stage.confetti(i,30,.8,1,190,1);if x and math.sqrt(x*x+y*y)>260 then far+=1 end end;assert(far>10,"Rare confetti leaves the well")
   assert(Rarity.Stage.Common.stones+Rarity.Stage.Common.sparkles==6 and Rarity.Stage.Uncommon.stones+Rarity.Stage.Uncommon.sparkles==14 and Rarity.Stage.Rare.stones+Rarity.Stage.Rare.sparkles==30)
  end)
  test("vibrant stages: Sunny Peach, Lime Soda, Berry Blast; never deck-tinted, no teal",function()
   for _,tier in ipairs({"Common","Uncommon","Rare"})do
    local st=Rarity.Stage[tier]
    for _,c in ipairs({st.core,st.edge,st.ray})do local h=c:ToHSV()*360;assert(h<150 or h>200,tier.." has a teal hue")end
    assert(Kit.contrast(st.core,Color3.new(1,1,1))>=2 and Kit.contrast(st.core,Stage.Ink)>=5,tier.." core reads with white and ink items")
   end
   -- Off (the Alive `aerohatch` switch, forced here): the old wells exactly.
   local stage=open(844,390,{tier="Uncommon",aero=false})
   assert(stage.well.BackgroundColor3==Rarity.Stage.Uncommon.edge and stage.core.ImageColor3==Rarity.Stage.Uncommon.core and stage.rimStroke.Color==Rarity.Look.Uncommon.color)
   assert(stage.aeroParts==nil and stage.raysImage.ImageRectOffset==Vector2.new(0,0),"the sunburst, no Aero parts")
  end)
  test("AERO-JUICE-BRIEF 3: Sky, Meadow and Aurora wells; shafts from the top, a horizon, bubbles in the egg's accent",function()
   local Aero=Rarity.Aero
   for _,tier in ipairs({"Common","Uncommon","Rare"})do
    local p=Aero.palette(tier)
    local stage=open(844,390,{tier=tier,kind="toy",aero=true});at(stage,.5)
    local st,lk=Rarity.stageLook(tier,true),Rarity.lookOf(tier,true)
    assert(stage.aero==true and stage.well.BackgroundColor3==p.edge and stage.core.ImageColor3==p.core and st.edge==p.edge,tier.." well")
    assert(stage.rimStroke.Color==lk.color and lk.color==p.look,tier.." rim")
    assert(stage.raysImage.ImageRectOffset==Vector2.new(512,0)and stage.aeroParts.raysAlt.ImageRectOffset==Vector2.new(512,0),"the shafts, not the sunburst")
    assert(math.abs(stage.raysImage.ImageTransparency-(1-Aero.Rays.alpha))<1e-6 and stage.raysImage.Position.Y.Scale==0,"soft, from the top")
    assert(#stage.aeroParts.bubbles==p.bubbles and #stage.aeroParts.sparkles==p.glints+p.sparkles,tier.." bubbles and sparkles")
    local shown=0;for _,b in ipairs(stage.aeroParts.bubbles)do if b.node.Visible then shown+=1 end end
    assert(shown>0,"bubbles rise before the burst")
    assert(stage.aeroParts.bubbles[1].stroke.Color==Aero.accent("toy",1),"the rim is the Toy Egg's accent")
    assert(stage.floorShadow.ImageColor3==p.shadow,"no cocoa shadow on the grass")
    -- Fable B37: the sky round the card, no checker, six faint sky bubbles.
    assert(stage.shell.AeroSky.Enabled and not stage.shell.CheckerHolder.Visible and #stage.aeroParts.outer==Aero.Backdrop.bubbles,tier.." sky backdrop")
    for i=1,6 do assert(stage:stoneColor(i)~=Color3.fromHex("#FFC14D"),"no Stars gold in the confetti")end
    -- Common and Uncommon (the Bear's sky too) never teal-grey: saturated edges (HatchAero.spec has the full check).
    local _,s=p.edge:ToHSV();assert(s>=.6,tier.." edge saturated")
   end
   local reduced=open(844,390,{tier="Uncommon",aero=true,reduced=function()return true end});at(reduced,.95)
   local b=reduced.aeroParts.bubbles[1];local before=b.node.Position
   reduced.clock+=2;at(reduced,1.5);assert(b.node.Position==before and reduced.raysImage.Rotation==0,"Reduced Motion: still rays and bubbles")
  end)
  test("layout: phone 844x390 matches the spec rects; 812x354, 568x320, PC and portrait stay on screen",function()
   local L=Stage.geometry(844,390)
   assert(L.wellSeat.x==24 and L.wellSeat.y==20 and L.wellSeat.w==380 and L.wellSeat.h==292 and L.tray.x==420 and L.primary.x==626 and L.primary.y+L.primary.h==370)
   for _,size in ipairs({{812,354},{844,390},{568,320},{1280,720},{1649,734},{1920,1080},{390,844}})do
    local W,H=size[1],size[2];local G=Stage.geometry(W,H)
    for _,key in ipairs({"wellCentre","wellSeat","again","pityTray","sticker","name","tray","secondary","primary"})do
     local r=G[key];assert(r.x>=0 and r.y>=0 and r.x+r.w<=W and r.y+r.h<=H,key.." off screen at "..W.."x"..H)
    end
    assert(G.primary.h>=44 and G.text.cell>=12 and G.text.small>=12,"targets and text at "..W.."x"..H)
    if G.landscape then assert(G.tray.x>=G.wellSeat.x+G.wellSeat.w,"the card column overlaps the well at "..W.."x"..H)end
   end
   assert(Stage.geometry(1649,734).s<=1.35,"PC stays in a band")
  end)
  test("QA v775: the corner close keeps a thumb-safe inset from the safe area and the top bar",function()
   local size=Stage.CloseSize;assert(size>=44)
   local x,y=Stage.closeRect(874,402,true,{l=62,t=0,r=62,b=21},{maxX=874,height=58})
   assert(874-62-(x+size)>=24 and y>=16)
   x,y=Stage.closeRect(568,320,true,nil,nil);assert(568-(x+size)==24 and y==16)
   x,y=Stage.closeRect(812,354,true,{l=0,t=0,r=0,b=0},{maxX=700,height=58});assert(y==66)
   x,y=Stage.closeRect(1920,1080,false,nil,nil);assert(1920-(x+size)==32 and y==28)
  end)
  test("disclosure: no name, sticker, tray or tier word before the receipt beat; stones are blank before the burst",function()
   local stage,record=open(844,390,{tier="Uncommon",odds=function()return {rows={{id="a",name="A",value="50%"},{id="b",name="B",value="50%"}}}end,wonId="a"})
   assert(record.borrows==1 and record.bare[1]==true and record.bare[2]==false)
   for _,age in ipairs({0,.5,1.0,1.3,R-.02})do
    at(stage,age)
    assert(stage.name.Text==""and not stage.nameGroup.Visible and not stage.sticker.Visible and not stage.tray.Visible and not stage.lines.Visible,"disclosed at "..age)
    assert(stage.skip.Visible and stage.root:GetAttribute("InputLocked")==true and not stage.buttons[1].node.Visible and not stage.close.Visible and not stage.againButton.Visible)
   end
   for _,o in ipairs(stage.orbit)do assert(o.ImageColor3==Rarity.Look.Uncommon.color or o.ImageColor3==Color3.new(1,1,1),"an orbit stone names something")end
   at(stage,R+.01);assert(stage.name.Text=="SQUEAKY CARROT"and stage.nameGroup.Visible and stage.nameScale.Scale<1,"the name pops in")
   at(stage,R+.3);assert(stage.sticker.Visible and stage.stickerText.Text==Stage.bannerText("Uncommon","toy")and stage.nameScale.Scale==1 and stage.tray.Visible)
   at(stage,3.1);assert(stage:isSettled()and not stage.skip.Visible)
   local L=stage.L;assert(stage.nameW<=L.textW+2 and stage.name.TextSize>=18,"the name fits its column")
  end)
  test("the result card: the egg card's odds, the won cell lemon, the pity line, a long table capped",function()
   local odds={rows={{id="rose",name="Rose",value="17%"},{id="tide",name="Tide",value="17%"},{id="charm",name="Charms",value="6%"},
    {id="pity",name="Charm within 9 eggs",label="If 14 eggs pass without a charm, the next one is a charm.",value="",info=true},
    {id="rounded",name=Copy.get("hatch.odds.rounded"),value="",info=true}}}
   local cells,notes=Stage.trayCells(odds,"tide");assert(#cells==3 and cells[2].won and not cells[1].won and #notes==2)
   assert(notes[1]=="If 14 eggs pass without a charm, the next one is a charm.","the pity rule is a note")
   local many={rows={}};for i=1,14 do table.insert(many.rows,{id="t"..i,name="Toy "..i,value="7%"})end
   local capped=Stage.trayCells(many,nil,9);assert(#capped==9 and capped[9].id=="more")
   local restricted=Stage.trayCells({rows={{id="next",name="Next: Ball",value=""}},restricted=true},nil);assert(#restricted==0,"restricted players see the Next line as a note")
   local stage=open(844,390,{odds=function()return odds end,wonId="tide",pity=function()return {line="Charm within 9 eggs",sub="3 left in today's nest"}end})
   at(stage,R+.6);task.wait()
   assert(stage.tray.Visible and stage.cells[2].frame.Visible and stage.cells[2].frame.BackgroundColor3==Stage.Lemon and stage.cells[1].frame.BackgroundColor3==Stage.Cream)
   assert(stage.trayKey.Visible and stage.pityTray.Visible and stage.pityLine.Text=="Charm within 9 eggs"and stage.pitySub.Text=="3 left in today's nest")
   local tray=stage.tray.AbsolutePosition.Y+stage.tray.AbsoluteSize.Y
   assert(tray<=stage.buttons[2].node.AbsolutePosition.Y,"the tray sits above the buttons")
  end)
  test("Hatch another: never before the card settles, locked 0.4 s, one press one request, a refusal frees it",function()
   local pending=false;local answer=true;local record={again=0}
   local stage=open(844,390,{again=function()return {text="Hatch another  ★ 12",enabled=true,pending=pending,act=function()record.again+=1;pending=answer;return answer end}end})
   at(stage,R+.1);assert(stage.againButton.Visible and not stage:hatchAnother()and record.again==0,"live before the card settled")
   at(stage,R+Stage.SettleAfter+.1);assert(not stage:hatchAnother(),"inside the 0.4 s lock")
   at(stage,R+Stage.SettleAfter+Stage.AgainLock+.01)
   assert(stage.againButton:GetAttribute("AgainLive")==true and GuiService.SelectedObject~=stage.againButton,"live, never the default focus")
   assert(stage:hatchAnother()and record.again==1)
   assert(not stage:hatchAnother()and record.again==1,"a second press makes no second request")
   stage:step(1/30);assert(Kit.buttonState(stage.againButton).label.Text==Copy.get("hatch.result.hatching"),"the key shows the pending state")
   -- A refused press frees the key a second later (the host is no longer pending).
   local refused,rec2=open(844,390,{again=function()return {text="x",enabled=true,pending=false,act=function()return true end}end})
   at(refused,3.1);assert(refused:hatchAnother());refused.againPressedAt=os.clock()-2;refused:step(1/30);refused:paintAgain(true)
   assert(not refused.againPressed and refused.againButton:GetAttribute("AgainLive")==true)
   local _=rec2
   -- Disabled with its reason beside it.
   local poor=open(844,390,{again=function()return {text="x",enabled=false,reason="3 more Stars needed",act=function()return true end}end})
   at(poor,3.1);assert(Kit.buttonState(poor.againButton).label.Text=="3 more Stars needed"and not poor:hatchAnother())
   local none=open(844,390,{});at(none,3.1);assert(not none.againButton.Visible,"no again(): no key (pets)")
  end)
  test("the toy lid: halves close over the screen underneath, the iris opens, and it holds the hatch clock",function()
   local ready=false
   local stage=open(844,390,{lid=true,ready=function()return ready end})
   assert(stage:holdsClock(),"the lid holds the clock")
   stage.openClock=.1;stage:step(0)
   assert(stage.lidTop.Visible and stage.lidBottom.Visible and not stage.well.Visible,"the screen underneath shows between the closing halves")
   stage.openClock=.3;stage:step(0);assert(stage.lid.waiting and stage:holdsClock()and stage.lidEgg.Visible,"the shut lid is the waiting state")
   stage.openClock=1.3;stage:step(0);assert(stage.lid.waiting,"still waiting while the scene loads")
   ready=true;stage.openClock=1.4;stage:step(0);assert(stage.iris.Visible and stage.well.Visible and stage:holdsClock(),"the iris opens from the egg once ready")
   stage.openClock=2.2;stage:step(0);assert(not stage:holdsClock()and not stage.iris.Visible and not stage.lidTop.Visible,"open: the hatch clock runs")
   local l=Stage.lidSample(.1,true,0);assert(l.close>0 and l.close<1 and l.iris==0)
   assert(Stage.lidSample(.22+.30,true,0).done and not Stage.lidSample(.5,false,0).done)
  end)
  test("Tap to skip: never on the first hatch of an egg type; from the second on",function()
   Stage.seenTypes={}
   local first,record=open(844,390,{kind="feature"});at(first,.5)
   assert(not first.skippable and not first.skipChip.Visible)
   assert(not first:activate(first.buttons[2])and record.skips==0,"the first one plays in full")
   local second,rec2=open(844,390,{kind="feature"});second.openClock=.5;at(second,.5)
   assert(second.skippable and second.skipChip.Visible and second.skipText.Text==Copy.get("hatch.result.tapToSkip"))
   assert(not second:activate(second.buttons[2])and rec2.skips==1,"an early press only skips")
  end)
  test("actions mirror the host's receipt buttons and call them only once the receipt is ready",function()
   local stage,record,use,keep=open(844,390)
   at(stage,3.1)
   local secondary,primary=stage.buttons[1],stage.buttons[2]
   assert(primary.node.Visible and secondary.node.Visible and Kit.buttonState(primary.node).label.Text=="Use now"and Kit.buttonState(secondary.node).label.Text=="Store")
   assert(primary.node.AbsolutePosition.X>secondary.node.AbsolutePosition.X and primary.node.AbsoluteSize.Y>=44)
   assert(stage:activate(primary)and stage:activate(secondary)and table.concat(record.acts,",")=="use,store")
   use.Text="Give to Bear";keep.Interactable=false;task.wait();stage:step(1/30)
   assert(Kit.buttonState(primary.node).label.Text=="Give to Bear"and not stage:activate(secondary)and #record.acts==2)
   keep.Visible=false;task.wait();stage:step(1/30);assert(not secondary.node.Visible)
   assert(stage.close.Visible);stage.options.onClose();assert(record.closes==1)
   local draining=true
   local guarded,guardedRecord=open(844,390,{consumeSkipInput=function()return draining end});at(guarded,3.1)
   assert(not guarded:activate(guarded.buttons[2])and #guardedRecord.acts==0);draining=false;assert(guarded:activate(guarded.buttons[2]))
  end)
  test("QA R1: every hatch result has one fun line (60 characters at most), shown only with the name",function()
   local Shared=game:GetService("ReplicatedStorage").Shared
   local Toys=require(Shared.ToyCatalog);local Materials=require(Shared.MaterialCatalog);local Hues=require(Shared.HueCatalog);local Features=require(Shared.FeatureCatalog)
   local seen={}
   local function check(kind,field,id)
    local line=Stage.describe(kind,{[field]=id})
    assert(type(line)=="string"and #line>0 and utf8.len(line)<=60,kind.." "..id.." line length")
    assert(Copy.has("hatch.reveal.describe."..kind.."."..id),kind.." "..id.." has no line of its own")
    assert(not seen[line],"two items share a line: "..line);seen[line]=true
   end
   for id in pairs(Toys.ById)do if id~=Toys.Default then check("toy","toyId",id)end end
   for id in pairs(Materials.ById)do if id~=Materials.Default then check("material","finishId",id)end end
   for _,id in ipairs(Hues.ItemOrder)do check("hue","itemId",id)end
   for _,id in ipairs(Features.Order)do check("feature","featureId",id)end
   local stage=open(844,390,{result={toyId="squeaky_carrot"}})
   at(stage,R-.02);assert(stage.describe.Text==""and not stage.lines.Visible)
   at(stage,R+.5);task.wait()
   assert(stage.lines.Visible and stage.describe.Text==Copy.get("hatch.reveal.describe.toy.squeaky_carrot")and stage.hostLine.Text=="Choose a pet for this toy.")
   local snack=open(844,390,{kind="stat",tier="Uncommon",effect=function()return "2x for your next 120 XP"end,description=function()return ""end})
   at(snack,R+.5);task.wait()
   assert(snack.effect.Visible and snack.describe.AbsolutePosition.Y>=snack.effect.AbsolutePosition.Y+snack.effect.AbsoluteSize.Y-1,"the effect line sits above the fun line")
  end)
  test("a 3D result turns once named (never under Reduced Motion); a reopen starts settled and silent",function()
   local stage,record=open(844,390)
   at(stage,R-.05);assert((record.spin or 0)==0)
   at(stage,R+.02);for _=1,30 do stage:step(1/30)end;assert(record.spin and record.spin>0)
   local still,quiet=open(844,390,{reduced=function()return true end})
   at(still,.7);for _=1,30 do still:step(1/30)end;assert((quiet.spin or 0)==0)
   local reopened,again=open(844,390,{instant=true,tier="Rare"});reopened:step(1/30);for _=1,20 do reopened:step(1/30)end
   assert(reopened:isSettled()and reopened.name.Text=="SQUEAKY CARROT"and(again.spin or 0)>0 and not reopened.stamp.Visible)
   for _,o in ipairs(reopened.pieces)do assert(not o.Visible)end
   reopened:destroy();reopened:destroy();assert(again.releases==1 and reopened.root.Parent==nil)
  end)
  test("the way out: the iris closes on the item, then the lid opens; Reduced Motion fades; Hatch another keeps the shell up",function()
   local unseen=open(844,390);assert(unseen:dismiss()==false and not unseen.leaving)
   local stage,record,_,_,host=open(844,390)
   at(stage,3.1);assert(stage.seenAt~=nil)
   local done=0
   assert(stage:dismiss(function()done+=1 end)==true and stage.leaving and stage.root:GetAttribute("Leaving")==true)
   if stage.connection then stage.connection:Disconnect();stage.connection=nil end
   local out=stage.root.Parent
   assert(out:IsA("ScreenGui")and out.Name=="RevealExit"and not host:FindFirstChild("ItemRevealStage"))
   assert(not stage:owned()and not stage:activate(stage.buttons[2])and #record.acts==0)
   stage:paintLeave(.12);assert(stage.iris.Visible and stage.iris.Size.X.Offset<960 and stage.well.Visible,"the iris closes on the item")
   stage:paintLeave(.40);assert(not stage.well.Visible and stage.lidTop.Visible and stage.lidTop.Position.Y.Offset<0,"then the lid opens onto the destination")
   assert(record.releases==0 and done==0,"the borrowed scene stays until the stage is gone")
   stage:paintLeave(Stage.LeaveTime);assert(stage.destroyed and done==1 and record.releases==1 and out.Parent==nil)
   local calm=open(844,390,{reduced=function()return true end})
   at(calm,.7);assert(calm:dismiss()==true);if calm.connection then calm.connection:Disconnect();calm.connection=nil end
   calm:paintLeave(.08);assert(calm.flat.Visible and calm.flat.BackgroundTransparency<1 and calm.flat.BackgroundTransparency>0)
   calm:paintLeave(1);assert(calm.destroyed)
   -- Hatch another: the old stage stays up until the next one takes over, without its lid.
   local first,firstRecord=open(844,390);at(first,3.1);local gone=0
   assert(first:dismiss(function()gone+=1 end,{handover=true})and Stage.handover==first)
   assert(first.root.Active and first.againButton.Interactable==false,"the kept-up stage swallows taps; its keys stay, disabled (round 3)")
   if first.connection then first.connection:Disconnect();first.connection=nil end
   local nextStage=open(844,390,{lid=true})
   assert(first.destroyed and gone==1 and firstRecord.releases==1 and not nextStage.useLid and Stage.handover==nil,"the next egg drops into the well")
  end)
 end)
 for _,stage in ipairs(stages)do pcall(function()stage:destroy()end)end
 Stage.handover=nil
 gui:Destroy()
 assert(ok,problem)
 return{passed=#cases,cases=cases}
end
