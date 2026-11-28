-- The Outfit Egg in Hatch eggs, the client half (artifacts/qa-2026-11-28-rotation/ROTATION-BRIEF.md sections 3 and 4,
-- ARCH-REVIEW-ROTATION 1, 2, 9-12; switch DailyRack "rack"). The server owns the rack (DailyRack, RackState): the client
-- draws only the snapshot `public.rack` = {day, price, mode, broken, last, outfit, pets[petId] = view} and sends back
-- what the player saw. No clock is read here and no time is ever shown (kid safety: "New picks every day" and "They come
-- back", never a countdown). Off (no `rack` in the snapshot): nothing here is reached; the shop is today's.
-- Pure first (scripts/RackShop.spec.lua): the request and its id, the answers, the odds rows, the Today's picks sheet's
-- cards, the Paint Egg's odds under look_daily / look_nopity. Then the buyer (one press in flight, a retry reuses its
-- id) and mount(deps), which init wires once: the press, the answer, the egg out of the machine, the reveal on the
-- regular hatch stage (GiftStage), "Wear it!".
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local OddsText=require(Shared:WaitForChild("OddsText"))
local Copy=require(Shared:WaitForChild("UICopy"))
local Wear=require(Shared:WaitForChild("WearableCatalog"))
local LookEgg=require(Shared:WaitForChild("LookEggCatalog"))
local Rack={}
Rack.Egg="outfit"
Rack.Tile="outfit"   -- the Hatch eggs tile id
Rack.Tries=4         -- one press resends its request (the same id) at most this many times
Rack.RetryAfter=.8   -- s before a resend (the server spaces hatch requests .3 s apart)
Rack.Timeout=20      -- s with no answer: resend (the same id), then give up kindly
Rack.Rank=table.freeze({common=1,uncommon=2,rare=3,epic=4,legendary=5})
-- Rarity pills (ROTATION-BRIEF 3): Common grey, Uncommon green, Rare blue, Epic purple, Sparkle gold.
Rack.Pill=table.freeze({common="#9AA3B2",uncommon="#5CC27A",rare="#4F8DF5",epic="#9B6BE8",legendary="#F0B429"})
Rack.Columns=table.freeze({phone=2,desktop=4})
Rack.Live=table.freeze({phone=6,desktop=8}) -- previews on cards at once (ARCH-REVIEW-ROTATION 12)

-- ── The snapshot ─────────────────────────────────────────────────────────────────────────────────────────────────────
function Rack.on(state)
	local r=type(state)=="table"and state.rack or nil
	return type(r)=="table"and type(r.pets)=="table"
end
-- The view the shop sells from: `petId`'s, else the pet that is out (`outfit`).
function Rack.view(state,petId)
	if not Rack.on(state)then return nil end
	local r=state.rack
	local v=(type(petId)=="string"and r.pets[petId])or r.outfit
	return if type(v)=="table"and type(v.items)=="table"then v else nil
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
function Rack.rarityName(rarity)return Copy.get("rack.rarity."..(if Rack.Rank[rarity]then rarity else "common"))end

-- ── The request (ARCH-REVIEW-ROTATION 1, 2) ─────────────────────────────────────────────────────────────────────────
-- What the player saw, bound: {id, egg, petId, day, price, mode, poolKey, equip}. nil when the view cannot be bought
-- (resting, the closet full, a malformed snapshot).
function Rack.request(rack,view,id,equip)
	if type(rack)~="table"or type(view)~="table"or type(id)~="string"or #id<1 or #id>100 then return nil end
	if view.rest==true or view.full==true or rack.broken==true then return nil end
	local mode=view.mode or rack.mode
	if type(view.pet)~="string"or type(rack.day)~="number"or type(rack.price)~="number"or(mode~="random"and mode~="fixed")
		or type(view.poolKey)~="string"then return nil end
	return {id=id,egg=Rack.Egg,petId=view.pet,day=rack.day,price=rack.price,mode=mode,poolKey=view.poolKey,equip=equip==true}
