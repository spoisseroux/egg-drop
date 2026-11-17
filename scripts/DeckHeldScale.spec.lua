-- v887 QA (2026-11-17): the held Pocket Deck drew its Shell and FrontPlate about
-- 100x too big (a ~180-stud pink slab every player saw), because the template was
-- cloned from Rojo-synced parts whose mesh initial size was wrong. Every resolved
-- part must carry the same mesh data as a fresh CreateMeshPartAsync of its id, at
-- the template's size.
-- Usage: require(ServerScriptService.Server.ZZSpecs.DeckHeldScale)(ServerScriptService.Server)
return function(server)
 local AssetService=game:GetService("AssetService")
 local Lounge=require(server.Lounge)
 local source=game:GetService("ServerStorage"):FindFirstChild("PocketDeckSlim")
 assert(source,"ServerStorage.PocketDeckSlim present")
 local model=Lounge.slimTemplate()
 assert(model,"template resolves")
 local count=0
 for _,piece in ipairs(model:GetChildren())do
  assert(piece:IsA("MeshPart"),piece.Name.." is a MeshPart")
  local fresh=AssetService:CreateMeshPartAsync(piece.MeshId)
  assert((piece.MeshSize-fresh.MeshSize).Magnitude<1e-3,piece.Name.." keeps the mesh's real initial size ("..tostring(piece.MeshSize).." vs "..tostring(fresh.MeshSize)..")")
  local want=source:FindFirstChild(piece.Name)
  assert(want and (piece.Size-want.Size).Magnitude<1e-4,piece.Name.." keeps the template size")
  assert(piece.Size.Magnitude<3,piece.Name.." is hand-sized")
  fresh:Destroy();count+=1
 end
 assert(count==9,"all nine deck parts resolve ("..count..")")
 return {passed=3,cases={"every held-deck part rebuilt from its mesh id","real mesh initial size, template part size","nine parts"}}
end
