-- The stat guide and the "Next at N" line (V3-LEVELS-BUILD-PLAN-2026-11-22 S1, V3-SCOPE-2026-11-21 2.3).
-- Every reward of one stat, 1 to 99, from StatRewards: earned rows ticked, the next row lemon, later
-- rows with their level. Level-gated shop items carry a "Go to shop" key. Derived from levels; nothing
-- is saved or claimed. StatsPanel shows it in place of the stat tiles and owns its keys (Guide:move,
-- Guide:act). The pure half (rows, nextText, line) is what the panel and the specs read.
local Shared=game:GetService("ReplicatedStorage").Shared
local Rewards=require(Shared.StatRewards)
local Stats=require(Shared.StatCatalog)
local Balls=require(Shared.BallThemes)
local Plates=require(Shared.DeckThemes)
local Variants=require(Shared.WearableVariants)
local Medals=require(Shared.Medals)
local UICopy=require(Shared.UICopy)
local Guide={}
Guide.__index=Guide
-- A picture per kind: a Kit.icon name on a disc (a medal draws itself).
Guide.Icons=table.freeze({trick="paw",juice="wand",look="sparkle",book="book",name="tag",wardrobe="shirt",balls="smiley",plates="faceplate"})

-- Pure ---------------------------------------------------------------------------
function Guide.text(row)return Rewards.text(row,UICopy.get)end
-- The "Next at N" line of a stat at `level`; nil while no row exists (the parts are off).
function Guide.nextText(stat,level,row)
 row=row or Rewards.next(stat,level)
 if row then return UICopy.get(if row.kind=="gate"then "stats.next.gate"else "stats.next.free",{level=row.level,name=Guide.text(row)})end
 if #Rewards.forStat(stat)>0 then return UICopy.get("stats.next.top")end
 return nil
end
-- An item a level gate sells that this snapshot already owns (the wardrobe: on any pet).
function Guide.owned(row,state)
 if type(row)~="table"or row.kind~="gate"or type(state)~="table"then return false end
 if row.area=="wardrobe"then
  for _,worn in pairs(type(state.petWearables)=="table"and state.petWearables or {})do
   if type(worn)=="table"and type(worn.owned)=="table"and table.find(worn.owned,row.ref)then return true end
  end
  return false
 end
 local list
 if row.area=="balls"then list=type(state.ballThemes)=="table"and state.ballThemes.owned else list=state.faceplates end
 return type(list)=="table"and table.find(list,row.ref)~=nil
end
-- The guide's rows: {row, state = "earned" | "next" | "later", text, status, shop}. Every row of the
-- first unreached level is "next". `shop`: the row leads to a shop (a gated item not owned yet).
function Guide.rows(stat,level,state)
 local out={}
 local following=Rewards.next(stat,level)
 for _,row in ipairs(Rewards.forStat(stat))do
  local kind=if row.level<=level then "earned"elseif following and row.level==following.level then "next"else "later"
  local shop=row.kind=="gate"and not Guide.owned(row,state)
  table.insert(out,{row=row,state=kind,text=Guide.text(row),shop=shop,
   status=if shop then UICopy.get("stats.guide.shop")elseif kind=="earned"then UICopy.get("stats.guide.earned")else UICopy.get("stats.guide.at",{level=row.level})})
 end
 return out
