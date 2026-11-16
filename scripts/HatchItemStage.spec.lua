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
  function s:setSpin(radians)record.spin=radians;record.spins=(record.spins or 0)+1;return radians~=0 end
  function s:setVeil(amount)record.veil=amount end
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
  test("QA v775: the corner close keeps a thumb-safe inset from the safe area and the top bar",function()
   local size=Stage.CloseSize;assert(size>=44,"44 px target")
   -- Spencer's phone: 874 x 402 logical with 62 px side insets and a 21 px home bar.
   local x,y=Stage.closeRect(874,402,true,{l=62,t=0,r=62,b=21},{maxX=874,height=58})
   assert(874-62-(x+size)>=24 and y>=16,"inside the safe area: "..x..","..y)
   assert(874-(x+size)>=62+24,"clear of the rounded corner")
   -- No insets (an emulator, a small phone): still 24 / 16 px in, never the old 12 / 10.
   x,y=Stage.closeRect(568,320,true,nil,nil);assert(568-(x+size)==24 and y==16,"568x320 "..x..","..y)
   assert(Stage.geometry(568,320).margin==24,"the close lines up with the stage margin (the buttons' right edge)")
   -- Roblox controls on the right of the top bar: the close goes under the bar.
   x,y=Stage.closeRect(812,354,true,{l=0,t=0,r=0,b=0},{maxX=700,height=58});assert(y==66 and x==812-24-size,"under the bar "..x..","..y)
   x,y=Stage.closeRect(812,354,true,{l=0,t=0,r=0,b=0},{maxX=812,height=58});assert(y==16,"free strip keeps the top row")
   -- Desktop: a wider inset; a tiny stage never pushes it off screen.
   x,y=Stage.closeRect(1920,1080,false,nil,nil);assert(1920-(x+size)==32 and y==28)
   x,y=Stage.closeRect(40,40,true,{r=200,t=200},nil);assert(x==0 and y==0)
   local stage=open(812,354);task.wait()
   local p,s,r=stage.close.AbsolutePosition,stage.close.AbsoluteSize,stage.root
   assert(r.AbsolutePosition.X+r.AbsoluteSize.X-(p.X+s.X)>=20 and p.Y-r.AbsolutePosition.Y>=16,"built stage close inset")
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
  test("QA R4: the stage opens eased, and one on screen leaves in its own gui: content sinks, then the dark lifts",function()
   local C=require(client.CelebrationKit)
   -- QA v735 H1: a slower open, eased in and out; the egg follows the dark.
   assert(C.OpenFade>=.3 and C.OpenSettle<=.7,"long enough to read as a fade, short enough not to drag")
   assert(C.openSample(0).dim==0 and C.openSample(C.OpenFade).dim==1 and math.abs(C.openSample(C.OpenFade*.5).dim-.5)<1e-6,"the dim eases in and out")
   assert(C.openSample(.03).dim<.03 and 1-C.openSample(C.OpenFade-.03).dim<.03,"no snap at either end of the dim")
   assert(C.openSample(C.OpenContentAt).content==0 and C.openSample(C.OpenContentAt+C.OpenFade).content==1,"the egg fades in after the dark starts")
   assert(math.abs(C.openSample(0).scale-C.OpenScale)<1e-6 and C.openSample(1).scale==1 and C.openSample(1).done and not C.openSample(C.OpenFade).done,"the egg eases up to size just after")
   local d,c,k=-1,-1,0
   for t=0,C.OpenSettle+.02,.005 do
    local x=C.openSample(t)
    assert(x.dim>=d and x.content>=c and x.scale>=k and x.dim<=1 and x.content<=1 and x.scale<=1,"open lanes only rise, at "..t)
    assert(x.dim-d<.06 or d<0,"no jump in the dim at "..t)
    d,c,k=x.dim,x.content,x.scale
   end
   local last=-1
   for t=0,C.LeaveTime+.02,.005 do
    local x=C.leaveSample(t)
    assert(x.content>=last-1e-9 and x.content<=1 and x.lift>=0 and x.lift<=1 and(x.lift==0 or x.content==1),"the dark lifts only after the content is gone, at "..t)
    assert(x.scale<=1 and x.scale>=.93);last=x.content
   end
   assert(C.leaveSample(C.LeaveTime).done and not C.leaveSample(C.LeaveTime-.01).done and C.LeaveTime<=.35,"a quick exit")
   -- A stage that never drew is destroyed by its caller as before.
   local unseen=open(812,354);assert(unseen:dismiss()==false and not unseen.destroyed and not unseen.leaving)
   local stage,record,_,_,host=open(812,354)
   at(stage,.5);assert(record.veil==0,"the egg is fully in once the dim is up")
   at(stage,3.1);assert(stage.seenAt~=nil and stage:isSettled())
   local before=stage.root.AbsolutePosition;local size=stage.root.AbsoluteSize;local done=0
   assert(stage:dismiss(function()done+=1 end)==true and stage.leaving and stage.root:GetAttribute("Leaving")==true)
   if stage.connection then stage.connection:Disconnect();stage.connection=nil end
   local out=stage.root.Parent
   assert(out:IsA("ScreenGui")and out.Name=="RevealExit"and out~=gui and out.DisplayOrder==gui.DisplayOrder+1 and not host:FindFirstChild("ItemRevealStage"),"it leaves in a gui of its own, above its host")
   task.wait();assert((stage.root.AbsolutePosition-before).Magnitude<1.5 and(stage.root.AbsoluteSize-size).Magnitude<1.5,"at the same place on screen")
   assert(not stage:owned()and not stage:activate(stage.buttons[2])and #record.acts==0 and not stage.root.Interactable,"a leaving stage takes no input")
   assert(stage:dismiss()==false,"one leave only")
   stage:paintLeave(.06);assert(stage.cover.Visible and stage.cover.BackgroundTransparency<1 and stage.cover.BackgroundTransparency>0 and stage.root.BackgroundTransparency==0 and stage.card.Visible,"content sinks into the dark first")
   assert(stage.seat.Size.X.Offset<stage.L.seat,"with an eased shrink")
   stage:paintLeave(C.LeaveTime*.8);assert(stage.root.BackgroundTransparency==1 and not stage.card.Parent.Visible and stage.cover.BackgroundTransparency>.3 and stage.cover.BackgroundTransparency<1,"then the dark lifts off what is underneath")
   assert(record.releases==0 and done==0,"the borrowed scene stays until the stage is gone")
   stage:paintLeave(C.LeaveTime);assert(stage.destroyed and done==1 and record.releases==1 and out.Parent==nil,"gone, its gui with it, and the scene handed back")
   -- Reduced Motion leaves by the same fade, without the shrink.
   local calm=open(812,354,{reduced=function()return true end})
   at(calm,.2);local seat=calm.seat.Size;assert(calm:dismiss()==true);if calm.connection then calm.connection:Disconnect();calm.connection=nil end
   calm:paintLeave(.06);assert(calm.seat.Size==seat and calm.cover.BackgroundTransparency<1);calm:paintLeave(1);assert(calm.destroyed)
  end)
  test("QA R2: the card is a lit backdrop in the tier's colour, and a 3D result turns once it is named",function()
   for _,tier in ipairs({"Common","Uncommon","Rare","Neutral"})do
    local look=Rarity.Look[tier]
    assert(typeof(look.back)=="Color3"and typeof(look.backDeep)=="Color3"and look.back~=look.backDeep,tier.." backdrop colours")
    local _,s,v=look.back:ToHSV();assert(s>=.25 and v>=.85,tier.." backdrop is a lit colour, not grey")
    local stage=open(812,354,{tier=tier,kind="material"})
    assert(stage.card:GetAttribute("BackdropTop")==look.back and stage.card:GetAttribute("BackdropFloor")==look.backDeep)
    assert(stage.cardBack.Color.Keypoints[1].Value==look.back and #stage.cardLights==Stage.BackLights and stage.cardStroke.Color==look.color)
    at(stage,3.1);assert(stage.card.Visible and stage.card.BackgroundTransparency==0,"an opaque backdrop")
   end
   assert(Rarity.Look.Neutral.back==Rarity.Look.Common.back and Rarity.Look.Rare.back~=Rarity.Look.Common.back and Rarity.Look.Uncommon.back~=Rarity.Look.Common.back)
   assert(Stage.spinAt(0)==0 and Stage.spinAt(-1)==0 and Stage.spinAt(.4)<Stage.SpinSpeed*.4 and math.abs((Stage.spinAt(3)-Stage.spinAt(2))-Stage.SpinSpeed)<1e-6,"the turn eases in, then holds a steady speed")
   local stage,record=open(812,354)
   at(stage,R-.05);assert((record.spin or 0)==0,"no turn before the name")
   at(stage,R+.02);for _=1,30 do stage:step(1/30)end
   local first=record.spin;assert(first and first>0,"the result turns once named")
   for _=1,30 do stage:step(1/30)end;assert(record.spin>first,"and keeps turning while it idles")
   local still,quiet=open(812,354,{reduced=function()return true end})
   at(still,.2);for _=1,30 do still:step(1/30)end;assert((quiet.spin or 0)==0,"no turn under Reduced Motion")
   local reopened,again=open(812,354,{instant=true})
   reopened:step(1/30);for _=1,20 do reopened:step(1/30)end;assert((again.spin or 0)>0,"a reopened receipt idles with the turn")
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
