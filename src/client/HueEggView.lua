-- Pet-specific customization and saved item receipts. A fixed editor shell with bounded owned live previews.
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
 self.charmTab=button(card,"CharmTab","Charm",function()self:setTab("charm")end)
 self.hueTab=button(card,"HueTab","Hue",function()self:setTab("hue")end)
 self.petTab=button(card,"PetTab","Pet",function()self:setTab("pet")end)
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
 self.petName=text(card,"PetName","Zivvi","Action");self.petName.TextXAlignment=Enum.TextXAlignment.Center
 self.channelTitle=text(body,"ChannelTitle","Main · saved doses","Action")
 self.inspection=text(body,"HueInspection","Inspect a swatch. Use a jar only for the next dose.","Body")
 for _,id in ipairs(ids)do if id~="reset"then
  local row=Art.frame(body,"Dose_"..id,"inset",UDim2.fromOffset(0,0),UDim2.fromOffset(200,44),23);Art.corner(row,8)
  local label=text(row,"Label",names[id],"Body");local value=text(row,"Count","0/5","Counter");value.TextXAlignment=Enum.TextXAlignment.Right
  local ticks={};for notch=1,5 do
   local stage=notch
   local tick=button(row,"Notch"..notch,tostring(notch),function()self:inspectHue(id,stage)end)
   tick:SetAttribute("SwatchColor",Hues.ById[id].color)
   Art.bind(tick,{BackgroundColor3=function()return tick:GetAttribute("SwatchColor")end,TextColor3=function()return tick:GetAttribute("SwatchInk")or Art.Ink end})
   for _,child in ipairs(tick:GetChildren())do if child:IsA("UIGradient")then child:Destroy()end end
   tick.SelectionGained:Connect(function()if self.shade.Visible and self.tab=="hue"and not self.confirmation then self:inspectHue(id,stage)end end)
   local mark=Art.frame(tick,"SavedMark",Art.Ink,UDim2.new(.5,-12,1,-5),UDim2.fromOffset(24,3),tick.ZIndex+1);mark.BackgroundTransparency=1;mark.Active=false;mark.Selectable=false
   local check=Art.frame(tick,"SavedCheck",Art.Ink,UDim2.fromOffset(3,7),UDim2.fromOffset(12,9),tick.ZIndex+1);check.BackgroundTransparency=1;check.Active=false;check.Selectable=false
   local a=Art.frame(check,"A",Art.Ink,UDim2.fromOffset(0,3),UDim2.fromOffset(5,2),check.ZIndex);a.Rotation=45
   local b=Art.frame(check,"B",Art.Ink,UDim2.fromOffset(3,2),UDim2.fromOffset(9,2),check.ZIndex);b.Rotation=-45
   a.Visible=false;b.Visible=false
   ticks[notch]=tick
  end
  self.bars[id]={row=row,label=label,value=value,ticks=ticks}
 end end
 self.inventoryTitle=text(body,"InventoryTitle","Your jars","Action")
 for _,id in ipairs(ids)do
  local n=button(body,"Item_"..id,"",function()self:chooseItem(id)end)
  local art=JarArt.create(n,id,UDim2.fromOffset(6,4),UDim2.fromOffset(44,52),n.ZIndex+1)
  local label=text(n,"ItemName",names[id],"Body");local quantity=text(n,"Quantity","×0","Counter");local reason=text(n,"Reason","","Supporting")
  self.jars[id]={button=n,art=art,label=label,quantity=quantity,reason=reason}
 end
 self.empty=text(body,"EmptyInventory","No jars yet. Find fixed-color fruit in Hue Eggs.","Body")
 self.charmTitle=text(body,"CharmTitle","A floating Dot, colored by Secondary.","Body")
 self.charmToggle=button(card,"ShowCharm","Charm On",function()if not self.intent.pending then self:requestCharm(true)end end)
 self.charmOff=button(card,"HideCharm","Charm Off",function()if not self.intent.pending then self:requestCharm(false)end end)
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
  local entry={button=node,viewport=viewport,world=world,camera=camera,caption=caption,active=active};self.gridPreviews[pet.id]=entry
  viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()if entry.visual and entry.fit then entry.fit()end end)
 end
 self.dot=self.shapes.dot
 self.receiptArt=Art.frame(body,"ResultJar","inset",UDim2.fromOffset(0,0),UDim2.fromOffset(150,160),23);self.receiptArt.BackgroundTransparency=1
 self.itemReveal=ItemReveal.new(self.receiptArt,{audio=self.options.audio,reduceEffects=self.options.reduceEffects})
 self.receipt=text(body,"SavedReceipt","","Reward");self.receipt.TextXAlignment=Enum.TextXAlignment.Center
 self.receiptDetail=text(body,"ReceiptDetail","Already saved in your inventory.","Body")
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
function View:owned(id)return Eggs.isOwned(self.state.inventoryMask or 0,id)end
function View:counts()local p=self.state.petHues and self.state.petHues[self.petId];return countsCopy(p and p[self.channel])end
function View:appearance()
 local appearance=table.clone(self.options.appearance and self.options.appearance(self.petId)or {})
 local p=self.state.petHues and self.state.petHues[self.petId]
 if p then appearance.mainDoses=countsCopy(p.main);appearance.secondaryDoses=countsCopy(p.secondary)end
 return appearance
end
function View:activePet()return if self.machine then self.machine.petId elseif self.options.activePet then self.options.activePet()else self.state.companionId or self.petId end
function View:choosePet(id)
 if self.intent.pending or self.machineSwitching or not self:owned(id)or not Hues.Supported[id]then return false end
 if self.assignment then
  self.petId=id;self.inspected=nil;self.selectTarget=false;self.tab="hue";self:refresh();return true
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
 if self.intent.pending or(channel~="main"and channel~="secondary")then return false end;self.scrollPositions[self.tab..":"..self.channel]=self.body.CanvasPosition;self.channel=channel;self.inspected=nil
 if self.confirmation then self.confirmation.channel=channel end;self:refresh();self.body.CanvasPosition=self.scrollPositions[self.tab..":"..self.channel]or Vector2.zero;return true
end
function View:setTab(tab)
 if self.intent.pending or self.confirmation or self.assignment or(tab~="pet"and tab~="hue"and tab~="charm")then return false end
 self.scrollPositions[self.tab..":"..self.channel]=self.body.CanvasPosition
 self.tab=tab;self.inspected=nil;self:refresh()
 self.body.CanvasPosition=self.scrollPositions[self.tab..":"..self.channel]or Vector2.zero;return true
