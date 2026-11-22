-- Level-gated shop items, client side (V3-LEVELS-BUILD-PLAN-2026-11-22 S2, V2-SCOPE-2026-11-19 9.4).
-- The shops (WardrobeShop, FaceplateShop, BallShop) read the gate through this one module, so they
-- say and draw it the same way: the chip "Needs Jump 15", the bar toward it, and a button that goes
-- to where that stat is trained. Display only: the server checks the save at purchase (NeedsLevel).
-- While the gates part is off `info` is nil, so callers draw and say exactly what they did before.
--
--   Locked.levels(state?)          {petId={stat=level}} of a snapshot (default: the owner's latest)
--   Locked.info(item,levels,owned) nil for an ungated or owned item, or while gates are off; else
--     {met, have, need, petId, stat or total, color, needs, short, count, line, ratio}
--   Locked.trainText(info,petName) the button that replaces Buy while the level is not met
--   Locked.route(info)             StatsHost.open options for that button ({stat, petId})
--   Locked.chip / bar / mark       the drawn parts (made only for a gated item)
local Shared=game:GetService("ReplicatedStorage").Shared
local Stats=require(Shared.StatCatalog)
local Gate=require(Shared.LevelGate)
local Levels=require(Shared.Levels)
local UICopy=require(Shared.UICopy)
local Locked={}
Locked.Mint=Color3.fromHex("#7FE0C8") -- total-level gates (scope 9.4)
Locked.ChipPad=8
Locked.ChipIcon=14
Locked.Headroom=.35 -- chip width kept for a longer translation

-- Pure ---------------------------------------------------------------------------
function Locked.on()return Levels.on("gates")end
function Locked.levels(state)
 if state==nil then state=require(script.Parent.OwnerSnapshot).read()end
 local stats=type(state)=="table"and state.petStats
 return Gate.levels(type(stats)=="table"and stats.pets or nil)
end
function Locked.info(item,levels,owned)
 if not Locked.on()or owned==true or type(item)~="table"or item.gate==nil then return nil end
 local gate=item.gate
 if not Gate.valid(gate)then -- never sold by the server, so never offered here
  local words=UICopy.get("shop.reason.needsLevel")
  return{met=false,have=0,need=0,color=Locked.Mint,needs=words,short=words,count="",line=words,ratio=0}
 end
 local p=Gate.progress(levels,gate)
 local info={met=p.met,have=p.have,need=p.need,petId=p.petId,stat=gate.stat,total=gate.total,ratio=math.clamp(p.have/p.need,0,1),
  count=tostring(math.min(p.have,p.need)).."/"..tostring(p.need)}
 if gate.stat then
  local name=UICopy.get("stats.name."..gate.stat)
  info.color=Stats.ById[gate.stat].color
  info.needs=UICopy.get("shop.needs.stat",{name=name,level=p.need})
  info.short=UICopy.get("stats.levelUp",{name=name,count=p.need})
 else
  info.color=Locked.Mint
  info.needs=UICopy.get("shop.needs.total",{count=p.need})
  info.short=UICopy.get("stats.chip",{count=p.need})
 end
 info.line=info.needs.." · "..info.count
 return info
end
function Locked.trainText(info,petName)
 if info and info.stat then return UICopy.get("shop.train",{name=UICopy.get("stats.name."..info.stat)})end
 if type(petName)=="string"and petName~=""then return UICopy.get("shop.train",{name=petName})end
 return UICopy.get("stats.open")
end
function Locked.route(info)
 return{stat=info and info.stat or nil,petId=info and info.petId or nil}
end

-- Drawn parts --------------------------------------------------------------------
-- A chip: the stat's icon (bars for a total) and the words, outlined in the stat's colour; gone once
-- the level is met. set(info, maxWidth) keeps the longest wording that fits.
function Locked.chip(parent,height)
 local Kit=require(script.Parent.DeckKit)
 height=height or 20
 local root=Kit.frame(parent,"LevelChip","well",UDim2.new(),UDim2.fromOffset(40,height),999)
 Kit.setSurface(root,"dark")
 local stroke=Kit.node("UIStroke",root,{Name="ChipRing",Thickness=1.5,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
 local left=Locked.ChipPad+Locked.ChipIcon+4
 local label=Kit.text(root,"Small","",Kit.Color.white,{Name="Words",TextSize=12,Position=UDim2.fromOffset(left,0),Size=UDim2.new(1,-left-Locked.ChipPad,1,0),TextTruncate=Enum.TextTruncate.AtEnd})
 local icon,iconKey
 local api={root=root,label=label,stroke=stroke}
 function api.set(info,maxWidth)
  local shown=info~=nil and not info.met
  root.Visible=shown;root:SetAttribute("Met",info~=nil and info.met==true)
  if not shown then return end
  local key=info.stat or "total"
  if iconKey~=key then
   if icon then icon:Destroy()end
   iconKey=key
   icon=if info.stat then require(script.Parent.StatsPanel).icon(root,info.stat,Locked.ChipIcon)else Kit.icon(root,"bars",Locked.ChipIcon,"text")
   icon.AnchorPoint=Vector2.new(0,.5);icon.Position=UDim2.new(0,Locked.ChipPad,.5,0)
  end
  stroke.Color=info.color
  Kit.paint(root,"BackgroundColor3","well")
  Kit.paint(label,"TextColor3",function()return Kit.Color.white end)
  local edge=left+Locked.ChipPad
  local room=math.max(24,(maxWidth or 1000)-edge)
  local extra=if Kit.translating then 1+Locked.Headroom else 1
  local words=info.needs
  local w=math.ceil(Kit.measure(words,"Small",12).X*extra)+2
  if w>room then words=info.short;w=math.ceil(Kit.measure(words,"Small",12).X*extra)+2 end
  label.Text=words
  root.Size=UDim2.fromOffset(math.min(w,room)+edge,height)
  root:SetAttribute("Words",words)
 end
 root.Visible=false
 return api
end
-- The thin progress bar under the requirement line, in the stat's colour.
function Locked.bar(parent,x,y,w,h)
 local Kit=require(script.Parent.DeckKit)
 local track=Kit.frame(parent,"LevelBar","well",UDim2.fromOffset(x,y),UDim2.fromOffset(w,h),999);Kit.stroke(track)
 local fill=Kit.frame(track,"Fill",nil,UDim2.new(),UDim2.new(0,0,1,0),999);fill.BackgroundTransparency=0
 Kit.node("UISizeConstraint",fill,{MinSize=Vector2.new(h,0)})
 track.Visible=false
 return{root=track,fill=fill,set=function(info)
  track.Visible=info~=nil and not info.met
  if not info then return end
  fill.Visible=info.ratio>0;fill.BackgroundColor3=info.color;fill.Size=UDim2.new(info.ratio,0,1,0)
  track:SetAttribute("Ratio",info.ratio)
 end}
end
-- The small lock on a picture's bottom left corner, and a light veil over the picture (never a
-- silhouette). set(shown).
function Locked.mark(picture,size)
 local Kit=require(script.Parent.DeckKit)
 size=size or 18
 local veil=Kit.frame(picture,"LockVeil","well",UDim2.new(),UDim2.fromScale(1,1),10);veil.BackgroundTransparency=.72;veil.ZIndex=picture.ZIndex+2
 local disc=Kit.frame(picture,"LockMark",nil,UDim2.new(0,3,1,-size-3),UDim2.fromOffset(size,size),999)
 disc.BackgroundTransparency=0;disc.BackgroundColor3=Kit.Color.ink;disc.ZIndex=picture.ZIndex+4;Kit.setSurface(disc,"dark")
 local lock=Kit.icon(disc,"lock",math.floor(size*.7),"text");lock.AnchorPoint=Vector2.new(.5,.5);lock.Position=UDim2.fromScale(.5,.5);lock.ZIndex=disc.ZIndex+1
 local api={root=disc,veil=veil}
 function api.set(shown)disc.Visible=shown==true;veil.Visible=shown==true end
 api.set(false)
 return api
end
return table.freeze(Locked)
