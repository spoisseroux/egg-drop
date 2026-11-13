local ReceiptLayout=require(script.Parent.ItemReceiptLayout)
local Shared=game:GetService("ReplicatedStorage").Shared
local OddsText=require(Shared.OddsText);local NextItem=require(script.Parent.NextItemText);local Catalog=require(Shared.FeatureCatalog);local Pets=require(Shared.PetCatalog)
local Art=require(script.Parent.DeckArt);local EggArt=require(script.Parent.EggArt)
local Reveal=require(script.Parent.HueItemReveal);local ItemArt=require(script.Parent.RewardItemArt)
local Panel={};Panel.__index=Panel
local function place(n,x,y,w,h)n.Position,n.Size=UDim2.fromOffset(x,y),UDim2.fromOffset(w,h)end
local function label(parent,name,copy,role)
 local n=Art.text(parent,name,copy,UDim2.fromOffset(0,0),UDim2.fromOffset(100,24),"text",16);Art.type(n,role or "Body");n.TextXAlignment=Enum.TextXAlignment.Left;return n
end
local function button(parent,name,copy,callback)
 local n=Instance.new("TextButton");n.Name,n.Text,n.Parent=name,copy,parent;n.BorderSizePixel=0;n.ZIndex=parent.ZIndex+1
 Art.button(n,10);Art.type(n,"Action");Art.bind(n,{BackgroundColor3="raised",TextColor3="text"});n.Activated:Connect(callback);return n
end
function Panel.new(parent,intent,options)
 local root=Art.frame(parent,"Features","panel",UDim2.fromOffset(0,0),UDim2.fromOffset(100,100),parent.ZIndex+1);root.BackgroundTransparency=1;root.Visible=false
 local self=setmetatable({root=root,intent=intent,options=options or {},rows={},selected={}},Panel)
 self.title=label(root,"Heading","Features","Heading");self.note=label(root,"Description","Grow and show each feature independently.","Body")
 self.art=Art.frame(root,"FeatureResultArt","inset",UDim2.fromOffset(0,0),UDim2.fromOffset(140,140),root.ZIndex+1);self.art.BackgroundTransparency=1
 self.reveal=Reveal.new(self.art,{audio=self.options.audio,reduceEffects=self.options.reduceEffects,recipeId="feature",resultBuilder=ItemArt.create})
 self.pool=label(root,"AvailableOdds","","Body");self.status=label(root,"Status","","Body")
 self.useNow=button(root,"UseNow","Use now",function()self:useResult()end)
 self.shop=button(root,"FeatureEggShop","Feature Egg · 32 Stars",function()if self.options.shop then self.options.shop()end end)
 self.confirmCopy=label(root,"ConfirmGrowth","","Body")
 self.confirm=button(root,"ConfirmGrowthAction","Use one",function()self:confirmUse()end)
 self.cancel=button(root,"CancelGrowth","Cancel",function()self:cancelUse()end)
 for _,id in ipairs(Catalog.Order)do
  local card=Art.frame(root,"Feature_"..id,"inset",UDim2.fromOffset(0,0),UDim2.fromOffset(100,100),root.ZIndex+1);Art.corner(card,10)
  local row={root=card,title=label(card,"Name",Catalog.ById[id].name,"Action"),count=label(card,"Growth","","Body"),preview=label(card,"Preview","","Supporting"),stages={}}
  for stage=0,5 do row.stages[stage]=button(card,"Preview"..stage,tostring(stage),function()self:preview(id,stage)end)end
  row.show=button(card,"ShowStage","Show",function()self:show(id)end)
  row.use=button(card,"UseOne","Grow with one",function()self:requestUse(id)end);self.rows[id]=row
 end
 return self
end
function Panel:canCustomize()return not self.options.canUse or self.options.canUse()==true end
function Panel:saved(id)return ((self.state.petFeatures or {})[self.petId]or Catalog.emptyRow())[id]end
function Panel:notify()if self.options.changed then self.options.changed()else self:refresh(self.state,self.petId,self.mode)end end
function Panel:preview(id,stage)
 if not self.root.Visible or self.mode~="choices"or self.confirmation then return false end
 if not self:canCustomize()or not Catalog.ById[id]or type(stage)~="number"or stage<0 or stage>5 or stage%1~=0 then return false end
 self.selected[id]=stage;if self.options.preview then self.options.preview(id,stage)end;self:notify();return true
end
function Panel:show(id)
 if not self.root.Visible or self.mode~="choices"or self.confirmation then return false end
 if not self:canCustomize()or not self.intent then return false end
 local stage=self.selected[id];if stage==nil then stage=self:saved(id).visible end
 return self.intent:show(self.petId,id,stage)
