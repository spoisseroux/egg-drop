-- Customize Material tab (was Finish; UI-SPEC-v816 section 2, Customization Egg plan
-- 2026-11-16 §4 and §5.3). Material jars are doses, not unlocks.
--  * Shine: one axis from -3 (Matte 3/3) to +3 (Gloss 3/3). A Matte jar moves it one stop
--    down, a Gloss jar one stop up, so they cancel. Jelly: a second axis, 0 to 3 stages.
--  * A read-only meter card shows both axes (no hit areas). Three jar cards (Gloss, Matte,
--    Jelly) carry a Use / Max / ×0 pill; the whole card is the tap target and previews.
--  * Footer: "Find jars in the Customization Egg ›" while the player has no jars at all,
--    and one "Back to original" that resets both axes. The server clears one axis per
--    request (LookState, kept so a rollback to v806+ still reads every receipt), so the
--    reset sends Shine first and then Jelly once the first one settles.
--  * A legacy permanent material (petMaterials) still renders; the dose look wins over it.
-- HueEggView mounts it; the panel owns its meter, cards, footer and the pane text.
local Shared=game:GetService("ReplicatedStorage").Shared
local TweenService=game:GetService("TweenService")
local Look=require(Shared.LookEggCatalog)
local Copy=require(Shared.UICopy)
local Kit=require(script.Parent.DeckKit)
local JarArt=require(script.Parent.HueJarArt)
local Panel={};Panel.__index=Panel
Panel.Jars={"gloss","matte","jelly"}
Panel.Cards=Panel.Jars -- older callers: the card ids
Panel.Reset="original"
Panel.MeterTime=.2
local sheenKeys={[-3]="m3",[-2]="m2",[-1]="m1",[0]="zero",[1]="p1",[2]="p2",[3]="p3"}
local function c(key,vars)return Copy.get("r4.customize.finish."..key,vars)end

-- Pure: the look name for a material row (stored values clamp to the display stops).
function Panel.lookName(row)
 row=if Look.validFinish(row)then row else {sheen=0,jelly=0}
 local sheen=math.clamp(row.sheen,-Look.SheenStops,Look.SheenStops);local jelly=math.min(row.jelly,Look.JellyStops)
 local sheenName=c("sheen."..sheenKeys[sheen])
 if jelly==0 then return sheenName end
 local jellyName=c("jelly.s"..jelly)
 if sheen==0 then return jellyName end
 return c("mix",{jelly=jellyName,sheen=sheenName})
end
-- Pure: a pet's row, clamped to the display stops.
function Panel.row(state,petId)
 local row=((state or {}).petFinish or {})[petId]
 if not Look.validFinish(row)then return {sheen=0,jelly=0}end
 return {sheen=math.clamp(row.sheen,-Look.SheenStops,Look.SheenStops),jelly=math.clamp(row.jelly,0,Look.JellyStops)}
end
-- Pure: the Shine meter's words ("Original", "Gloss 2/3", "Matte 1/3") and Jelly's "n/3".
function Panel.shineWords(sheen)
 if sheen==0 then return c("sheen.zero")end
 return c("stop",{item=c("jar."..(if sheen>0 then "gloss"else "matte")),count=math.abs(sheen),total=Look.SheenStops})
end
function Panel.jellyWords(jelly)return c("jellyCount",{count=jelly,total=Look.JellyStops})end
-- Pure: true when the player holds no material jars at all.
function Panel.noJars(state)
 local stock=(state or {}).finishInventory or {}
 for _,id in ipairs(Panel.Jars)do if(stock[id]or 0)>0 then return false end end
 return true
end
-- Pure: "Back to original" shows only off the original look.
function Panel.canReset(row)return row.sheen~=0 or row.jelly>0 end
-- Pure: the state of one card for a pet. Returns {id,name,status,count,enabled,reason,line,
-- button,pill,free,reset}. pill: "use", "max" or "none".
function Panel.card(id,state,petId,ready)
 state=state or {}
 local row=Panel.row(state,petId)
 if id==Panel.Reset or id=="originalSheen"or id=="originalJelly"then
  local off=Panel.canReset(row)
  return {id=Panel.Reset,reset=true,name=c("reset"),status="",enabled=ready and off,free=true,
   line=if off then c("clearLine",{look=Panel.lookName(row)})else c("already"),button=c("reset")}
 end
 local stock=(state.finishInventory or {})
 local count=stock[id]or 0
 local after,reason=Look.step(row,id)
 local jar=c("jar."..id)
 local line,pill,button
 if count<1 then line=c("eggLink");pill="none";button=c("noJars",{item=jar})
 elseif not after then line=c(if reason=="MaxJelly"then "maxJelly"else "maxSheen");pill="max";button=c("useJar",{item=jar})
 else line=Panel.lookName(row).." → "..Panel.lookName(after);pill="use";button=c("useJar",{item=jar})end
 return {id=id,name=jar,status="×"..count,count=count,enabled=ready and count>0 and after~=nil,reason=if count<1 then "EmptyStock"else reason,
  line=line,pill=pill,button=button}
