-- v2 Stat Eggs and Stat Snacks on the client: one owner for the buy, the reveal, every feed (the
-- stats panel's preview and pet focus) and the public "ate a snack" beat on other players' pets.
-- init.client.lua mounts it with a few shared pieces; it never decides anything the server owns.
--
-- deps: remotes (Folder), audio (BoardAudio), playerGui, state() -> nursery snapshot,
--   activeId() -> the pet that is out, petName(petId), roomView, closeShop(), openStats(options),
--   ownPetVisual() -> the local garden pet visual, otherPetVisual(userId) -> visual or nil,
--   inRound() -> bool
local Players=game:GetService("Players")
local GuiService=game:GetService("GuiService")
local Shared=game:GetService("ReplicatedStorage").Shared
local K=require(Shared.StatEggCatalog)
local Stats=require(Shared.StatCatalog)
local UICopy=require(Shared.UICopy)
local Intent=require(script.Parent.SnackIntent)
local Eating=require(script.Parent.SnackEating)
local Reveal=require(script.Parent.StatEggReveal)
local Odds=require(script.Parent.StatEggOdds)
local Rail=require(script.Parent.NotificationRail)
local Host={}
-- The favourite stat a fed snack cheers for: the Bear's Heart is a show of feeling only; a species
-- with PetCatalog `favouriteStat` (the Bunny: Jump, +10% XP in StatState.grant) adds its own.
Host.FavouriteStat={pip="heart"}
for _,pet in ipairs(require(game:GetService("ReplicatedStorage").Shared.PetCatalog).collection)do
	if type(pet.favouriteStat)=="string"then Host.FavouriteStat[pet.id]=pet.favouriteStat end
end

-- Pure: the plain line for a refused feed or buy.
function Host.reasonText(reason,petName,statId,buying)
	if buying then
		local key="hatch.stat.reason."..tostring(reason)
		local text=UICopy.get(key)
		if text~=key then return text end
		return UICopy.get("stats.snacks.reason.other")
	end
	local vars={pet=petName or "Bear",stat=if statId then UICopy.get("stats.name."..statId)else ""}
	local key="stats.snacks.reason."..tostring(reason)
	local text=UICopy.get(key,vars)
	if text==key then text=UICopy.get("stats.snacks.reason.other",vars)end
	return text
end
-- Pure: the rail line after a feed ("Jump boost: 2x for your next 120 XP").
function Host.boostLine(receipt)
	local size=K.size(receipt.size)or K.Sizes.nibble
	return UICopy.get("stats.snacks.line",{name=UICopy.get("stats.name."..tostring(receipt.stat)),mult=size.mult,count=size.xp})
end
-- Pure: the corner pill on the reveal (the Feast promise or the fixed next snack).
function Host.revealPill(state,petId)
	local egg=type(state)=="table"and state.statEgg or {}
	if egg.mode=="random"then
		local left=K.pityLeft(egg.misses)
		return if left<=1 then UICopy.get("hatch.stat.pityOne")else UICopy.get("hatch.stat.pity",{count=left})
	end
	local q=Odds.quote(state,petId)
	if q and q.next then return UICopy.get("hatch.stat.next",{stat=Odds.statName(q.next.stat),size=Odds.sizeName(q.next.size)})end
	return ""
end

function Host.mount(deps)
	local api={busy=false}
	local remotes=deps.remotes
	local intent=Intent.new(remotes:WaitForChild("HatchRequest"),remotes:WaitForChild("SnackResult"))
	local reveal=Reveal.new(deps.playerGui,deps.audio)
	local owner=Instance.new("Folder");owner.Name="SnackRailOwner";owner.Parent=deps.playerGui
	api.intent,api.reveal=intent,reveal
	-- Declared before intent.onLate below, which uses it (it was a nil global there).
	local notify
	-- A buy or feed the server settled after the client gave up waiting: show it now.
	intent.onLate=function(action,message)
		if message.status~="Saved"or type(message.receipt)~="table"then return end
		local receipt=message.receipt
		if action=="statEggBuy"then
			local petId=deps.activeId()
			reveal:show(receipt,api.revealInfo(petId),{
				feed=function(r)api.feedNow(r.snackId)end,keep=function()notify(UICopy.get("hatch.stat.reveal.kept"),true)end})
		else
			notify(Host.boostLine(receipt),true)
		end
		if api.onChanged then api.onChanged()end
	end
	-- Eating players: the local garden pet, the stats panel's preview, and other players' pets.
	api.garden=Eating.new(deps.audio)
	api.panel=Eating.new(deps.audio)
	api.others={} -- [userId] = {eating, visual}
	local function reduced()return GuiService.ReducedMotionEnabled end
	-- The snack pouch, for a tap on a snack line: the tray in pet focus (Focus:openSnacks is
	-- idempotent: an open tray just refreshes), else the stats panel's Snacks view. A panel
	-- already open refuses a second copy (StatsHost.open returns false) and the ticket just
	-- dismisses; it does not switch that panel to its Snacks view.
	local function openPouch()
		local room=deps.roomView
		if room and room.focusing and room.focusUI and room.focusUI.openSnacks then return room.focusUI:openSnacks()==true end
		if deps.inRound and deps.inRound()then return false end
		if deps.openStats then return deps.openStats({from="rail",snacks=true})==true end
		return false
	end
	api.openPouch=openPouch
	-- A rail line. `pouch`: a snack was fed or kept (an info line that opens the pouch on a
	-- tap); otherwise a refusal (a warning line, nothing to open).
	function notify(text,pouch)
		if text and text~=""then
			Rail.enqueue(owner,"snack:"..text,{text=text,icon=if pouch then "•"else "!",duration=2.6,
				activate=if pouch then openPouch else nil})
		end
	end
	api.notify=notify

	-- The result card (V2-HATCH-REDESIGN 2.5): the egg card's odds and Feast promise on the
	-- state after this hatch, the stock line, and Hatch another (the same buy as the egg card).
	function api.revealInfo(petId)
		return {canFeed=true,
			odds=function()return Odds.rows(deps.state(),petId)end,
			pity=function()
				local state=deps.state()
				local egg=type(state)=="table"and state.statEgg or {}
				local line=if egg.mode=="random"then Host.revealPill(state,petId)else ""
				return {line=line,sub=Odds.stockLine(state)}
			end,
			again=function()
				local state=deps.state()
				local action=Odds.action(state,petId)
				local egg=type(state)=="table"and state.statEgg or {}
				local text=if action.free then action.text else UICopy.get("hatch.result.againPrice",{count=egg.price or K.Price})
				local reason=if action.enabled then nil elseif type(action.need)=="string"and action.need~=""then action.need else action.text
				return {text=text,enabled=action.enabled==true,reason=reason,pending=api.buying==true,
					act=function()return api.buy(action.free==true)end}
			end}
	end
	-- The egg: buy (or open a free one) for the pet that is out, then the reveal.
	function api.buy(free)
		local state=deps.state();local petId=deps.activeId()
		local q=Odds.quote(state,petId)
		if api.buying or not q then return false end
		api.buying=true
		intent:buy(petId,free,q.key,function(message)
			api.buying=false
			if message.status=="Saved"and type(message.receipt)=="table"then
				if deps.closeShop then deps.closeShop()end
				local receipt=message.receipt
				reveal:show(receipt,api.revealInfo(petId),{
					feed=function(r)api.feedNow(r.snackId)end,
					keep=function()notify(UICopy.get("hatch.stat.reveal.kept"),true)end})
			else
				reveal.againPressed=nil
				notify(Host.reasonText(message.reason,nil,nil,true))
			end
			if api.onChanged then api.onChanged()end
		end)
		return true
	end

	-- One feed. where = "panel" (the stats panel's preview; options.visual, options.overlay) or
	-- "garden" (the garden pet in focus). The offer plays at once; the bites only after the receipt.
	function api.feed(snackId,where,options)
		options=options or {}
		if api.busy then return false end
		local state=deps.state();local petId=deps.activeId()
		local snack
		for _,s in ipairs(state and state.statEgg and state.statEgg.pouch or {})do if s.id==snackId then snack=s;break end end
		if not snack or not petId then return false end
		local name=deps.petName(petId)
		if deps.inRound and deps.inRound()then notify(Host.reasonText("InRound",name));return false end
		local eating=if where=="panel"then api.panel else api.garden
		local visual=if where=="panel"then options.visual else deps.ownPetVisual()
		api.busy=true
		if options.onBusy then options.onBusy(true)end
		local offered=visual~=nil and not reduced()and eating:offer(visual,{stat=snack.stat,size=snack.size})
		local _=offered
		intent:feed(snackId,petId,function(message)
			if message.status=="Saved"and type(message.receipt)=="table"then
				local receipt=message.receipt
				local favourite=Host.FavouriteStat[petId]==receipt.stat
				local function done()
					api.busy=false
					if options.onBusy then options.onBusy(false)end
					local line=Host.boostLine(receipt)
					if favourite then line..="  "..UICopy.get("stats.snacks.favourite",{pet=name})end
					notify(line,true)
					if api.onChanged then api.onChanged()end
				end
				if visual and(message.reason~="AlreadySaved"or eating:busy())then
					local ok=eating:eat(visual,{stat=receipt.stat,size=receipt.size,favourite=favourite},{reduced=reduced(),overlay=options.overlay,onDone=function()done()end})
					if not ok then done()end
				else
					eating:cancel();done()
				end
			else
				if message.status=="Timeout"then eating:cancel()else eating:refuse()end
				api.busy=false
				if options.onBusy then options.onBusy(false)end
				notify(Host.reasonText(message.reason,name,snack.stat))
				if api.onChanged then api.onChanged()end
			end
		end)
		return true
	end

	-- "Feed now" on the reveal. In pet focus already: the tray opens with that snack picked. Else
	-- the stats panel's Snacks view opens and feeds it in place at once (one press, the pet always
	-- in view; V2-FEEDING-RUNES 2 "it feeds in place"). Entering pet focus from a menu needs the
	-- pet close by and a camera move, which can fail and would strand the press.
	function api.feedNow(snackId)
		local room=deps.roomView
		if room and room.focusing and room.focusUI and room.focusUI.openSnacks then
			return room.focusUI:openSnacks(snackId)
		end
		if deps.openStats then return deps.openStats({from="reveal",snacks=true,snack=snackId,feedNow=true})end
		return false
	end

	-- Another player's pet ate a snack (the server's public beat, after its save).
	local beat=remotes:WaitForChild("SnackBeat")
	api.beatConnection=beat.OnClientEvent:Connect(function(userId,info)
		if userId==Players.LocalPlayer.UserId or type(info)~="table"or not Stats.ById[info.stat]or not K.size(info.size)then return end
		local visual=deps.otherPetVisual and deps.otherPetVisual(userId)
		if not visual then return end
		local entry=api.others[userId]
		if not entry then entry={eating=Eating.new(deps.audio,{gain=.55})};api.others[userId]=entry end
		entry.visual=visual
		entry.eating:eat(visual,{stat=info.stat,size=info.size},{reduced=reduced()})
	end)
	-- Per frame, after the pets were posed (RoomView calls this).
	function api.stepGarden(dt)
		api.garden:step(dt)
		for userId,entry in pairs(api.others)do
			if not entry.eating:busy()and #entry.eating.crumbs==0 then api.others[userId]=nil else entry.eating:step(dt)end
		end
	end
	function api.stepPanel(dt)api.panel:step(dt)end
	function api.destroy()
		intent:destroy();reveal:destroy();api.garden:destroy();api.panel:destroy()
		for _,entry in pairs(api.others)do entry.eating:destroy()end
		if api.beatConnection then api.beatConnection:Disconnect()end
		owner:Destroy()
	end
	return api
end
return Host
