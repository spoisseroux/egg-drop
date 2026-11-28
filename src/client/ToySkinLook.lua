-- Toy colours, the client half (ROTATION-2-BRIEF section 1, lane C; ARCH-REVIEW-ROTATION-2 point 8). Pure: no instances.
-- The one place the client reads Shared.ToySkins (lane A's rows), so a shape change there is aligned here alone:
--   row      ToySkins.ById[id] = {id, toy, colour, name, hex, rarity, part}  (toyId / color / partName also accepted)
--   snapshot state.rack.toy = {owned = {skinId = true} | {skinId...}, worn = {toyId = skinId}, items...}; present only
--            while the `toys` switch is on (off: no swatches, every toy draws its original colour)
--   public   PetAppearance[petId].toySkin (other players), whitelisted by GardenClient.appearance through publicSkin
--   answer   WearableResult {action = "toySkinWear", id, status = "Saved" | "Retrying" | anything else (refused), reason}
-- An unknown skin, a skin of another toy, or "none" draws the original colour, never an error.
local Shared=game:GetService("ReplicatedStorage").Shared
local Skins=require(Shared.ToySkins)
local Swatches=require(script.Parent.WardrobeSwatches)
local Look={}
Look.None="none"
Look.Action="toySkinWear"
Look.MaxId=32
-- The tinted part of each toy (the brief's table) and its original colour (PetToyGeometry's own): the first swatch.
Look.Parts=table.freeze({ball="FeltBall",bone="BoneBody",sparkler="IndigoGrip",wobble_top="TealBody",squeaky_carrot="CarrotBody",pocket_deck="DeckShell"})
Look.Original=table.freeze({ball="#D0E83A",bone="#FFF1D6",sparkler="#333C78",wobble_top="#3FB7B0",squeaky_carrot="#FF8A3C",pocket_deck="#F3E9D2"})
Look.SparkWhite=.6 -- the sparkler's sparks start at the skin colour lerped 60% to white and end at the skin colour

function Look.validId(id)
	return type(id)=="string"and #id>=1 and #id<=Look.MaxId and string.match(id,"^[a-z][a-z0-9_]*$")~=nil
end
local function hexOf(value)
	if typeof(value)=="Color3"then return value:ToHex()end
	if type(value)=="string"then local s=string.gsub(value,"^#","");if string.match(s,"^%x%x%x%x%x%x$")then return string.upper(s)end end
	return nil
end
-- A ToySkins row in one shape, or nil.
function Look.row(id)
	if not Look.validId(id)or id==Look.None then return nil end
	local raw=(Skins.get and Skins.get(id))or(Skins.ById and Skins.ById[id])
	if type(raw)~="table"then return nil end
	local toy=raw.toy or raw.toyId
	local hex=hexOf(raw.hex or raw.color)
	if type(toy)~="string"or not hex then return nil end
	local part=raw.part or raw.partName or(Skins.Parts and Skins.Parts[toy])or Look.Parts[toy]
	return {id=id,toy=toy,name=if type(raw.name)=="string"then raw.name else id,hex="#"..hex,color=Color3.fromHex(hex),rarity=raw.rarity or "common",part=part}
end
-- The skin `skinId` drawn on toy `toyId`: its row, or nil (unknown, another toy's, none).
function Look.skin(toyId,skinId)
	local row=Look.row(skinId)
	return if row and row.toy==toyId then row else nil
end
-- The colour part `partName` of toy `toyId` takes under `skin` (a row from Look.skin, or nil): the skin's colour on its
-- named part, `default` everywhere else.
function Look.tint(skin,partName,default)
	return if skin and skin.part==partName then skin.color else default
end
-- The sparkler's spark colours under `skin`: (start, end) Color3, or nil for the warm original sparks.
function Look.sparks(skin)
	if not skin then return nil end
	return skin.color:Lerp(Color3.new(1,1,1),Look.SparkWhite),skin.color
end
-- Every row of `toyId`, in ToySkins order.
function Look.forToy(toyId)
	local out={}
	for _,id in ipairs(Skins.Order or {})do local row=Look.row(id);if row and row.toy==toyId then table.insert(out,row)end end
	return out
end

-- ── The snapshot ─────────────────────────────────────────────────────────────────────────────────────────────────────
function Look.state(state)
	local rack=type(state)=="table"and state.rack
	local toy=type(rack)=="table"and rack.toy
	return if type(toy)=="table"and toy.off~=true then toy else nil
end
function Look.on(state)return Look.state(state)~=nil end
-- Owned skin ids as a set (the save's map, or a list).
function Look.owned(state)
	local toy=Look.state(state);local set={}
	local owned=toy and toy.owned
	if type(owned)=="table"then
		for k,v in pairs(owned)do
			if type(k)=="string"and v==true then set[k]=true elseif type(v)=="string"then set[v]=true end
		end
	end
	return set
end
-- The skin worn on `toyId` (the server's word), or nil for the original.
function Look.worn(state,toyId)
	local toy=Look.state(state)
	local id=toy and type(toy.worn)=="table"and toy.worn[toyId]
	return if Look.skin(toyId,id)then id else nil
end
-- {toyId = skinId} for every toy wearing a colour (an appearance's `toySkins`).
function Look.wornMap(state)
	local out={}
	for toyId in pairs(Look.Parts)do out[toyId]=Look.worn(state,toyId)end
	return out
end
-- The skin to draw for `toyId` from an appearance: `toySkins[toyId]` (the owner's map), else `toySkin` (the public field,
-- for the appearance's own toyId). nil = the original.
function Look.forAppearance(a,toyId)
	if type(a)~="table"then return nil end
	local id=if type(a.toySkins)=="table"then a.toySkins[toyId]else nil
	if id==nil and a.toyId==toyId then id=a.toySkin end
	return if Look.skin(toyId,id)then id else nil
end
-- GardenClient's whitelist: another player's published skin, kept only when it is a well-formed id of that toy.
function Look.publicSkin(toyId,raw)
	if type(toyId)~="string"or toyId==Look.None or not Look.validId(raw)or raw==Look.None then return nil end
	return if Look.skin(toyId,raw)then raw else nil
end
-- The swatch row for `toyId`: the original first, then the owned colours (ToySkins order). nil when the switch is off or
-- the toy has no colours. `originalName` labels the first swatch.
function Look.swatches(state,toyId,originalName)
	if not Look.on(state)or not Look.Original[toyId]then return nil end
	local owned=Look.owned(state)
	local list={{id=Look.None,name=originalName or "Original",hex=Look.Original[toyId],color=Color3.fromHex(Look.Original[toyId]),original=true}}
	for _,row in ipairs(Look.forToy(toyId))do if owned[row.id]then table.insert(list,row)end end
	return list
end

-- ── The wear queue (one in flight, last tap wins; WardrobeSwatches) ─────────────────────────────────────────────────
-- d = {id = () -> unique id, send = (order) -> ()}. Orders: {id, action = "toySkinWear", toyId, skinId (or "none")}.
local Queue={};Queue.__index=Queue
function Look.queue(d)return setmetatable({d=d or {},swatches=Swatches.new(),saved={},message=nil},Queue)end
-- The look: the server's `worn` map, the saves already answered (until a snapshot catches up), then every open order.
function Queue:shown(worn)
	local out=table.clone(type(worn)=="table"and worn or {})
	for toyId,id in pairs(self.saved)do out[toyId]=if id==Look.None then nil else id end
	for _,order in ipairs(self.swatches:open())do out[order.toyId]=if order.skinId==Look.None then nil else order.skinId end
	return out
end
-- A new snapshot: saves it now shows are no longer overlaid.
function Queue:sync(worn)
	worn=type(worn)=="table"and worn or {}
	for toyId,id in pairs(self.saved)do if(worn[toyId]or Look.None)==id then self.saved[toyId]=nil end end
end
function Queue:confirmed(worn)
	local out=table.clone(type(worn)=="table"and worn or {})
	for toyId,id in pairs(self.saved)do out[toyId]=if id==Look.None then nil else id end
	return out
end
-- A tap: wear `skinId` ("none" = the original) on `toyId`. `worn` = the server's map. False when it changes nothing.
function Queue:tap(toyId,skinId,worn)
	if type(toyId)~="string"or(skinId~=Look.None and not Look.skin(toyId,skinId))then return false end
	if(self:shown(worn)[toyId]or Look.None)==skinId then return false end
	local order={id=if self.d.id then self.d.id()else tostring(os.clock()),action=Look.Action,toyId=toyId,skinId=skinId}
	local send=self.swatches:tap(order)
	self.message=nil
	if send and self.d.send then self.d.send(send)end
	return true
end
function Queue:busy()return self.swatches:busy()end
-- An answer. Returns true when it was this queue's. A Retrying answer is the server's last word on that order (its save
-- retries on its own): the queue lets go and sends the tap waiting behind it (WardrobeShop's beta 45 fix).
function Queue:result(message,worn)
	if type(message)~="table"or(message.action~=nil and message.action~=Look.Action)then return false end
	local inflight=self.swatches.inflight
	if not inflight or inflight.id~=message.id then return false end
	if message.status=="Saved"or message.status=="Retrying"then
		self.saved[inflight.toyId]=inflight.skinId;self.message=nil
	else
		self.message=message.reason or "Refused"
	end
	local confirmed=self:confirmed(worn)
	local nextOrder=self.swatches:settle(message.id,function(o)return(confirmed[o.toyId]or Look.None)~=o.skinId end)
	if nextOrder and self.d.send then self.d.send(nextOrder)end
	return true
end
function Queue:clear()self.swatches:clear();table.clear(self.saved);self.message=nil end
Look.Queue=Queue
return Look
