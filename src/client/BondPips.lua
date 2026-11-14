-- Bond pips (overnight 2026-11-14 slice F, VISUAL-BRIEF 5, SYSTEMS-SCOPE 5.4): five small
-- hearts in a row under a pet's name (Companions pane, focus card), a thin bar under them
-- for progress to the next level, and the pure level-up rules the toast and flourish use.
--
-- Filled = the house accent at full strength; empty = `line` at 40% and a little smaller,
-- so filled and empty read apart without colour. The heart is drawn from Kit frames (two
-- round lobes and a turned square), each pip its own CanvasGroup so the overlapping
-- pieces fade as one shape. Pip 18 px on desktop, 14 px on phones, 4 px gaps, 3 px bar.
--
-- Levels come from Shared.BondCatalog (lane K) and the XP from the snapshot's `bond`
-- (lane S). While either is missing `info` returns nil and callers show nothing.
local TweenService=game:GetService("TweenService")
local Shared=game:GetService("ReplicatedStorage").Shared
local UICopy=require(Shared.UICopy)
local Kit=require(script.Parent.DeckKit)
local Pips={}
Pips.Count=5
Pips.Gap=4
Pips.Bar=3
Pips.Size={regular=18,compact=14}
Pips.EmptyAlpha=.6    -- `line` at 40%
Pips.EmptyScale=.8
Pips.PopSeconds=.2    -- 1.0 -> 1.25 -> 1.0
Pips.Tricks=table.freeze({"l1","l2","l3","l4","l5"})

local function optional(name)
 local module=Shared:FindFirstChild(name)
 if not module then return nil end
 local ok,value=pcall(require,module)
 return if ok then value else nil
end
function Pips.catalog()return Pips.override or optional("BondCatalog")end

