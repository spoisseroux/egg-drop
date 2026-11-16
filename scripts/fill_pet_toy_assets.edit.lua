-- Run once in Studio Edit (Studio MCP execute_luau, Edit datamodel) after Rojo first syncs
-- assets/toys/PetToyAssets.rbxmx. Rojo live sync creates new MeshParts with an empty
-- MeshId, so PetToyGeometry falls back to spheres until this fills them. Idempotent.
-- Ids: assets/art-source/toys/pet-toys-meshids.json (Model asset 134846528553129).
local ids={
 ["ball__Seam"]="rbxassetid://102329939674898",
 ["bone__BoneBody"]="rbxassetid://137042441955734",
 ["pocket_deck__DeckBezel"]="rbxassetid://123918361490939",
 ["pocket_deck__DeckButtonA"]="rbxassetid://123911422852662",
 ["pocket_deck__DeckButtonB"]="rbxassetid://87382607179370",
 ["pocket_deck__DeckPad"]="rbxassetid://138807671772266",
 ["pocket_deck__DeckScreen"]="rbxassetid://136674259833613",
 ["pocket_deck__DeckShell"]="rbxassetid://121290658538978",
 ["sparkler__BrassWire"]="rbxassetid://135226153244448",
 ["sparkler__IndigoGrip"]="rbxassetid://75806402366250",
 ["sparkler__SparkBurst"]="rbxassetid://90940228734119",
 ["squeaky_carrot__CarrotBody"]="rbxassetid://126606412872656",
 ["squeaky_carrot__CarrotLeaves"]="rbxassetid://76365351419211",
 ["wobble_top__BrassStem"]="rbxassetid://127207206867390",
 ["wobble_top__CoralFoot"]="rbxassetid://122695115582822",
 ["wobble_top__CreamEquator"]="rbxassetid://114751455189964",
 ["wobble_top__TealBody"]="rbxassetid://106475586216672",
}
local AssetService=game:GetService("AssetService")
local pack=assert(game:GetService("ReplicatedStorage"):FindFirstChild("PetToyAssets"),"PetToyAssets is not synced yet")
local filled,kept=0,0
for name,id in pairs(ids)do
 local part=assert(pack:FindFirstChild(name),"missing template "..name)
 if part.MeshId==id then kept+=1 else
  local size=part.Size
  local made=AssetService:CreateMeshPartAsync(Content.fromUri(id),{CollisionFidelity=Enum.CollisionFidelity.Box})
  part:ApplyMesh(made);made:Destroy()
  part.Size=size;part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=false
  filled+=1
 end
end
return string.format("PetToyAssets: %d filled, %d already set",filled,kept)