end
function View:inspectHue(id,stage)
 if not self.shade.Visible or self.page~="palette"or self.tab~="hue"or self.confirmation or self.intent.pending then return false end
 local color=Swatches.at(self.petId,self:appearance(),self.channel,id,stage);if not color then return false end
 self.inspected={id=id,stage=stage,petId=self.petId,channel=self.channel}
 self:paintSwatches(true);self:layout();return true
end
function View:compactSwatches()
 local size=self.shade.AbsoluteSize;local pad=if size.Y<280 then 8 else 16
 return self.page=="palette"and self.tab=="hue"and not self.confirmation and not self.assignment and size.Y<420 and math.min(640,size.X-16)-pad*2>=560
end
function View:paintSwatches(visible)
 local counts=self:counts();local appearance=self:appearance()
 local compact=self:compactSwatches();local detail="Inspect a swatch. Use a jar only for the next dose."
 self.inspection.Visible=visible
 self.inspection.Text=if compact and self.machine then "Tap a swatch."elseif compact then "Tap a swatch to preview."else detail
 for id,bar in pairs(self.bars)do
  bar.row.Visible=visible;bar.value.Text=tostring(counts[id]).."/5"
  for stage,tick in ipairs(bar.ticks)do
   local color=Swatches.at(self.petId,appearance,self.channel,id,stage)
   local inspected=self.inspected and self.inspected.petId==self.petId and self.inspected.channel==self.channel and self.inspected.id==id and self.inspected.stage==stage
   tick:SetAttribute("SwatchColor",color);tick.BackgroundColor3=color;tick.BackgroundTransparency=0;tick:SetAttribute("Filled",stage<=counts[id]);tick:SetAttribute("SavedStage",stage==counts[id]);tick:SetAttribute("Inspected",inspected==true)
   tick:SetAttribute("AccessibleLabel",names[id].." stage "..stage..(if stage==counts[id]then " · Saved"else " · Unapplied preview"))
   -- Clear keyline on Citrus and Ink; saved stage and inspection are independent.
   local stroke=tick:FindFirstChildWhichIsA("UIStroke")
   if stroke then stroke.Color=if inspected then Color3.fromHex("#008EA8")elseif stage==counts[id]then Art.Ink else Color3.fromHex("#647F87");stroke.Thickness=if inspected or stage==counts[id]then 3 else 1;stroke.Transparency=0 end
   tick.TextColor3=swatchInk(color)
   tick:SetAttribute("SwatchInk",tick.TextColor3)
   tick.Text=tostring(stage)
   for _,part in ipairs(tick.SavedCheck:GetChildren())do part.Visible=stage==counts[id];part.BackgroundColor3=tick.TextColor3 end
   tick.SavedMark.BackgroundColor3=Art.Ink;tick.SavedMark.BackgroundTransparency=if stage<=counts[id]then 0 else 1
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
 Art.type(bar.label,"Action");Art.type(bar.value,"Counter")
 local valueW=math.max(54,Art.textWidth(bar.value)+4)
 local header=math.max(Art.textHeight(bar.label,width-valueW-24,22),Art.textHeight(bar.value,valueW,22))
 local columns=math.clamp(math.floor((width-12)/48),1,5)
 local cell=(width-16-(columns-1)*4)/columns;local rows=math.ceil(5/columns)
 local gap=if compactSpacing then 4 else 8
 local height=header+rows*44+(rows-1)*4+(if compactSpacing then 12 else 16)
 place(bar.row,x,y,width,height);place(bar.label,8,3,width-valueW-24,header);place(bar.value,width-valueW-8,3,valueW,header)
 for i,tick in ipairs(bar.ticks)do Art.type(tick,"Counter");place(tick,8+((i-1)%columns)*(cell+4),header+gap+math.floor((i-1)/columns)*48,cell,44)end
 return height
end
function View:reason(id)
 local count=(self.state.hueInventory or {})[id]or 0
 if count<1 then return "No jars"end
 if not self:owned(self.petId)then return "Choose an owned pet"end
 local c=self:counts()
 if id=="reset"then return if nonzero(c)then nil else "Already original"end
 return if c[id]>=5 then "Already 5/5"else nil
end
function View:chooseItem(id)
 if self.intent.pending or self:reason(id)then return false end
 local r=self.state.pendingHueResult
 if r then self.page="receipt";self.confirmation=nil;self:refresh();return false end
 self.confirmReturn={scroll=self.body.CanvasPosition,target=self.jars[id].button};self.confirmation={itemId=id,petId=self.petId,channel=self.channel};self.body.CanvasPosition=Vector2.zero;self.epoch+=1;self:refresh();return true
end
function View:useResult()
 self.itemReveal:cancel()
 local r=self.state.pendingHueResult;if not r or self.intent.pending then return false end
 self.page="palette";self.tab="pet";self.selectTarget=true;self.body.CanvasPosition=Vector2.zero;self.epoch+=1
 self.assignment={itemId=r.itemId,pendingResultId=r.id};self.confirmation=nil;self:refresh();return true
end
function View:requestLegacy(id)
 if self.intent.pending then return false end
 self.confirmation={legacyItem=id};self:refresh();return true
end
function View:cancelConfirmation()
 if self.intent.pending then return false end
 local pendingResult=self.confirmation and self.confirmation.pendingResultId
 self.confirmation=nil;self.selectTarget=false;if pendingResult then self.page="receipt";self.resultDraft=nil end;self:refresh();if self.confirmReturn then self.body.CanvasPosition=self.confirmReturn.scroll;GuiService.SelectedObject=self.confirmReturn.target;self.confirmReturn=nil end;self.epoch+=1;return true
end
function View:shapeSelectionsEnabled()
 local remotes=game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
 return if self.options.shapeSelectionsEnabled then self.options.shapeSelectionsEnabled()==true else CharmCatalog.SelectionsEnabled==true and remotes~=nil and(remotes:GetAttribute("PetCharmVersion")or 0)>=CharmCatalog.Version