end
-- The row to open on: the asked reward, else the first unreached one, else the last.
function Guide.start(rows,rowId)
 for index,entry in ipairs(rows)do if rowId~=nil and entry.row.id==rowId then return index end end
 for index,entry in ipairs(rows)do if entry.state~="earned"then return index end end
 return math.max(1,#rows)
end
-- Stats with a reward earned since `base` (the levels last looked at): {[stat]=true}.
function Guide.dots(base,levels)
 local out={}
 if type(base)~="table"or type(levels)~="table"then return out end
 for _,stat in ipairs(Stats.Order)do
  if base[stat]and levels[stat]and #Rewards.earned(stat,base[stat],levels[stat])>0 then out[stat]=true end
 end
 return out
end
-- The colour behind a row's picture: the item's own, else the stat's.
function Guide.color(row)
 local color
 if row.kind=="gate"then
  local hex
  if row.area=="wardrobe"then
   for _,variant in ipairs(Variants.Rows)do if variant.id==row.ref then hex=variant.color end end
  elseif row.area=="balls"then
   local theme=Balls.ById[row.ref];hex=theme and theme.ramps and theme.ramps[3]and theme.ramps[3].body
  else hex=Plates.ById[row.ref]and Plates.ById[row.ref].accent end
  if typeof(hex)=="Color3"then color=hex
  elseif type(hex)=="string"then local ok,value=pcall(Color3.fromHex,hex);if ok then color=value end end
 end
 return color or Stats.ById[row.stat].color
end
function Guide.iconName(row)return Guide.Icons[if row.kind=="gate"then row.area else row.kind]or "star"end

-- Drawn parts --------------------------------------------------------------------
-- A small round picture for a reward row.
function Guide.picture(parent,row,size)
 local Kit=require(script.Parent.DeckKit)
 if row.kind=="medal"then
  local medal=require(script.Parent.MedalView).new(parent,size)
  medal.set(row.stat,Medals.index(row.ref)or 1)
  return medal.root
 end
 local disc=Kit.frame(parent,"Picture",nil,UDim2.new(),UDim2.fromOffset(size,size),999)
 disc.BackgroundTransparency=0;disc.BackgroundColor3=Guide.color(row);Kit.stroke(disc,nil,1)
 Kit.setSurface(disc,"light")
 local icon=Kit.icon(disc,Guide.iconName(row),math.floor(size*.62),if Guide.iconName(row)=="star"then nil else Kit.Color.ink)
 icon.AnchorPoint=Vector2.new(.5,.5);icon.Position=UDim2.fromScale(.5,.5)
 return disc
end
-- The "Next at N" line: a picture and the words. set(row or nil, text).
function Guide.line(parent,x,y,w,h,textSize)
 local Kit=require(script.Parent.DeckKit)
 local root=Kit.frame(parent,"NextLine",nil,UDim2.fromOffset(x,y),UDim2.fromOffset(w,h))
 local label=Kit.text(root,"Strong","","text",{Name="Words",Position=UDim2.fromOffset(h+6,0),Size=UDim2.fromOffset(w-h-6,h),TextSize=textSize,TextTruncate=Enum.TextTruncate.AtEnd})
 local api={root=root,label=label}
 local picture,shown
 function api.set(row,text)
  root.Visible=text~=nil
  label.Text=text or ""
  local key=row and row.id or nil
  if shown~=key then
   if picture then picture:Destroy();picture=nil end
   shown=key
   if row then picture=Guide.picture(root,row,h)end
  end
  label.Position=UDim2.fromOffset(if row then h+6 else 0,0);label.Size=UDim2.fromOffset(if row then w-h-6 else w,h)
  root:SetAttribute("Reward",key);root:SetAttribute("Level",row and row.level or nil)
 end
 return api
end

-- host: the body; rect {x,y,w,h}; callbacks: close(), shop(row) (nil: no shop keys), stat(delta),
-- ring() -> the panel's focus ring.
function Guide.new(host,rect,phone,callbacks)
 local Kit=require(script.Parent.DeckKit)
 local self=setmetatable({callbacks=callbacks or {},phone=phone,rows={},views={},index=1,w=rect.w,h=rect.h},Guide)
 local card=Kit.card(host,"StatGuide",nil,{pad=12});card.Position=UDim2.fromOffset(rect.x,rect.y);card.Size=UDim2.fromOffset(rect.w,rect.h);card.Visible=false
 self.root=card
 self.pad=if phone then 10 else 16
 self.head=if phone then 40 else 48
 local close=Kit.closeKey(card,"GuideClose",if phone then 32 else 34,UICopy.get("stats.hint.back"))
 close.AnchorPoint=Vector2.new(1,0);close.Position=UDim2.fromOffset(rect.w-self.pad+2,if phone then 4 else 8)
 close.Activated:Connect(function()if self.callbacks.close then self.callbacks.close()end end)
 self.closeKey=close
 self.title=Kit.text(card,"Heading","","text",{Name="GuideTitle",Position=UDim2.fromOffset(self.pad+(if phone then 32 else 42),0),
  Size=UDim2.fromOffset(rect.w-self.pad*2-(if phone then 74 else 92),self.head),TextSize=if phone then 16 else 20,TextTruncate=Enum.TextTruncate.AtEnd})
 local list=Kit.node("ScrollingFrame",card,{Name="Rewards",BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(self.pad,self.head),
  Size=UDim2.fromOffset(rect.w-self.pad*2,rect.h-self.head-8),ScrollBarThickness=4,ZIndex=card.ZIndex+1,Selectable=false,ScrollingDirection=Enum.ScrollingDirection.Y,
  ScrollBarImageColor3=Color3.new(1,1,1),ScrollBarImageTransparency=.6,CanvasSize=UDim2.new()})
 self.list=list
 return self
end
Guide.RowHeight={phone=44,regular=46}
Guide.RowGap=5
function Guide:buildRows()
 local Kit=require(script.Parent.DeckKit)
 for _,view in ipairs(self.views)do view.root:Destroy()end
 table.clear(self.views)
 if self.empty then self.empty:Destroy();self.empty=nil end
 local rowH=if self.phone then Guide.RowHeight.phone else Guide.RowHeight.regular
 local w=self.list.Size.X.Offset-10
 local statusW=if self.phone then 92 else 112
 if Kit.translating then statusW=math.floor(statusW*1.2)end
 local textSize=if self.phone then 13 else 15
 for index,entry in ipairs(self.rows)do
  local lemon=entry.state=="next"
  local root=Kit.frame(self.list,"Reward_"..entry.row.id,if lemon then "selected"else "well",UDim2.fromOffset(3,3+(index-1)*(rowH+Guide.RowGap)),UDim2.fromOffset(w-6,rowH),10)
  Kit.stroke(root);Kit.setSurface(root,if lemon then "light"else "dark")
  if entry.state=="earned"then root.BackgroundTransparency=.25 end
  local level=Kit.text(root,"Counter",tostring(entry.row.level),if lemon then "text"else "soft",{Name="RowLevel",Position=UDim2.fromOffset(8,0),Size=UDim2.fromOffset(26,rowH),TextSize=if self.phone then 13 else 15})
  local picture=Guide.picture(root,entry.row,if self.phone then 26 else 30)
  picture.Position=UDim2.fromOffset(38,math.floor((rowH-picture.Size.Y.Offset)/2))
  local tx=38+picture.Size.X.Offset+8
  local words=Kit.text(root,"Strong",entry.text,"text",{Name="RowText",Position=UDim2.fromOffset(tx,0),Size=UDim2.fromOffset(w-6-tx-statusW-12,rowH),TextSize=textSize,TextWrapped=true,TextTruncate=Enum.TextTruncate.AtEnd})
  local shop=entry.shop and self.callbacks.shop~=nil
  local view={root=root,entry=entry,level=level,text=words,shop=shop}
  if shop then
   local key=Kit.button(root,"GoToShop",{text=entry.status,size=Vector2.new(statusW,36),textSize=if self.phone then 12 else 14,compact=true,selectable=false})
   key.Position=UDim2.fromOffset(w-6-statusW-5,math.floor((rowH-36)/2)-1)
   key.Activated:Connect(function()self:select(index);self:act()end)
   view.key=key
  else
   local right=if entry.state=="earned"then 22 else 0
   view.status=Kit.text(root,"Small",entry.status,if lemon then "text"else "soft",{Name="RowStatus",Position=UDim2.fromOffset(w-6-statusW-8,0),Size=UDim2.fromOffset(statusW-right,rowH),TextSize=12,
    TextXAlignment=Enum.TextXAlignment.Right,TextTruncate=Enum.TextTruncate.AtEnd})
   if entry.state=="earned"then
    local check=Kit.icon(root,"check",16,"accent");check.AnchorPoint=Vector2.new(1,.5);check.Position=UDim2.new(1,-8,.5,0)
   end
  end
  root:SetAttribute("State",entry.state);root:SetAttribute("Level",entry.row.level)
  root:SetAttribute("AccessibleLabel",entry.text..", "..entry.status)
  self.views[index]=view
 end
 if #self.rows==0 then
  self.empty=Kit.text(self.list,"Body",UICopy.get("stats.guide.none"),"soft",{Name="None",Position=UDim2.fromOffset(6,6),Size=UDim2.fromOffset(w-12,28),TextSize=textSize})
 end
 self.list.CanvasSize=UDim2.fromOffset(0,math.max(0,#self.rows*(rowH+Guide.RowGap)-Guide.RowGap+8))
 self.rowH=rowH
end
-- Shows one stat's rewards. rowId: the reward to land on (default: keep the row, else the next one).
function Guide:show(stat,level,state,rowId,keep)
 local StatsPanel=require(script.Parent.StatsPanel)
 local was=self.stat
 self.stat=stat
 self.rows=Guide.rows(stat,level,state)
 self.title.Text=UICopy.get("stats.guide.title",{name=UICopy.get("stats.name."..stat)})
 if self.statIcon and was~=stat then self.statIcon:Destroy();self.statIcon=nil end
 if not self.statIcon then
  local size=if self.phone then 24 else 32
  self.statIcon=StatsPanel.icon(self.root,stat,size);self.statIcon.Position=UDim2.fromOffset(self.pad,math.floor((self.head-size)/2))
 end
 local parts={}
 for _,entry in ipairs(self.rows)do table.insert(parts,entry.row.id..":"..entry.state..":"..tostring(entry.shop))end
 local key=stat.."|"..table.concat(parts,",")
 if self.key~=key then self.key=key;self:buildRows()end
 self.root.Visible=true
 self.root:SetAttribute("GuideStat",stat);self.root:SetAttribute("Rows",#self.rows)
 if keep and was==stat then self:select(math.clamp(self.index,1,math.max(1,#self.rows)),true)
 else self:select(Guide.start(self.rows,rowId),true)end
end
function Guide:hide()self.root.Visible=false end
function Guide:select(index,instant)
 self.index=math.clamp(index,1,math.max(1,#self.rows))
 local view=self.views[self.index]
 if view then
  local top=view.root.Position.Y.Offset;local bottom=top+self.rowH
  local window=self.list.AbsoluteWindowSize.Y;if window<=0 then window=self.list.Size.Y.Offset end
  local y=self.list.CanvasPosition.Y
  -- Opening lands the row a third of the way down; moving scrolls just far enough.
  if instant then y=top-window/3 elseif top-8<y then y=top-8 elseif bottom+8>y+window then y=bottom+8-window end
  self.list.CanvasPosition=Vector2.new(0,math.clamp(y,0,math.max(0,self.list.CanvasSize.Y.Offset-window)))
  local ring=self.callbacks.ring and self.callbacks.ring()
  if ring then ring.attach(view.root,10)end
 end
 self.root:SetAttribute("FocusedReward",view and view.entry.row.id or nil)
end
function Guide:move(dy)
 local index=math.clamp(self.index+dy,1,math.max(1,#self.rows))
 if index==self.index then return false end
 self:select(index);return true
end
-- A / Enter on the focused row: a shop row leads there.
function Guide:act()
 local view=self.views[self.index]
 if not view or not view.shop then return false end
 if view.key then require(script.Parent.DeckKit).pulse(view.key)end
 self.callbacks.shop(view.entry.row)
 return true
end
function Guide:destroy()self.root:Destroy()end
return Guide
