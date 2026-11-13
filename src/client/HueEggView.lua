-- Customize (UI-SPEC-REDESIGN-MENUS-2026-11-12 section 2) and saved item receipts.
-- The palette page is the Kit screen family: shared header, icon tabs Hue / Charm /
-- Materials / Toys (Features behind Shared.FeatureFlags), a card grid and a pinned
-- preview pane with one primary action. Pet and Wardrobe are rows on the Companions
-- hub now; receipts' "Use now" lands on the hub's Pets selector (options.petsSelector),
-- with the in-editor recipient page kept underneath as the fallback. Confirmations,
-- receipts, migration and buy pages keep the transaction card.
local GuiService=game:GetService("GuiService")
local UserInputService=game:GetService("UserInputService")
local Shared=game:GetService("ReplicatedStorage").Shared
local Hues=require(Shared.HueCatalog)
local Eggs=require(Shared.EggCatalog)
local Pets=require(Shared.PetCatalog)
local Swatches=require(script.Parent.HueSwatches)
local CharmCatalog=require(Shared.PetCharmCatalog)
local Palette=require(Shared.PetPalette)
local Art=require(script.Parent.DeckArt)
local EggArt=require(script.Parent.EggArt)
local JarArt=require(script.Parent.HueJarArt)
local ItemReveal=require(script.Parent.HueItemReveal)
local Factory=require(script.Parent.PetFactory)
local Bounds=require(script.Parent.PetRigBounds)
local MaterialCatalog=require(Shared.MaterialCatalog)
local MaterialPanel=require(script.Parent.MaterialPanel)
local ToyCatalog=require(Shared.ToyCatalog);local FeatureCatalog=require(Shared.FeatureCatalog)
local ToyPanel=require(script.Parent.ToyPanel);local FeaturePanel=require(script.Parent.FeaturePanel)
local Kit=require(script.Parent.DeckKit);local Cards=require(script.Parent.CustomizeCards)
local FeatureFlags=require(Shared.FeatureFlags)
local WearableCatalog=require(Shared.WearableCatalog)
local ReceiptLayout=require(script.Parent.ItemReceiptLayout)
local EatingProof=require(script.Parent.HueEatingProof);local FruitEating=require(script.Parent.PetFruitEating)
local View={};View.__index=View
local ids={"rose","tide","citrus","iris","reset"}
local names={rose="Rose fruit",tide="Tide fruit",citrus="Citrus fruit",iris="Iris fruit",reset="Reset Hue"}
local function place(n,x,y,w,h)n.Position,n.Size=UDim2.fromOffset(x,y),UDim2.fromOffset(w,h)end
local function text(parent,name,copy,role)
 local n=Art.text(parent,name,copy,UDim2.fromOffset(0,0),UDim2.fromOffset(100,24),"text",16)
 Art.type(n,role or "Body");n.TextXAlignment=Enum.TextXAlignment.Left;return n
end
local function button(parent,name,copy,callback)
 local n=Instance.new("TextButton");n.Name,n.Text,n.Parent=name,copy,parent;n.BorderSizePixel=0;n.ZIndex=parent.ZIndex+1
 Art.bind(n,{BackgroundColor3="raised",TextColor3="text"});Art.button(n,10);Art.type(n,"Action");n.Activated:Connect(callback);return n
end
local function channelName(channel)return if channel=="main"then "Main"else "Secondary"end
local function nonzero(counts)for _,id in ipairs(ids)do if(counts[id]or 0)>0 then return true end end;return false end
local function countsCopy(counts)local r=Hues.emptyCounts();for _,id in ipairs(ids)do if id~="reset"then r[id]=counts and counts[id]or 0 end end;return r end
local function luminance(color)
 local function linear(value)return if value<=.04045 then value/12.92 else((value+.055)/1.055)^2.4 end
 return linear(color.R)*.2126+linear(color.G)*.7152+linear(color.B)*.0722
end
local function swatchInk(color)
 local dark=Color3.new(0,0,0);local light=Color3.new(1,1,1);local value=luminance(color)
 return if(value+.05)/(luminance(dark)+.05)>1.05/(value+.05)then dark else light
end
function View.new(parent,intent,options)
 local shade=Art.frame(parent,"HueEggView","ink",UDim2.fromScale(0,0),UDim2.fromScale(1,1),20);shade.Visible=false;shade.Active=true;shade.BackgroundTransparency=1
 local card=Art.frame(shade,"Card","panel",UDim2.fromScale(.5,.5),UDim2.fromOffset(640,640),21);card.AnchorPoint=Vector2.new(.5,.5);Art.panel(card,18)
 local body=Instance.new("ScrollingFrame");body.Name,body.Parent="Body",card;body.BackgroundTransparency=1;body.BorderSizePixel=0;body.ZIndex=22
 body.Active=true -- Native scrolling owns wheel input instead of also zooming the garden camera.
 body.ScrollingDirection,body.ElasticBehavior=Enum.ScrollingDirection.Y,Enum.ElasticBehavior.Never;body.ScrollBarThickness=4;Art.bind(body,{ScrollBarImageColor3="accent"})
 local self=setmetatable({shade=shade,card=card,body=body,intent=intent,options=options or {},state={},petId="pip",page="palette",tab="hue",channel="main",targets={},jars={},bars={},charmRequests={},epoch=0},View)
 self.title=text(card,"Title","Customize","Heading");self.wallet=text(card,"Wallet","0 Stars","Counter")
 self.closeButton=Art.bareClose(button(card,"Close","×",function()self:close("back")end))
 self.action=button(card,"Action","Confirm",function()self:activate()end)
 self.cancel=button(card,"Cancel","Cancel",function()self:cancelConfirmation()end)
 -- Customize tabs are Kit.tabs segments built with the chrome; this maps tab id -> segment button.
 self.editorTabs={}
 self.eatingProof=EatingProof.new();self.fruitEating=FruitEating.new()
 self.toyIntent=self.options.toyIntent;self.featureIntent=self.options.featureIntent
 self.materialIntent=self.options.materialIntent
 self.materialPanel=MaterialPanel.new(body,self.materialIntent,{audio=self.options.audio,reduceEffects=self.options.reduceEffects,canEquip=function()return self.shade.Visible and self.page=="palette"and self.tab=="materials"and not self.confirmation and self.materialPanel.petId==self.petId and self:canCustomize()end,receiptOpen=function(result)return self.shade.Visible and self.page=="materialReceipt"and self.state.pendingMaterialResult and self.state.pendingMaterialResult.id==result.id end,shop=function()self:close("shop");if self.options.materialShop then self.options.materialShop()end end,
  useNow=function(result)self.materialAssignment={resultId=result.id,finishId=result.finishId};self:landOnPets(result)end})
 self.toyPanel=ToyPanel.new(body,self.toyIntent,{audio=self.options.audio,reduceEffects=self.options.reduceEffects,canEquip=function()return self.shade.Visible and self.page=="palette"and self.tab=="toys"and not self.confirmation and self.toyPanel.petId==self.petId and self:canCustomize()end,
  receiptOpen=function(result)return self.shade.Visible and self.page=="toyReceipt"and self.state.pendingToyResult and self.state.pendingToyResult.id==result.id end,
  shop=function()self:close("shop");if self.options.toyShop then self.options.toyShop()end end,
  useNow=function(result)self.toyAssignment={resultId=result.id,toyId=result.toyId};self:landOnPets(result)end})
 self.featurePanel=FeaturePanel.new(body,self.featureIntent,{audio=self.options.audio,reduceEffects=self.options.reduceEffects,canUse=function()return self.shade.Visible and self.page=="palette"and self.tab=="features"and not self.confirmation and self.featurePanel.petId==self.petId and self:canCustomize()end,
  receiptOpen=function(result)return self.shade.Visible and self.page=="featureReceipt"and self.state.pendingFeatureResult and self.state.pendingFeatureResult.id==result.id end,
  canAssignReceipt=function(resultId,featureId)return self.shade.Visible and self.page=="palette"and self.tab=="features"and not self.confirmation and self.featurePanel.petId==self.petId and self:hasFeatureAssignment()and self.featureAssignment.resultId==resultId and self.featureAssignment.featureId==featureId end,
  binding=function()return tostring(self.lifecycleEpoch)..":"..self.petId..":"..self.page..":"..self.tab end,
  shop=function()self:close("shop");if self.options.featureShop then self.options.featureShop()end end,
  changed=function()if self.shade.Visible then self:refresh()end end,
  preview=function(id,stage)self.featurePreview={petId=self.petId,id=id,stage=stage}end,
  cancelUse=function()if self.featureAssignment then self.tab="pet"end end,
  useNow=function(result)self.featureAssignment={resultId=result.id,featureId=result.featureId};self:landOnPets(result)end})
 self.targetTitle=text(body,"TargetTitle","Choose a pet","Action")
 for _,pet in ipairs(Pets.collection)do local id=pet.id;self.targets[id]=button(body,"Target_"..id,pet.name,function()self:choosePet(id)end)end
 self.targetChange=button(body,"ChangePet","Change pet",function()if not self.intent.pending then self.selectTarget=not self.selectTarget;self:refresh()end end)
 self.machinePickup=button(card,"MachinePickUp","Pick up",function()if self.options.careAction then self.options.careAction("carePickup")end end)
 self.machineSetDown=button(card,"MachineSetDown","Set down",function()if self.options.careAction then self.options.careAction("careSetDown")end end)
 self.mainTab=button(card,"MainTab","Main",function()self:chooseChannel("main")end)
 self.secondaryTab=button(card,"SecondaryTab","Secondary",function()self:chooseChannel("secondary")end)
 self.portrait=Art.frame(card,"PetPortrait","inset",UDim2.fromOffset(0,0),UDim2.fromOffset(240,170),23);Art.corner(self.portrait,16)
 self.viewport=Instance.new("ViewportFrame");self.viewport.Name="SavedPet";self.viewport.BackgroundTransparency=1;self.viewport.Size=UDim2.fromScale(1,1);self.viewport.ZIndex=24;self.viewport.Parent=self.portrait
 self.viewport.Ambient=Color3.fromRGB(175,184,183);self.viewport.LightColor=Color3.fromRGB(255,250,231);self.viewport.LightDirection=Vector3.new(-1,-1.4,-3)
 self.world=Instance.new("WorldModel");self.world.Parent=self.viewport;self.camera=Instance.new("Camera");self.camera.FieldOfView=30;self.camera.Parent=self.viewport;self.viewport.CurrentCamera=self.camera
 self.petName=text(card,"PetName","Bear","Action");self.petName.TextXAlignment=Enum.TextXAlignment.Center
 self.channelTitle=text(body,"ChannelTitle","Main","Action")
 self.inspection=text(body,"HueInspection","Choose a color to use one fruit.","Body")
 for _,id in ipairs(ids)do if id~="reset"then
  local row=Art.frame(body,"Dose_"..id,"inset",UDim2.fromOffset(0,0),UDim2.fromOffset(200,44),23);Art.corner(row,8)
  local label=text(row,"Label",names[id],"Body");local value=text(row,"Count","0/5","Counter");value.TextXAlignment=Enum.TextXAlignment.Right
  local ticks,stages={},{};for notch=0,5 do
   local stage=notch
   local tick=button(row,"Notch"..notch,tostring(notch),function()self:chooseNotch(id,stage)end);tick:SetAttribute("DoseStage",stage)
   tick:SetAttribute("SwatchColor",if stage==0 then Color3.new(1,1,1)else Hues.ById[id].color)
   Art.bind(tick,{BackgroundColor3=function()return tick:GetAttribute("SwatchColor")end,TextColor3=function()return tick:GetAttribute("SwatchInk")or Art.Ink end})
   for _,child in ipairs(tick:GetChildren())do if child:IsA("UIGradient")then child:Destroy()end end
   local check=Art.frame(tick,"SavedCheck",Art.Ink,UDim2.fromOffset(3,7),UDim2.fromOffset(12,9),tick.ZIndex+1);check.BackgroundTransparency=1;check.Active=false;check.Selectable=false
   local a=Art.frame(check,"A",Art.Ink,UDim2.fromOffset(0,3),UDim2.fromOffset(5,2),check.ZIndex);a.Rotation=45
   local b=Art.frame(check,"B",Art.Ink,UDim2.fromOffset(3,2),UDim2.fromOffset(9,2),check.ZIndex);b.Rotation=-45
   a.Visible=false;b.Visible=false
   table.insert(ticks,tick);stages[stage]=tick
  end
  self.bars[id]={row=row,label=label,value=value,ticks=ticks,stages=stages}
 end end
 self.inventoryTitle=text(body,"InventoryTitle","Your jars","Action")
 for _,id in ipairs(ids)do
  local n=button(body,"Item_"..id,"",function()self:chooseItem(id)end)
  local art=JarArt.create(n,id,UDim2.fromOffset(6,4),UDim2.fromOffset(44,52),n.ZIndex+1)
  local label=text(n,"ItemName",names[id],"Body");local quantity=text(n,"Quantity","×0","Counter");local reason=text(n,"Reason","","Supporting")
  self.jars[id]={button=n,art=art,label=label,quantity=quantity,reason=reason}
 end
 self.empty=text(body,"EmptyInventory","No jars yet. Find fixed-color fruit in Hue Eggs.","Body")
 self.charmTitle=text(body,"CharmTitle","A floating Snowflake, colored by Secondary.","Body")
 self.eggsButton=button(body,"FindEggs","Eggs",function()self:close("shop");local open=self.options.eggs or self.options.shop;if open then open()end end)
 self.shapes={};self.shapeIcons={};self.gridPreviews={};self.scrollPositions={}
 for _,id in ipairs(CharmCatalog.Order)do self.shapes[id]=button(body,"Shape_"..id,CharmCatalog.ById[id].name,function()self:selectCharm(id)end)end
 for id,node in pairs(self.shapes)do
  node.Text=""
  local icon=Art.frame(node,"ShapeIcon","inset",UDim2.fromOffset(12,10),UDim2.fromOffset(44,44),node.ZIndex+1);Art.corner(icon,10)
  local form=Art.frame(icon,"Shape",Art.Silver,UDim2.fromOffset(10,10),UDim2.fromOffset(24,24),icon.ZIndex+1)
  Art.corner(form,if id=="pebble"then 8 else 100)
  if id=="ring"then form.BackgroundTransparency=1;local edge=Art.stroke(form,Art.Silver,0,5);edge.Name="RingEdge"end
  if id=="pebble"then form.Rotation=-18;form.Size=UDim2.fromOffset(27,21)end
  -- The "dot" charm is the snowflake mesh: three crossed bars, tinted like the other forms.
  if id=="dot"then form.BackgroundTransparency=1
   for k=0,2 do local bar=Art.frame(form,"FlakeBar",Art.Silver,UDim2.fromOffset(10,0),UDim2.fromOffset(4,24),form.ZIndex+1);Art.corner(bar,2);bar.Rotation=k*60
    Art.bind(bar,{BackgroundColor3=function()return form.BackgroundColor3 end});form:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()bar.BackgroundColor3=form.BackgroundColor3 end)end
  end
  local label=text(node,"ShapeName",CharmCatalog.ById[id].name,"Action")
  local check=text(node,"SelectedCheck","✓","Action");check.TextXAlignment=Enum.TextXAlignment.Center;check.Visible=false
  Art.bind(label,{TextColor3=function()return node.TextColor3 end});Art.bind(check,{TextColor3=function()return node.TextColor3 end})
  local function ink()label.TextColor3=node.TextColor3;check.TextColor3=node.TextColor3 end
  node:GetPropertyChangedSignal("TextColor3"):Connect(ink);ink()
  self.shapeIcons[id]={tile=icon,form=form,label=label,check=check}
 end
 for _,pet in ipairs(Pets.collection)do
  local node=self.targets[pet.id];node.Text=""
  local viewport=Instance.new("ViewportFrame");viewport.Name="SavedPet";viewport.BackgroundTransparency=1;viewport.ZIndex=node.ZIndex+1;viewport.Parent=node
  viewport.Ambient=self.viewport.Ambient;viewport.LightColor=self.viewport.LightColor;viewport.LightDirection=self.viewport.LightDirection
  local world=Instance.new("WorldModel");world.Parent=viewport;local camera=Instance.new("Camera");camera.FieldOfView=30;camera.Parent=viewport;viewport.CurrentCamera=camera
  local caption=text(node,"PetName",pet.name,"Action");caption.TextXAlignment=Enum.TextXAlignment.Center
  local active=text(node,"Active","","Supporting");active.TextXAlignment=Enum.TextXAlignment.Center
  -- The labels sit on the tab fill, so they follow the tab's own ink: dark on a
  -- selected pastel deck fill, light on an unselected dark tile.
  Art.bind(caption,{TextColor3=function()return node.TextColor3 end});Art.bind(active,{TextColor3=function()return node.TextColor3 end})
  node:GetPropertyChangedSignal("TextColor3"):Connect(function()caption.TextColor3=node.TextColor3;active.TextColor3=node.TextColor3 end)
  local entry={button=node,viewport=viewport,world=world,camera=camera,caption=caption,active=active};self.gridPreviews[pet.id]=entry
  viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()if entry.visual and entry.fit then entry.fit()end end)
 end
 self.dot=self.shapes.dot
 self.receiptArt=Art.frame(body,"ResultJar","inset",UDim2.fromOffset(0,0),UDim2.fromOffset(150,160),23);self.receiptArt.BackgroundTransparency=1
 self.itemReveal=ItemReveal.new(self.receiptArt,{audio=self.options.audio,reduceEffects=self.options.reduceEffects})
 self.receipt=text(body,"SavedReceipt","","Reward");self.receipt.TextXAlignment=Enum.TextXAlignment.Center
 self.receiptDetail=text(body,"ReceiptDetail","Added to your items.","Body")
 self.useNow=button(body,"UseNow","Use now",function()self:useResult()end)
 self.quote=text(body,"Confirmation","","Body")
 self.confirmTarget=text(body,"ConfirmTarget","","Action")
 self.confirmDelta=text(body,"ConfirmDelta","","Action")
 self.confirmStock=text(body,"ConfirmStock","","Body")
 self.confirmWarning=text(body,"ConfirmWarning","","Body")
 self.resultSwatch=Art.frame(body,"ResultSwatch",Art.Silver,UDim2.fromOffset(0,0),UDim2.fromOffset(32,32),24);Art.corner(self.resultSwatch,8);Art.stroke(self.resultSwatch,"line",0,1)
 self.status=text(body,"Status","","Body")
 self.migrationText=text(body,"MigrationReceipt","","Body")
 self.legacyTitle=text(body,"LegacyTitle","Your carried Hue Egg: choose its fixed fruit once.","Body")
 self.legacyButtons={};for _,id in ipairs(ids)do if id~="reset"then self.legacyButtons[id]=button(body,"Redeem_"..id,names[id],function()self:requestLegacy(id)end)end end
 self.presetTitle=text(body,"LegacyPresetsTitle","Previous colors · available until the first new dose","Supporting");self.presetButtons={}
 shade:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()if shade.Visible then self:layout()end end)
 Art.watchTextPreference(shade,function()return shade.Visible end,function()self:layout()end)
 body:GetPropertyChangedSignal("CanvasPosition"):Connect(function()if self.shade.Visible then self:updateGrid(0)end end)
 shade.Destroying:Connect(function()self:destroy(true)end);return self