end
-- The pane's button for the Outfit Egg: {text, enabled, short (the Stars missing, the card asks), note}.
function Rack.action(state)
	local view=Rack.view(state)
	if not view then return {text=Copy.get("rack.notReady"),enabled=false}end
	local rack=state.rack
	local price=tonumber(rack.price)or 0
	if rack.broken==true then return {text=Copy.get("rack.notReady"),enabled=false}end
	if view.rest==true then return {text=Copy.get("rack.restButton"),enabled=false,note=Copy.get("rack.rest")}end
	if view.full==true then return {text=Copy.get("rack.full"),enabled=false,note=Copy.get("rack.answer.full")}end
	local text=Copy.get("rack.hatch",{count=price})
	local missing=price-(tonumber(state.nectar)or 0)
	if missing>0 then return {text=text,enabled=false,short=missing}end
	return {text=text,enabled=true}
end

-- ── The answers (WearableResult, action "rackEgg") ──────────────────────────────────────────────────────────────────
-- -> {kind, text?, record?, replay?}
--   reveal   Saved (or AlreadySaved: a replay, read-only) with its record: the egg comes out, then its card
--   refresh  the server's rack moved on (DayChanged, PoolChanged, PriceChanged, PolicyChanged; or an older save already
--            holds it): no charge, a fresh snapshot, a kind line
--   retry    a busy save or a spaced request: the same request again (the same id)
--   stars    NeedStars: the "need more Stars" card
--   message  RackDone, ClosetFull, another reveal open, anything else: a kind line, nothing charged
local Retry=table.freeze({Busy=true,Throttled=true,Pending=true,Retrying=true,Unavailable=true})
local Changed=table.freeze({DayChanged="rack.answer.day",PoolChanged="rack.answer.changed",PriceChanged="rack.answer.changed",PolicyChanged="rack.answer.changed"})
local Said=table.freeze({RackDone="rack.answer.done",ClosetFull="rack.answer.full",RevealPending="rack.answer.reveal",NotReady="rack.answer.busy"})
function Rack.outcome(packet)
	if type(packet)~="table"then return {kind="message",text=Copy.get("rack.answer.oops")}end
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
	if Said[reason]then return {kind="message",text=Copy.get(Said[reason])}end
	return {kind="message",text=Copy.get("rack.answer.oops")}
end

-- ── One press in flight (the buyer) ─────────────────────────────────────────────────────────────────────────────────
-- deps: id() -> a fresh request id (one per press), send(request), clock(). A press while one is out is refused; an
-- answer for another id is ignored; a retry (a busy answer, a timeout) sends the very same request, so the server's
-- rack.ops answers AlreadySaved and never charges twice.
local Buyer={};Buyer.__index=Buyer
function Rack.buyer(deps)return setmetatable({d=deps,pending=nil},Buyer)end
function Buyer:busy()return self.pending~=nil end
function Buyer:press(state,petId,equip)
	if self.pending then return false,"Pending"end
	local view=Rack.view(state,petId)
	local request=view and Rack.request(state.rack,view,self.d.id(),equip)
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
	local o=Rack.outcome(packet)
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

