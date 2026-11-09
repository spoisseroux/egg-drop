-- Saved portrait motion and channel-scoped reset; injected snapshot, no profile writes.
return function(client,parent)
 require(script.Parent.PetAssetsReadyFixture)(client,{"pip","puddle"})
 local View=require(client.HueEggView);local Intent=require(client.HueIntent)
 local Run=game:GetService("RunService");local Http=game:GetService("HttpService")
 local root=Instance.new("Frame");root.Size=UDim2.fromOffset(900,720);root.Parent=parent
 local sent,cases={},{};local active="pip";local reduced=false;local view;local audio={deviceActive=true,plays=0}
 function audio:play()self.plays+=1;return true end
 local intent=Intent.new({id=function()return "portrait-reset"end,send=function(a,v)table.insert(sent,{action=a,value=v})end,changed=function()if view then view:refresh()end end})
 view=View.new(root,intent,{activePet=function()return active end,equipPet=function(id)active=id;return true end,audio=audio,reduceEffects=function()return reduced end,appearance=function()return {charmVisible=true,charmShape="ring"}end})
 local counts={main={rose=2,tide=1,citrus=0,iris=0},secondary={rose=0,tide=0,citrus=1,iris=2}}
 local state={status="Ready",revision=1,nectar=24,inventoryMask=127,hues={},petHues={pip=counts,puddle=counts},hueInventory={rose=3,tide=1,citrus=2,iris=2,reset=2}}
 local function frames(n)for _=1,n or 3 do Run.RenderStepped:Wait()end end
 local function elapsed(seconds)local deadline=os.clock()+seconds;repeat Run.RenderStepped:Wait()until os.clock()>=deadline end
 local function test(name,run)run();table.insert(cases,name)end
 local ok,problem=pcall(function()
  view:open(state,"palette","pip");frames();local visual=view.visual
  test("one muted saved portrait uses production 15Hz sampler without camera or state drift",function()
   assert(visual.sampledPose and visual.poseCadence==15 and not visual.worldContext and view.portraitClock)
   local clock=view.portraitClock;local camera=view.camera.CFrame;local before=Http:JSONEncode(state);local bucket=visual.poseBucket
   elapsed(.18);view:syncPortraitClock()
   assert(view.portraitClock==clock and visual.poseBucket~=bucket and view.camera.CFrame==camera)
   assert(Http:JSONEncode(state)==before and #sent==0 and audio.plays==0 and not visual.cooStart)
  end)
  test("inspection and stock-only refresh preserve visual identity phase and fixed framing",function()
   local camera=view.camera.CFrame;local t=visual.cosmeticTime;local clock=view.portraitClock
   assert(view:inspectHue("rose",4));state.hueInventory.rose=4;view:refresh()
   assert(view.visual==visual and view.portraitClock==clock and visual.cosmeticTime==t and view.camera.CFrame==camera)
   frames();assert(visual.cosmeticTime>=t and #sent==0 and audio.plays==0)
  end)
  test("confirmation and close retire their clock and cancel restores only one clock",function()
   assert(view:chooseItem("rose")and view.portraitClock==nil);local t=visual.cosmeticTime;frames(4)
   assert(visual.cosmeticTime==t);assert(view:cancelConfirmation()and view.portraitClock)
   view:close("test");assert(view.portraitClock==nil);t=visual.cosmeticTime;frames(4);assert(visual.cosmeticTime==t)
   view:open(state,"palette","pip");frames();assert(view.portraitClock and view.visual==visual)
  end)
  test("reduced motion is static and blur pauses without voice or a camera reframe",function()
   reduced=true;frames();assert(visual.reducedEffects);local t=visual.cosmeticTime;local bucket=visual.poseBucket;local camera=view.camera.CFrame
   frames(5);assert(visual.cosmeticTime==t and visual.poseBucket==bucket and view.camera.CFrame==camera)
   reduced=false;frames();audio.deviceActive=false;frames();t=visual.cosmeticTime;frames(4);assert(visual.cosmeticTime==t)
   audio.deviceActive=true;frames();assert(visual.cosmeticTime>=t and audio.plays==0)
  end)
  test("pet swap and destroy cannot update the retired visual or retain a render connection",function()
   local old=view.visual;assert(view:choosePet("puddle")and view:activate());view:syncActive();frames();assert(old.destroyed and view.visual~=old and view.portraitClock)
   local now=view.visual;view:destroy();assert(view.portraitClock==nil and now.destroyed);frames(4);assert(view.destroyed)
  end)
 end)
 if not view.destroyed then view:destroy()end;root:Destroy();assert(ok,problem)
 -- A second owner isolates the confirmed transaction from the lifecycle tests.
 root=Instance.new("Frame");root.Size=UDim2.fromOffset(568,210);root.Parent=parent;view=nil
 intent=Intent.new({id=function()return "portrait-reset"end,send=function(a,v)table.insert(sent,{action=a,value=v})end,changed=function()if view then view:refresh()end end})
 view=View.new(root,intent,{reduceEffects=function()return true end})
 ok,problem=pcall(function()
  test("reset quotes and consumes exactly one selected channel while preserving the other",function()
   view:open(state,"palette","pip");assert(view:chooseItem("reset"));frames()
   assert(view.title.Text=="Reset Main color?"and view.confirmDelta.Text=="Restore white Main")
   assert(view.confirmWarning.Text=="Erase Rose 2/5 and Tide 1/5"and view.confirmStock.Text=="2 jars → 1")
   assert(view:cancelConfirmation());view:chooseChannel("secondary");assert(view:chooseItem("reset"));frames()
   assert(view.title.Text=="Reset Secondary color?"and view.confirmDelta.Text=="Restore grey Secondary")
   assert(view.confirmWarning.Text=="Erase Citrus 1/5 and Iris 2/5")
   assert(view:activate()and not view:activate()and #sent==1)
   local packet=sent[1].value;assert(packet.itemId=="reset"and packet.channel=="secondary"and packet.counts.citrus==1 and packet.counts.iris==2)
   assert(state.petHues.pip.main.rose==2 and state.petHues.pip.main.tide==1 and audio.plays==0)
  end)
 end)
 view:destroy();root:Destroy();assert(ok,problem);return{passed=#cases,cases=cases}
end
