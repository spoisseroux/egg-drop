-- Round items carousel (ROUND-ITEMS-AND-BALL-THEMES-SCOPE A5, BUILD-PLAN 2026-11-13).
-- Sits inside the board, in the air above the fill line (at most 45% of the board
-- height), so Next / Then and every legally resting ball stay visible. While it is
-- open the board dims, a PAUSED chip shows and the round is frozen (the caller
-- feeds `isOpen` into syncPause). The server owns the belt; this only shows the
-- published belt and asks to use the middle item.
-- Also owns two small board notes: the desktop belt chip ("ITEMS ●●○ B") and the
-- fading note line (UICopy items.note.empty / items.note.full).
local Shared=game:GetService("ReplicatedStorage").Shared
local Kit=require(script.Parent.DeckKit)
local UICopy=require(Shared.UICopy)
local Items=require(Shared.RoundItems)
local Icons=require(script.Parent.ItemIcons)
local Carousel={}
Carousel.__index=Carousel
Carousel.NoteHold=1.5
Carousel.NoteFade=.35
Carousel.EmptyNote=UICopy.get("items.note.empty")
Carousel.FullNote=UICopy.get("items.note.full")
-- QA 2026-11-13: a power-up ball merge that grants an item says so ("+ Magnet").
Carousel.GrantLine="From a star ball"
Carousel.GrantHold=1.8

-- ── Pure helpers (spec-checked) ─────────────────────────────────────────────
function Carousel.wrap(index,delta,count)
 if count<=0 then return 0 end
 return (index-1+delta)%count+1
end
-- Side capsules: one item shows alone, two show the other on the right.
function Carousel.neighbours(index,count)
 if count<=1 then return nil,nil end
 if count==2 then return nil,Carousel.wrap(index,1,count)end
 return Carousel.wrap(index,-1,count),Carousel.wrap(index,1,count)
end
-- What a key does in a round. Closed: B (keyboard B, gamepad B or X) opens; the rest
-- passes through. Open: browse, use, close, and swallow everything else it binds.
function Carousel.keyAction(key,open)
 local K=Enum.KeyCode
 if not open then
  if key==K.B or key==K.ButtonB or key==K.ButtonX then return "open"end
  return nil
 end
 if key==K.Left or key==K.A or key==K.DPadLeft then return "left"end
 if key==K.Right or key==K.D or key==K.DPadRight then return "right"end
 if key==K.Space or key==K.Return or key==K.KeypadEnter or key==K.ButtonA then return "use"end
 if key==K.B or key==K.ButtonB or key==K.ButtonX or key==K.Backspace then return "close"end
 return "sink"
end
Carousel.Keys={Enum.KeyCode.B,Enum.KeyCode.ButtonB,Enum.KeyCode.ButtonX,Enum.KeyCode.Backspace,
 Enum.KeyCode.Left,Enum.KeyCode.Right,Enum.KeyCode.A,Enum.KeyCode.D,Enum.KeyCode.DPadLeft,Enum.KeyCode.DPadRight,
 Enum.KeyCode.Up,Enum.KeyCode.Down,Enum.KeyCode.W,Enum.KeyCode.S,Enum.KeyCode.DPadUp,Enum.KeyCode.DPadDown,
 Enum.KeyCode.Space,Enum.KeyCode.Return,Enum.KeyCode.KeypadEnter,Enum.KeyCode.ButtonA}
-- The one pause flag (clientUI.syncPause): a modal always; a deck layer (quest
-- log, Pocket Menu, item carousel, the Collection book opened over the round) only
-- while the round is live.
function Carousel.pauseWanted(state)
 local deck=(state.questLog or state.pocketMenu or state.carousel or state.book)and not state.roundOver
 return state.modal==true or deck==true
end