end
function View:requestCharm(visible,shape)
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
 local captured=pending
 task.delay(2,function()
  if self.destroyed or self.charmRequests[id]~=captured then return end
  captured.retry=true;self:refresh()
 end)
 self:refresh();return true
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
  self.charmRequests[packet.petId]=nil;self.charmMessage="Charm saved"
 elseif packet.status=="Rejected"then
  self.charmRequests[packet.petId]=nil;self.charmMessage="Charm was not saved. Try again."
 elseif packet.status~="Applied"then return false end
 if self.petId==packet.petId then self:refresh()end;return true
end
function View:activate()
 if not self.shade.Visible or not self.action.Visible or not self.action.Interactable then return false end
 self.itemReveal:cancel()
 if self.intent.status=="Retrying"then return self.intent:retry()end
 local q=self.confirmation
 if self.page=="migration"then
  local ok=self.intent:ackMigration();if ok then self.migrationOperation=self.intent.pending.value.id end;return ok
 elseif self.assignment and not q then
  local assignment=self.assignment
  self.confirmation={itemId=assignment.itemId,petId=self.petId,channel=self.channel,pendingResultId=assignment.pendingResultId}
  self.assignment=nil;self.selectTarget=false;self.body.CanvasPosition=Vector2.zero;self.epoch+=1;self:refresh();return true
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
  else ok=self.intent:use(self.petId,self.channel,q.itemId,q.pendingResultId)end
  if ok then self.submitted=self.intent.pending.value.id end;return ok
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
 local key=tostring(self.viewport.AbsoluteSize)..":"..tostring(self.visual.rigRevision or 0)..":"..tostring(self.visual.charmVisible)..":"..tostring(self.visual.renderCharmShape)..":"..tostring(self.visual)
 if self.portraitCameraKey==key then return end;self.portraitCameraKey=key
 local box,size=Bounds.get(self.visual);local a=math.max(.1,self.viewport.AbsoluteSize.X/math.max(1,self.viewport.AbsoluteSize.Y));local half=math.tan(math.rad(self.camera.FieldOfView/2))
 local distance=math.max(size.Y*.5/half,size.X*.5/(half*a))+size.Z*.5+.3
 local center=box.Position;self.camera.CFrame=CFrame.lookAt(center+Vector3.new(0,.12,distance*1.10),center)
end
function View:paintPortrait()
 if not self.portrait.Visible then return end
 local a=self:appearance();local key=self.petId
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
 end)
