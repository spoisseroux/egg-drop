-- Studio Client. Full-screen item reveal (QA v685 H2/H3/H5, 2026-11-15): timeline, layout
-- on phone and PC, tier looks, disclosure, the mirrored receipt actions and the scene
-- loan. A synthetic scene; no purchase, remote, save or sound.
-- Usage: require(PlayerScripts.Client.ZZSpecs.HatchItemStage)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Stage=require(client.HatchItemStage);local Pose=require(client.HatchDisplayPose);local Rarity=require(client.HatchRarityCue)
 local Kit=require(client.DeckKit)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local gui=Instance.new("ScreenGui");gui.Name="_HatchItemStageSpec";gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=parent
 local stages={}
 local R=Pose.ItemReady
 local function fakeScene(record)
  local s={ready=true,root=Instance.new("Frame")}
  function s:borrow(seat)record.borrows+=1;self.root.Parent=seat;return self end
  function s:release(token)assert(token==self);record.releases+=1;self.root.Parent=nil end
  function s:setBare(bare,hideHero)record.bare={bare,hideHero}end
  function s:layout()record.layouts+=1 end
  return s
 end
 local function open(w,h,extra)
  local record={borrows=0,releases=0,layouts=0,skips=0,closes=0,acts={}}
  local host=Instance.new("Frame");host.Size=UDim2.fromOffset(w,h);host.BackgroundTransparency=1;host.Parent=gui
  local use=Instance.new("TextButton");use.Name="UseNow";use.Text="Use now";use.Parent=host
  local keep=Instance.new("TextButton");keep.Name="Action";keep.Text="Store";keep.Parent=host
  local options={scene=fakeScene(record),kind="toy",tier="Neutral",cover=false,owns=function()return true end,reduced=function()return false end,
   name=function()return "Squeaky Carrot"end,detail=function()return "Choose a pet for this toy."end,
   onSkip=function()record.skips+=1 end,onClose=function()record.closes+=1 end,
   actions=function()return {{source=use,primary=true,act=function()table.insert(record.acts,"use")end},{source=keep,primary=false,act=function()table.insert(record.acts,"store")end}}end}
  for key,value in pairs(extra or {})do options[key]=value end
  local stage=Stage.show(host,options);table.insert(stages,stage)
  if stage.connection then stage.connection:Disconnect();stage.connection=nil end
  return stage,record,use,keep,host
 end
 local function at(stage,age)stage:updateExternal(age,nil);stage:step(1/30)end
 local ok,problem=pcall(function()
  test("timeline: build, burst, card, then the name exactly at the receipt beat",function()
   local s=Stage.sample(0);assert(s.build==0 and s.flash==0 and s.burstAge<0 and math.abs(s.card)<1e-6 and s.slide==0 and not s.named and not s.input and s.pre==1)
   assert(Stage.sample(.5).build>0 and Stage.sample(.5).build<Stage.sample(.9).build and Stage.sample(.94).build==1)
   assert(Stage.sample(.6).shake<Stage.sample(.9).shake and Stage.sample(1.0).shake==0,"the wobble grows, then stops at the burst")
   assert(Stage.BurstAt==Rarity.BurstAt and Stage.sample(Stage.BurstAt-.01).flash==0 and Stage.sample(Stage.BurstAt).flash==1 and Stage.sample(Stage.BurstAt+.33).flash==0)
   assert(Stage.sample(Stage.BurstAt+.01).beam>1.4 and math.abs(Stage.sample(2).beam-.55)<1e-6,"the beam flares at the burst and rests after")
   assert(Stage.sample(1.05).card<=.001 and math.abs(Stage.sample(1.4).card-1)<.01 and Stage.sample(Stage.SlideAt).slide==0 and math.abs(Stage.sample(Stage.SlideAt+.37).slide-1)<1e-3 and Stage.SlideAt+.36<=R)
   assert(not Stage.sample(R-.001).named and not Stage.sample(R-.001).input and Stage.sample(R).named and Stage.sample(R).input)
   assert(Stage.sample(R).banner==0 and Stage.sample(R+.4).banner==1 and Stage.sample(R+.4).buttons==1)
   assert(not Stage.sample(R+Stage.SettleAfter-.01).settled and Stage.sample(R+Stage.SettleAfter).settled and R+Stage.SettleAfter<Pose.ItemDuration)
   for t=0,3.1,.01 do
    local x=Stage.sample(t)
    for _,key in ipairs({"build","shake","flash","rays","card","slide","name","banner","detail","buttons","pre"})do assert(x[key]>=-.15 and x[key]<=1.15,key.." out of range at "..t)end
    assert(x.beam>=0 and x.beam<=1.7)
   end
  end)
  test("Reduced Motion: one 150 ms fade to the settled frame, no burst",function()
   local a,b=Stage.sample(.05,true),Stage.sample(.15,true)
   assert(a.reduced and a.fade>0 and a.fade<1 and not a.input and not a.named and b.fade==1 and b.input and b.named and b.settled)
   assert(b.flash==0 and b.shake==0 and b.burstAge==math.huge and b.card==1 and b.slide==1 and Stage.shard(1,10,b.burstAge)==nil)
  end)
  test("shards fly out, fall and fade; deterministic and bounded",function()
   assert(Stage.shard(1,10,-.01)==nil and Stage.shard(1,10,Stage.ShardLife+.01)==nil)
   local x0,y0=Stage.shard(3,30,0);assert(x0==0 and y0==0)
   local x1,y1,r1,f1=Stage.shard(3,30,.3);local x2,y2,r2,f2=Stage.shard(3,30,.3)
   assert(x1==x2 and y1==y2 and r1==r2 and f1==f2 and f1==1 and(math.abs(x1)>.1 or math.abs(y1)>.1))
   local _,_,_,fade=Stage.shard(3,30,Stage.ShardLife-.05);assert(fade>0 and fade<.2)
   for i=1,30 do local x,y=Stage.shard(i,30,Stage.ShardLife);assert(math.abs(x)<2 and y<2.6 and y>-1.6)end
  end)
  test("banner words: tier and kind; an untiered item says NEW",function()
   assert(Stage.bannerText("Rare","material")=="RARE FINISH"and Stage.bannerText("Common","material")=="COMMON FINISH")
   assert(Stage.bannerText("Uncommon","feature")=="UNCOMMON FEATURE"and Stage.bannerText("Neutral","toy")=="NEW TOY"and Stage.bannerText("Neutral","hue")=="NEW COLOUR JAR")
   assert(Stage.bannerText(nil,"mystery")=="NEW ITEM")
   for _,tier in ipairs({"Common","Uncommon","Rare"})do
    local ink=Stage.inkOn(Rarity.Look[tier].color);assert(ink==Stage.Ink or ink==Color3.new(1,1,1))
   end
  end)
  test("layout: phone 812x354, phone 844x390, PC and portrait keep everything on screen",function()
   for _,size in ipairs({{812,354},{844,390},{1280,720},{1649,734},{1920,1080},{390,844}})do
    local W,H=size[1],size[2];local L=Stage.geometry(W,H)
    assert(L.landscape==(W>=H*1.15)and L.phone==(Kit.compactRule(W,H)or W<760))
    local egg=L.seat*Stage.EggScale
    assert(L.cx0-egg/2>=0 and L.cx0+egg/2<=W and L.cy0-egg/2>=-2 and L.cy0+egg/2<=H+2,"egg off screen at "..W.."x"..H)
    assert(L.cx1-L.cardW/2>=8 and L.cy1-L.cardH/2>=8 and L.cy1+L.cardH/2<=H-8,"card off screen at "..W.."x"..H)
    assert(L.btnY>=0 and L.btnY+L.btnH<=H-8 and L.btnX>=8 and L.btnX+L.btnW<=W-8 and L.btnH>=48,"buttons at "..W.."x"..H)
    assert(L.detailY+L.detailSize<L.btnY and L.nameY>L.bannerY and L.detailY>L.nameY,"text stack at "..W.."x"..H)
    if L.landscape then
     assert(L.textX>L.cx1+L.cardW/2,"the name column overlaps the card at "..W.."x"..H)
     -- Roblox's top-left buttons: the banner starts under them on a phone, or right of them.
     assert(not L.phone or L.bannerY>=56 or L.textX>=250,"banner under the top bar at "..W.."x"..H)
    else assert(L.bannerY>L.cy1+L.cardH/2,"portrait stack at "..W.."x"..H)end
   end
  end)
  test("tier looks build the stage: more rays, shards, rings and sparkles for Rare",function()
   local common=open(812,354,{tier="Common",kind="material"});local rare=open(812,354,{tier="Rare",kind="material"})
   local a,b=common:getStats(),rare:getStats()
   assert(a.rays==6 and a.shards==10 and a.rings==1 and a.sparkles==0 and b.rays==16 and b.shards==30 and b.rings==2 and b.sparkles==12)
   assert(common.cardStroke.Color==Rarity.Look.Common.color and rare.cardStroke.Color==Rarity.Look.Rare.color and common.cardStroke.Color~=rare.cardStroke.Color)
   assert(rare.root:GetAttribute("RevealTier")=="Rare"and rare.banner.BackgroundColor3==Rarity.Look.Rare.color)
   at(common,1.05);at(rare,1.05)
   local function live(stage)local n=0;for _,shard in ipairs(stage.shards)do if shard.Visible then n+=1 end end;return n end
   assert(live(common)==10 and live(rare)==30 and rare.flash.BackgroundTransparency<common.flash.BackgroundTransparency,"the Rare burst is bigger and brighter")
   assert(rare.beamWide.AbsoluteSize.X>common.beamWide.AbsoluteSize.X,"the Rare beam is wider")
  end)
  test("the reward stays undisclosed until the receipt beat, then the name slams under its banner",function()
   local stage,record=open(812,354)
   assert(record.borrows==1 and record.bare[1]==true and record.bare[2]==false,"the scene is borrowed bare; the item stays visible")
   for _,age in ipairs({0,.5,1.0,1.3,R-.02})do
    at(stage,age)
    assert(stage.name.Text==""and not stage.nameGroup.Visible and not stage.banner.Visible and not stage.detail.Visible,"disclosed at "..age)
    assert(stage.skip.Visible and stage.root:GetAttribute("InputLocked")==true and not stage.buttons[1].node.Visible and not stage.buttons[2].node.Visible and not stage.close.Visible)
   end
   assert(stage.pre.Visible==false,"the waiting line leaves at the burst")
   at(stage,R+.01)
   assert(stage.name.Text=="SQUEAKY CARROT"and stage.nameGroup.Visible and stage.nameScale.Scale>1.5,"the name slams in large")
   at(stage,R+.3);assert(stage.banner.Visible and stage.bannerText.Text=="NEW TOY"and stage.detail.Text=="Choose a pet for this toy."and stage.nameScale.Scale<1.1)
   at(stage,3.1);assert(stage:isSettled()and stage.nameScale.Scale==1 and not stage.skip.Visible)
   -- The long name still fits its column on a phone.
   local L=stage.L;assert(stage.nameW<=L.textW+2 and stage.name.TextSize>=18)
  end)
  test("QA R1: every hatch result has one fun line (60 characters at most), shown only with the name",function()
   local Shared=game:GetService("ReplicatedStorage").Shared
   local Copy=require(Shared.UICopy)
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
   for _,kind in ipairs({"toy","material","hue","feature","item"})do assert(utf8.len(Copy.get("hatch.reveal.describe.other."..kind))<=60)end
   assert(Stage.describe("toy",{toyId="not_a_toy"})==Copy.get("hatch.reveal.describe.other.toy")and Stage.describe("mystery",nil)==Copy.get("hatch.reveal.describe.other.item"))
   local stage=open(812,354,{result={toyId="squeaky_carrot"}})
   at(stage,R-.02);assert(stage.describe.Text==""and not stage.describe.Visible,"the line waits for the receipt beat")
   at(stage,R+.5);task.wait()
   assert(stage.describe.Visible and stage.describe.Text==Copy.get("hatch.reveal.describe.toy.squeaky_carrot")and stage.detail.Visible,"the fun line, then the host's line")
   assert(stage.describe.AbsolutePosition.Y<stage.detail.AbsolutePosition.Y and stage.detail.AbsolutePosition.Y+stage.detail.AbsoluteSize.Y<=stage.buttons[2].node.AbsolutePosition.Y,"lines stack above the buttons")
   assert(stage.describe.TextSize>=12 and stage.detail.TextSize>=12)
   local custom=open(812,354,{description=function()return "A host line."end})
   at(custom,R+.5);assert(custom.describe.Text=="A host line.")
  end)
  test("actions mirror the host's receipt buttons and call them only once the receipt is ready",function()
   local stage,record,use,keep=open(812,354)
   at(stage,.5);assert(not stage:activate(stage.buttons[2])and record.skips==1 and #record.acts==0,"an early press only skips")
   at(stage,3.1)
   local secondary,primary=stage.buttons[1],stage.buttons[2]
   assert(primary.node.Visible and secondary.node.Visible and Kit.buttonState(primary.node).label.Text=="Use now"and Kit.buttonState(secondary.node).label.Text=="Store")
   assert(primary.node.AbsolutePosition.X>secondary.node.AbsolutePosition.X and primary.node.AbsoluteSize.Y>=48,"primary on the right, 48 px tall")
   assert(stage:activate(primary)and stage:activate(secondary)and table.concat(record.acts,",")=="use,store")
   use.Text="Give to Bear";keep.Interactable=false;task.wait();stage:step(1/30)
   assert(Kit.buttonState(primary.node).label.Text=="Give to Bear"and not stage:activate(secondary)and #record.acts==2,"a disabled host button stays disabled")
   keep.Visible=false;task.wait();stage:step(1/30);assert(not secondary.node.Visible)
   assert(stage.close.Visible);stage.options.onClose();assert(record.closes==1)
   -- The dark stage hides the host's receipt card underneath.
   assert(Stage.Dim==1 and stage.root.BackgroundTransparency==0 and stage.root.Active,"the receipt card shows through")
   -- The press that skipped never also presses an action.
   local draining=true
   local guarded,guardedRecord=open(812,354,{consumeSkipInput=function()return draining end});at(guarded,3.1)
   assert(not guarded:activate(guarded.buttons[2])and #guardedRecord.acts==0);draining=false;assert(guarded:activate(guarded.buttons[2]))
  end)
  test("a reopen starts settled and silent; Reduced Motion fades; destroy returns the scene",function()
   local stage,record=open(812,354,{instant=true});stage:step(1/30)
   assert(stage:isSettled()and stage.name.Text=="SQUEAKY CARROT"and stage.card.Visible)
   for _,shard in ipairs(stage.shards)do assert(not shard.Visible)end
   assert(stage.flash.BackgroundTransparency==1,"no flash on a reopen")
   stage:destroy();stage:destroy();assert(record.releases==1 and stage.root.Parent==nil)
   local reduced=open(812,354,{reduced=function()return true end,tier="Rare"});at(reduced,.05)
   assert(not reduced:isSettled()and reduced.flash.BackgroundTransparency==1)
   at(reduced,.15);assert(reduced:isSettled()and reduced.name.Text=="SQUEAKY CARROT"and reduced.rayGroup.Rotation==0)
   for _,shard in ipairs(reduced.shards)do assert(not shard.Visible)end
  end)
 end)
 for _,stage in ipairs(stages)do pcall(function()stage:destroy()end)end
 gui:Destroy()
 assert(ok,problem)
 return{passed=#cases,cases=cases}
end
