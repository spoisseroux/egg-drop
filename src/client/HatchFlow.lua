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
--  view = HueEggView, openHue = function(page, petId, back) -> bool}
function Flow.new(d)
 return setmetatable({d=d,direct=nil,queued=nil},Flow)
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
-- Hatch (purchase=true) or open (false) the egg `kind` from Hatch eggs.
function Flow:open(kind,purchase)
 local k=Flow.Kinds[kind];if not k then return false end
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
-- After every snapshot / intent change: once the hatched result lands, open its reveal.
function Flow:sync()
 local state=self.d.state()
 if self.queued and state then
  local queued=self.queued
  local other=Flow.otherPending(queued,state)
  -- Each intent takes the snapshot in turn; the egg's own intent must have seen the store
  -- land too, or its buy is refused ("Store or use your saved egg first").
  local target=self:intent(queued)
  if not other and target and target.state and Flow.otherPending(queued,target.state)then return false end
  if not other then self.queued=nil;return self:open(queued,true)end
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
 elseif intent and(intent.status=="Retrying"or not intent.pending)then
  self.direct=nil;if k.page then self.d.openHue(k.page,nil,"eggs")end
 end
 return false
end
return Flow
