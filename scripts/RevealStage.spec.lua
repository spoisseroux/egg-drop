-- Studio Client. Full-screen hatch reveal stage (UI-SPEC-REDESIGN-CELEBRATIONS 1):
-- timeline sample(t), Reduced Motion, accent rule, spin decay, headline choice,
-- layout, a live stage and the EggHatchView hand-off. No remotes or saves.
-- Usage: require(PlayerScripts.Client.ZZSpecs.RevealStage)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Stage=require(client.RevealStage)
 local Pets=require(game:GetService("ReplicatedStorage").Shared.PetCatalog)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function near(a,b,eps)return math.abs(a-b)<=(eps or 1e-3)end
 local gui=Instance.new("ScreenGui");gui.Name="_RevealStageSpec";gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=parent
 local stages={}
 local ok,problem=pcall(function()
  test("timeline: each beat starts on its millisecond and every lane stays bounded",function()
   local s=Stage.sample(0);assert(s.dark==0 and s.shown==0 and s.colour==0 and s.flash==0 and not s.burstAlive and math.abs(s.headline)<1e-6 and s.plate==0 and not s.input)
   assert(near(Stage.sample(.121).dark,1,.01)and Stage.sample(.119).spot<.01)
   assert(near(Stage.sample(.301).spot,1,.02)and Stage.sample(.299).streak<.01 and near(Stage.sample(.521).streak,1,.01))
   assert(Stage.sample(.419).colour==0 and near(Stage.sample(.541).colour,1,.01))
   assert(near(Stage.sample(.42).flash,.6,.01)and Stage.sample(.701).flash<.01 and Stage.sample(.43).burstAlive and not Stage.sample(.91).burstAlive)
   assert(math.abs(Stage.sample(.479).headline)<1e-6 and Stage.sample(.599).plate==0 and Stage.sample(.839).desc==0)
   assert(near(Stage.sample(.841).plate,1,.01)and near(Stage.sample(1.001).desc,1,.01))
   assert(Stage.sample(.601).letters==1 and Stage.sample(.641).letters==2 and Stage.sample(.5).letters==0)
   assert(not Stage.sample(.999).input and Stage.sample(1.0).input and not Stage.sample(1.13).settled and Stage.sample(1.14).settled)
   assert(Stage.sample(.559).greet==false and Stage.sample(.56).greet)
   assert(Stage.sample(.12).spinIn==540 and Stage.sample(.43).spinIn<1)
   for t=0,1.3,.01 do
    local x=Stage.sample(t)
    for _,key in ipairs({"dark","spot","rise","shown","streak","colour","flash","burst","headline","plate","desc","buttons"})do
     assert(x[key]>=-.15 and x[key]<=1.15,key.." out of range at "..t)
    end
    assert(x.streakGlow>=1 and x.streakGlow<=3)
   end
  end)
  test("Reduced Motion: one 150 ms cross-fade to the settled frame, no flash, burst or spin-in",function()
   local a,b,c=Stage.reducedSample(0),Stage.reducedSample(.075),Stage.reducedSample(.15)
   assert(a.reduced and a.fade==0 and near(b.fade,.5)and c.fade==1 and not a.settled and c.settled)
   assert(a.flash==0 and not a.burstAlive and a.spinIn==0 and a.plate==1 and a.headline>=.99 and a.desc==1 and a.buttons>=.99)
  end)
  test("accent: undyed grey becomes Stars gold, dyed secondaries are lifted to read on black",function()
   local gold=Color3.fromHex("#FFC14D")
   assert(Stage.accent(Color3.fromHex("#A8A5AE"))==gold and Stage.accent(nil)==gold)
   local rose=Color3.fromHex("#FF327A");local lifted=Stage.accent(rose)
   local h0=rose:ToHSV();local h,s,v=lifted:ToHSV();assert(near(h,h0)and s>=.55 and v>=.9)
   local _,s2,v2=Stage.accent(Color3.fromHex("#1A2A60")):ToHSV();assert(s2>=.55 and v2>=.9-1e-6)
   local _,s3=Stage.accent(Color3.fromHex("#E8D6F2")):ToHSV();assert(s3>=.55-1e-6)
   assert(Stage.accentFor("pip",nil)==gold,"an undyed Bear gets the gold plate")
   assert(Stage.accentFor("pip",{secondary="tide"})~=gold,"a dyed secondary takes over")
   assert(Stage.ink(gold)==Color3.fromHex("#0E0F12")and Stage.ink(Color3.fromRGB(40,60,255))==Color3.new(1,1,1))
   assert(Stage.contrast(gold,Color3.fromHex("#0E0F12"))>=4.5)
  end)
  test("spin: exponential decay (0.55 s), stop under 4°/s, 80 ms release window, 1080°/s cap, spring home",function()
   assert(Stage.decay(1000,0)==1000 and near(Stage.decay(1000,.55),1000/math.exp(1),.01))
   assert(Stage.decay(5,.05)>4 and Stage.decay(4.2,.1)==0 and Stage.decay(-4.2,.1)==0)
   local omega,angle=1000,0
   for _=1,600 do angle+=omega/60;omega=Stage.decay(omega,1/60);if omega==0 then break end end
   assert(omega==0 and math.abs(angle-Stage.coast(1000))<Stage.coast(1000)*.03,"coast "..angle)
   assert(near(Stage.releaseSpeed({{t=0,yaw=0},{t=.05,yaw=30},{t=.1,yaw=60}},.1),600,1))
   assert(Stage.releaseSpeed({{t=0,yaw=0},{t=.01,yaw=100}},.01)==1080 and Stage.releaseSpeed({{t=0,yaw=0},{t=.01,yaw=-100}},.01)==-1080)
   assert(Stage.releaseSpeed({},0)==0 and near(Stage.coast(Stage.flickSpeed(1)),45))
   local yaw,velocity=300,0
   for _=1,240 do yaw,velocity=Stage.springStep(yaw,velocity,1/60)end
   assert(math.abs(Stage.wrap(yaw-Stage.Spin.home))<1,"spring settles on the three-quarter pose, got "..yaw)
  end)
  test("headline and tag strip follow the result",function()
   assert(Stage.tagKind({petId="pip"},"companion")=="new"and Stage.tagKind({rare=true},"companion")=="rare")
   assert(Stage.tagKind({duplicate=true,rare=true},"companion")=="owned"and Stage.tagKind({},"toy")=="saved")
   local h=Stage.headline("new");assert(h[1]=="A NEW"and h[2]=="LITTLE WONDER!")
   assert(Stage.headline("rare")[2]=="DISCOVERY!"and Stage.headline("owned")[1]=="ALREADY"and Stage.headline("saved")[2]=="YOUR GARDEN!")
   assert(Stage.tagStrip(Pets.byId.pip,"new")=="No. 01 · NEW FRIEND")
   assert(Stage.tagStrip(Pets.byId.foxfire_wick,"new"):find("RARE FRIEND",1,true))
  end)
  test("layout: desktop and phone match the mockup numbers; phone stays under the Roblox controls",function()
   local d=Stage.geometry(1920,1080)
   assert(not d.phone and d.petX==800 and d.feet==842 and d.plateX==1010 and d.plateY==640 and d.btnY==968 and d.meetW==300 and d.playW==240)
   assert(d.descX==1108 and d.descY==878 and d.headX==88 and d.headY==76)
   local p=Stage.geometry(812,354)
   assert(p.phone and p.petX==268 and p.feet==306 and p.plateY==104 and p.btnY==292 and p.btnH==48 and p.descY==198)
   assert(p.headY>=60 and p.plateY-p.plateTag*1.6>=60,"nothing but the stage under y 60")
   for _,L in ipairs({d,p,Stage.geometry(568,320),Stage.geometry(360,580)})do
    assert(L.tagSize>=12 and L.descSize>=12 and L.hintSize>=12 and L.plateTag>=12 and L.btnH>=44)
   end
  end)
  test("beta 14 Q3: on a phone the buttons keep clear of the stage card (shot 2 at 844 x 390)",function()
   for _,size in ipairs({{667,375},{740,360},{812,354},{812,375},{844,390},{932,430}})do
    local L=Stage.geometry(size[1],size[2])
    local x,_,w=Stage.wellRect(L)
    local rowLeft=L.W-L.margin-L.meetW-L.gap-L.playW
    assert(L.phone and L.playW>=Stage.PlayMin and w>=math.floor(L.petBox*1.3),size[1].."x"..size[2])
    assert(rowLeft>=x+w+Stage.RowClear,"buttons clear of the card at "..size[1].."x"..size[2]..": "..rowLeft.." vs "..(x+w))
   end
   local d=Stage.geometry(1920,1080);assert(d.wellW==nil and d.playW==240,"desktop unchanged")
  end)
  test("pet descriptions exist, one line of at most 60 characters; Bear's is the approved line",function()
   assert(Pets.byId.pip.description=="Soft as a nap. Hugs first, asks questions never.")
   for _,pet in ipairs(Pets.collection)do assert(type(pet.description)=="string"and #pet.description>0 and utf8.len(pet.description)<=60,pet.id)end
  end)
  test("QA R5: the pet is lit flat and bright with a soft glow behind it, and it waves every few seconds",function()
   local L,W=Stage.Light,Stage.Wave
   local function lum(c)return .2126*c.R+.7152*c.G+.0722*c.B end
   assert(lum(L.ambient)>=.75 and lum(L.color)<=.45 and L.direction.Z<0 and math.abs(L.direction.Y)<math.abs(L.direction.Z),"a bright ambient and a soft light from the front, not a hard top light")
   local rest=Stage.wavePose(-1,0,false);assert(rest.handR==W.rest and rest.handL==W.restL and not rest.waving,"at rest before the greeting")
   local up=Stage.wavePose(W.raise+.01,5,false);assert(up.waving and up.handR>.9 and up.headRoll<0,"the arm goes up")
   local lo,hi=math.huge,-math.huge
   for t=W.raise,W.raise+W.wag,.01 do local pose=Stage.wavePose(t,t,false);lo=math.min(lo,pose.handR);hi=math.max(hi,pose.handR)end
   assert(hi-lo>.35,"and the hand wags")
   assert(not Stage.wavePose(W.raise+W.wag+W.lower+.1,0,false).waving and Stage.wavePose(W.period+W.raise+.01,0,false).waving,"it rests, then waves again")
   local calm=Stage.wavePose(W.raise+.1,0,true);assert(not calm.waving and calm.handR==W.rest,"Reduced Motion holds the resting pose")
   for t=0,8,.02 do
    local pose=Stage.wavePose(t,t,false)
    assert(pose.handR>=W.rest-.01 and pose.handR<=W.up+W.swing+.01 and pose.blink>0 and pose.blink<=1 and math.abs(pose.stretch)<.02 and pose.heroScale==1,"bounded at "..t)
   end
   local host=Instance.new("Frame");host.Size=UDim2.fromOffset(812,354);host.BackgroundTransparency=1;host.Parent=gui
   local stage=Stage.show(host,{pet=Pets.byId.pip,tag="new",reduced=false,buttons={{id="meet",text="Meet Bear",primary=true}}})
   table.insert(stages,stage);stage.connection:Disconnect();stage.connection=nil
   assert(stage.viewport.Ambient==L.ambient and stage.viewport.LightColor==L.color and #stage.petGlow==L.glowDiscs,"the stage uses the soft light")
   assert(not stage.petGlow[1].Visible or stage.petGlow[1].BackgroundTransparency==1,"no glow on the silhouette")
   for _=1,6 do stage:step(.1)end
   assert(stage.waveAt~=nil and stage.petGlow[1].Visible and stage.petGlow[1].BackgroundTransparency<1,"the glow comes up with the colour, and the wave starts on the greeting beat")
   if stage.visual then
    local waved=false
    for _=1,60 do stage:step(.05);local pose=stage.visual.revealPose;if pose and pose.waving and pose.handR>.9 then waved=true end end
    assert(waved,"the Bear waves on the stage")
   end
   stage:destroy();host:Destroy()
  end)
  test("QA R4: a stage on screen leaves in its own gui (content into the dark, then the dark lifts); Play again's cover stays dark",function()
   local C=require(client.CelebrationKit)
   local host=Instance.new("Frame");host.Size=UDim2.fromOffset(812,354);host.BackgroundTransparency=1;host.Parent=gui
   local function show()
    local stage=Stage.show(host,{pet=Pets.byId.pip,tag="new",reduced=false,instant=true,buttons={{id="play",text="Play again"},{id="meet",text="Meet Bear",primary=true}}})
    table.insert(stages,stage);stage.connection:Disconnect();stage.connection=nil;return stage
   end
   local unseen=show();assert(unseen:dismiss()==false and not unseen.destroyed,"a stage that never drew is destroyed by its caller");unseen:destroy()
   local stage=show();stage:step(1/30);assert(stage.seenAt~=nil)
   local before=stage.root.AbsolutePosition;local done=0
   assert(stage:dismiss(function()done+=1 end)==true and stage.leaving and not stage:owned())
   if stage.connection then stage.connection:Disconnect();stage.connection=nil end
   local out=stage.root.Parent
   assert(out:IsA("ScreenGui")and out.Name=="RevealExit"and out.DisplayOrder==gui.DisplayOrder+1 and not host:FindFirstChild("RevealStage"))
   task.wait();assert((stage.root.AbsolutePosition-before).Magnitude<1.5,"at the same place on screen")
   assert(stage:activate(2)==false,"a leaving stage takes no input")
   local pet=stage.petHolder.Size
   stage:paintLeave(.06);assert(stage.cover.Visible and stage.cover.BackgroundTransparency>0 and stage.cover.BackgroundTransparency<1 and stage.root.BackgroundTransparency==0)
   assert(stage.petHolder.Size.X.Offset<pet.X.Offset,"the pet eases down a little as it goes")
   stage:paintLeave(C.LeaveTime*.8);assert(stage.root.BackgroundTransparency==1 and not stage.petLayer.Visible and stage.cover.BackgroundTransparency>.3)
   stage:paintLeave(C.LeaveTime);assert(stage.destroyed and done==1 and out.Parent==nil)
   -- After "Play again" the cover is already dark: the leave must not flash the stage back.
   local again=show();again:step(1/30);again:exit("play");again.clock+=.2;again:paint()
   assert(again.cover.Visible and again.cover.BackgroundTransparency==0,"Play again fades the stage out under its cover")
   assert(again:dismiss()==true);if again.connection then again.connection:Disconnect();again.connection=nil end
   again:paintLeave(.01);assert(again.cover.BackgroundTransparency==0,"still dark");again:paintLeave(C.LeaveTime);assert(again.destroyed)
   host:Destroy()
  end)
  test("QA R3: the name plate's slanted end is one triangle on the plate's own edges, with no loose block",function()
   for _,h in ipairs({44,60,96,168})do
    local w,rotation,from,to=Stage.slantEnd(h,2)
    assert(math.abs(w-h*math.tan(math.rad(Stage.PlateSlant)))<=.5 and math.abs(rotation-Stage.PlateSlant)<1.5,"a 16 degree slant at "..h)
    assert(from>0 and from<to and to<1 and to-from<.08 and math.abs((from+to)*.5-.5)<.06,"one sharp cut near the diagonal at "..h)
   end
   for _,size in ipairs({{812,354},{1920,1080}})do
    local host=Instance.new("Frame");host.Size=UDim2.fromOffset(size[1],size[2]);host.BackgroundTransparency=1;host.Parent=gui
    local stage=Stage.show(host,{pet=Pets.byId.pip,tag="new",reduced=false,instant=true,buttons={{id="meet",text="Meet Bear",primary=true}}})
    table.insert(stages,stage);stage.connection:Disconnect();stage.connection=nil
    local L=stage.L;local cut,body=stage.plateCut,stage.plateBody
    assert(cut.Rotation==0 and cut.AnchorPoint==Vector2.zero and cut.BackgroundColor3==body.BackgroundColor3 and cut.BackgroundTransparency==0,"same colour, not a turned block")
    assert(cut.Position.Y.Offset==0 and cut.Size.Y.Offset==L.plateH and body.Position.Y.Offset==0 and body.Size.Y.Offset==L.plateH,"the end shares the plate's top and bottom edges")
    assert(cut.Position.X.Offset<0 and cut.Position.X.Offset+cut.Size.X.Offset>=1 and cut.Position.X.Offset+cut.Size.X.Offset<=3,"the end starts left of the plate and overlaps it, so no gap shows")
    local keys=stage.plateCutGradient.Transparency.Keypoints
    assert(#keys==4 and keys[1].Value==1 and keys[2].Value==1 and keys[3].Value==0 and keys[4].Value==0,"clear above the cut, solid below it")
    stage:destroy();host:Destroy()
   end
  end)
  test("live stage: a press before the buttons settles without acting; then Meet and Play again act",function()
   local host=Instance.new("Frame");host.Size=UDim2.fromOffset(812,354);host.BackgroundTransparency=1;host.Parent=gui
   local pressed,skips,cues={},0,{}
   local audio={deviceActive=true};function audio:play(name)table.insert(cues,name);return false end
   local stage=Stage.show(host,{pet=Pets.byId.pip,tag="new",audio=audio,reduced=false,
    buttons={{id="play",text="Play again",glyph="B"},{id="meet",text="Meet Bear",glyph="A",primary=true}},
    onButton=function(id)table.insert(pressed,id)end,onSkip=function()skips+=1 end})
   table.insert(stages,stage)
   stage.connection:Disconnect();stage.connection=nil
   assert(cues[1]=="reveal_hush"and stage.root.BackgroundTransparency==1,"stage starts over the egg scene")
   for _=1,5 do stage:step(.1)end
   assert(not stage:isSettled()and table.find(cues,"reveal_shimmer")and table.find(cues,"tag_slam"))
   assert(stage.name.Text=="BEAR"and stage.plateTag.Text=="No. 01 · NEW FRIEND"and stage.desc.Text==Pets.byId.pip.description)
   assert(stage.headline.label.Text=="LITTLE WONDER!"and stage.accent==Color3.fromHex("#FFC14D"))
   assert(stage:confirm()and #pressed==0 and skips==1 and stage:isSettled(),"first press only settles")
   assert(stage.buttons[2].node.Visible and stage.root.BackgroundTransparency==0)
   assert(stage:confirm()and pressed[1]=="meet");assert(stage:back()and pressed[2]=="play")
   stage.focus=2;stage:setButtons({meet={text="Saving…",enabled=false}});assert(not stage:confirm()and #pressed==2)
   stage.omega=500;stage:stepIdle(.1);assert(stage.omega>0 and stage.omega<500)
   stage:destroy();assert(not host:FindFirstChild("RevealStage"))
   host:Destroy()
  end)
  test("Reduced Motion live stage: cross-fade, still idle, spin stops on release",function()
   local host=Instance.new("Frame");host.Size=UDim2.fromOffset(1920,1080);host.BackgroundTransparency=1;host.Parent=gui
   local cues={};local audio={deviceActive=true};function audio:play(name,_,volume)table.insert(cues,{name=name,volume=volume});return false end
   local stage=Stage.show(host,{pet=Pets.byId.pip,audio=audio,reduced=true,fresh=true,instant=true,voice=false,buttons={{id="meet",text="Meet Bear",primary=true}}})
   table.insert(stages,stage);stage.connection:Disconnect();stage.connection=nil
   assert(stage.reducedStart and not stage:isSettled()and cues[1].name=="reveal_shimmer"and cues[1].volume<.5)
   stage:step(.1);stage:step(.1);assert(stage:isSettled()and stage.flash.BackgroundTransparency==1)
   local yaw=stage.yaw;stage.omega=500;stage:stepIdle(.1);assert(stage.omega==0)
   stage.lastTouch=-math.huge;stage.homed=true;stage:stepIdle(1);assert(stage.yaw==yaw,"no self-turn under Reduced Motion")
   local quiet=Stage.show(host,{pet=Pets.byId.pip,audio=audio,reduced=true,instant=true})
   table.insert(stages,quiet);assert(quiet:isSettled()and #cues==1,"a reopened reveal is silent and settled")
   stage:destroy();quiet:destroy();host:Destroy()
  end)
  test("EggHatchView hands the hatch to the full-screen stage and Meet acknowledges through it",function()
   local View=require(client.EggHatchView)
   local host=Instance.new("Frame");host.Size=UDim2.fromOffset(812,354);host.BackgroundTransparency=1;host.Parent=gui
   local sent={}
   local view=View.new(host,{play=function()end},function()return true end,function(command,value)table.insert(sent,{command=command,value=value})end)
   view.nativeDisplay=false -- Legacy Stage/button contract; native delegation has its own host/scene fixtures.
   view:open({status="Ready",revision=10,lastHatch={id="stage-fixture",petId="pip",starter=true},nectar=6})
   local stage=view.reveal
   assert(stage and view.stageLayer.Visible and not view.card.Interactable,"stage covers the card")
   assert(view.shade and view.revealHost and view.body and view.ackReady==true,"fields init.client.lua reads are intact")
   local meet=stage:primaryButton();assert(meet and require(client.DeckKit).buttonState(meet).label.Text=="Meet Bear")
   if stage.connection then stage.connection:Disconnect();stage.connection=nil end
   -- step clamps dt to 0.1; a fresh reduced reveal needs 0.15 s to settle.
   stage:step(.1);stage:step(.1);assert(stage:isSettled())
   assert(stage:confirm()and #sent==1 and sent[1].command=="ack"and sent[1].value=="stage-fixture")
   -- While Meet saves, Play again is unavailable: B falls through to close() (slice D fix).
   assert(not view:revealBack())
   view:close("close");assert(view.reveal==nil and not view.stageLayer.Visible and view.card.Interactable)
   view.shade:Destroy();host:Destroy()
  end)
  test("QA v2 R1.1: the confetti popper fires from both bottom corners, arcs up and falls out",function()
   local W,H=1920,1080
   assert(Stage.confetti(1,-.01,W,H)==nil and Stage.confetti(1,Stage.ConfettiLife+.01,W,H)==nil,"only while alive")
   local left,right,peak=0,0,H
   for i=1,Stage.ConfettiCount do
    local x0=Stage.confetti(i,0,W,H)
    assert(x0,"every piece starts on screen")
    if x0<W/2 then left+=1 else right+=1 end
    for t=0,Stage.ConfettiLife,.05 do
     local x,y,_,share,fade=Stage.confetti(i,t,W,H)
     if x then
      peak=math.min(peak,y);assert(share>=0 and share<=1 and fade>=0 and fade<=1)
      assert(x>-W*.1 and x<W*1.1,"stays near the frame")
     end
    end
    local a={Stage.confetti(i,.7,W,H)};local b={Stage.confetti(i,.7,W,H)};assert(a[1]==b[1]and a[2]==b[2],"deterministic")
   end
   assert(left==Stage.ConfettiCount/2 and right==Stage.ConfettiCount/2,"two poppers")
   assert(peak<H*.6,"the pieces reach up the stage")
  end)
  test("QA v2 R1.1: a first view pops once with its cue; a reopen and Reduced Motion never do",function()
   local host=Instance.new("Frame");host.Size=UDim2.fromOffset(812,354);host.BackgroundTransparency=1;host.Parent=gui
   local cues={};local audio={deviceActive=true};function audio:play(name)table.insert(cues,name);return false end
   local stage=Stage.show(host,{pet=Pets.byId.pip,audio=audio,reduced=false,buttons={{id="meet",text="Meet Bear",primary=true}}})
   table.insert(stages,stage);stage.connection:Disconnect();stage.connection=nil
   for _=1,4 do stage:step(.1)end;assert(not stage.popAt,"not before the colour burst")
   stage:step(.1);assert(stage.popAt and table.find(cues,Stage.PopCue),"pops with the burst")
   local shown=0;for _,piece in ipairs(stage.confettiPieces)do if piece.Visible then shown+=1 end end
   assert(shown>0,"pieces on screen")
   local count=#cues;stage:settle();assert(#cues==count,"one pop only")
   for _=1,25 do stage:step(.1)end
   assert(not stage:confettiAlive()and not stage.confettiPieces[1].Visible,"the pieces are gone")
   local again=Stage.show(host,{pet=Pets.byId.pip,audio=audio,reduced=false,instant=true})
   table.insert(stages,again);again:settle();assert(not again.popAt,"a reopen does not pop")
   local calm=Stage.show(host,{pet=Pets.byId.pip,audio=audio,reduced=true,fresh=true})
   table.insert(stages,calm);calm:settle();assert(not calm.popAt,"no confetti under Reduced Motion")
   stage:destroy();again:destroy();calm:destroy();host:Destroy()
  end)
  test("QA v2 R1.2/R1.5: the stage layer covers the screen; the first Bear's B is Back, not Play again",function()
   local View=require(client.EggHatchView);local Kit=require(client.DeckKit)
   assert(View.secondaryIntent({starter=true})=="exit"and View.secondaryIntent({})=="play"and View.secondaryIntent(nil)=="play")
   assert(View.closeReason("exit")=="exit"and View.closeReason("meet")=="meet"and View.closeReason("play")=="afterHatch")
   local host=Instance.new("Frame");host.Size=UDim2.fromOffset(812,354);host.BackgroundTransparency=1;host.Parent=gui
   local sent={}
   local view=View.new(host,{play=function()end},function()return true end,function(command,value)table.insert(sent,{command=command,value=value})end)
   view.nativeDisplay=false -- This case inspects the legacy Stage/DeckKit button implementation.
   assert(view.stageLayer:GetAttribute("CoversScreen")and view.revealBackdrop:GetAttribute("CoversScreen"),"full-screen layers")
   view:open({status="Ready",revision=10,lastHatch={id="starter-fixture",petId="pip",starter=true},nectar=6})
   local stage=view.reveal;assert(stage,"stage open")
   assert(view.revealBackdrop.Visible and view.card.BackgroundTransparency==1 and view.cinematic.frame.BackgroundTransparency==1,"no card rect over the black")
   local back;for _,entry in ipairs(stage.buttons)do if not entry.primary then back=entry end end
   assert(back and back.id=="exit"and Kit.buttonState(back.node).label.Text==require(game:GetService("ReplicatedStorage").Shared.UICopy).get("r1.reveal.exit"))
   if stage.connection then stage.connection:Disconnect();stage.connection=nil end
   stage:step(.1);stage:step(.1);assert(stage:isSettled())
   assert(stage:back()and #sent==1 and sent[1].command=="ack","B acknowledges the starter")
   assert(view.ackIntent and view.ackIntent.intent=="exit"and view.ackIntent.starter==true)
   view:close("close");view.shade:Destroy();host:Destroy()
  end)
  -- QA v685 H1 (2026-11-15): the native egg opening is the lead-in on this stage.
  test("egg lead-in: the egg plays on the stage, the entrance waits, then runs; a skip settles with the popper",function()
   local Pose=require(client.HatchDisplayPose)
   assert(Stage.LeadIn+Stage.InputAt==Pose.BearReady,"the receipt unlocks as the buttons open")
   local a,b,c=Stage.leadSample(0),Stage.leadSample(1.0),Stage.leadSample(Stage.LeadOut)
   assert(a.glow==0 and a.flash==0 and a.egg==1 and not a.done and b.flash>.3 and b.egg==1 and not b.done and c.egg==0 and c.done and c.flash==0)
   assert(Stage.leadSample(.5).glow<Stage.leadSample(.9).glow and Stage.leadSample(Stage.LeadIn).done)
   local record={borrows=0,releases=0,bare=nil}
   local function fakeScene()
    local s={ready=true,root=Instance.new("Frame")}
    function s:borrow(seat)record.borrows+=1;self.root.Parent=seat;return self end
    function s:release(token)assert(token==self);record.releases+=1;self.root.Parent=nil end
    function s:setBare(bare,hideHero)record.bare={bare,hideHero}end
    function s:layout()end
    function s:groundPoint()return Vector2.new(.5,.75)end
    return s
   end
   local function open(extra)
    local host=Instance.new("Frame");host.Size=UDim2.fromOffset(812,354);host.BackgroundTransparency=1;host.Parent=gui
    local options={pet=Pets.byId.pip,scene=fakeScene(),externalClock=true,owns=function()return true end,reduced=function()return false end,
     buttons={{id="exit",text="Back"},{id="meet",text="Meet Bear",primary=true}}}
    for key,value in pairs(extra or {})do options[key]=value end
    local stage=Stage.show(host,options);table.insert(stages,stage)
    if stage.connection then stage.connection:Disconnect();stage.connection=nil end
    return stage,host
   end
   local skipped=0
   local stage,host=open({onSkip=function()skipped+=1 end})
   assert(record.borrows==1 and record.bare[1]==true and record.bare[2]==true,"the scene is borrowed bare with its own pet hidden")
   -- QA R4 / v735 H1: the stage dims in from the world (0.34 s of real time), then its spotlight and pool.
   local seat=stage.lead.seat;assert(seat.Visible and stage.root.BackgroundTransparency>0 and stage.cone[1].light.BackgroundTransparency>stage.cone[1].base,"the stage opens from the world, not with a pop")
   task.wait(require(client.CelebrationKit).OpenSettle+.05);stage:step(0);assert(stage.root.BackgroundTransparency==0 and math.abs(stage.cone[1].light.BackgroundTransparency-stage.cone[1].base)<1e-4,"the egg sits on the black stage")
   -- The egg's contact point lands on the floor pool under the spotlight.
   local L=stage.L;local p,sz=seat.AbsolutePosition-host.AbsolutePosition,seat.AbsoluteSize
   assert(near(p.X+sz.X*.5,L.petX,2)and near(p.Y+sz.Y*.75,L.feet,2),"egg seat off the pool")
   for _=1,9 do stage:updateExternal(_*.1,{inputLocked=true,receiptReady=false});stage:step(.1)end
   assert(stage.age==0 and not stage.lead.done and not stage:isSettled(),"the entrance ran during the lead-in")
   assert(stage.cone[1].clip.Visible and stage.pool[1].node.Visible and stage.viewport.ImageTransparency==1,"spotlight and pool hold the egg; no pet yet")
   stage:updateExternal(1.06,{inputLocked=true,receiptReady=false});assert(stage.lead.done)
   stage:step(1/30);assert(stage.cone[1].clip.Visible and stage.pool[1].node.Visible,"the spotlight dropped out at the hand-off")
   stage.loaded=true;stage:step(.1);stage:step(.1);assert(near(stage.age,.2+1/30,1e-6)and seat.Visible,"egg shells still clearing at 1.26")
   stage:updateExternal(1.36,{inputLocked=true,receiptReady=false});stage:step(.1);assert(not seat.Visible)
   for _=1,10 do stage:step(.1)end
   assert(stage:isSettled()and stage.popAt~=nil and skipped==0,"natural run settles with its popper and no skip")
   assert(stage.root:GetAttribute("InputLocked")==true)
   stage:destroy();assert(record.releases==1,"destroy returns the scene")
   -- A skip (the hatch clock jumps) lands settled, pops, and never calls onSkip back.
   stage=open({onSkip=function()skipped+=1 end})
   stage:updateExternal(.2,{inputLocked=true});stage:step(.1)
   stage:updateExternal(4.4,{inputLocked=false,receiptReady=true})
   assert(stage.lead.done and stage:isSettled()and stage.popAt~=nil and skipped==0 and not stage.lead.seat.Visible)
   -- A press on the stage during the lead-in skips through the host once.
   stage=open({onSkip=function()skipped+=1 end});stage:settle();assert(skipped==1 and stage:isSettled())
   -- The press that skipped never also presses Meet.
   local pressed=0;local draining=true
   stage=open({consumeSkipInput=function()return draining end,onButton=function()pressed+=1 end});stage:settle(true)
   assert(not stage:confirm()and pressed==0);draining=false;assert(stage:confirm()and pressed==1)
   -- An unfocused window: the hatch clock has not started, so the stage waits on the egg
   -- and plays in step once its owner is back (never a silent settled screen).
   local owned=false
   stage=open({owns=function()return owned end});stage:step(.1);stage:step(.1)
   assert(not stage:isSettled()and not stage.lead.done and stage.lead.seat.Visible and stage.age==0,"an unfocused hatch must wait on the egg")
   owned=true;for i=1,5 do stage:updateExternal(i*.2,{inputLocked=true})end;stage:step(.1);assert(not stage.lead.done and stage.age==0)
   stage:updateExternal(1.06,{inputLocked=true});stage:step(.1);assert(stage.lead.done and not stage:isSettled()and near(stage.age,.1,1e-6))
   -- Losing the owner once the hatch is running lands on the settled frame.
   owned=false;stage:step(.1);assert(stage:isSettled())
   -- A reopen and Reduced Motion have no lead-in.
   stage=open({instant=true});assert(stage.lead.done and not stage.lead.seat.Visible and stage:isSettled())
   stage=open({reduced=function()return true end,fresh=true});stage:step(.05);assert(stage.lead.done and not stage.lead.seat.Visible)
   stage:step(.2);assert(stage:isSettled()and stage.popAt==nil,"Reduced Motion has no popper")
  end)
  -- Round 3 (Spencer 2026-11-20): the Bunny's hatch is a Rare pet jackpot on the pet's own clock.
  test("Round 3: the Rare pet entrance (leap, stamp, three hops, late headline) keeps the input time; the Bear's is unchanged",function()
   local Pose=require(client.HatchDisplayPose);local Rarity=require(client.HatchRarityCue)
   assert(Rarity.tier("companion",{petId="blip"})=="Rare"and Rarity.tier("companion",{petId="pip"})=="Common")
   assert(Pose.readyAt("companion","Rare",false)==Pose.BearReady and not Rarity.timing("Rare","companion",false).jackpot,"no pet wind-up: the clock is the Bear's")
   for t=0,1.3,.01 do
    local a,b=Stage.sample(t),Stage.sample(t,false)
    assert(a.rare==nil and a.arc==nil and a.stamp==nil,"a Bear sample has no Rare lanes")
    for key,value in pairs(a)do assert(b[key]==value,key.." differs at "..t)end
   end
   local R=Stage.Rare;local S=function(t)return Stage.sample(t,true)end
   assert(S(.12).spinIn==720 and S(.47).spinIn<1 and Stage.sample(.12).spinIn==540,"720 deg against the Bear's 540")
   assert(near(S(.29).arc,R.arc,.01)and S(.48).arc==0 and near(S(.56).arc,.16,.01)and near(S(.71).arc,.07,.01)and S(.9).arc==0,"leap arc and two hops")
   assert(S(.40).squash==0 and near(S(.46).squash,.12,1e-3)and near(S(.62).squash,.06,.01)and S(1.14).squash==0,"three landings")
   assert(S(.24).stamp==0 and S(.25).stamp==1 and near(S(.25).stampScale,2.6,.01)and near(S(.37).stampScale,1,.01)and S(.38).stampShake>0)
   assert(S(.78).stamp==0 and R.stampLeave+R.stampOut<=R.headline,"the stamp is gone before the headline")
   assert(math.abs(S(.76).headline)<1e-6 and near(S(.98).headline,1,.02)and not S(.79).greet and S(.80).greet)
   assert(S(.81).plate==0 and S(.81).letters==0 and S(.821).letters==1 and S(.861).letters==2 and near(S(1.07).plate,1,.01))
   assert(not S(.999).input and S(1.0).input and not S(1.13).settled and S(1.14).settled,"input and settle as the Bear's")
   for t=0,1.3,.01 do local x=S(t);assert(x.stamp>=0 and x.stamp<=1 and x.arc>=0 and x.arc<=R.arc+1e-6 and x.squash>=-.12 and x.squash<=.13)end
   local calm=Stage.reducedSample(0,true)
   assert(calm.arc==0 and calm.squash==0 and calm.stamp==0 and Stage.reducedSample(.15,true).stamp==1 and Stage.reducedSample(.9,true).stamp==1)
   assert(Stage.reducedSample(1.05,true).stamp==0 and Stage.reducedSample(.15,true).settled and Stage.reducedSample(0).stamp==nil)
   assert(Stage.earFlick(.45)==0 and near(Stage.earFlick(.46),math.rad(22),1e-3))
  end)
  test("Round 3: the jackpot lanes land as the shell opens (0.98 on the hatch clock); Reduced Motion is the static calm frame",function()
   local J=Stage.jackpot
   assert(J(.97).rainbow==0 and J(.97).shock==nil and J(.97).punch==0 and J(.97).bloom==0)
   assert(J(.98).shock and J(.98).shock.radius==40 and J(.98).shake==3 and J(1.0).bloom>0 and J(1.4).bloom==0)
   assert(near(J(1.23).rainbow,1,1e-6)and J(1.481).shock==nil and J(1.2).shake==0 and near(J(2.2).shafts,.25,1e-3)and J(2.2).punch==0)
   local peak=0;for h=.98,1.6,.01 do peak=math.max(peak,J(h).punch)end;assert(peak>1,"the well punches open (Back overshoot)")
   local calm=J(1.0,true);assert(calm.rainbow==.6 and near(calm.shafts,.15,1e-6)and calm.shock==nil and calm.shake==0 and calm.punch==0)
   local names={};for _,beat in ipairs(Stage.RareCues)do names[beat[2]]=(names[beat[2]]or 0)+1 end
   assert(names.bear_boop==3 and names.tag_slam==1 and names.name_slam==1 and names.desc_tick==1)
   for _,dropped in ipairs({"reveal_hush","spot_on","streak_whoosh","reveal_shimmer",Stage.PopCue})do assert(names[dropped]==nil,dropped.." is dropped")end
   assert(Stage.RareCues[1][3]==1.25 and Stage.RareCues[2][3]==1.40 and Stage.RareCues[3][3]==1.55,"the boops rise")
  end)
  test("Round 3: a live Bunny stage draws the jackpot over its egg lead-in; a Bear stage builds none of it",function()
   local ItemStage=require(client.HatchItemStage)
   local host=Instance.new("Frame");host.Size=UDim2.fromOffset(812,354);host.BackgroundTransparency=1;host.Parent=gui
   local cues={};local audio={deviceActive=true};function audio:play(name,pitch)table.insert(cues,{name=name,pitch=pitch});return false end
   local function has(name,pitch)for _,c in ipairs(cues)do if c.name==name and(pitch==nil or math.abs(c.pitch-pitch)<1e-6)then return true end end;return false end
   local bear=Stage.show(host,{pet=Pets.byId.pip,audio=audio,reduced=false,buttons={{id="meet",text="Meet Bear",primary=true}}})
   table.insert(stages,bear);if bear.connection then bear.connection:Disconnect();bear.connection=nil end
   assert(not bear.jackpot and bear.edge==nil and bear.stamp==nil and bear.shock==nil and bear.backdrop.shafts==nil and #bear.burst==Stage.BurstCount)
   bear:destroy();table.clear(cues)
   local scene={ready=true,root=Instance.new("Frame")}
   function scene:borrow(seat)self.root.Parent=seat;return self end
   function scene:release()self.root.Parent=nil end
   function scene:setBare()end;function scene:layout()end;function scene:groundPoint()return Vector2.new(.5,.75)end
   local bunny=Stage.show(host,{pet=Pets.byId.blip,tag="rare",audio=audio,scene=scene,externalClock=true,owns=function()return true end,
    reduced=function()return false end,buttons={{id="meet",text="Meet Bunny",primary=true}}})
   table.insert(stages,bunny);if bunny.connection then bunny.connection:Disconnect();bunny.connection=nil end
   assert(bunny.jackpot and bunny.tier=="Rare"and #bunny.burst==Stage.Rare.burstCount and #bunny.cannonPieces==ItemStage.Cannon.count*2)
   local ring=ItemStage.edgeRing(Stage.Rare.edgeRadius.phone,Stage.Rare.edgeBand)
   assert(bunny.edgeCorner.CornerRadius.Offset==ring.corner and bunny.edge.Position.X.Offset==-ring.offset and bunny.edgeStroke.Thickness==ring.thickness,"rounded inner corners")
   assert(bunny.headline.label.Text=="DISCOVERY!"and bunny.stamp.Text~="")
   task.wait(require(client.CelebrationKit).OpenSettle+.05)
   for i=1,9 do bunny:updateExternal(i*.1,{inputLocked=true});bunny:step(.05)end -- (a jump over 0.3 s would settle)
   assert(not bunny.edge.Visible and not bunny.shock.Visible,"nothing before the shell opens")
   bunny:updateExternal(1.0,{inputLocked=true});bunny:step(.05)
   assert(bunny.shock.Visible and bunny.edge.Visible and bunny.backdrop.rimRainbow.Enabled and bunny.backdrop.shafts.Visible,"the burst lands in the lead-in")
   bunny:updateExternal(1.06,{inputLocked=true});assert(bunny.lead.done and not has("reveal_hush"),"no hush for a Rare pet")
   bunny:step(.11);bunny:step(.11);assert(bunny.popAt~=nil and not has(Stage.PopCue),"the cannons fire silently")
   bunny:step(.1);assert(bunny.stamp.Visible and bunny.stampScale.Scale>1,"the stamp drops")
   local flying=0;for _,piece in ipairs(bunny.cannonPieces)do if piece.Visible then flying+=1 end end
   local popped=0;for _,piece in ipairs(bunny.confettiPieces)do if piece.Visible then popped+=1 end end
   assert(flying>0 and popped==0,"cannons, never the corner poppers")
   for _=1,10 do bunny:step(.1)end
   assert(bunny:isSettled()and not bunny.stamp.Visible and bunny.edge.Visible)
   assert(has("bear_boop",1.25)and has("bear_boop",1.40)and has("bear_boop",1.55)and has("tag_slam")and has("name_slam")and has("desc_tick"))
   for _,dropped in ipairs({"reveal_hush","spot_on","streak_whoosh","reveal_shimmer",Stage.PopCue})do assert(not has(dropped),dropped.." played")end
   bunny:destroy()
   -- Reduced Motion: the calm frame (static edge 0.6, the stamp fades in and out, no cannons).
   table.clear(cues)
   local calm=Stage.show(host,{pet=Pets.byId.blip,tag="rare",audio=audio,reduced=true,fresh=true,buttons={{id="meet",text="Meet Bunny",primary=true}}})
   table.insert(stages,calm);if calm.connection then calm.connection:Disconnect();calm.connection=nil end
   assert(not has("reveal_shimmer"))
   calm:step(.1);calm:step(.1)
   assert(calm:isSettled()and calm.edge.Visible and near(calm.edgeStroke.Transparency,.4,1e-6)and calm.stamp.Visible and not calm.shock.Visible and calm.popAt==nil)
   for _=1,10 do calm:step(.1)end;assert(not calm.stamp.Visible and calm.edge.Visible)
   calm:destroy();host:Destroy()
  end)
  test("Round 3: a host can hold press-to-skip (canSkip); clock jumps still settle",function()
   local host=Instance.new("Frame");host.Size=UDim2.fromOffset(812,354);host.BackgroundTransparency=1;host.Parent=gui
   local allow,skips=false,0
   local held=Stage.show(host,{pet=Pets.byId.blip,reduced=false,canSkip=function()return allow end,onSkip=function()skips+=1 end,
    buttons={{id="meet",text="Meet Bunny",primary=true}}})
   table.insert(stages,held);if held.connection then held.connection:Disconnect();held.connection=nil end
   held:settle();held:confirm();assert(not held:isSettled()and skips==0,"held")
   allow=true;held:settle();assert(held:isSettled()and skips==1)
   local quiet=Stage.show(host,{pet=Pets.byId.blip,reduced=false,canSkip=function()return false end,buttons={}})
   table.insert(stages,quiet);if quiet.connection then quiet.connection:Disconnect();quiet.connection=nil end
   quiet:settle(true);assert(quiet:isSettled(),"a quiet settle (a jump, a lost owner) is never held")
   held:destroy();quiet:destroy();host:Destroy()
  end)
 end)
 for _,stage in ipairs(stages)do pcall(function()stage:destroy()end)end
 gui:Destroy()
 assert(ok,problem)
 return{passed=#cases,cases=cases}
end
