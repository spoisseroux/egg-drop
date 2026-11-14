-- Bear attachment anchors, authored horns/wings S1-S5, wearable slots and exclusions,
-- and the procedural fallback for rigs without authored attachment meshes.
-- Client spec: require(PlayerScripts.Client.ZZSpecs.PetAttachments)(PlayerScripts.Client)
return function(client,parent)
 local fixture=assert(script.Parent:FindFirstChild("PetAssetsReadyFixture"),"Install actual authored readiness helper")
 require(fixture)(client)
 local Shared=game.ReplicatedStorage.Shared
 local Factory=require(client.PetFactory);local Bounds=require(client.PetRigBounds)
 local Rules=require(Shared.PetAttachmentRules);local Pets=require(Shared.PetCatalog);local Defs=require(Shared.PetRigDefinitions)
 local H=require(Shared.HueCatalog)
 local bear=Defs.pip
 local root=Instance.new("Folder");root.Name="_PetAttachments";root.Parent=parent or workspace
 local visuals,cases={},{};local function test(name,run)run();table.insert(cases,name)end
 local function appearance(h,w,wear,c)return{charmVisible=true,charmShape="dot",toyId="none",appearanceGeneration=1,featureStages={horns=h or 0,claws=c or 0,wings=w or 0},wearables=wear}end
 local function make(pet,a,native)
  local v=Factory.new(root,Vector3.new(0,4,0),pet,.72,a or appearance(),{native=native});table.insert(visuals,v)
  v.reducedEffects=true;v:update(0);return v
 end
 local function entries(v,predicate)local r={};for _,e in ipairs(v.pieces)do if predicate(e)then r[e.name]=e end end;return r end
 local function count(t)local n=0;for _ in pairs(t)do n+=1 end;return n end
 local function find(v,name)for _,e in ipairs(v.pieces)do if e.name==name then return e end end end
 local function shown(e)return e and e.part.Parent~=nil and e.part.Transparency<1 end
 local ok,problem=pcall(function()
  test("the Bear rig carries all 46 manifest anchors with channels, kinds and frames",function()
   assert(count(bear.anchorFrames)==46,"anchor count "..count(bear.anchorFrames))
   for name,frame in pairs(bear.anchorFrames)do
    assert(bear.anchors[name],"anchor position missing "..name)
    for i=1,3 do assert(math.abs(bear.anchors[name][i]-frame.position[i])<1e-6,"anchor disagrees "..name)end
    assert(table.find({"Head","Body","HandL","HandR","FootL","FootR","Root"},frame.channel),name)
    local cf=Rules.anchorFrame(bear,name,1);assert(math.abs(cf.XVector:Cross(cf.YVector):Dot(cf.ZVector)-1)<1e-4,"anchor frame not orthonormal "..name)
   end
   -- Guide positions (runtime = Blender (x, z, -y)): HatCrown 0,1.38,0.03; HelixR from its own ear, not mirrored.
   local hat=bear.anchors.HatCrown;assert(math.abs(hat[2]-1.3824)<1e-4 and math.abs(hat[3]-.03)<1e-4)
   assert(math.abs(bear.anchors.HelixL[1]+bear.anchors.HelixR[1])>.01,"helix anchors mirrored")
   -- Surface anchors: +Y leaves the surface. HornL leans out to -X and forward to +Z.
   local horn=Rules.anchorFrame(bear,"HornL",1);assert(horn.YVector.X<-.2 and horn.YVector.Y>.9 and horn.YVector.Z>.05,tostring(horn.YVector))
   local guide={HatCrown="Head",HornL="Head",HelixL="Head",HelixR="Head",EyeL="Head",Mouth="Head",Torso="Body",Neck="Body",Tail="Body",WingL="Body",HandL="HandL",ClawR="HandR",ToeL="FootL"}
   for name,channel in pairs(guide)do assert(bear.anchorFrames[name].channel==channel,name)end
   for _,a in ipairs(bear.attachments)do
    local anchor=assert(bear.anchorFrames[a.anchor],"attachment anchor missing "..a.name)
    assert(a.channel==anchor.channel,"attachment does not follow its anchor channel "..a.name)
   end
  end)
  test("authored attachments sit on their anchors and ride the anchor channel",function()
   local wear={Hat="beanie",Shirt="tee",Neck="beads",EarPiercingL="ring",EarPiercingR="ring",Eyes="sparkle",Mouth="blep",Tail="heart"}
   local v=make(Pets.byId.pip,appearance(0,3,wear));assert(v.backend=="AuthoredMesh"and v.model:GetAttribute("FeatureBackend")=="AuthoredAttachments")
   local placed=0
   for _,a in ipairs(bear.attachments)do local e=find(v,a.name);if e then
    placed+=1
    -- QA v2 R4.1: hats carry their per-item fit lift (WearableCatalog.Fit).
    local fit=if a.item then require(game.ReplicatedStorage.Shared.WearableCatalog).fitOffset(bear.id,a.item)else Vector3.zero
    local expected=(Vector3.new(a.center[1],a.center[2],a.center[3])+fit)*v.scale
    assert((e.frame.Position-expected).Magnitude<1e-3*v.scale,"off anchor "..a.name)
    assert(e.channel==a.channel and e.part:IsA("MeshPart")and not e.part.CanQuery and e.part.Anchored,a.name)
    -- Every part sits within 0.6 studs (rig size) of its anchor (shirts and tails reach furthest).
    local anchor=Vector3.new(table.unpack(bear.anchors[a.anchor]))*v.scale;assert((e.frame.Position-anchor).Magnitude<.6*v.scale,"far from anchor "..a.name)
   end end
   -- beanie 2 + tee 4 + beads 2 + rings 2 + sparkle 8 + blep 2 + heart 1 = 21 pieces, + 2 wings.
   assert(placed==23,"expected 23 parts (21 wearable pieces + 2 wings), got "..placed)
   -- Head-channel parts follow a head turn; body parts do not.
   v.affectionTilt=4;v.poseDirty=true;v:update(0);local turned=find(v,"Hat_Beanie").part.CFrame;local shirt=find(v,"Shirt_Tee_Torso").part.CFrame
   v.affectionTilt=0;v.poseDirty=true;v:update(0)
   assert((find(v,"Hat_Beanie").part.CFrame.Position-turned.Position).Magnitude>.01,"hat ignored the head channel")
   assert((find(v,"Shirt_Tee_Torso").part.CFrame.Position-shirt.Position).Magnitude<1e-4,"shirt followed the head")
   assert(find(v,"HelixL_Ring").earSide=="L"and find(v,"Tail_AltHeart").tailWag)
   -- The tee is three pieces; each sleeve rides its arm channel, so a wave folds arm and sleeve together.
   assert(shown(find(v,"Shirt_Tee_Torso"))and shown(find(v,"Shirt_Tee_SleeveL"))and shown(find(v,"Shirt_Tee_SleeveR")),"tee is not three shown pieces")
   assert(find(v,"Shirt_Tee_Torso").channel=="Body"and find(v,"Shirt_Tee_SleeveL").channel=="HandL"and find(v,"Shirt_Tee_SleeveR").channel=="HandR")
   local function grip(s)return find(v,"Hand"..s).part.CFrame:ToObjectSpace(find(v,"Shirt_Tee_Sleeve"..s).part.CFrame)end
   local function arm(s)return find(v,"Shirt_Tee_Torso").part.CFrame:ToObjectSpace(find(v,"Hand"..s).part.CFrame)end
   local gripL,gripR,armL,armR=grip("L"),grip("R"),arm("L"),arm("R")
   v.reducedEffects=false;v:greet();v.poseDirty=true;v:update(.6)
   for s,rest in pairs({L={gripL,armL},R={gripR,armR}})do
    local moved=arm(s);assert(math.acos(math.clamp(moved.LookVector:Dot(rest[2].LookVector),-1,1))>.2,"arm "..s.." did not fold for the wave")
    local now=grip(s);assert((now.Position-rest[1].Position).Magnitude<1e-3 and now.LookVector:Dot(rest[1].LookVector)>.9999,"sleeve "..s.." left its arm")
   end
   v.reducedEffects=true;v.greeting=2;v.poseDirty=true;v:update(0)
  end)
  test("horns and wings show exactly the S1-S5 meshes for the shown stage 0..5",function()
   local v=make(Pets.byId.pip,appearance())
   local before=#v.pieces;local heights={}
   for n=0,5 do
    v:applyAppearance(appearance(n,n));v:update(0)
    local horns=entries(v,function(e)return e.featureId=="horns"end);local wings=entries(v,function(e)return e.featureId=="wings"end)
    if n==0 then assert(count(horns)==0 and count(wings)==0)
    else
     assert(count(horns)==2 and horns["HornL_S"..n]and horns["HornR_S"..n],"horn stage "..n)
     assert(count(wings)==2 and wings["WingL_S"..n]and wings["WingR_S"..n],"wing stage "..n)
     for _,e in pairs(horns)do assert(shown(e)and e.part:IsA("MeshPart"))end
     heights[n]=horns["HornL_S"..n].frame.Position.Y+horns["HornL_S"..n].size.Y/2
     if n>1 then assert(heights[n]>heights[n-1],"horn did not grow at "..n)end
     assert(v.model:GetAttribute("VisibleHorns")==n and v.model:GetAttribute("VisibleWings")==n)
    end
    local m=#v.model:GetDescendants();for _=1,6 do v:applyAppearance(appearance(n,n));v:update(0)end;assert(#v.model:GetDescendants()==m,"rebuild not idempotent")
    -- Claws have no authored meshes: they stay procedural (none at stage 0 here).
    assert(count(entries(v,function(e)return e.featureId=="claws"end))==0)
   end
   -- S5 wings are the Bear's own wing mesh.
   local template=game.ReplicatedStorage.PetAssets.Bear
   assert(find(v,"WingL_S5").part.MeshId==template.Bear__WingL.MeshId)
   v:applyAppearance(appearance(0,0));v:update(0);assert(#v.pieces==before and v.featureHaloLift==0)
  end)
  test("multi-piece items: own colour, secondary-tinted and face-ink pieces; horns and wings take the secondary",function()
   local a=appearance(4,2,{Tail="heart",Shirt="tee",Hat="flowercrown",Eyes="sparkle",Mouth="blep"});a.mainDoses=H.emptyCounts();a.secondaryDoses=H.emptyCounts();a.secondaryDoses.tide=5
   local v=make(Pets.byId.pip,a)
   for _,name in ipairs({"HornL_S4","HornR_S4","WingL_S2","WingR_S2"})do
    local e=assert(find(v,name),name);assert(e.colorRole=="secondary"and(e.color or e.part.Color)==v.secondaryColor,name)
   end
   -- Tinted wearable pieces take the secondary but leave the night-glow group (wearables never glow).
   for _,name in ipairs({"Tail_AltHeart","Hat_FlowerCrown_Petals","Shirt_Tee_Stripes","EyeL_AltSparkle_Iris","EyeR_AltSparkle_Iris"})do
    local e=assert(find(v,name),name);assert(e.colorRole=="wearSecondary"and e.part.Color==v.secondaryColor,name.." "..tostring(e.colorRole))
   end
   assert(v.secondaryColor==H.ById.tide.color and v.twoTone==true)
   for name,hex in pairs({Shirt_Tee_Torso="#33539E",Shirt_Tee_SleeveL="#33539E",Hat_FlowerCrown="#58B368",Hat_FlowerCrown_Centers="#FFD23F",EyeL_AltSparkle_White="#FFFFFF",Mouth_AltBlep_Tongue="#FF7C9C"})do
    local e=assert(find(v,name),name);assert(e.colorRole=="own"and e.part.Color:ToHex()==Color3.fromHex(hex):ToHex(),name)
   end
   for _,name in ipairs({"EyeL_AltSparkle","EyeR_AltSparkle","Mouth_AltBlep"})do
    local e=assert(find(v,name),name);assert(e.colorRole=="face"and e.part.Color==v.colors.face,name)
   end
   -- Every piece of an item shares its item id.
   assert(find(v,"Hat_FlowerCrown").item=="flowercrown"and find(v,"Hat_FlowerCrown_Petals").item=="flowercrown"and find(v,"Hat_FlowerCrown_Petals").piece=="Petals")
   -- A squint scales the whole sparkle eye about one centre: shine and iris stay inside the white.
   v.expression="pleased";for _=1,40 do v.poseDirty=true;v:update(.1)end
   for _,s in ipairs({"L","R"})do
    local white=find(v,"Eye"..s.."_AltSparkle_White").part
    for _,piece in ipairs({"Shine","Iris"})do
     local p=find(v,"Eye"..s.."_AltSparkle_"..piece).part;local y=white.CFrame:PointToObjectSpace(p.Position).Y
     assert(math.abs(y)<=white.Size.Y/2+1e-3,piece.." "..s.." left the eye while squinting")
    end
   end
   v.expression="neutral";for _=1,40 do v.poseDirty=true;v:update(.1)end
   -- The open crown keeps the S4 horns shown under it.
   assert(shown(find(v,"HornL_S4"))and v.model:GetAttribute("VisibleHorns")==4)
   a.secondaryDoses=H.emptyCounts();a.secondaryDoses.rose=5;v:applyAppearance(a);v:update(0)
   assert(find(v,"HornL_S4").part.Color==H.ById.rose.color or find(v,"HornL_S4").color==H.ById.rose.color,"horn ignored the new secondary")
  end)
  test("a full hat hides horns (stage kept) and the centre charm; swaps replace default pieces; sides are independent",function()
   local v=make(Pets.byId.pip,appearance(5,0,{Hat="beanie"}))
   assert(not find(v,"HornL_S5")and v.model:GetAttribute("VisibleHorns")==0 and v.featureStages.horns==5 and v.featureHaloLift==0)
   assert(v.attachmentState.charmCenterHidden==true and shown(find(v,"Hat_Beanie")))
   v:applyAppearance(appearance(5,0,{}));v:update(0)
   assert(shown(find(v,"HornL_S5"))and not find(v,"Hat_Beanie")and math.abs(v.featureHaloLift-.1*v.scale)<1e-6,"horns did not return / charm lift")
   v:applyAppearance(appearance(0,0,{Eyes="sleepy",Mouth="blep",Tail="heart",EarPiercingR="starstud"}));v:update(0)
   for _,name in ipairs({"EyeL","EyeR","MouthSmile","Tail"})do assert(find(v,name).part.Transparency==1,"default not replaced "..name)end
   for _,name in ipairs({"EyeL_AltSleepy","EyeR_AltSleepy","Mouth_AltBlep","Mouth_AltBlep_Tongue","Tail_AltHeart","HelixR_StarStud"})do assert(shown(find(v,name)),name)end
   assert(not find(v,"HelixL_StarStud")and not find(v,"EyeL_AltSparkle")and not find(v,"HelixL_Ring"))
   -- The Blep is neutralOnly: another mood brings the default mouth back and hides the Blep.
   assert(find(v,"MouthSmile").neutralSuppressed==true and not find(v,"MouthSmile").suppressed)
   v.expression="sleepy";for _=1,40 do v.poseDirty=true;v:update(.1)end
   assert(not shown(find(v,"Mouth_AltBlep"))and not shown(find(v,"Mouth_AltBlep_Tongue")),"blep shown off the neutral face")
   v.expression="neutral";for _=1,40 do v.poseDirty=true;v:update(.1)end
   assert(shown(find(v,"Mouth_AltBlep"))and find(v,"MouthSmile").part.Transparency==1,"blep did not return on the neutral face")
   v:applyAppearance(appearance(0,0,{}));v:update(0)
   for _,name in ipairs({"EyeL","EyeR","MouthSmile","Tail"})do assert(find(v,name).part.Transparency==0,"default did not return "..name)end
  end)
  test("authored S1-S5 wings flap about their own roots: gentle idle, quicker when pleased or petted, still under Reduced Effects",function()
   local Motion=require(client.PetIdleMotion)
   local function run(m,expression,seconds,each)for _=1,math.floor(seconds*60)do local l,r=Motion.wings(m,expression,1/60);if each then each(l,r)end end end
   local function measure(expression,extra)
    local m=extra or {cosmeticSeed=4};run(m,expression,2)
    local peak,n,last,offset=0,0,nil,0
    run(m,expression,6,function(l,r)peak=math.max(peak,math.abs(l));offset=math.max(offset,math.abs(l-r));if last and(last<0)~=(l<0)then n+=1 end;last=l end)
    return peak,n,offset
   end
   local idlePeak,idleCross,lag=measure("neutral")
   assert(idlePeak>math.rad(8)and idlePeak<=math.rad(12)+1e-6,"idle amplitude "..math.deg(idlePeak))
   assert(idleCross>=6 and idleCross<=7,"idle cycle crossings "..idleCross)-- 1.8 s cycle: ~6.7 crossings in 6 s
   assert(lag>math.rad(2),"left and right flap in lockstep")
   local happyPeak,happyCross=measure("pleased");local fondPeak,fondCross=measure("affectionate");local pettedPeak,pettedCross=measure("neutral",{cosmeticSeed=4,petting=true})
   assert(happyCross>=2*idleCross and fondCross>=2*idleCross and pettedCross>=2*idleCross,"excited flap is not quicker")
   assert(happyPeak>idlePeak and fondPeak>idlePeak and pettedPeak>idlePeak and happyPeak<=Motion.WingMax+1e-6)
   local sleepyPeak=measure("sleepy");assert(sleepyPeak<math.rad(3),"sleepy wings flap")
   run({reducedEffects=true},"pleased",2,function(l,r)assert(l==0 and r==0,"wings flap under Reduced Effects")end)
   for n=1,5 do
    local v=make(Pets.byId.pip,appearance(0,n));v.reducedEffects=false;v.expression="neutral";v:update(0)
    local count=#v.model:GetDescendants();local left,right=find(v,"WingL_S"..n),find(v,"WingR_S"..n)
    assert(left and right and left.wingSide=="L"and right.wingSide=="R","wing "..n.." untagged")
    local hinge=Vector3.new(table.unpack(bear.anchors.WingL))*v.scale
    local function inRig(p)return(CFrame.new(v.origin)*CFrame.Angles(0,v.yaw or 0,0)):PointToObjectSpace(p)end
    -- The wing turns about its own root: its distance to the WingL anchor holds while the tip rises and falls.
    local lowY,highY,d0=math.huge,-math.huge,nil
    for _=1,120 do
     v:update(1/60)
     local p=inRig(left.part.Position);lowY,highY=math.min(lowY,p.Y),math.max(highY,p.Y)
     local d=(p-hinge).Magnitude;d0=d0 or d;assert(math.abs(d-d0)<.02*v.scale,"wing "..n.." left its root")
    end
    assert(highY-lowY>.004*v.scale,"wing "..n.." did not flap")
    assert(#v.model:GetDescendants()==count,"wing flap allocated instances")
    local pad=Motion.padding(v,left);assert(pad.X>0 and pad.Y>0 and pad.Z>0,"wing padding missing")
    v.reducedEffects=true;v:update(1/60);local rest=left.part.Position;v:update(1/60)
    assert((left.part.Position-rest).Magnitude<1e-5,"wing moving under Reduced Effects")
   end
  end)
  test("rules: normalise unknown items, one item per slot, a Back wearable hides wings, flags drive exclusions",function()
   assert(next(Rules.normalize(bear,{Hat="crown",Wings="beanie",Eyes="sparkle",EarPiercing="ring",Mouth="o",Tail="arrow"}))=="Eyes","placeholder ids must be gone")
   -- 3 hats, 2 shirts, 2 necklaces, 2 helix pairs x 2 sides, 6 eyes (round, smallwide [unsold], sparkle, sleepy, happy, lash), 2 mouths, 1 tail.
   local items=Rules.items(bear);assert(#items==20,#items)
   local sold=require(Shared.WearableCatalog).forPet("pip").order;assert(#sold==17,"manifest items "..#sold)
   for _,item in ipairs(sold)do assert(item.price==({common=15,rare=30,showcase=60})[item.tier],item.id)end
   -- Real manifest flags: full hats hide horns; the Flower Crown is an open crown (horns and the centre charm stay) with a low brim.

   local r0=Rules.resolve(bear,{horns=3},{Hat="sunhat"});assert(r0.stages.horns==0 and r0.charmCenterHidden,"sun hat kept horns")
   r0=Rules.resolve(bear,{horns=3},{Hat="flowercrown"});assert(r0.stages.horns==3 and not r0.charmCenterHidden and r0.blocked.Forehead,"flower crown hid horns or kept the forehead")
   r0=Rules.resolve(bear,{},{Shirt="hoodie",Neck="bellcollar"});assert(r0.blocked.Chest,"printedChest did not block the chest slot")
   local neckShown=false;for _,a in ipairs(r0.show)do if a.slot=="Neck"then neckShown=true end end;assert(neckShown,"a necklace draws over a shirt")
   assert(Rules.hasFeature(bear,"horns")and Rules.hasFeature(bear,"wings")and not Rules.hasFeature(bear,"claws"))
   local fake=table.clone(bear);fake.attachments=table.clone(bear.attachments)
   table.insert(fake.attachments,{name="Back_Pack",slot="Back",anchor="Back",channel="Body",colorRole="own",color="#FFFFFF",item="pack",center={0,.5,-.3},size={.3,.3,.2}})
   table.insert(fake.attachments,{name="Hat_Band",slot="Hat",anchor="HatCrown",channel="Head",colorRole="own",color="#FFFFFF",item="band",flags={openCrown=true,hidesEars=true},center={0,1.4,0},size={.3,.1,.3}})
   local r=Rules.resolve(fake,{horns=3,wings=4},{Back="pack"});assert(r.stages.wings==0 and r.stages.horns==3)
   r=Rules.resolve(fake,{horns=3},{Hat="band",EarPiercingL="ring"})
   assert(r.stages.horns==3 and not r.charmCenterHidden,"openCrown hat hid horns")
   for _,a in ipairs(r.show)do assert(a.slot~="EarPiercing","hidesEars hat left a piercing visible")end
   r=Rules.resolve(bear,{horns=4},{});assert(r.charmLift==.1)
   r=Rules.resolve(bear,{horns=3},{});assert(r.charmLift==0)
  end)
  test("rigs without authored attachments, and the Bear's native fallback, keep procedural features and ignore wearables",function()
   for _,pet in ipairs(Pets.collection)do
    local native=pet.id=="pip"
    local v=make(pet,appearance(3,3,{Hat="beanie"},3),native)
    assert(v.model:GetAttribute("FeatureBackend")=="Procedural",pet.id)
    local procedural=entries(v,function(e)return e.role=="feature"end)
    assert(count(procedural)==24,pet.id.." procedural count "..count(procedural))
    assert(procedural.Feature_horns1L and procedural.Feature_wings1L and procedural.Feature_claws1L)
    assert(not find(v,"Hat_Beanie"),pet.id.." wore a wearable without authored meshes")
   end
   -- Authored Bear: claws stay procedural beside the authored horns and wings.
   local v=make(Pets.byId.pip,appearance(3,3,nil,3));local claws=entries(v,function(e)return e.featureId=="claws"end)
   assert(count(claws)==8 and claws.Feature_claws1L and find(v,"HornL_S3")and find(v,"WingR_S3"))
   assert(select(2,Bounds.get(v)).Y>0)
  end)
 end)
 for _,v in ipairs(visuals)do v:destroy()end;root:Destroy();assert(ok,problem);return{passed=#cases,cases=cases}
end
