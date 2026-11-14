-- Weekly shelf, client side (overnight 2026-11-14 slice C, SYSTEMS-SCOPE 3.6). The shops
-- (WardrobeShop, FaceplateShop, BallShop) and the machine hub read the shelf through this
-- one module, so they agree on the week and the price they show and send.
--
-- The shelf itself is Shared.WeeklyShelf (lane K): pure and deterministic, no server
-- state. The week comes from the snapshot's `dailyDay` (the server's own day), never the
-- client clock, so the price the client sends is the one the server expects; near the
-- Monday reset a stale snapshot is refused with PriceChanged and the shop re-reads.
-- Everything here returns "no deal" while WeeklyShelf is missing or its flag is off.
local Shared=game:GetService("ReplicatedStorage").Shared
local UICopy=require(Shared.UICopy)
local Kit=require(script.Parent.DeckKit)
local Snapshot=require(script.Parent.OwnerSnapshot)
local Deal={}
Deal.Kinds=table.freeze({"wearable","faceplate","ball"})

local function optional(name)
 local module=Shared:FindFirstChild(name)
 if not module then return nil end
 local ok,value=pcall(require,module)
 return if ok then value else nil
end
-- Looked up on every call (cheap; require caches), so a module synced in later is found.
function Deal.shelf()return Deal.override or optional("WeeklyShelf")end

-- Pure: the shelf week of a snapshot's `dailyDay` (nil when it has none).
function Deal.weekOf(dailyDay)
 local day=tonumber(dailyDay)
 if not day then return nil end
 local Shelf=Deal.shelf()
 if Shelf and type(Shelf.weekOfDay)=="function"then return Shelf.weekOfDay(day)end
 local Rotation=optional("QuestRotation")
 return if Rotation then Rotation.week(day)else(day+3)//7
end
-- The week of a snapshot (default: the owner's latest one).
function Deal.week(state)
 if state==nil then state=Snapshot.read()end
 if type(state)~="table"then return nil end
 -- The server's own shelf week when the snapshot carries it (public.shelfWeek, lane S).
 if type(state.shelfWeek)=="number"then return state.shelfWeek end
 return Deal.weekOf(state.dailyDay)
end
-- Pure: this week's slots, {kind, id, full, price} each ({} when there is no shelf).
function Deal.slots(week)
 local Shelf=Deal.shelf()
 if not Shelf or week==nil then return {}end
 local ok,slots=pcall(Shelf.slots,week)
 return if ok and type(slots)=="table"then slots else {}
end
-- Pure: the shelf price of one item this week, or nil (full price).
function Deal.price(kind,id,week)
 local Shelf=Deal.shelf()
 if not Shelf or week==nil or type(id)~="string"then return nil end
 local ok,price=pcall(Shelf.price,kind,id,week)
 return if ok and type(price)=="number"then price else nil
end
-- Pure: what a shop charges and shows. Returns price, full (full is nil off the shelf).
function Deal.quote(kind,id,base,week)
 local price=Deal.price(kind,id,week)
 if price and type(base)=="number"and price<base then return price,base end
 return base,nil
end
-- Pure: a card's price line. On the shelf: the shelf price, then the full price struck
-- through (rich text; the label needs RichText).
function Deal.priceText(price,full)
 if full then return "★ "..price.."  <s>"..full.."</s>"end
 return "★ "..price
end
-- A card's status label: rich text only while it shows a struck price.
function Deal.setPrice(label,text)
 label.RichText=string.find(text,"<s>",1,true)~=nil
 label.Text=text
end

-- Pure: the names on this week's shelf for the given kinds, in slot order.
-- names = {wearable=function(id)->name, faceplate=..., ball=...}.
function Deal.names(week,kinds,names)
 local out={}
 for _,slot in ipairs(Deal.slots(week))do
  if type(slot)=="table"and table.find(kinds,slot.kind)then
   local resolve=names[slot.kind]
   local name=resolve and resolve(slot.id)
   if type(name)=="string"and name~=""then table.insert(out,name)end
  end
 end
 return out
end
-- Pure: the hub line candidates, longest first ("This week: a, b", then the short one);
-- nil when nothing of these kinds is on the shelf.
function Deal.lines(week,kinds,names)
 local list=Deal.names(week,kinds,names)
 if #list==0 then return nil end
 return {UICopy.get("shelf.line",{item=table.concat(list,", ")}),UICopy.get("shelf.short")}
end

-- The "THIS WEEK −20%" chip (Kit.chip, gold). `set(on, width)` shows it and falls back to
-- the short "−20%" when the long text would not fit `width`.
function Deal.chip(parent,height)
 local chip=Kit.chip(parent,UICopy.get("shelf.chip"),"gold",height or 22)
 chip.root.Name="ShelfChip";chip.root.Visible=false
 local api={root=chip.root,chip=chip}
 function api.set(on,width)
  chip.root.Visible=on==true
  chip.root:SetAttribute("Shelf",on==true)
  if not on then return end
  chip.set(UICopy.get("shelf.chip"),"gold")
  if width and chip.root.Size.X.Offset>width then chip.set(UICopy.get("shelf.chipShort"),"gold")end
 end
 return api
end

return Deal
