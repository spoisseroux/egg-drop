-- Customize Finish tab (Customization Egg slice 3, plan 2026-11-16 §4 and §5.3). Successor to
-- MaterialPanel on the tab bar: finish jars are doses, not unlocks.
--  * Sheen: one axis from Chalky (-3) to Glassy (+3). A Matte jar moves it one notch down, a
--    Gloss jar one notch up, so they cancel. Jelly: a second axis, 0 to 3 stages.
--  * One tap on a jar card spends one jar (HueIntent:finishUse); "Original" is free per axis.
--  * The look name is "{jelly} {sheen}" ("Clear Jelly Glassy", "Matte", ...).
--  * A legacy permanent finish (petMaterials) shows as a Kept chip; the dose look wins over it.
-- HueEggView mounts it; the panel owns its cards, notch bar and pane text.
local Shared=game:GetService("ReplicatedStorage").Shared
local Look=require(Shared.LookEggCatalog)
local Materials=require(Shared.MaterialCatalog)
local Copy=require(Shared.UICopy)
local Art=require(script.Parent.DeckArt)
local JarArt=require(script.Parent.HueJarArt)
local Panel={};Panel.__index=Panel
Panel.Cards={"gloss","matte","jelly","originalSheen","originalJelly"}
local sheenKeys={[-3]="m3",[-2]="m2",[-1]="m1",[0]="zero",[1]="p1",[2]="p2",[3]="p3"}

-- Pure: the look name for a finish row (stored values clamp to the display stops).
function Panel.lookName(row)
 row=if Look.validFinish(row)then row else {sheen=0,jelly=0}
 local sheen=math.clamp(row.sheen,-Look.SheenStops,Look.SheenStops);local jelly=math.min(row.jelly,Look.JellyStops)
 local sheenName=Copy.get("r4.customize.finish.sheen."..sheenKeys[sheen])
 if jelly==0 then return sheenName end
 local jellyName=Copy.get("r4.customize.finish.jelly.s"..jelly)
 if sheen==0 then return jellyName end
 return Copy.get("r4.customize.finish.mix",{jelly=jellyName,sheen=sheenName})
end
-- Pure: the state of one card for a pet. Returns {id,name,status,count,enabled,reason,line,button,axis}.
function Panel.card(id,state,petId,ready)
 state=state or {}
 local row=(state.petFinish or {})[petId]or {sheen=0,jelly=0}
 local stock=(state.finishInventory or {})
 if id=="originalSheen"or id=="originalJelly"then
  local axis=if id=="originalSheen"then "sheen"else "jelly"
  local original=row[axis]==0
  return {id=id,axis=axis,name=Copy.get("r4.customize.finish.original"),status=Copy.get(if axis=="sheen"then "r4.customize.finish.sheenAxis"else "r4.customize.finish.jellyAxis"),
   enabled=ready and not original,line=if original then Copy.get("r4.customize.finish.already")else Copy.get("r4.customize.finish.clearLine",{look=Panel.lookName(row)}),
   button=Copy.get("r4.customize.finish.original"),free=true}
 end
 local count=stock[id]or 0
 local after,reason=Look.step(row,id)
 local name=Copy.get("r4.customize.finish.jar."..id)
 local line
 if count<1 then line=Copy.get("r4.customize.finish.empty")
 elseif not after then line=Copy.get(if reason=="MaxJelly"then "r4.customize.finish.maxJelly"else "r4.customize.finish.maxSheen")
 else line=Panel.lookName(row).." → "..Panel.lookName(after)end
 return {id=id,name=name,status="×"..count,count=count,enabled=ready and count>0 and after~=nil,reason=if count<1 then "EmptyStock"else reason,line=line,
  button=Copy.get("r4.customize.finish.useJar",{item=Copy.get("r4.customize.finish.jar."..id)})}
end

function Panel.new(parent,intent,options)
 local root=Instance.new("Frame");root.Name="Finish";root.BackgroundTransparency=1;root.Visible=false;root.ZIndex=parent.ZIndex+1;root.Parent=parent
 local self=setmetatable({root=root,intent=intent,options=options or {},cards={},state={}},Panel)
 local Cards=require(script.Parent.CustomizeCards)
 for _,id in ipairs(Panel.Cards)do self.cards[id]=Cards.new(root,"FinishCard_"..id)end
 -- Notch bar: seven sheen notches (Matte end left, Gloss end right) and three Jelly pips.
 local bar=Instance.new("Frame");bar.Name="FinishBar";bar.BackgroundTransparency=1;bar.Size=UDim2.fromOffset(200,56);bar.ZIndex=root.ZIndex+1;bar.Parent=root
 self.bar=bar
 self.lookName=Art.text(bar,"LookName","",UDim2.fromOffset(0,0),UDim2.fromOffset(200,22),"text",16);Art.type(self.lookName,"Body")
 self.lookName.TextXAlignment=Enum.TextXAlignment.Left
 self.notches={};self.pips={}
 for stop=-3,3 do
  local n=Instance.new("Frame");n.Name="Notch"..stop;n.BorderSizePixel=0;n.ZIndex=bar.ZIndex+1;n.Parent=bar
  Instance.new("UICorner",n).CornerRadius=UDim.new(1,0);self.notches[stop]=n
 end
 for stage=1,3 do
  local p=Instance.new("Frame");p.Name="Pip"..stage;p.BorderSizePixel=0;p.ZIndex=bar.ZIndex+1;p.Parent=bar
  Instance.new("UICorner",p).CornerRadius=UDim.new(1,0);self.pips[stage]=p
 end
 self.kept=Art.text(bar,"Kept","",UDim2.fromOffset(0,0),UDim2.fromOffset(120,18),"soft",12);self.kept.TextXAlignment=Enum.TextXAlignment.Right
 return self
