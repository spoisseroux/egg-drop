-- Pure single-presentation queue. No delayed callbacks: elapsed time belongs to
-- the currently visible item, so a stale timer cannot dismiss its successor.
local Queue={};Queue.__index=Queue
function Queue.new(limit)
 return setmetatable({items={},providers={},serial=0,limit=limit or 24,current=nil},Queue)
end
function Queue:cancel(item)
 if not item or item.cancelled then return end
 item.cancelled=true
 if self.current==item then self.current=nil end
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
function Queue:step(dt,fits)
 local current=self.current
 if current and(current.cancelled or current.data.active==false or not fits(current.data))then self.current=nil;current=nil end
 if current and not current.persistent and current.data.paused~=true then
  current.age+=math.max(0,dt)
  if current.age>=.36+(current.data.duration or 3.5)then
   self:cancel(current)
   if current.data.onDone then current.data.onDone()end
   current=nil
  end
 end
 -- A provider never occupies a queue slot or holds up a real notice.
 local candidate
 for _,item in ipairs(self.items)do
  if not item.cancelled and item.data.active~=false and fits(item.data)then
   if not candidate or(item.data.priority or 0)>(candidate.data.priority or 0)then candidate=item end
  end
 end
 if current and not current.persistent then candidate=current end
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
