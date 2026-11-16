-- Pure single-presentation queue. No delayed callbacks: elapsed time belongs to
-- the currently visible item, so a stale timer cannot dismiss its successor.
--
-- QA v775 (calm rail):
--  * `gap` (seconds, default 0): once a shown line leaves (its time ran out, it was
--    cancelled, tapped through or switched off) nothing new shows until the gap has passed,
--    so a line that fades is never replaced at once and at most one new line shows per gap.
--  * step(dt, fits, held): `held` is true while a tip or notice card is open. Every clock
--    stops (the line's time and the gap), nothing new appears and the shown line is not
--    replaced. A line marked `tapped` (the player opened its card) ends when the hold does,
--    and the gap starts over when the card closes (a shown status line stays meanwhile).
local Queue={};Queue.__index=Queue
function Queue.new(limit)
 return setmetatable({items={},providers={},serial=0,limit=limit or 24,current=nil,gap=0,rest=0},Queue)
end
function Queue:cancel(item)
 if not item or item.cancelled then return end
 item.cancelled=true
 if self.current==item then self.current=nil;self.rest=self.gap end
 for i=#self.items,1,-1 do if self.items[i]==item then table.remove(self.items,i)end end
 for i=#self.providers,1,-1 do if self.providers[i]==item then table.remove(self.providers,i)end end
end
function Queue:cancelOwner(owner)
 for _,list in ipairs({self.items,self.providers})do
  for i=#list,1,-1 do if list[i].owner==owner then self:cancel(list[i])end end
 end
end
function Queue:add(owner,key,data,persistent)
 local list=if persistent then self.providers else self.items
 for _,item in ipairs(list)do
  if item.owner==owner and item.key==key then item.data=data;return item end
 end
 if not persistent and #list>=self.limit then return nil end
 self.serial+=1
 local item={owner=owner,key=key,data=data,persistent=persistent==true,serial=self.serial,age=0,shown=false}
 table.insert(list,item);return item
end
function Queue:step(dt,fits,held)
 dt=math.max(0,dt)
 local current=self.current
 if current and(current.cancelled or current.data.active==false or not fits(current.data))then self.current=nil;current=nil;self.rest=self.gap end
 -- A card is open: the shown line stays as it is, and nothing else may take its place.
 if held then self.wasHeld=true;return current end
 -- The card has just closed: the rail rests before anything new, a status line included.
 if self.wasHeld then self.wasHeld=nil;self.rest=math.max(self.rest,self.gap)end
 if self.rest>0 then self.rest=math.max(0,self.rest-dt)end
 if current and current.tapped then
  -- Its card has closed: the line was tapped through (a status line just stays).
  current.tapped=nil
  if not current.persistent then
   self:cancel(current)
   if current.data.onDone then current.data.onDone()end
   current=nil
  end
 end
 if current and not current.persistent and current.data.paused~=true then
  current.age+=dt
  if current.age>=.36+(current.data.duration or 3.5)then
   self:cancel(current)
   if current.data.onDone then current.data.onDone()end
   current=nil
  end
 end
 -- The calm gap after a line left: the rail stays empty.
 if not current and self.rest>0 then self.current=nil;return nil end
 -- A provider never occupies a queue slot or holds up a real notice.
 local candidate
 for _,item in ipairs(self.items)do
  if not item.cancelled and item.data.active~=false and fits(item.data)then
   if not candidate or(item.data.priority or 0)>(candidate.data.priority or 0)then candidate=item end
  end
 end
 if current and(not current.persistent or self.rest>0)then candidate=current end
 if not candidate then
  for _,item in ipairs(self.providers)do
   if not item.cancelled and item.data.active~=false and fits(item.data)
    and(not candidate or(item.data.priority or 0)>(candidate.data.priority or 0))then candidate=item end
  end
 end
 self.current=candidate
 if candidate and not candidate.shown then
  candidate.shown=true
  if candidate.data.onShown then candidate.data.onShown()end
 end
 return self.current
end
return Queue
