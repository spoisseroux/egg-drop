-- Deck network S4 (deck-network-plan.md, architect review section 3): the client side of
-- a drop. The tap answers at once (sound and dispenser kick) and the server's
-- BoardDropAck settles it. Pure Luau: times are passed in, so the spec drives it directly.
--   * Own throttle: taps closer than DropInterval are ignored (the server checks too).
--   * Not-ready latch: after a sent drop no new drop is sent until its ack arrives and
--     the board reports FieldReady again (true at ack time, or a later true), or
--     LatchTimeout passes (a lost ack never locks the deck).
--   * Tokens 1-65535, opaque to the server (never used for validation).
--   * The Drops-attribute drop sound is skipped once per tap that already played it.
local Intent={};Intent.__index=Intent
Intent.DropInterval=.2
Intent.LatchTimeout=1.5
Intent.TapSoundWindow=1.5

function Intent.new()
 return setmetatable({lastSend=-math.huge,token=0,pending={},latched=false,latchAt=-math.huge,tapSounds={},
  stats={sent=0,throttled=0,latched=0,accepted=0,refused=0,timeouts=0}},Intent)
end

-- Can a tap send now? (canPlay() already checked the replicated FieldReady.)
function Intent:allow(now)
 if self.latched and now-self.latchAt>=Intent.LatchTimeout then self.latched=false;self.stats.timeouts+=1 end
 if self.latched then self.stats.latched+=1;return false,"Latched"end
 if now-self.lastSend<Intent.DropInterval then self.stats.throttled+=1;return false,"Throttled"end
 return true
end

-- Record a sent drop; returns its token. `predicted` is the drop count the tap shows
-- (the dispenser) until the server's own count catches up or the drop is refused.
function Intent:send(now,predicted)
 self.predicted=predicted
 self.token=self.token%65535+1
 self.lastSend,self.latched,self.latchAt=now,true,now
 self.pending[self.token]=now
 table.insert(self.tapSounds,now)
 self.stats.sent+=1
 return self.token
end

-- The server's answer. fieldReady: the replicated FieldReady at arrival.
-- Returns "accepted", "refused" or nil (unknown or stale token).
function Intent:ack(token,ok,fieldReady)
 if type(token)~="number"or not self.pending[token]then return nil end
 self.pending[token]=nil
 if ok then
  self.stats.accepted+=1
  self.acked=true
  if fieldReady~=false then self.latched=false end
  return "accepted"
 end
 self.stats.refused+=1
 self.latched=false
 self.predicted=nil
 -- The refused tap's sound was already played; the Drops attribute will not change.
 table.remove(self.tapSounds,1)
 return "refused"
end

-- FieldReady changed: a true after an accepted ack opens the latch.
function Intent:fieldReady(value)
 if value==true and self.acked then self.latched=false;self.acked=false end
end

-- The Drops attribute went up: true when a tap already played this drop's sound.
function Intent:consumeTapSound(now)
 while self.tapSounds[1]and now-self.tapSounds[1]>Intent.TapSoundWindow do table.remove(self.tapSounds,1)end
 if self.tapSounds[1]then table.remove(self.tapSounds,1);return true end
 return false
end

-- A reset, a mode change or the round ending: forget pending taps.
function Intent:clear()
 table.clear(self.pending);table.clear(self.tapSounds)
 self.latched,self.acked=false,false
 self.predicted=nil
end

-- The drop count to show: the server's, or the tap's prediction while it is ahead.
function Intent:shownDrops(actual)
 if self.predicted and self.predicted>actual then return self.predicted end
 self.predicted=nil
 return actual
end

return Intent
