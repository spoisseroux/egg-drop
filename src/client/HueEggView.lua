-- Pet-specific customization and saved item receipts. Exactly one portrait.
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
function View.new(parent,intent,options)
 local shade=Art.frame(parent,"HueEggView","ink",UDim2.fromScale(0,0),UDim2.fromScale(1,1),20);shade.Visible=false;shade.Active=true;shade.BackgroundTransparency=1
 local card=Art.frame(shade,"Card","panel",UDim2.fromScale(.5,.5),UDim2.fromOffset(640,640),21);card.AnchorPoint=Vector2.new(.5,.5);Art.panel(card,18)
 local body=Instance.new("ScrollingFrame");body.Name,body.Parent="Body",card;body.BackgroundTransparency=1;body.BorderSizePixel=0;body.ZIndex=22
 body.ScrollingDirection,body.ElasticBehavior=Enum.ScrollingDirection.Y,Enum.ElasticBehavior.Never;body.ScrollBarThickness=4;Art.bind(body,{ScrollBarImageColor3="accent"})
 local self=setmetatable({shade=shade,card=card,body=body,intent=intent,options=options or {},state={},petId="pip",page="palette",tab="hue",channel="main",targets={},jars={},bars={},charmRequests={},epoch=0},View)
 self.title=text(card,"Title","Customize","Heading");self.wallet=text(card,"Wallet","0 Stars","Counter")
 self.closeButton=Art.bareClose(button(card,"Close","×",function()self:close("back")end))
 self.action=button(card,"Action","Confirm",function()self:activate()end)
 self.cancel=button(card,"Cancel","Cancel",function()self:cancelConfirmation()end)
 self.charmTab=button(body,"CharmTab","Charm",function()self:setTab("charm")end)
 self.hueTab=button(body,"HueTab","Hue",function()self:setTab("hue")end)
 self.targetTitle=text(body,"TargetTitle","Choose a pet","Action")
 for _,pet in ipairs(Pets.collection)do local id=pet.id;self.targets[id]=button(body,"Target_"..id,pet.name,function()self:choosePet(id)end)end
 self.targetChange=button(body,"ChangePet","Change pet",function()if not self.intent.pending then self.selectTarget=not self.selectTarget;self:refresh()end end)
 self.mainTab=button(body,"MainTab","Main",function()self:chooseChannel("main")end)
 self.secondaryTab=button(body,"SecondaryTab","Secondary",function()self:chooseChannel("secondary")end)
 self.portrait=Art.frame(body,"PetPortrait","inset",UDim2.fromOffset(0,0),UDim2.fromOffset(240,170),23);Art.corner(self.portrait,16)
 self.viewport=Instance.new("ViewportFrame");self.viewport.Name="SavedPet";self.viewport.BackgroundTransparency=1;self.viewport.Size=UDim2.fromScale(1,1);self.viewport.ZIndex=24;self.viewport.Parent=self.portrait
 self.viewport.Ambient=Color3.fromRGB(175,184,183);self.viewport.LightColor=Color3.fromRGB(255,250,231);self.viewport.LightDirection=Vector3.new(-1,-1.4,-3)
 self.world=Instance.new("WorldModel");self.world.Parent=self.viewport;self.camera=Instance.new("Camera");self.camera.FieldOfView=30;self.camera.Parent=self.viewport;self.viewport.CurrentCamera=self.camera
 self.petName=text(body,"PetName","Zivvi","Action");self.petName.TextXAlignment=Enum.TextXAlignment.Center
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
 self.charmToggle=button(body,"ShowCharm","Show charm",function()self:toggleCharm()end)
 self.shapes={}
 for _,id in ipairs(CharmCatalog.Order)do self.shapes[id]=button(body,"Shape_"..id,CharmCatalog.ById[id].name,function()self:selectCharm(id)end)end
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
function View:choosePet(id)
 if self.intent.pending or not self:owned(id)or not Hues.Supported[id]then return false end
 self.petId=id;self.inspected=nil;self.selectTarget=false;if self.confirmation then self.confirmation.petId=id;self.confirmation.channel=self.channel end;self:refresh();return true
end
function View:chooseChannel(channel)
 if self.intent.pending or(channel~="main"and channel~="secondary")then return false end;self.channel=channel;self.inspected=nil
 if self.confirmation then self.confirmation.channel=channel end;self:refresh();return true
