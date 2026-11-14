-- Bounded deduplicated content requests. Reuses the proven queue's timeout and
-- in-flight slot accounting; a timed-out engine request retains its slot until
-- it returns, preventing retries from multiplying stalled PreloadAsync calls.
local Provider=game:GetService("ContentProvider")
local Players=game:GetService("Players")
local Readiness=require(script.Parent.PetAssetReadiness)
local Warmup={};Warmup.__index=Warmup
local retired=false;local imageHost;local loaderStops=setmetatable({},{__mode="k"})
local function canonical(uri)
 if type(uri)~="string"or uri==""then return nil end
 local id=uri:match("^rbxassetid://(%d+)$")or uri:match("[?&]id=(%d+)")or uri:match("^(%d+)$");return if id then "rbxassetid://"..id else uri
end
local function imageFor(uri)
 if retired then error("ImageWarmupDestroyed")end
 local player=Players.LocalPlayer;local pg=player and player:FindFirstChildOfClass("PlayerGui")
 if not pg then error("ImageWarmupPlayerGuiUnavailable")end
 if not imageHost or not imageHost.Parent then
  imageHost=Instance.new("ScreenGui");imageHost.Name="_EggDropImageWarmup";imageHost.ResetOnSpawn=false
  imageHost.DisplayOrder=-100;imageHost.Parent=pg
 end
 local image=Instance.new("ImageLabel");image.Name="TypedImageRequest";image.BackgroundTransparency=1
 image.Visible=false;image.Active=false;image.Size=UDim2.fromOffset(1,1);image.Image=uri;image.Parent=imageHost
 return image
end
function Warmup.imageLoader(options)
 options=options or {}
 local create=options.createImage or imageFor;local spawn=options.spawn or task.spawn
 local schedule=options.schedule or task.delay;local cancel=options.cancel or task.cancel
 local preload=options.preload or function(items,callback)Provider:PreloadAsync(items,callback)end
 local successStatus=options.successStatus or Enum.AssetFetchStatus.Success
 local stats={created=0,destroyed=0,engineActive=0,enginePeak=0,engineCalls=0,callbackSuccess=0,callbackFailure=0,errors=0,timeoutCleanup=0}
 local running={};local stopped=false
 local function stop()
  if stopped then return end;stopped=true
  for probe in pairs(running)do probe.cleanup();if probe.timer then pcall(cancel,probe.timer)end end
 end
 loaderStops[stop]=true
 local function load(ids,done)
  if stopped or retired then done(false,"ImageWarmupDestroyed");return end
  spawn(function()
   if stopped or retired then done(false,"ImageWarmupDestroyed");return end
   local probe={};local finished,timedOut=false,false;local success,failure=0,0
   function probe.cleanup()
    if probe.image then probe.image:Destroy();probe.image=nil;stats.destroyed+=1 end
   end
   running[probe]=true
   local engineStarted=false
   local ok,problem=pcall(function()
    assert(#ids==1,"TypedImageBatchMustContainOneAsset")
    probe.image=create(ids[1]);stats.created+=1
    probe.timer=schedule(options.timeout or 1.2,function()
     if not finished then timedOut=true;stats.timeoutCleanup+=1;probe.cleanup()end
    end)
    stats.engineCalls+=1;stats.engineActive+=1;stats.enginePeak=math.max(stats.enginePeak,stats.engineActive);engineStarted=true
    preload({probe.image},function(uri,status)
     if canonical(uri)~=canonical(ids[1])then return end
     if status==successStatus then success+=1;stats.callbackSuccess+=1 else failure+=1;stats.callbackFailure+=1 end
    end)
   end)
   finished=true;if engineStarted then stats.engineActive-=1 end
   if probe.timer then pcall(cancel,probe.timer)end
   probe.cleanup();running[probe]=nil
   if not ok then stats.errors+=1 end
   local ready=ok and not stopped and not retired and not timedOut and success>0 and failure==0
   done(ready,if stopped or retired then "ImageWarmupDestroyed"elseif timedOut then "ImageLoadTimeout"elseif not ok then tostring(problem)elseif failure>0 then "ContentFetchFailed"elseif success==0 then "ContentNoCallback"else nil)
  end)
 end
 return load,stats,stop
end
function Warmup.new(options)
 options=options or {}
 local load,stats,stop=options.load,nil,nil
 if not load then load,stats,stop=Warmup.imageLoader(options)end
 return setmetatable({queue=Readiness.new({now=options.now,load=load,limit=options.limit or 2,
  timeout=options.timeout or 1.2,retryDelay=options.retryDelay or 3}),known={},count=0,max=options.max or 128,imageStats=stats,stopImages=stop},Warmup)
end
function Warmup:request(ids,callback,priority)
 local ticket={cancelled=false,children={}};local unique={};local count=0
 for _,uri in ipairs(ids)do local id=canonical(uri);if id and not unique[id]then unique[id]=true;count+=1 end end
 function ticket:cancel()self.cancelled=true;for _,child in ipairs(self.children)do child:cancel()end end
 if count==0 or count>16 then callback(false,"InvalidAssetBatch");return ticket end
 local ready,reported={},false
 local function changed(id,ok,reason)
  if ticket.cancelled then return end
  ready[id]=ok
  if not ok then if not reported then reported=true;callback(false,reason)end;return end
  for asset in pairs(unique)do if not ready[asset]then return end end
  callback(true);reported=true
 end
 for id in pairs(unique)do
  if not self.known[id]and self.count>=self.max then changed(id,false,"ContentQueueFull")
  else
   if not self.known[id]then self.known[id]=true;self.count+=1 end
   local child=self.queue:request(id,id,id,{id},priority or 1,function(ok,reason)changed(id,ok,reason)end)
   table.insert(ticket.children,child)
  end
 end
 return ticket
end
function Warmup:step()self.queue:step()end
function Warmup:retry(ids,callback,priority)
 for _,uri in ipairs(ids)do
  local id=canonical(uri);local record=id and self.queue.records[id]
  if record and record.state=="failed"and not record.running then
   record.state="queued";record.terminal=false;record.attempts=0;record.queuedAt=self.queue.now();record.token+=1
  end
 end
 return self:request(ids,callback,priority)
end
Warmup.shared=Warmup.new()
local connection=game:GetService("RunService").Heartbeat:Connect(function()Warmup.shared:step()end)
if script then script.Destroying:Connect(function()
 retired=true;connection:Disconnect();for stop in pairs(loaderStops)do stop()end
 if imageHost then imageHost:Destroy();imageHost=nil end
end)end
return Warmup