end

-- ── Instances ───────────────────────────────────────────────────────────────
local function label(parent,name,role,color,size,align)
 local t=Kit.text(parent,role,"",color,{Name=name,TextSize=size,TextXAlignment=align or Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd})
 return t
end
local function pill(parent,name,z)
 local p=Kit.frame(parent,name,nil,UDim2.new(),UDim2.fromOffset(52,24),999);p.ZIndex=z
 local stroke=Instance.new("UIStroke");stroke.Name="PillStroke";stroke.Thickness=1;stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;stroke.Parent=p
 local t=Kit.text(p,"Strong","","text",{Name="PillText",Size=UDim2.fromScale(1,1),TextSize=13,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=z+1})
 return p,stroke,t
end

function Panel.new(parent,intent,options)
 local root=Instance.new("Frame");root.Name="Finish";root.BackgroundTransparency=1;root.Visible=false;root.ZIndex=parent.ZIndex+1;root.Parent=parent
 local self=setmetatable({root=root,intent=intent,options=options or {},cards={},pills={},dims={},state={},resetQueue=nil},Panel)
 local Cards=require(script.Parent.CustomizeCards)
 -- Meter card: read-only (no hit areas, no hover, no focus ring).
 local meter=Kit.frame(root,"Meter","raised",UDim2.new(),UDim2.fromOffset(200,87),12);Kit.stroke(meter)
 meter:SetAttribute("ReadOnly",true);self.meter=meter
 local z=meter.ZIndex
 self.shineTitle=label(meter,"ShineTitle","Title","text",16);self.shineTitle.Text=c("shine")
 self.shineWord=label(meter,"ShineWord","Small","accent",13,Enum.TextXAlignment.Right)
 self.track=Kit.frame(meter,"ShineTrack","well",UDim2.new(),UDim2.fromOffset(100,6),999);self.track.ZIndex=z+1
 self.ticks={}
 for stop=-3,3 do
  local t=Kit.frame(meter,"Tick"..stop,"soft",UDim2.new(),UDim2.fromOffset(2,stop==0 and 14 or 10),999);t.ZIndex=z+2;t.BackgroundTransparency=if stop==0 then .2 else .5
  self.ticks[stop]=t
 end
 self.fill=Kit.frame(meter,"ShineFill","accent",UDim2.new(),UDim2.fromOffset(0,6),999);self.fill.ZIndex=z+3
 self.marker=Kit.frame(meter,"ShineMarker","accent",UDim2.new(),UDim2.fromOffset(18,18),999);self.marker.ZIndex=z+4;self.marker.AnchorPoint=Vector2.new(.5,.5)
 local ring=Instance.new("UIStroke");ring.Name="MarkerRing";ring.Color=Color3.new(1,1,1);ring.Thickness=2;ring.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;ring.Parent=self.marker
 self.endMatte=Kit.text(meter,"Label",c("jar.matte"),"soft",{Name="EndMatte",TextSize=11})
 self.endGloss=Kit.text(meter,"Label",c("jar.gloss"),"soft",{Name="EndGloss",TextSize=11,TextXAlignment=Enum.TextXAlignment.Right})
 self.divider=Kit.frame(meter,"Divider",nil,UDim2.new(),UDim2.fromOffset(1,40));self.divider.BackgroundTransparency=.86;self.divider.BackgroundColor3=Color3.new(1,1,1)
 self.jellyTitle=label(meter,"JellyTitle","Title","text",16);self.jellyTitle.Text=c("jellyAxis")
 self.jellyWord=label(meter,"JellyWord","Counter","soft",13,Enum.TextXAlignment.Right)
 self.segments={}
 for stage=1,3 do
  local s=Kit.frame(meter,"Segment"..stage,nil,UDim2.new(),UDim2.fromOffset(20,6),999);s.BackgroundTransparency=0;s.ZIndex=z+2
  self.segments[stage]=s
 end
 self.helper=label(meter,"Helper","Small","soft",12);self.helper.Text=c("helper")
 -- Jar cards.
 for _,id in ipairs(Panel.Jars)do
  local card=Cards.new(root,"FinishCard_"..id);self.cards[id]=card
  self.pills[id]={pill(card,"StatePill",card.ZIndex+6)}
  local dim=Kit.frame(card,"EmptyDim","panel",UDim2.new(),UDim2.fromScale(1,1),12);dim.BackgroundTransparency=.5;dim.ZIndex=card.ZIndex+8;dim.Visible=false
  self.dims[id]=dim
 end
 -- Footer: the egg link (no jars at all) and Back to original.
 local link=Kit.node("TextButton",root,{Name="EggLink",Text="",AutoButtonColor=false,BackgroundTransparency=1,Selectable=false,ZIndex=root.ZIndex+2,Size=UDim2.fromOffset(200,44)})
 self.linkText=Kit.text(link,"Strong",c("eggLink"),"accent",{Name="Line",Size=UDim2.fromScale(1,1),TextSize=14,TextTruncate=Enum.TextTruncate.AtEnd})
 link.Activated:Connect(function()if self.options.openEgg then self.options.openEgg()end end)
 self.link=link
 -- Back to original: one outline button (focus ring like a card; the pane confirms).
 local reset=Kit.button(root,"FinishReset",{variant="secondary",text=c("reset"),size=Vector2.new(150,45),textSize=14,selectable=false})
 self.resetButton=reset;reset.Visible=false
 reset.Activated:Connect(function()if self.options.tap then self.options.tap(Panel.Reset)end end)
 for _,id in ipairs(Panel.Jars)do local jar=id
  self.cards[id].Activated:Connect(function()if self.options.tap then self.options.tap(jar)end end)
 end
 return self
