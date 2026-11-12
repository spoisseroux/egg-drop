-- Existing-owner analytic cosmetics, real imported/native rigs, no live authority.
return function(client)
 local readyFixture=assert(script.Parent:FindFirstChild("PetAssetsReadyFixture"),"Install the real authored-readiness QA helper beside this spec")
 require(readyFixture)(client)
 local Motion=require(client.PetIdleMotion);local Visual=require(client.GardenPetVisual)
 local Shot=require(client.PetGreetingShot);local Pets=require(game.ReplicatedStorage.Shared.PetCatalog)
 local folder=Instance.new("Folder");folder.Name="_GardenBabyMotion";folder.Parent=workspace
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function find(visual,name)for _,piece in ipairs(visual.pieces)do if piece.name==name then return piece end end end
 local function entry(visual,name)return find(visual,name)or error(name.." missing")end
 local function sample(v,expression)return table.pack(Motion.sample(v,expression or "neutral"))end
 local ok,problem=pcall(function()
  test("seeded blinks close briefly, rest open and repeat without frame integration",function()
   for _,seed in ipairs({0,117,996})do
    local v={cosmeticSeed=seed,time=0};local shut,open,shortest=0,0,1
    for i=0,1200 do
     v.time=i*.01;local state=sample(v);shortest=math.min(shortest,state[1])
     if state[1]<.5 then shut+=1 else open+=1 end
     local again=sample(v);for j=1,state.n do assert(state[j]==again[j],"same seed/time changed")end
     assert(math.abs(state[2])<=Motion.Breath+.00001 and math.abs(state[3])<=Motion.BodyStretch+.00001)
     assert(math.abs(state[4])<=Motion.HeadAngle+.00001 and math.abs(state[5])<=Motion.HeadAngle*.5+.00001)
     assert(math.abs(state[6])<=Motion.DotSide+.00001 and math.abs(state[7])<=Motion.DotRise+.00001)
     assert(state[8]>=.96-.00001 and state[8]<=1.04+.00001)
    end
    assert(shortest<.1 and shut>0 and shut<60 and open>1100,"blink duration/open rest drift")
   end
   local a=sample({time=1.1,cosmeticSeed=12});local b=sample({time=1.1,cosmeticSeed=823})
   assert(a[2]~=b[2],"different owners synchronize their idle")
  end)
  test("reduced motion is exactly static and sleep/contact retain expression eyelids",function()
   local v={reducedEffects=true,cosmeticSeed=117}
   for _,time in ipairs({0,.075,4,17,1000000})do
    v.time=time;local s=sample(v);assert(s[1]==1 and s[8]==1)
    for i=2,7 do assert(s[i]==0,"periodic reduced motion")end
   end
   v.reducedEffects=false
   for i=0,600 do v.time=i*.025;assert(sample(v,"sleepy")[1]==1 and sample(v,"affectionate")[1]==1)end
   local a=sample({time=8,cosmeticTime=123.4,cosmeticSeed=12})
   local b=sample({time=900,cosmeticTime=123.4,cosmeticSeed=12})
   for i=1,a.n do assert(a[i]==b[i],"observer construction age changes shared idle")end
  end)
  for _,id in ipairs({"pip","puddle"})do for _,native in ipairs({false,true})do
   test(id.." "..(if native then "native"else "imported").." Dot moves separately, feet stay planted and frames allocate no nodes",function()
    local visual=Visual.new(folder,Vector3.zero,Pets.byId[id],.72,{charmVisible=true},{native=native})
    visual.cosmeticSeed=117;visual.focusPose=true;visual.greeting=2;visual.expression="neutral";visual:update(0)
    local count=#visual.model:GetDescendants();local foot=entry(visual,"FootL").part.CFrame
    local dot=entry(visual,"CharmDot");local baseline=dot.part.Position;local moved=false;local blink=false
    local eye=entry(visual,"EyeL");local glint=find(visual,"GlintL") -- the v1 Bear (pip) has no glint piece
    for i=0,240 do
     visual.time=i*.05;visual:update(0)
     assert(entry(visual,"FootL").part.CFrame==foot,"idle slides or lifts the planted foot")
     moved=moved or(dot.part.Position-baseline).Magnitude>.025
     if eye.part.Size.Y<eye.size.Y*.3 then blink=true;if glint then assert(glint.part.Transparency==1,"glint remains above closed eyelid")end end
     assert(math.abs(dot.part.Size.X*dot.part.Size.Y*dot.part.Size.Z-dot.size.X*dot.size.Y*dot.size.Z)<.00001,"Dot squash changes volume")
    end
    assert(moved and blink and #visual.model:GetDescendants()==count)
    -- Cuff trims exist only on cuffed rigs; the v1 Bear's paw tips come from its two-tone body.
    for _,side in ipairs(if find(visual,"CuffTrimL")then {"L","R"}else {})do
     local hand=entry(visual,"Hand"..side).part;local trim=entry(visual,"CuffTrim"..side).part
     visual.expression="neutral";visual:update(0);local relative=hand.CFrame:ToObjectSpace(trim.CFrame)
     for _,pose in ipairs({"curious","pleased","affectionate"})do
      visual.expression=pose;visual:update(0);local folded=hand.CFrame:ToObjectSpace(trim.CFrame)
      assert((folded.Position-relative.Position).Magnitude<.00001 and folded.LookVector:Dot(relative.LookVector)>.999999,"mitten tip detaches while folding")
     end
    end
    visual.reducedEffects=true;visual:update(0);local frames={}
    for _,piece in ipairs(visual.pieces)do frames[piece.part]={piece.part.CFrame,piece.part.Size}end
    visual:update(7)
    for part,frame in pairs(frames)do assert(part.CFrame==frame[1]and part.Size==frame[2],"reduced pose drifts")end
    visual:destroy()
   end)
  end end
  test("all seven stable identities share the approved neutral reset palette including retained editions",function()
   local Palette=require(game.ReplicatedStorage.Shared.PetPalette)
   local order={"pip","puddle","wick","orbit","bloom_pip","foxfire_wick","eclipse_orbit"}
   for index,id in ipairs(order)do
    local original=Palette.original(id)
    assert(Pets.byId[id].index==index and Pets.byId[id].color==Color3.fromRGB(255,255,255))
    assert(original.body==Color3.fromRGB(255,255,255)and original.secondary==Color3.fromHex("#A8A5AE"))
    assert(Pets.isActive(id)==(index==1),"retained edition silently reentered the active roster") -- v1: only pip is active
   end
  end)
  test("focus captures analytic extrema once and hidden Dot contributes no padding or points",function()
   local visual=Visual.new(folder,Vector3.zero,Pets.byId.pip,.72,{charmVisible=true},{native=true})
   visual.cosmeticTime=987.65;visual.cosmeticSeed=823;visual.time=4;visual.expression="curious";visual:update(0)
   local before=entry(visual,"Head").part.CFrame
   local _,_,_,visible=Shot.captureFocusedSubject(visual)
   assert(visible.sweepSamples==17 and visible.motionBoundsVersion==Motion.Version)
   assert(entry(visual,"Head").part.CFrame==before and visual.idleMotionFrozen==nil and visual.cosmeticTime==987.65)
   visual:applyAppearance({charmVisible=false});local _,_,_,hidden=Shot.captureFocusedSubject(visual)
   for _,name in ipairs(hidden.names)do assert(name~="CharmDot","hidden Dot reserves camera space")end
   assert(hidden.size.Y<visible.size.Y and #hidden.points<#visible.points)
   local _,_,_,cached,hit=Shot.captureFocusedSubject(visual);assert(hit and cached==hidden)
   visual:destroy()
  end)
 end)
 folder:Destroy();assert(ok,problem);return cases
end
