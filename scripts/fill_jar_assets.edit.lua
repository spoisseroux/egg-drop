-- Run in Studio Edit (Studio MCP execute_luau, Edit datamodel) after Rojo syncs
-- assets/jars/JarAssets.rbxmx. Rojo live sync creates MeshParts with an empty MeshId, so
-- JarModel falls back to the flat jar until this fills them from the uploaded Model.
-- Idempotent. Ids: assets/art-source/jars/customization-jars-meshids.json (Model 111754744827256).
local pack=assert(game:GetService("ReplicatedStorage"):FindFirstChild("JarAssets"),"JarAssets is not synced yet")
local source=game:GetService("InsertService"):LoadAsset(111754744827256)
local byName={};for _,d in ipairs(source:GetDescendants())do if d:IsA("MeshPart")then byName[d.Name]=d end end
local filled,kept=0,0
for _,part in ipairs(pack:GetChildren())do
 local made=assert(byName[part.Name],"not in the uploaded model: "..part.Name)
 if part.MeshId==made.MeshId then kept+=1 else
  local size=part.Size;part:ApplyMesh(made);part.Size=size
  part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=false
  filled+=1
 end
end
source:Destroy()
return string.format("JarAssets: %d filled, %d already set",filled,kept)