end
function Panel:refresh(state,petId,visible)
 self.state,self.petId=state or {},petId
 self.root.Visible=visible==true
 self:pumpReset()
end
function Panel:ready()
 if self.options.canUse and not self.options.canUse()then return false end
 return self.intent~=nil and not self.intent.pending
end
-- Back to original: Shine, then Jelly once the first request settles (each axis once).
function Panel:pumpReset()
 local q=self.resetQueue
 if not q or self.intent==nil or self.intent.pending or self.intent.status=="Retrying"then return end
 self.resetQueue=nil -- one step only, whatever happens next
 if q.petId~=self.petId then return end
 local row=Panel.row(self.state,q.petId)
 -- Code review a9960c4: the first clear must have landed. A refused or failed one ends the
 -- reset here, so Back to original never half-applies by clearing only the second axis.
 if self.intent.status=="Rejected"or row[q.first]~=0 then return end
 local axis=q.axes[1]
 if axis and row[axis]~=0 then
  -- Deferred: refresh runs inside the intent's own change notification.
  task.defer(function()if self.root.Parent and self.intent and not self.intent.pending then self.intent:finishClear(q.petId,axis)end end)
 end
end
function Panel:act(id)
 if not self.root.Visible or not self:ready()then return false end
 local card=Panel.card(id,self.state,self.petId,true)
 if not card.enabled then return false end
 if card.reset then
  local row=Panel.row(self.state,self.petId)
  local axes={};if row.sheen~=0 then table.insert(axes,"sheen")end;if row.jelly~=0 then table.insert(axes,"jelly")end
  local first=table.remove(axes,1)
  if not first then return false end
  self.resetQueue=if #axes>0 then {petId=self.petId,first=first,axes=axes}else nil
  local ok=self.intent:finishClear(self.petId,first)
  if not ok then self.resetQueue=nil end
  return ok
 end
 local pending=self.state.pendingHueResult
 return self.intent:finishUse(self.petId,id,if pending and pending.itemId==id then pending.id else nil)
end

local function animate(object,goal,fast)
 if fast or Kit.reduced()then for k,v in pairs(goal)do object[k]=v end;return end
 TweenService:Create(object,TweenInfo.new(Panel.MeterTime,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),goal):Play()
