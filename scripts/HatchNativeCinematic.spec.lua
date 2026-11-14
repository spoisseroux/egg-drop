-- Real receipt/cinematic GUI owners with a synthetic asset-free scene seam.
-- This proves lifecycle only; actual mesh/UV/render proof is separate.
return function(client,parent)
 local C=require(client.HatchCinematic);local Stage=require(client.RevealStage)
 local root=Instance.new("Frame");root.Size=UDim2.fromOffset(812,354);root.Parent=parent
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local ok,problem=pcall(function()
  test("one scene borrowed once, ready while tail active, cancel releases before destroy",function()
   local record={creates=0,borrows=0,releases=0,destroys=0,completed=0,actions=0};local c=C.new(root,nil,false,function()return true end)
   local stage
   c.stageHandoff=function(info)
    stage=Stage.show(root,{scene=info.scene,externalClock=true,pet=info.pet,result=info.result,
     buttons={{id="meet",text="Meet",primary=true}},owns=function()return true end,onSkip=function()c:skip()end,consumeSkipInput=info.consumeSkipInput,onButton=function()record.actions+=1 end})
    return stage
   end
   c.stageClear=function()stage:destroy()end
   local function create(home)
    record.creates+=1;local s={ready=true,root=Instance.new("Frame")};s.root.Parent=home
    function s:borrow(seat)record.borrows+=1;self.root.Parent=seat;return self end
    function s:release(token)assert(token==self);record.releases+=1;self.root.Parent=home end
    function s:render(sample)self.sample=sample end
    function s:layout()end
    function s:destroy()assert(record.releases==record.borrows);record.destroys+=1;self.root:Destroy()end
    function s:getItemGraphic()return nil end
    function s:setAppearance(value)record.appearance=value end
    return s
   end
   c:play({id="native-lifecycle-fixture",petId="pip"},function()record.completed+=1 end,{nativeDisplay=true,sceneFactory=create})
   c:disconnectClock()
   local appearance={body="rose",bodyRank=3};c:setAppearance(appearance)
   assert(record.appearance==appearance,"late saved appearance was not forwarded to the native owner")
   for _=1,14 do c:step(.2);c:disconnectClock()end
   local state=c:getPresentationState()
   assert(state.receiptReady and not state.inputLocked and state.decorativeActive and c.active)
   assert(record.completed==1 and not c:skip()and stage:isSettled())
   assert(not c:skipInputBegan({KeyCode=Enum.KeyCode.ButtonA})and not c:consumeSkipInput(),"ready A was incorrectly drained during decorative tail")
   assert(stage:confirm()and record.actions==1,"ready A/Enter did not activate exactly once")
   for _=1,10 do c:step(.2);c:disconnectClock()end
   assert(record.completed==1 and not c.active and record.creates==1 and record.borrows==1)
   c:cancel();assert(record.releases==1 and record.destroys==1)
   c:play({id="native-held-skip-fixture",petId="pip"},function()record.completed+=1 end,{nativeDisplay=true,sceneFactory=create})
   c:disconnectClock();local held={KeyCode=Enum.KeyCode.ButtonA}
   assert(c:skipInputBegan(held)and c:consumeSkipInput())
   assert(not stage:confirm()and record.actions==1,"the held skip also activated receipt")
   c:releaseSkipInput(held);task.wait(.06)
   assert(not c:consumeSkipInput()and stage:confirm()and record.actions==2)
   c:cancel();assert(record.releases==2 and record.destroys==2)
   c.reduceEffects=true
   c:play({id="native-reduced-fade-fixture",petId="pip"},function()record.completed+=1 end,{nativeDisplay=true,sceneFactory=create})
   c:disconnectClock();assert(c.active and c:getPresentationState().inputLocked)
   c:step(.05);c:disconnectClock();assert(c.active and not c:getPresentationState().receiptReady)
   c:step(.10);c:disconnectClock();assert(not c.active and c:getPresentationState().receiptReady and record.completed==3)
   assert(c.presentationSample.hop==0 and c.presentationSample.shellAlpha==0 and c.presentationSample.blink==1)
   c:cancel();c:destroy();assert(record.releases==3 and record.destroys==3)
  end)
 end)
 root:Destroy();assert(ok,problem);return {passed=#cases,cases=cases}
end