end
function View:isOpen()return self.shade.Visible end
function View:openWardrobe()
 if not self.shade.Visible or self.page~="palette"or self.confirmation or self.intent.pending or not self:canCustomize()then return false end
 if not WearableCatalog.hasItems(self.petId)or not self.options.wardrobe then return false end
 return self.options.wardrobe(self.petId)==true
end
function View:canCustomize()
 return not self.options.canCustomize or self.options.canCustomize(if self.machine then self.machine.petId else self.petId)==true
end
function View:hasHueAssignment()
 local result=self.state.pendingHueResult;local draft=self.assignment or self.confirmation
 if not draft or not draft.pendingResultId then return false end
 if result and result.id==draft.pendingResultId and result.itemId==draft.itemId then return true end
 local pending=self.intent.pending
 return pending~=nil and pending.action=="hueUse"and pending.value.pendingResultId==draft.pendingResultId and pending.value.itemId==draft.itemId
end
function View:hasToyAssignment()
 local r=self.state.pendingToyResult;local q=self.toyAssignment
 return r~=nil and q~=nil and r.id==q.resultId and r.toyId==q.toyId
end
function View:hasFeatureAssignment()
 local r=self.state.pendingFeatureResult;local q=self.featureAssignment
 return r~=nil and q~=nil and r.id==q.resultId and r.featureId==q.featureId
end
function View:hasReceiptAssignment()return self:hasHueAssignment()or self:hasMaterialAssignment()or self:hasToyAssignment()or self:hasFeatureAssignment()end
function View:eatingBinding()return tostring(self.lifecycleEpoch)..":"..self.petId..":"..self.channel..":"..tostring(self.shade.AbsoluteSize)end
function View:hasMaterialAssignment()
 local result=self.state.pendingMaterialResult;local draft=self.materialAssignment
 return result~=nil and draft~=nil and result.id==draft.resultId and result.finishId==draft.finishId
end
function View:owned(id)return Eggs.isOwned(self.state.inventoryMask or 0,id)end
function View:counts()local p=self.state.petHues and self.state.petHues[self.petId];return countsCopy(p and p[self.channel])end
function View:appearance()
 local appearance=table.clone(self.options.appearance and self.options.appearance(self.petId)or {})
 local p=self.state.petHues and self.state.petHues[self.petId]
 if p then appearance.mainDoses=countsCopy(p.main);appearance.secondaryDoses=countsCopy(p.secondary)end
 appearance.finish=(self.state.petMaterials or {})[self.petId]or appearance.finish or MaterialCatalog.Default
 appearance.toyId=(self.state.petToys or {})[self.petId]or ToyCatalog.Default
 appearance.featureStages={};local features=(self.state.petFeatures or {})[self.petId]or FeatureCatalog.emptyRow()
 for _,id in ipairs(FeatureCatalog.Order)do appearance.featureStages[id]=(features[id]or {}).visible or 0 end
 if self.featurePreview and self.featurePreview.petId==self.petId then appearance.featureStages[self.featurePreview.id]=self.featurePreview.stage end
 return appearance
end
function View:activePet()return if self.machine then self.machine.petId elseif self.options.activePet then self.options.activePet()else self.state.companionId or self.petId end
function View:choosePet(id)
 if id~=self.petId then self.fruitEating:cancel();self.eatingProof:cancel();self.eatingReady=nil;self.featurePreview=nil end
 if self.intent.pending or self.machineSwitching or not self:owned(id)or not Hues.Supported[id]then return false end
 if not self:canCustomize()and not self:hasReceiptAssignment()then return false end
 if self.toyAssignment then
  local q=self.toyAssignment
  if not self:hasToyAssignment()or not self.toyIntent or not self.toyIntent:equip(id,q.toyId,q.resultId)then return false end
  self.petId=id;self.toyAssignment=nil;self.page="toyReceipt";self.tab="toys";self:refresh();return true
 end
 if self.featureAssignment then
  if not self:hasFeatureAssignment()then return false end
  self.petId=id;self.tab="features";self.featurePanel:refresh(self.state,id,"choices")
  if not self.featurePanel:requestUse(self.featureAssignment.featureId,self.featureAssignment.resultId)then self.tab="pet";self:refresh();return false end
  self:refresh();return true
 end
 if self.materialAssignment then
  local result=self.materialAssignment;local pending=self.state.pendingMaterialResult
  if not pending or pending.id~=result.resultId or pending.finishId~=result.finishId then self.materialAssignment=nil
  else
   if not self.materialIntent or not self.materialIntent:equip(id,result.finishId,result.resultId)then return false end
   self.petId=id;self.tab="materials";self.materialAssignment=nil
   if not self:canCustomize()then self.page="materialReceipt"end
   self:refresh();return true
  end
 end
 if self.assignment then
  self.petId=id;self.inspected=nil;self.useMessage=nil;self.selectTarget=false;self.tab="hue";self:refresh();return true
 end
 if id==self:activePet()then self.petId=id;self.tab="hue";self:refresh();return true end
 self.confirmation={equipPetId=id};self.selectTarget=false;self:refresh();return true
end
function View:syncActive()
 local q=self.confirmation
 if not self.machine and self.equipTargetId and self.equipTargetId==self:activePet()then
  if not q or q.equipPetId==self.equipTargetId then self.petId=self.equipTargetId;self.confirmation=nil end
  self.machineSwitching=nil;self.equipTargetId=nil;self.exitMessage=nil;self:refresh()
 end
end
function View:setMachineSession(session)
 local changed=not self.machine or not session or self.machine.claimId~=session.claimId
 local identityChanged=session and self.machine and self.machine.petId~=session.petId
 self.machine=session
 if changed then self.machineEpoch=(self.machineEpoch or 0)+1 end
 if session and changed then
  self.petId=session.petId;self.machineSwitching=nil;self.equipTargetId=nil;self.equipSaved=nil;self.confirmation=nil;self.selectTarget=false;self.exitPending=nil
  if self.shade.Visible then self:refresh()end
 elseif session and identityChanged then
  self.petId=session.petId;self:finishMachineEquip()
  if self.shade.Visible then self:refresh()end
 end
end
function View:machineBinding()
 local binding=table.clone(self.machine or {});binding.epoch=self.machineEpoch;return binding
end
function View:finishMachineEquip()
 if not self.machine or not self.equipSaved or self.machine.petId~=self.equipTargetId then return false end
 self.machineSwitching=nil;self.equipTargetId=nil;self.equipSaved=nil;self.confirmation=nil
 if self.closeAfterEquip then
  self.closeAfterEquip=nil;local epoch,claim,lifecycle=self.machineEpoch,self.machine.claimId,self.lifecycleEpoch
  task.defer(function()if self.shade.Visible and self.lifecycleEpoch==lifecycle and self.machineEpoch==epoch and self.machine and self.machine.claimId==claim then self:close("back")end end)
 end
 return true
end
function View:machineEquipFinished(status,binding)
 if binding and(not self.machine or binding.epoch~=self.machineEpoch or binding.claimId~=self.machine.claimId)then return false end
 if status=="Saved"then self.equipSaved=true;self:finishMachineEquip()
 else self.machineSwitching=nil;self.equipTargetId=nil;self.equipSaved=nil;self.closeAfterEquip=nil;self.exitMessage="Pet was not changed. Try Make active again."end
 if self.shade.Visible then self:refresh()end
 return true
end
function View:chooseChannel(channel)
 if not self:canCustomize()and not self:hasHueAssignment()then return false end
 if self.intent.pending or(channel~="main"and channel~="secondary")then return false end;self.scrollPositions[self.tab..":"..self.channel]=self.body.CanvasPosition;self.channel=channel;self.inspected=nil
 if self.assignment then
  local assignment=self.assignment;local reason=self:reason(assignment.itemId)
  if reason then self.useMessage=reason;self:refresh();return false end
  self.confirmation={itemId=assignment.itemId,petId=self.petId,channel=channel,pendingResultId=assignment.pendingResultId}
  self.assignment=nil;self.useMessage=nil;self.body.CanvasPosition=Vector2.zero;self.epoch+=1
 elseif self.confirmation then self.confirmation.channel=channel end
 self:refresh();if not self.confirmation then self.body.CanvasPosition=self.scrollPositions[self.tab..":"..self.channel]or Vector2.zero end;return true
end
function View:setTab(tab)
 if not self:canCustomize()and not(self:hasHueAssignment()and(tab=="pet"or tab=="hue"))and not((self:hasMaterialAssignment()or self:hasToyAssignment()or self:hasFeatureAssignment())and tab=="pet")then return false end
 if tab=="features"and not FeatureFlags.Features then return false end
 if self.intent.pending or self.confirmation or(self.assignment and tab~="pet"and tab~="hue")or(tab~="pet"and tab~="hue"and tab~="charm"and tab~="materials"and tab~="toys"and tab~="features")then return false end
 self.scrollPositions[self.tab..":"..self.channel]=self.body.CanvasPosition
 if tab~="pet"then self.materialAssignment=nil;self.toyAssignment=nil;self.featureAssignment=nil end
 self.featurePreview=nil;self.fruitEating:cancel();self.eatingProof:cancel()
 if self.chromeFocus and tab~=self.tab then self.chromeFocus[tab]=nil end;self.charmMessage=if tab=="charm"then self.charmMessage else nil
 self.tab=tab;self.inspected=nil;self.useMessage=nil;self.selectTarget=self.assignment~=nil and tab=="pet";self:refresh()
 self.body.CanvasPosition=if tab=="pet"then Vector2.zero else self.scrollPositions[self.tab..":"..self.channel]or Vector2.zero;return true
end
function View:inspectHue(id,stage)
 if not self.shade.Visible or self.page~="palette"or self.tab~="hue"or self.confirmation or self.intent.pending then return false end
 local color=Swatches.at(self.petId,self:appearance(),self.channel,id,stage);if not color then return false end
 self.inspected={id=id,stage=stage,petId=self.petId,channel=self.channel}
 self:paintSwatches(true);self:layout();return true
end
function View:chooseNotch(id,stage)
 if not self.shade.Visible or self.page~="palette"or self.tab~="hue"or self.confirmation
  or not self.bars[id]or type(stage)~="number"or stage%1~=0 or stage<0 or stage>5 then return false end
 -- A displayed notch is a color reference. Every notch uses one fruit on top
 -- of the current committed count; zero is never a reset command.
 return self:chooseItem(id)
end
function View:compactSwatches()
 local size=self.shade.AbsoluteSize;local pad=if size.Y<280 then 8 else 16
 return self.page=="palette"and self.tab=="hue"and not self.confirmation and not self.assignment and size.Y<420 and math.min(640,size.X-16)-pad*2>=560
