-- v2 S3: the stat level-up line (V2-SCOPE-2026-11-19 section 9.2) and the results strip
-- text. Each snapshot's petStats is compared with the last levels seen per pet; a higher
-- level queues "<Stat> <level>" on the notification rail. Level-ups close together merge
-- into one line ("Power 15, Energy 12") while that line is queued or showing. During a
-- round (`held`) nothing shows; the lines wait for the results screen. The first snapshot
-- (and a pet seen for the first time) only records levels. A tap on the line opens the
-- stats panel on that stat (`open(statId)`).
local Shared=game:GetService("ReplicatedStorage").Shared
local Catalog=require(Shared.StatCatalog)
local UICopy=require(Shared.UICopy)
local Toasts={}
Toasts.__index=Toasts
Toasts.Duration=4

-- Pure: level-ups between two level maps ({[petId] = {[stat] = level}}), in stat order.
-- A pet missing from `before` gives none (first sight records only).
function Toasts.diff(before,after)
 local ups={}
 if type(before)~="table"or type(after)~="table"then return ups end
 for petId,levels in pairs(after)do
  local old=before[petId]
  if type(old)=="table"then
   for _,id in ipairs(Catalog.Order)do
    if(levels[id]or 1)>(old[id]or 1)then table.insert(ups,{petId=petId,stat=id,level=levels[id]})end
   end
  end
 end
 return ups
end
-- Pure: the level map of a snapshot's petStats (levels from XP, the server's own maths).
function Toasts.levels(petStats)
 local out={}
 local pets=type(petStats)=="table"and type(petStats.pets)=="table"and petStats.pets or nil
 if not pets then return nil end
 for petId,entry in pairs(pets)do
  local xp=type(entry)=="table"and type(entry.xp)=="table"and entry.xp or {}
  local row={}
  for _,id in ipairs(Catalog.Order)do row[id]=Catalog.levelFor(tonumber(xp[id])or 0)end
  out[petId]=row
 end
 return out
end
-- Pure: merge new ups into a pending map ({[stat] = level}, highest wins) and the line.
function Toasts.merge(pending,ups)
 pending=pending or {}
 for _,up in ipairs(ups)do pending[up.stat]=math.max(pending[up.stat]or 0,up.level)end
 return pending
end
function Toasts.line(pending)
 local parts,first={},nil
 for _,id in ipairs(Catalog.Order)do
  if pending[id]then
   first=first or id
   table.insert(parts,UICopy.get("stats.levelUp",{name=UICopy.get("stats.name."..id),count=pending[id]}))
  end
 end
 return table.concat(parts,", "),first
end
-- Pure: results strip parts from the round's gains ({power=, energy=, heart=}) and the
-- pet's XP now. Each part: {id, gain, level, up = levelled this round, text}.
function Toasts.resultsParts(gains,xpNow)
 local out={}
 if type(gains)~="table"then return out end
 xpNow=type(xpNow)=="table"and xpNow or {}
 for _,id in ipairs(Catalog.Order)do
  local gain=tonumber(gains[id])or 0
  if gain>0 then
   local now=tonumber(xpNow[id])
   local level=if now then Catalog.levelFor(now)else nil
   local up=now~=nil and level>Catalog.levelFor(math.max(0,now-gain))
   local name=UICopy.get("stats.name."..id)
   table.insert(out,{id=id,gain=gain,level=level,up=up,
    text=if up then UICopy.get("stats.results.up",{name=name,count=gain,target=level})else UICopy.get("stats.results.gain",{name=name,count=gain})})
  end
 end
 return out
end
-- Rich text for one line of parts, each name in its stat colour.
function Toasts.resultsRich(parts)
 local out={}
 for _,part in ipairs(parts)do
  table.insert(out,string.format('<font color="#%s">%s</font>',Catalog.ById[part.id].color:ToHex(),part.text))
 end
 return table.concat(out,"   ")
end

-- Pure: the line for `levels`, or "Power 15 +2" when the full line does not fit the rail
-- (`fits(text)`; a phone's top bar, a long translation, four stats at once).
function Toasts.capped(levels,fits)
 local text,first=Toasts.line(levels)
 if not fits or fits(text)then return text,first end
 local others=0
 for id in pairs(levels)do if id~=first then others+=1 end end
 if others==0 then return text,first end
 return UICopy.get("stats.levelUpMore",{name=UICopy.get("stats.name."..first),count=levels[first],target=others}),first
end
-- The rail's own width rule (NotificationRail.geometry) for a tappable line.
local function railFits(rail)
 local GuiService=game:GetService("GuiService")
 local TextService=game:GetService("TextService")
 return function(text)
  local inset=GuiService.TopbarInset
  local width=TextService:GetTextSize(text,14,Enum.Font.BuilderSansMedium,Vector2.new(10000,40)).X
  return rail.geometry(inset.Width,inset.Height,width,true).fits
 end
end
Toasts.MaxWait=20 -- a queued line that never showed in this long is retired

-- deps: rail (NotificationRail), owner (Instance), held() -> bool, open(statId, petId),
-- fits(text) -> bool (optional; the rail's width rule by default), now() (optional clock)
function Toasts.new(deps)
 return setmetatable({deps=deps,seen=nil,pending=nil,pendingPet=nil,handle=nil,serial=0,
  fits=deps.fits or(if deps.rail and deps.rail.geometry then railFits(deps.rail)else nil)},Toasts)
end
function Toasts:update(petStats)
 local levels=Toasts.levels(petStats)
 if not levels then return end
 if self.seen==nil then self.seen=levels;return end
 local ups=Toasts.diff(self.seen,levels)
 -- A pet seen for the first time joins the record; known pets keep their highest level.
 for petId,row in pairs(levels)do
  local old=self.seen[petId]
  if old==nil then self.seen[petId]=row else for id,level in pairs(row)do old[id]=math.max(old[id]or 1,level)end end
 end
 if #ups==0 then return end
 self.pending=Toasts.merge(self.pending,ups)
 self.pendingPet=ups[1].petId
 self:flush()
end
-- Show (or grow) the line once nothing holds it. Called on update and every frame.
function Toasts:flush(now)
 if not self.pending or(self.deps.held and self.deps.held())then return end
 now=now or(if self.deps.now then self.deps.now()else os.clock())
 local pending,petId=self.pending,self.pendingPet
 self.pending,self.pendingPet=nil,nil
 local fits=self.fits
 local live=self.handle
 -- A line that ended, or never got a turn on the rail, takes no more merges.
 if live and(live.done or(not live.shown and now-live.at>Toasts.MaxWait))then
  if not live.done and live.item then live.item:cancel()end
  live=nil
 end
 local merged=Toasts.merge(if live then table.clone(live.levels)else nil,{})
 for id,level in pairs(pending)do merged[id]=math.max(merged[id]or 0,level)end
 -- The merged line would not fit while the new ups alone do: they start their own line.
 if live and fits and not fits((Toasts.line(merged)))and fits((Toasts.line(pending)))then live=nil;merged=pending end
 if not live then
  self.serial+=1;live={key="statLevel:"..self.serial,done=false,shown=false,at=now,levels={}};self.handle=live
 end
 live.levels=merged;live.petId=live.petId or petId
 local text,first=Toasts.capped(merged,fits)
 local deps=self.deps
 -- Same key: the rail updates the queued or showing line in place.
 live.item=deps.rail.enqueue(deps.owner,live.key,{text=text,icon="▲",duration=Toasts.Duration,
  activate=if deps.open then function()deps.open(first,live.petId)end else nil,
  onShown=function()live.shown=true end,onDone=function()live.done=true end})
 return text
end
return Toasts