end
function View:setTab(tab)
 if self.intent.pending or self.confirmation then return false end
 self.tab=tab;self.inspected=nil;self:refresh();return true
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
 self.inspection.Text=if compact then "Tap a swatch to preview."else detail
 for id,bar in pairs(self.bars)do
  bar.row.Visible=visible;bar.value.Text=tostring(counts[id]).."/5"
  for stage,tick in ipairs(bar.ticks)do
   local color=Swatches.at(self.petId,appearance,self.channel,id,stage)
   local inspected=self.inspected and self.inspected.petId==self.petId and self.inspected.channel==self.channel and self.inspected.id==id and self.inspected.stage==stage
   tick:SetAttribute("SwatchColor",color);tick.BackgroundColor3=color;tick.BackgroundTransparency=0;tick:SetAttribute("Filled",stage<=counts[id]);tick:SetAttribute("SavedStage",stage==counts[id]);tick:SetAttribute("Inspected",inspected==true)
   tick:SetAttribute("AccessibleLabel",names[id].." stage "..stage.." · #"..string.upper(color:ToHex())..(if stage==counts[id]then " · Saved"else " · Unapplied preview"))
   -- Clear keyline on Citrus and Ink; saved stage and inspection are independent.
   local stroke=tick:FindFirstChildWhichIsA("UIStroke")
   if stroke then stroke.Color=if inspected then Color3.fromHex("#008EA8")elseif stage==counts[id]then Art.Ink else Color3.fromHex("#647F87");stroke.Thickness=if inspected or stage==counts[id]then 3 else 1;stroke.Transparency=0 end
   local luminance=color.R*.2126+color.G*.7152+color.B*.0722
   tick.TextColor3=if luminance<.48 then Color3.new(1,1,1)else Color3.fromHex("#102D34")
   tick:SetAttribute("SwatchInk",tick.TextColor3)
   tick.Text=tostring(stage)
   for _,part in ipairs(tick.SavedCheck:GetChildren())do part.Visible=stage==counts[id];part.BackgroundColor3=tick.TextColor3 end
   tick.SavedMark.BackgroundColor3=Art.Ink;tick.SavedMark.BackgroundTransparency=if stage<=counts[id]then 0 else 1
   if inspected then
    detail=(if stage==counts[id]then "Saved"else "Preview · Unapplied").." · "..names[id].." stage "..stage.." · #"..string.upper(color:ToHex())
     ..(if((self.state.hueInventory or {})[id]or 0)==0 then " · 0 in inventory"else " · Inspect only")
    self.inspection.Text=if compact then (if stage==counts[id]then "Saved "else "Preview ")..Hues.ById[id].name.." "..stage.." · #"..string.upper(color:ToHex())else detail
   end
  end
 end
 self.inspection:SetAttribute("AccessibleLabel",detail)
end
local function layoutBar(bar,x,y,width)
 Art.type(bar.label,"Body");Art.type(bar.value,"Counter")
 local valueW=math.max(54,Art.textWidth(bar.value)+4)
 local header=math.max(Art.textHeight(bar.label,width-valueW-24,22),Art.textHeight(bar.value,valueW,22))
 local columns=if width>=264 then 5 else 3
 local cell=(width-16-(columns-1)*4)/columns;local rows=math.ceil(5/columns)
 local height=header+rows*44+(rows-1)*4+16
 place(bar.row,x,y,width,height);place(bar.label,8,3,width-valueW-24,header);place(bar.value,width-valueW-8,3,valueW,header)
 for i,tick in ipairs(bar.ticks)do Art.type(tick,"Counter");place(tick,8+((i-1)%columns)*(cell+4),header+8+math.floor((i-1)/columns)*48,cell,44)end
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
 self.page="palette";self.tab="hue";self.selectTarget=true;self.body.CanvasPosition=Vector2.zero;self.epoch+=1
 self.assignment={itemId=r.itemId,pendingResultId=r.id};self.confirmation=nil;self:refresh();return true
end
function View:requestLegacy(id)
 if self.intent.pending then return false end
 self.confirmation={legacyItem=id};self:refresh();return true
