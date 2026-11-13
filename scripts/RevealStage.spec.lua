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
  test("pet descriptions exist, one line of at most 60 characters; Bear's is the approved line",function()
   assert(Pets.byId.pip.description=="Soft as a nap. Hugs first, asks questions never.")
   for _,pet in ipairs(Pets.collection)do assert(type(pet.description)=="string"and #pet.description>0 and utf8.len(pet.description)<=60,pet.id)end
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
 end)
 for _,stage in ipairs(stages)do pcall(function()stage:destroy()end)end
 gui:Destroy()
 assert(ok,problem)
 return{passed=#cases,cases=cases}
end
