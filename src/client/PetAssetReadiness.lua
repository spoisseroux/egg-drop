-- Shared bounded family requests. Metadata is not downloaded-mesh readiness.
local Provider=game:GetService("ContentProvider")
local Readiness={};local Queue={};Queue.__index=Queue
local function fetch(parts,complete)
 task.spawn(function()
  local expected,seen={},{};local failed=false
  for _,part in ipairs(parts)do
   local id=string.match(part.MeshId,"%d+")
   if not id then complete(false,"InvalidMeshResource");return end
   expected[id]=true
  end
  local ok,problem=pcall(function()
   Provider:PreloadAsync(parts,function(uri,status)
    local id=string.match(uri,"%d+")
    if expected[id]then if status==Enum.AssetFetchStatus.Success then seen[id]=true else failed=true end end
   end)
  end)
  for id in pairs(expected)do if not seen[id]then failed=true end end
  complete(ok and not failed,if not ok then tostring(problem)elseif failed then "RequiredMeshFetchFailed"else nil)
 end)
end
function Readiness.new(options)
 options=options or {}
 return setmetatable({records={},active=0,serial=0,now=options.now or os.clock,load=options.load or fetch,limit=options.limit or 2,timeout=options.timeout or 12,retryDelay=options.retryDelay or 5},Queue)
end
local function notify(record,ready,reason)
 for ticket,callback in pairs(record.listeners)do if not ticket.cancelled then callback(ready,reason)end end
 if ready then table.clear(record.listeners)end
end
function Queue:pump()
 while self.active<self.limit do
  local selected
  for _,record in pairs(self.records)do if record.state=="queued"and(not selected or record.priority>selected.priority or(record.priority==selected.priority and record.serial<selected.serial))then selected=record end end
  if not selected then return end
  local record=selected;record.state="loading";record.attempts+=1;record.started=self.now();record.token+=1;local token=record.token
  self.active+=1;record.running=true
  local returned=false
  local function complete(ok,reason)
   if returned then return end;returned=true;record.running=false;self.active-=1
   if self.records[record.key]==record and record.token==token and record.state=="loading"then
    record.state=if ok then "ready"else "failed";record.reason=reason;record.retryAt=self.now()+self.retryDelay
    notify(record,ok,reason)
   end
   self:pump()
  end
  local ok,problem=pcall(self.load,record.parts,complete)
  if not ok then complete(false,tostring(problem))end
 end
end
function Queue:step()
 local now=self.now()
 for _,record in pairs(self.records)do
  if(record.state=="loading"and now-record.started>=self.timeout)or(record.state=="queued"and now-record.queuedAt>=self.timeout)then
   record.terminal=record.state=="queued"
   record.state="failed";record.reason=if record.terminal then "QueueWaitTimeout"else "MeshLoadTimeout";record.token+=1;record.retryAt=now+self.retryDelay
   notify(record,false,record.reason)
  elseif record.state=="failed"and not record.terminal and not record.running and record.attempts<2 and next(record.listeners)and now>=record.retryAt then
   record.state="queued";record.queuedAt=now
  end
 end
 self:pump()
end
function Queue:ready(key,source,signature)
 local record=self.records[key]
 return record~=nil and record.source==source and record.signature==signature and record.state=="ready"
end
function Queue:request(key,source,signature,parts,priority,callback)
 self.serial+=1
 local record=self.records[key]
 if not record or record.source~=source or record.signature~=signature then
  if record then record.token+=1;table.clear(record.listeners)end
  record={key=key,source=source,signature=signature,parts=parts,priority=priority or 1,serial=self.serial,state="queued",queuedAt=self.now(),attempts=0,token=0,listeners={}}
  self.records[key]=record
 else
  record.priority=math.max(record.priority,priority or 1)
  if record.terminal and record.reason=="QueueWaitTimeout"then record.terminal=false;record.state="queued";record.queuedAt=self.now()end
 end
 local ticket={cancelled=false}
 function ticket:cancel()self.cancelled=true;record.listeners[self]=nil end
 record.listeners[ticket]=callback
 if record.state=="ready"then callback(true);record.listeners[ticket]=nil end
 self:step();return ticket
end
Readiness.shared=Readiness.new()
return Readiness
