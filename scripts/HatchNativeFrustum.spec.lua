-- Actual authored native rig and every visible part corner across animation,
-- resize and late rig fit. A failed asset load is a failure, not render proof.
return function(client,parent)
 local Scene=require(client.HatchDisplayScene);local Pose=require(client.HatchDisplayPose)
 local Pets=require(game:GetService("ReplicatedStorage").Shared.PetCatalog)
 local Run=game:GetService("RunService");local root=Instance.new("Frame");root.Size=UDim2.fromOffset(812,354);root.Parent=parent
 local scene=Scene.new(root,{kind="companion",pet=Pets.byId.pip,result={id="native-frustum",petId="pip"}})
 local ok,problem=pcall(function()
  local deadline=os.clock()+3
  repeat Run.Heartbeat:Wait()until scene.ready or os.clock()>deadline
  assert(scene.ready and not scene.failure and scene.visual.backend=="AuthoredMesh","actual authored assets required: "..tostring(scene.failure))
  for _,size in ipairs({Vector2.new(812,354),Vector2.new(640,354),Vector2.new(354,500)})do
   root.Size=UDim2.fromOffset(size.X,size.Y);Run.Heartbeat:Wait();scene:layout()
   for index=22,88 do
    local age=index/20;scene:render(Pose.sample(age,"companion",false))
    local lo,hi,count=scene:projectionBounds()
    assert(count>0 and lo.X>=.03 and lo.Y>=.03 and hi.X<=.97 and hi.Y<=.97,
     string.format("native frustum %.2f %dx%d: %.4f %.4f / %.4f %.4f",age,size.X,size.Y,lo.X,lo.Y,hi.X,hi.Y))
   end
  end
 end)
 scene:destroy();root:Destroy();assert(ok,problem)
 return{passed=1,cases={"native swept corner frustum fits entrance/hop/waves at three aspects"}}
end
