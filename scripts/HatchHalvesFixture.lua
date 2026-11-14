-- Coordinator-run native geometry proof, never a production asset mutation.
-- Compare two actual MeshId orientations at recorded semantic assembly centres.
return function(parent)
 local root=Instance.new("Frame");root.Name="HatchHalvesProof";root.Size=UDim2.fromOffset(812,354);root.BackgroundColor3=Color3.fromHex("#132F31");root.Parent=parent
 local result={root=root,worlds={},variants={}}
 for index,angle in ipairs({0,180})do
  local viewport=Instance.new("ViewportFrame");viewport.Name="Orientation"..angle;viewport.BackgroundTransparency=1;viewport.Position=UDim2.fromOffset((index-1)*406,40);viewport.Size=UDim2.fromOffset(406,300);viewport.Ambient=Color3.fromRGB(180,180,180);viewport.LightColor=Color3.new(1,1,1);viewport.LightDirection=Vector3.new(-1,-1,-2);viewport.Parent=root
  local world=Instance.new("WorldModel");world.Parent=viewport;local camera=Instance.new("Camera");camera.FieldOfView=32;camera.CFrame=CFrame.lookAt(Vector3.new(1.25,1.10,2.4),Vector3.new(0,.40,0));camera.Parent=viewport;viewport.CurrentCamera=camera
  local parts={}
  for _,row in ipairs({{"Left","138813947452098",-.2487184256,Color3.fromHex("#76D9F7")},{"Right","106574437908727",.2487184256,Color3.fromHex("#EF786B")}})do
   local p=game:GetService("AssetService"):CreateMeshPartAsync(Content.fromUri("rbxassetid://"..row[2]))
   p.Name="Semantic"..row[1];p.Size=Vector3.new(.4974368513,.8234862685,.9948737025);p.CFrame=CFrame.new(row[3],.4117431343,0)*CFrame.Angles(0,math.rad(angle),0)
   p.TextureID="";p.Color=row[4];p.Material=Enum.Material.SmoothPlastic;p.Anchored=true;p.CanCollide=false;p.DoubleSided=false;p.Parent=world;table.insert(parts,p)
  end
  local label=Instance.new("TextLabel");label.BackgroundTransparency=1;label.Text="Actual halves / local Y rotation "..angle.."°";label.TextColor3=Color3.new(1,1,1);label.TextSize=18;label.Size=UDim2.fromOffset(406,36);label.Position=UDim2.fromOffset((index-1)*406,0);label.Parent=root
  table.insert(result.worlds,world);table.insert(result.variants,{angle=angle,parts=parts,camera=camera,viewport=viewport})
 end
 function result:destroy()self.root:Destroy()end
 return result
end
