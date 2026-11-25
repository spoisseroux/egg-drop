-- Direct hatch from Hatch eggs (QA v685 H4), moved out of init.client.lua (v842) so the
-- end-to-end hatch spec drives the same code as the game.
-- Hatch buys straight away; the item view opens only once the result lands, as the hatch
-- reveal (egg, rarity sound, item), so there is no second "Hatch" card. A refused or
-- stalled purchase still opens the buy page, which shows the reason or Try again.
-- v842 phone bug: a Customization Egg hatch landed with no egg and no sound, and the next
-- Toy Egg hatch reopened that jar. The look kind now hands its result to the Hue reveal as
-- a fresh hatch, and the egg being hatched owns the receipt page (HueEggView:open).
local Flow={}
Flow.__index=Flow
Flow.Kinds=table.freeze({
 hue=table.freeze({page="buy",intent="hueIntent",method="hatch",pending="pendingHueResult"}),
 -- Customization Egg (slice 4): buys through the Hue intent; a refusal stays on Hatch eggs,
 -- which re-renders from the latest snapshot (no buy page of its own).
 look=table.freeze({page=nil,intent="hueIntent",method="lookHatch",pending="pendingHueResult"}),
 material=table.freeze({page="materialBuy",intent="materialIntent",method="buy",pending="pendingMaterialResult"}),
 toy=table.freeze({page="toyBuy",intent="toyIntent",method="buy",pending="pendingToyResult"}),
 feature=table.freeze({page="featureBuy",intent="featureIntent",method="buy",pending="pendingFeatureResult"}),
})

-- d: {intents = {hueIntent=..., toyIntent=..., ...}, state = function() -> snapshot,
--  view = HueEggView, openHue = function(page, petId, back) -> bool,
--  lastRequest = function() -> os.clock() of the last nursery request sent (optional),
--  clock = function() -> seconds (default os.clock), after = function(seconds, fn) (default task.delay)}
function Flow.new(d)
 return setmetatable({d=d,direct=nil,queued=nil},Flow)
end
-- Beta (17) R13: the server takes one hatch-family request per 0.3 s per player (init.server
-- lastHatchRequest: buys, stores, acks, equips). Hatch another sent its buy the moment the store
-- landed (~20 ms after the store request), so it was refused "Throttled" and nothing happened.
-- The automatic follow-up (Hatch another, a queued egg) now waits until Spacing after the last
-- request, and a buy refused "Throttled" is sent again once, Spacing later.
Flow.Spacing=.35
function Flow:clock()return if self.d.clock then self.d.clock()else os.clock()end
function Flow:after(seconds,fn)if self.d.after then self.d.after(seconds,fn)else task.delay(seconds,fn)end end
-- Seconds until a request may go (0 = now).
function Flow:wait()
 local last=self.d.lastRequest and self.d.lastRequest()
 if type(last)~="number"then return 0 end
 return math.max(0,Flow.Spacing-(self:clock()-last))
end
-- Too soon: sync again when the gap has passed (one timer at a time). True when it had to wait.
function Flow:hold()
 local wait=self:wait()
 if wait<=0 then return false end
 if not self.holding then
  self.holding=true
  self:after(wait+.01,function()self.holding=false;self:sync()end)
 end
 return true
end
function Flow:intent(kind)return self.d.intents[Flow.Kinds[kind].intent]end
-- The server keeps one unopened result at a time (HatchGuard), so hatching another egg first
-- stores the waiting one, losslessly (a jar to the inventory, a toy or feature acknowledged).
local storeOrder={"hue","material","toy","feature"}
local storeMethod={hue="store",material="ack",toy="ack",feature="ack"}
function Flow.otherPending(kind,state)
 local own=Flow.Kinds[kind].pending
 for _,other in ipairs(storeOrder)do
  local field=Flow.Kinds[other].pending
  if field~=own and state[field]then return other,state[field]end
 end
 return nil
