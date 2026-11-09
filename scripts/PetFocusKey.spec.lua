-- One local focus-only raking light; no per-pet or global lighting changes.
return function(client)
 local Key=require(client.PetFocusKey);local camera=assert(workspace.CurrentCamera);local key=Key.new()
 local folder=Instance.new("Folder");folder.Name="_FocusKeyFixture";folder.Parent=workspace
 local v={model=folder,origin=camera.CFrame.Position+camera.CFrame.LookVector*4,bodyBoundsFrame=CFrame.new(camera.CFrame.Position+camera.CFrame.LookVector*4)}
 local cases={};local ok,err=pcall(function()
  key:update(camera,v,false,0);assert(not key.part);table.insert(cases,"roaming allocates no light")
  key:update(camera,v,true,0);assert(key.light and key.light.Enabled and key.light.Range==14 and math.abs(key.light.Brightness-.6)<.00001 and key.part.Parent==camera)
  local part,light=key.part,key.light;key:update(camera,v,true,0);assert(key.part==part and key.light==light and #part:GetChildren()==1);table.insert(cases,"one bounded raking key reused in close night focus")
  key:update(camera,v,false,0);assert(not light.Enabled);key:update(camera,v,true,1);assert(not light.Enabled)
  local foreign=Instance.new("Camera");key:update(foreign,v,true,0);assert(not light.Enabled);foreign:Destroy()
  v.nightTreatment="groupedRoleFill";key:update(camera,v,true,0);assert(not light.Enabled);table.insert(cases,"leave/day/camera replacement and baseline disable key")
 end)
 key:destroy();folder:Destroy();assert(ok,err);return cases
end
