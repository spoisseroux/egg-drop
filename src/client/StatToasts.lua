-- v2 S3: the stat level-up line (V2-SCOPE-2026-11-19 section 9.2) and the results strip
-- text. Each snapshot's petStats is compared with the last levels seen per pet; a higher
-- level queues "<Stat> <level>" on the notification rail. Level-ups close together merge
-- into one line ("Power 15, Energy 12") while that line is queued or showing. During a
-- round (`held`) nothing shows; the lines wait for the results screen. The first snapshot
-- (and a pet seen for the first time) only records levels. A tap on the line opens the
-- stats panel on that stat (`open(statId)`); when the panel is already open, `focus`
-- (optional) switches it to that stat instead, so no second panel opens. Without `focus`
-- the open call is refused by the host (StatsHost.open returns false while open) and the
-- ticket just dismisses.
local Shared=game:GetService("ReplicatedStorage").Shared
local Catalog=require(Shared.StatCatalog)
local UICopy=require(Shared.UICopy)
-- Levels matter (S1): a level that brings a reward names it ("Jump 15 · Lime Party Hat"), and a tap
-- opens the stat guide on that reward. No rows while the parts are off, so the lines stay plain.
local Levels=require(Shared.Levels)
local Rewards=require(Shared.StatRewards)
local Bond=require(Shared.BondCatalog)
local Toasts={}
Toasts.__index=Toasts
Toasts.Duration=5.5

-- Pure: level-ups between two level maps ({[petId] = {[stat] = level}}), in stat order.
-- A pet missing from `before` gives none (first sight records only).
function Toasts.diff(before,after)
 local ups={}
 if type(before)~="table"or type(after)~="table"then return ups end
 for petId,levels in pairs(after)do
  local old=before[petId]
  if type(old)=="table"then
   for _,id in ipairs(Catalog.Order)do
    if(levels[id]or 1)>(old[id]or 1)then table.insert(ups,{petId=petId,stat=id,level=levels[id],from=old[id]or 1})end
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
-- The lowest level a merged line started from, per stat (`from` of Toasts.diff).
function Toasts.mergeFrom(from,ups)
 from=from or {}
 for _,up in ipairs(ups)do if up.from then from[up.stat]=math.min(from[up.stat]or math.huge,up.from)end end
 return from
