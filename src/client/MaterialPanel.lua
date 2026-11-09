local Shared=game:GetService("ReplicatedStorage").Shared
local Catalog=require(Shared.MaterialCatalog)
local Art=require(script.Parent.DeckArt);local EggArt=require(script.Parent.EggArt)
local Reveal=require(script.Parent.HueItemReveal)
local Panel={};Panel.__index=Panel
local function place(node,x,y,w,h)node.Position,node.Size=UDim2.fromOffset(x,y),UDim2.fromOffset(w,h)end
local function label(parent,name,copy,role)
 local node=Art.text(parent,name,copy,UDim2.fromOffset(0,0),UDim2.fromOffset(100,24),"text",16);Art.type(node,role or "Body");node.TextXAlignment=Enum.TextXAlignment.Left;return node
end
local function button(parent,name,copy,callback)
 local node=Instance.new("TextButton");node.Name,node.Text,node.Parent=name,copy,parent;node.ZIndex=parent.ZIndex+1;node.BorderSizePixel=0
 Art.button(node,10);Art.type(node,"Action");Art.bind(node,{BackgroundColor3="raised",TextColor3="text"});node.Activated:Connect(callback);return node
end
function Panel.new(parent,intent,options)
 local root=Art.frame(parent,"Materials","panel",UDim2.fromOffset(0,0),UDim2.fromOffset(100,100),parent.ZIndex+1);root.BackgroundTransparency=1;root.Visible=false
 local self=setmetatable({root=root,intent=intent,options=options or {},rows={}},Panel)
 self.title=label(root,"Heading","Materials","Heading");self.note=label(root,"Description","Choose a material for this pet.","Body")
 self.art=Art.frame(root,"MaterialResultArt","inset",UDim2.fromOffset(0,0),UDim2.fromOffset(100,100),root.ZIndex+1);self.art.BackgroundTransparency=1
 self.reveal=Reveal.new(self.art,{audio=self.options.audio,reduceEffects=self.options.reduceEffects,recipeId="material",resultBuilder=function(parent,result,position,size,z)
  local tile=Art.frame(parent,"UnlockedMaterial","raised",position,size,z);tile.BackgroundTransparency=1
  local sample=Art.frame(tile,"FinishSample",Color3.fromHex("#69D7D5"),UDim2.new(.5,-32,.5,-32),UDim2.fromOffset(64,64),z+1);Art.corner(sample,32)
  sample:SetAttribute("AccessibleLabel",Catalog.ById[result.finishId].name.." material")
  local shade=Instance.new("UIGradient");shade.Color=ColorSequence.new(Color3.fromHex("#A8EBDF"),Color3.fromHex("#3EAAA9"));shade.Rotation=70;shade.Parent=sample
  if result.finishId=="gloss"or result.finishId=="metal"then
   local glint=Art.frame(sample,"GlossGlint",Color3.new(1,1,1),UDim2.fromOffset(14,12),UDim2.fromOffset(18,9),z+2);Art.corner(glint,6);glint.Rotation=-28
  else shade.Color=ColorSequence.new(Color3.fromHex("#8BD7D1"),Color3.fromHex("#69BBB8"))end
  return tile
 end})
 self.pool=label(root,"AvailableOdds","","Body")
 self.status=label(root,"Status","","Body")
 self.useNow=button(root,"UseNow","Use now",function()local result=self.state.pendingMaterialResult;if result and self.options.useNow then self.options.useNow(result)end end)
 self.shop=button(root,"MaterialEggShop","Material Egg · 16 Stars",function()if self.options.shop then self.options.shop()end end)
 for _,id in ipairs(Catalog.Order)do
  local finishId=id
  self.rows[id]=button(root,"Finish_"..id,Catalog.ById[id].name,function()if self.intent then self.intent:equip(self.petId,finishId)end end)
 end
 return self
end
function Panel:refresh(state,petId,mode,animate)
 self.state,self.petId,self.mode=state or {},petId,mode
 self.root.Visible=mode~=nil
 self.useNow.Visible=mode=="receipt"and self.state.pendingMaterialResult~=nil
 if mode~="receipt"and self.reveal.resultId then self.reveal:clear()end
 if not mode then return end
 local result=self.state.pendingMaterialResult;local receipt=mode=="receipt";local buy=mode=="buy"
 self.title.Text=if receipt and result then Catalog.ById[result.finishId].name.." unlocked!"elseif buy then "Material Egg"else "Materials"
 self.note.Text=if receipt then "For all your pets."elseif buy then "16 Stars · one new material. No duplicates."else "Choose a material for this pet."
 self.art.Visible=receipt or buy
 if receipt and result then self.reveal:show(result,animate==true)
 elseif buy and not self.art:FindFirstChild("MaterialEgg")then
  for _,child in ipairs(self.art:GetChildren())do child:Destroy()end
  EggArt.create(self.art,"material",UDim2.fromScale(0,0),UDim2.fromScale(1,1),self.art.ZIndex+1,"MaterialEgg")
 end
 self.shop.Visible=not receipt and not buy
 local selected=(self.state.petMaterials or {})[petId]or Catalog.Default
 for id,node in pairs(self.rows)do
  local owned=Catalog.owns(self.state.materialUnlocks,id)
  node.Visible=not receipt and not buy and owned
  node.Text=(if selected==id then "✓ "else "")..Catalog.ById[id].name
  node.Interactable=owned and self.intent~=nil and not self.intent.pending and selected~=id
  Art.tab(node,selected==id,node.Interactable)
  node:SetAttribute("AccessibleLabel",Catalog.ById[id].name..(if selected==id then " · Current"else " · Use for "..(petId or "this pet")))
 end
 local odds={};for _,entry in ipairs(Catalog.odds(self.state.materialUnlocks))do table.insert(odds,Catalog.ById[entry.id].name.." · "..string.format("%.2g",entry.probability*100).."%")end
 self.pool.Visible=buy
 self.pool.Text=if #odds==0 then "All materials owned"elseif not self.state.materialAvailable then "Material Eggs are not ready yet."else table.concat(odds,"\n")
 self.shop.Text=if #odds==0 then "All materials owned"else "Material Egg · 16 Stars"
 self.shop.Interactable=#odds>0 and self.state.materialAvailable==true and not(self.intent and self.intent.pending)
 self.useNow.Interactable=self.intent~=nil and not self.intent.pending
 self.status.Text=self.intent and self.intent.message or "";self.status.Visible=self.status.Text~=""
end
function Panel:layout(width,compact)
 local y=0
 local function copy(node,role)
  if not node.Visible then return end;Art.type(node,role);local h=Art.textHeight(node,math.max(1,width-8),24);place(node,4,y,width-8,h);y+=h+8
 end
 local function action(node)
  if not node.Visible or node.Parent~=self.root then return end;Art.type(node,"Action");local h=math.max(44,Art.actionHeight(node,width-8));place(node,4,y,width-8,h);y+=h+8
 end
 self.title.Visible=not(compact and self.mode=="choices");self.note.Visible=self.title.Visible
 copy(self.title,"Heading")
 if self.art.Visible then local side=math.min(if self.mode=="receipt"then 88 else 140,math.max(44,width-16));place(self.art,(width-side)/2,y,side,side);y+=side+8 end
 copy(self.note,"Body");copy(self.pool,"Body")
 for _,id in ipairs(Catalog.Order)do action(self.rows[id])end
 action(self.useNow);action(self.shop);copy(self.status,"Body")
 self.root.Size=UDim2.fromOffset(width,y);return y
end
function Panel:destroy()self.reveal:destroy();self.root:Destroy()end
return Panel