end
function View:refresh()
 self.state=self.intent.state or self.state
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
 if r and self.page=="buy"then self.page="receipt"end
 if self.page=="receipt"and not r then self.page="palette"end
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
 self.title.Text=if migration then "Your converted colors"elseif self.assignment then "Choose where to use"elseif confirming then if self.confirmation.itemId=="reset"then "Reset "..channelName(self.channel).." color?"elseif self.confirmation.itemId then "Use "..names[self.confirmation.itemId].."?"else "Confirm choice"elseif self.page=="receipt"then "A jar for your garden"elseif self.page=="buy"then "Hue Egg"else "Companions"
 self.title:SetAttribute("AccessibleLabel",if customization then "Customize "..Pets.byId[self.petId].name else self.title.Text)
 if self.confirmation and self.confirmation.equipPetId then self.title.Text="Make "..Pets.byId[self.confirmation.equipPetId].name.." active?"end
 self.wallet.Text=tostring(self.state.nectar or 0).." Stars"
 local function visible(n,value)n.Visible=value end
 for _,n in ipairs({self.petTab,self.charmTab,self.hueTab})do visible(n,customization and not confirming)end
 for _,n in ipairs({self.portrait,self.petName})do visible(n,customization and self.tab~="pet"and not confirming)end
 for _,n in ipairs({self.mainTab,self.secondaryTab,self.channelTitle,self.inventoryTitle})do visible(n,hue and not confirming)end
 if self.assignment then self.inventoryTitle.Visible=false end
 self.mainTab.Visible=hue and not confirming;self.secondaryTab.Visible=hue and not confirming;self.targetChange.Visible=false;self.targetTitle.Visible=customization and not confirming and(self.tab=="pet"or self.selectTarget==true)
 self.machinePickup.Visible=false;self.machineSetDown.Visible=false;self.wallet.Visible=false
 for id,n in pairs(self.targets)do n.Visible=customization and not confirming and (self.tab=="pet"or self.selectTarget==true)and self:owned(id);n.Interactable=not self.intent.pending;Art.tab(n,id==self:activePet(),n.Interactable)
  local preview=self.gridPreviews[id];preview.active.Text=if id==self:activePet()then "✓ Active"elseif self.assignment and id==self.petId then "✓ Recipient"else "";n:SetAttribute("AccessibleLabel",Pets.byId[id].name.." · "..(if id==self:activePet()then "Active"elseif self.assignment then "Choose jar recipient"else "Make active"))end
 Art.tab(self.petTab,self.tab=="pet",not self.intent.pending);Art.tab(self.charmTab,self.tab=="charm",not self.intent.pending);Art.tab(self.hueTab,self.tab=="hue",not self.intent.pending)
 Art.tab(self.mainTab,self.channel=="main",not self.intent.pending);Art.tab(self.secondaryTab,self.channel=="secondary",not self.intent.pending)
 self.targetChange.Text=Pets.byId[self.petId].name.." · Change pet";self.petName.Text=Pets.byId[self.petId].name;self.channelTitle.Text=channelName(self.channel).." · saved doses"
 local counts=self:counts();local stock=0
 self:paintSwatches(hue and not confirming)
 for _,id in ipairs(ids)do local j=self.jars[id];local quantity=(self.state.hueInventory or {})[id]or 0;stock+=quantity
  j.button.Visible=hue and not confirming and not self.assignment and quantity>0;j.quantity.Text="×"..quantity;j.reason.Text=self:reason(id)or "Choose to use";j.button.Interactable=not self.intent.pending and self:reason(id)==nil and not confirming
  j.button:SetAttribute("DisabledReason",self:reason(id));Art.control(j.button,false,j.button.Interactable)
 end
 self.empty.Visible=hue and not confirming and not self.assignment and stock==0
 self.charmTitle.Visible=charm and not confirming;self.charmToggle.Visible=charm and not confirming;self.charmOff.Visible=self.charmToggle.Visible
 local a=self:appearance();local charmPending=self.charmRequests[self.petId]
 self.charmToggle.Text=if charmPending and charmPending.retry then "Retry save"elseif charmPending then "Saving…"else "Charm On"
 self.charmToggle.Interactable=not charmPending or charmPending.retry==true;self.charmOff.Interactable=self.charmToggle.Interactable
 Art.tab(self.charmToggle,a.charmVisible~=false,self.charmToggle.Interactable);Art.tab(self.charmOff,a.charmVisible==false,self.charmOff.Interactable)
 local known=CharmCatalog.known(a.charmShape or "dot");local enabled=self:shapeSelectionsEnabled()
 self.charmTitle.Text=if known then "A floating "..CharmCatalog.ById[a.charmShape or "dot"].name..", colored by Secondary."else "Your saved charm uses a Dot here. Its original shape is preserved."
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
  self.receipt.Text=names[r.itemId].." · "..tostring((self.state.hueInventory or {})[r.itemId]or r.inventoryAfter or 1).." in inventory"
  self.itemReveal:show(r,self.purchaseInFlight==r.id);self.purchaseInFlight=nil
 end
 self.legacyTitle.Visible=self.state.legacyHueEgg~=nil and not confirming and self.tab=="hue"
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
 elseif self.assignment then self.quote.Text="Choose a pet and channel for "..names[self.assignment.itemId]..". Review the exact change before using one jar."
 elseif self.page=="buy"then self.quote.Text="8 Stars · one saved jar\nRose fruit 20% · Tide fruit 20% · Citrus fruit 20% · Iris fruit 20% · Reset Hue 20%\nReset clears one channel. Store any result. Duplicate jars stack."end
 local decision=confirming and q.itemId~=nil
 for _,node in ipairs({self.confirmTarget,self.confirmDelta,self.confirmStock,self.confirmWarning})do node.Visible=decision end
 if decision then
  local lines=string.split(self.quote.Text,"\n")
  self.confirmTarget.Text=lines[1];self.confirmTarget:SetAttribute("AccessibleLabel",self.quote.Text)
  self.confirmDelta.Text=if q.itemId=="reset"then "Restore "..(if self.channel=="main"then "white Main"else "grey Secondary")else lines[3]or ""
  self.confirmStock.Text=tostring((self.state.hueInventory or {})[q.itemId]or 0).." jars → "..math.max(0,((self.state.hueInventory or {})[q.itemId]or 0)-1)
  self.confirmWarning.Text=if q.itemId=="reset"then lines[3]or ""else lines[5]or ""
  self.confirmWarning.Visible=self.confirmWarning.Text~="";self.quote.Visible=false
 end
 self.presetTitle.Visible=false
 for _,n in pairs(self.presetButtons)do n.Visible=false end
 local presets=self.state.legacyHuePresets and self.state.legacyHuePresets[self.petId];local p=self.state.petHues and self.state.petHues[self.petId]
 if hue and not confirming and presets and not(p and p.legacyLocked and p.legacyLocked[self.channel])then
  for _,preset in ipairs(presets[self.channel]or {})do
   self.presetTitle.Visible=true;local id=preset.id;local n=self.presetButtons[id]
   if not n then n=button(self.body,"Preset_"..id,preset.name,function()self.confirmation={presetId=id,name=preset.name};self:refresh()end);self.presetButtons[id]=n end
   n.Visible=true;n.Interactable=not self.intent.pending
  end
 end
 self.status.Text=if self.exitMessage then self.exitMessage elseif self.saveNotice then self.saveNotice.detail elseif self.charmMessage and charm then self.charmMessage else self.intent.message or "";self.status.Visible=self.status.Text~=""
 self.action.Visible=migration or self.assignment~=nil or confirming or self.page=="receipt"or self.page=="buy"or self.intent.status=="Retrying"
 self.cancel.Visible=confirming
 self.action.Text=if migration and not self.intent.pending then "Continue"elseif self.intent.status=="Retrying"then "Retry save"elseif self.intent.pending then "Saving…"elseif confirming then if q.itemId=="reset"then "Reset "..channelName(self.channel)elseif q.itemId then "Use one"else "Confirm"elseif self.assignment then "Review jar for "..Pets.byId[self.petId].name elseif self.page=="receipt"then "Store"elseif self.page=="buy"then "Back to Hue Egg"else ""
 local reason=(q and q.itemId and self:reason(q.itemId))or(self.assignment and self:reason(self.assignment.itemId))
 self.action.Interactable=self.action.Visible and(not self.assignment or self.tab~="pet")and(if self.intent.status=="Retrying"then true else not self.intent.pending and not reason and self.intent:ready(if confirming and not q.legacyItem then self.petId else nil))
 self.cancel.Interactable=not self.intent.pending;self.useNow.Interactable=not self.intent.pending
 if self.confirmation and self.confirmation.equipPetId then self.action.Text=if self.machineSwitching then "Saving…"else "Make active";self.action.Interactable=not self.machineSwitching end
 Art.control(self.action,true,self.action.Interactable);Art.control(self.cancel,false,self.cancel.Interactable)
 self.targetTitle.Text=if self.assignment then "Choose the recipient for "..names[self.assignment.itemId]else "Your companions"
 local hasOwned=false;for id in pairs(self.targets)do if self:owned(id)then hasOwned=true;break end end
 self.targetTitle.Visible=customization and not confirming and self.tab=="pet"and(self.assignment~=nil or not hasOwned)
 self.eggsButton.Visible=customization and self.tab=="pet"and not confirming
 if not hasOwned and self.targetTitle.Visible then self.targetTitle.Text="No companions yet. Hatch a Companion Egg."end
 self:layout();self:updateGrid(0);self:paintPortrait();self:syncPortraitClock()
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
    local key=id..":"..game:GetService("HttpService"):JSONEncode(appearance)
    if key~=entry.key then
    if entry.visual then entry.visual:destroy()end
    entry.key=key;entry.geometry=nil;entry.visual=Factory.new(entry.world,Vector3.zero,Pets.byId[id],nil,appearance)
    local visual=entry.visual
    local function fit()
     if entry.visual~=visual or visual.destroyed then return end
     local geometry=tostring(entry.viewport.AbsoluteSize)..":"..tostring(visual.rigRevision)
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
function View:layout()
 if self.page~="palette"or self.confirmation then
  for _,node in ipairs({self.petTab,self.charmTab,self.hueTab,self.portrait,self.petName,self.mainTab,self.secondaryTab,self.charmToggle,self.charmOff})do
   if node==self.petTab or node==self.charmOff then node.Visible=false else node.Parent=self.body end
  end
  self:layoutTransaction();return
 end
 if self.layingOut then return end;self.layingOut=true
 local size=self.shade.AbsoluteSize;local short=size.Y<220;local pad=if short then 4 else 12
 local width=math.max(1,math.min(900,size.X-16));local height=math.max(1,math.min(760,size.Y-16));self.card.Size=UDim2.fromOffset(width,height)
 local w=width-pad*2
 self.wallet.Visible=false;self.targetChange.Visible=false;self.machinePickup.Visible=false;self.machineSetDown.Visible=false
 local roomy=height>=420 and width>=600
 local function style(node,role)Art.roomyType(node,role,false,roomy)end
 self.title.Text=if self.assignment then "Jar recipient"else "Companions";style(self.title,if short then "Action"else "Heading")
 local titleH=math.max(44,Art.textHeight(self.title,w-52,24)+4)
 place(self.title,pad,0,w-52,titleH);place(self.closeButton,width-pad-44,0,44,44)
 local tabs={self.petTab,self.hueTab,self.charmTab};local tabW=(w-8)/3;local tabH=44
 for _,node in ipairs(tabs)do node.Parent=self.card;style(node,"Action");tabH=math.max(tabH,Art.actionHeight(node,tabW))end
 for i,node in ipairs(tabs)do place(node,pad+(i-1)*(tabW+4),titleH,tabW,tabH)end
 local contentTop=titleH+tabH+4;local footer=0
 if self.action.Visible then Art.type(self.action,"Action",true);footer=math.max(44,Art.actionHeight(self.action,w))+4;place(self.action,pad,height-footer,w,footer-4)end
 local available=math.max(1,height-contentTop-footer-pad)
 local grid=self.tab=="pet";local columns=not grid and w>=500
 self.petName.Visible=not grid
 local rail=if short and columns then math.min(356,w*.68)elseif columns then math.max(260,math.min(310,math.floor(w*.40)))else w
 local listX,listY,listW,listH=pad,contentTop,w,available
 for _,node in ipairs({self.portrait,self.petName,self.mainTab,self.secondaryTab,self.charmToggle,self.charmOff})do node.Parent=self.card end
 if not grid then
  local controls=if self.tab=="hue"then {self.mainTab,self.secondaryTab}else {self.charmToggle,self.charmOff}
  for _,node in ipairs(controls)do style(node,"Action")end
  if short and columns then
   rail=math.min(w-112,math.max(rail,72+2*(math.max(Art.textWidth(controls[1]),Art.textWidth(controls[2]))+16)))
  end
  local half=(rail-4)/2;local controlH=44
  for _,node in ipairs(controls)do controlH=math.max(controlH,Art.actionHeight(node,half))end
  style(self.petName,"Action");local nameH=Art.textHeight(self.petName,rail,22)
  local previewH=if columns then math.max(1,available-nameH-controlH-8)else math.min(160,math.max(60,available*.36))
  previewH=math.min(previewH,260)
  -- At 160px landscape the compact pet sits alongside the control/name stack.
  if short and columns then
   local previewW=60;previewH=available
   self.title.Text=Pets.byId[self.petId].name.." · "..(if self.tab=="hue"then "Hue"else "Charm")
   self.petName.Visible=false
   place(self.portrait,pad,contentTop,previewW,previewH)
   local cw=(rail-previewW-8)/2
   for i,node in ipairs(controls)do place(node,pad+previewW+4+(i-1)*(cw+4),contentTop,cw,44)end
  else
   place(self.portrait,pad,contentTop,rail,previewH)
   place(self.petName,pad,contentTop+previewH+2,rail,nameH)
   for i,node in ipairs(controls)do place(node,pad+(i-1)*(half+4),contentTop+previewH+nameH+4,half,controlH)end
  end
  if columns then listX,listW=pad+rail+12,w-rail-12
  else local fixed=previewH+nameH+controlH+10;listY=contentTop+fixed;listH=math.max(1,available-fixed)end
 end
 place(self.body,listX,listY,listW,listH)
 local y=0
 local function copy(node)
  if not node.Visible then return end
  style(node,node:GetAttribute("TypeRole")or "Body");local h=Art.textHeight(node,listW-8,22);place(node,4,y,listW-8,h);y+=h+8
 end
 local function action(node)
  if not node.Visible then return end
  Art.type(node,"Action",true);local h=math.max(44,Art.actionHeight(node,listW-8));place(node,4,y,listW-8,h);y+=h+8
 end
 copy(self.targetTitle)
 if grid then
  copy(self.quote)
  local count=math.max(1,math.floor((listW+8)/156));local cell=(listW-(count-1)*8-8)/count;local index=0
  if height<420 then
   local minimum=44
   for _,entry in pairs(self.gridPreviews)do if entry.button.Visible then
    style(entry.caption,"Action");style(entry.active,"Supporting")
    minimum=math.max(minimum,44+Art.textHeight(entry.caption,cell-8,22)+Art.textHeight(entry.active,cell-8,20)+10)
   end end
   cell=math.min(cell,math.max(minimum,listH-8));count=math.max(1,math.floor((listW+4)/(cell+8)))
  end
  for _,pet in ipairs(Pets.collection)do local entry=self.gridPreviews[pet.id]
   if entry.button.Visible then
    local x=4+(index%count)*(cell+8);local row=math.floor(index/count);place(entry.button,x,y+row*(cell+8),cell,cell)
    style(entry.caption,"Action");style(entry.active,"Supporting")
    local nh=Art.textHeight(entry.caption,cell-8,22);local ah=Art.textHeight(entry.active,cell-8,20)
    place(entry.viewport,4,4,cell-8,math.max(1,cell-nh-ah-10));place(entry.caption,4,cell-nh-ah-4,cell-8,nh);place(entry.active,4,cell-ah-2,cell-8,ah)
    index+=1
   end
  end
  y+=math.ceil(index/count)*(cell+8);action(self.eggsButton)
 else
  copy(self.channelTitle);copy(self.inspection)
  for _,id in ipairs(ids)do local bar=self.bars[id];if bar and bar.row.Visible then y+=layoutBar(bar,4,y,listW-8)+8 end end
  copy(self.charmTitle)
  for _,id in ipairs(CharmCatalog.Order)do local node=self.shapes[id]
   if node.Visible then
    local icon=self.shapeIcons[id];style(icon.label,"Action");style(icon.check,"Action")
    -- The row's input owner has no text or content padding. Each illustrated
    -- seat owns an explicit measured rectangle, including Largest text.
    local rowW=listW-8;local checkW=math.max(24,Art.textWidth(icon.check)+4)
    local labelX=68;local labelW=math.max(1,rowW-labelX-checkW-24)
    local stacked=labelW<math.min(Art.textWidth(icon.label)+2,72)
    if stacked then labelX,labelW=12,math.max(1,rowW-24)end
    local labelH=Art.textHeight(icon.label,labelW,24);local checkH=Art.textHeight(icon.check,checkW,24)
    local h=if stacked then 68+labelH+12 else math.max(68,labelH+24)
    place(node,4,y,rowW,h)
    place(icon.tile,12,if stacked then 12 else (h-44)/2,44,44)
    place(icon.label,labelX,if stacked then 68 else (h-labelH)/2,labelW,labelH)
    place(icon.check,rowW-12-checkW,if stacked then 12 else (h-checkH)/2,checkW,checkH)
    y+=h+8
   end
  end
  copy(self.legacyTitle);for _,id in ipairs(ids)do if self.legacyButtons[id]then action(self.legacyButtons[id])end end
  copy(self.presetTitle);for _,node in pairs(self.presetButtons)do action(node)end
  copy(self.quote);copy(self.inventoryTitle);copy(self.empty)
  for _,id in ipairs(ids)do local jar=self.jars[id]
   if jar.button.Visible then
    local tw=math.max(1,listW-84);style(jar.label,"Body");style(jar.quantity,"Counter");style(jar.reason,"Supporting")
    local lh=Art.textHeight(jar.label,math.max(1,tw-40),22);local rh=Art.textHeight(jar.reason,tw,20);local h=math.max(72,lh+rh+14)
    place(jar.button,4,y,listW-8,h);place(jar.art,6,(h-52)/2,44,52);place(jar.label,60,5,math.max(1,tw-40),lh);place(jar.quantity,listW-56,5,36,lh);place(jar.reason,60,lh+7,tw,rh);y+=h+8
   end
  end
 end
 copy(self.status)
 self.body.CanvasSize=UDim2.fromOffset(0,y+4);self.body.ScrollingEnabled=y+4>listH
 self.body.CanvasPosition=Vector2.new(0,math.clamp(self.body.CanvasPosition.Y,0,math.max(0,y+4-listH)))
 self.layingOut=false;self:fitPortrait()
