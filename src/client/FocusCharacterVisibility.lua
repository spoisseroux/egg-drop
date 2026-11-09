-- Owner-client presentation only. Never writes replicated Transparency.
-- Each prior modifier belongs to one scope and is restored exactly once.
local Run=game:GetService("RunService")
local Visibility={}
local serial=0
function Visibility.acquire(character)
 serial+=1
 local binding="PetFocusCharacterHide"..serial
 local scope={character=character,records={},connections={},released=false}
 local function restore(node)
  local record=scope.records[node];if not record then return end
  scope.records[node]=nil
  if record.connection then record.connection:Disconnect()end
  pcall(function()node.LocalTransparencyModifier=record.prior end)
 end
 local function hide(node)
  if scope.released or scope.records[node]or not(node:IsA("BasePart")or node:IsA("Decal"))then return end
  -- Older Decal implementations may expose no local modifier; their parent
  -- BasePart is still hidden. Never substitute replicated Transparency.
  local ok,prior=pcall(function()return node.LocalTransparencyModifier end)
  if not ok then return end
  local record={prior=prior};scope.records[node]=record
  node.LocalTransparencyModifier=1
  record.connection=node:GetPropertyChangedSignal("LocalTransparencyModifier"):Connect(function()
   if not scope.released and scope.records[node]==record and node.LocalTransparencyModifier~=1 then node.LocalTransparencyModifier=1 end
  end)
 end
 function scope:release()
  if self.released then return end;self.released=true
  Run:UnbindFromRenderStep(binding)
  for _,connection in ipairs(self.connections)do connection:Disconnect()end
  table.clear(self.connections)
  local nodes={};for node in pairs(self.records)do table.insert(nodes,node)end
  for _,node in ipairs(nodes)do restore(node)end
 end
 if character then
  table.insert(scope.connections,character.DescendantAdded:Connect(hide))
  table.insert(scope.connections,character.DescendantRemoving:Connect(restore))
  table.insert(scope.connections,character.Destroying:Connect(function()scope:release()end))
  for _,node in ipairs(character:GetDescendants())do hide(node)end
  Run:BindToRenderStep(binding,Enum.RenderPriority.Camera.Value+3,function()
   if scope.released then return end
   -- CameraModule may repaint its own local modifiers each frame. Reassert
   -- only the cached owner parts after the camera, without rescanning the rig.
   for node in pairs(scope.records)do
    if node.Parent and node.LocalTransparencyModifier~=1 then node.LocalTransparencyModifier=1 end
   end
  end)
 end
 return scope
end
return Visibility