-- Pure: the levels shown (the catalogue's shipped cap, never more than the five pips).
function Pips.cap(catalog)
 catalog=catalog or Pips.catalog()
 local shipped=catalog and tonumber(catalog.MaxLevelShipped)or Pips.Count
 return math.clamp(math.floor(shipped),1,Pips.Count)
end
-- Pure: one pet's bond for display, or nil while bond data is not there.
-- Returns {xp, level (true level), shown (1..cap), progress (0..1 to the next level), max}.
function Pips.info(bond,petId,catalog)
 catalog=catalog or Pips.catalog()
 if not catalog or type(catalog.level)~="function"or type(bond)~="table"or type(petId)~="string"then return nil end
 local xp=bond[petId]
 if type(xp)~="number"or xp~=xp or xp<0 then xp=0 end
 local level=math.max(1,math.floor(tonumber(catalog.level(xp))or 1))
 local cap=Pips.cap(catalog)
 local shown=math.min(level,cap)
 local progress=1
 local thresholds=catalog.Thresholds
 if level<cap and type(thresholds)=="table"and type(thresholds[level])=="number"and type(thresholds[level+1])=="number"then
  local span=thresholds[level+1]-thresholds[level]
  progress=if span>0 then math.clamp((xp-thresholds[level])/span,0,1)else 1
 end
 return{xp=xp,level=level,shown=shown,progress=progress,max=level>=cap}
end
-- Pure: the trick a level unlocks (nil past the shipped tricks).
function Pips.trickName(level)
 local key=Pips.Tricks[level]
 return if key then UICopy.get("bond.trick."..key)else nil
end
-- Pure: the level-up toast ("Bond level 3 · New trick: Wiggle dance").
function Pips.toastText(level)
 local trick=Pips.trickName(level)
 if trick then return UICopy.get("bond.levelUp",{count=level,name=trick})end
 return UICopy.get("bond.levelUpPlain",{count=level})
end
-- Pure: the short line beside the pips ("Lv 3", or "Lv 5 · more soon" at the cap).
function Pips.label(info)
 if not info then return ""end
 return UICopy.get(if info.max then "bond.max"else "bond.short",{count=info.shown})
end
-- Level-up detection (SYSTEMS-SCOPE 5.4): `seen` is the caller's table (clientUI.bondSeen).
-- The first snapshot only sets the baseline; after that a pet whose shown level is higher
-- than the last one seen gives one event {petId, level}, once per pet per level.
function Pips.levelUps(seen,bond,catalog)
 local events={}
 if type(seen)~="table"or type(bond)~="table"then return events end
 seen.levels=seen.levels or {}
 local ids={}
 for petId in pairs(bond)do if type(petId)=="string"then table.insert(ids,petId)end end
 table.sort(ids)
 for _,petId in ipairs(ids)do
  local info=Pips.info(bond,petId,catalog)
  if info then
   local before=seen.levels[petId]or(if seen.ready then 1 else info.shown)
   if seen.ready and info.shown>before then table.insert(events,{petId=petId,level=info.shown})end
   seen.levels[petId]=math.max(before,info.shown)
  end
 end
 seen.ready=true
 return events
end
-- Pure: the row's width and height at a pip size.
function Pips.extent(size)
 return Pips.Count*size+(Pips.Count-1)*Pips.Gap,size+Pips.Gap+Pips.Bar
end

-- One heart, `size` px square: white pieces in a CanvasGroup (GroupColor3 tints them).
-- Centre-anchored, so the empty (smaller) pip and the level-up pop scale about its middle.
local function heart(parent,index,size)
 local pip=Kit.node("CanvasGroup",parent,{Name="Pip"..index,BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromOffset(size,size),
  AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset((index-1)*(size+Pips.Gap)+size/2,size/2),ZIndex=parent.ZIndex+1,Active=false})
 local a=.586 -- lobe diameter and square side, as a share of the pip
 local function piece(name,x,y,rotation,round)
  local f=Kit.node("Frame",pip,{Name=name,BorderSizePixel=0,BackgroundColor3=Color3.new(1,1,1),AnchorPoint=Vector2.new(.5,.5),
   Position=UDim2.fromScale(x,y),Size=UDim2.fromScale(a,a),Rotation=rotation,ZIndex=pip.ZIndex})
  if round then Kit.corner(f,999)else Kit.corner(f,math.max(1,math.floor(size*.08)))end
 end
 piece("Point",.5,.543,45,false)
 piece("LobeL",.5-.3536*a,.543-.3536*a,0,true)
 piece("LobeR",.5+.3536*a,.543-.3536*a,0,true)
 local scale=Kit.node("UIScale",pip,{Name="PipScale",Scale=1})
 return{root=pip,scale=scale}
end

-- parent: any GuiObject. compact: phone size. Returns {root, set(info, animate), info}.
-- `set(nil)` hides the row. `animate` pops a pip that fills (it fades in under Reduced Motion).
function Pips.new(parent,compact)
 local size=if compact then Pips.Size.compact else Pips.Size.regular
 local width,height=Pips.extent(size)
 local root=Kit.frame(parent,"BondPips",nil,UDim2.new(),UDim2.fromOffset(width,height))
 root.Visible=false
 local api={root=root,size=size,width=width,height=height,pips={},filled=nil}
 for index=1,Pips.Count do api.pips[index]=heart(root,index,size)end
 local bar=Kit.progress(root,Pips.Bar)
 bar.root.Name="BondBar";bar.root.Position=UDim2.fromOffset(0,size+Pips.Gap);bar.root.Size=UDim2.fromOffset(width,Pips.Bar)
 if bar.minimum then bar.minimum.MinSize=Vector2.new(Pips.Bar,0)end
 api.bar=bar
 local function paintPip(index,filled)
  local pip=api.pips[index]
  Kit.paint(pip.root,"GroupColor3",function()return Kit.color(if filled then "accent"else "line")end)
  pip.root.GroupTransparency=if filled then 0 else Pips.EmptyAlpha
  pip.scale.Scale=if filled then 1 else Pips.EmptyScale
  pip.root:SetAttribute("Filled",filled)
 end
 function api.set(info,animate)
  api.info=info
  root.Visible=info~=nil
  if not info then api.filled=nil;root:SetAttribute("BondLevel",nil);return end
  local before=api.filled
  for index=1,Pips.Count do
   local filled=index<=info.shown
   paintPip(index,filled)
   if animate and filled and before~=nil and index>before then
    local pip=api.pips[index]
    if Kit.reduced()then
     -- Reduced Motion: no pop, the pip fades in.
     pip.root.GroupTransparency=1
     TweenService:Create(pip.root,TweenInfo.new(Pips.PopSeconds),{GroupTransparency=0}):Play()
    else
     local half=Pips.PopSeconds/2
     pip.scale.Scale=1;Kit.tween(pip.scale,half,{Scale=1.25})
     task.delay(half,function()if pip.scale.Parent then Kit.tween(pip.scale,half,{Scale=1})end end)
    end
   end
  end
  api.filled=info.shown
  bar.set(info.progress,1,false,animate==true)
  bar.root.Visible=not info.max
  root:SetAttribute("BondLevel",info.shown)
  root:SetAttribute("AccessibleLabel",UICopy.get("bond.level",{count=info.shown}))
 end
 return api
end

return Pips
