-- QA layout only: fake private inventory, zero remotes, no awards or saves.
return function(client)
 local p=game.Players.LocalPlayer
 local q=script.Parent
 local View=require(client.HueEggView)
 local Hue=require(client.HueIntent)
 local Material=require(client.MaterialIntent)
 local H=require(game.ReplicatedStorage.Shared.HueCatalog)
 require(q.PetAssetsReadyFixture)(client)
 local pg=p.PlayerGui
 local source=pg.EggDropOverlays.SafeContent
 local gui=Instance.new('ScreenGui');gui.Name='_PlayfulScreen_LAYOUT_FIXTURE';gui.ScreenInsets=Enum.ScreenInsets.None;gui.DisplayOrder=200;gui.ResetOnSpawn=false;gui.Parent=pg
 local host=Instance.new('Frame');host.BackgroundTransparency=1;host.Parent=gui
 local label=Instance.new('TextLabel');label.Text='LAYOUT FIXTURE / fake owned inventory / no saves';label.TextScaled=true;label.Size=UDim2.fromOffset(440,20);label.Position=UDim2.fromOffset(90,0);label.BackgroundTransparency=.2;label.Parent=gui
 local view
 local function changed()if view then view:refresh()end end
 local function noSend()error('Layout fixture must not send')end
 local hue=Hue.new({id=function()return 'fixture' end,send=noSend,changed=changed})
 local material=Material.new({id=function()return 'fixture' end,send=noSend,changed=changed})
 view=View.new(host,hue,{materialIntent=material,activePet=function()return 'pip'end,reduceEffects=function()return true end,appearance=function()return {charmVisible=true,charmShape='ring'}end})
 local hidden={};for _,g in pg:GetChildren()do if g:IsA('ScreenGui')and g~=gui then hidden[g]=g.Enabled;g.Enabled=false end end
 local function align()host.Position=UDim2.fromOffset(source.AbsolutePosition.X-gui.AbsolutePosition.X,source.AbsolutePosition.Y-gui.AbsolutePosition.Y);host.Size=UDim2.fromOffset(source.AbsoluteSize.X,source.AbsoluteSize.Y)end
 local function show()
  align();view:close('fixture')
  local state={revision=1,status='Ready',inventoryMask=127,nectar=64,hueInventory={rose=3,citrus=1,reset=1},petHues={},materialAvailable=true,materialUnlocks={gloss=true,matte=true},petMaterials={pip='gloss'}}
  for _,pet in ipairs(require(game.ReplicatedStorage.Shared.PetCatalog).collection)do state.petHues[pet.id]={main=H.emptyCounts(),secondary=H.emptyCounts()}end
  local page=q:GetAttribute('ScreenPage')or 'hue'
  if page=='materialReceipt'then state.pendingMaterialResult={id='fixture-material',finishId='gloss',revision=1,catalogVersion=1}
  elseif page=='fruitReceipt'or page=='resetReceipt'then local id=if page=='resetReceipt'then 'reset'else 'citrus';state.pendingHueResult={id='fixture-'..id,itemId=id,revision=1,inventoryAfter=1}
  end
  view:open(state,page,'pip')
 end
 show()
 local c=q:GetAttributeChangedSignal('ScreenPage'):Connect(show)
 local d=source:GetPropertyChangedSignal('AbsoluteSize'):Connect(align)
 local e;e=q:GetAttributeChangedSignal('StudyCleanup'):Connect(function()if q:GetAttribute('StudyCleanup')then c:Disconnect();d:Disconnect();e:Disconnect();view:destroy();material:destroy();gui:Destroy();for g,on in hidden do if g.Parent then g.Enabled=on end end end end)
 return view
end