end
-- The reward a line names for one stat: the first row of the highest level reached, or nil.
function Toasts.reward(stat,from,level)
 local rows=if type(from)=="number"then Rewards.earned(stat,from,level)else {}
 local best=rows[#rows]
 if not best then return nil end
 for _,row in ipairs(rows)do if row.level==best.level then return row end end
 return best
end
-- The line, its first stat, and the first reward it names (a row; nil without `from`).
function Toasts.line(pending,from)
 local parts,first,reward={},nil,nil
 for _,id in ipairs(Catalog.Order)do
  if pending[id]then
   local vars={name=UICopy.get("stats.name."..id),count=pending[id]}
   local row=from and Toasts.reward(id,from[id],pending[id])or nil
   first=first or id;reward=reward or row
   if row then vars.reward=Rewards.text(row,UICopy.get);table.insert(parts,UICopy.get("stats.levelUpReward",vars))
   else table.insert(parts,UICopy.get("stats.levelUp",vars))end
  end
 end
 return table.concat(parts,", "),first,reward
end
-- The trick tickets (S1, instead of the bond toast): tricks unlocked since the last snapshot.
-- `seen` is the caller's table; the first snapshot (and a pet first seen, and the part turning on)
-- only records. One event per pet: {petId, level = tricks now, heart = Heart alone brought it (its
-- own ticket names it), text}.
function Toasts.tricksOn()return Levels.on("track")end
function Toasts.trickUps(seen,state)
 local events={}
 if type(seen)~="table"or type(state)~="table"or not Toasts.tricksOn()then return events end
 local pets=type(state.petStats)=="table"and type(state.petStats.pets)=="table"and state.petStats.pets or {}
 local first=seen.tricks==nil
 seen.tricks=seen.tricks or {}
 local ids={};for petId in pairs(pets)do if type(petId)=="string"then table.insert(ids,petId)end end
 table.sort(ids)
 for _,petId in ipairs(ids)do
  local level=type(pets[petId])=="table"and type(pets[petId].level)=="table"and pets[petId].level.heart or nil
  local xp=Bond.xpOf(state.bond,petId)
  local now=Bond.trickLevel(xp,level)
  local before=seen.tricks[petId]
  if not first and before and now>before then
   local unlock=Bond.unlock(now)
   table.insert(events,{petId=petId,level=now,heart=Bond.level(xp)<now,
    text=if unlock then UICopy.get("stats.reward.trick",{name=UICopy.get(unlock.copy)})else ""})
  end
  seen.tricks[petId]=math.max(before or 0,now)
 end
 return events
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
-- `from` (optional) adds the rewards when they fit. Second and third results: the stat a tap opens
-- (the reward's, when there is one) and that reward's row.
function Toasts.capped(levels,fits,from)
 local text,first,row
 if from then
  text,first,row=Toasts.line(levels,from)
  if not fits or fits(text)then return text,if row then row.stat else first,row end
 end
 text,first=Toasts.line(levels)
 local target=if row then row.stat else first
 if not fits or fits(text)then return text,target,row end
 local others=0
 for id in pairs(levels)do if id~=first then others+=1 end end
 if others==0 then return text,target,row end
 return UICopy.get("stats.levelUpMore",{name=UICopy.get("stats.name."..first),count=levels[first],target=others}),target,row
end
-- The rail's own width rule (NotificationRail.geometry) for a tappable line: the whole line
-- shows on its ticket (`full`; a longer one would be truncated at the end).
local function railFits(rail)
 local GuiService=game:GetService("GuiService")
 local TextService=game:GetService("TextService")
 return function(text)
  local inset=GuiService.TopbarInset
  local width=TextService:GetTextSize(text,14,Enum.Font.BuilderSansMedium,Vector2.new(10000,40)).X
  local g=rail.geometry(inset.Width,inset.Height,width,true)
  if g.full==nil then return g.fits end
  return g.full
 end
end
Toasts.MaxWait=20 -- a queued line that never showed in this long is retired

-- deps: rail (NotificationRail), owner (Instance), held() -> bool, open(statId, petId, rowId),
-- focus(statId, petId, rowId) -> bool (optional: the panel is already open, switch it to that stat;
-- false when it is not open), fits(text) -> bool (optional; the rail's width rule by
-- default), now() (optional clock)
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
 self.pendingFrom=Toasts.mergeFrom(self.pendingFrom,ups)
 self.pendingPet=ups[1].petId
 self:flush()
end
-- Show (or grow) the line once nothing holds it. Called on update and every frame.
function Toasts:flush(now)
 if not self.pending or(self.deps.held and self.deps.held())then return end
 now=now or(if self.deps.now then self.deps.now()else os.clock())
 local pending,petId,from=self.pending,self.pendingPet,self.pendingFrom
 self.pending,self.pendingPet,self.pendingFrom=nil,nil,nil
 local fits=self.fits
 local live=self.handle
 -- A line that ended, or never got a turn on the rail, takes no more merges.
 if live and(live.done or(not live.shown and now-live.at>Toasts.MaxWait))then
  if not live.done and live.item then live.item:cancel()end
  live=nil
 end
 local merged=Toasts.merge(if live then table.clone(live.levels)else nil,{})
 for id,level in pairs(pending)do merged[id]=math.max(merged[id]or 0,level)end
 local mergedFrom=if live and live.from then table.clone(live.from)else {}
 for id,level in pairs(from or {})do mergedFrom[id]=math.min(mergedFrom[id]or math.huge,level)end
 -- The merged line would not fit while the new ups alone do: they start their own line.
 if live and fits and not fits((Toasts.line(merged)))and fits((Toasts.line(pending)))then live=nil;merged=pending;mergedFrom=from or {}end
 if not live then
  self.serial+=1;live={key="statLevel:"..self.serial,done=false,shown=false,at=now,levels={}};self.handle=live
 end
 live.levels=merged;live.from=mergedFrom;live.petId=live.petId or petId
 local text,first,row=Toasts.capped(merged,fits,mergedFrom)
 local deps=self.deps
 -- Same key: the rail updates the queued or showing line in place.
 live.item=deps.rail.enqueue(deps.owner,live.key,{text=text,icon="▲",duration=Toasts.Duration,
  activate=if deps.open then function()
   if deps.focus and deps.focus(first,live.petId,row and row.id or nil)then return true end
   return deps.open(first,live.petId,row and row.id or nil)
  end else nil,
  onShown=function()live.shown=true end,onDone=function()live.done=true end})
 return text
end
return Toasts
