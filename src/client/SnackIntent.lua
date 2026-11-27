-- v2 Stat Eggs: the client's side of statEggBuy and snackFeed (HatchRequest; replies on
-- SnackResult). It only asks: every rule is the server's. One operation id per press, kept across
-- "Retrying" and the soft refusals (Busy, Throttled) so a commit the server finds later is
-- confirmed by the same id (architect review). A feed that gets no answer in Timeout seconds
-- ends on screen ("Timeout"); the next snapshot is the truth.
local HttpService=game:GetService("HttpService")
local Intent={}
Intent.__index=Intent
Intent.FeedTimeout=4
Intent.BuyTimeout=10
Intent.RetryDelay=.6
Intent.MaxResends=4

-- request, result: RemoteEvents (or test doubles with FireServer / OnClientEvent:Connect).
-- options.guid, options.delay: test seams.
function Intent.new(request,result,options)
	options=options or {}
	local self=setmetatable({request=request,waiting={},unsettled={},guid=options.guid or function()return HttpService:GenerateGUID(false)end,
		delay=options.delay or task.delay},Intent)
	if result then self.connection=result.OnClientEvent:Connect(function(message)self:onResult(message)end)end
	return self
end
function Intent:pending(action)
	for _,w in pairs(self.waiting)do if action==nil or w.action==action then return true end end
	return false
end
function Intent:send(action,value,callback,timeout)
	local id=self.guid()
	value.id=id
	local w={action=action,value=value,callback=callback,resends=0,done=false}
	self.waiting[id]=w
	self.request:FireServer(action,value)
	self.delay(timeout,function()
		if self.waiting[id]==w and not w.done then
			w.done=true;self.waiting[id]=nil;self.unsettled[id]=w
			callback({id=id,action=action,status="Timeout",reason="Timeout"})
		end
	end)
	return id
end
-- Code review: an op that ended on screen still "Retrying" or timed out can be settled later by
-- the server's background retry, which answers the same id. That late answer goes to onLate
-- (the host shows the reveal or the boost line), so the player is never invited to buy again.
function Intent:onResult(message)
	if type(message)~="table"or type(message.id)~="string"then return end
	local late=self.unsettled[message.id]
	if late and message.status~="Retrying"then
		self.unsettled[message.id]=nil
		if self.onLate then self.onLate(late.action,message)end
		return
	end
	local w=self.waiting[message.id]
	if not w or w.done then return end
	local soft=message.status=="Retrying"or(message.status=="Rejected"and(message.reason=="Busy"or message.reason=="Throttled"))
	if soft and w.resends<Intent.MaxResends then
		w.resends+=1
		self.delay(Intent.RetryDelay,function()
			if self.waiting[message.id]==w and not w.done then self.request:FireServer(w.action,w.value)end
		end)
		return
	end
	w.done=true;self.waiting[message.id]=nil
	if message.status=="Retrying"then self.unsettled[message.id]=w end
	w.callback(message)
end
-- quote: the key the card showed (statEgg.quotes[petId].key). gift: the gift chain's free Snack Egg (an explicit ask,
-- always free; the server never falls back to the bank or a medal egg).
function Intent:buy(petId,free,quote,callback,gift)
	local value={petId=petId,free=free==true or gift==true,quote=quote}
	if gift==true then value.gift=true end
	return self:send("statEggBuy",value,callback,Intent.BuyTimeout)
end
function Intent:feed(snackId,petId,callback)
	return self:send("snackFeed",{snackId=snackId,petId=petId},callback,Intent.FeedTimeout)
end
function Intent:destroy()
	if self.connection then self.connection:Disconnect()end
	for _,w in pairs(self.waiting)do w.done=true end
	table.clear(self.waiting);table.clear(self.unsettled)
end
return Intent
