return function(client,parent)
 local Scene=require(client.HatchDisplayScene);local Pose=require(client.HatchDisplayPose)
 local Run=game:GetService("RunService");local count=0
 for _,id in ipairs({"wobble_top","ball"})do
  local root=Instance.new("Frame");root.Size=UDim2.fromOffset(200,200);root.Parent=parent
  local scene=Scene.new(root,{kind="toy",result={id="item-fit-"..id,toyId=id}})
  local ok,problem=pcall(function()
   local untilTime=os.clock()+3;repeat Run.Heartbeat:Wait()until scene.ready or os.clock()>untilTime
   assert(scene.ready and not scene.failure and scene.item.mode=="Object3D","actual toy/egg assets required")
   scene:layout()
   for index=22,62 do
    scene:render(Pose.sample(index/20,"toy",false));local lo,hi=scene:itemProjectionBounds()
    assert(lo.X>=.02 and lo.Y>=.02 and hi.X<=.98 and hi.Y<=.98,"item swept fit cropped at "..index/20)
   end
   local lo,hi,contact=scene:itemProjectionBounds();local span=math.max(hi.X-lo.X,hi.Y-lo.Y)
   assert(span>=.55 and span<=.60,string.format("settled%s longest %.1fpx",id,span*200))
   assert(contact and contact.Y>=.78 and contact.Y<=.82,string.format("settled%s contactline %.3f",id,contact and contact.Y or -1))
  end)
  scene:destroy();root:Destroy();assert(ok,problem);count+=1
 end
 -- QA R2 (2026-11-15): a finish is shown worn by a Bear, and a 3D result turns on its
 -- upright axis by orbiting the hero camera only; flat Hue art does not turn.
 do
  local root=Instance.new("Frame");root.Size=UDim2.fromOffset(200,200);root.Parent=parent
  local scene=Scene.new(root,{kind="material",result={id="item-fit-gloss",finishId="gloss"},resultBuilder=function()error("the sample tile is not used when the Bear can wear the finish")end})
  local ok,problem=pcall(function()
   local untilTime=os.clock()+3;repeat Run.Heartbeat:Wait()until scene.ready or os.clock()>untilTime
   assert(scene.ready and not scene.failure and scene.item.mode=="PetFinish"and scene.item.visual.petId=="pip","a finish is worn by the Bear")
   assert(scene.item.visual.appearance.finish=="gloss"and #scene.item.entries>3 and scene.item.visual.worldContext==false,"a display Bear in the finish, outside the garden")
   scene:layout()
   for index=22,62 do
    scene:render(Pose.sample(index/20,"material",false));local lo,hi=scene:itemProjectionBounds()
    assert(lo.X>=.02 and lo.Y>=.02 and hi.X<=.98 and hi.Y<=.98,"the Bear is cropped at "..index/20)
   end
   local lo,hi=scene:itemProjectionBounds();local span=math.max(hi.X-lo.X,hi.Y-lo.Y)
   assert(span>=.50 and span<=.80,string.format("settled Bear longest %.1fpx",span*200))
   local base=scene.heroCamera.CFrame;local stage=scene.stageCamera.CFrame;local light=scene.heroView.LightDirection
   assert(scene:setSpin(math.rad(90))and scene.heroCamera.CFrame~=base and scene.stageCamera.CFrame==stage,"the hero camera orbits; the egg camera stays")
   assert((scene.heroCamera.CFrame.Position-scene.itemPivot).Magnitude>1 and math.abs((scene.heroCamera.CFrame.Position-scene.itemPivot).Magnitude-(base.Position-scene.itemPivot).Magnitude)<1e-3,"orbit keeps its distance")
   assert(math.abs(scene.heroCamera.CFrame.Position.Y-base.Position.Y)<1e-4 and scene.heroView.LightDirection~=light,"an upright turn, with the light")
   scene:layout();assert(scene.heroCamera.CFrame~=scene.stageCamera.CFrame,"a new layout keeps the turn")
   assert(not scene:setSpin(0)and scene.heroCamera.CFrame==scene.stageCamera.CFrame and scene.heroView.LightDirection==light,"zero restores the shared camera")
   scene:setBare(true,false);assert(scene.heroView.Ambient~=Color3.fromRGB(155,181,164),"a stage lights the item itself")
   scene:setSpin(1);scene:setBare(false);assert(scene.spin==0 and scene.heroView.Ambient==Color3.fromRGB(155,181,164),"handing the scene back resets light and turn")
  end)
  scene:destroy();root:Destroy();assert(ok,problem);count+=1
  local flatRoot=Instance.new("Frame");flatRoot.Size=UDim2.fromOffset(200,200);flatRoot.Parent=parent
  local flat=Scene.new(flatRoot,{kind="hue",result={id="item-fit-rose",itemId="rose"},resultBuilder=function(gui)local f=Instance.new("Frame");f.Parent=gui;return f end})
  local ok2,problem2=pcall(function()
   assert(flat.item.mode=="NativeItemArt"and not flat:setSpin(1)and flat.spin==0,"flat jar art does not turn")
  end)
  flat:destroy();flatRoot:Destroy();assert(ok2,problem2);count+=1
 end
 return{passed=count,cases={"200px Wobble Top fitted hero","200px Ball fitted hero","a finish is worn by the Bear and turns by camera orbit","flat Hue art does not turn"}}
end