end
function View:paintSwatches(visible)
 local counts=self:counts();local appearance=self:appearance()
 local compact=self:compactSwatches();local detail="Choose a color to use one fruit."
 self.inspection.Visible=visible
 self.inspection.Text=detail
 for id,bar in pairs(self.bars)do
  local reason=self:reason(id)
  bar.row.Visible=visible;bar.savedCopy=reason or tostring(counts[id]).."/5";bar.value.Text=bar.savedCopy
  local stock=(self.state.hueInventory or {})[id]or 0;local stockCopy=tostring(stock)..(if stock==1 then " jar"else " jars");bar.stockCopy=reason or stockCopy
  bar.row:SetAttribute("AccessibleLabel",names[id].." · "..stockCopy.." · Current "..counts[id].."/5"..(if reason then " · "..reason else ""))
  for _,tick in ipairs(bar.ticks)do local stage=tick:GetAttribute("DoseStage")
   local color=if stage==0 then Color3.new(1,1,1)else Swatches.at(self.petId,appearance,self.channel,id,stage)
   local inspected=self.inspected and self.inspected.petId==self.petId and self.inspected.channel==self.channel and self.inspected.id==id and self.inspected.stage==stage
   tick:SetAttribute("SwatchColor",color);tick.BackgroundColor3=color;tick.BackgroundTransparency=0;tick:SetAttribute("Filled",stage<=counts[id]);tick:SetAttribute("SavedStage",stage==counts[id]);tick:SetAttribute("Inspected",inspected==true)
   tick:SetAttribute("AccessibleLabel",names[id].." "..stage..(if stage==counts[id]then " · Current"else "")..(if reason then " · "..reason else " · Use one: "..counts[id].." to "..math.min(5,counts[id]+1)))
   tick.Interactable=not self.intent.pending and reason==nil
   -- Clear keyline on Citrus and Ink; saved stage and inspection are independent.
   local stroke=tick:FindFirstChildWhichIsA("UIStroke")
   if stroke then stroke.Color=if stage==counts[id]then Art.Ink else Color3.fromHex("#647F87");stroke.Thickness=if stage==counts[id]then 3 else 1;stroke.Transparency=0 end
   tick.TextColor3=swatchInk(color)
   tick:SetAttribute("SwatchInk",tick.TextColor3)
   tick.Text=tostring(stage)
   for _,part in ipairs(tick.SavedCheck:GetChildren())do part.Visible=stage==counts[id];part.BackgroundColor3=tick.TextColor3 end
   if inspected then
    detail=(if stage==counts[id]then "Saved"else "Preview · Unapplied").." · "..names[id].." stage "..stage
     ..(if((self.state.hueInventory or {})[id]or 0)==0 then " · 0 in inventory"else " · Inspect only")
    self.inspection.Text=if compact then (if stage==counts[id]then "Saved "elseif self.machine then ""else "Preview ")..Hues.ById[id].name.." "..stage else detail
   end
  end
 end
 self.inspection:SetAttribute("AccessibleLabel",detail)
