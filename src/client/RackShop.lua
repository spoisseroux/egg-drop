-- The rack eggs in Hatch eggs, the client half (artifacts/qa-2026-11-28-rotation/ROTATION-BRIEF.md sections 3 and 4,
-- ARCH-REVIEW-ROTATION 1, 2, 9-12; switch DailyRack "rack"; slice 2: ROTATION-2-BRIEF 1-5, ARCH-REVIEW-ROTATION-2 5).
-- The server owns the rack (DailyRack, RackState): the client draws only the snapshot `public.rack` = {day, price, mode,
-- broken, last, outfit, pets[petId] = view, toy?, deck?} and sends back what the player saw. No clock is read here and
-- no time is ever shown (kid safety: "New picks every day" and "They come back", never a countdown). Off (no `rack` in
-- the snapshot): nothing here is reached; the shop is today's.
-- Three eggs share the buyer, the answers and the sheet. Each is its own Hatch eggs tile (the tile id is the egg id the
-- request sends) with its own snapshot view:
--   outfit     public.rack.outfit (or pets[petId]); its price is rack.price; a tile while `rack` is there
--   toycolour  public.rack.toy  (rack_toys on): toy colours; a tile once the player owns a toy
--   deck       public.rack.deck (rack_deck on): plates and ball themes; a tile once the Snack gift is recorded
-- No egg on a call = the Outfit Egg, exactly as slice 1.
-- Pure first (scripts/RackShop.spec.lua, RackShop2.spec.lua): the tiles, the request and its id, the answers, the odds
-- rows, the Today's picks sheet's cards (wearable, toy, plate, ball), the Paint Egg's odds under look_daily /
-- look_nopity. Then the buyer (one press in flight, a retry reuses its id) and mount(deps), which init wires once: the
-- press, the answer, the egg out of the machine (every egg cranks), the reveal on the regular hatch stage (GiftStage),
-- "Wear it!" / "Use it!".
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local OddsText=require(Shared:WaitForChild("OddsText"))
local Copy=require(Shared:WaitForChild("UICopy"))
local Wear=require(Shared:WaitForChild("WearableCatalog"))
local LookEgg=require(Shared:WaitForChild("LookEggCatalog"))
local Rack={}
Rack.Egg="outfit"
Rack.Tile="outfit"   -- the Outfit Egg's Hatch eggs tile id
Rack.Tries=4         -- one press resends its request (the same id) at most this many times
Rack.RetryAfter=.8   -- s before a resend (the server spaces hatch requests .3 s apart)
Rack.Timeout=20      -- s with no answer: resend (the same id), then give up kindly
Rack.Rank=table.freeze({common=1,uncommon=2,rare=3,epic=4,legendary=5})
-- Rarity pills (ROTATION-BRIEF 3): Common grey, Uncommon green, Rare blue, Epic purple, Sparkle gold.
Rack.Pill=table.freeze({common="#9AA3B2",uncommon="#5CC27A",rare="#4F8DF5",epic="#9B6BE8",legendary="#F0B429"})
Rack.Columns=table.freeze({phone=2,desktop=4})
Rack.Live=table.freeze({phone=6,desktop=8}) -- previews on cards at once (ARCH-REVIEW-ROTATION 12)
-- The eggs, in tile order. Words are UICopy keys: name (the tile), title (the sheet), label / line (the pane's odds),
-- rest / restButton (every pick owned), full / fullButton (the closet or shelf at its cap), done (a RackDone answer),
-- use (the reveal's key) and worn (its toast). shell: the machine's drop; press: the buy action that cranks it.
Rack.Tiles=table.freeze({"outfit","toycolour","deck"})
Rack.Kinds=table.freeze({
	outfit=table.freeze({name="hatch.egg.outfit.name",title="rack.title",label="rack.label",line="rack.line",rest="rack.rest",
		restButton="rack.restButton",full="rack.answer.full",fullButton="rack.full",done="rack.answer.done",use="rack.reveal.wear",
		worn="rack.reveal.worn",shell="Hue",press="lookBuy"}),
	toycolour=table.freeze({name="rack.toy.title",title="rack.toy.title",label="rack.toy.label",line="rack.toy.line",rest="rack.toy.rest",
		restButton="rack.toy.restButton",full="rack.deck.full",fullButton="rack.deck.fullButton",done="rack.toy.rest",use="rack.toy.use",
		worn="rack.toy.worn",shell="Toy",press="toyBuy",field="toy"}),
	deck=table.freeze({name="rack.deck.title",title="rack.deck.title",label="rack.deck.label",line="rack.deck.line",rest="rack.deck.rest",
		restButton="rack.deck.restButton",full="rack.deck.full",fullButton="rack.deck.fullButton",done="rack.deck.rest",use="rack.deck.use",
		worn="rack.deck.worn",shell="Hue",press="lookBuy",field="deck"}),
})
function Rack.isTile(id)return type(id)=="string"and Rack.Kinds[id]~=nil end
local function kindOf(egg)return if type(egg)=="string"and Rack.Kinds[egg]then egg else Rack.Egg end
Rack.kindOf=kindOf
local function shared(name)
	local module=Shared:FindFirstChild(name)
	if not module then return nil end
	local ok,value=pcall(require,module)
	return if ok then value else nil
end

-- ── The snapshot ─────────────────────────────────────────────────────────────────────────────────────────────────────
function Rack.on(state)
	local r=type(state)=="table"and state.rack or nil
	return type(r)=="table"and type(r.pets)=="table"
end
-- The Outfit Egg's view: `petId`'s, else the pet that is out (`outfit`).
function Rack.view(state,petId)
	if not Rack.on(state)then return nil end
	local r=state.rack
	local v=(type(petId)=="string"and r.pets[petId])or r.outfit
	return if type(v)=="table"and type(v.items)=="table"then v else nil
end
-- The view an egg sells from: the Outfit Egg's (Rack.view), else rack.toy / rack.deck while their switches put them in.
function Rack.eggView(state,egg,petId)
	egg=kindOf(egg)
	if egg=="outfit"then return Rack.view(state,petId)end
	if not Rack.on(state)then return nil end
	local v=state.rack[Rack.Kinds[egg].field]
	return if type(v)=="table"and type(v.items)=="table"then v else nil
end
-- The pet that is out (the toy and deck eggs bind it: the server checks it is owned and writes it in `last`).
function Rack.outPet(state,fallback)
	local r=if Rack.on(state)then state.rack else nil
	local out=r and type(r.outfit)=="table"and r.outfit.pet or nil
	return if type(out)=="string"then out else fallback
end
-- An egg's price: the Outfit Egg's is rack.price (slice 1), the others' their own view's.
function Rack.price(state,egg)
	egg=kindOf(egg)
	if not Rack.on(state)then return nil end
	if egg=="outfit"then return tonumber(state.rack.price)end
	local v=Rack.eggView(state,egg)
	return v and tonumber(v.price)or nil
end
-- Owns a toy (the Toy Colour Egg's tile, ROTATION-2-BRIEF 4)? Any known toy unlocked, the "none" default aside.
function Rack.ownsToy(state)
	local unlocks=type(state)=="table"and state.toyUnlocks or nil
	if type(unlocks)~="table"then return false end
	local Toys=shared("ToyCatalog")
	for id,on in pairs(unlocks)do
		if on==true and type(id)=="string"and id~="none"and(not Toys or Toys.known(id))then return true end
	end
	return false
end
-- The Snack gift recorded (the Deck Egg's tile)? A save never owed the chain (older, gifts off) has nothing to wait for.
function Rack.snackDone(state)
	local g=type(state)=="table"and state.gifts or nil
	if type(g)~="table"or g.owed~=true then return true end
	return(type(g.granted)=="table"and g.granted.snack==true)or type(g.snack)=="table"
end
-- The rack tiles on Hatch eggs for this snapshot, in Rack.Tiles order (ROTATION-2-BRIEF 4).
function Rack.tiles(state)
	local out={}
	if not Rack.on(state)then return out end
	table.insert(out,"outfit")
	if Rack.eggView(state,"toycolour")and Rack.ownsToy(state)then table.insert(out,"toycolour")end
	if Rack.eggView(state,"deck")and Rack.snackDone(state)then table.insert(out,"deck")end
	return out
end
-- The Hatch eggs list (`base`, EggHatchView's liveOrder) with this snapshot's rack tiles: the Outfit Egg before the
-- Paint Egg (slice 1), the Toy Colour Egg right after the Toy Egg, the Deck Egg after the Paint Egg (before the Snacks).
Rack.New=table.freeze({toycolour=true,deck=true}) -- tiles that wear the client-local "New" dot until first opened
function Rack.order(base,state)
	local tiles=Rack.tiles(state)
	if #tiles==0 then return base end
	local order=table.clone(base)
	local function after(id,anchor,offset)
		if not table.find(tiles,id)then return end
		local at=table.find(order,anchor)
		table.insert(order,if at then at+offset else #order+1,id)
	end
	after("outfit","look",0)
	after("toycolour","toy",1)
	after("deck","look",1)
	return order
end
-- A wearable's catalogue row (every row ever: an egg row is never on sale, ARCH-REVIEW-ROTATION 6).
function Rack.item(petId,id)
	if type(petId)~="string"or type(id)~="string"then return nil end
	return Wear.forPet(petId,math.huge).byId[id]
end
function Rack.name(petId,id,fallback)
	local item=Rack.item(petId,id)
	return(item and item.name)or fallback or tostring(id)
end
-- A pick's name for any egg: a wearable's catalogue name, a toy colour's or a plate's / ball theme's row name.
function Rack.pickName(egg,petId,id,fallback)
	egg=kindOf(egg)
	if egg=="outfit"then return Rack.name(petId,id,fallback)end
	if type(fallback)=="string"and fallback~=""then return fallback end
	local module=shared(if egg=="toycolour"then "ToySkins"else "DeckRack")
	local row=module and module.ById and module.ById[id]
	return(row and row.name)or tostring(id)
end
function Rack.rarityName(rarity)return Copy.get("rack.rarity."..(if Rack.Rank[rarity]then rarity else "common"))end

-- ── The request (ARCH-REVIEW-ROTATION 1, 2; ARCH-REVIEW-ROTATION-2 5) ───────────────────────────────────────────────
-- What the player saw, bound: {id, egg, petId, day, price, mode, poolKey, equip}. nil when the view cannot be bought
-- (resting, the closet or shelf full, a malformed snapshot). egg (default outfit): the toy and deck eggs send their own
-- price (view.price) and the pet that is out (`petId`; their views carry no pet); day and mode are the view's when it
-- has them, else the rack's.
function Rack.request(rack,view,id,equip,egg,petId)
	egg=kindOf(egg)
	if type(rack)~="table"or type(view)~="table"or type(id)~="string"or #id<1 or #id>100 then return nil end
	if view.rest==true or view.full==true or view.broken==true or rack.broken==true then return nil end
	local mode=view.mode or rack.mode
	local day=if type(view.day)=="number"then view.day else rack.day
	local price=if egg=="outfit"then rack.price else view.price
	local pet=if type(view.pet)=="string"then view.pet else petId
	if type(pet)~="string"or type(day)~="number"or type(price)~="number"or(mode~="random"and mode~="fixed")
		or type(view.poolKey)~="string"then return nil end
	return {id=id,egg=egg,petId=pet,day=day,price=price,mode=mode,poolKey=view.poolKey,equip=equip==true}
end
-- The pane's button for a rack egg (default the Outfit Egg): {text, enabled, short (the Stars missing, the card asks), note}.
function Rack.action(state,egg)
	egg=kindOf(egg)
	local K=Rack.Kinds[egg]
	local view=Rack.eggView(state,egg)
	if not view then return {text=Copy.get("rack.notReady"),enabled=false}end
	local rack=state.rack
	local price=Rack.price(state,egg)or 0
	if rack.broken==true or view.broken==true then return {text=Copy.get("rack.notReady"),enabled=false}end
	if view.rest==true then return {text=Copy.get(K.restButton),enabled=false,note=Copy.get(K.rest)}end
	if view.full==true then return {text=Copy.get(K.fullButton),enabled=false,note=Copy.get(K.full)}end
	local text=Copy.get("rack.hatch",{count=price})
	local missing=price-(tonumber(state.nectar)or 0)
	if missing>0 then return {text=text,enabled=false,short=missing}end
	return {text=text,enabled=true}
end

-- ── The answers (WearableResult, action "rackEgg") ──────────────────────────────────────────────────────────────────
-- -> {kind, text?, record?, replay?}
--   reveal   Saved (or AlreadySaved: a replay, read-only) with its record: the egg comes out, then its card
--   refresh  the server's rack moved on (DayChanged, PoolChanged, PriceChanged, PolicyChanged; AlreadyOwned: owned
--            since the view): no charge, a fresh snapshot, a kind line
--   retry    a busy save or a spaced request: the same request again (the same id)
--   stars    NeedStars: the "need more Stars" card
--   message  RackDone, ClosetFull, ShelfFull, LockedToy, another reveal open, anything else: a kind line, nothing charged
-- Every refusal the server sends (RackState.apply, HatchProgress.rackEgg, the handler) has its line (Rack.Said); an
-- unknown one is "That didn't work. Try again."
local Retry=table.freeze({Busy=true,Throttled=true,Pending=true,Retrying=true,Unavailable=true})
local Changed=table.freeze({DayChanged="rack.answer.day",PoolChanged="rack.answer.changed",PriceChanged="rack.answer.changed",
	PolicyChanged="rack.answer.changed",AlreadyOwned="rack.answer.changed"})
local Said=table.freeze({ClosetFull="rack.answer.full",RevealPending="rack.answer.reveal",NotReady="rack.answer.busy",
	ShelfFull="rack.deck.full",LockedToy="rack.toy.locked",FromDeckEgg="rack.deck.reason",RackBroken="rack.refuse.broken",
	Unowned="rack.refuse.pet",NotOwned="rack.refuse.skin",InvalidSkin="rack.answer.oops",InvalidRack="rack.answer.oops",
	InvalidRoll="rack.answer.oops",OperationConflict="rack.answer.oops"})
Rack.Retry,Rack.Changed,Rack.Said=Retry,Changed,Said
function Rack.outcome(packet,egg)
	if type(packet)~="table"then return {kind="message",text=Copy.get("rack.answer.oops")}end
	egg=kindOf(egg or(type(packet.rack)=="table"and packet.rack.egg)or nil)
	local reason=packet.reason
	if packet.status=="Saved"then
		if type(packet.rack)=="table"and type(packet.rack.item)=="string"then
			return {kind="reveal",record=packet.rack,replay=reason=="AlreadySaved"}
		end
		return {kind="refresh"}
	end
	if packet.status=="Retrying"or Retry[reason]then return {kind="retry"}end
	if Changed[reason]then return {kind="refresh",text=Copy.get(Changed[reason])}end
	if reason=="NeedStars"then return {kind="stars"}end
	if reason=="RackDone"then return {kind="message",text=Copy.get(Rack.Kinds[egg].done)}end
	if Said[reason]then return {kind="message",text=Copy.get(Said[reason])}end
	return {kind="message",text=Copy.get("rack.answer.oops")}
end

-- ── One press in flight (the buyer) ─────────────────────────────────────────────────────────────────────────────────
-- deps: id() -> a fresh request id (one per press), send(request), clock(). A press while one is out is refused (any
-- egg: one rack press at a time); an answer for another id is ignored; a retry (a busy answer, a timeout) sends the
-- very same request, so the server's rack.ops answers AlreadySaved and never charges twice.
local Buyer={};Buyer.__index=Buyer
function Rack.buyer(deps)return setmetatable({d=deps,pending=nil},Buyer)end
function Buyer:busy()return self.pending~=nil end
-- petId: the Outfit Egg's pet (nil: the one out); for the toy and deck eggs, the pet that is out (nil: the rack's).
function Buyer:press(state,petId,equip,egg)
	if self.pending then return false,"Pending"end
	egg=kindOf(egg)
	local outfit=egg=="outfit"
	local view=Rack.eggView(state,egg,if outfit then petId else nil)
	local request=view and Rack.request(state.rack,view,self.d.id(),equip,egg,if outfit then nil else(petId or Rack.outPet(state)))
	if not request then return false,"NotReady"end
	self.pending={request=request,tries=0,at=self.d.clock(),view=view}
	self.d.send(request)
	return true,request
end
-- The same request again (its id unchanged). False when nothing is out.
function Buyer:resend()
	local p=self.pending
	if not p then return false end
	p.at=self.d.clock()
	self.d.send(p.request)
	return true
end
-- An answer: nil when it is not this press's; else the outcome. A retry under Tries keeps the press out (the caller
-- resends after RetryAfter); over it, a kind line and the press ends.
function Buyer:answer(packet)
	local p=self.pending
	if not p or type(packet)~="table"or packet.action~="rackEgg"or packet.id~=p.request.id then return nil end
	local o=Rack.outcome(packet,p.request.egg)
	if o.kind=="retry"then
		if p.tries<Rack.Tries then p.tries+=1;o.request=p.request;return o end
		o={kind="message",text=Copy.get("rack.answer.busy")}
	end
	self.pending=nil
	o.request=p.request;o.view=p.view
	return o
end
-- No answer for Timeout s: resend (the same id) while tries remain, else let go with a kind line. -> outcome or nil.
function Buyer:check(now)
	local p=self.pending
	if not p or now-p.at<Rack.Timeout then return nil end
	if p.tries<Rack.Tries then p.tries+=1;self:resend();return {kind="retry",request=p.request}end
	self.pending=nil
	return {kind="message",text=Copy.get("rack.answer.busy"),request=p.request,view=p.view}
end

-- ── The odds rows and the sheet (ROTATION-BRIEF 3, ROTATION-2-BRIEF 1-3) ────────────────────────────────────────────
-- Today's picks in one order, the pane's rows and the sheet's cards alike: the ones you can get first, by rarity (common
-- first: the likeliest on top), then deal order; the sparkle pick after the picks; a locked toy colour after those
-- (its toy comes from the Toy Egg); owned ones last ("Yours").
local function entries(view)
	local list={}
	for index,item in ipairs(view.items or {})do
		if type(item)=="table"and type(item.id)=="string"then
			table.insert(list,{id=item.id,base=item.base,name=item.name,rarity=item.rarity or "common",units=tonumber(item.units)or 0,
				owned=item.owned==true,locked=item.locked==true and item.owned~=true,deal=index,sparkle=false,toy=item.toy,
				deckKind=item.kind,hex=item.hex})
		end
	end
	local s=view.sparkle
	if type(s)=="table"and type(s.id)=="string"then
		-- Angel Wings (ROTATION-2-BRIEF 3): on a wings day the sparkle pick, a flat 1%, legendary like every sparkle pick
		table.insert(list,{id=s.id,base=s.base,name=if s.wings==true then Copy.get("rack.wings.name")else s.name,rarity="legendary",
			units=tonumber(s.units)or 0,owned=s.owned==true,deal=#list+1,sparkle=true,finish=s.finish,wings=s.wings==true})
	end
	local function group(e)return if e.owned then 3 elseif e.locked then 2 else 1 end
	table.sort(list,function(a,b)
		if group(a)~=group(b)then return group(a)<group(b)end
		if a.sparkle~=b.sparkle then return not a.sparkle end
		local x,y=Rack.Rank[a.rarity]or 9,Rack.Rank[b.rarity]or 9
		if x~=y then return x<y end
		return a.deal<b.deal
	end)
	return list
end
Rack.entries=entries
-- The odds text for the entries, from the exact integer units (OddsText.list: the shares add up, a rounded table says
-- so). Owned: "Yours". Locked: "Get toy". Fixed mode (restricted players never roll): the next pick only, "Next".
local function values(view,list)
	local total=tonumber(view.total)or 0
	local chances={}
	for i,e in ipairs(list)do chances[i]=if total>0 and not e.owned and not e.locked then e.units/total else 0 end
	local texts,rounded=OddsText.list(chances)
	for i,e in ipairs(list)do
		e.value=if e.owned then Copy.get("rack.yours")elseif e.locked then Copy.get("rack.toy.lockedTag")elseif chances[i]>0 then texts[i]else "0%"
		e.chance=chances[i]
	end
	return rounded==true
end
-- The view's egg, read from its shape when no egg is named: toy items carry `toy`, deck items `kind`.
local function eggOfView(view,egg)
	if Rack.isTile(egg)then return egg end
	local first=type(view)=="table"and type(view.items)=="table"and view.items[1]or nil
	if type(first)=="table"then
		if type(first.toy)=="string"then return "toycolour"end
		if first.kind=="plate"or first.kind=="ball"then return "deck"end
	end
	return Rack.Egg
end
Rack.eggOfView=eggOfView
local function plateRow(id)local Plates=shared("DeckThemes");return Plates and Plates.ById and Plates.ById[id]end
-- The colour dot of a row: a recolour's own hex, a toy colour's hex, a plate's accent, a ball theme's middle ball, else
-- its rarity's pill.
function Rack.color(petId,e,egg)
	egg=kindOf(egg)
	if egg=="toycolour"then
		local row=(shared("ToySkins")or {}).ById
		row=row and row[e.id]
		return e.hex or(row and row.hex)or Rack.Pill[e.rarity]or Rack.Pill.common
	end
	if egg=="deck"then
		local kind=e.deckKind
		if kind=="plate"then local theme=plateRow(e.id);if theme and theme.accent then return theme.accent end end
		if kind=="ball"then
			local Balls=shared("BallThemes")
			local ok,ramp=pcall(function()return Balls.ramp(3,e.id)end)
			if ok and type(ramp)=="table"and type(ramp.body)=="string"then return ramp.body end
		end
		return Rack.Pill[e.rarity]or Rack.Pill.common
	end
	local item=Rack.item(petId,e.id)
	return(item and item.color)or Rack.Pill[e.rarity]or Rack.Pill.common
end
-- The pane's rows: {rows = {{id, name, value, rarity, pill, color, owned, locked, sparkle, tap}}, label, per, note,
-- rounded, restricted, empty, egg}. Every row is a button (tap: the sheet on it).
function Rack.rows(view,egg)
	egg=eggOfView(view,egg)
	local K=Rack.Kinds[egg]
	if type(view)~="table"then return {rows={},label=Copy.get(K.label),per=Copy.get(K.line),empty=Copy.get("rack.notReady"),egg=egg}end
	local list=entries(view)
	local petId=view.pet
	if view.mode=="fixed"then
		local rows={}
		for _,e in ipairs(list)do
			if e.id==view.next then
				table.insert(rows,{id=e.id,name=Copy.get("hatch.next.line",{item=Rack.pickName(egg,petId,e.id,e.name)}),value="",rarity=e.rarity,
					pill=Rack.rarityName(e.rarity),color=Rack.color(petId,e,egg),tap=true})
			end
		end
		return {rows=rows,label=Copy.get("hatch.next.label"),per=Copy.get(K.line),restricted=true,
			empty=if #rows==0 then Copy.get(K.rest)else nil,egg=egg}
	end
	local rounded=values(view,list)
	local rows={}
	for _,e in ipairs(list)do
		table.insert(rows,{id=e.id,name=Rack.pickName(egg,petId,e.id,e.name),value=e.value,rarity=e.rarity,pill=Rack.rarityName(e.rarity),
			color=Rack.color(petId,e,egg),owned=e.owned,locked=e.locked,sparkle=e.sparkle,wings=e.wings,tap=true})
	end
	if rounded and #rows>0 then table.insert(rows,{id="rounded",name=Copy.get("hatch.odds.rounded"),value="",info=true})end
	return {rows=rows,label=Copy.get(K.label),per=Copy.get(K.line),rounded=rounded,
		note=if view.rest==true then Copy.get(K.rest)else nil,egg=egg}
end
-- The Today's picks sheet: {kind (the egg), title, line, footer, button, cards, focus, columns, live}. options = {egg,
-- gift (the gift's item id, pinned first: "Your gift", 100%), focus (the tapped row's id), phone}. Cards: {id, name,
-- rarity, pill, pillColor, value, owned, sparkle, gift, color} plus, by egg:
--   outfit     wear (the item worn in its preview)
--   toycolour  kind "toy", toy, skin (the toy in that colour), locked (its toy comes from the Toy Egg: the line says so)
--   deck       kind "plate" (plate: its texture on the handheld) | "ball" (ball: its five balls), accent (the trim)
function Rack.sheet(view,options)
	options=options or {}
	local egg=eggOfView(view,options.egg)
	local K=Rack.Kinds[egg]
	local petId=type(view)=="table"and view.pet or options.petId
	local cards={}
	if egg=="outfit"and type(options.gift)=="string"then
		table.insert(cards,{id=options.gift,name=Rack.name(petId,options.gift),rarity="common",pill=Copy.get("rack.gift"),
			pillColor=Rack.Pill.legendary,value="100%",gift=true,wear=options.gift,color=Rack.color(petId,{id=options.gift,rarity="common"})})
	end
	if type(view)=="table"then
		local list=entries(view)
		if view.mode=="fixed"then
			for _,e in ipairs(list)do
				e.value=if e.owned then Copy.get("rack.yours")elseif e.locked then Copy.get("rack.toy.locked")elseif e.id==view.next then Copy.get("rack.next")else ""
			end
		else
			values(view,list)
			for _,e in ipairs(list)do if e.locked then e.value=Copy.get("rack.toy.locked")end end
		end
		for _,e in ipairs(list)do
			if not(options.gift and e.id==options.gift)then
				local card={id=e.id,name=Rack.pickName(egg,petId,e.id,e.name),rarity=e.rarity,pill=Rack.rarityName(e.rarity),
					pillColor=Rack.Pill[e.rarity]or Rack.Pill.common,value=e.value,owned=e.owned,sparkle=e.sparkle,wings=e.wings,
					color=Rack.color(petId,e,egg)}
				if egg=="toycolour"then
					card.kind="toy";card.toy=e.toy or(((shared("ToySkins")or {}).ById or {})[e.id]or {}).toy;card.skin=e.id;card.locked=e.locked
				elseif egg=="deck"then
					card.kind=if e.deckKind=="ball"then "ball"else "plate"
					if card.kind=="plate"then card.plate=e.id else card.ball=e.id end
					card.accent=card.color
				else
					card.wear=e.id
				end
				table.insert(cards,card)
			end
		end
	end
	local focus=1
	for i,c in ipairs(cards)do if c.id==options.focus then focus=i;break end end
	return {kind=egg,petId=petId,title=Copy.get(K.title),line=Copy.get(K.line),footer=Copy.get("rack.back"),
		button=Copy.get(if options.gift and egg=="outfit"then "rack.gotIt"else "rack.close"),cards=cards,focus=focus,
		columns=if options.phone then Rack.Columns.phone else Rack.Columns.desktop,live=if options.phone then Rack.Live.phone else Rack.Live.desktop}
end

-- The pet wearing `itemId` over `appearance` (a preview, never saved): the item's slot keys emptied, then its keys.
function Rack.wearing(appearance,petId,itemId)
	local a=table.clone(type(appearance)=="table"and appearance or {})
	local item=Rack.item(petId,itemId)
	local worn=table.clone(type(a.wearables)=="table"and a.wearables or {})
	if item then
		for _,key in ipairs(Wear.slotKeys(petId,item.slot)or {})do worn[key]=nil end
		for _,key in ipairs(item.keys or {})do worn[key]=item.id end
	end
	a.wearables=worn
	return a
end

-- ── The Paint Egg's odds under its switches (ARCH-REVIEW-ROTATION 7, 8) ────────────────────────────────────────────
-- state.lookDay (look_daily on): that day's splash table; state.lookNoPity (look_nopity on): never a guaranteed charm,
-- and no "charm in N" line. Both absent: today's egg exactly. -> {missing, misses, day, noPity, due, left, each, rows}
function Rack.lookTable(state)
	state=type(state)=="table"and state or {}
	local missing=LookEgg.missing(state.charmUnlocks)
	local misses=if LookEgg.validMisses(state.lookCharmMisses)then state.lookCharmMisses else 0
	local day=if type(state.lookDay)=="number"and state.lookDay%1==0 then state.lookDay else nil
	local noPity=state.lookNoPity==true
	local due=LookEgg.pityDue(missing,misses,noPity)
	local left=LookEgg.pityLeft(missing,misses,noPity)
	local row=LookEgg.tables(day)[#missing]
	return {missing=missing,misses=misses,day=day,noPity=noPity,due=due,left=left,charm=row and row.charm or 0,
		rows=LookEgg.odds(missing,day)or {},splash=LookEgg.splashOf(day)}
end
-- The Paint Egg's sheet: today's pots (the pet painted each), the shine jars, the charms; the splash pot marked while
-- look_daily is on. `rows` are EggHatchView.lookOdds's. -> the same shape as Rack.sheet.
function Rack.paintSheet(rows,state,options)
	options=options or {}
	local t=Rack.lookTable(state)
	local cards={}
	for _,r in ipairs(rows or {})do
		if not r.info and r.id~="next"and r.id~="charmCountdown"then
			local kind=if r.id=="charm"then "charm"else LookEgg.kind(r.id)
			table.insert(cards,{id=r.id,name=r.name,value=r.value,kind=kind,paint=if kind=="hue"then r.id else nil,
				finishJar=if kind=="finish"then r.id else nil,splash=t.splash~=nil and r.id==t.splash,
				pill=if t.splash~=nil and r.id==t.splash then Copy.get("rack.splash")else nil,pillColor=Rack.Pill.legendary})
		end
	end
	local focus=1
	for i,c in ipairs(cards)do if c.id==options.focus then focus=i;break end end
	return {kind="paint",petId=options.petId,title=Copy.get("rack.paintTitle"),line=Copy.get(if t.day then "rack.paintDaily"else "rack.paintLine"),
		footer=Copy.get("rack.paintBack"),button=Copy.get("rack.close"),cards=cards,focus=focus,
		columns=if options.phone then Rack.Columns.phone else Rack.Columns.desktop,live=if options.phone then Rack.Live.phone else Rack.Live.desktop}
end

-- The onboarding path (the tile, an odds row, the sheet, Hatch free!) is GiftShop.aim's.

-- ── The reveal's record (pure) ──────────────────────────────────────────────────────────────────────────────────────
-- The stage record (GiftStage) for a saved pick: {kind = "rack" | "rackToy" | "rackDeck", id, item, rarity, pet, toy?,
-- deckKind?}. The Toy Colour Egg's names the toy that wears it; the Deck Egg's says plate or ball (the server's
-- `last.kind`, else the DeckRack row).
function Rack.stageRecord(record,egg)
	egg=kindOf(egg or(type(record)=="table"and record.egg)or nil)
	local r={kind="rack",id=record.id,item=record.item,rarity=record.rarity,pet=record.pet}
	if egg=="toycolour"then
		local row=((shared("ToySkins")or {}).ById or {})[record.item]
		r.kind="rackToy";r.toy=row and row.toy or nil
	elseif egg=="deck"then
		local Deck=shared("DeckRack")
		r.kind="rackDeck";r.deckKind=if record.kind=="plate"or record.kind=="ball"then record.kind else(Deck and Deck.kindOf(record.item))
	end
	return r,egg
end

-- ── The client wiring (init gives the game) ─────────────────────────────────────────────────────────────────────────
-- deps: view (EggHatchView), state(), send(request), arm(id, action) (the machine's buy crank: every egg cranks),
-- snapshot(), id(), clock(), result (the WearableResult remote), deliver(open, shell) -> true when the machine took the
-- reveal, show(record, options) (GiftStage.show), equip(petId, slot, itemId), wearToy(toyId, skinId) (toySkinWear),
-- useDeck(kind, id) (the existing plate and ball equip paths), deckArt(parent, result, position, size, z) (the 2D
-- plate / balls for the stage), petId() (the pet that is out), toast(text), appearance(petId), audio, reduced(),
-- defer(seconds, fn).
function Rack.mount(deps)
	local buyer=Rack.buyer({id=deps.id,clock=deps.clock,send=function(request)deps.send(request)end})
	local mount={buyer=buyer}
	local waiting=nil -- the view's done for the press out
	local function finish(o)
		local done=waiting;waiting=nil
		if done then pcall(done,o)end
	end
	local function present(record,o)
		local r,egg=Rack.stageRecord(record,record.egg or(o.request and o.request.egg))
		local K=Rack.Kinds[egg]
		local petId=record.pet
		local chance
		if o.view then
			-- the odds it had when pressed (the view the press saw, before it was owned)
			local list=entries(o.view)
			if o.view.mode~="fixed"then values(o.view,list)end
			for _,e in ipairs(list)do if e.id==record.item then chance=e end end
		end
		local name=Rack.pickName(egg,petId,record.item,chance and chance.name)
		local options={text=function(key,vars)return Copy.get(key,vars)end,audio=deps.audio,reduceEffects=deps.reduced,reduced=deps.reduced,
			itemName=name,rarity=record.rarity,
			detail=if chance and chance.value and not chance.owned and not chance.locked then Copy.get("rack.reveal.detail",{rarity=Rack.rarityName(record.rarity),percent=chance.value})
				else Rack.rarityName(record.rarity),
			closed=function()if deps.closed then pcall(deps.closed)end end}
		if egg=="toycolour"then
			options.act=function()
				if r.toy and deps.wearToy then deps.wearToy(r.toy,record.item)end
				if deps.toast then deps.toast(Copy.get(K.worn,{item=name}))end
			end
		elseif egg=="deck"then
			options.resultBuilder=deps.deckArt
			options.act=function()
				if r.deckKind and deps.useDeck then deps.useDeck(r.deckKind,record.item)end
				if deps.toast then deps.toast(Copy.get(K.worn,{item=name}))end
			end
		else
			local item=Rack.item(petId,record.item)
			local base=deps.appearance and deps.appearance(petId)or {}
			options.wearAppearance=Rack.wearing(base,petId,record.item)
			options.act=function()
				if item and deps.equip then deps.equip(petId,item.slot,record.item)end
				if deps.toast then deps.toast(Copy.get(K.worn,{item=name}))end
			end
		end
		local function open()if not deps.show(r,options)and deps.fallback then deps.fallback(r,options)end end
		if not(deps.deliver and deps.deliver(open,K.shell))then open()end
	end
	local function handle(o)
		if not o then return end
		if o.kind=="retry"then
			deps.defer(Rack.RetryAfter,function()if buyer.pending and buyer.pending.request==o.request then buyer:resend()end end)
			return
		end
		if o.kind=="reveal"then
			if deps.view:isOpen()then deps.view:close("gift")end
			present(o.record,o)
		elseif o.kind=="refresh"then
			deps.snapshot()
		elseif o.kind=="stars"then
			local egg=kindOf(o.request and o.request.egg)
			pcall(function()deps.view:askStars({id=egg,name=Copy.get(Rack.Kinds[egg].name),cost=tonumber(o.request and o.request.price)or 0})end)
		end
		if o.kind~="reveal"and deps.refuse then pcall(deps.refuse)end
		finish(o)
	end
	-- The view's press for egg `egg` (nil: the Outfit Egg): true when the request went out; done(outcome) once answered.
	function mount.press(done,egg)
		egg=kindOf(egg)
		-- the toy and deck eggs: the server's pet that is out (rack.outfit), else the one the garden shows
		local state=deps.state()
		local petId=if egg~="outfit"then Rack.outPet(state,deps.petId and deps.petId()or nil)else nil
		local ok,request=buyer:press(state,petId,false,egg)
		if not ok then return false end
		waiting=done
		pcall(deps.arm,request.id,Rack.Kinds[egg].press)
		return true
	end
	mount.connection=deps.result.OnClientEvent:Connect(function(packet)handle(buyer:answer(packet))end)
	function mount.step()handle(buyer:check(deps.clock()))end
	function mount.destroy()if mount.connection then mount.connection:Disconnect();mount.connection=nil end end
	deps.view.onRackEgg=mount.press
	return mount
end

return Rack
