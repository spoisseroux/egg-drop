-- QA v735 H2: the Ball toy reads as a tennis ball (src/client/PetToyGeometry.lua).
-- Toys v2 (QA v760): optic yellow-green felt (a true sphere) and the real one-piece white
-- seam, a mesh from ReplicatedStorage.PetToyAssets. Geometry only; no remotes.
-- Run (Client): require(Client.ZZSpecs.TennisBallToy)(Client)
return function(client,parent)
 local Toys=require(client.PetToyGeometry)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local root=Instance.new("Folder");root.Name="_TennisBallToy";root.Parent=parent or workspace
 local ok,problem=pcall(function()
  test("two parts, inside the part limit, felt first",function()
   assert(game.ReplicatedStorage:FindFirstChild("PetToyAssets"),"Install the toy mesh pack (assets/toys/PetToyAssets.rbxmx)")
   local h=assert(Toys.create(root,"ball",1))
   assert(#h.parts==2 and #h.parts<=Toys.PartLimit,"parts "..#h.parts)
   local felt=h.model:FindFirstChild("FeltBall")
   assert(h.model.PrimaryPart==felt,"the felt is the primary part")
   assert(felt:FindFirstChildOfClass("SpecialMesh").MeshType==Enum.MeshType.Sphere,"the felt is a true sphere")
   for _,p in ipairs(h.parts)do assert(p.Anchored and not p.CanQuery and not p.CanTouch and not p.CanCollide,p.Name)end
   h:destroy()
  end)
  test("the felt is optic yellow-green, not coral",function()
   local h=assert(Toys.create(root,"ball",1));local hue,sat,val=h.model.FeltBall.Color:ToHSV();h:destroy()
   assert(hue>.15 and hue<.24,"hue "..hue);assert(sat>.6 and val>.8,"saturated and bright")
  end)
  test("one white seam mesh wraps the ball, centred on it and just proud of the felt",function()
   local h=assert(Toys.create(root,"ball",1));local felt=h.model.FeltBall
   local seam=assert(h.model:FindFirstChild("Seam"),"no seam")
   assert(seam:IsA("MeshPart")and seam.MeshId~="","the seam is the modelled mesh")
   local _,sat,val=seam.Color:ToHSV();assert(sat<.1 and val>.95,"the seam is white")
   assert((seam.Position-felt.Position).Magnitude<1e-4,"centred on the ball")
   -- The seam curve never reaches the poles of its own axes, so its box is a little
   -- smaller than the ball's on every axis, yet it wraps most of the way round each.
   for _,axis in ipairs({"X","Y","Z"})do
    local ratio=seam.Size[axis]/felt.Size[axis];assert(ratio>.8 and ratio<1.02,axis.." ratio "..ratio)
   end
   h:destroy()
  end)
  test("it scales with the pet and the old coral ball and seam discs are gone",function()
   local h=assert(Toys.create(root,"ball",2.5))
   assert(math.abs(h.model.FeltBall.Size.X-.6)<1e-4 and math.abs(h.model.Seam.Size.X-.2127*2.5)<1e-3)
   assert(not(h.model:FindFirstChild("CoralBall")or h.model:FindFirstChild("OffsetCreamEquator")or h.model:FindFirstChild("TealDimple")))
   assert(not(h.model:FindFirstChild("SeamArcL")or h.model:FindFirstChild("SeamArcR")))
   h:destroy()
  end)
  test("play and hold are unchanged",function()
   assert(Toys.Play.ball=="roll"and Toys.has("ball")and Toys.hold("ball")==Toys.Hold.ball)
  end)
 end)
 root:Destroy();assert(ok,problem);return cases
end
