-- "You need more Stars" (Stars store access, Spencer 2026-11-21: "do we need to make stars
-- easier to buy in game? ... Like clicking the stars icon opens a store to buy stars?").
-- A short buy button in any shop calls Short.ask; the card is the ConfirmDialog with two
-- choices of equal size: Get Stars (the Robux store) and Play a round (earn them free).
-- Close key, B / Esc or a tap outside: nothing happens.
--
-- init.client sets the route with Short.setRoute(function(choice, request) ... end), where
-- choice is "store" or "earn". Without a route (specs, or before the client is up) ask()
-- shows nothing and returns false.
--
--   Short.ask({price, wallet, item = "Sun Hat" | nil, from = "wardrobe"}, owner) -> true when shown
--   owner (optional, code review): the screen that asked. The handle goes in owner.confirmHandle,
--   so the screen's own close (ConfirmDialog.cancelFor) closes the card with it.
local UICopy=require(game:GetService("ReplicatedStorage").Shared.UICopy)
local Short={}
local route

function Short.setRoute(fn)route=fn end
function Short.hasRoute()return route~=nil end

-- Pure: how many Stars are missing (0 when the wallet covers the price).
function Short.count(price,wallet)
 return math.max(0,math.floor(tonumber(price)or 0)-math.floor(tonumber(wallet)or 0))
end

-- Pure: the card's words for a request.
function Short.copy(request)
 local count=Short.count(request.price,request.wallet)
 local item=type(request.item)=="string"and request.item~=""and request.item or nil
 return{count=count,
  title=if count==1 then UICopy.get("starsShort.titleOne")else UICopy.get("starsShort.title",{count=count}),
  line=if item then UICopy.get("starsShort.line",{item=item,price=math.floor(tonumber(request.price)or 0)})else UICopy.get("starsShort.lineNoItem"),
  buy=UICopy.get("starsShort.buy"),earn=UICopy.get("starsShort.earn")}
end

function Short.ask(request,owner)
 if type(request)~="table"or not route then return false end
 local words=Short.copy(request)
 if words.count<=0 then return false end
 local Confirm=require(script.Parent.ConfirmDialog)
 local handle=Confirm.ask({tone="spend",title=words.title,line=words.line,confirm=words.buy,
  alt={text=words.earn,onSelect=function()if owner then owner.confirmHandle=nil end;if route then route("earn",request)end end},
  onConfirm=function()if owner then owner.confirmHandle=nil end;if route then route("store",request)end end,
  onCancel=function()if owner then owner.confirmHandle=nil end end})
 if owner then owner.confirmHandle=handle end
 return handle~=nil
end

return Short