end
function Panel:requestUse(id,resultId)
 if not self.root.Visible or self.mode~="choices"or self.confirmation then return false end
 if not self.intent or self.intent.pending or not Catalog.ById[id]then return false end
 local result=self.state.pendingFeatureResult
 local receipt=resultId~=nil and result~=nil and result.id==resultId and result.featureId==id and(not self.options.canAssignReceipt or self.options.canAssignReceipt(resultId,id))
 if not self:canCustomize()and not receipt then return false end
 local saved=self:saved(id);local stock=(self.state.featureStock or {})[id]or 0
 if saved.earned>=5 or stock<1 then return false end
 self.confirmation={petId=self.petId,featureId=id,resultId=resultId,earned=saved.earned,stock=stock,binding=self.options.binding and self.options.binding()};self:notify();return true
end
function Panel:confirmUse()
 if not self.root.Visible or self.mode~="choices"then return false end
 local q=self.confirmation;if not q or q.petId~=self.petId or not self.intent then return false end
 if self.options.binding and q.binding~=self.options.binding()then self:cancelUse();return false end
 local saved=self:saved(q.featureId);local stock=(self.state.featureStock or {})[q.featureId]or 0
 if saved.earned~=q.earned or stock~=q.stock then self:cancelUse();return false end
 local result=self.state.pendingFeatureResult
 if not self:canCustomize()and not(result and q.resultId==result.id and q.featureId==result.featureId and(not self.options.canAssignReceipt or self.options.canAssignReceipt(q.resultId,q.featureId)))then return false end
 if not self.intent:use(self.petId,q.featureId,q.resultId)then return false end
 self.submitted=self.intent.pending and self.intent.pending.value.id;self:notify();return true
end
function Panel:cancelUse()
 if self.intent and self.intent.pending then return false end
 self.confirmation=nil;if self.options.cancelUse then self.options.cancelUse()end;self:notify();return true
end
function Panel:useResult()
 local result=self.state and self.state.pendingFeatureResult
 if not result or not self.root.Visible or self.mode~="receipt"or(self.options.receiptOpen and not self.options.receiptOpen(result))then return false end
 if self.reveal:consumeSkipInput()or self.reveal:skip()then return false end
 if self.options.useNow then self.options.useNow(result);return true end;return false
end
function Panel:refresh(state,petId,mode,animate)
 if self.petId~=petId or self.mode~=mode then self.selected={};self.confirmation=nil end
 self.state,self.petId,self.mode=state or {},petId,mode;self.root.Visible=mode~=nil
 if self.submitted and self.intent and not self.intent.pending and self.intent.receipt and self.intent.receipt.id==self.submitted then self.confirmation=nil;self.submitted=nil;self.selected={}end
 self.useNow.Visible=mode=="receipt"and self.state.pendingFeatureResult~=nil
 if mode~="receipt"and self.reveal.resultId then self.reveal:clear()end
 if not mode then return end
 local receipt,buy=mode=="receipt",mode=="buy";local result=self.state.pendingFeatureResult;local confirming=self.confirmation~=nil
 self.title.Text=if receipt and result then Catalog.ById[result.featureId].name.." found!"elseif buy then "Feature Egg"else "Features"
 self.note.Text=if receipt then "Choose a pet to grow this feature."elseif buy then "32 Stars · one stored feature item. Fixed odds."else "Grown is what you earned. Shown is the size on this pet."
 self.art.Visible=receipt or buy
 if receipt and result then self.reveal:show(result,animate==true)
 elseif buy and not self.art:FindFirstChild("FeatureEgg")then for _,n in ipairs(self.art:GetChildren())do n:Destroy()end;EggArt.create(self.art,"feature",UDim2.fromScale(0,0),UDim2.fromScale(1,1),self.art.ZIndex+1,"FeatureEgg")end
 self.pool.Visible=buy;local odds={}
 for _,r in ipairs(Catalog.odds())do table.insert(odds,Catalog.ById[r.id].name.." · "..r.rarity.." · "..OddsText.format(r.probability))end
 -- Restricted players get the fixed next feature, never a roll (F1 policy): no odds list.
 self.pool.Text=(if NextItem.restricted(self.state)then NextItem.line("feature",self.state)else table.concat(odds,"\n")).."\nStacks hold 99 each. A rolled full stack uses no Stars. Other pets can use your stored items."
 self.shop.Visible=not receipt and not buy and not confirming;self.shop.Interactable=self.intent~=nil and not self.intent.pending and not Catalog.full(self.state.featureStock or {})
 self.useNow.Interactable=self.intent~=nil and not self.intent.pending
 self.status.Text=self.intent and self.intent.message or "";self.status.Visible=self.status.Text~=""
 self.confirmCopy.Visible=confirming;self.confirm.Visible=confirming;self.cancel.Visible=confirming
 if confirming then
  local q=self.confirmation
  self.confirmCopy.Text=Pets.byId[q.petId].name.." · "..Catalog.ById[q.featureId].name.."\nGrown "..q.earned.." → "..(q.earned+1).." / 5\nShown → "..(q.earned+1).."\nStock "..q.stock.." → "..(q.stock-1)
  self.confirm.Interactable=not self.intent.pending;self.cancel.Interactable=not self.intent.pending
 end
 for id,row in pairs(self.rows)do
  row.root.Visible=not receipt and not buy and not confirming
  local saved=self:saved(id);local stock=(self.state.featureStock or {})[id]or 0;local selected=self.selected[id];if selected==nil then selected=saved.visible end
  row.count.Text="Grown "..saved.earned.."/5 · Shown "..saved.visible.."/"..saved.earned.." · "..stock.." stored"
  row.preview.Text=if selected==saved.visible then "Current size"else "Preview "..selected.." · not saved"
  for stage,n in pairs(row.stages)do n.Interactable=self:canCustomize()and not(self.intent and self.intent.pending);Art.tab(n,selected==stage,n.Interactable);n:SetAttribute("AccessibleLabel",Catalog.ById[id].name.." · Preview size "..stage)end
  row.show.Text=if selected>saved.earned then "Not grown yet"elseif selected==0 then "Hide"else "Show "..selected
  row.show.Interactable=self:canCustomize()and self.intent~=nil and not self.intent.pending and selected<=saved.earned and selected~=saved.visible
  row.use.Text=if saved.earned>=5 then "Max · 5/5 grown"elseif stock<1 then "No items"else "Grow with one";row.use.Interactable=self:canCustomize()and self.intent~=nil and not self.intent.pending and saved.earned<5 and stock>0
 end