-- ── Instances ───────────────────────────────────────────────────────────────
local function capsule(parent,name)
 local c=Kit.frame(parent,name,"raised",UDim2.new(),UDim2.fromOffset(60,60),999)
 c.AnchorPoint=Vector2.new(.5,.5);c.BackgroundTransparency=0
 local ring=Kit.node("UIStroke",c,{Name="Ring",Thickness=2,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
 local glyph=Kit.text(c,"Title","",nil,{Name="Glyph",Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center,TextScaled=false,FontFace=Kit.Type.Heading[3]})
 -- The item's icon (ItemIcons); the glyph text stays as the fallback for an unknown id.
 local icon=Icons.new(c,nil,nil);icon.Size=UDim2.fromScale(.62,.62)
 local hit=Kit.node("TextButton",c,{Name="Hit",Text="",BackgroundTransparency=1,AutoButtonColor=false,Size=UDim2.fromScale(1,1),ZIndex=c.ZIndex+3,Selectable=false})
 return {root=c,ring=ring,glyph=glyph,icon=icon,hit=hit}
end
local function paintCapsule(cap,id,lit)
 local item=id and Items.ById[id]
 cap.root.Visible=item~=nil
 if not item then return end
 Icons.set(cap.icon,id)
 cap.glyph.Visible=Icons.source(id)==nil
 cap.glyph.Text=item.glyph
 cap.glyph.TextColor3=item.color
 cap.ring.Color=item.color
 cap.ring.Transparency=if lit then 0 else .45
 cap.root.BackgroundColor3=Kit.color("raised"):Lerp(item.color,if lit then .22 else .08)
 cap.glyph.TextTransparency=if lit then 0 else .35
end

function Carousel.new(parent,options)
 options=options or {}
 local z=options.z or 38
 local self=setmetatable({callbacks={},belt={},index=1,isOpen=false,phone=false,noteToken=0},Carousel)
 local host=Kit.node("Frame",parent,{Name="ItemCarousel",BackgroundTransparency=1,ZIndex=z,Active=false,Size=UDim2.fromOffset(0,0)})
 self.host=host
 -- Dimmed board: catches taps (tap to close) while the carousel is open.
 local dim=Kit.node("TextButton",host,{Name="Dim",Text="",AutoButtonColor=false,BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=.5,
  BorderSizePixel=0,Size=UDim2.fromScale(1,1),ZIndex=z+1,Visible=false,Selectable=false})
 dim.Activated:Connect(function()if self.callbacks.close then self.callbacks.close()end end)
 self.dim=dim
 local paused=Kit.frame(dim,"Paused","well",UDim2.new(.5,0,1,-8),UDim2.fromOffset(84,24),999)
 paused.AnchorPoint=Vector2.new(.5,1);paused.BackgroundTransparency=0;Kit.stroke(paused)
 Kit.text(paused,"Label","Paused","soft",{Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center})
 self.pausedChip=paused
 -- The panel: header, three capsules, name, effect, hint.
 local panel=Kit.frame(host,"Panel","panel",UDim2.new(),UDim2.fromOffset(300,220),14)
 panel.ZIndex=z+3;panel.BackgroundTransparency=.04;panel.Visible=false;panel.Active=true;panel.ClipsDescendants=true
 Kit.stroke(panel)
 self.panel=panel
 self.title=Kit.text(panel,"Label","Items","dim",{Name="Title"})
 self.count=Kit.text(panel,"Label","","dim",{Name="Count",TextXAlignment=Enum.TextXAlignment.Right})
 self.caps={left=capsule(panel,"Left"),mid=capsule(panel,"Middle"),right=capsule(panel,"Right")}
 self.caps.left.hit.Activated:Connect(function()self:move(-1)end)
 self.caps.right.hit.Activated:Connect(function()self:move(1)end)
 self.caps.mid.hit.Activated:Connect(function()if self.callbacks.use then self.callbacks.use()end end)
 self.prev=Kit.text(panel,"Heading","‹","soft",{Name="Prev",TextXAlignment=Enum.TextXAlignment.Center})
 self.nextArrow=Kit.text(panel,"Heading","›","soft",{Name="Next",TextXAlignment=Enum.TextXAlignment.Center})
 self.name=Kit.text(panel,"Name","",nil,{Name="ItemName",TextXAlignment=Enum.TextXAlignment.Center})
 self.effect=Kit.text(panel,"Small","","soft",{Name="Effect",TextXAlignment=Enum.TextXAlignment.Center,TextWrapped=true})
 self.hint=Kit.text(panel,"Small","","dim",{Name="Hint",TextXAlignment=Enum.TextXAlignment.Center})
 -- Desktop belt chip at the board's top left (the phone has the shoulder button).
 -- Each slot shows its item's icon (16 px) or a dim dot when empty.
 local chip=Kit.frame(host,"BeltChip","well",UDim2.fromOffset(8,8),UDim2.fromOffset(128,26),999)
 chip.ZIndex=z+1;chip.BackgroundTransparency=.15;chip.Visible=false;Kit.stroke(chip)
 Kit.text(chip,"Label","Items","dim",{Name="Caption",Position=UDim2.fromOffset(10,0),Size=UDim2.fromOffset(40,26)})
 self.dots,self.slotIcons={},{}
 for i=1,Items.BeltSize do
  local slot=Kit.frame(chip,"Slot"..i,nil,UDim2.fromOffset(49+(i-1)*17,5),UDim2.fromOffset(16,16))
  local dot=Kit.frame(slot,"Dot",nil,UDim2.fromScale(.5,.5),UDim2.fromOffset(10,10),999)
  dot.AnchorPoint=Vector2.new(.5,.5);dot.BackgroundTransparency=0;self.dots[i]=dot
  self.slotIcons[i]=Icons.new(slot,16,nil)
 end
 local bGlyph=Kit.glyph(chip,"B",false,18);bGlyph.Position=UDim2.new(1,-22,.5,-9)
 self.chip=chip
 -- Fading note line.
 local note=Kit.frame(host,"Note","well",UDim2.new(.5,0,.18,0),UDim2.fromOffset(180,32),999)
 note.AnchorPoint=Vector2.new(.5,.5);note.ZIndex=z+6;note.BackgroundTransparency=1;note.Visible=false
 self.noteText=Kit.text(note,"Strong","","text",{Name="Message",Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center,TextTransparency=1})
 self.noteStroke=Kit.stroke(note)
 self.note=note
 self:setBelt({})
 return self
end

function Carousel:on(name,callback)self.callbacks[name]=callback end

-- `position`/`size`: the board's rect in the parent (the board viewport's own UDim2s).
function Carousel:place(position,size,phone)
 self.host.Position=position;self.host.Size=size;self.phone=phone==true
 local W,H=size.X.Offset,size.Y.Offset
 if W<=0 or H<=0 then W,H=self.host.AbsoluteSize.X,self.host.AbsoluteSize.Y end
 self.W,self.H=W,H
 self:layout()
 self:refreshChip()
end

function Carousel:layout()
 local W,H=self.W or 300,self.H or 500
 local pad=math.max(6,math.floor(W*.03))
 local w=math.max(120,W-2*pad)
 local h=math.floor(math.min(H*.45,w*.82))
 local k=math.clamp(w/330,.45,1.4)
 self.panel.Position=UDim2.fromOffset(pad,pad);self.panel.Size=UDim2.fromOffset(w,h)
 self.panelRest=self.panel.Position
 local top=math.floor(8+10*k)
 local label=math.max(11,math.floor(13*k))
 self.title.Position=UDim2.fromOffset(12,4);self.title.Size=UDim2.fromOffset(w/2-12,top+6);self.title.TextSize=label
 self.count.Position=UDim2.fromOffset(w/2,4);self.count.Size=UDim2.fromOffset(w/2-12,top+6);self.count.TextSize=label
 local nameSize=math.clamp(math.floor(22*k),14,26)
 local effectSize=math.clamp(math.floor(14*k),12,16)
 local hintSize=math.clamp(math.floor(13*k),11,15)
 local bottom=h-6-hintSize-4
 local effectY=bottom-effectSize*2-4
 local nameY=effectY-nameSize-4
 local band=nameY-(top+10)
 local mid=math.clamp(math.floor(math.min(band-4,w*.34)),40,120)
 local side=math.max(30,math.floor(mid*.68))
 local cy=top+10+math.floor(band/2)
 local spread=math.floor(mid/2+side/2+math.max(6,w*.05))
 self.geometry={mid=mid,side=side,cy=cy,spread=spread,cx=math.floor(w/2)}
 self:placeCaps(false)
 local arrowW=math.max(16,math.floor(20*k))
 self.prev.Position=UDim2.fromOffset(2,cy-12);self.prev.Size=UDim2.fromOffset(arrowW,24)
 self.nextArrow.Position=UDim2.fromOffset(w-arrowW-2,cy-12);self.nextArrow.Size=UDim2.fromOffset(arrowW,24)
 self.name.Position=UDim2.fromOffset(8,nameY);self.name.Size=UDim2.fromOffset(w-16,nameSize+4);self.name.TextSize=nameSize
 self.effect.Position=UDim2.fromOffset(10,effectY);self.effect.Size=UDim2.fromOffset(w-20,effectSize*2+2);self.effect.TextSize=effectSize
 self.hint.Position=UDim2.fromOffset(8,bottom);self.hint.Size=UDim2.fromOffset(w-16,hintSize+4);self.hint.TextSize=hintSize
 for _,cap in pairs(self.caps)do cap.glyph.TextSize=math.floor((if cap==self.caps.mid then mid else side)*.5)end
 self.note.Position=UDim2.new(.5,0,0,math.floor(math.min(H*.2,h*.5)))
 self:paint()
end

function Carousel:placeCaps(animate)
 local g=self.geometry;if not g then return end
 local spots={left=g.cx-g.spread,mid=g.cx,right=g.cx+g.spread}
 for key,cap in pairs(self.caps)do
  local d=if key=="mid"then g.mid else g.side
  local goal={Position=UDim2.fromOffset(spots[key],g.cy),Size=UDim2.fromOffset(d,d)}
  if animate then
   -- Slide in from the side the player moved toward (120 ms Quad Out; Reduced Motion cuts).
   cap.root.Position=UDim2.fromOffset(spots[key]+(self.lastMove or 0)*math.floor(g.spread*.35),g.cy)
   Kit.tween(cap.root,.12,goal)
  else cap.root.Position=goal.Position;cap.root.Size=goal.Size end
 end
end

function Carousel:paint()
 local belt,count=self.belt,#self.belt
 if count==0 then self.index=1 else self.index=math.clamp(self.index,1,count)end
 local left,right=Carousel.neighbours(self.index,count)
 paintCapsule(self.caps.mid,belt[self.index],true)
 paintCapsule(self.caps.left,left and belt[left],false)
 paintCapsule(self.caps.right,right and belt[right],false)
 self.prev.Visible=count>1;self.nextArrow.Visible=count>1
 local item=Items.ById[belt[self.index]or ""]
 self.name.Text=if item then item.name else ""
 self.effect.Text=if item then(if self.phone then item.short else item.effect)else ""
 self.count.Text=if count>0 then string.format("%d of %d",self.index,count)else ""
 self.count.Text=string.upper(self.count.Text)
 self.hint.Text=if self.phone then "Tap to use"else "◀▶ Browse    A Use    B Close"
 self.caps.mid.hit:SetAttribute("AccessibleLabel",if item then "Use "..item.name else "No item")
end

-- `belt`: the published belt (list of ids). Keeps the selected item when it is still there.
function Carousel:setBelt(belt)
 local current=self.belt[self.index]
 self.belt=table.clone(belt or {})
 local keep=current and table.find(self.belt,current)
 self.index=keep or math.clamp(self.index,1,math.max(1,#self.belt))
 if #self.belt==0 and self.isOpen then self:close(true)end
 self:paint();self:refreshChip()
end

function Carousel:setChipVisible(visible)
 self.chipWanted=visible==true;self:refreshChip()
end
function Carousel:refreshChip()
 self.chip.Visible=self.chipWanted==true and not self.phone and not self.isOpen
 for i,dot in ipairs(self.dots)do
  local id=self.belt[i]
  local item=Items.ById[id or ""]
  local drawn=item~=nil and Icons.source(id)~=nil
  Icons.set(self.slotIcons[i],if item then id else nil)
  dot.Visible=not drawn
  dot.BackgroundColor3=if item then item.color else Kit.Color.white
  dot.BackgroundTransparency=if item then 0 else .8
 end
end

-- Returns false (and shows the empty note) when there is nothing to choose.
function Carousel:open()
 if self.isOpen then return false end
 if #self.belt==0 then self:showNote(Carousel.EmptyNote);return false end
 self.isOpen=true;self.lastMove=0
 self.dim.Visible=true;self.panel.Visible=true
 self:paint();self:placeCaps(false);self:refreshChip()
 local rest=self.panelRest or self.panel.Position
 if not Kit.reduced()then self.panel.Position=rest-UDim2.fromOffset(0,14)end
 Kit.tween(self.panel,.14,{Position=rest})
 return true
end
function Carousel:close(instant)
 if not self.isOpen then return false end
 self.isOpen=false
 self.dim.Visible=false;self.panel.Visible=false
 if self.panelRest then self.panel.Position=self.panelRest end
 self:refreshChip()
 return true
end
function Carousel:move(delta)
 local count=#self.belt
 if not self.isOpen or count<2 or delta==0 then return false end
 self.index=Carousel.wrap(self.index,if delta<0 then -1 else 1,count)
 self.lastMove=if delta<0 then -1 else 1
 self:paint();self:placeCaps(true)
 if self.callbacks.moved then self.callbacks.moved(self.index)end
 return true
end
function Carousel:selected()
 if not self.isOpen then return nil end
 return self.belt[self.index],self.index
end

-- A short note on the board that softly fades after ~1.5 s (Reduced Motion: it just goes).
function Carousel:showNote(text)
 self.noteToken+=1;local token=self.noteToken
 local note,label=self.note,self.noteText
 local size=Kit.measure(text,"Strong",label.TextSize)
 note.Size=UDim2.fromOffset(math.ceil(size.X)+32,math.max(32,label.TextSize+14))
 label.Text=text;note.Visible=true
 note.BackgroundTransparency=.1;label.TextTransparency=0;self.noteStroke.Transparency=Kit.Stroke.transparency
 self.lastNote=text
 task.delay(Carousel.NoteHold,function()
  if self.noteToken~=token then return end
  if Kit.reduced()then note.Visible=false;return end
  Kit.tween(note,Carousel.NoteFade,{BackgroundTransparency=1})
  Kit.tween(label,Carousel.NoteFade,{TextTransparency=1})
  Kit.tween(self.noteStroke,Carousel.NoteFade,{Transparency=1})
  task.delay(Carousel.NoteFade,function()if self.noteToken==token then note.Visible=false end end)
 end)
end

-- Grant toast (QA 2026-11-13): "+ Magnet" with the item's icon and where it came
-- from, popping in over the board, held ~1.8 s, then fading (Reduced Motion: no pop,
-- it just goes). The belt chip boings so the eye finds the new slot.
function Carousel.grantText(id)
 local item=Items.ById[id or ""]
 return if item then "+ "..item.name else nil
end
function Carousel:showGrant(id)
 local text=Carousel.grantText(id);if not text then return false end
 self.grantToken=(self.grantToken or 0)+1;local token=self.grantToken
 local toast=self.grant
 if not toast then
  local z=self.host.ZIndex
  local root=Kit.frame(self.host,"Grant","well",UDim2.new(.5,0,0,0),UDim2.fromOffset(200,52),999)
  root.AnchorPoint=Vector2.new(.5,.5);root.ZIndex=z+7;root.BackgroundTransparency=.06;root.Visible=false
  local stroke=Kit.stroke(root,nil,1.5,0)
  local scale=Kit.node("UIScale",root,{Scale=1})
  local disc=Kit.frame(root,"IconDisc","raised",UDim2.fromOffset(8,8),UDim2.fromOffset(36,36),999);disc.BackgroundTransparency=0
  local icon=Icons.new(disc,26,nil)
  local title=Kit.text(root,"Name","",nil,{Name="Title",Position=UDim2.fromOffset(52,5),Size=UDim2.fromOffset(140,24),TextSize=18})
  local line=Kit.text(root,"Small","","soft",{Name="Line",Position=UDim2.fromOffset(52,27),Size=UDim2.fromOffset(140,18),TextSize=12})
  toast={root=root,stroke=stroke,scale=scale,disc=disc,icon=icon,title=title,line=line}
  self.grant=toast
 end
 local item=Items.ById[id]
 Icons.set(toast.icon,id)
 toast.title.Text=text;toast.line.Text=Carousel.GrantLine
 toast.title.TextColor3=item.color:Lerp(Kit.Color.text,.35);toast.stroke.Color=item.color
 toast.disc.BackgroundColor3=Kit.color("raised"):Lerp(item.color,.22)
 local w=math.max(Kit.measure(text,"Name",18).X,Kit.measure(Carousel.GrantLine,"Small",12).X)
 toast.root.Size=UDim2.fromOffset(math.ceil(w)+52+18,52)
 toast.title.Size=UDim2.fromOffset(math.ceil(w)+8,24);toast.line.Size=UDim2.fromOffset(math.ceil(w)+8,18)
 toast.root.Position=UDim2.new(.5,0,0,math.floor(math.min((self.H or 500)*.28,(self.H or 500)*.45-30)))
 toast.root:SetAttribute("Item",id)
 for _,node in ipairs({toast.title,toast.line})do node.TextTransparency=0 end
 toast.root.BackgroundTransparency=.06;toast.stroke.Transparency=0;toast.root.Visible=true
 self.lastGrant=text
 if Kit.reduced()then toast.scale.Scale=1
 else toast.scale.Scale=.7;Kit.tween(toast.scale,.18,{Scale=1},Enum.EasingStyle.Back);Kit.boing(self.chip)end
 task.delay(Carousel.GrantHold,function()
  if self.grantToken~=token then return end
  if Kit.reduced()then toast.root.Visible=false;return end
  for _,node in ipairs({toast.title,toast.line})do Kit.tween(node,Carousel.NoteFade,{TextTransparency=1})end
  Kit.tween(toast.root,Carousel.NoteFade,{BackgroundTransparency=1});Kit.tween(toast.stroke,Carousel.NoteFade,{Transparency=1})
  task.delay(Carousel.NoteFade,function()if self.grantToken==token then toast.root.Visible=false end end)
 end)
 return true
end

function Carousel:destroy()self.host:Destroy()end

return Carousel
