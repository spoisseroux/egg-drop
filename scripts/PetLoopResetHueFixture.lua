-- TEMPORARY native layout fixture. Run returned function on the client with the
-- actual production Client folder. All modules get fresh identities, never its
-- entry LocalScript. Workspace controls: HueFixturePage (buy/palette),
-- HueFixtureHeld, HueFixtureMix, HueFixtureResult; optional HueFixturePet,
-- HueFixtureWidth/Height (0=available), HueFixtureCleanup=true. No real save path.
return function(client)
 local Players=game:GetService("Players");local Gui=game:GetService("GuiService")
 local playerGui=Players.LocalPlayer:FindFirstChildOfClass("PlayerGui");assert(playerGui,"native local PlayerGui required")
 local originalSelection=Gui.SelectedObject
 local gui=Instance.new("ScreenGui");gui.Name="_PET_LOOP_HUE_LAYOUT_FIXTURE";gui.ResetOnSpawn=false
 gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.DisplayOrder=1000;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=playerGui
 local backdrop=Instance.new("Frame");backdrop.Name="IsolatedFixtureBackdrop";backdrop.Size=UDim2.fromScale(1,1)
 backdrop.BackgroundColor3=Color3.fromRGB(23,32,34);backdrop.BorderSizePixel=0;backdrop.Active=true;backdrop.Parent=gui
 local badge=Instance.new("TextLabel");badge.Name="FixtureLabel";badge.BackgroundTransparency=1;badge.TextColor3=Color3.fromRGB(255,224,129)
 badge.Font=Enum.Font.GothamBold;badge.TextSize=12;badge.Size=UDim2.new(1,-12,0,24);badge.Position=UDim2.fromOffset(6,0);badge.ZIndex=100;badge.Parent=backdrop
 local root=Instance.new("Frame");root.Name="FixtureSafeViewport";root.AnchorPoint=Vector2.new(.5,.5)
 root.BackgroundTransparency=1;root.ClipsDescendants=true;root.Parent=backdrop
 local modules=Instance.new("Folder");modules.Name="_FreshProductionModules";modules.Parent=gui
 local View,Intent
 local defaults={HueFixturePage="buy",HueFixtureHeld=true,HueFixtureMix=false,HueFixtureResult=false,HueFixturePet="pip",HueFixtureWidth=0,HueFixtureHeight=0,HueFixtureCleanup=false}
 local originals,connections={},{};local view,intent;local destroyed=false;local revision,serial=0,0
 local outputNames={"HueFixtureReady","HueFixtureIntents","HueFixtureInfo"}
 for name,value in pairs(defaults)do originals[name]={value=workspace:GetAttribute(name)};if workspace:GetAttribute(name)==nil then workspace:SetAttribute(name,value)end end
 for _,name in ipairs(outputNames)do originals[name]={value=workspace:GetAttribute(name)}end
 local function cleanup()
  if destroyed then return end;destroyed=true
  for _,connection in ipairs(connections)do connection:Disconnect()end;table.clear(connections)
  if view then view:destroy()end
  gui:Destroy()
  for name,old in pairs(originals)do workspace:SetAttribute(name,old.value)end
  if originalSelection and originalSelection.Parent and originalSelection:IsDescendantOf(playerGui)then Gui.SelectedObject=originalSelection else Gui.SelectedObject=nil end
 end
 local function number(name,maximum)
  local n=workspace:GetAttribute(name)
  return if type(n)=="number"and n==n and n>0 and n<math.huge then math.clamp(n,1,maximum)else maximum
 end
 local function refresh()
  if destroyed then return end
  if workspace:GetAttribute("HueFixtureCleanup")==true then cleanup();return end
  local available=backdrop.AbsoluteSize
  if available.X<100 or available.Y<100 then return end
  local width=number("HueFixtureWidth",math.max(1,available.X));local height=number("HueFixtureHeight",math.max(1,available.Y-24))
  root.Size=UDim2.fromOffset(width,height);root.Position=UDim2.new(.5,0,0,24+(available.Y-24)/2)
  local mixed=workspace:GetAttribute("HueFixtureMix")==true;local result=workspace:GetAttribute("HueFixtureResult")==true
  local held=workspace:GetAttribute("HueFixtureHeld")==true and not result
  local page=if mixed then "palette"elseif workspace:GetAttribute("HueFixturePage")=="palette"then "palette"else "buy"
  if result then page="buy"end
  local pet=if workspace:GetAttribute("HueFixturePet")=="puddle"then "puddle"else "pip"
  revision+=1
  local state={status="Ready",revision=revision,nectar=if held or result then 10 else 18,inventoryMask=3,hues={}}
  for _,id in ipairs({"pip","puddle"})do state.hues[id]={ranks={rose=1,tide=2,citrus=0,iris=0},body="tide",secondary="rose"}end
  if held then state.heldHueEgg={token="fixture-held-token",purchaseId="fixture-purchase"}end
  if result then
   state.hues[pet].body="rose";state.hues[pet].secondary="default"
   state.hueLastPurchase={id="fixture-purchase"}
   state.lastHueResult={id="fixture-applied-"..revision,action="hueApply",petId=pet,hue="rose",newRank=1,secondaryUnlocked=true,revision=revision}
  end
  intent.pending,intent.receipt,intent.lastRecordId=nil,nil,nil
  intent.status,intent.message=if result then "Saved"else "Ready",if result then "Saved"else nil
  view:open(state,page,pet)
  if mixed then view:chooseMix("rose");view:chooseMix("tide")elseif held then view:chooseHue("rose")end
  badge.Text=string.format("READ-ONLY LAYOUT FIXTURE | %s%s | %dx%d | no remotes or profile writes",if result then "applied result"else page,if mixed then " / Mix"elseif held then " / held"else "",width,height)
  workspace:SetAttribute("HueFixtureInfo",badge.Text);workspace:SetAttribute("HueFixtureReady",true)
 end
 local ok,problem=xpcall(function()
  for _,child in ipairs(client:GetChildren())do if child:IsA("ModuleScript")then child:Clone().Parent=modules end end
  local Art=require(modules.DeckArt);Art.applyTheme(require(client.DeckArt).getTheme())
  View,Intent=require(modules.HueEggView),require(modules.HueIntent)
  intent=Intent.new({id=function()serial+=1;return"fixture-"..serial end,available=function()return true end,
   changed=function()if view then view:refresh()end end,
   send=function(action,value,expected)
    workspace:SetAttribute("HueFixtureIntents",(workspace:GetAttribute("HueFixtureIntents")or 0)+1)
    -- Actual controller quote, injected read-only transport: no RemoteEvent exists.
    intent:receive({id=value.id,petId=value.petId,action=action,status="Rejected",reason="FixtureReadOnly",revision=expected})
   end})
  view=View.new(root,intent,{appearance=function()return{charmVisible=true}end,closed=cleanup})
  for name in pairs(defaults)do table.insert(connections,workspace:GetAttributeChangedSignal(name):Connect(refresh))end
  table.insert(connections,backdrop:GetPropertyChangedSignal("AbsoluteSize"):Connect(refresh))
  table.insert(connections,gui.Destroying:Connect(cleanup))
  workspace:SetAttribute("HueFixtureIntents",0);refresh()
 end,debug.traceback)
 if not ok then cleanup();error(problem)end
 return{view=view,intent=intent,root=root,gui=gui,refresh=refresh,destroy=cleanup}
end