end
-- Hatch (purchase=true) or open (false) the egg `kind` from Hatch eggs. `retry`: the one
-- re-send after a Throttled refusal (any other open starts a fresh request that may retry once).
function Flow:open(kind,purchase,retry)
 local k=Flow.Kinds[kind];if not k then return false end
 if purchase then self.retried=retry==true;self.retryKind=nil end
 -- One request at a time: a Hatch another waiting on its store takes no second purchase.
 if purchase and self.againKind then return false end
 local intent=self:intent(kind);local state=self.d.state()
 if purchase and state and not state[k.pending]and intent then
  -- v842: another egg's result is waiting; store it, then hatch this egg (sync).
  local other,result=Flow.otherPending(kind,state)
  if other then
   local holder=self:intent(other)
   if self.queued==kind and holder and holder.pending then return true end
   if holder and holder[storeMethod[other]](holder,result.id)then self.queued=kind;return true end
   self.queued=nil;return false
  end
  if self.direct==kind and intent.pending then return true end
  if intent[k.method](intent)then self.direct=kind;return true end
 end
 self.direct=nil
 if k.page or not purchase then return self.d.openHue(k.page or "buy",nil,"eggs")==true end
 return false
end
-- v2 Hatch another (V2-HATCH-REDESIGN 2.5): the result card stores its result, then the same
-- egg hatches again once that store has landed. One press is one request: a second press while
-- one is waiting is refused, and a refused store (or 10 s without an answer) gives up.
Flow.AgainTimeout=10
function Flow:again(kind)
 if not Flow.Kinds[kind]or self:againPending()or self.direct or self.queued then return false end
 self.againKind=kind;self.againAt=os.clock();return true
end
-- True while a Hatch another is waiting for its store, or its hatch is in flight (the result
-- card keeps its shell up until then). A store that never answers gives up after the timeout.
function Flow:againPending()
 if self.againKind and os.clock()-(self.againAt or 0)>Flow.AgainTimeout then self.againKind=nil end
 if self.againDirect and self.direct~=self.againDirect and self.retryKind~=self.againDirect then self.againDirect=nil end
 return self.againKind~=nil or self.againDirect~=nil
end
function Flow:cancelAgain()self.againKind=nil;self.againDirect=nil;self.retryKind=nil end
function Flow:syncAgain(state)
 local kind=self.againKind;if not kind then return false end
 local k=Flow.Kinds[kind];local intent=self:intent(kind)
 if not self:againPending()then return false end
 if not state or state[k.pending]then
  if intent and not intent.pending and intent.status=="Rejected"then self.againKind=nil end
  return false
 end
 if intent and(intent.pending or(intent.state and intent.state[k.pending]))then return false end
 -- The store just went: the buy waits out the server's request spacing.
 if self:hold()then return false end
 self.againKind=nil
 local opened=self:open(kind,true)
 if opened and self.direct==kind then self.againDirect=kind end
 return opened
end
-- After every snapshot / intent change: once the hatched result lands, open its reveal.
function Flow:sync()
 local state=self.d.state()
 if self.againKind then
  local opened=self:syncAgain(state)
  if self.againKind or opened then return opened end
 end
 if self.queued and state then
  local queued=self.queued
  local other=Flow.otherPending(queued,state)
  -- Each intent takes the snapshot in turn; the egg's own intent must have seen the store
  -- land too, or its buy is refused ("Store or use your saved egg first").
  local target=self:intent(queued)
  if not other and target and target.state and Flow.otherPending(queued,target.state)then return false end
  if not other then
   if self:hold()then return false end
   self.queued=nil;return self:open(queued,true)
  end
  -- The store was refused: stop, the saved result stays where it is (a store that landed
  -- before its snapshot just waits for the snapshot).
  local holder=self:intent(other)
  if holder and not holder.pending and holder.status=="Rejected"then self.queued=nil end
  return false
 end
 local kind=self.direct
 if not kind or not state then return false end
 local k=Flow.Kinds[kind];local intent=self:intent(kind)
 if state[k.pending]then
  self.direct=nil;self.d.view.directHatch=kind
  if not self.d.openHue(k.page or "buy",nil,"eggs")then self.d.view.directHatch=nil;return false end
  return true
 elseif intent and not intent.pending and intent.status=="Rejected"and intent.reason=="Throttled"and not self.retried then
  -- Refused only for coming too soon: send it again once, after the spacing.
  self.direct=nil;self.retried=true;self.retryKind=kind
  self:after(math.max(self:wait(),Flow.Spacing),function()
   if self.retryKind~=kind then return end
   self:open(kind,true,true)
  end)
 elseif intent and(intent.status=="Retrying"or not intent.pending)then
  self.direct=nil;if k.page then self.d.openHue(k.page,nil,"eggs")end
 end
 return false
end
return Flow