end
function Panel:layoutMeter(width,compact)
 local m=self.meter;local pad=if compact then 8 else 12
 local h=if compact then 87 else 104
 m.Position=UDim2.fromOffset(3,3);m.Size=UDim2.fromOffset(width-6,h)
 local inner=width-6-pad*2
 local shineW=math.floor(inner*.66);local jellyW=math.floor(inner*.30);local jx=pad+inner-jellyW
 local row=Panel.row(self.state,self.petId)
 local key=tostring(self.petId)
 local fast=self.meterKey~=key;self.meterKey=key
 -- Paint, Shine, Dress: the words are read each layout (UICopy's paint override follows the switch), so the meter
 -- reads Soft / Normal / Shiny and See-through while it is on, today's words while it is off.
 self.shineTitle.Text=c("shine");self.jellyTitle.Text=c("jellyAxis");self.helper.Text=c("helper")
 self.endMatte.Text=c("jar.matte");self.endGloss.Text=c("jar.gloss");self.linkText.Text=c("eggLink")
 local titleSize=if compact then 15 else 17
 self.shineTitle.TextSize=titleSize;self.jellyTitle.TextSize=titleSize
 self.shineTitle.Position=UDim2.fromOffset(pad,pad);self.shineTitle.Size=UDim2.fromOffset(math.floor(shineW*.5),20)
 self.shineWord.Text=Panel.shineWords(row.sheen)
 self.shineWord.Position=UDim2.fromOffset(pad+math.floor(shineW*.5),pad);self.shineWord.Size=UDim2.fromOffset(shineW-math.floor(shineW*.5),20)
 local ty=pad+(if compact then 28 else 34)
 self.track.Position=UDim2.fromOffset(pad,ty);self.track.Size=UDim2.fromOffset(shineW,6)
 local inset=9;local span=shineW-inset*2
 local function xOf(stop)return pad+inset+math.floor((stop+Look.SheenStops)/(2*Look.SheenStops)*span+.5)end
 for stop=-3,3 do
  local t=self.ticks[stop];local th=t.Size.Y.Offset
  t.Visible=math.abs(stop)<=Look.SheenStops;t.Position=UDim2.fromOffset(xOf(stop)-1,ty+3-th/2)
 end
 local cx,mx=xOf(0),xOf(row.sheen)
 animate(self.marker,{Position=UDim2.fromOffset(mx,ty+3)},fast)
 animate(self.fill,{Position=UDim2.fromOffset(math.min(cx,mx),ty),Size=UDim2.fromOffset(math.abs(mx-cx),6)},fast)
 local ey=ty+(if compact then 10 else 14)
 self.endMatte.Position=UDim2.fromOffset(pad,ey);self.endMatte.Size=UDim2.fromOffset(80,14)
 self.endGloss.Position=UDim2.fromOffset(pad+shineW-80,ey);self.endGloss.Size=UDim2.fromOffset(80,14)
 self.divider.Position=UDim2.fromOffset(pad+shineW+math.floor((jx-pad-shineW)/2),pad);self.divider.Size=UDim2.fromOffset(1,ey+14-pad)
 self.jellyTitle.Position=UDim2.fromOffset(jx,pad);self.jellyTitle.Size=UDim2.fromOffset(math.floor(jellyW*.6),20)
 self.jellyWord.Text=Panel.jellyWords(row.jelly)
 self.jellyWord.Position=UDim2.fromOffset(jx+math.floor(jellyW*.6),pad);self.jellyWord.Size=UDim2.fromOffset(jellyW-math.floor(jellyW*.6),20)
 local segGap=6;local segW=math.floor((jellyW-segGap*(Look.JellyStops-1))/Look.JellyStops)
 local accent,trackColor=Kit.color("accent"),Kit.color("well")
 for stage=1,3 do
  local s=self.segments[stage];s.Visible=stage<=Look.JellyStops
  s.Position=UDim2.fromOffset(jx+(stage-1)*(segW+segGap),ty);s.Size=UDim2.fromOffset(segW,6)
  animate(s,{BackgroundColor3=if stage<=row.jelly then accent else trackColor},fast)
  s:SetAttribute("Filled",stage<=row.jelly)
 end
 self.helper.Position=UDim2.fromOffset(pad,h-pad-16);self.helper.Size=UDim2.fromOffset(inner,16)
 m:SetAttribute("Sheen",row.sheen);m:SetAttribute("Jelly",row.jelly);m:SetAttribute("ShineWords",self.shineWord.Text)
 return h
end
function Panel:dressPill(id,kind,compact)
 local p,stroke,t=table.unpack(self.pills[id])
 local accent=Kit.color("accent")
 t.Text=if kind=="use"then c("pill.use")elseif kind=="max"then c("pill.max")else c("pill.none")
 p.BackgroundTransparency=if kind=="use"then 0 else 1
 p.BackgroundColor3=accent
 stroke.Color=if kind=="use"then accent else Kit.Color.soft;stroke.Transparency=if kind=="use"then 1 else .35
 t.TextColor3=if kind=="use"then Kit.Color.ink else Kit.Color.soft
 p:SetAttribute("PillState",kind)
 local w,h=if compact then 44 else 52,if compact then 20 else 24
 p.Size=UDim2.fromOffset(w,h)
 return p,w,h
end
-- Grid (same contract as before): returns the used height and the focus list
-- ({button,id,name,act,card}). Focus order: Gloss, Matte, Jelly, then Back to original.
function Panel:layoutCards(width,cols,cardH,gap,focusIndex,compact)
 local Cards=require(script.Parent.CustomizeCards)
 local y=self:layoutMeter(width,compact)+3+(if compact then 8 else 12)
 local ready=self:ready()
 local jarGap=if compact then 10 else 12
 local jarH=if compact then 64 else 76
 local rects=Cards.rects(#Panel.Jars,width,#Panel.Jars,jarH,jarGap,y)
 local focus={}
 for i,id in ipairs(Panel.Jars)do
  local node=self.cards[id];Cards.place(node,rects[i])
  local card=Panel.card(id,self.state,self.petId,ready)
  Cards.dress(node,{name=card.name,status=card.status,tone="soft",focused=i==focusIndex,compact=compact,
   isNew=self.options.isNew~=nil and self.options.isNew(id)==true})
  JarArt.card(node,id)
  -- Name across the top; the count and the state pill share the second row.
  local parts=node:FindFirstChild("CardParts")
  local r=rects[i];local side=math.max(28,r.h-20);local tx=10+side+10
  local p,pw,ph=self:dressPill(id,card.pill,compact)
  p.Visible=true;p.Parent=node;p.Position=UDim2.fromOffset(r.w-8-pw,math.floor(r.h/2)+1)
  if parts then
   local name,status=parts:FindFirstChild("CardName"),parts:FindFirstChild("CardStatus")
   local newRoom=if node:GetAttribute("IsNew")then 40 else 0
   if name then name.Position=UDim2.fromOffset(tx,math.floor(r.h/2)-21);name.Size=UDim2.fromOffset(math.max(1,r.w-tx-8-newRoom),20)
    -- Shrink the jar name before it truncates (narrow phone cards).
    local size=if compact then 15 else 17
    while size>12 and Kit.measure(name.Text,"Name",size).X>name.Size.X.Offset do size-=1 end
    name.TextSize=size
   end
   -- With no jars the pill already reads ×0, so the count steps aside.
   if status then status.Position=UDim2.fromOffset(tx,math.floor(r.h/2)+1);status.Size=UDim2.fromOffset(math.max(1,r.w-tx-8-pw-4),ph);status.Visible=card.pill~="none"end
  end
  self.dims[id].Visible=card.pill=="none"
  node:SetAttribute("FinishCard",id);node:SetAttribute("Enabled",card.enabled);node:SetAttribute("PillState",card.pill)
  table.insert(focus,{button=node,id=id,name=card.name,card=card,act=function()return self:act(id)end})
 end
 y+=jarH+(if compact then 8 else 12)
 -- Footer row.
 local footH=if compact then 45 else 48
 local row=Panel.row(self.state,self.petId)
 local none=Panel.noJars(self.state)
 self.link.Visible=none
 if none then self.link.Position=UDim2.fromOffset(3,y);self.link.Size=UDim2.fromOffset(math.max(1,width-6-160),math.max(44,footH))end
 local showReset=Panel.canReset(row)
 local reset=self.resetButton;reset.Visible=showReset
 if showReset then
  local rw,rh=150,45
  reset.Position=UDim2.fromOffset(width-3-rw,y);reset.Size=UDim2.fromOffset(rw,rh)
  reset:SetAttribute("Focused",#focus+1==focusIndex)
  local card=Panel.card(Panel.Reset,self.state,self.petId,ready)
  table.insert(focus,{button=reset,id=Panel.Reset,name=card.name,card=card,act=function()return self:act(Panel.Reset)end})
 end
 if none or showReset then y+=footH+4 end
 self.root.Size=UDim2.fromOffset(width,y);return y,focus
end
function Panel:destroy()self.root:Destroy()end
return Panel
