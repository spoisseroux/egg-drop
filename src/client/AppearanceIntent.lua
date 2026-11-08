-- Session-local appearance intent transport. Server responses/attributes own confirmation.
local Intent={};Intent.__index=Intent
local order={"theme","sticker"}
function Intent.new(d)
 local self=setmetatable({d=d,alive=true,revision=d.revision or 0,confirmed={theme=d.themeId,sticker=d.stickerId},slots={},nextSend=0,timerToken=0},Intent)
 for _,slot in ipairs(order)do self.slots[slot]={counter=0,status="Ready"}end
 return self
end
function Intent:now()return (self.d.now or os.clock)()end
function Intent:view()
 local v={themeId=self.confirmed.theme,stickerId=self.confirmed.sticker,confirmedTheme=self.confirmed.theme,confirmedSticker=self.confirmed.sticker,revision=self.revision,slots={}}
 for _,slot in ipairs(order)do local s=self.slots[slot];if s.desired then v[if slot=="theme"then "themeId"else "stickerId"]=s.desired.id end
  v.slots[slot]={status=s.status,id=if s.desired then s.desired.id else s.acceptedId,reason=s.reason,seq=if s.desired then s.desired.seq else s.acceptedSeq}
 end
 return v
end
function Intent:emit()
 local pieces={self.confirmed.theme or"",self.confirmed.sticker or"",self.revision}
 for _,slot in ipairs(order)do local s=self.slots[slot];table.insert(pieces,table.concat({s.status,s.desired and s.desired.id or"",s.desired and s.desired.seq or 0,s.reason or"",s.savedSeq or 0},":"))end
 local key=table.concat(pieces,"|");if self.key==key then return end;self.key=key
 if self.d.changed then self.d.changed(self:view())end
end
function Intent:cancelTimer()
 self.timerToken+=1;self.timerAt=nil
 if self.timer then pcall(self.d.cancel or task.cancel,self.timer);self.timer=nil end
end
function Intent:schedule(at)
 if not self.alive then return end
 if not at then self:cancelTimer();return end
 if self.timerAt and self.timerAt<=at then return end
 self:cancelTimer();self.timerAt=at;local token=self.timerToken
 self.timer=(self.d.delay or task.delay)(math.max(0,at-self:now()),function()
  if not self.alive or token~=self.timerToken then return end
  self.timer,self.timerAt=nil,nil;self:step()
 end)
end
function Intent:choose(slot,id)
 local s=self.slots[slot];if not self.alive or not s or type(id)~="string"then return false end
 if s.desired and s.desired.id==id then return false end
 if not s.flight and not s.desired and self.confirmed[slot]==id then s.desired=nil;s.status="Ready";s.reason=nil;self:emit();return false end
 s.counter+=1;if s.counter>2147483647 then s.counter=2147483647;return false end
 s.desired={id=id,seq=s.counter,attempts=0,rebases=0};s.status,s.reason="Pending",nil
 self:emit();self:step();return true
end
function Intent:retry(slot)
 local s=self.slots[slot];if not s or not self.alive or s.flight then return false end
 if s.desired and s.status=="Retry"then s.desired.attempts=0;s.status="Pending";s.reason=nil;self:step();return true end
 if s.rejectedId and s.reason~="Locked"and s.reason~="InvalidChoice"and s.reason~="Invalid"and s.reason~="Superseded"then return self:choose(slot,s.rejectedId)end
 return false
end
function Intent:snapshot(theme,sticker,revision)
 if not self.alive or type(revision)~="number"or revision<self.revision or type(theme)~="string"or type(sticker)~="string"then return false end
 self.revision=revision;self.confirmed.theme,self.confirmed.sticker=theme,sticker;self:emit();return true