end
function View:cancelConfirmation()
 if self.intent.pending then return false end
 local pendingResult=self.confirmation and self.confirmation.pendingResultId
 self.confirmation=nil;self.selectTarget=false;if pendingResult then self.page="receipt"end;self:refresh();if self.confirmReturn then self.body.CanvasPosition=self.confirmReturn.scroll;GuiService.SelectedObject=self.confirmReturn.target;self.confirmReturn=nil end;self.epoch+=1;return true
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
 local wanted=not self.destroyed and self.shade.Visible and self.portrait.Visible and not self.confirmation and self.visual~=nil
 if not wanted then self:stopPortraitClock();return end
 if self.portraitClock then return end
 self.portraitClock=game:GetService("RunService").RenderStepped:Connect(function(dt)
  if self.destroyed or not self.shade.Visible or not self.portrait.Visible or self.confirmation then self:stopPortraitClock();return end
  if GuiService.MenuIsOpen or(self.options.audio and self.options.audio.deviceActive==false)then return end
  local visual=self.visual;if not visual or visual.destroyed then return end
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
   self.confirmation=nil;self.selectTarget=false;self.submitted=nil
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
 self.title.Text=if migration then "Your converted colors"elseif self.assignment then "Choose where to use"elseif confirming then if self.confirmation.itemId=="reset"then "Reset "..channelName(self.channel).." color?"elseif self.confirmation.itemId then "Use "..names[self.confirmation.itemId].."?"else "Confirm choice"elseif self.page=="receipt"then "A jar for your garden"elseif self.page=="buy"then "Hue Egg"else "Customize"
 self.title:SetAttribute("AccessibleLabel",if customization then "Customize "..Pets.byId[self.petId].name else self.title.Text)
 self.wallet.Text=tostring(self.state.nectar or 0).." Stars"
 local function visible(n,value)n.Visible=value end
 for _,n in ipairs({self.charmTab,self.hueTab,self.portrait,self.petName})do visible(n,customization and not confirming)end
 for _,n in ipairs({self.mainTab,self.secondaryTab,self.channelTitle,self.inventoryTitle})do visible(n,hue and not confirming)end
 if self.assignment then self.inventoryTitle.Visible=false end
 self.mainTab.Visible=hue and not confirming;self.secondaryTab.Visible=hue and not confirming;self.targetChange.Visible=false;self.targetTitle.Visible=customization and not confirming and self.selectTarget==true
 for id,n in pairs(self.targets)do n.Visible=customization and not confirming and self.selectTarget==true and self:owned(id);n.Interactable=not self.intent.pending;Art.control(n,id==self.petId,n.Interactable)end
 Art.tab(self.charmTab,self.tab=="charm",not self.intent.pending);Art.tab(self.hueTab,self.tab=="hue",not self.intent.pending)
 Art.tab(self.mainTab,self.channel=="main",not self.intent.pending);Art.tab(self.secondaryTab,self.channel=="secondary",not self.intent.pending)
 self.targetChange.Text=Pets.byId[self.petId].name.." · Change pet";self.petName.Text=Pets.byId[self.petId].name.." · saved appearance";self.channelTitle.Text=channelName(self.channel).." · saved doses"
 local counts=self:counts();local stock=0
 self:paintSwatches(hue and not confirming)
 for _,id in ipairs(ids)do local j=self.jars[id];local quantity=(self.state.hueInventory or {})[id]or 0;stock+=quantity
  j.button.Visible=hue and not confirming and not self.assignment and quantity>0;j.quantity.Text="×"..quantity;j.reason.Text=self:reason(id)or "Choose to use";j.button.Interactable=not self.intent.pending and self:reason(id)==nil and not confirming
  j.button:SetAttribute("DisabledReason",self:reason(id));Art.control(j.button,false,j.button.Interactable)
 end
 self.empty.Visible=hue and not confirming and not self.assignment and stock==0
 self.charmTitle.Visible=charm and not confirming;self.charmToggle.Visible=charm and not confirming
 local a=self:appearance();local charmPending=self.charmRequests[self.petId]
 self.charmToggle.Text=if charmPending and charmPending.retry then "Retry charm save"elseif charmPending then "Saving…"elseif a.charmVisible~=false then "✓ Show charm"else "Show charm"
 self.charmToggle.Interactable=not charmPending or charmPending.retry==true
 local known=CharmCatalog.known(a.charmShape or "dot");local enabled=self:shapeSelectionsEnabled()
 self.charmTitle.Text=if known then "A floating "..CharmCatalog.ById[a.charmShape or "dot"].name..", colored by Secondary."else "Your saved charm uses a Dot here. Its original shape is preserved."
 for id,node in pairs(self.shapes)do
  node.Visible=charm and not confirming and(enabled or id==CharmCatalog.renderShape(a.charmShape));node.Interactable=enabled and not charmPending
  local selected=known and id==(a.charmShape or "dot");node.Text=(if selected then "✓ "else "")..CharmCatalog.ById[id].name;Art.control(node,selected,node.Interactable)
 end
 self.receipt.Visible=self.page=="receipt";self.receiptArt.Visible=self.receipt.Visible;self.receiptDetail.Visible=self.receipt.Visible;self.useNow.Visible=self.receipt.Visible
 if r and self.receipt.Visible then
  self.receipt.Text=names[r.itemId].." · "..tostring((self.state.hueInventory or {})[r.itemId]or r.inventoryAfter or 1).." in inventory"
  self.itemReveal:show(r,self.purchaseInFlight==r.id);self.purchaseInFlight=nil
 end
 self.legacyTitle.Visible=self.state.legacyHueEgg~=nil and not confirming
 for _,n in pairs(self.legacyButtons)do n.Visible=self.legacyTitle.Visible;n.Interactable=not self.intent.pending end
 self.quote.Visible=confirming or self.assignment~=nil or self.page=="buy";self.resultSwatch.Visible=confirming and not(self.confirmation.legacyItem or self.confirmation.presetId)
 local q=self.confirmation
 if q then
  if q.legacyItem then self.quote.Text="Exchange your carried Hue Egg for one "..names[q.legacyItem].."? This choice is saved once."
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
 self.status.Text=if self.saveNotice then self.saveNotice.detail elseif self.charmMessage and charm then self.charmMessage else self.intent.message or "";self.status.Visible=self.status.Text~=""
 self.action.Visible=migration or self.assignment~=nil or confirming or self.page=="receipt"or self.page=="buy"or self.intent.status=="Retrying"
 self.cancel.Visible=confirming
 self.action.Text=if migration and not self.intent.pending then "Continue"elseif self.intent.status=="Retrying"then "Retry save"elseif self.intent.pending then "Saving…"elseif confirming then if q.itemId=="reset"then "Reset "..channelName(self.channel)elseif q.itemId then "Use fruit"else "Confirm"elseif self.assignment then "Review use"elseif self.page=="receipt"then "Store"elseif self.page=="buy"then "Back to Hue Egg"else ""
 local reason=(q and q.itemId and self:reason(q.itemId))or(self.assignment and self:reason(self.assignment.itemId))
 self.action.Interactable=self.action.Visible and(if self.intent.status=="Retrying"then true else not self.intent.pending and not reason and self.intent:ready(if confirming and not q.legacyItem then self.petId else nil))
 self.cancel.Interactable=not self.intent.pending;self.useNow.Interactable=not self.intent.pending
 Art.control(self.action,true,self.action.Interactable);Art.control(self.cancel,false,self.cancel.Interactable)
 self:layout();self:paintPortrait();self:syncPortraitClock()
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
function View:layout()
 if self.layingOut then return end;self.layingOut=true
 self.channelTitle.Visible=self.page=="palette"and self.tab=="hue"and not self.confirmation and not self:compactSwatches()
 self:paintSwatches(self.inspection.Visible)
 if self.portrait.Visible then self.petName.Visible=true end
 local size=self.shade.AbsoluteSize;local width=math.max(1,math.min(if self.confirmation and not(size.Y<280)then 470 else 640,size.X-16));local short=size.Y<280;local pad=if short then 8 else 16;local w=width-pad*2
 Art.type(self.title,if short then "Body"else "Heading",short);Art.type(self.wallet,"Counter",short)
 local titleH=Art.textHeight(self.title,w-52,24);place(self.title,pad,5,w-52,titleH);place(self.closeButton,width-pad-44,4,44,44)
 local header=math.max(48,titleH+8);self.wallet.Visible=self.confirmation==nil
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
 local height=math.max(1,math.min(if self.confirmation then 420 else 760,size.Y-16));self.card.Size=UDim2.fromOffset(width,height)
 local bodyH=math.max(1,height-header-footer-8);place(self.body,pad,header,w,bodyH)
 if self.cancel.Visible then place(self.cancel,pad,height-footer,(w-8)/2,footer-8);place(self.action,pad+(w+8)/2,height-footer,(w-8)/2,footer-8)else place(self.action,pad,height-footer,w,footer-8)end
 if short and self.confirmation then
  local side=math.max(112,math.min(144,w*.26));local gap=8;local fullW=w
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
 -- Roomy customization gives the saved pet its own generous column.
 if self.page=="palette"and self.tab=="hue"and not self.confirmation and not self.assignment and w>=560 and(height>=500 or height<420)then
  local gap=16;local compactLandscape=height<420;local lw=math.floor(w*.40);local rx=lw+gap;local rw=w-rx-4;local tabH=math.max(self.charmTab.Size.Y.Offset,self.hueTab.Size.Y.Offset);local ly=tabH+8;local ry=tabH+8
  local portraitH=if compactLandscape then 100 else 210;place(self.portrait,4,ly,lw-4,portraitH);ly+=portraitH+4
  self.petName.Text=Pets.byId[self.petId].name;self.petName.Visible=not compactLandscape
  if self.petName.Visible then Art.type(self.petName,"Action");local nh=Art.textHeight(self.petName,lw-4,24);place(self.petName,4,ly,lw-4,nh);ly+=nh+12 end
  local half=(lw-12)/2;local ch=math.max(44,Art.actionHeight(self.mainTab,half),Art.actionHeight(self.secondaryTab,half))
  place(self.mainTab,4,ly,half,ch);place(self.secondaryTab,12+half,ly,half,ch);ly+=ch+12
  if self.status.Visible then local sh=Art.textHeight(self.status,lw-4,24);place(self.status,4,ly,lw-4,sh);ly+=sh+8 end
  if self.channelTitle.Visible then Art.type(self.channelTitle,"Action");local chh=Art.textHeight(self.channelTitle,rw,24);place(self.channelTitle,rx,ry,rw,chh);ry+=chh+8 end
  if self.inspection.Visible then local ih=Art.textHeight(self.inspection,rw,24);place(self.inspection,rx,ry,rw,ih);ry+=ih+8 end
  for _,id in ipairs(ids)do local b=self.bars[id];if b and b.row.Visible then
   ry+=layoutBar(b,rx,ry,rw)+7
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
 self.petId=petId or self.petId;self.tab=if page=="charm"then "charm"else "hue";self.channel="main";self.inspected=nil;self.confirmation=nil;self.assignment=nil;self.selectTarget=false;self.body.CanvasPosition=Vector2.zero
 local p=self.intent.pending
 if p and p.action=="hueUse"then self.page="palette";self.petId=p.value.petId;self.channel=p.value.channel;self.confirmation={itemId=p.value.itemId,petId=p.value.petId,channel=p.value.channel,pendingResultId=p.value.pendingResultId};self.submitted=p.value.id end
 self.previousSelection=GuiService.SelectedObject;self.epoch+=1;self.shade:SetAttribute("ControllerEpoch",self.epoch);self.shade.Visible=true;self:refresh();return true
end
function View:close(reason)
 self:stopPortraitClock()
 if not self.shade.Visible then return end
 self.itemReveal:cancel();self.purchaseInFlight=nil;self.shade.Visible=false;self.epoch+=1;self.shade:SetAttribute("ControllerEpoch",self.epoch)
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
 return {root=self.shade,epoch=self.epoch,target=function()return if self.confirmation then self.cancel elseif self.action.Visible and self.action.Interactable then self.action else self.hueTab end,fallback=self.closeButton,ensure=function(n)self:ensure(n)end}
end
function View:destroy(fromSignal)
 if self.destroyed then return end;self.destroyed=true;self:stopPortraitClock();self.itemReveal:destroy();if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.shade)then GuiService.SelectedObject=nil end;if self.visual then self.visual:destroy();self.visual=nil end;if not fromSignal then self.shade:Destroy()end
end
return View