-- ── The odds rows and the sheet (ROTATION-BRIEF 3) ──────────────────────────────────────────────────────────────────
-- Today's picks in one order, the pane's rows and the sheet's cards alike: unowned first, then by rarity (common
-- first: the likeliest on top), then deal order; the sparkle pick after the picks; owned ones last ("Yours").
local function entries(view)
	local list={}
	for index,item in ipairs(view.items or {})do
		if type(item)=="table"and type(item.id)=="string"then
			table.insert(list,{id=item.id,base=item.base,name=item.name,rarity=item.rarity or "common",units=tonumber(item.units)or 0,
				owned=item.owned==true,deal=index,sparkle=false})
		end
	end
	local s=view.sparkle
	if type(s)=="table"and type(s.id)=="string"then
		table.insert(list,{id=s.id,base=s.base,name=s.name,rarity="legendary",units=tonumber(s.units)or 0,owned=s.owned==true,
			deal=#list+1,sparkle=true,finish=s.finish})
	end
	table.sort(list,function(a,b)
		if a.owned~=b.owned then return not a.owned end
		if a.sparkle~=b.sparkle then return not a.sparkle end
		local x,y=Rack.Rank[a.rarity]or 9,Rack.Rank[b.rarity]or 9
		if x~=y then return x<y end
		return a.deal<b.deal
	end)
	return list
end
Rack.entries=entries
-- The odds text for the entries, from the exact integer units (OddsText.list: the shares add up, a rounded table says
-- so). Owned: "Yours". Fixed mode (restricted players never roll): the next pick only, "Next".
local function values(view,list)
	local total=tonumber(view.total)or 0
	local chances={}
	for i,e in ipairs(list)do chances[i]=if total>0 and not e.owned then e.units/total else 0 end
	local texts,rounded=OddsText.list(chances)
	for i,e in ipairs(list)do
		e.value=if e.owned then Copy.get("rack.yours")elseif chances[i]>0 then texts[i]else "0%"
		e.chance=chances[i]
	end
	return rounded==true
end
-- The pane's rows: {rows = {{id, name, value, rarity, pill, color, owned, sparkle, tap}}, label, per, note, rounded,
-- restricted, empty}. Every row is a button (tap: the sheet on it).
function Rack.rows(view)
	if type(view)~="table"then return {rows={},label=Copy.get("rack.label"),per=Copy.get("rack.line"),empty=Copy.get("rack.notReady")}end
	local list=entries(view)
	local petId=view.pet
	if view.mode=="fixed"then
		local rows={}
		for _,e in ipairs(list)do
			if e.id==view.next then
				table.insert(rows,{id=e.id,name=Copy.get("hatch.next.line",{item=Rack.name(petId,e.id,e.name)}),value="",rarity=e.rarity,
					pill=Rack.rarityName(e.rarity),color=Rack.color(petId,e),tap=true})
			end
		end
		return {rows=rows,label=Copy.get("hatch.next.label"),per=Copy.get("rack.line"),restricted=true,
			empty=if #rows==0 then Copy.get("rack.rest")else nil}
	end
	local rounded=values(view,list)
	local rows={}
	for _,e in ipairs(list)do
		table.insert(rows,{id=e.id,name=Rack.name(petId,e.id,e.name),value=e.value,rarity=e.rarity,pill=Rack.rarityName(e.rarity),
			color=Rack.color(petId,e),owned=e.owned,sparkle=e.sparkle,tap=true})
	end
	if rounded and #rows>0 then table.insert(rows,{id="rounded",name=Copy.get("hatch.odds.rounded"),value="",info=true})end
	return {rows=rows,label=Copy.get("rack.label"),per=Copy.get("rack.line"),rounded=rounded,
		note=if view.rest==true then Copy.get("rack.rest")else nil}
end
-- The colour dot of a row: the recolour's own hex, else its rarity's pill.
function Rack.color(petId,e)
	local item=Rack.item(petId,e.id)
	return(item and item.color)or Rack.Pill[e.rarity]or Rack.Pill.common
end
-- The Today's picks sheet: {title, line, footer, button, cards, focus, columns, live}. options = {gift (the gift's item
-- id, pinned first: "Your gift", 100%), focus (the tapped row's id), phone}. Cards: {id, name, rarity, pill, pillColor,
-- value, owned, sparkle, gift, wear (the item worn in its preview), color}.
function Rack.sheet(view,options)
	options=options or {}
	local petId=type(view)=="table"and view.pet or options.petId
	local cards={}
	if type(options.gift)=="string"then
		table.insert(cards,{id=options.gift,name=Rack.name(petId,options.gift),rarity="common",pill=Copy.get("rack.gift"),
			pillColor=Rack.Pill.legendary,value="100%",gift=true,wear=options.gift,color=Rack.color(petId,{id=options.gift,rarity="common"})})
	end
	if type(view)=="table"then
		local list=entries(view)
		if view.mode=="fixed"then
			for _,e in ipairs(list)do e.value=if e.owned then Copy.get("rack.yours")elseif e.id==view.next then Copy.get("rack.next")else "" end
		else values(view,list)end
		for _,e in ipairs(list)do
			if not(options.gift and e.id==options.gift)then
				table.insert(cards,{id=e.id,name=Rack.name(petId,e.id,e.name),rarity=e.rarity,pill=Rack.rarityName(e.rarity),
					pillColor=Rack.Pill[e.rarity]or Rack.Pill.common,value=e.value,owned=e.owned,sparkle=e.sparkle,wear=e.id,
					color=Rack.color(petId,e)})
			end
		end
	end
	local focus=1
	for i,c in ipairs(cards)do if c.id==options.focus then focus=i;break end end
	return {kind="outfit",petId=petId,title=Copy.get("rack.title"),line=Copy.get("rack.line"),footer=Copy.get("rack.back"),
		button=Copy.get(if options.gift then "rack.gotIt"else "rack.close"),cards=cards,focus=focus,
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

-- ── The client wiring (init gives the game) ─────────────────────────────────────────────────────────────────────────
-- deps: view (EggHatchView), state(), send(request), arm(id) (the machine's buy crank), snapshot(), id(), clock(),
-- result (the WearableResult remote), deliver(open) -> true when the machine took the reveal, show(record, options)
-- (GiftStage.show), equip(petId, slot, itemId), toast(text), appearance(petId), audio, reduced(), defer(seconds, fn).
function Rack.mount(deps)
	local buyer=Rack.buyer({id=deps.id,clock=deps.clock,send=function(request)deps.send(request)end})
	local mount={buyer=buyer}
	local waiting=nil -- the view's done for the press out
	local function finish(o)
		local done=waiting;waiting=nil
		if done then pcall(done,o)end
	end
	local function present(record,o)
		local petId=record.pet
		local item=Rack.item(petId,record.item)
		local chance
		if o.view then
			-- the odds it had when pressed (the view the press saw, before it was owned)
			local list=entries(o.view)
			if o.view.mode~="fixed"then values(o.view,list)end
			for _,e in ipairs(list)do if e.id==record.item then chance=e end end
		end
		local base=deps.appearance and deps.appearance(petId)or {}
		local options={text=function(key,vars)return Copy.get(key,vars)end,audio=deps.audio,reduceEffects=deps.reduced,reduced=deps.reduced,
			itemName=Rack.name(petId,record.item),rarity=record.rarity,wearAppearance=Rack.wearing(base,petId,record.item),
			detail=if chance and chance.value and not chance.owned then Copy.get("rack.reveal.detail",{rarity=Rack.rarityName(record.rarity),percent=chance.value})
				else Rack.rarityName(record.rarity),
			act=function()
				if item and deps.equip then deps.equip(petId,item.slot,record.item)end
				if deps.toast then deps.toast(Copy.get("rack.reveal.worn",{item=Rack.name(petId,record.item)}))end
			end,
			closed=function()if deps.closed then pcall(deps.closed)end end}
		local r={kind="rack",id=record.id,item=record.item,rarity=record.rarity,pet=petId}
		local function open()if not deps.show(r,options)and deps.fallback then deps.fallback(r,options)end end
		if not(deps.deliver and deps.deliver(open))then open()end
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
			pcall(function()deps.view:askStars({name=Copy.get("hatch.egg.outfit.name"),cost=tonumber(o.request and o.request.price)or 0})end)
		end
		if o.kind~="reveal"and deps.refuse then pcall(deps.refuse)end
		finish(o)
	end
	-- The view's press: true when the request went out; done(outcome) once it is answered.
	function mount.press(done)
		local ok,request=buyer:press(deps.state(),nil,false)
		if not ok then return false end
		waiting=done
		pcall(deps.arm,request.id)
		return true
	end
	mount.connection=deps.result.OnClientEvent:Connect(function(packet)handle(buyer:answer(packet))end)
	function mount.step()handle(buyer:check(deps.clock()))end
	function mount.destroy()if mount.connection then mount.connection:Disconnect();mount.connection=nil end end
	deps.view.onRackEgg=mount.press
	return mount
end

return Rack
