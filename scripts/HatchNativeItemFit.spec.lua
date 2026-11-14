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
 return{passed=count,cases={"200px Wobble Top fitted hero","200px Ball fitted hero"}}
end
