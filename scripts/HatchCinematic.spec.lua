-- Isolated committed-result presentation fixtures. No purchases, profile writes or native input.
return function(client,parent)
 local readyFixture=assert(script.Parent:FindFirstChild("PetAssetsReadyFixture"),"Install the real authored-readiness QA helper beside this spec")
 require(readyFixture)(client)
 local Cinematic=require(client.HatchCinematic)
 local Shot=require(client.PetGreetingShot)
 local Pets=require(game.ReplicatedStorage.Shared.PetCatalog)
 local Art=require(client.DeckArt)
 local Gui=game:GetService("GuiService")
 local TextService=game:GetService("TextService")
 local Run=game:GetService("RunService")
 local root=Instance.new("Frame");root.Name="_HatchCinematicSpec";root.Size=UDim2.fromOffset(600,360);root.BackgroundTransparency=1;root.Parent=parent
 local cases,views,geometry={},{},{}
 local function test(name,run)run();table.insert(cases,name)end
 local function settle()Run.Heartbeat:Wait();Run.Heartbeat:Wait()end
 local serial=0
 local function packet(pet,rare)serial+=1;return table.freeze({id="cinematic-fixture-"..pet.."-"..tostring(os.clock()).."-"..serial,petId=pet,rare=rare==true})end
 local function make()
  local owner,reduced=true,false;local sounds={};local audio={deviceActive=true,deviceEpoch=0}
  local c;function audio:play(name,pitch,volume,token)table.insert(sounds,{name=name,age=c.age,pitch=pitch,owner=token})end
  function audio:stopOwner()end
  c=Cinematic.new(root,audio,function()return reduced end,function()return owner end);table.insert(views,c);settle()
  return c,sounds,function(value)owner=value;c:refreshOwner()end,function(value)reduced=value;c:refreshOwner()end,audio
 end
 local function advance(c,duration)
  c:disconnectClock();local left=duration
  while left>.000001 do local dt=math.min(1/60,left);c:step(dt);left-=dt end
 end
 local function visibleFit(c,label)
  local camera=c.heroCamera;local aspect=c.heroHost.AbsoluteSize.X/math.max(1,c.heroHost.AbsoluteSize.Y)
  local tangent=math.tan(math.rad(30)*.5)
  for _,entry in ipairs(c.heroVisual.pieces)do local p=entry.part
   if entry.role~="ripple"and entry.faceRole~="spark"and p.Transparency<.99 then
    for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
     local point=camera.CFrame:PointToObjectSpace(p.CFrame:PointToWorldSpace(p.Size*Vector3.new(x,y,z)*.5));local depth=-point.Z
     assert(depth>.5 and math.abs(point.X)<=depth*tangent*aspect*.98 and math.abs(point.Y)<=depth*tangent*.98,label.." clips "..p.Name)
    end end end
   end
  end
 end
 local ok,problem=pcall(function()
  test("short-landscape484x203 keeps final name and caption inside host beside hero",function()
   root.Size=UDim2.fromOffset(484,203);settle();local c=make();c.compactLandscape=true
   c:play({id="short-largest-layout",petId="pip",starter=true,starterGoal="Companion Egg · 6/18 Stars · win quests"},nil,{skipIntro=true});c:disconnectClock();settle();c:disconnectClock()
   assert(c.landscapeLayout and c.heading.TextFits and c.tag.TextFits and c.caption.TextFits)
   for _,node in ipairs({c.tag,c.heading,c.caption})do
    local y=node.AbsolutePosition.Y-c.frame.AbsolutePosition.Y
    assert(y>=0 and y+node.AbsoluteSize.Y<=c.frame.AbsoluteSize.Y+.5,"short final copy escapes host "..node.Name)
   end
   assert(c.heroHost.AbsolutePosition.X+c.heroHost.AbsoluteSize.X<=c.heading.AbsolutePosition.X-11.9)
  end)

  test("all seven real subjects fit the rectangular viewport through every greeting frame",function()
   for _,size in ipairs({Vector2.new(600,360),Vector2.new(338,420),Vector2.new(500,180)})do
    root.Size=UDim2.fromOffset(size.X,size.Y);settle()
    for _,pet in ipairs(Pets.collection)do
     local c=make();c:play(packet(pet.id,pet.family~=nil),nil,{skipIntro=true});c:disconnectClock();settle();c:disconnectClock()
     assert(c.renderMode=="3D"and c.heroViewport and not c.heroViewport:FindFirstChildOfClass("UIGradient"))
     if c.landscapeLayout then assert(c.heroHost.Position.X.Offset+c.heroHost.Size.X.Offset<=c.heading.Position.X.Offset-11.9,"hero band crosses the text column")
     else assert(c.heroHost.Position.Y.Offset+c.heroHost.Size.Y.Offset<=c.heading.Position.Y.Offset-7.9,"hero band crosses the exact caption/name")end
     visibleFit(c,pet.id.."/rest/"..tostring(size))
     c.heroVisual:greet()
     for frame=1,90 do c.heroVisual:update(1/60);visibleFit(c,pet.id.."/greeting@"..frame.."/"..tostring(size))end
     local preference=Gui.PreferredTextSize.Name
     local row={pet=pet.id,size=tostring(size),preference=preference,fraction=c.heroFraction,limited=c.fitLimited,reason=c.fitReason,preparationMs=c.heroPreparationMs,sweptPoints=#c.sweptPoints,bandHeight=c.heroHost.AbsoluteSize.Y,stageHeight=c.frame.AbsoluteSize.Y}
     assert(c.heroFraction>0 and c.heroFraction<=.63)
     if not c.fitLimited and size.Y>=300 then assert(c.heroFraction>=.48,"unconstrained subject did not fill its stage")end
     if (pet.id=="pip"or pet.id=="puddle")and size.X>=500 then
      -- The two largest preferences have separately reviewed native 600x360
      -- compositions; only an independently measured text reserve qualifies.
      local textException=(preference=="Larger"or preference=="Largest")and size==Vector2.new(600,360)and not c.landscapeLayout and c.fitLimited and c.fitReason=="text reserve"
      if textException then
       local wrap=c.frame.AbsoluteSize.X-24
       local function canonical(node,fontSize,font,minimum)
        local offset=TextService:GetTextSizeOffsetAsync(fontSize,Font.fromEnum(font))
        local probe=TextService:GetTextSize("Mg",fontSize,font,Vector2.new(10000,10000)).Y
        local measuredSize=if offset>0 and probe<fontSize+offset-1 then fontSize+offset else fontSize
        local bounds=TextService:GetTextSize(node.Text,measuredSize,font,Vector2.new(wrap,10000))
        local required=math.max(minimum,math.ceil(bounds.Y)+4)
        assert(node.TextFits and node.TextBounds.Y<=node.AbsoluteSize.Y+.5,preference.." exception hid canonical copy: "..node.Name)
        assert(math.abs(node.AbsoluteSize.Y-required)<=1,preference.." label reservation differs from independent canonical measurement: "..node.Name)
        return{required=required,height=node.AbsoluteSize.Y,width=node.AbsoluteSize.X,nativeHeight=node.TextBounds.Y}
       end
       local tag=canonical(c.tag,18,Art.Font.Supporting,18)
       local name=canonical(c.heading,28,Art.Font.Heading,24)
       local caption=canonical(c.caption,18,Art.Font.Supporting,18)
       local expectedBand=c.frame.AbsoluteSize.Y-tag.required-name.required-caption.required-30
       assert(expectedBand>0 and expectedBand<c.frame.AbsoluteSize.Y*.65 and math.abs(expectedBand-c.heroHost.AbsoluteSize.Y)<=1,"Largest text budget does not independently explain restricted hero band")
       assert(c.tag.AbsolutePosition.Y+c.tag.AbsoluteSize.Y<=c.heroHost.AbsolutePosition.Y-5,"Largest tag crosses the hero")
       assert(c.heroHost.AbsolutePosition.Y+c.heroHost.AbsoluteSize.Y<=c.heading.AbsolutePosition.Y-7,"Largest name crosses the hero")
       assert(c.heading.AbsolutePosition.Y+c.heading.AbsoluteSize.Y<=c.caption.AbsolutePosition.Y-3 and c.caption.AbsolutePosition.Y+c.caption.AbsoluteSize.Y<=c.frame.AbsolutePosition.Y+c.frame.AbsoluteSize.Y-7,"Largest caption escapes its reserved stage")
       row.exception=preference.."600x360 canonical text budget; Medium normal48% floor retained"
       row.canonicalLabels={tag=tag,name=name,caption=caption};row.independentBand=expectedBand
       local onePixel=1/math.max(1,c.frame.AbsoluteSize.Y)
       assert(c.heroFraction+onePixel>=.40,string.format("%s Largest text-constrained fraction%.6f below40%% beyondonepixel; band%.1f/%.1f labels%.1f/%.1f/%.1f",pet.id,c.heroFraction,expectedBand,c.frame.AbsoluteSize.Y,tag.required,name.required,caption.required))
      else
       -- The swept greeting envelope can trade at most two actual stage pixels
       -- against the 48% composition target; all swept corners remain checked.
       local pixelBudget=if preference=="Medium"and c.fitLimited and c.fitReason=="full greeting"then 2 else 0
       local shortfall=math.max(0,(.48-c.heroFraction)*c.frame.AbsoluteSize.Y)
       row.normalFitShortfallPixels=shortfall;row.normalFitPixelBudget=pixelBudget
       assert(shortfall<=pixelBudget+.000001,string.format("%s normal %s stage fraction %.6f limited by %s; 48%% shortfall %.3fpx exceeds %.1fpx",pet.id,preference,c.heroFraction,c.fitReason,shortfall,pixelBudget))
      end
     end
     table.insert(geometry,row)
     c:destroy()
    end
   end
  end)
  test("all seven maximum simultaneous features and Ring fit the smallest swept greeting stage",function()
   root.Size=UDim2.fromOffset(484,203);settle()
   for _,pet in ipairs(Pets.collection)do
    local c=make();c.compactLandscape=true
    c:play(packet(pet.id),nil,{skipIntro=true,appearance={charmVisible=true,charmShape="ring",featureStages={horns=5,claws=5,wings=5}}});c:disconnectClock();settle();c:disconnectClock()
    assert(c.heroVisual.featureStages.horns==5 and c.heroVisual.featureStages.claws==5 and c.heroVisual.featureStages.wings==5)
    visibleFit(c,pet.id.."/all-max/rest");c.heroVisual:greet()
    for frame=1,90 do c.heroVisual:update(1/60);visibleFit(c,pet.id.."/all-max/greet@"..frame)end
    c:destroy()
   end
  end)
  test("common and rare split within1.5/1.7s and settle with no idle clock or audio replay",function()
   root.Size=UDim2.fromOffset(600,360);settle()
   for _,rare in ipairs({false,true})do
    local c,sounds=make();local completed,presented=0,0
    c:play(packet(if rare then "foxfire_wick"else "puddle",rare),function()completed+=1 end,{onPresented=function()presented+=1 end})
    assert(presented==1 and c.active and c.connection and c.heroConnection==nil)
    local count=#c.frame:GetDescendants();advance(c,c.splitAt+.25)
    assert(c.liveBits==(if rare then 20 else 12),"jewel droplets/rare prism count exceeded existing pool")
    assert((c.discoveryArt.top.Visible and c.discoveryArt.bottom.Visible)or c.shell.Visible,"neither loaded split nor complete unavailable-asset egg visible")
    if c.discoveryArt.top.Visible then assert(c.discoveryArt.top.Position.X.Offset<c.center.X and c.discoveryArt.bottom.Position.X.Offset>c.center.X,"patterned halves did not split outward")end
    if rare then
     local center=c.outlineCenter or c.center
     for i=17,20 do
      local node=c.bits[i];local theta=math.rad(35+(i-17)*90)
      assert(node.Size.Y.Offset>c.heroPixels*.2 and node.BackgroundTransparency<.21,string.format("rare ray phase age%.6f paint~%.6f residual%.6f split%.2f length%.2f threshold%.2f alpha%.3f",c.age,c.age-(c.sampleAge or 0),c.sampleAge or 0,c.splitAt,node.Size.Y.Offset,c.heroPixels*.2,node.BackgroundTransparency))
      assert((node.Position.X.Offset-center.X)*math.cos(theta)>0 and(node.Position.Y.Offset-center.Y)*math.sin(theta)>0,"rare rays did not spread across quadrants")
     end
     assert(c.bits[17].BackgroundColor3~=c.bits[18].BackgroundColor3,"rare rays lost gold/family contrast")
    end
    for _,node in ipairs(c.bits)do if node.Visible then
     local angle=math.rad(node.Rotation);local ex=(math.abs(math.cos(angle))*node.Size.X.Offset+math.abs(math.sin(angle))*node.Size.Y.Offset)*.5
     local ey=(math.abs(math.sin(angle))*node.Size.X.Offset+math.abs(math.cos(angle))*node.Size.Y.Offset)*.5
     assert(node.Position.X.Offset-ex>=0 and node.Position.X.Offset+ex<=c.layoutWidth and node.Position.Y.Offset-ey>=0 and node.Position.Y.Offset+ey<=c.layoutHeight,"burst bit escapes stage")
    end end
    advance(c,c.duration-c.age+.001);assert(completed==1 and not c.active and not c.connection and c.liveBits==0 and not c.discoveryArt.top.Visible and not c.discoveryArt.bottom.Visible,string.format("terminal age%.9f duration%.9f complete%d active%s clock%s bits%d",c.age,c.duration,completed,tostring(c.active),tostring(c.connection~=nil),c.liveBits))
    local position=c.bits[1].Position;local cues=#sounds;advance(c,2)
    assert(c.bits[1].Position==position and not c.connection and c.liveBits==0 and #sounds==cues and #c.frame:GetDescendants()==count)
    c:finishStatic();assert(completed==1);c:destroy()
   end
  end)
  test("quiet same-ID final and reduced first visibility reserve marker and complete synchronously",function()
   local c,sounds,_,reduce=make();local complete,presented=0,0
   c:play(packet("pip"),function()complete+=1 end,{skipIntro=true,onPresented=function()presented+=1 end})
   assert(complete==1 and presented==1 and #sounds==0 and not c.active and c.resultRoot.Visible)
   c:cancel();reduce(true)
   c:play(packet("pip"),function()complete+=1 end,{onPresented=function()presented+=1 end})
   assert(complete==2 and presented==2 and #sounds==0 and not c.connection and c.liveBits==0)
   local writes=c.writes;for _=1,20 do c:refreshOwner()end;assert(c.writes==writes)
   c:destroy()
  end)
  test("covered first play defers marker while presented owner loss lands final and stops its clock",function()
   local c,sounds,owner=make();owner(false);local complete,presented=0,0
   c:play(packet("pip"),function()complete+=1 end,{onPresented=function()presented+=1 end})
   assert(presented==0 and #sounds==0 and not c.connection)
   assert(not c:skip()and c.active and complete==0 and presented==0,"covered stale skip settled unseen result")
   owner(true);assert(presented==1 and c.connection and #sounds==1)
   advance(c,.6);owner(false);assert(complete==1 and not c.active and not c.connection and c.liveBits==0)
   local writes,cues=c.writes,#sounds;for _=1,20 do c:refreshOwner()end;assert(c.writes==writes and #sounds==cues)
   owner(true);advance(c,.2);assert(c.connection==nil and #sounds==cues)
   c:destroy()
  end)
  test("resize keeps exact hero and epoch and device discontinuity settles only once",function()
   local c,sounds,_,_,audio=make();local complete=0;c:play(packet("orbit"),function()complete+=1 end)
   advance(c,.5);local viewport,visual,epoch=c.heroViewport,c.heroVisual,c.epoch
   root.Size=UDim2.fromOffset(420,260);settle();c:disconnectClock();c:layout()
   assert(c.heroViewport==viewport and c.heroVisual==visual and c.epoch==epoch)
   audio.deviceEpoch=2;c:step(.01);assert(complete==1 and not c.active and c.deviceEpoch==2)
   local age,cues=c.age,#sounds;advance(c,.2);assert(c.age==age and not c.connection and #sounds==cues and complete==1)
   c:destroy()
  end)
  test("candidate minimum height is independent of previous stage and painted text sizes",function()
   root.Size=UDim2.fromOffset(600,360);settle();local c=make()
   c:play({id="candidate-sizing-fixture",petId="foxfire_wick",rare=true,duplicate=true,promotedTo=3},nil,{skipIntro=true});c:disconnectClock()
   local viewport,epoch=c.heroViewport,c.epoch
   local expected=c:minimumHeightForWidth(540,195)
   root.Size=UDim2.fromOffset(484,276);settle();c:disconnectClock();c:layout()
   assert(c:minimumHeightForWidth(540,195)==expected,"previous stacked layout changed landscape candidate")
   c.heading.TextSize,c.tag.TextSize,c.caption.TextSize=9,44,8
   assert(c:minimumHeightForWidth(540,195)==expected,"candidate used mutable painted font sizes")
   assert(c:minimumHeightForWidth(484,276)>=160 and c.heroViewport==viewport and c.epoch==epoch)
   c:layout();c:destroy()
  end)
  test("pixel fallback and twenty canceled cycles retain a fixed passive pool",function()
   root.Size=UDim2.fromOffset(600,360);settle();local c,sounds=make();c.forceFallback=true
   c:play(packet("puddle"),nil,{skipIntro=true});assert(c.renderMode=="PixelFallback"and c.portrait and not c.heroViewport);c:cancel()
   c.forceFallback=false;local count=#c.frame:GetDescendants()
   for _=1,20 do c:play(packet("pip"),nil,{skipIntro=true});c:cancel();assert(#c.frame:GetDescendants()==count and not c.connection and c.liveBits==0)end
   assert(#c.bits==24 and #sounds==0);for _,bit in ipairs(c.bits)do assert(not bit.Visible and not bit.Active and not bit.Selectable)end
   c:destroy();assert(not c.connection and #c.connections==0 and #c.ancestorConnections==0)
  end)
 end)
 for _,c in ipairs(views)do c:destroy()end;root:Destroy();assert(ok,problem)
 return{passed=#cases,cases=cases,geometry=geometry,fixtureOnly=true}
end
