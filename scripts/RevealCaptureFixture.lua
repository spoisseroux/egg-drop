-- Studio Client capture fixture for the 2026-11-15 reveal redesign (QA v685 H1/H2/H3/H5).
-- Copy to src/client/ZZSpecs/RevealCaptureFixture.lua, restart Play, then from a Client
-- execute_luau:  _G.RevealFx=require(client.ZZSpecs.RevealCaptureFixture)(client)
--   RevealFx.open({ {kind="pet",x=0,y=0,w=812,h=354}, {kind="material",id="jelly",...} })
--   RevealFx.to(1.2)   -- step every open reveal to hatch time 1.2 s (fixed 1/30 s steps)
--   RevealFx.frames(9) -- step 9 frames of real time (the v2 toy lid runs before hatch time 0)
-- v2 (2026-11-20): kind="stat" {size, stat} draws the Stat Egg (StatEggReveal.scene on the
-- real HatchItemStage); items carry the result card's odds, pity and Hatch another from the
-- real EggHatchView / StatEggOdds rules on a synthetic state; spec.lid=false skips the lid.
--   RevealFx.close()
-- It runs the REAL modules (HatchCinematic, HatchDisplayScene, RevealStage, HueItemReveal,
-- HatchItemStage) on synthetic results: no purchase, remote, save or sound. The clocks are
-- stepped by hand so a frame can be captured at an exact time; nothing here ships.
return function(client)
 local Players=game:GetService("Players")
 local Shared=game:GetService("ReplicatedStorage").Shared
 local Cinematic=require(client.HatchCinematic)
 local RevealStage=require(client.RevealStage)
 local ItemReveal=require(client.HueItemReveal)
 local ItemStage=require(client.HatchItemStage)
 local Pose=require(client.HatchDisplayPose)
 local Rarity=require(client.HatchRarityCue)
 local Eggs=require(client.EggHatchView)
 local Pets=require(Shared.PetCatalog)
 local Copy=require(Shared.UICopy)
 local Fx={entries={}}
 local function node(class,parent,props)local o=Instance.new(class);for k,v in pairs(props)do o[k]=v end;o.Parent=parent;return o end
 local function gui()
  if Fx.gui and Fx.gui.Parent then return Fx.gui end
  Fx.gui=node("ScreenGui",Players.LocalPlayer.PlayerGui,{Name="RevealCaptureFixture",ResetOnSpawn=false,DisplayOrder=1000,
   ScreenInsets=Enum.ScreenInsets.None,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,IgnoreGuiInset=true})
  node("Frame",Fx.gui,{Name="Mat",BackgroundColor3=Color3.fromRGB(40,40,40),BorderSizePixel=0,Size=UDim2.fromScale(1,1),Active=true})
  return Fx.gui
 end
 -- A stand-in for the garden behind the dimmed item reveal (so the dim reads in captures).
 local function garden(host)
  local sky=node("Frame",host,{Name="FixtureGarden",BackgroundColor3=Color3.fromRGB(255,214,224),BorderSizePixel=0,Size=UDim2.fromScale(1,1)})
  node("Frame",sky,{BackgroundColor3=Color3.fromRGB(64,190,74),BorderSizePixel=0,Position=UDim2.fromScale(0,.55),Size=UDim2.fromScale(1,.45)})
  node("Frame",sky,{BackgroundColor3=Color3.fromRGB(240,150,60),BorderSizePixel=0,Position=UDim2.fromScale(.42,.55),Size=UDim2.fromScale(.16,.45)})
 end
 local function freeze(entry)
  local c=entry.cinematic
  c:disconnectClock();c.refreshOwner=function()end
  if c.active then c.age=0;c.sampleAge=0;c:paint()end
  for _,stage in ipairs(entry.stages())do if stage.connection then stage.connection:Disconnect();stage.connection=nil end end
  entry.frozen=true
 end
 local function openPet(entry,spec)
  local host=entry.host
  local layer=node("Frame",host,{Name="RevealLayer",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=70})
  local seat=node("Frame",host,{Name="RevealHost",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=40})
  node("Frame",host,{Name="RevealBackdrop",BackgroundColor3=Color3.fromHex("#06070B"),BorderSizePixel=0,Size=UDim2.fromScale(1,1),ZIndex=20})
  local c=Cinematic.new(seat,nil,function()return spec.reduced==true end,function()return true end)
  c:setBleed(true);entry.cinematic=c
  local pet=Pets.byId[spec.id or "pip"]or Pets.byId.pip
  c.stageHandoff=function(info)
   entry.stage=RevealStage.show(layer,{pet=info.pet,name=info.displayName,appearance=info.appearance,scene=info.scene,externalClock=info.externalClock,
    result=info.result,consumeSkipInput=info.consumeSkipInput,tag=RevealStage.tagKind(info.result,info.kind),description=info.pet.description,
    next=info.result.starterGoal,instant=info.instant,fresh=info.fresh,voice=false,reduced=function()return spec.reduced==true end,owns=function()return true end,
    buttons={{id="exit",text=Copy.get("r1.reveal.exit"),glyph="B"},{id="meet",text="Meet "..(info.pet.name or "friend"),glyph="A",primary=true}},
    onButton=function()end,onSkip=function()if c.skip then c:skip()end end})
   return entry.stage
  end
  c.stageClear=function()if entry.stage then entry.stage:destroy();entry.stage=nil end end
  entry.stages=function()return {entry.stage}end
  entry.ready=function()return c.presented==true and entry.stage~=nil and entry.stage.loaded==true end
  c:play({id="fixture-pet-"..tostring(os.clock()),petId=pet.id,starter=true,starterGoal="Toy Egg ready · choose it in Menu"},function()entry.completed=true end,{nativeDisplay=true})
 end
 local builders={
  material=function()return require(client.MaterialFinishPreview).create end,
  toy=function()return require(client.RewardItemArt).create end,
  feature=function()return require(client.RewardItemArt).create end,
 }
 local function openItem(entry,spec)
  local host=entry.host;garden(host)
  local art=node("Frame",host,{Name="ReceiptArt",BackgroundTransparency=1,Position=UDim2.fromOffset(20,20),Size=UDim2.fromOffset(140,140),ZIndex=5})
  local kind=spec.kind
  local result={id="fixture-"..kind.."-"..tostring(os.clock())}
  local name,detail,primaryText,secondaryText
  if kind=="material"then result.finishId=spec.id;name=require(Shared.MaterialCatalog).ById[spec.id].name;detail=Copy.get("hatch.display.material");primaryText,secondaryText="Use now","Keep"
  elseif kind=="toy"then result.toyId=spec.id;name=require(Shared.ToyCatalog).ById[spec.id].name;detail="Choose a pet for this toy.";primaryText,secondaryText=if spec.give then "Give to Bear"else "Use now","Store"
  elseif kind=="feature"then result.featureId=spec.id;name=require(Shared.FeatureCatalog).ById[spec.id].name;detail="Grows on any pet.";primaryText,secondaryText="Use now","Store"
  else result.itemId=spec.id;local row=require(Shared.HueCatalog).Items[spec.id];name=spec.name or(row and row.name)or spec.id;detail=spec.detail or "1 in inventory · choose a pet and channel.";primaryText,secondaryText=spec.primary or "Use now",spec.secondary or "Store"end -- spec.name/detail/primary: Customization Egg results
  -- Stand-ins for the host's receipt buttons (HueEggView's Action and Use now).
  local primary=node("TextButton",host,{Name="FixtureUseNow",Text=primaryText,Size=UDim2.fromOffset(10,10),Position=UDim2.fromOffset(-50,-50)})
  local secondary=node("TextButton",host,{Name="FixtureAction",Text=secondaryText,Size=UDim2.fromOffset(10,10),Position=UDim2.fromOffset(-50,-50)})
  -- The result card's tray from the real egg-card rules on a synthetic state.
  local egg=if kind=="hue"then "look"else kind
  local state={nectar=200,toyUnlocks={ball=true},lookCharmMisses=spec.misses or 5,charmUnlocks=0,lookAvailable=true,materialAvailable=true}
  local won=result.itemId or result.toyId or result.finishId or result.featureId
  if kind=="hue"and require(Shared.LookEggCatalog).kind(result.itemId)=="charm"then won="charm"end
  local reveal=ItemReveal.new(art,{recipeId=kind,resultBuilder=builders[kind]and builders[kind]()or nil,reduceEffects=function()return spec.reduced==true end,
   stage={parent=host,cover=false,zIndex=80,owns=function()return true end,name=function()return name end,detail=function()return detail end,close=function()end,
    odds=function()local ok,rows=pcall(Eggs.oddsRows,egg,state,"pip");return if ok then rows else nil end,wonId=function()return won end,
    pity=function()
     if egg=="look"then for _,row in ipairs(Eggs.lookOdds(state).rows)do if row.id=="pity"then return {line=row.name,sub=""}end end end
     if egg=="toy"then return {line=Copy.get("hatch.result.stockToys",{count=5}),sub=""}end
     return nil
    end,
    again=function()return {text=Copy.get("hatch.result.againPrice",{count=if egg=="toy"then 20 else 12}),enabled=true,act=function()entry.again=true;return true end}end,
    actions=function()return {{source=primary,primary=true,act=function()entry.acted="primary"end},{source=secondary,primary=false,act=function()entry.acted="secondary"end}}end}})
  entry.reveal=reveal
  reveal:show(result,spec.instant~=true)
  entry.cinematic=reveal.cinematic
  entry.stages=function()return {reveal.stage}end
  entry.ready=function()return reveal.cinematic.presented==true and reveal.stage~=nil end
  if spec.lid==false and reveal.stage then reveal.stage.useLid=false end
 end
 -- The Stat Egg: StatEggReveal's snack scene on the real stage, with a hand-stepped clock
 -- shaped like a cinematic (age, active, step, paint) so the fixture drives it the same way.
 local function openStat(entry,spec)
  local Reveal=require(client.StatEggReveal);local Odds=require(client.StatEggOdds)
  local receipt={snackId=1,stat=spec.stat or "power",size=spec.size or "snack"}
  local words=Reveal.copy(receipt,"Bear")
  local tier=Reveal.tier(receipt)
  local state={nectar=200,statEgg={enabled=true,mode="random",price=15,pouch={},pouchSize=12,free=0,boughtToday=1,dailyBuys=3,misses=spec.misses or 3,
   quotes={pip={key="k",eligible={"heart","power","energy","jump","speed","smarts"}}}}}
  local keep=node("TextButton",entry.host,{Name="FixtureKeep",Text=Copy.get("hatch.stat.reveal.keep"),Size=UDim2.fromOffset(10,10),Position=UDim2.fromOffset(-50,-50)})
  local feed=node("TextButton",entry.host,{Name="FixtureFeed",Text=Copy.get("hatch.stat.reveal.feed"),Size=UDim2.fromOffset(10,10),Position=UDim2.fromOffset(-50,-50)})
  local scene=Reveal.scene(receipt)
  local reduced=spec.reduced==true
  local stat=require(Shared.StatCatalog).ById[receipt.stat]
  local stage=ItemStage.show(entry.host,{scene=scene,kind="stat",tier=tier,result=receipt,cover=false,zIndex=80,lid=spec.lid~=false,
   reduced=function()return reduced end,owns=function()return true end,
   name=function()return words.name end,effect=function()return words.boost end,description=function()return ""end,
   sticker=function()return ItemStage.bannerText(tier,"stat")end,stoneColors=function()return {stat.color}end,
   odds=function()return Odds.rows(state,"pip")end,wonId=receipt.size,
   pity=function()return {line=require(client.SnackHost).revealPill(state,"pip"),sub=Odds.stockLine(state)}end,
   again=function()return {text=Copy.get("hatch.result.againPrice",{count=15}),enabled=true,act=function()entry.again=true;return true end}end,
   actions=function()return {{source=keep,primary=false,act=function()entry.acted="keep"end},{source=feed,primary=true,act=function()entry.acted="feed"end}}end,
   onSkip=function()end,onClose=function()end})
  local T=Rarity.timing(tier,"stat",reduced)
  local c={age=0,active=true,presented=true,rarityState={tier=tier}}
  function c:disconnectClock()end
  function c:refreshOwner()end
  function c:paint()local sample=Pose.sample(self.age,"stat",reduced,tier);scene:render(sample);stage:updateExternal(self.age,sample)end
  function c:step(dt)if not stage:holdsClock()then self.age=math.min(T.duration,self.age+dt)end;self:paint()end
  function c:finishStatic()self.age=T.duration;self:paint()end
  function c:destroy()stage:destroy();scene:destroy()end
  entry.cinematic=c;entry.stage=stage
  entry.stages=function()return {stage}end
  entry.ready=function()return true end
 end
 function Fx.open(specs)
  Fx.close()
  local root=gui()
  for index,spec in ipairs(specs)do
   local host=node("Frame",root,{Name="Host"..index,BackgroundColor3=Color3.new(0,0,0),BorderSizePixel=0,ClipsDescendants=true,
    Position=UDim2.fromOffset(spec.x or 0,spec.y or 0),Size=UDim2.fromOffset(spec.w or 812,spec.h or 354),ZIndex=2})
   local entry={host=host,spec=spec};Fx.entries[index]=entry
   -- HatchCinematic allows one visible owner and settles the previous one on a new play.
   -- The fixture shows several side by side, so earlier ones ignore that one call.
   for _,other in ipairs(Fx.entries)do if other.cinematic then other.cinematic.finishStatic=function()end end end
   if spec.kind=="pet"then openPet(entry,spec)elseif spec.kind=="stat"then openStat(entry,spec)else openItem(entry,spec)end
   for _,other in ipairs(Fx.entries)do if other.cinematic then other.cinematic.finishStatic=nil end end
  end
  -- Wait for every scene (and pet rig) to load, freezing each clock as it starts.
  local deadline=os.clock()+8
  repeat
   local all=true
   for _,entry in ipairs(Fx.entries)do
    if not entry.frozen and entry.cinematic.presented then freeze(entry)end
    if not entry.frozen or not entry.ready()then all=false end
   end
   task.wait()
  until all or os.clock()>deadline
  for _,entry in ipairs(Fx.entries)do if not entry.frozen then freeze(entry)end end
  -- The open fade follows the fixture's clock too (QA R4), starting from the first frame.
  -- v2: the toy lid starts on the fixture's clock too (it ran while the scenes loaded).
  for _,entry in ipairs(Fx.entries)do for _,stage in ipairs(entry.stages())do stage.openElapsed=0;stage.openClock=0;stage.lidHeld=0;stage.lid=nil;stage:step(0)end end
  Fx.time=0
  return Fx.stats()
 end
 -- One fixed 1/30 s frame of real time for every reveal (the real step functions).
 local function frame()
  local dt=1/30
  Fx.time+=dt
  for _,entry in ipairs(Fx.entries)do
   local c=entry.cinematic
   c.windowActive=true -- Studio is not the focused window during MCP captures
   if c.active then c:step(dt)end
   for _,stage in ipairs(entry.stages())do stage.openElapsed=Fx.time;stage:step(dt)end
  end
 end
 function Fx.frames(n)for _=1,n do frame()end;return Fx.stats()end
 -- Advance every reveal to hatch time `t` (v2: the lid runs first, so hatch time starts
 -- once its iris is open). At most 20 s of frames.
 function Fx.to(t)
  for _=1,600 do
   local behind=false
   for _,entry in ipairs(Fx.entries)do local c=entry.cinematic;if c.active and c.age<t-1e-6 then behind=true end end
   if not behind then break end
   frame()
  end
  return Fx.stats()
 end
 function Fx.skip()
  for _,entry in ipairs(Fx.entries)do if entry.cinematic.active then entry.cinematic:finishStatic()end;for _,stage in ipairs(entry.stages())do stage:step(1/30)end end
  return Fx.stats()
 end
 -- QA R4: start every stage's leave (items through the real HueItemReveal:clear, pets through
 -- RevealStage:dismiss), frozen, then Fx.leaveTo(t) paints it at `t` seconds into the leave.
 function Fx.leave()
  Fx.leaving={}
  for _,entry in ipairs(Fx.entries)do
   local stage=entry.stages()[1]
   if stage then
    stage.seenAt=os.clock()
    if entry.reveal then entry.reveal:clear()else stage:dismiss(function()entry.dismissed=true end)end
    if stage.leaving then stage.leaving.at=os.clock()end
    if stage.leaving then
     if stage.connection then stage.connection:Disconnect();stage.connection=nil end
     table.insert(Fx.leaving,stage)
    end
   end
  end
  return #Fx.leaving
 end
 function Fx.leaveTo(t)
  local alive=0
  for _,stage in ipairs(Fx.leaving or {})do if not stage.destroyed then stage:paintLeave(t);if not stage.destroyed then alive+=1 end end end
  return alive
 end
 function Fx.stats()
  local out={time=Fx.time}
  for index,entry in ipairs(Fx.entries)do
   local c=entry.cinematic;local stage=entry.stages()[1]
   out[index]={kind=entry.spec.kind,age=c.age,active=c.active,tier=c.rarityState and c.rarityState.tier,ready=c.nativeScene and c.nativeScene.ready,
    failure=c.nativeScene and c.nativeScene.failure,presented=c.presented,stage=stage and stage:getStats()or nil,completed=entry.completed}
  end
  return out
 end
 function Fx.close()
  if Fx.leaving then Fx.leaveTo(10);Fx.leaving=nil end
  for _,entry in ipairs(Fx.entries)do
   pcall(function()if entry.reveal then entry.reveal:destroy()elseif entry.cinematic then entry.cinematic:destroy()end end)
  end
  table.clear(Fx.entries)
  if Fx.gui then Fx.gui:Destroy();Fx.gui=nil end
 end
 return Fx
end
