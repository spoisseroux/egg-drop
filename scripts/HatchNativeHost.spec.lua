-- Host contract only: synthetic cinematic/Stage interfaces, real receipt adapters.
-- Actual scene, lower-shell assets and floor/render proof belong to native specs.
return function(client,parent)
 local Item=require(client.HueItemReveal);local View=require(client.EggHatchView)
 local Pets=require(game:GetService("ReplicatedStorage").Shared.PetCatalog)
 local root=Instance.new("Frame");root.Name="_HatchNativeHost";root.Size=UDim2.fromOffset(812,354);root.Parent=parent
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local ok,problem=pcall(function()
  test("item receipt unlocks while decorative owner remains active",function()
   local record={created=0,destroyed=0}
   local function factory(host)
    record.created+=1
    local c={frame=Instance.new("Frame"),active=true,state={inputLocked=true,receiptReady=false,decorativeActive=true},graphic=Instance.new("Frame")}
    c.frame.Parent=host;c.graphic.Parent=c.frame
    function c:getPresentationState()return self.state end
    function c:getItemGraphic()return self.graphic end
    function c:play(packet,done,options)
     self.packet=packet;self.done=done;self.options=options
     if options.skipIntro then self.active=false;self.state={inputLocked=false,receiptReady=true,decorativeActive=false};done()end
    end
    function c:consumeSkipInput()return false end
    function c:skip()
     if not self.state.inputLocked then return false end
     self.state.inputLocked=false;self.state.receiptReady=true;self.done();return true
    end
    function c:destroy()record.destroyed+=1;self.frame:Destroy()end
    record.current=c;return c
   end
   local item=Item.new(root,{recipeId="toy",cinematicFactory=factory})
   local receipt={id="saved-toy",toyId="wobble_top",revision=7}
   assert(item:show(receipt,true));local c=record.current
   assert(c.options.nativeDisplay==true and c.packet.id==receipt.id and receipt.revision==7)
   assert(item.jar==c.graphic and item.top==nil and item.bottom==nil,"native host touched legacy shell internals")
   c.state.inputLocked=false;c.state.receiptReady=true;c.done()
   assert(c.active and c.state.decorativeActive and item:receiptReady()and not item:inputLocked()and not item.active)
   assert(not item:skip(),"ready receipt was consumed as decorative skip")
   assert(not item:show(receipt,true)and not item.active and record.created==1,"same receipt rebuilt scene or relocked tail")
   item:clear();assert(record.destroyed==1 and record.created==1)
   assert(not item:show(receipt,true)and record.current.options.skipIntro==true,"same saved receipt replayed intro after reopen")
   item:destroy();assert(record.destroyed==2)
  end)
  test("companion host borrows exact scene and never destroys cinematic ownership",function()
   local scene={destroyed=0};local captured,stage
   local host={shade=Instance.new("Frame"),stageLayer=Instance.new("Frame"),card=Instance.new("Frame"),audio={},state={},reducedEffects=false}
   host.shade.Parent=root;host.shade.Visible=true;host.stageLayer.Parent=host.shade;host.card.Parent=host.shade
   host.hideRevealStage=View.hideRevealStage;host.ownsInput=function()return true end
   host.syncRevealButtons=function()end;host.chooseResult=function()end;host.revealPlay=function()end
   host.stageRenderer={show=function(_,options)
    captured=options;stage={destroyed=0};function stage:destroy()self.destroyed+=1 end;return stage
   end}
   local result={id="saved-bear",petId="pip",starter=true}
   local drain=function()return true end
   local returned=View.showRevealStage(host,{result=result,pet=Pets.byId.pip,scene=scene,externalClock=true,fresh=true,consumeSkipInput=drain})
   assert(returned==stage and captured.scene==scene and captured.externalClock==true and captured.result==result)
   assert(captured.consumeSkipInput==drain and captured.consumeSkipInput(),"same skip input can confirm receipt")
   assert(host.card.Interactable==false and host.stageLayer.Visible)
   View.hideRevealStage(host)
   assert(stage.destroyed==1 and scene.destroyed==0 and host.card.Interactable and not host.stageLayer.Visible,"UI host destroyed borrowed scene")
  end)
  test("destroyed result host rejects queued layout and update without reparenting Notice",function()
   local view=View.new(root,{play=function()end},true,function()error("destroyed host sent a command")end)
   view.nativeDisplay=false
   view.noticeManaged=true;view.managedSaveNotice={short="Saving",detail="Your surprise is safe while the save finishes."}
   view:open({status="Ready",revision=1,lastHatch={id="destroyed-host",petId="pip",starter=true},nectar=6})
   assert(view.note.Parent==view.body,"fixture must exercise scrolling Notice ownership")
   view:queueSelectedRecipe()
   view.shade:Destroy()
   game:GetService("RunService").Heartbeat:Wait()
   assert(view.destroyed and view.inputLink==nil and view.sizeLink==nil and view.bodySizeLink==nil and view.eggClock==nil)
   assert(not view:isOpen()and not view:ownsInput(),"retired host still owns global input")
   assert(view.note.Parent==nil)
   local before=view.state
   local safe,problem=pcall(function()view:layout();view:layoutShop();view:renderBody();view:update({status="Ready",revision=2});view:retire()end)
   assert(safe,problem);assert(view.state==before and view.note.Parent==nil,"late update revived a retired result host")
  end)
 end)
 root:Destroy();assert(ok,problem);return{passed=#cases,cases=cases}
end
