-- Stamp card (play-forever F2; BUILD-PLAN rules, StampCard.lua). Drawn where the daily
-- gift is offered: the Pocket menu's daily page (DeckMenu) and the Hatch eggs list
-- (EggHatchView). Seven slots; the stamps already on this card are filled, the slot
-- the next stamp lands in shows its reward, and the 7th (12 Stars) is the bigger gift
-- in Stars gold. A claim lands the stamp with Kit.boing and a "+N Stars" pop (both cut
-- under Reduced Motion: the pop then just shows and hides). No streak, no penalty:
-- the line under the card says so.
--
-- Presentation only. The caller keeps its own claim button (the `daily` action); this
-- view reads the snapshot (`stamps`, `stampCard = {rewards, onCard, next}`,
-- `dailyAvailable`) and notices a new stamp by the count going up by one.
local Shared=game:GetService("ReplicatedStorage").Shared
local Stamp=require(Shared.StampCard)
local UICopy=require(Shared.UICopy)
local Kit=require(script.Parent.DeckKit)
local View={}
View.__index=View
View.Length=Stamp.Length
View.PopSeconds=1.2
-- Regular / compact (phone, short sheets) measurements.
View.Metrics=table.freeze({
 regular=table.freeze({head=18,slot=52,line=20,gap=6,slotGap=8,label=13,reward=15,small=14}),
 compact=table.freeze({head=16,slot=40,line=16,gap=4,slotGap=6,label=12,reward=13,small=12}),
})
View.StampColor=Kit.Tint.hatch -- peach ink on the stamps (the gift lives with Hatch eggs)
-- Stamp art (QA 2026-11-13 Q5): seven original rubber stamps, one per slot, drawn by
-- scripts/deck_art/build_stamps.py into assets/ui/stamps/. One atlas upload: row 0 the
-- full-colour stamps (a stamped slot), row 1 their white outlines (an upcoming slot,
-- tinted and faded). `atlas` stays nil until the upload; then the vector fallback
-- (a disc in the stamp's colour with a check; a faint ring under the reward) steps aside.
View.Art={atlas="rbxassetid://105525503357374",cell=128,
 designs=table.freeze({
  table.freeze({name="paw",color=Color3.fromRGB(255,158,196)}),
  table.freeze({name="star",color=Color3.fromRGB(140,200,255)}),
  table.freeze({name="egg",color=Color3.fromRGB(255,169,143)}),
  table.freeze({name="ball",color=Color3.fromRGB(127,224,200)}),
  table.freeze({name="flower",color=Color3.fromRGB(201,167,255)}),
  table.freeze({name="heart",color=Color3.fromRGB(255,122,147)}),
  table.freeze({name="crown",color=Kit.Color.stars}),
 })}
View.OutlineTransparency=.62 -- an upcoming slot's outline: faint, under its reward

-- Pure: the card from a snapshot.
-- Returns {rewards, filled (0..7), nextIndex (1..7), available, full, reward, stamps}.
function View.model(state)
 state=type(state)=="table"and state or {}
 local card=if type(state.stampCard)=="table"then state.stampCard else {}
 local stamps=if type(state.stamps)=="number"and state.stamps==state.stamps and state.stamps>=0 then math.floor(state.stamps)else 0
 local rewards=if type(card.rewards)=="table"and #card.rewards==Stamp.Length then card.rewards else Stamp.Rewards
 local onCard=if type(card.onCard)=="number"then math.clamp(math.floor(card.onCard),0,Stamp.Length-1)else Stamp.onCard(stamps)
 local available=state.dailyAvailable==true
 -- Today's stamp finished the card (stamps % 7 == 0 after a claim): it stays full until tomorrow.
 local full=not available and stamps>0 and onCard==0
 local filled=if full then Stamp.Length else onCard
 local nextIndex=if full then 1 else onCard+1
 return{rewards=rewards,filled=filled,nextIndex=nextIndex,available=available,full=full,reward=rewards[nextIndex],stamps=stamps}
end
-- Pure: one row per slot {index, reward, filled, next, today, big}.
function View.slots(model)
 local out={}
 for index=1,Stamp.Length do
  local filled=index<=model.filled
  out[index]={index=index,reward=model.rewards[index],filled=filled,next=not filled and index==model.nextIndex,
   today=model.available and not filled and index==model.nextIndex,big=index==Stamp.Length}
 end
 return out
end
-- Pure: the line under the card.
function View.line(model)
 if model.available then return UICopy.get("stamp.next",{reward=model.reward})end
 if model.full then return UICopy.get("stamp.full")end
 return UICopy.get("stamp.tomorrow",{reward=model.reward})
end
-- Pure: the caller's claim button text.
function View.buttonText(state)
 local model=View.model(state)
 if model.available then return UICopy.get("stamp.button",{reward=model.reward})end
 return UICopy.get("stamp.done")
end
-- Pure: the design for a slot (1..7): {name, color}.
function View.design(index)
 local designs=View.Art.designs
 return designs[math.clamp(math.floor(index or 1),1,#designs)]
end
-- Pure: the art for a slot, or nil while the atlas has no id (the vector fallback).
-- Returns {image, offset (Vector2), size (Vector2)}; `filled` picks the full-colour
-- row, otherwise the outline row.
function View.artFor(index,filled)
 local art=View.Art
 if type(art.atlas)~="string"or art.atlas==""then return nil end
 local column=math.clamp(math.floor(index or 1),1,#art.designs)-1
 return{image=art.atlas,offset=Vector2.new(column*art.cell,if filled then 0 else art.cell),size=Vector2.new(art.cell,art.cell)}
end
-- Pure: the height the card takes at a width (layout reserves it before building).
function View.height(compact)
 local m=if compact then View.Metrics.compact else View.Metrics.regular
 return m.head+m.gap+m.slot+m.gap+m.line
end

local function txt(parent,role,content,color,props)return Kit.text(parent,role,content,color,props)end

-- parent: any GuiObject. options: name.
function View.new(parent,options)
 options=options or {}
 local root=Kit.frame(parent,options.name or "StampCard",nil,UDim2.new(),UDim2.fromOffset(300,View.height(false)))
 root:SetAttribute("StampCard",true)
 local self=setmetatable({root=root,slotViews={},compact=false,width=300,lastStamps=nil,popToken=0},View)
 self.title=txt(root,"Label",UICopy.get("stamp.title"),"dim",{Name="Title"})
 Kit.tintEyebrow(self.title,"hatch")
 self.promise=txt(root,"Small",UICopy.get("stamp.promise"),"soft",{Name="Promise",TextXAlignment=Enum.TextXAlignment.Right,TextTruncate=Enum.TextTruncate.AtEnd})
 local row=Kit.frame(root,"Slots",nil,UDim2.new(),UDim2.fromOffset(300,52));self.row=row
 for index=1,Stamp.Length do
  local slot=Kit.frame(row,"Slot"..index,"well",UDim2.new(),UDim2.fromOffset(36,52),10)
  local stroke=Kit.stroke(slot)
  local design=View.design(index)
  -- Upcoming: the stamp's outline (art) or a faint ring (fallback), under the reward.
  local ghost=Kit.node("ImageLabel",slot,{Name="StampOutline",BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
   Size=UDim2.fromOffset(28,28),ImageTransparency=View.OutlineTransparency,ZIndex=slot.ZIndex+1,Visible=false})
  local ghostRing=Kit.frame(slot,"StampGhost",nil,UDim2.fromScale(.5,.5),UDim2.fromOffset(28,28),999)
  ghostRing.AnchorPoint=Vector2.new(.5,.5);ghostRing.Visible=false
  Kit.node("UIStroke",ghostRing,{Name="GhostRing",Thickness=1.5,Color=design.color,Transparency=.7,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
  local reward=txt(slot,"Counter","","soft",{Name="Reward",Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center})
  reward.ZIndex=slot.ZIndex+3
  -- Stamped: the full-colour stamp (art) or a disc in the stamp's colour with a check.
  local art=Kit.node("ImageLabel",slot,{Name="StampArt",BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
   Size=UDim2.fromOffset(28,28),Rotation=-8,ZIndex=slot.ZIndex+2,Visible=false})
  local mark=Kit.frame(slot,"Stamp",nil,UDim2.fromScale(.5,.5),UDim2.fromOffset(28,28),999)
  mark.AnchorPoint=Vector2.new(.5,.5);mark.BackgroundTransparency=0;mark.BackgroundColor3=design.color;mark.Rotation=-8
  Kit.node("UIStroke",mark,{Name="StampRing",Thickness=2,Color=Kit.Sticker.cream,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
  local check=Kit.icon(mark,"check",18,"ink");check.AnchorPoint,check.Position=Vector2.new(.5,.5),UDim2.fromScale(.5,.5)
  slot:SetAttribute("StampDesign",design.name)
  self.slotViews[index]={frame=slot,stroke=stroke,reward=reward,mark=mark,check=check,art=art,ghost=ghost,ghostRing=ghostRing,design=design}
 end
 self.lineLabel=txt(root,"Small","","soft",{Name="Line",TextTruncate=Enum.TextTruncate.AtEnd})
 -- "+N Stars" pop over the landed slot (one label, reused).
 self.pop=txt(root,"Counter","","stars",{Name="Pop",TextXAlignment=Enum.TextXAlignment.Center,Visible=false})
 self.pop.ZIndex=root.ZIndex+8
 return self
end

-- Lays the card out `width` wide; returns its height.
function View:layout(width,compact)
 self.width=math.max(120,math.floor(width or self.width));self.compact=compact==true
 local m=if self.compact then View.Metrics.compact else View.Metrics.regular
 local W=self.width
 local h=View.height(self.compact)
 self.root.Size=UDim2.fromOffset(W,h)
 self.title.TextSize=m.label;self.title.Position=UDim2.fromOffset(0,0);self.title.Size=UDim2.fromOffset(math.min(140,W),m.head)
 local titleW=Kit.measure(self.title.Text,"Label",m.label).X+14+12
 self.promise.TextSize=m.small;self.promise.Position=UDim2.fromOffset(titleW,0);self.promise.Size=UDim2.fromOffset(math.max(0,W-titleW),m.head)
 -- The promise is the voice of the card; it shows only when it fits whole.
 self.promise.Visible=Kit.measure(self.promise.Text,"Small",m.small).X<=W-titleW
 local y=m.head+m.gap
 self.row.Position=UDim2.fromOffset(0,y);self.row.Size=UDim2.fromOffset(W,m.slot)
 local slotW=math.floor((W-(Stamp.Length-1)*m.slotGap)/Stamp.Length)
 local used=slotW*Stamp.Length+(Stamp.Length-1)*m.slotGap
 local x0=math.floor((W-used)/2)
 local disc=math.max(18,math.min(slotW,m.slot)-12)
 -- The art is a seal with scalloped edges: a little larger than the disc, never past the slot.
 local seal=math.max(18,math.min(slotW,m.slot)-4)
 for index,slot in ipairs(self.slotViews)do
  slot.frame.Position=UDim2.fromOffset(x0+(index-1)*(slotW+m.slotGap),0);slot.frame.Size=UDim2.fromOffset(slotW,m.slot)
  slot.reward.TextSize=m.reward
  slot.mark.Size=UDim2.fromOffset(disc,disc)
  slot.art.Size=UDim2.fromOffset(seal,seal);slot.ghost.Size=UDim2.fromOffset(seal,seal);slot.ghostRing.Size=UDim2.fromOffset(disc,disc)
  local c=math.max(12,math.floor(disc*.62));slot.check.Size=UDim2.fromOffset(c,c)
 end
 self.slotW=slotW
 y+=m.slot+m.gap
 self.lineLabel.TextSize=m.small;self.lineLabel.Position=UDim2.fromOffset(0,y);self.lineLabel.Size=UDim2.fromOffset(W,m.line)
 self.pop.TextSize=m.reward
 if self.cardModel then self:paint()end
 return h
end

function View:paint()
 local model=self.cardModel;if not model then return end
 for index,row in ipairs(View.slots(model))do
  local slot=self.slotViews[index]
  -- Stamped = full colour, upcoming = faint outline (art when uploaded, else vector).
  local art=View.artFor(index,row.filled)
  slot.art.Visible=row.filled and art~=nil
  slot.mark.Visible=row.filled and art==nil
  slot.ghost.Visible=not row.filled and art~=nil
  slot.ghostRing.Visible=not row.filled and art==nil
  if art then
   local image=if row.filled then slot.art else slot.ghost
   image.Image=art.image;image.ImageRectOffset=art.offset;image.ImageRectSize=art.size
   if not row.filled then slot.ghost.ImageColor3=if row.big then Kit.Color.stars else slot.design.color end
  end
  slot.frame:SetAttribute("StampArt",art~=nil)
  slot.reward.Visible=not row.filled
  slot.reward.Text="+"..tostring(row.reward)
  local tone=if row.big then "stars"elseif row.today then "text"else "soft"
  Kit.paint(slot.reward,"TextColor3",function()return Kit.Color[tone]end)
  -- The 7th slot is the bigger gift (gold); the slot today's stamp lands in is the
  -- action (mint, 2 px); the rest keep the 1 px card stroke.
  if row.big then
   slot.stroke.Thickness=2;slot.stroke.Transparency=if row.filled then .5 else 0;Kit.paint(slot.stroke,"Color",function()return Kit.Color.stars end)
  elseif row.today then
   slot.stroke.Thickness=2;slot.stroke.Transparency=0;Kit.paint(slot.stroke,"Color",function()return Kit.color("accent")end)
  else
   slot.stroke.Thickness=1;slot.stroke.Transparency=Kit.Stroke.transparency;Kit.paint(slot.stroke,"Color",function()return Kit.Stroke.color end)
  end
  slot.frame:SetAttribute("Filled",row.filled);slot.frame:SetAttribute("Next",row.next);slot.frame:SetAttribute("Today",row.today)
  slot.frame:SetAttribute("Big",row.big);slot.frame:SetAttribute("Reward",row.reward)
 end
 self.lineLabel.Text=View.line(model)
 local lineTone=if model.available then "text"else "soft"
 Kit.paint(self.lineLabel,"TextColor3",function()return Kit.Color[lineTone]end)
 self.root:SetAttribute("Filled",model.filled);self.root:SetAttribute("NextReward",model.reward)
 self.root:SetAttribute("AccessibleLabel",UICopy.get("stamp.title")..", "..model.filled.." of "..Stamp.Length..". "..self.lineLabel.Text)
end

-- state: the snapshot. A stamp count one higher than the last one seen lands the stamp.
function View:set(state)
 local model=View.model(state)
 local landed=self.lastStamps~=nil and model.stamps==self.lastStamps+1
 self.lastStamps=model.stamps;self.cardModel=model
 self:paint()
 if landed then
  local index=if model.filled>0 then model.filled else Stamp.Length
  self:land(index,model.rewards[index])
 end
 return landed
end

-- The stamp lands: boing on the slot (nothing under Reduced Motion) and a "+N Stars" pop.
function View:land(index,reward)
 local slot=self.slotViews[index];if not slot then return end
 Kit.boing(slot.frame)
 self.popToken+=1;local token=self.popToken
 local pop=self.pop
 pop.Text=UICopy.get("stamp.landed",{reward=reward or 0})
 local w=math.ceil(Kit.measure(pop.Text,"Counter",pop.TextSize).X)+8
 local m=if self.compact then View.Metrics.compact else View.Metrics.regular
 local cx=slot.frame.Position.X.Offset+slot.frame.Size.X.Offset/2
 local x=math.clamp(cx-w/2,0,math.max(0,self.width-w))
 local y=m.head+m.gap-(m.reward+4)
 pop.Size=UDim2.fromOffset(w,m.reward+4);pop.Visible=true;pop.TextTransparency=0
 self.root:SetAttribute("LandedSlot",index)
 if Kit.reduced()then
  pop.Position=UDim2.fromOffset(x,y)
 else
  pop.Position=UDim2.fromOffset(x,y+8)
  Kit.tween(pop,.24,{Position=UDim2.fromOffset(x,y)})
 end
 task.delay(View.PopSeconds,function()
  if self.popToken~=token or not pop.Parent then return end
  if Kit.reduced()then pop.Visible=false;return end
  Kit.tween(pop,.2,{TextTransparency=1})
  task.delay(.22,function()if self.popToken==token and pop.Parent then pop.Visible=false end end)
 end)
end

function View:destroy()self.popToken+=1;self.root:Destroy()end
return View