end
function Panel:refresh(state,petId,visible)
 self.state,self.petId=state or {},petId
 self.root.Visible=visible==true
end
function Panel:ready()
 if self.options.canUse and not self.options.canUse()then return false end
 return self.intent~=nil and not self.intent.pending
end
function Panel:act(id)
 if not self.root.Visible or not self:ready()then return false end
 local card=Panel.card(id,self.state,self.petId,true)
 if not card.enabled then return false end
 if card.axis then return self.intent:finishClear(self.petId,card.axis)end
 local pending=self.state.pendingHueResult
 return self.intent:finishUse(self.petId,id,if pending and pending.itemId==id then pending.id else nil)
end
-- Card grid (same contract as MaterialPanel:layoutCards): returns the used height and the
-- focus list ({button,id,name,act,card}).
function Panel:layoutCards(width,cols,cardH,gap,focusIndex,compact)
 local Cards=require(script.Parent.CustomizeCards)
 local row=(self.state.petFinish or {})[self.petId]or {sheen=0,jelly=0}
 -- Bar: look name, notches, pips.
 local barH=if compact then 46 else 56
 self.bar.Position=UDim2.fromOffset(3,3);self.bar.Size=UDim2.fromOffset(width-6,barH)
 self.lookName.Text=Copy.get("r4.customize.finish.look",{look=Panel.lookName(row)});self.lookName.Size=UDim2.fromOffset(width-140,22)
 local accent=Art.color and Art.color("accent")or Color3.fromHex("#58DDC2")
 local soft=Color3.fromRGB(70,92,98)
 local sheen=math.clamp(row.sheen,-Look.SheenStops,Look.SheenStops)
 local span=math.min(width-110,300);local step=span/6
 for stop=-3,3 do
  local n=self.notches[stop];local on=stop==sheen;local size=if on then 16 else(if stop==0 then 10 else 8)
  n.Visible=math.abs(stop)<=Look.SheenStops
  n.Size=UDim2.fromOffset(size,size);n.Position=UDim2.fromOffset(4+(stop+3)*step-size/2+8,30-size/2+(if compact then -4 else 0))
  n.BackgroundColor3=if on then accent else soft
 end
 for stage=1,3 do
  local p=self.pips[stage];local on=stage<=row.jelly;p.Visible=stage<=Look.JellyStops
  p.Size=UDim2.fromOffset(12,12);p.Position=UDim2.fromOffset(span+40+(stage-1)*18,24+(if compact then -4 else 0))
  p.BackgroundColor3=if on then accent else soft
 end
 local legacy=(self.state.petMaterials or {})[self.petId]
 self.kept.Visible=legacy~=nil and legacy~=Materials.Default
 if self.kept.Visible then self.kept.Text=Copy.get("r4.customize.finish.kept",{finish=Materials.ById[legacy]and Materials.ById[legacy].name or legacy});self.kept.Position=UDim2.fromOffset(width-130,2)end
 local y0=barH+8
 local rects,h=Cards.rects(#Panel.Cards,width,cols,cardH,gap,y0)
 local focus={}
 for i,id in ipairs(Panel.Cards)do
  local node=self.cards[id];Cards.place(node,rects[i])
  local card=Panel.card(id,self.state,self.petId,self:ready())
  Cards.dress(node,{name=card.name,status=card.status,tone=if card.enabled then "soft"else "dim",icon=if card.axis then "drop"else nil,
   focused=i==focusIndex,compact=compact,isNew=self.options.isNew~=nil and not card.axis and self.options.isNew(id)==true})
  if not card.axis then JarArt.card(node,id)end
  node:SetAttribute("FinishCard",id);node:SetAttribute("Enabled",card.enabled)
  table.insert(focus,{button=node,id=id,name=card.name,card=card,act=function()return self:act(id)end})
 end
 local y=y0+h+8
 self.root.Size=UDim2.fromOffset(width,y);return y,focus
end
function Panel:destroy()self.root:Destroy()end
return Panel
