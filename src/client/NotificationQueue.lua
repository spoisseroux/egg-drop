-- Pure multi-presentation queue for the notification row (v2 "Toy tickets",
-- artifacts/v2-notifications-2026-11-20/NOTIFICATIONS-SPEC.md section 1). No delayed
-- callbacks: each shown item owns its clock (`age`), so a stale timer can never end
-- another item.
--
--  * Up to `maxShown` (4) timed items show at once, plus 1 status line (a provider:
--    `persistent`, no timer). The rest wait here.
--  * New timed items are admitted at least `spacing` (0.4 s) apart, the highest
--    `priority` first (the oldest among equals). Every shown item runs its own clock.
--  * step(dt, fits, held) returns the shown items in display order: the status line
--    pinned first (leftmost), then the timed items oldest first. The list is reused
--    from step to step; copy it to keep it.
--  * `held` is true while a tip or notice card is open: every clock stops, nothing new is
--    admitted and nothing is replaced. An item marked `tapped` (the player tapped its
--    ticket) ends when the hold does (at the next step when nothing holds it); a tapped
--    status line just stays.
--  * An item switched off (`active == false`) or that no longer `fits` leaves the row but
--    stays queued with its clock kept; it may come back later.
--  * The v775 calm gap (one line per 3 s) is retired by the spec; the hold stays.
local Queue={};Queue.__index=Queue
Queue.MaxShown=4
Queue.Spacing=.4
-- Round 3 (Spencer: "make the notifications last a bit longer"): 3.5 s before.
Queue.Duration=5
function Queue.new(limit)
 return setmetatable({items={},providers={},serial=0,limit=limit or 24,shown={},status=nil,
  maxShown=Queue.MaxShown,spacing=Queue.Spacing,since=math.huge,view={},scratch={}},Queue)
end
local function remove(list,item)
 for i=#list,1,-1 do if list[i]==item then table.remove(list,i)end end
end
function Queue:cancel(item)
 if not item or item.cancelled then return end
 item.cancelled=true;item.showing=false
 if self.status==item then self.status=nil end
 remove(self.shown,item);remove(self.items,item);remove(self.providers,item)
end
function Queue:cancelOwner(owner)
 for _,list in ipairs({self.items,self.providers})do
  for i=#list,1,-1 do if list[i]and list[i].owner==owner then self:cancel(list[i])end end
 end
end
function Queue:add(owner,key,data,persistent)
 local list=if persistent then self.providers else self.items
 for _,item in ipairs(list)do
  if item.owner==owner and item.key==key then item.data=data;return item end
 end
 if not persistent and #list>=self.limit then return nil end
 self.serial+=1
 local item={owner=owner,key=key,data=data,persistent=persistent==true,serial=self.serial,age=0,shown=false,showing=false}
 table.insert(list,item);return item
end
-- True while `item` is on the row.
function Queue:visible(item)return item~=nil and item.showing==true end
-- The time an item stays on the row (its timer bar drains over this).
function Queue.durationOf(item)return item.data.duration or Queue.Duration end
local function present(item)
 item.showing=true
 if not item.shown then
  item.shown=true
  if item.data.onShown then item.data.onShown()end
 end
end
function Queue:finish(item)
 if item.cancelled then return end
 self:cancel(item)
 if item.data.onDone then item.data.onDone()end
end
function Queue:list()
 local view=self.view;table.clear(view)
 if self.status then table.insert(view,self.status)end
 for _,item in ipairs(self.shown)do table.insert(view,item)end
 return view
end
function Queue:step(dt,fits,held)
 dt=math.max(0,dt or 0)
 local shown=self.shown
 -- Cancelled, switched off or no longer fitting: off the row (it may come back later).
 for i=#shown,1,-1 do
  local item=shown[i]
  if item.cancelled or item.data.active==false or not fits(item.data)then table.remove(shown,i);item.showing=false end
 end
 local status=self.status
 if status and(status.cancelled or status.data.active==false or not fits(status.data))then status.showing=false;self.status=nil end
 -- A card is open: every clock stops and the row stays as it is.
 if held then return self:list()end
 -- Ends are collected first: an onDone may queue or cancel other lines.
 local ending=self.scratch;table.clear(ending)
 for _,item in ipairs(shown)do
  if item.tapped then
   item.tapped=nil;table.insert(ending,item) -- tapped through (its card, if any, has closed)
  elseif item.data.paused~=true then
   item.age+=dt
   if item.age>=Queue.durationOf(item)then table.insert(ending,item)end
  end
 end
 if self.status and self.status.tapped then self.status.tapped=nil end
 for _,item in ipairs(ending)do self:finish(item)end
 table.clear(ending)
 -- Admit at most one timed item per spacing, the highest priority first.
 self.since+=dt
 if #shown<self.maxShown and self.since>=self.spacing then
  local candidate
  for _,item in ipairs(self.items)do
   if not item.cancelled and not item.showing and item.data.active~=false and fits(item.data)then
    if not candidate or(item.data.priority or 0)>(candidate.data.priority or 0)then candidate=item end
   end
  end
  if candidate then
   table.insert(shown,candidate);self.since=0
   present(candidate)
  end
 end
 -- The status line: the highest-priority active provider.
 local best
 for _,item in ipairs(self.providers)do
  if not item.cancelled and item.data.active~=false and fits(item.data)
   and(not best or(item.data.priority or 0)>(best.data.priority or 0))then best=item end
 end
 if best~=self.status then
  if self.status then self.status.showing=false end
  self.status=best
  if best then present(best)end
 end
 return self:list()
end
return Queue
