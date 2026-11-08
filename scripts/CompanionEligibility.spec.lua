-- Actual nearest-six controller with an injected player inventory, no real remote avatars.
return function(client)
 local Companions=require(client.RoomCompanions);local Players=game:GetService("Players")
 local own=assert(Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart"))
 local folder=Instance.new("Folder");folder.Name="_CompanionEligibility";folder.Parent=workspace
 local boards=Instance.new("Folder");boards.Parent=folder;local peers={Players.LocalPlayer};local dead,created=0,0
 for i=1,8 do
  local character=Instance.new("Model");character.Name="Peer"..i;character.Parent=folder
  local root=Instance.new("Part");root.Name="HumanoidRootPart";root.Anchored=true;root.CanCollide=false;root.CanQuery=false;root.Transparency=1;root.CFrame=CFrame.new(own.Position+Vector3.new(i,0,0));root.Parent=character
  local h=Instance.new("Humanoid");h.RequiresNeck=false;h.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None;h.Parent=character
  local peer={UserId=900000+i,Character=character};table.insert(peers,peer)
  local board=Instance.new("Folder");board.Name=tostring(peer.UserId);board:SetAttribute("Mode","Room");board:SetAttribute("CompanionId","pip");board.Parent=boards
 end
 local function create(_,position)
  created+=1;local model=Instance.new("Model");model.Parent=folder;local body=Instance.new("Part");body.Anchored=true;body.CanCollide=false;body.CanQuery=false;body.Transparency=1;body.Parent=model;model.PrimaryPart=body
  return{model=model,origin=position,worldScale=.72,update=function()end,destroy=function()dead+=1;model:Destroy()end}
 end
 local c=Companions.new(boards,create,function()return false end,{players=function()return peers end})
 local cases={};local function count()local n=0;for _ in pairs(c.active)do n+=1 end;return n end
 local ok,err=pcall(function()
  c:update(.12);assert(count()==6 and c.active[peers[2]]and not c.active[peers[8]]);table.insert(cases,"nearest six live peers remain the presentation cap")
  peers[2].Character.Humanoid.Health=0;c.refreshIn=0;c:update(.12)
  assert(count()==6 and not c.active[peers[2]]and c.active[peers[8]]);table.insert(cases,"dead nearer humanoid yields to next live peer")
  local peer=peers[3];local old=peer.Character.HumanoidRootPart;old.Name="OldRoot"
  local replacement=old:Clone();replacement.Name="HumanoidRootPart";replacement.Parent=peer.Character;c.refreshIn=0;c:update(.12)
  assert(c.active[peer].root==replacement and c.active[peer].visual.gaitWeight==0 and c.active[peer].visual.movementBob==0)
  table.insert(cases,"nearby replacement root resets gait and bob generation")
  for _=1,5 do c:clear();assert(count()==0);c:update(.12);assert(count()==6)end
  c:clear();assert(created==dead and count()==0);table.insert(cases,"repeated owner cycles destroy every old remote rig")
 end)
 c:clear();folder:Destroy();assert(ok,err);return cases
end