end
local function layoutBar(bar,x,y,width,compactSpacing)
 bar.value.Text=if compactSpacing then bar.stockCopy else bar.savedCopy
 Art.type(bar.label,"Action");Art.type(bar.value,"Counter")
 local valueW=math.max(54,Art.textWidth(bar.value)+4)
 local stacked=valueW>width*.52
 local labelW=if stacked then math.max(1,width-16)else math.max(1,width-valueW-24)
 local labelH=Art.textHeight(bar.label,labelW,22)
 if stacked then valueW=math.max(1,width-16)end
 local valueH=Art.textHeight(bar.value,valueW,22)
 local header=if stacked then labelH+valueH+4 else math.max(labelH,valueH)
 local columns=math.clamp(math.floor((width-12)/48),1,6)
 local cell=(width-16-(columns-1)*4)/columns;local rows=math.ceil(#bar.ticks/columns)
 local gap=if compactSpacing then 4 else 8
 local height=header+rows*44+(rows-1)*4+(if compactSpacing then 12 else 16)
 place(bar.row,x,y,width,height);place(bar.label,8,3,labelW,labelH);place(bar.value,width-valueW-8,if stacked then labelH+7 else 3,valueW,valueH)
 for i,tick in ipairs(bar.ticks)do Art.type(tick,"Counter");place(tick,8+((i-1)%columns)*(cell+4),header+gap+math.floor((i-1)/columns)*48,cell,44)end
 return height
end
function View:reason(id)
 local count=(self.state.hueInventory or {})[id]or 0
 if not self:owned(self.petId)then return "Choose an owned pet"end
 local c=self:counts()
 if id~="reset"and c[id]>=5 then return Hues.ById[id].name.." is maxed"end
 if count<1 then return if id=="reset"then "No Reset Hue"else "No "..names[id]end
 if id=="reset"then return if nonzero(c)then nil else "Original"end
 return if c[id]>=5 then "Max"else nil
end
function View:chooseItem(id)
 if not self:canCustomize()then return false end
 if self.intent.pending or self:reason(id)then return false end
 local r=self.state.pendingHueResult
 if r then self.page="receipt";self.confirmation=nil;self:refresh();return false end
 self.confirmReturn={scroll=self.body.CanvasPosition,target=self.jars[id].button};self.confirmation={itemId=id,petId=self.petId,channel=self.channel};self.body.CanvasPosition=Vector2.zero;self.epoch+=1;self:refresh();return true
end
function View:useResult()
 if self.itemReveal:consumeSkipInput()or self.itemReveal:skip()then return false end
 self.itemReveal:clear()
 local r=self.state.pendingHueResult;if not r or self.intent.pending then return false end
 self.page="palette";self.tab="pet";self.selectTarget=true;self.body.CanvasPosition=Vector2.zero;self.epoch+=1
 self.assignment={itemId=r.itemId,pendingResultId=r.id};self.confirmation=nil;self:refresh()
 self:openPetsSelector(names[r.itemId]);return true
end
function View:requestLegacy(id)
 if not self:canCustomize()then return false end
 if self.intent.pending then return false end
 self.confirmation={legacyItem=id};self:refresh();return true
end
function View:cancelConfirmation()
 if self.intent.pending then return false end
 local decision=self.confirmation;local pendingResult=decision and decision.pendingResultId
 self.confirmation=nil;self.selectTarget=false
 if pendingResult then self.page="palette";self.tab="hue";self.assignment={itemId=decision.itemId,pendingResultId=pendingResult};self.resultDraft=nil end
 self:refresh();if self.confirmReturn then self.body.CanvasPosition=self.confirmReturn.scroll;GuiService.SelectedObject=self.confirmReturn.target;self.confirmReturn=nil end;self.epoch+=1;return true
end
function View:shapeSelectionsEnabled()
 local remotes=game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
 return if self.options.shapeSelectionsEnabled then self.options.shapeSelectionsEnabled()==true else CharmCatalog.SelectionsEnabled==true and remotes~=nil and(remotes:GetAttribute("PetCharmVersion")or 0)>=CharmCatalog.Version
end
function View:requestCharm(visible,shape)
 if not self:canCustomize()then return false end
 local id=self.petId;local pending=self.charmRequests[id]
 if pending then
  if not pending.retry or not self.options.charm then return false end
  pending.retry=false;self.options.charm(id,pending.visible,pending.shape,pending.seq,pending.shapeVersion)
 else
  if not self.options.charm then return false end
  local shapeVersion=if shape~=nil then CharmCatalog.Version else nil
  local operation=self.options.charm(id,visible,shape,nil,shapeVersion)
  if type(operation)~="table"or type(operation.seq)~="number"then return false end
  pending={petId=id,visible=visible,shape=shape,shapeVersion=shapeVersion,expectedShape=shape or self:appearance().charmShape or "dot",seq=operation.seq};self.charmRequests[id]=pending
 end
 self:queueCharmTimeout(pending)
 self:refresh();return true
end
function View:queueCharmTimeout(pending)
 pending.waitEpoch=(pending.waitEpoch or 0)+1;local epoch=pending.waitEpoch
 local delay=self.options.delay or task.delay;delay(8,function()
  if self.destroyed or self.charmRequests[pending.petId]~=pending or pending.waitEpoch~=epoch then return end
  pending.retry=true;self:refresh()
 end)
end
function View:toggleCharm()
 if self.intent.pending then return false end
 return self:requestCharm(self:appearance().charmVisible==false)
end
function View:selectCharm(shape)
 if self.intent.pending or not self:shapeSelectionsEnabled()or not CharmCatalog.known(shape)then return false end
 return self:requestCharm(self:appearance().charmVisible~=false,shape)
end
function View:selectDot()return self:selectCharm("dot")end
function View:charmResult(packet)
 if type(packet)~="table"then return false end
 local pending=self.charmRequests[packet.petId]
 if not pending or packet.seq~=pending.seq then return false end
 if packet.status=="Saved"then
  if packet.visible~=pending.visible or(packet.shape~=nil and packet.shape~=pending.expectedShape)then return false end
  self.charmRequests[packet.petId]=nil;self.charmMessage=nil
 elseif packet.status=="Rejected"then
  self.charmRequests[packet.petId]=nil;self.charmMessage="Charm was not saved. Try again."
 elseif packet.status=="Applied"then self:queueCharmTimeout(pending)
 else return false end
 if self.petId==packet.petId then self:refresh()end;return true
end
function View:activate()
 if not self.shade.Visible or not self.action.Visible or not self.action.Interactable or GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox()then return false end
 for _,reveal in ipairs({self.itemReveal,self.materialPanel.reveal,self.toyPanel.reveal,self.featurePanel.reveal})do if reveal:consumeSkipInput()or reveal:skip()then return false end end
 if self.page=="toyReceipt"then local r=self.state.pendingToyResult;return self.toyIntent and r and(if self.toyIntent.status=="Retrying"then self.toyIntent:retry()else self.toyIntent:ack(r.id))or false end
 if self.page=="toyBuy"then return self.toyIntent and(if self.toyIntent.status=="Retrying"then self.toyIntent:retry()else self.toyIntent:buy())or false end
 if self.page=="featureReceipt"then local r=self.state.pendingFeatureResult;return self.featureIntent and r and(if self.featureIntent.status=="Retrying"then self.featureIntent:retry()else self.featureIntent:ack(r.id))or false end
 if self.page=="featureBuy"then return self.featureIntent and(if self.featureIntent.status=="Retrying"then self.featureIntent:retry()else self.featureIntent:buy())or false end
 if not self.shade.Visible or not self.action.Visible or not self.action.Interactable then return false end
 self.itemReveal:cancel()
 if self.materialIntent and self.materialIntent.pending and self.materialIntent.status=="Retrying"and(self.page=="materialReceipt"or self.page=="materialBuy"or self.tab=="materials")then return self.materialIntent:retry()end
 if self.page=="materialReceipt"then
  local result=self.state.pendingMaterialResult
  return self.materialIntent and result and self.materialIntent:ack(result.id)or false
 elseif self.page=="materialBuy"then return self.materialIntent and(if self.materialIntent.status=="Retrying"then self.materialIntent:retry()else self.materialIntent:buy())or false
 elseif self.tab=="materials"and self.materialIntent and self.materialIntent.status=="Retrying"then return self.materialIntent:retry()end
 if self.intent.status=="Retrying"then return self.intent:retry()end
 local q=self.confirmation
 if q and not self:canCustomize()and not self:hasHueAssignment()then return false end
 if self.page=="migration"then
  local ok=self.intent:ackMigration();if ok then self.migrationOperation=self.intent.pending.value.id end;return ok
 elseif self.assignment and not q then
  local ok=self.intent:store(self.assignment.pendingResultId);if ok then self.storeOperation=self.intent.pending.value.id end;return ok
 elseif q then
  if q.equipPetId then
   if self.machineSwitching or not self.options.equipPet then return false end
   self.equipTargetId=q.equipPetId;self.equipSaved=nil
   self.machineSwitching=true
   local started=self.options.equipPet(q.equipPetId)==true
   if not started then self.machineSwitching=nil;self.equipTargetId=nil end
   self:refresh();return started
  end
  local ok
  if q.legacyItem then ok=self.intent:legacyRedeem(q.legacyItem)
  elseif q.presetId then ok=self.intent:legacyPreset(self.petId,self.channel,q.presetId)
  else self.eatArmed=q.itemId~="reset";ok=self.intent:use(self.petId,self.channel,q.itemId,q.pendingResultId);self.eatArmed=nil end
  if ok then self.submitted=if self.intent.pending then self.intent.pending.value.id else self.submitted end;return ok
 elseif self.page=="receipt"then
  local r=self.state.pendingHueResult;if not r then return false end
  local ok=self.intent:store(r.id);if ok then self.storeOperation=self.intent.pending.value.id end;return ok
 elseif self.page=="buy"then
  self:close("shop");if self.options.shop then self.options.shop()end;return true
 end
 return false
end
function View:fitPortrait()
 if not self.visual then return end
 local key=tostring(self.viewport.AbsoluteSize)..":"..tostring(self.visual.rigRevision or 0)..":"..tostring(self.visual.featureRevision or 0)..":"..tostring(self.visual.charmVisible)..":"..tostring(self.visual.renderCharmShape)..":"..tostring(self.visual)
 if self.portraitCameraKey==key then return end;self.portraitCameraKey=key
 local box,size=Bounds.get(self.visual);local a=math.max(.1,self.viewport.AbsoluteSize.X/math.max(1,self.viewport.AbsoluteSize.Y));local half=math.tan(math.rad(self.camera.FieldOfView/2))
 local distance=math.max(size.Y*.5/half,size.X*.5/(half*a))+size.Z*.5+.3
 local center=box.Position;self.camera.CFrame=CFrame.lookAt(center+Vector3.new(0,.12,distance*1.10),center)
end
function View:paintPortrait()
 if not self.portrait.Visible then return end
 local a=self:appearance();local key=self.petId
 -- Focusing a Charm card previews it at once (None hides the charm); nothing is saved.
 if self:chromeActive()and self.tab=="charm"and self.charmFocusId then
  if self.charmFocusId=="none"then a.charmVisible=false else a.charmVisible=true;a.charmShape=self.charmFocusId end
 end
 if not self.visual or self.visualId~=key then
  if self.visual then self.visual:destroy()end
  self.visual=Factory.new(self.world,Vector3.zero,Pets.byId[self.petId],nil,a);self.visualId=key
  local visual=self.visual
  visual.onRigChanged=function()if not self.destroyed and self.visual==visual then self:fitPortrait()end end
 end
 self.visual.reducedEffects=GuiService.ReducedMotionEnabled or(self.options.reduceEffects and self.options.reduceEffects()==true)or false
 if self.visual.applyAppearance then self.visual:applyAppearance(a)end;self.visual:update(0);self:fitPortrait();self:syncPortraitClock()
end
function View:stopPortraitClock()
 if self.portraitClock then self.portraitClock:Disconnect();self.portraitClock=nil end
end
function View:syncPortraitClock()
 local wanted=not self.destroyed and self.shade.Visible and not self.confirmation and((self.portrait.Visible and self.visual~=nil)or self.tab=="pet")
 if not wanted then self:stopPortraitClock();return end
 if self.portraitClock then return end
 self.portraitClock=game:GetService("RunService").RenderStepped:Connect(function(dt)
  if self.destroyed or not self.shade.Visible or self.confirmation or(not self.portrait.Visible and self.tab~="pet")then self:stopPortraitClock();return end
  if GuiService.MenuIsOpen or(self.options.audio and self.options.audio.deviceActive==false)then return end
  self:updateGrid(math.min(dt,.1))
  local visual=self.visual;if not self.portrait.Visible or not visual or visual.destroyed then return end
  local reduced=GuiService.ReducedMotionEnabled or(self.options.reduceEffects and self.options.reduceEffects()==true)or false
  if visual.reducedEffects~=reduced then visual.reducedEffects=reduced;visual.poseDirty=true;visual:update(0)end
  if not reduced then visual.cosmeticTime=os.clock();visual:update(math.min(dt,.1))end
  if self.fruitEating.active then
   if self.fruitEating.token.binding~=self:eatingBinding()then self.fruitEating:cancel();if self.boundedEating then self:close("receipt-finished");return end end
   if self.fruitEating.active and not self.fruitEating:step(math.min(dt,.1))and self.boundedEating then self:close("receipt-finished");return end
  end
 end)
end
function View:refresh()
 self.state=self.intent.state or self.state
 if self.shade.Visible and self.eatArmed and self.intent.pending then self.submitted=self.intent.pending.value.id;self.eatingProof:capture(self.intent.pending,self.state,self:eatingBinding())end
 if self.shade.Visible then
  local receipt=self.intent.receipt or self.state.lastHueResult
  local token=self.eatingProof:take(receipt,self.state,self:eatingBinding())
  if token then self.eatingReady=token;self.boundedEating=not self:canCustomize()end
 end
 if self.intent.status=="Rejected"then self.eatingProof:cancel()end
 for _,entry in ipairs({{self.toyIntent,"toy"},{self.featureIntent,"feature"}})do local intent,kind=entry[1],entry[2]
  if self.shade.Visible and intent and intent.pending and intent.pending.action==kind.."Buy"then self[kind.."PurchaseInFlight"]=intent.pending.value.id end
 end
 if self.shade.Visible and self.materialIntent and self.materialIntent.pending and self.materialIntent.pending.action=="materialBuy"then self.materialPurchaseInFlight=self.materialIntent.pending.value.id end
 if self.shade.Visible and self.intent.pending and self.intent.pending.action=="hueBuy"then self.purchaseInFlight=self.intent.pending.value.id end
 for id,request in pairs(self.charmRequests)do
  if request.retry and self.options.appearance then
   local saved=self.options.appearance(id)
   if saved and saved.charmVisible==request.visible and(saved.charmShape==nil or saved.charmShape==request.expectedShape)then self.charmRequests[id]=nil end
  end
 end
 local receipt=self.intent.receipt
 if not self.intent.pending and receipt then
  if self.submitted==receipt.id then
   self.confirmation=nil;self.selectTarget=false;self.submitted=nil;self.resultDraft=nil
   if receipt.action=="hueLegacyRedeem"then self.page="receipt"end
  end
  if self.migrationOperation==receipt.id then self.migrationOperation=nil;self.page=if self.state.pendingHueResult then "receipt"else self.afterMigrationPage or "palette"end
  if self.storeOperation==receipt.id then self.storeOperation=nil;self:close("stored");return end
 end
 if not self.shade.Visible then return end
 local r=self.state.pendingHueResult
 local materialResult=self.state.pendingMaterialResult;local toyResult=self.state.pendingToyResult;local featureResult=self.state.pendingFeatureResult
 if self.toyAssignment and not self:hasToyAssignment()then self.toyAssignment=nil end
 if self.featureAssignment and not self:hasFeatureAssignment()then self.featureAssignment=nil end
 for _,entry in ipairs({{"toy",toyResult,"toys"},{"feature",featureResult,"features"}})do
  if entry[2]and self.page==entry[1].."Buy"then self.page=entry[1].."Receipt"end
  if self.page==entry[1].."Receipt"and not entry[2]then self.page="palette";self.tab=entry[3]end
 end
 if self.materialAssignment and(not materialResult or materialResult.id~=self.materialAssignment.resultId or materialResult.finishId~=self.materialAssignment.finishId)then self.materialAssignment=nil end
 if materialResult and self.page=="materialBuy"then self.page="materialReceipt"end
 if self.page=="materialReceipt"and not materialResult then self.page="palette";self.tab="materials"end
 if r and self.page=="buy"then self.page="receipt"end
 if self.page=="receipt"and not r then self.page="palette"end
 if self.page=="palette"and not self:canCustomize()and not self:hasReceiptAssignment()and not self.boundedEating then
  self:close("receipt-finished");return
 end
 local owned=self:owned(self.petId);if not owned then for _,p in ipairs(Pets.collection)do if self:owned(p.id)then self.petId=p.id;owned=true;break end end end
 local migration=self.page=="migration";local customization=self.page=="palette";local hue=customization and self.tab=="hue";local charm=customization and self.tab=="charm";local confirming=self.confirmation~=nil
 self.migrationText.Visible=migration
 if migration then
  local lines={"Your previous colors are safe. Your saved Stars, pets and purchases are unchanged."}
  for _,pet in ipairs(Pets.collection)do local row=self.state.petHues and self.state.petHues[pet.id];local presets=self.state.legacyHuePresets and self.state.legacyHuePresets[pet.id]
   if row and presets and(#(presets.main or {})>0 or #(presets.secondary or {})>0)then
    table.insert(lines,pet.name..": Main Rose "..row.main.rose.."/5 · Tide "..row.main.tide.."/5 · Citrus "..row.main.citrus.."/5 · Iris "..row.main.iris.."/5")
    table.insert(lines,"Previously earned choices: "..#(presets.main or {}).." Main · "..#(presets.secondary or {}).." Secondary. The first new fruit locks exchanges on that channel until a Reset Hue.")
   end
  end
  if self.state.legacyHueEgg then table.insert(lines,"Your carried Hue Egg still lets you choose one fixed fruit, with no charge.")end
  self.migrationText.Text=table.concat(lines,"\n\n")
 end
 self.title.Text=if migration then "Your converted colors"elseif self.assignment then "Choose where to use"elseif confirming then if self.confirmation.itemId=="reset"then "Reset "..channelName(self.channel).." color?"elseif self.confirmation.itemId then "Use one "..names[self.confirmation.itemId].."?"else "Confirm choice"elseif self.page=="receipt"then "A jar for your garden"elseif self.page=="buy"then "Hue Egg"else "Companions"
 if self.page=="receipt"and r then self.title.Text=names[r.itemId]
 elseif self.page=="materialReceipt"and materialResult then self.title.Text=MaterialCatalog.ById[materialResult.finishId].name.." unlocked!"
 elseif self.page=="toyBuy"then self.title.Text="Toy Egg"elseif self.page=="featureBuy"then self.title.Text="Feature Egg"
 elseif self.page=="toyReceipt"and toyResult then self.title.Text=ToyCatalog.ById[toyResult.toyId].name.." unlocked!"
 elseif self.page=="featureReceipt"and featureResult then self.title.Text=FeatureCatalog.ById[featureResult.featureId].name.." found!"end
 self.title:SetAttribute("AccessibleLabel",if customization then "Customize "..Pets.byId[self.petId].name else self.title.Text)
 if self.confirmation and self.confirmation.equipPetId then self.title.Text="Make "..Pets.byId[self.confirmation.equipPetId].name.." active?"end
 self.wallet.Text=tostring(self.state.nectar or 0).." Stars"
 local function visible(n,value)n.Visible=value end
 for _,n in ipairs({self.portrait,self.petName})do visible(n,customization and self.tab~="pet"and not confirming)end
 for _,n in ipairs({self.mainTab,self.secondaryTab,self.channelTitle,self.inventoryTitle})do visible(n,hue and not confirming)end
 if self.assignment then self.inventoryTitle.Visible=false end
 self.mainTab.Visible=hue and not confirming;self.secondaryTab.Visible=hue and not confirming;self.targetChange.Visible=false;self.targetTitle.Visible=customization and not confirming and(self.tab=="pet"or self.selectTarget==true)
 self.machinePickup.Visible=false;self.machineSetDown.Visible=false;self.wallet.Visible=false
 for id,n in pairs(self.targets)do n.Visible=customization and not confirming and (self.tab=="pet"or self.selectTarget==true)and self:owned(id);n.Interactable=not self.intent.pending;Art.tab(n,id==self:activePet(),n.Interactable)
  local preview=self.gridPreviews[id];preview.active.Text=if id==self:activePet()then "✓ Active"elseif self.assignment and id==self.petId then "✓ Recipient"else "";n:SetAttribute("AccessibleLabel",Pets.byId[id].name.." · "..(if id==self:activePet()then "Active"elseif self.assignment then "Choose jar recipient"else "Make active"))end
 Art.tab(self.mainTab,self.channel=="main",not self.intent.pending);Art.tab(self.secondaryTab,self.channel=="secondary",not self.intent.pending)
 self.targetChange.Text=Pets.byId[self.petId].name.." · Change pet";self.petName.Text=Pets.byId[self.petId].name;self.channelTitle.Text=channelName(self.channel)
 local counts=self:counts();local stock=0
 self:paintSwatches(hue and not confirming and not self.assignment)
 for _,id in ipairs(ids)do local j=self.jars[id];local quantity=(self.state.hueInventory or {})[id]or 0;stock+=quantity
  j.button.Visible=hue and not confirming and not self.assignment and quantity>0;j.quantity.Text="×"..quantity;j.reason.Text=self:reason(id)or "Use";j.button.Interactable=not self.intent.pending and self:reason(id)==nil and not confirming
  j.button:SetAttribute("DisabledReason",self:reason(id));Art.control(j.button,false,j.button.Interactable)
 end
 self.empty.Visible=hue and not confirming and not self.assignment and stock==0
 self.charmTitle.Visible=charm and not confirming
 local a=self:appearance();local charmPending=self.charmRequests[self.petId]
 local known=CharmCatalog.known(a.charmShape or "dot");local enabled=self:shapeSelectionsEnabled()
 self.charmTitle.Text=if known then "A floating "..CharmCatalog.ById[a.charmShape or "dot"].name..", colored by Secondary."else "Your saved charm shows as a Snowflake here. Its original shape is preserved."
 for id,node in pairs(self.shapes)do
  node.Visible=charm and not confirming and(enabled or id==CharmCatalog.renderShape(a.charmShape));node.Interactable=enabled and not charmPending
  local icon=self.shapeIcons[id];local tint=Palette.resolve(self.petId,a).secondary;icon.form.BackgroundColor3=tint;local edge=icon.form:FindFirstChild("RingEdge");if edge then edge.Color=tint end
  local tileColor=if tint.R*.2126+tint.G*.7152+tint.B*.0722>.5 then Color3.fromHex("#173D36")else Color3.fromHex("#F8F2DF")
  Art.bind(icon.tile,{BackgroundColor3=function()return tileColor end})
  local selected=known and id==(a.charmShape or "dot");node.Text="";icon.label.Text=CharmCatalog.ById[id].name;icon.check.Visible=selected;Art.control(node,selected,node.Interactable)
  node:SetAttribute("AccessibleLabel",CharmCatalog.ById[id].name.." charm · Secondary tint"..(if selected then " · Selected"else ""))
 end
 self.receipt.Visible=self.page=="receipt";self.receiptArt.Visible=self.receipt.Visible;self.receiptDetail.Visible=self.receipt.Visible;self.useNow.Visible=self.receipt.Visible
 if r and self.receipt.Visible then
  self.receipt.Text=tostring((self.state.hueInventory or {})[r.itemId]or r.inventoryAfter or 1).." in inventory · choose a pet and channel"..(if r.itemId=="reset"then " to reset."else ".")
  self.itemReveal:show(r,self.purchaseInFlight==r.id);self.purchaseInFlight=nil
 end
 self.legacyTitle.Visible=self:canCustomize()and self.state.legacyHueEgg~=nil and not confirming and self.tab=="hue"
 for _,n in pairs(self.legacyButtons)do n.Visible=self.legacyTitle.Visible;n.Interactable=not self.intent.pending end
 self.quote.Visible=confirming or self.assignment~=nil or self.page=="buy";self.resultSwatch.Visible=confirming and not(self.confirmation.legacyItem or self.confirmation.presetId or self.confirmation.equipPetId)
 local q=self.confirmation
 if q then
  if q.equipPetId then self.quote.Text="Make "..Pets.byId[q.equipPetId].name.." your active pet?\n"..Pets.byId[self.petId].name.." returns to your collection after the save.\nNo Stars or jars are used."
  elseif q.legacyItem then self.quote.Text="Exchange your carried Hue Egg for one "..names[q.legacyItem].."? This choice is saved once."
  elseif q.presetId then self.quote.Text="Restore "..q.name.." on "..Pets.byId[self.petId].name.."'s "..channelName(self.channel).."? This uses your previous-color exchange, with no jar cost."
  else
   local nextCounts=countsCopy(counts);local item=q.itemId;local quantity=(self.state.hueInventory or {})[item]or 0
   if item=="reset"then
    nextCounts=Hues.emptyCounts();local erased={};for _,hue in ipairs(Hues.Order)do if counts[hue.id]>0 then table.insert(erased,hue.name.." "..counts[hue.id].."/5")end end
    self.quote.Text=Pets.byId[self.petId].name.." · "..channelName(self.channel).."\nReset "..channelName(self.channel).." color?\nErase "..table.concat(erased," and ").."\n1 of "..quantity.." jars · stock "..quantity.." → "..math.max(0,quantity-1)
   else
    nextCounts[item]=math.min(5,nextCounts[item]+1);self.quote.Text=Pets.byId[self.petId].name.." · "..channelName(self.channel).."\nUse "..names[item].."?\n"..Hues.ById[item].direction.." "..counts[item].."/5 → "..nextCounts[item].."/5\n1 of "..quantity.." jars · stock "..quantity.." → "..math.max(0,quantity-1)
   end
   local proposed=table.clone(a);proposed[if self.channel=="main"then "mainDoses"else "secondaryDoses"]=nextCounts
   local resolved=Palette.resolve(self.petId,proposed);self.resultSwatch.BackgroundColor3=resolved[if self.channel=="main"then "body"else "secondary"]
   local prior=self.state.legacyHuePresets and self.state.legacyHuePresets[self.petId]
   local row=self.state.petHues and self.state.petHues[self.petId]
   if item~="reset"and prior and #(prior[self.channel]or {})>0 and not(row and row.legacyLocked and row.legacyLocked[self.channel])then
    self.quote.Text..="\nThis first new fruit locks previously earned exchanges on this channel until Reset Hue."
   end
  end
 elseif self.assignment then self.quote.Text=if self.tab=="pet"then "Choose a pet."else "Choose Main or Secondary."
 elseif self.page=="buy"then self.quote.Text="8 Stars · one saved jar\nRose fruit 20% · Tide fruit 20% · Citrus fruit 20% · Iris fruit 20% · Reset Hue 20%\nReset clears one channel. Store any result. Duplicate jars stack."end
 local decision=confirming and q.itemId~=nil
 for _,node in ipairs({self.confirmTarget,self.confirmDelta,self.confirmStock,self.confirmWarning})do node.Visible=decision end
 if decision then
  local lines=string.split(self.quote.Text,"\n")
  self.confirmTarget.Text=lines[1];self.confirmTarget:SetAttribute("AccessibleLabel",self.quote.Text)
 self.confirmDelta.Text=if q.itemId=="reset"then "Restore "..(if self.channel=="main"then "white Main"else "grey Secondary")else Hues.ById[q.itemId].name.." "..counts[q.itemId].." → "..math.min(5,counts[q.itemId]+1)
 local stock=(self.state.hueInventory or {})[q.itemId]or 0
 self.confirmStock.Text=tostring(stock)..(if stock==1 then " jar"else " jars").." → "..math.max(0,stock-1)
  self.confirmWarning.Text=if q.itemId=="reset"then lines[3]or ""else lines[5]or ""
  self.confirmWarning.Visible=self.confirmWarning.Text~="";self.quote.Visible=false
 end
 self.presetTitle.Visible=false
 for _,n in pairs(self.presetButtons)do n.Visible=false end
 local presets=self.state.legacyHuePresets and self.state.legacyHuePresets[self.petId];local p=self.state.petHues and self.state.petHues[self.petId]
 if self:canCustomize()and hue and not confirming and presets and not(p and p.legacyLocked and p.legacyLocked[self.channel])then
  for _,preset in ipairs(presets[self.channel]or {})do
   self.presetTitle.Visible=true;local id=preset.id;local n=self.presetButtons[id]
   if not n then n=button(self.body,"Preset_"..id,preset.name,function()self.confirmation={presetId=id,name=preset.name};self:refresh()end);self.presetButtons[id]=n end
   n.Visible=true;n.Interactable=not self.intent.pending
  end
 end
 self.status.Text=if self.exitMessage then self.exitMessage elseif self.useMessage then self.useMessage elseif self.saveNotice then self.saveNotice.detail elseif self.charmMessage and charm then self.charmMessage elseif self.intent.pending and self.intent.status~="Retrying"then ""elseif self.intent.status=="Saved"then ""else self.intent.message or "";self.status.Visible=self.status.Text~=""
 self.action.Visible=migration or self.assignment~=nil or confirming or self.page=="receipt"or self.page=="buy"or self.intent.status=="Retrying"
 self.cancel.Visible=confirming
 self.action.Text=if migration then "Continue"elseif self.intent.status=="Retrying"then "Try again"elseif confirming then if q.itemId=="reset"then "Reset "..channelName(self.channel)elseif q.itemId then "Use one"else "Confirm"elseif self.assignment then "Store"elseif self.page=="receipt"then "Store"elseif self.page=="buy"then "Back to Hue Egg"else ""
 local reason=q and q.itemId and self:reason(q.itemId)
 self.action.Interactable=self.action.Visible and(if self.intent.status=="Retrying"then true else not self.intent.pending and not reason and self.intent:ready(if confirming and not q.legacyItem then self.petId else nil))
 self.cancel.Interactable=not self.intent.pending;self.useNow.Interactable=not self.intent.pending
 if self.confirmation and self.confirmation.equipPetId then self.action.Text=if self.machineSwitching then "Saving…"else "Make active";self.action.Interactable=not self.machineSwitching end
 Art.control(self.action,true,self.action.Interactable);Art.control(self.cancel,false,self.cancel.Interactable)
 self.targetTitle.Text=if self.assignment then "Choose the recipient for "..names[self.assignment.itemId]else "Your companions"
 local hasOwned=false;for id in pairs(self.targets)do if self:owned(id)then hasOwned=true;break end end
 self.targetTitle.Visible=customization and not confirming and self.tab=="pet"and(self.assignment~=nil or not hasOwned)
 if self.toyAssignment then self.targetTitle.Visible=customization and self.tab=="pet";self.targetTitle.Text="Choose a pet for "..ToyCatalog.ById[self.toyAssignment.toyId].name end
 if self.featureAssignment then self.targetTitle.Visible=customization and self.tab=="pet";self.targetTitle.Text="Choose a pet for "..FeatureCatalog.ById[self.featureAssignment.featureId].name end
 if self.materialAssignment then self.targetTitle.Visible=customization and self.tab=="pet";self.targetTitle.Text="Choose a pet for "..MaterialCatalog.ById[self.materialAssignment.finishId].name end
 self.eggsButton.Visible=customization and self.tab=="pet"and not confirming and self:canCustomize()
 if not hasOwned and self.targetTitle.Visible then self.targetTitle.Text="No companion yet. Play your first rounds to meet your Bear."end
 local materialMode=if self.page=="materialReceipt"then "receipt"elseif self.page=="materialBuy"then "buy"elseif customization and self.tab=="materials"and not confirming then "choices"else nil
 self.materialPanel:refresh(self.state,self.petId,materialMode,materialResult and self.materialPurchaseInFlight==materialResult.id)
 if materialMode=="receipt"then self.materialPurchaseInFlight=nil end
 if materialMode then
  self.status.Visible=self.saveNotice~=nil
  self.action.Visible=materialMode=="receipt"or materialMode=="buy"or(self.materialIntent and self.materialIntent.status=="Retrying")or false
  self.action.Text=if self.materialIntent and self.materialIntent.status=="Retrying"then "Try again"elseif materialMode=="receipt"then "Keep"else "Hatch · 16 Stars"
  if materialMode=="buy"and not(self.materialIntent and self.materialIntent.status=="Retrying")then
   if #MaterialCatalog.remaining(self.state.materialUnlocks)==0 then self.action.Text="All materials owned"elseif not self.state.materialAvailable then self.action.Text="Materials not ready"end
  end
  self.action.Interactable=self.materialIntent~=nil and self.materialIntent:ready()and(materialMode~="buy"or(self.state.materialAvailable==true and #MaterialCatalog.remaining(self.state.materialUnlocks)>0 and(self.state.nectar or 0)>=MaterialCatalog.Cost))
  if self.materialIntent and self.materialIntent.status=="Retrying"then self.action.Interactable=true end
  Art.control(self.action,true,self.action.Interactable)
 end
 for _,entry in ipairs({{self.toyPanel,self.toyIntent,"toy",toyResult,ToyCatalog},{self.featurePanel,self.featureIntent,"feature",featureResult,FeatureCatalog}})do
  local panel,intent,kind,result,catalog=entry[1],entry[2],entry[3],entry[4],entry[5]
  local mode=if self.page==kind.."Receipt"then "receipt"elseif self.page==kind.."Buy"then "buy"elseif customization and self.tab==kind.."s"and not confirming then "choices"else nil
  -- Feature's plural is Features, Toy's is Toys.
  panel:refresh(self.state,self.petId,mode,result and self[kind.."PurchaseInFlight"]==result.id)
  if mode=="receipt"then self[kind.."PurchaseInFlight"]=nil end
  if mode then
   self.action.Visible=mode=="receipt"or mode=="buy"or(intent and intent.status=="Retrying")or false
   self.action.Text=if intent and intent.status=="Retrying"then "Try again"elseif mode=="receipt"then "Store"else "Hatch · "..catalog.Cost.." Stars"
   self.action.Interactable=intent~=nil and intent:ready()and(mode~="buy"or(self.state.nectar or 0)>=catalog.Cost)
   if mode=="buy"and kind=="toy"and #catalog.remaining(self.state.toyUnlocks)==0 then self.action.Text="All toys owned";self.action.Interactable=false end
   if mode=="buy"and kind=="feature"and catalog.full(self.state.featureStock or {})then self.action.Text="All stacks full";self.action.Interactable=false end
   if intent and intent.status=="Retrying"then self.action.Interactable=true end
   Art.control(self.action,true,self.action.Interactable)
  end
 end
 if self.boundedEating then
  for _,node in ipairs({self.inventoryTitle,self.empty,self.channelTitle,self.inspection,self.legacyTitle,self.presetTitle,self.status,self.quote})do node.Visible=false end
  for _,j in pairs(self.jars)do j.button.Visible=false end
  for _,b in pairs(self.bars)do b.row.Visible=false end
  self.mainTab.Visible=false;self.secondaryTab.Visible=false
 end
 self:layout();self:updateGrid(0);self:paintPortrait()
 if self.eatingReady and self.visual and self.portrait.Visible then
  self.fruitEating:start(self.visual,self.eatingReady,GuiService.ReducedMotionEnabled or(self.options.reduceEffects and self.options.reduceEffects()))
  self.eatingReady=nil
 end
 self:syncPortraitClock()
 if self.confirmation~=self.focusedConfirmation then
  self.focusedConfirmation=self.confirmation;self.epoch+=1
  if self.confirmation then
   local generation=self.epoch;local decision=self.confirmation
   if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.shade)then GuiService.SelectedObject=nil end
   if string.match(UserInputService:GetLastInputType().Name,"^Gamepad")then
    task.defer(function()game:GetService("RunService").Heartbeat:Wait()
     if not self.destroyed and self.shade.Visible and self.epoch==generation and self.confirmation==decision and not GuiService.MenuIsOpen then GuiService.SelectedObject=self.cancel end
    end)
   end
  end
 end
 self.shade:SetAttribute("ControllerEpoch",self.epoch)
end
-- One scheduler and at most seven live identities. Visibility gates both loading
-- and idle work; a new saved appearance destroys the old generation before bind.
function View:updateGrid(dt)
 local live=self.shade.Visible and self.page=="palette"and self.tab=="pet"and not self.confirmation
 if live and self.visual then self.visual:destroy();self.visual=nil;self.visualId=nil;self.portraitCameraKey=nil end
 local top,bottom=self.body.AbsolutePosition.Y,self.body.AbsolutePosition.Y+self.body.AbsoluteSize.Y
 for id,entry in pairs(self.gridPreviews)do
  local visible=live and entry.button.Visible and entry.button.AbsolutePosition.Y<bottom and entry.button.AbsolutePosition.Y+entry.button.AbsoluteSize.Y>top
  if not visible then
   if entry.visual then entry.visual:destroy();entry.visual=nil;entry.key=nil end
  else
   if dt==0 or not entry.visual then
    local appearance=table.clone(self.options.appearance and self.options.appearance(id)or {})
    local doses=self.state.petHues and self.state.petHues[id]
    if doses then appearance.mainDoses=countsCopy(doses.main);appearance.secondaryDoses=countsCopy(doses.secondary)end
    appearance.finish=(self.state.petMaterials or {})[id]or appearance.finish or MaterialCatalog.Default
    local key=id..":"..game:GetService("HttpService"):JSONEncode(appearance)
    if key~=entry.key then
    if entry.visual then entry.visual:destroy()end
    entry.key=key;entry.geometry=nil;entry.visual=Factory.new(entry.world,Vector3.zero,Pets.byId[id],nil,appearance)
    local visual=entry.visual
    local function fit()
     if entry.visual~=visual or visual.destroyed then return end
     local geometry=tostring(entry.viewport.AbsoluteSize)..":"..tostring(visual.rigRevision)..":"..tostring(visual.featureRevision or 0)
     if entry.geometry==geometry then return end;entry.geometry=geometry
     local box,size=Bounds.get(visual);local aspect=math.max(.1,entry.viewport.AbsoluteSize.X/math.max(1,entry.viewport.AbsoluteSize.Y))
     local half=math.tan(math.rad(entry.camera.FieldOfView/2));local distance=math.max(size.Y*.5/half,size.X*.5/(half*aspect))+size.Z*.5+.3
     entry.camera.CFrame=CFrame.lookAt(box.Position+Vector3.new(0,.12,distance*1.10),box.Position)
    end
    visual.reducedEffects=GuiService.ReducedMotionEnabled or(self.options.reduceEffects and self.options.reduceEffects()==true)or false
     entry.fit=fit;visual.onRigChanged=fit;visual:update(0);fit();entry.nextSample=os.clock()+Pets.byId[id].index*.009
    end
   end
   if dt==0 and entry.fit then entry.fit()end
   local now=os.clock()
   if dt>0 and now>=(entry.nextSample or 0)then
    entry.nextSample=now+1/15
    local visual=entry.visual;local reduced=GuiService.ReducedMotionEnabled or(self.options.reduceEffects and self.options.reduceEffects()==true)or false
    visual.reducedEffects=reduced
    if not reduced then visual.cosmeticTime=now;visual:update(1/15)end
   end
  end
 end
end
function View:retireTransientArt(closing)
 if self.confirmJar and(closing or not self.confirmation or not self.confirmation.itemId or self.page~="palette")then
  self.confirmJar:Destroy();self.confirmJar=nil;self.confirmJarItem=nil
 end
 if closing or self.page~="receipt"then
  if self.itemReveal.resultId or #self.receiptArt:GetChildren()>0 then self.itemReveal:clear()end
 end
end
function View:layout()
 self:retireTransientArt(false)
 self.materialPanel.useNow.Parent=if self.page=="materialReceipt"then self.card else self.materialPanel.root
 self.toyPanel.useNow.Parent=if self.page=="toyReceipt"then self.card else self.toyPanel.root
 self.featurePanel.useNow.Parent=if self.page=="featureReceipt"then self.card else self.featurePanel.root
 self.useNow.Parent=if self.page=="receipt"then self.card else self.body
 if self:chromeActive()then return self:layoutChrome()end
 self:showChrome(false)
 if self.page~="palette"or self.confirmation then
  for _,node in ipairs({self.portrait,self.petName,self.mainTab,self.secondaryTab})do node.Parent=self.body end
  self:layoutTransaction();return
 end
 return self:layoutPetPage()
end
-- The in-editor recipient page (tab "pet"): kept under the hub's Pets selector so
-- receipts and jars can still choose a pet when the selector is backed out of.
function View:layoutPetPage()
 if self.layingOut then return end;self.layingOut=true
 local size=self.shade.AbsoluteSize;local short=size.Y<220;local pad=if short then 4 else 12
 local width=math.max(1,math.min(900,size.X-16));local height=math.max(1,math.min(760,size.Y-(if short then 8 else 16)));self.card.Size=UDim2.fromOffset(width,height)
 local w=width-pad*2
 self.wallet.Visible=false;self.targetChange.Visible=false;self.machinePickup.Visible=false;self.machineSetDown.Visible=false
 self.portrait.Visible=false;self.petName.Visible=false;self.mainTab.Visible=false;self.secondaryTab.Visible=false
 local roomy=height>=420 and width>=600
 local function style(node,role)Art.roomyType(node,role,false,roomy)end
 self.title.Text=if self.assignment then "Jar recipient"else "Companions";style(self.title,if short then "Action"else "Heading")
 local titleH=math.max(44,Art.textHeight(self.title,w-52,24)+4)
 place(self.title,pad,0,w-52,titleH);place(self.closeButton,width-pad-44,0,44,44)
 local contentTop=titleH+(if short then 0 else 4);local footer=0
 if self.action.Visible then Art.type(self.action,"Action",true);footer=math.max(44,Art.actionHeight(self.action,w))+4;place(self.action,pad,height-footer,w,footer-4)end
 local listH=math.max(1,height-contentTop-footer-pad)
 place(self.body,pad,contentTop,w,listH)
 local rect=Art.scrollContentRect(self.body,w);local origin=rect.x-4
 local listW=rect.width+8
 local y=8
 local function copy(node)
  if not node.Visible then return end
  style(node,node:GetAttribute("TypeRole")or "Body");local h=Art.textHeight(node,listW-8,22);place(node,4,y,listW-8,h);y+=h+8
 end
 copy(self.targetTitle);copy(self.quote)
 local count=math.min(4,math.max(1,math.floor((rect.width+8)/52)))
 local index=0;local rowHeights={};local entries={}
 for _,pet in ipairs(Pets.collection)do local entry=self.gridPreviews[pet.id]
  if entry.button.Visible then
   local x,cell=Art.gridCell(rect.width,index%count,count,8)
   style(entry.caption,"Action");style(entry.active,"Supporting")
   local nh=Art.textHeight(entry.caption,cell-8,22);local ah=Art.textHeight(entry.active,cell-8,20)
   table.insert(entries,{entry=entry,x=x,width=cell,row=math.floor(index/count)+1,nameH=nh,activeH=ah})
   index+=1
  end
 end
 local firstRowCopy=0
 for _,item in ipairs(entries)do if item.row==1 then firstRowCopy=math.max(firstRowCopy,item.nameH+item.activeH)end end
 local previewCap=if height<420 then math.max(44,listH-y-firstRowCopy-16)else math.huge
 for _,item in ipairs(entries)do
  item.previewSide=math.min(item.width-8,previewCap)
  rowHeights[item.row]=math.max(rowHeights[item.row]or 0,item.previewSide+item.nameH+item.activeH+10)
 end
 local rowTops={};for row,h in ipairs(rowHeights)do rowTops[row]=y;y+=h+8 end
 for _,item in ipairs(entries)do
  local entry=item.entry;local cell=item.width;local h=rowHeights[item.row];local nh,ah=item.nameH,item.activeH
  place(entry.button,4+item.x,rowTops[item.row],cell,h)
  place(entry.viewport,(cell-item.previewSide)/2,4,item.previewSide,item.previewSide)
  place(entry.caption,4,h-nh-ah-4,cell-8,nh);place(entry.active,4,h-ah-2,cell-8,ah)
 end
 if self.eggsButton.Visible then Art.type(self.eggsButton,"Action",true);local h=math.max(44,Art.actionHeight(self.eggsButton,listW-8));place(self.eggsButton,4,y,listW-8,h);y+=h+8 end
 copy(self.status)
 for _,node in ipairs(self.body:GetChildren())do if node:IsA("GuiObject")and node.Visible then node.Position+=UDim2.fromOffset(origin,0)end end
 self.body.CanvasSize=UDim2.fromOffset(0,y+6);self.body.ScrollingEnabled=y+6>listH
 self.body.CanvasPosition=Vector2.new(0,math.clamp(self.body.CanvasPosition.Y,0,math.max(0,y+6-listH)))
 self.layingOut=false
end

-- ── Customize chrome (redesign menus 2) ─────────────────────────────────────
-- Pure: the tab row. Features joins only when Shared.FeatureFlags.Features is on.
function View.tabList(flags)
 flags=flags or FeatureFlags
 local tabs={{id="hue",label="Hue",icon="drop"},{id="charm",label="Charm",icon="sparkle"},{id="materials",label="Materials",icon="sphere"},{id="toys",label="Toys",icon="ball"}}
 if flags.Features then table.insert(tabs,{id="features",label="Features",icon="pattern"})end
 return tabs
end
-- Pure: the Charm cards. None is the first card, a normal option like the others.
function View.charmCards(appearance,enabled)
 appearance=appearance or {}
 local hidden=appearance.charmVisible==false
 local shape=appearance.charmShape or CharmCatalog.Default
 local known=CharmCatalog.known(shape)
 local shown=CharmCatalog.renderShape(shape)
 local cards={{id="none",name="None",status=if hidden then "WEARING"else "No charm",tone=if hidden then "accent"else "soft",wearing=hidden}}
 for _,id in ipairs(CharmCatalog.Order)do
  if enabled or id==shown then
   local wearing=not hidden and known and id==shape
   table.insert(cards,{id=id,name=CharmCatalog.ById[id].name,status=if wearing then "WEARING"else "Free",tone=if wearing then "accent"else "soft",wearing=wearing})
  end
 end
 return cards
end
-- Pure: the request a Charm card sends: None -> (false), a shape -> (true, shape).
function View.charmRequestFor(id)
 if id=="none"then return false,nil end
 return true,id
end
-- Pure: the pane for a focused Charm card. pending = the in-flight request or nil.
function View.charmPane(card,petName,pending,message)
 local line=if card.id=="none"then "No charm floats beside "..petName else "Floats beside "..petName.." in its Secondary colour"
 if pending and pending.retry then return{button="Try again",enabled=true,line=line,status=message or "Not saved yet."}end
 if pending then return{button="Saving…",enabled=false,line=line,status="Saving…"}end
 if card.wearing then return{button="Wearing",enabled=false,line=line,status=message or ""}end
 return{button="Wear",enabled=true,line=line,status=message or "Trying it on. Not saved yet."}
end
-- Pure: chrome geometry for a W x H screen (panel units on desktop, pixels on phones).
function View.chromeGeometry(W,H,phone)
 if phone then
  local pw=232;local gw=W-20-pw-12-20
  return{phone=true,W=W,H=H,tabs={x=20,y=64,w=gw,h=36},pane={x=W-20-pw,y=64,w=pw,h=H-84},grid={x=20,y=108,w=gw,h=H-108-16},
   cols=if gw>=420 then 2 else 1,cardH=64,gap=8,pad=12,well=86,actionH=44}
 end
 return{phone=false,W=848,H=608,tabs={x=24,y=84,w=800,h=44},pane={x=24,y=144,w=328,h=392},grid={x=368,y=144,w=456,h=392},
  cols=2,cardH=96,gap=12,pad=16,well=196,actionH=56}
end
function View:chromeActive()
 return self.shade.Visible and self.page=="palette"and not self.confirmation and self.tab~="pet"
end
-- Receipts' "Use now" (material, toy, feature): pick the pet on the hub's Pets selector.
function View:landOnPets(result)
 self.page="palette";self.tab="pet";self.body.CanvasPosition=Vector2.zero;self:refresh()
 local name=if result.finishId then MaterialCatalog.ById[result.finishId].name elseif result.toyId then ToyCatalog.ById[result.toyId].name
  elseif result.featureId then FeatureCatalog.ById[result.featureId].name else "it"
 self:openPetsSelector(name)
end
function View:openPetsSelector(itemName)
 if not self.options.petsSelector then return false end
 local lifecycle=self.lifecycleEpoch
 return self.options.petsSelector({line="Use "..itemName.." on this pet",button="Use here",
  choose=function(id)return not self.destroyed and self.shade.Visible and self.lifecycleEpoch==lifecycle and self:choosePet(id)==true end,
  cancel=function()end})==true
end
-- Docks the nodes the chrome borrows from the transaction card (panels, legacy rows,
-- the portrait) into the chrome, or back to the card's body.
function View:showChrome(on)
 if not self.chromeRoot then return end
 self.chromeRoot.Visible=on;self.card.Visible=not on
 local target=if on then self.gridContent else self.body
 for _,node in ipairs({self.materialPanel.root,self.toyPanel.root,self.featurePanel.root,self.empty,self.legacyTitle,self.presetTitle})do node.Parent=target end
 for _,node in pairs(self.legacyButtons)do node.Parent=target end
 for _,node in pairs(self.presetButtons)do node.Parent=target end
 if on then self.portrait.Parent=self.chromeWell;self.portrait.Position=UDim2.new();self.portrait.Size=UDim2.fromScale(1,1)
 elseif self.portrait.Parent==self.chromeWell then self.portrait.Parent=self.card end
 if not on and self.chromeRing then self.chromeRing.hide()end
 -- QA Q2.1: the chrome's dim joins the shared shade stack (one dim at a time); a
 -- screen opened over Customize (Wardrobe, Pets selector) hides this panel.
 if on and self.chromeDim and self.shade.Visible then
  Kit.shadeOpen(self,self.chromeDim,function(covered)
   if not self.chromePanel then return end
   self.chromePanel.Visible=not covered
   if not covered and self.chromeBody then Kit.slideIn(self.chromeBody,-Kit.SlideOffset,Kit.headerSkip(self.header))end
  end)
 elseif not on and not self.rebuildingChrome then Kit.shadeClose(self)end
end
function View:buildChrome(view)
 if self.chromeRoot then
  -- Return borrowed nodes before the old chrome is destroyed.
  self.rebuildingChrome=true;self:showChrome(false);self.rebuildingChrome=nil;self.chromeRoot:Destroy()
 end
 local phone=view~=nil
 local g=View.chromeGeometry(if phone then view.W else 848,if phone then view.H else 608,phone)
 self.chromeGeom=g;self.chromeKey=if phone then string.format("%dx%d",view.W,view.H)else "regular"
 local root=Kit.frame(self.shade,"Customize",nil,UDim2.new(),UDim2.fromScale(1,1));root.ZIndex=self.shade.ZIndex+1;root.Visible=false
 self.chromeRoot=root
 local dim=Kit.frame(root,"Shade",nil,UDim2.new(),UDim2.fromScale(1,1));dim.BackgroundTransparency=if phone then 1 else .35;dim.BackgroundColor3=Color3.new(0,0,0);dim.Active=true
 dim:SetAttribute("ShadeAlpha",dim.BackgroundTransparency);Kit.coverScreen(dim);self.chromeDim=dim
 local panel=Kit.frame(root,"Panel","panel",UDim2.fromScale(.5,.5),UDim2.fromOffset(g.W,g.H),30);panel.Active=true;panel.ZIndex=dim.ZIndex+1
 self.chromePanel=panel;self.chromeScale=Kit.node("UIScale",panel,{Scale=1})
 local body=panel
 if phone then
  panel.BackgroundTransparency=1
  local sheet=Kit.sheet(panel,g.W,g.H)
  body=Kit.frame(panel,"Body",nil,UDim2.new(),UDim2.fromScale(1,1));body.ZIndex=sheet.ZIndex+3
 else
  panel.AnchorPoint=Vector2.new(.5,.5);panel.ClipsDescendants=true;Kit.stroke(panel)
  local gradient=Kit.frame(panel,"Gradient",nil,UDim2.new(),UDim2.fromScale(1,1));gradient.BackgroundTransparency=0;gradient.BackgroundColor3=Color3.new(1,1,1)
  Kit.node("UIGradient",gradient,{Rotation=90,Color=ColorSequence.new(Color3.new(1,1,1),Color3.new(0,0,0)),Transparency=NumberSequence.new(.97,.88)})
 end
 self.chromeBody=body
 self.header=Kit.header(body,{title="Customize",eyebrow="Companions",tint="companions",compact=phone,width=g.W,left=if phone then 24 else 24,onBack=function()self:close("back")end})
 local tabs=View.tabList();local labels,icons={},{}
 for _,t in ipairs(tabs)do table.insert(labels,t.label);table.insert(icons,t.icon)end
 self.chromeTabs=Kit.tabs(body,labels,g.tabs.w,g.tabs.h,if phone then 14 else 16,icons);self.chromeTabs.root.Position=UDim2.fromOffset(g.tabs.x,g.tabs.y)
 self.chromeTabs.changed=function(index)
  local wanted=tabs[index].id
  if not self:setTab(wanted)then self:layout()end
 end
 self.editorTabs={}
 for i,t in ipairs(tabs)do self.editorTabs[t.id]=self.chromeTabs.buttons[i];self.chromeTabs.buttons[i].Name="Tab_"..t.id end
 -- Pane: preview well, name, chip, one line, status, primary action.
 local pane=Kit.card(body,"Preview",nil,{pad=g.pad});pane.Position=UDim2.fromOffset(g.pane.x,g.pane.y);pane.Size=UDim2.fromOffset(g.pane.w,g.pane.h)
 self.chromePane=pane
 local p=g.pad;local iw=g.pane.w-p*2
 local well=Kit.frame(pane,"PreviewWell","well",UDim2.fromOffset(p,p),UDim2.fromOffset(iw,g.well),12);Kit.stroke(well);self.chromeWell=well
 local y=p+g.well+(if phone then 6 else 12)
 local nameH=if phone then 22 else 30
 self.paneName=Kit.text(pane,"Title","","text",{Name="PaneName",Position=UDim2.fromOffset(p,y),Size=UDim2.fromOffset(iw-80,nameH),TextSize=if phone then 18 else 24,TextTruncate=Enum.TextTruncate.AtEnd})
 self.paneChip=Kit.chip(pane,"Free",nil,if phone then 22 else 26);self.paneChip.root.AnchorPoint=Vector2.new(1,.5);self.paneChip.root.Position=UDim2.fromOffset(p+iw,y+nameH/2)
 y+=nameH+(if phone then 0 else 4)
 self.paneLine=Kit.text(pane,"Small","","soft",{Name="PaneLine",Position=UDim2.fromOffset(p,y),Size=UDim2.fromOffset(iw,20),TextSize=if phone then 12 else 15,TextTruncate=Enum.TextTruncate.AtEnd})
 y+=if phone then 18 else 24
 self.paneStatus=Kit.text(pane,"Small","","soft",{Name="PaneStatus",Position=UDim2.fromOffset(p,y),Size=UDim2.fromOffset(iw,20),TextSize=if phone then 12 else 15,TextTruncate=Enum.TextTruncate.AtEnd})
 local action,state=Kit.button(pane,"Action",{variant="primary",text="Wear",glyph="A",size=Vector2.new(iw,g.actionH),textSize=if phone then 16 else nil,selectable=false})
 action.Position=UDim2.fromOffset(p,g.pane.h-p-g.actionH);self.chromeAction,self.chromeActionState=action,state
 action.Activated:Connect(function()self:chromeAct()end)
 -- Grid.
 local grid=Kit.node("ScrollingFrame",body,{Name="Grid",BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(g.grid.x,g.grid.y),
  Size=UDim2.fromOffset(g.grid.w,g.grid.h),ScrollBarThickness=4,ZIndex=body.ZIndex+1,Selectable=false,ScrollingDirection=Enum.ScrollingDirection.Y,
  ScrollBarImageColor3=Color3.new(1,1,1),ScrollBarImageTransparency=.6,Active=true})
 self.chromeGrid=grid;self.gridContent=grid
 self.channelTabs=Kit.tabs(grid,{"Main","Secondary"},g.grid.w-6,if phone then 36 else 40,if phone then 14 else 15)
 self.channelTabs.root.Name="ChannelTabs"
 self.channelTabs.changed=function(index)if not self:chooseChannel(if index==1 then "main"else "secondary")then self:layout()end end
 self.hueCards={}
 for _,id in ipairs(ids)do local itemId=id
  local b=Cards.new(grid,"HueCard_"..id);self.hueCards[id]=b
  b.Activated:Connect(function()self:chromeTap("hue",itemId)end)
 end
 self.charmCards={}
 for _,id in ipairs({"none",table.unpack(CharmCatalog.Order)})do local cardId=id
  local b=Cards.new(grid,"CharmCard_"..id);self.charmCards[id]=b
  b.Activated:Connect(function()self:chromeTap("charm",cardId)end)
 end
 local tip=Kit.card(grid,"CharmTip",nil,{pad=16,role="well"});tip.Visible=false;self.charmTip=tip
 self.charmTipIcon=Kit.icon(tip,"drop",20,"soft");self.charmTipIcon.Position=UDim2.fromOffset(24,26)
 self.charmTipText=Kit.text(tip,"Body","","text",{Name="TipText",Position=UDim2.fromOffset(60,12),Size=UDim2.new(1,-72,1,-24),TextSize=15,TextWrapped=true})
 if not phone then
  local hints=Kit.frame(body,"Hints",nil,UDim2.fromOffset(24,566),UDim2.fromOffset(560,24))
  local x=0
  for _,pair in ipairs({{"+","Browse"},{"LB","Tab"},{"A","Wear"},{"B","Back"}})do
   local chip=Kit.glyph(hints,pair[1],false,22,true);chip.Position=UDim2.fromOffset(x,1)
   local t=Kit.text(hints,"Small",pair[2],"soft",{Position=UDim2.fromOffset(x+chip.Size.X.Offset+6,0),Size=UDim2.fromOffset(120,24),AutomaticSize=Enum.AutomaticSize.X})
   if pair[1]=="A"then self.hintVerb=t end
   x+=chip.Size.X.Offset+6+game:GetService("TextService"):GetTextSize(pair[2],14,Enum.Font.BuilderSans,Vector2.new(500,30)).X+18
  end
  self.hintPromise=Kit.text(body,"Small","","dim",{Name="Promise",Position=UDim2.fromOffset(424,566),Size=UDim2.fromOffset(400,24),TextXAlignment=Enum.TextXAlignment.Right})
 else self.hintVerb=nil;self.hintPromise=nil end
 self.chromeRing=Kit.focusRing(panel)
 self.chromeFocus=self.chromeFocus or {}
end
function View:fitChrome(size)
 local phone=Kit.compactRule(size.X,size.Y)
 local view=nil
 if phone then local _,kh=Kit.keepOut();view={W=math.floor(size.X),H=math.floor(size.Y)-(kh+2),top=kh+2}end
 local key=if view then string.format("%dx%d",view.W,view.H)else "regular"
 if self.chromeKey~=key or not self.chromeRoot then self:buildChrome(view);self.chromeRoot.Visible=true;self.card.Visible=false;self:showChrome(true)end
 local panel=self.chromePanel
 if view then panel.AnchorPoint=Vector2.zero;panel.Position=UDim2.fromOffset(0,view.top);panel.Size=UDim2.fromOffset(view.W,view.H);self.chromeScale.Scale=1
 else panel.AnchorPoint=Vector2.new(.5,.5);panel.Position=UDim2.fromScale(.5,.5);panel.Size=UDim2.fromOffset(848,608)
  self.chromeScale.Scale=math.max(.1,math.min(1.2,(size.X-24)/848,(size.Y-24)/608))end
end
function View:focusIndex()return(self.chromeFocus and self.chromeFocus[self.tab])or 1 end
local Promise={hue="One fruit, one step of colour.",charm="Charms are free.",materials="Finishes are free to switch.",toys="Toys are free to switch.",features="Grow and show features freely."}
function View:layoutChrome()
 if self.layingOut then return end;self.layingOut=true
 self:fitChrome(self.shade.AbsoluteSize);self:showChrome(true)
 local g=self.chromeGeom;local compact=g.phone
 local pet=Pets.byId[self.petId];local petName=pet and pet.name or ""
 local tabs=View.tabList()
 for i,t in ipairs(tabs)do if t.id==self.tab and self.chromeTabs.selected~=i then self.chromeTabs.select(i)end end
 self.header.root.Visible=true
 if self.header.wallet then self.header.wallet.set(self.state.nectar or 0)end
 self.header.setTitle("Customize",if self.machine then "Care Cradle"else "Companions")
 local allowed=self:canCustomize()
 self.chromeTabs.root.Visible=not self.boundedEating and(allowed or self:hasHueAssignment())
 for _,b in pairs(self.chromeTabs.buttons)do b.Interactable=not self.intent.pending end
 local grid=self.chromeGrid;local gw=g.grid.w-4 -- the 4 px scrollbar never covers the right column
 for _,b in pairs(self.hueCards)do b.Visible=false end
 for _,b in pairs(self.charmCards)do b.Visible=false end
 self.charmTip.Visible=false;self.channelTabs.root.Visible=false
 local focus={}
 local index=self:focusIndex()
 local y=3
 local pane={name=petName,chip=nil,line="",status="",button=nil,enabled=false}
 local a=self:appearance()
 if self.boundedEating then
  pane.line="Eating…"
 elseif self.tab=="hue"then
  self.channelTabs.root.Visible=true;self.channelTabs.root.Position=UDim2.fromOffset(3,y)
  self.channelTabs.select(if self.channel=="main"then 1 else 2);y+=self.channelTabs.root.Size.Y.Offset+12
  local counts=self:counts();local live={}
  if not self.assignment then
   for _,id in ipairs(ids)do local stock=(self.state.hueInventory or {})[id]or 0;if id~="reset"or stock>0 then table.insert(live,id)end end
  end
  local rects,h=Cards.rects(#live,gw,g.cols,g.cardH,g.gap,y)
  index=math.clamp(index,1,math.max(1,#live))
  for i,id in ipairs(live)do
   local b=self.hueCards[id];b.Visible=true;Cards.place(b,rects[i])
   local stock=(self.state.hueInventory or {})[id]or 0;local reason=self:reason(id)
   local swatch=if id=="reset"then Hues.Items.reset.color else(Swatches.at(self.petId,a,self.channel,id,math.min(5,counts[id]+1))or Hues.ById[id].color)
   local status=(if id=="reset"then "Clears "..channelName(self.channel)else counts[id].." of 5").." · ×"..stock
   Cards.dress(b,{name=names[id],status=status,tone=if reason then "dim"else "soft",swatch=swatch,focused=i==index,compact=compact})
   table.insert(focus,{button=b,id=id,act=function()return self:chooseItem(id)end})
  end
  y+=h+(if #live>0 then 12 else 0)
  for _,node in ipairs({self.empty,self.legacyTitle})do
   if node.Visible then Art.type(node,"Body",compact);local th=Art.textHeight(node,gw-6,24);place(node,3,y,gw-6,th);y+=th+8 end
  end
  for _,id in ipairs(ids)do local n=self.legacyButtons[id];if n and n.Visible then Art.type(n,"Action",compact);local bh=math.max(44,Art.actionHeight(n,gw-6));place(n,3,y,gw-6,bh);y+=bh+8 end end
  if self.presetTitle.Visible then Art.type(self.presetTitle,"Body",compact);local th=Art.textHeight(self.presetTitle,gw-6,24);place(self.presetTitle,3,y,gw-6,th);y+=th+8 end
  for _,n in pairs(self.presetButtons)do if n.Visible then Art.type(n,"Action",compact);local bh=math.max(44,Art.actionHeight(n,gw-6));place(n,3,y,gw-6,bh);y+=bh+8 end end
  local item=focus[index]
  if self.assignment then
   pane.name=names[self.assignment.itemId];pane.line="Choose Main or Secondary for "..petName
  elseif item then
   local id=item.id;local counts2=counts;local reason=self:reason(id);local stock=(self.state.hueInventory or {})[id]or 0
   pane.name=names[id];pane.chip={"×"..stock,"plain"}
   pane.line=reason or(if id=="reset"then "Clears "..petName.."'s "..channelName(self.channel).." colour"else channelName(self.channel).." "..counts2[id].." of 5 → "..math.min(5,counts2[id]+1).." of 5")
   pane.button=if id=="reset"then "Use Reset Hue"else "Use 1 fruit"
   pane.enabled=allowed and not self.intent.pending and reason==nil
  else
   pane.line="No fruit yet. Hatch a Hue Egg."
  end
  if self.intent.status=="Retrying"then pane.button="Try again";pane.enabled=true end
 elseif self.tab=="charm"then
  local enabled=self:shapeSelectionsEnabled()
  local cards=View.charmCards(a,enabled)
  -- First visit lands on the card being worn.
  if not self.chromeFocus.charm then for i,c in ipairs(cards)do if c.wearing then index=i end end end
  index=math.clamp(index,1,#cards);self.chromeFocus.charm=index
  local rects,h=Cards.rects(#cards,gw,g.cols,g.cardH,g.gap,y)
  local tint=Palette.resolve(self.petId,a).secondary
  for i,c in ipairs(cards)do
   local b=self.charmCards[c.id];b.Visible=true;Cards.place(b,rects[i])
   Cards.dress(b,{name=c.name,status=c.status,tone=c.tone,icon=if c.id=="none"then "none"elseif c.id=="dot"then "sparkle"elseif c.id=="ring"then "ball"else "sphere",
    iconColor=if c.id=="none"then Kit.Color.soft else tint,focused=i==index,compact=compact})
   b:SetAttribute("Wearing",c.wearing)
   local cardId=c.id
   table.insert(focus,{button=b,id=c.id,act=function()return self:wearCharm(cardId)end})
  end
  y+=h+12
  if not compact then
   self.charmTip.Visible=true;place(self.charmTip,3,y,gw-6,72)
   self.charmTipText.Text="Charms take "..petName.."'s Secondary colour.\nChange it on the Hue tab."
   Kit.tintIcon(self.charmTipIcon,function()return tint end)
   y+=80
  end
  local c=cards[index];self.charmFocusId=c.id
  local s=View.charmPane(c,petName,self.charmRequests[self.petId],self.charmMessage)
  pane.name=c.name;pane.chip={"Free","accent"};pane.line=s.line;pane.status=s.status;pane.button=s.button;pane.enabled=s.enabled and allowed
 else
  local panel=if self.tab=="materials"then self.materialPanel elseif self.tab=="toys"then self.toyPanel else self.featurePanel
  if panel.root.Visible then
   local h,list=panel:layoutCards(gw,g.cols,g.cardH,g.gap,index,compact)
   panel.root.Position=UDim2.fromOffset(0,y-3);y+=h-3
   focus=list
   index=math.clamp(index,1,math.max(1,#list))
   local item=list[index]
   if item then
    pane.name=item.name;pane.line=if item.wearing then "Wearing on "..petName else "Free to switch, saved at once"
    pane.button=if item.wearing then "Wearing"else "Wear";pane.enabled=not item.wearing and allowed
    pane.status=panel.status.Visible and panel.status.Text or ""
   else pane.line="Hatch eggs to find more."end
  end
 end
 self.chromeFocus[self.tab]=index;self.focusables=focus
 grid.CanvasSize=UDim2.fromOffset(0,y+6)
 -- Pane.
 self.paneName.Text=pane.name or ""
 self.paneChip.root.Visible=pane.chip~=nil
 if pane.chip then self.paneChip.set(pane.chip[1],pane.chip[2]);if pane.chip[2]=="accent"then Kit.paint(self.paneChip.label,"TextColor3","accent")end end
 local status=pane.status or ""
 if self.exitMessage then status=self.exitMessage elseif self.useMessage then status=self.useMessage elseif self.saveNotice then status=self.saveNotice.detail end
 if compact and status~=""then self.paneLine.Text=status;self.paneStatus.Text=""else self.paneLine.Text=pane.line or "";self.paneStatus.Text=status end
 self.chromeAction.Visible=pane.button~=nil
 if pane.button then Kit.setText(self.chromeAction,pane.button);Kit.setEnabled(self.chromeAction,pane.enabled==true)end
 Kit.setGlyphVisible(self.chromeAction,not compact or not Kit.lastInputTouch())
 if self.hintVerb then self.hintVerb.Text=if self.tab=="hue"then "Use"else "Wear"end
 if self.hintPromise then self.hintPromise.Text=Promise[self.tab]or ""end
 self.chromePanel:SetAttribute("Tab",self.tab);self.chromePanel:SetAttribute("FocusedCard",focus[index]and focus[index].id or nil)
 -- Focus ring on the focused card.
 local target=focus[index]
 if target and self.chromeRing then
  self.chromeRing.attach(target.button,12)
  local top=target.button.Position.Y.Offset;local bottom=top+target.button.Size.Y.Offset;local view=grid.Size.Y.Offset
  local cy=grid.CanvasPosition.Y
  if top-8<cy then cy=top-8 elseif bottom+8>cy+view then cy=bottom+8-view end
  grid.CanvasPosition=Vector2.new(0,math.clamp(cy,0,math.max(0,y+6-view)))
 elseif self.chromeRing then self.chromeRing.hide()end
 self.layingOut=false;self:fitPortrait()
end
-- Tap / click on a chrome card: the first tap selects (and previews), the second acts.
function View:chromeTap(tab,id)
 if not self:chromeActive()or self.tab~=tab then return false end
 for i,item in ipairs(self.focusables or {})do
  if item.id==id then
   if i==self:focusIndex()then return self:chromeAct()end
   self:chromeFocusAt(i);return true
  end
 end
 return false
end
function View:chromeFocusAt(index)
 self.chromeFocus[self.tab]=index;self.epoch+=1
 if self.tab=="charm"then self.charmMessage=nil end
 self:layout();self:paintPortrait()
end
function View:chromeMove(dx,dy)
 local list=self.focusables or {};if #list==0 then return false end
 local nextIndex=Cards.step(self:focusIndex(),dx,dy,#list,self.chromeGeom.cols)
 if nextIndex==self:focusIndex()then return false end
 self:chromeFocusAt(nextIndex);return true
end
function View:shiftTab(delta)
 local tabs=View.tabList();local at=1
 for i,t in ipairs(tabs)do if t.id==self.tab then at=i end end
 local nextIndex=math.clamp(at+delta,1,#tabs)
 if nextIndex==at then return false end
 return self:setTab(tabs[nextIndex].id)
end
-- A / Enter / the pane button.
function View:chromeAct()
 if not self:chromeActive()then return false end
 if self.tab=="hue"and self.intent.status=="Retrying"then return self.intent:retry()end
 if self.tab=="materials"and self.materialIntent and self.materialIntent.status=="Retrying"then return self.materialIntent:retry()end
 local item=(self.focusables or {})[self:focusIndex()]
 if not item or not self.chromeAction.Visible or not Kit.buttonState(self.chromeAction).enabled then return false end
 return item.act()==true
end
-- Charm: None sends charm(petId, false); a shape sends charm(petId, true, shape).
function View:wearCharm(id)
 if self.intent.pending then return false end
 if id~="none"and not CharmCatalog.known(id)then return false end
 local visible,shape=View.charmRequestFor(id)
 if shape and not self:shapeSelectionsEnabled()then shape=nil end
 return self:requestCharm(visible,shape)
end
-- Keyboard / gamepad for the chrome (bound by the caller, as the Wardrobe's is).
function View:chromeInput(key)
 if not self:chromeActive()then return false end
 local K=Enum.KeyCode
 if key==K.Left or key==K.A or key==K.DPadLeft then self:chromeMove(-1,0)
 elseif key==K.Right or key==K.D or key==K.DPadRight then self:chromeMove(1,0)
 elseif key==K.Up or key==K.W or key==K.DPadUp then self:chromeMove(0,-1)
 elseif key==K.Down or key==K.S or key==K.DPadDown then self:chromeMove(0,1)
 elseif key==K.Q or key==K.ButtonL1 then self:shiftTab(-1)
 elseif key==K.E or key==K.ButtonR1 then self:shiftTab(1)
 elseif key==K.X or key==K.ButtonX then if self.tab=="hue"then self:chooseChannel(if self.channel=="main"then "secondary"else "main")end
 elseif key==K.ButtonB or key==K.Backspace then self:close("back")
 elseif key==K.Return or key==K.KeypadEnter or key==K.Space or key==K.ButtonA then self:chromeAct()
 else return false end
 return true
end
function View:layoutTransaction()
 if self.layingOut then return end;self.layingOut=true
 self.targetChange.Text=Pets.byId[self.petId].name.." · Change pet"
 self.targetChange:SetAttribute("AccessibleLabel","Change active pet · "..Pets.byId[self.petId].name)
 self.channelTitle.Visible=self.page=="palette"and self.tab=="hue"and not self.confirmation and not self:compactSwatches()
 self:paintSwatches(self.inspection.Visible)
 if self.portrait.Visible then self.petName.Visible=true end
 local materialReceipt=self.page=="materialReceipt";local toyReceipt=self.page=="toyReceipt";local featureReceipt=self.page=="featureReceipt";local hueReceipt=self.page=="receipt";local paired=self.cancel.Visible or materialReceipt or toyReceipt or featureReceipt or hueReceipt
 local size=self.shade.AbsoluteSize;local width=math.max(1,math.min(if materialReceipt or(self.confirmation and not(size.Y<280))then 470 else 640,size.X-16));local short=size.Y<280;local pad=if short then 8 else 16;local w=width-pad*2
 local inlineHue=hueReceipt and size.Y<420
 if hueReceipt and self.state.pendingHueResult then self.title.Text=names[self.state.pendingHueResult.itemId]end
 self.receiptDetail.Visible=false;self.receipt.TextXAlignment=if inlineHue then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center
 Art.type(self.title,if short or inlineHue then "Body"else "Heading",short);Art.type(self.wallet,"Counter",short)
 local titleH=Art.textHeight(self.title,w-52,24);place(self.title,pad,5,w-52,titleH);place(self.closeButton,width-pad-44,4,44,44)
 local header=math.max(48,titleH+8);self.wallet.Visible=false
 if self.wallet.Visible then
  local walletH=Art.textHeight(self.wallet,w,22)
  if self.page=="palette"and width>=580 and size.Y<420 then
   local walletW=Art.textWidth(self.wallet)+4;local titleW=w-walletW-64
   self.title.Text=Pets.byId[self.petId].name.." · "..(if self.tab=="hue"then channelName(self.channel)else "Charm");Art.type(self.title,"Body",false)
   local compactH=Art.textHeight(self.title,titleW,24);header=math.max(44,compactH+8,walletH+8)
   place(self.title,pad,4,titleW,header-8);place(self.wallet,width-pad-44-walletW-8,4,walletW,header-8)
  else place(self.wallet,pad,header,w,walletH);header+=walletH+4 end
 end
 local footer=0
 local peer=if materialReceipt then self.materialPanel.useNow elseif toyReceipt then self.toyPanel.useNow elseif featureReceipt then self.featurePanel.useNow elseif hueReceipt then self.useNow else self.cancel
 if self.action.Visible then Art.type(self.action,"Action",short);Art.type(peer,"Action",short);footer=math.max(44,Art.actionHeight(self.action,if paired then (w-8)/2 else w),if paired then Art.actionHeight(peer,(w-8)/2)else 44)+8 end
 if self.machinePickup.Visible then
  Art.type(self.machinePickup,"Action",short);Art.type(self.machineSetDown,"Action",short)
  footer=math.max(44,Art.actionHeight(self.machinePickup,(w-8)/2),Art.actionHeight(self.machineSetDown,(w-8)/2))+8
 end
 local height=math.max(1,math.min(if self.confirmation then 420 else 760,size.Y-16));self.card.Size=UDim2.fromOffset(width,height)
 local bodyH=math.max(1,height-header-footer-8);place(self.body,pad,header,w,bodyH)
 if paired then place(peer,pad,height-footer,(w-8)/2,footer-8);place(self.action,pad+(w+8)/2,height-footer,(w-8)/2,footer-8)else place(self.action,pad,height-footer,w,footer-8)end
 if self.machinePickup.Visible then place(self.machinePickup,pad,height-footer,(w-8)/2,footer-8);place(self.machineSetDown,pad+(w+8)/2,height-footer,(w-8)/2,footer-8)end
 if short and self.confirmation then
  local side=math.max(112,math.min(w*.45,math.max(Art.textWidth(self.action),Art.textWidth(self.cancel))+20));local gap=8;local fullW=w
  w=math.max(1,w-side-gap);bodyH=math.max(1,height-header-8)
  place(self.body,pad,header,w,bodyH)
  local ah=math.max(44,Art.actionHeight(self.action,side));local cancelH=math.max(44,Art.actionHeight(self.cancel,side))
  place(self.cancel,pad+fullW-side,header,side,cancelH);place(self.action,pad+fullW-side,header+cancelH+8,side,ah)
 end
 local bodyW=w;local shellW=width-pad*2;local rect=Art.scrollContentRect(self.body,bodyW);local origin=rect.x-4
 w=rect.width+8
 local y=6
 local function copy(n,min)if not n.Visible then return end;Art.type(n,n:GetAttribute("TypeRole")or "Body",short);local h=Art.textHeight(n,w-8,min or 24);place(n,4,y,w-8,h);y+=h+8 end
 local function row(nodes,cols)
  local live={};for _,n in ipairs(nodes)do if n.Visible then table.insert(live,n)end end;if #live==0 then return end
  local _,rw=Art.gridCell(w-8,0,cols,8);local h=44
  for _,n in ipairs(live)do Art.type(n,"Action",short);h=math.max(h,Art.actionHeight(n,rw))end
  for i,n in ipairs(live)do local x,cellW=Art.gridCell(w-8,(i-1)%cols,cols,8);place(n,4+x,y+math.floor((i-1)/cols)*(h+8),cellW,h)end;y+=math.ceil(#live/cols)*(h+8)
 end
 copy(self.migrationText)
 for _,panel in ipairs({self.materialPanel,self.toyPanel,self.featurePanel})do if panel.root.Visible then place(panel.root,4,y,w-8,panel:layout(w-8,size.Y<420,bodyH));y+=panel.root.Size.Y.Offset+8 end end
 if self.confirmation then
  local item=self.confirmation.itemId
  if item then
   local inset=if w>=260 then 90 else 4
   if self.confirmJar and self.confirmJarItem~=item then self.confirmJar:Destroy();self.confirmJar=nil end
   if not self.confirmJar then self.confirmJar=JarArt.create(self.body,item,UDim2.fromOffset(4,0),UDim2.fromOffset(76,88),25);self.confirmJarItem=item end
   place(self.confirmJar,4,0,if inset>4 then 76 else 44,if inset>4 then 88 else 52)
   for _,entry in ipairs({{self.confirmTarget,"Action",20},{self.confirmDelta,"Action",18},{self.confirmStock,"Body",16}})do
    local node=entry[1];Art.type(node,entry[2],short)
    local chip=if node==self.confirmDelta then 32 else 0;local tw=w-inset-4-chip;local h=Art.textHeight(node,tw,24)
    place(node,inset,y,tw,h)
    if node==self.confirmDelta then place(self.resultSwatch,w-30,y+(h-24)/2,24,24)end
    y+=h+6
   end
   y=math.max(if inset>4 then 92 else 56,y)
   copy(self.confirmWarning,24)
  else copy(self.quote,28)end
 elseif self.confirmJar then self.confirmJar:Destroy();self.confirmJar=nil;self.confirmJarItem=nil end
 copy(self.targetTitle);local targets={};for _,pet in ipairs(Pets.collection)do table.insert(targets,self.targets[pet.id])end;row(targets,if w>=430 then 3 else 2)
 if self.targetChange.Visible then Art.type(self.targetChange,"Body",short);local tw=math.min(w-8,math.max(160,Art.textWidth(self.targetChange)+20));local th=math.max(44,Art.actionHeight(self.targetChange,tw));place(self.targetChange,4,y,tw,th);y+=th+8 end
 if hueReceipt then
  local receiptH=ReceiptLayout.layout(self.receiptArt,self.receipt,w-8,bodyH,size.Y<420)
  self.receiptArt.Position+=UDim2.fromOffset(4,y);self.receipt.Position+=UDim2.fromOffset(4,y);y+=receiptH
 end
 if self.portrait.Visible then local h=if short then 140 else 180;place(self.portrait,4,y,w-8,h);y+=h+4;copy(self.petName)end
 row({self.mainTab,self.secondaryTab},2);copy(self.channelTitle);copy(self.inspection)
 for _,id in ipairs(ids)do local b=self.bars[id];if b and b.row.Visible then
  y+=layoutBar(b,4,y,w-8)+6
 end end
 copy(self.charmTitle);local shapeButtons={};for _,id in ipairs(CharmCatalog.Order)do table.insert(shapeButtons,self.shapes[id])end;row(shapeButtons,3)
 copy(self.legacyTitle);local redemption={};for _,id in ipairs(ids)do if self.legacyButtons[id]then table.insert(redemption,self.legacyButtons[id])end end;row(redemption,2)
 copy(self.presetTitle);local presets={};for _,n in pairs(self.presetButtons)do table.insert(presets,n)end;table.sort(presets,function(a,b)return a.Name<b.Name end);row(presets,2)
 if not self.confirmation then copy(self.quote,28)end
 copy(self.status)
 -- Stock remains the last section; confirmation/footer stays reachable while it scrolls.
 copy(self.inventoryTitle);copy(self.empty)
 for _,id in ipairs(ids)do local j=self.jars[id];if j.button.Visible then
  Art.type(j.label,"Body",short);Art.type(j.quantity,"Counter",short);Art.type(j.reason,"Supporting",short)
  local textW=math.max(1,w-76);local lh=Art.textHeight(j.label,math.max(1,textW-40),22);local rh=Art.textHeight(j.reason,textW,18);local h=math.max(68,lh+rh+12)
  place(j.button,4,y,w-8,h);place(j.art,6,(h-52)/2,44,52);place(j.label,60,5,textW-40,lh);place(j.quantity,w-56,5,38,lh);place(j.reason,60,lh+7,textW,rh);y+=h+8
 end end
 if(self.confirmation or materialReceipt or toyReceipt or featureReceipt or hueReceipt)and not short then
  -- Canvas includes six pixels after content; reserve all six before the footer.
  height=math.min(size.Y-16,header+y+footer+14);self.card.Size=UDim2.fromOffset(width,height)
  bodyH=math.max(1,height-header-footer-8);place(self.body,pad,header,bodyW,bodyH)
  place(peer,pad,height-footer,(shellW-8)/2,footer-8);place(self.action,pad+(shellW+8)/2,height-footer,(shellW-8)/2,footer-8)
 end
 for _,node in ipairs(self.body:GetChildren())do if node:IsA("GuiObject")and node.Visible then node.Position+=UDim2.fromOffset(origin,0)end end
 self.body.CanvasSize=UDim2.fromOffset(0,y+6);self.body.ScrollingEnabled=y+6>bodyH
 self.body.CanvasPosition=Vector2.new(0,math.clamp(self.body.CanvasPosition.Y,0,math.max(0,y+6-bodyH)));self.layingOut=false;self:fitPortrait()
end
function View:setSaveNotice(notice)self.saveNotice=notice;if self.shade.Visible then self:refresh()end end
function View:open(state,page,petId)
 self.materialAssignment=nil;self.toyAssignment=nil;self.featureAssignment=nil;self.featurePreview=nil
 self.intent:update(state);self.state=state or {}
 if self.materialIntent then self.materialIntent:update(self.state)end
 if self.toyIntent then self.toyIntent:update(self.state)end;if self.featureIntent then self.featureIntent:update(self.state)end
 if self.state.lastHatch then if self.options.pendingHatch then self.options.pendingHatch()end;return false end
 self.page=if self.state.pendingHueResult then "receipt"elseif self.state.pendingMaterialResult then "materialReceipt"elseif self.state.pendingToyResult then "toyReceipt"elseif self.state.pendingFeatureResult then "featureReceipt"elseif page=="toyBuy"then "toyBuy"elseif page=="featureBuy"then "featureBuy"elseif page=="materialBuy"then "materialBuy"elseif page=="buy"then "buy"else "palette"
 if self.state.hueMigrationId and self.state.hueMigrationAcknowledged==false then self.afterMigrationPage=self.page;self.page="migration"end
 self.petId=petId or self.petId;self.tab=if page=="charm"then "charm"elseif page=="materials"then "materials"elseif page=="toys"then "toys"elseif page=="features"then "features"elseif page=="pet"then "pet"else "hue";self.channel="main";self.inspected=nil;self.useMessage=nil;self.confirmation=nil;self.assignment=nil;self.selectTarget=false;self.body.CanvasPosition=Vector2.zero
 local p=self.intent.pending
 if p and p.action=="hueUse"then self.page="palette";self.petId=p.value.petId;self.channel=p.value.channel;self.confirmation={itemId=p.value.itemId,petId=p.value.petId,channel=p.value.channel,pendingResultId=p.value.pendingResultId};self.submitted=p.value.id end
 local draft=self.resultDraft
 if not p and self.page~="migration"and self.state.pendingHueResult and draft and draft.id==self.state.pendingHueResult.id then
  self.page="palette";self.petId=draft.petId;self.channel=draft.channel;self.tab=draft.tab
  self.confirmation=if draft.confirmation then table.clone(draft.confirmation)else nil
  self.assignment=if draft.assignment then table.clone(draft.assignment)else nil;self.selectTarget=self.tab=="pet"
 end
 if not self.machine and self.equipTargetId and not self.confirmation and self.page=="palette"then
  if self.equipTargetId==self:activePet()then self.petId=self.equipTargetId;self.equipTargetId=nil;self.machineSwitching=nil
  else self.confirmation={equipPetId=self.equipTargetId};self.machineSwitching=nil end
 end
 if self.page=="palette"and not self:canCustomize()and not self:hasReceiptAssignment()then return false end
 self.lifecycleEpoch=(self.lifecycleEpoch or 0)+1;self.previousSelection=GuiService.SelectedObject;self.epoch+=1;self.shade:SetAttribute("ControllerEpoch",self.epoch);self.shade.Visible=true;self:refresh()
 -- QA Q2.2: opened from the Companions hub, the page slides in from the right (Pets move).
 local from=self.slideFrom;self.slideFrom=nil
 if from and self:chromeActive()and self.chromeBody then Kit.slideIn(self.chromeBody,from,Kit.headerSkip(self.header))end
 return true
end
function View:close(reason)
 self.fruitEating:cancel();self.eatingProof:cancel();self.eatingReady=nil;self.boundedEating=nil
 self:stopPortraitClock()
 if not self.shade.Visible then return end
 if reason=="back"then
  if self.confirmation and not self.machineSwitching then self:cancelConfirmation();return false end
  if self.machine and self.machineSwitching then self.closeAfterEquip=true;return false end
  if self.machine then
   if self.exitPending then return false end
   if self.options.dismissMachine then
    self.exitPending=true;self.exitMessage="Taking your companion…";self:refresh()
    local binding=self:machineBinding()
    local started=self.options.dismissMachine(binding,function(packet)
     if self.destroyed or not self.machine or binding.epoch~=self.machineEpoch or binding.claimId~=self.machine.claimId then return end
     self.exitPending=nil
     if packet.status=="Accepted"or packet.status=="Saved"then self:close("picked-up")
     else self.exitMessage="Could not take your companion. Press × to retry.";self:refresh()end
    end)
    if not started then self.exitPending=nil;self.exitMessage="Wait for your companion, then press × to retry.";self:refresh()end
    return false
   end
  end
 end
 self.exitPending=nil;self.exitMessage=nil;self.closeAfterEquip=nil
 self.materialAssignment=nil
 if not self.machine then self.machineSwitching=nil end
 local pendingId=if self.assignment then self.assignment.pendingResultId elseif self.confirmation then self.confirmation.pendingResultId else nil
 if pendingId then self.resultDraft={id=pendingId,petId=self.petId,channel=self.channel,tab=self.tab,assignment=if self.assignment then table.clone(self.assignment)else nil,confirmation=if self.confirmation then table.clone(self.confirmation)else nil}end
 self.lifecycleEpoch=(self.lifecycleEpoch or 0)+1
 self:retireTransientArt(true);self.purchaseInFlight=nil;self.shade.Visible=false;Kit.shadeClose(self);self.epoch+=1;self.shade:SetAttribute("ControllerEpoch",self.epoch)
 if self.chromePanel then self.chromePanel.Visible=true end
 self.materialPanel.reveal:clear();self.materialPurchaseInFlight=nil
 self.toyPanel.reveal:clear();self.toyPurchaseInFlight=nil;self.featurePanel.reveal:clear();self.featurePurchaseInFlight=nil
 self:updateGrid(0)
 if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.shade)then GuiService.SelectedObject=nil end
 if self.options.closed then self.options.closed(reason)end
end
function View:ensure(target)
 if not target:IsDescendantOf(self.body)then return end
 local y=target.AbsolutePosition.Y-self.body.AbsolutePosition.Y+self.body.CanvasPosition.Y;local scroll=self.body.CanvasPosition.Y;local h=self.body.Size.Y.Offset
 if y<scroll then scroll=y elseif y+target.AbsoluteSize.Y>scroll+h then scroll=y+target.AbsoluteSize.Y-h end
 self.body.CanvasPosition=Vector2.new(0,math.clamp(scroll,0,math.max(0,self.body.CanvasSize.Y.Offset-h)))
end
function View:getControllerFocus()
 if not self.shade.Visible then return nil end
 -- The Customize chrome owns its own focus (ContextAction, like the Wardrobe).
 if self:chromeActive()then return nil end
 return {root=self.shade,epoch=self.epoch,target=function()return if self.confirmation then self.cancel elseif self.action.Visible and self.action.Interactable then self.action else self.targets[self:activePet()or ""]or self.closeButton end,fallback=self.closeButton,ensure=function(n)self:ensure(n)end}
end
function View:destroy(fromSignal)
 if self.destroyed then return end
 if self.materialPanel then self.materialPanel:destroy()end
 if self.destroyed then return end;self.destroyed=true;self:stopPortraitClock();self.itemReveal:destroy();self.materialPanel:destroy();self.toyPanel:destroy();self.featurePanel:destroy();if self.chromeRoot then self.chromeRoot:Destroy()end;self.fruitEating:destroy();for _,entry in pairs(self.gridPreviews)do if entry.visual then entry.visual:destroy();entry.visual=nil end end;if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.shade)then GuiService.SelectedObject=nil end;if self.visual then self.visual:destroy();self.visual=nil end;if not fromSignal then self.shade:Destroy()end
end
return View
