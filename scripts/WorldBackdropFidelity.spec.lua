-- v887 QA (2026-11-17): the backdrop ring (cloud sea, far peaks) is about 1,800 studs a
-- mesh. At Automatic fidelity a phone at a low graphics level swaps in a coarse LOD that
-- rose through the garden as a pink wall. RenderFidelity cannot be set at runtime, so
-- the template in ServerStorage must carry Precise.
return function()
 local template=game:GetService("ServerStorage"):FindFirstChild("WorldAssets")
 template=template and template:FindFirstChild("WorldV7")
 assert(template,"ServerStorage.WorldAssets.WorldV7 is present")
 local count,loose=0,{}
 for _,part in ipairs(template:GetDescendants())do
  if part:IsA("MeshPart")and part.Name:find("^W7_Backdrop__")then
   count+=1
   if part.RenderFidelity~=Enum.RenderFidelity.Precise then table.insert(loose,part.Name)end
  end
 end
 assert(count>=8,"the backdrop ring has its 5 clouds and 3 far peaks ("..count..")")
 assert(#loose==0,"backdrop meshes at Precise fidelity: "..table.concat(loose,", "))
 return {passed=2,cases={"backdrop ring present","backdrop meshes never drop to a coarse LOD"}}
end