end
function Panel:layout(width,compact,availableHeight)
 if self.mode=="receipt"then
  self.title.Visible=false
  local height=ReceiptLayout.layout(self.art,self.note,width,availableHeight,compact)
  if self.status.Visible then Art.type(self.status,"Body",compact);local h=Art.textHeight(self.status,width-8,24);place(self.status,4,height,width-8,h);height+=h+8 end
  self.root.Size=UDim2.fromOffset(width,height);return height
 end
 local y=0
 local function copy(n,role)if not n.Visible then return end;Art.type(n,role);local h=Art.textHeight(n,math.max(1,width-8),24);place(n,4,y,width-8,h);y+=h+8 end
 local function action(n)if not n.Visible or n.Parent~=self.root then return end;Art.type(n,"Action");local h=Art.actionHeight(n,width-8);place(n,4,y,width-8,h);y+=h+8 end
 self.title.Visible=not(compact and self.mode=="choices");self.note.Visible=self.title.Visible;copy(self.title,"Heading")
 if self.art.Visible then local side=math.min(if self.mode=="receipt"then 112 else 140,math.max(44,width-16));place(self.art,(width-side)/2,y,side,side);y+=side+8 end
 copy(self.note,"Body");copy(self.pool,"Body");copy(self.confirmCopy,"Body");action(self.cancel);action(self.confirm)
 for _,id in ipairs(Catalog.Order)do local row=self.rows[id];if row.root.Visible then
  local inner=width-16;local ry=6
  for _,entry in ipairs({{row.title,"Action"},{row.count,"Body"},{row.preview,"Supporting"}})do Art.type(entry[1],entry[2]);local h=Art.textHeight(entry[1],inner-12,24);place(entry[1],6,ry,inner-12,h);ry+=h+4 end
  local cols=math.max(1,math.min(6,math.floor((inner+4)/48)));local _,cellW=Art.gridCell(inner,0,cols,4);local stageH=44
  for _,n in pairs(row.stages)do Art.type(n,"Counter");stageH=math.max(stageH,Art.actionHeight(n,cellW))end
  for stage=0,5 do local x,w=Art.gridCell(inner,stage%cols,cols,4);place(row.stages[stage],6+x,ry+math.floor(stage/cols)*(stageH+4),w,stageH)end
  ry+=math.ceil(6/cols)*(stageH+4)+4
  for _,n in ipairs({row.show,row.use})do Art.type(n,"Action");local h=Art.actionHeight(n,inner);place(n,6,ry,inner,h);ry+=h+6 end
  place(row.root,4,y,width-8,ry);y+=ry+8
 end end
 action(self.useNow);action(self.shop);copy(self.status,"Body");self.root.Size=UDim2.fromOffset(width,y);return y
end
-- Customize card grid (redesign 2.3; the tab is hidden behind FeatureFlags.Features).
-- Each feature keeps its own stage controls; its card takes the Kit card face.
function Panel:layoutCards(width,cols,cardH,gap,focusIndex,compact)
 local Kit=require(script.Parent.DeckKit)
 local y=self:layout(width,compact)
 for _,row in pairs(self.rows)do
  Kit.paint(row.root,"BackgroundColor3","raised");Kit.corner(row.root,12)
  local stroke=row.root:FindFirstChildOfClass("UIStroke")or Kit.stroke(row.root)
  stroke.Color=Color3.new(1,1,1);stroke.Transparency=.86;stroke.Thickness=1
 end
 return y,{}
end
function Panel:destroy()self.reveal:destroy();self.root:Destroy()end
return Panel