end
function View:layoutTransaction()
 if self.layingOut then return end;self.layingOut=true
 self.targetChange.Text=Pets.byId[self.petId].name.." · Change pet"
 self.targetChange:SetAttribute("AccessibleLabel","Change active pet · "..Pets.byId[self.petId].name)
 self.channelTitle.Visible=self.page=="palette"and self.tab=="hue"and not self.confirmation and not self:compactSwatches()
 self:paintSwatches(self.inspection.Visible)
 if self.portrait.Visible then self.petName.Visible=true end
 local size=self.shade.AbsoluteSize;local width=math.max(1,math.min(if self.confirmation and not(size.Y<280)then 470 else 640,size.X-16));local short=size.Y<280;local pad=if short then 8 else 16;local w=width-pad*2
 Art.type(self.title,if short then "Body"else "Heading",short);Art.type(self.wallet,"Counter",short)
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
 if self.action.Visible then Art.type(self.action,"Action",short);Art.type(self.cancel,"Action",short);footer=math.max(44,Art.actionHeight(self.action,if self.cancel.Visible then (w-8)/2 else w),if self.cancel.Visible then Art.actionHeight(self.cancel,(w-8)/2)else 44)+8 end
 if self.machinePickup.Visible then
  Art.type(self.machinePickup,"Action",short);Art.type(self.machineSetDown,"Action",short)
  footer=math.max(44,Art.actionHeight(self.machinePickup,(w-8)/2),Art.actionHeight(self.machineSetDown,(w-8)/2))+8
 end
 local height=math.max(1,math.min(if self.confirmation then 420 else 760,size.Y-16));self.card.Size=UDim2.fromOffset(width,height)
 local bodyH=math.max(1,height-header-footer-8);place(self.body,pad,header,w,bodyH)
 if self.cancel.Visible then place(self.cancel,pad,height-footer,(w-8)/2,footer-8);place(self.action,pad+(w+8)/2,height-footer,(w-8)/2,footer-8)else place(self.action,pad,height-footer,w,footer-8)end
 if self.machinePickup.Visible then place(self.machinePickup,pad,height-footer,(w-8)/2,footer-8);place(self.machineSetDown,pad+(w+8)/2,height-footer,(w-8)/2,footer-8)end
 if short and self.confirmation then
  local side=math.max(112,math.min(w*.45,math.max(Art.textWidth(self.action),Art.textWidth(self.cancel))+20));local gap=8;local fullW=w
  w=math.max(1,w-side-gap);bodyH=math.max(1,height-header-8)
  place(self.body,pad,header,w,bodyH)
  local ah=math.max(44,Art.actionHeight(self.action,side));local cancelH=math.max(44,Art.actionHeight(self.cancel,side))
  place(self.cancel,pad+fullW-side,header,side,cancelH);place(self.action,pad+fullW-side,header+cancelH+8,side,ah)
 end
 local y=0
 local function copy(n,min)if not n.Visible then return end;Art.type(n,n:GetAttribute("TypeRole")or "Body",short);local h=Art.textHeight(n,w-8,min or 24);place(n,4,y,w-8,h);y+=h+8 end
 local function row(nodes,cols)
  local live={};for _,n in ipairs(nodes)do if n.Visible then table.insert(live,n)end end;if #live==0 then return end
  local rw=(w-8-(cols-1)*8)/cols;local h=44
  for _,n in ipairs(live)do Art.type(n,"Action",short);h=math.max(h,Art.actionHeight(n,rw))end
  for i,n in ipairs(live)do place(n,4+((i-1)%cols)*(rw+8),y+math.floor((i-1)/cols)*(h+8),rw,h)end;y+=math.ceil(#live/cols)*(h+8)
 end
 copy(self.migrationText)
 if self.confirmation then
  local item=self.confirmation.itemId
  if self.confirmJar then self.confirmJar:Destroy();self.confirmJar=nil end
  if item then
   local inset=if w>=260 then 90 else 4
   self.confirmJar=JarArt.create(self.body,item,UDim2.fromOffset(4,0),UDim2.fromOffset(if inset>4 then 76 else 44,if inset>4 then 88 else 52),25)
   for _,entry in ipairs({{self.confirmTarget,"Action",20},{self.confirmDelta,"Action",18},{self.confirmStock,"Body",16}})do
    local node=entry[1];Art.type(node,entry[2],short);if not short then node.TextSize=entry[3]end
    local chip=if node==self.confirmDelta then 32 else 0;local tw=w-inset-4-chip;local h=Art.textHeight(node,tw,24)
    place(node,inset,y,tw,h)
    if node==self.confirmDelta then place(self.resultSwatch,w-30,y+(h-24)/2,24,24)end
    y+=h+6
   end
   y=math.max(if inset>4 then 92 else 56,y)
   copy(self.confirmWarning,24)
  else copy(self.quote,28)end
 elseif self.confirmJar then self.confirmJar:Destroy();self.confirmJar=nil end
 row({self.charmTab,self.hueTab},2)
 copy(self.targetTitle);local targets={};for _,pet in ipairs(Pets.collection)do table.insert(targets,self.targets[pet.id])end;row(targets,if w>=430 then 3 else 2)
 if self.targetChange.Visible then Art.type(self.targetChange,"Body",short);local tw=math.min(w-8,math.max(160,Art.textWidth(self.targetChange)+20));local th=math.max(44,Art.actionHeight(self.targetChange,tw));place(self.targetChange,4,y,tw,th);y+=th+8 end
 if self.receiptArt.Visible then place(self.receiptArt,(w-140)/2,y,140,160);y+=164 end
 copy(self.receipt,36);copy(self.receiptDetail);row({self.useNow},1)
 if self.portrait.Visible then local h=if short then 140 else 180;place(self.portrait,4,y,w-8,h);y+=h+4;copy(self.petName)end
 row({self.mainTab,self.secondaryTab},2);copy(self.channelTitle);copy(self.inspection)
 for _,id in ipairs(ids)do local b=self.bars[id];if b and b.row.Visible then
  y+=layoutBar(b,4,y,w-8)+6
 end end
 copy(self.charmTitle);row({self.charmToggle},1);local shapeButtons={};for _,id in ipairs(CharmCatalog.Order)do table.insert(shapeButtons,self.shapes[id])end;row(shapeButtons,3)
 copy(self.legacyTitle);local redemption={};for _,id in ipairs(ids)do if self.legacyButtons[id]then table.insert(redemption,self.legacyButtons[id])end end;row(redemption,2)
 copy(self.presetTitle);local presets={};for _,n in pairs(self.presetButtons)do table.insert(presets,n)end;table.sort(presets,function(a,b)return a.Name<b.Name end);row(presets,2)
 if not self.confirmation then copy(self.quote,28)end
 copy(self.status)
 -- Stock remains the last section; confirmation/footer stays reachable while it scrolls.
 copy(self.inventoryTitle);copy(self.empty)
 for _,id in ipairs(ids)do local j=self.jars[id];if j.button.Visible then
  Art.type(j.label,"Body",short);Art.type(j.quantity,"Counter",short);Art.type(j.reason,"Supporting",short)
  local textW=w-84;local lh=Art.textHeight(j.label,textW,22);local rh=Art.textHeight(j.reason,textW,18);local h=math.max(68,lh+rh+12)
  place(j.button,4,y,w-8,h);place(j.art,6,(h-52)/2,44,52);place(j.label,60,5,textW-40,lh);place(j.quantity,w-58,5,38,lh);place(j.reason,60,lh+7,textW,rh);y+=h+8
 end end
 -- Docked Charm shares the compact landscape composition; desktop stays as authored.
 local compactCharm=self.machine~=nil and self.tab=="charm"and height<420
 -- Roomy customization gives the saved pet its own generous column.
 if self.page=="palette"and(self.tab=="hue"or compactCharm)and not self.selectTarget and not self.confirmation and not self.assignment and w>=560 and(height>=500 or height<420)then
  local gap=16;local compactLandscape=height<420;local lw=math.floor(w*.40);local rx=lw+gap;local rw=w-rx-4;local tabH=math.max(self.charmTab.Size.Y.Offset,self.hueTab.Size.Y.Offset);local ly=tabH+8;local ry=tabH+8
  local compactMachineHue=self.machine~=nil and self.tab=="hue"and compactLandscape
  if compactMachineHue then ry=tabH+4 end
  if compactCharm then
   ly=0;local half=(rw-8)/2
   place(self.charmTab,rx,0,half,tabH);place(self.hueTab,rx+half+8,0,half,tabH)
   self.targetChange.Text="Change pet";self.targetChange:SetAttribute("AccessibleLabel","Change active pet · "..Pets.byId[self.petId].name)
  end
  local portraitH=if compactLandscape then 100 else 210
  if compactCharm then
   local changeH=math.max(44,Art.actionHeight(self.targetChange,lw-4))
   portraitH=math.min(100,math.max(96,bodyH-changeH-8));portraitH=math.min(portraitH,math.max(1,bodyH))
  end
  place(self.portrait,4,ly,lw-4,portraitH);ly+=portraitH+4
  self.petName.Text=Pets.byId[self.petId].name;self.petName.Visible=not compactLandscape
  if self.petName.Visible then Art.type(self.petName,"Action");local nh=Art.textHeight(self.petName,lw-4,24);place(self.petName,4,ly,lw-4,nh);ly+=nh+12 end
  if self.mainTab.Visible then
   local half=(lw-12)/2;local ch=math.max(44,Art.actionHeight(self.mainTab,half),Art.actionHeight(self.secondaryTab,half))
   place(self.mainTab,4,ly,half,ch);place(self.secondaryTab,12+half,ly,half,ch);ly+=ch+12
  end
  if self.machine then
   local th=math.max(44,Art.actionHeight(self.targetChange,lw-4));place(self.targetChange,4,ly,lw-4,th);ly+=th+8
  end
  if self.status.Visible then local sh=Art.textHeight(self.status,lw-4,24);place(self.status,4,ly,lw-4,sh);ly+=sh+8 end
  if compactCharm then
   self.charmTitle.Visible=false
   Art.type(self.charmToggle,"Action");local toggleH=math.max(44,Art.actionHeight(self.charmToggle,rw));place(self.charmToggle,rx,ry,rw,toggleH);ry+=toggleH+4
   local live={};for _,id in ipairs(CharmCatalog.Order)do local n=self.shapes[id];if n.Visible then table.insert(live,n)end end
   local sw=(rw-(#live-1)*8)/math.max(1,#live);local sh=44
   for _,n in ipairs(live)do Art.type(n,"Action");sh=math.max(sh,Art.actionHeight(n,sw))end
   for i,n in ipairs(live)do n:SetAttribute("AccessibleLabel",n.Text.." · charm colored by Secondary");place(n,rx+(i-1)*(sw+8),ry,sw,sh)end
   if #live>0 then ry+=sh+8 end
  else
  if self.channelTitle.Visible then Art.type(self.channelTitle,"Action");local chh=Art.textHeight(self.channelTitle,rw,24);place(self.channelTitle,rx,ry,rw,chh);ry+=chh+8 end
  if self.inspection.Visible then local ih=Art.textHeight(self.inspection,rw,24);place(self.inspection,rx,ry,rw,ih);ry+=ih+(if compactMachineHue then 4 else 8)end
  for _,id in ipairs(ids)do local b=self.bars[id];if b and b.row.Visible then
   ry+=layoutBar(b,rx,ry,rw,compactMachineHue)+7
  end end
  if self.presetTitle.Visible then local ph=Art.textHeight(self.presetTitle,rw,24);place(self.presetTitle,rx,ry,rw,ph);ry+=ph+6
   for _,n in ipairs(presets)do if n.Visible then local h=math.max(44,Art.actionHeight(n,rw));place(n,rx,ry,rw,h);ry+=h+8 end end
  end
  local ih=Art.textHeight(self.inventoryTitle,rw,24);place(self.inventoryTitle,rx,ry,rw,ih);ry+=ih+8
  if self.empty.Visible then local eh=Art.textHeight(self.empty,rw,24);place(self.empty,rx,ry,rw,eh);ry+=eh+8 end
  for _,id in ipairs(ids)do local j=self.jars[id];if j.button.Visible then
   local tw=rw-80;local lh=Art.textHeight(j.label,tw-38,22);local rh=Art.textHeight(j.reason,tw,18);local h=math.max(72,lh+rh+12)
   place(j.button,rx,ry,rw,h);place(j.art,6,(h-52)/2,44,52);place(j.label,60,5,tw-38,lh);place(j.quantity,rw-48,5,38,lh);place(j.reason,60,lh+7,tw,rh);ry+=h+8
  end end
  end
  if self.legacyTitle.Visible then local lh=Art.textHeight(self.legacyTitle,lw-4,24);place(self.legacyTitle,4,ly,lw-4,lh);ly+=lh+8
   for _,n in ipairs(redemption)do if n.Visible then local rh=math.max(44,Art.actionHeight(n,lw-4));place(n,4,ly,lw-4,rh);ly+=rh+8 end end
  end
  y=math.max(ly,ry)
 end
 if self.confirmation and not short then
  height=math.min(size.Y-16,header+y+footer+12);self.card.Size=UDim2.fromOffset(width,height)
  bodyH=math.max(1,height-header-footer-8);place(self.body,pad,header,w,bodyH)
  place(self.cancel,pad,height-footer,(w-8)/2,footer-8);place(self.action,pad+(w+8)/2,height-footer,(w-8)/2,footer-8)
 end
 self.body.CanvasSize=UDim2.fromOffset(0,y+4);self.body.ScrollingEnabled=y+4>bodyH
 self.body.CanvasPosition=Vector2.new(0,math.clamp(self.body.CanvasPosition.Y,0,math.max(0,y+4-bodyH)));self.layingOut=false;self:fitPortrait()
end
function View:setSaveNotice(notice)self.saveNotice=notice;if self.shade.Visible then self:refresh()end end
function View:open(state,page,petId)
 self.intent:update(state);self.state=state or {}
 if self.state.lastHatch then if self.options.pendingHatch then self.options.pendingHatch()end;return false end
 self.page=if self.state.pendingHueResult then "receipt"elseif page=="buy"then "buy"else "palette"
 if self.state.hueMigrationId and self.state.hueMigrationAcknowledged==false then self.afterMigrationPage=self.page;self.page="migration"end
 self.petId=petId or self.petId;self.tab=if page=="charm"then "charm"elseif page=="pet"then "pet"else "hue";self.channel="main";self.inspected=nil;self.confirmation=nil;self.assignment=nil;self.selectTarget=false;self.body.CanvasPosition=Vector2.zero
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
 self.lifecycleEpoch=(self.lifecycleEpoch or 0)+1;self.previousSelection=GuiService.SelectedObject;self.epoch+=1;self.shade:SetAttribute("ControllerEpoch",self.epoch);self.shade.Visible=true;self:refresh();return true
end
function View:close(reason)
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
 if not self.machine then self.machineSwitching=nil end
 local pendingId=if self.assignment then self.assignment.pendingResultId elseif self.confirmation then self.confirmation.pendingResultId else nil
 if pendingId then self.resultDraft={id=pendingId,petId=self.petId,channel=self.channel,tab=self.tab,assignment=if self.assignment then table.clone(self.assignment)else nil,confirmation=if self.confirmation then table.clone(self.confirmation)else nil}end
 self.lifecycleEpoch=(self.lifecycleEpoch or 0)+1
 self.itemReveal:cancel();self.purchaseInFlight=nil;self.shade.Visible=false;self.epoch+=1;self.shade:SetAttribute("ControllerEpoch",self.epoch)
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
 return {root=self.shade,epoch=self.epoch,target=function()return if self.confirmation then self.cancel elseif self.action.Visible and self.action.Interactable then self.action else self.petTab end,fallback=self.closeButton,ensure=function(n)self:ensure(n)end}
end
function View:destroy(fromSignal)
 if self.destroyed then return end;self.destroyed=true;self:stopPortraitClock();self.itemReveal:destroy();for _,entry in pairs(self.gridPreviews)do if entry.visual then entry.visual:destroy();entry.visual=nil end end;if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.shade)then GuiService.SelectedObject=nil end;if self.visual then self.visual:destroy();self.visual=nil end;if not fromSignal then self.shade:Destroy()end
end
return View