end
function Intent:receive(message)
 if not self.alive or type(message)~="table"then return false end
 local s=self.slots[message.slot];if not s or type(message.seq)~="number"or type(message.id)~="string"then return false end
 local status=message.status;if status~="Applied"and status~="Rejected"and status~="Saved"then return false end
 if type(message.revision)=="number"and message.revision>=self.revision and type(message.themeId)=="string"and type(message.stickerId)=="string"then
  self.revision=message.revision;self.confirmed.theme,self.confirmed.sticker=message.themeId,message.stickerId
 end
 local current=s.flight or (if s.status=="Retry"then s.desired else nil);local matching=current and current.seq==message.seq and current.id==message.id
 if status=="Saved"then
  -- Saved can be the first delivered reply when Applied was lost.
  if matching then
   s.acceptedSeq,s.acceptedId=message.seq,message.id;s.flight=nil;s.reason=nil;s.rejectedId=nil
   if s.desired and s.desired.seq==message.seq then s.desired=nil end
  end
  if s.acceptedSeq==message.seq and s.acceptedId==message.id then s.savedSeq=message.seq;if not s.desired then s.status="Saved"else s.status="Pending"end end
 elseif status=="Rejected"and message.reason=="Superseded"and s.acceptedSeq==message.seq and s.acceptedId==message.id then
  s.acceptedSeq,s.acceptedId,s.savedSeq=nil,nil,nil
  if not s.desired then s.status,s.reason="Rejected","Superseded"end
 elseif matching then
  if status=="Applied"then
   s.acceptedSeq,s.acceptedId=message.seq,message.id;s.flight=nil;s.reason=nil;s.rejectedId=nil
   if s.desired and s.desired.seq==message.seq then s.desired=nil;s.status="Applied"else s.status="Pending"end
  elseif message.reason=="Throttled"and type(message.retryAfter)=="number"and s.desired and s.desired.seq==current.seq then
   current.retryAt=self:now()+math.max(.03,message.retryAfter);current.deadline=current.retryAt+1.5;s.status="Pending"
  elseif(message.reason=="Stale"or message.reason=="SeqConflict")and type(message.lastSeq)=="number"and s.desired and s.desired.rebases<2 then
   s.counter=math.min(2147483646,math.max(s.counter,math.floor(message.lastSeq)));s.desired.seq=s.counter+1;s.counter=s.desired.seq;s.desired.rebases+=1;s.desired.attempts=0;s.flight=nil;s.status="Pending"
  else
   s.flight=nil
   if s.desired and s.desired.seq==message.seq then s.rejectedId=s.desired.id;s.desired=nil;s.status,s.reason="Rejected",message.reason or"Unavailable"end
  end
 end
 self:emit();self:step();return true
end
function Intent:step()
 if not self.alive then return end
 if self.stepping then self.dirty=true;return end
 self.stepping=true
 repeat
  self.dirty=false;local now=self:now()
  for _,slot in ipairs(order)do
   local s=self.slots[slot];local f=s.flight
   if f and s.desired and s.desired.seq~=f.seq then
    -- A newer explicit choice supersedes only the resend, not a possible server commit.
    if f.retryAt or (f.deadline and now>=f.deadline)then s.flight=nil;f=nil end
   end
   if f and now>=(f.retryAt or f.deadline)then
    if f.attempts>=3 then s.flight=nil;s.status,s.reason="Retry","NoReply"
    else f.retryAt=math.max(now,self.nextSend)end
   end
   if not s.flight and s.desired and s.status~="Retry"then s.flight=s.desired;s.flight.retryAt=math.max(now,self.nextSend);f=s.flight end
   f=s.flight
   if f and f.retryAt and now>=f.retryAt and now>=self.nextSend then
    f.retryAt=nil;f.attempts+=1;f.deadline=now+1.5;self.nextSend=now+.26
    self.d.send({slot=slot,id=f.id,seq=f.seq})
   end
  end
 until not self.dirty
 self.stepping=false;self:emit()
 local nextAt
 for _,slot in ipairs(order)do local s=self.slots[slot];local f=s.flight
  if f then local at=f.retryAt or f.deadline;nextAt=if nextAt then math.min(nextAt,at)else at end
 end
 self:schedule(nextAt)
end
function Intent:destroy()
 if not self.alive then return end;self.alive=false;self:cancelTimer()
end
return Intent
