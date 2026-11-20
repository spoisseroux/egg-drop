-- v2 Stat Eggs: the egg card's odds block and its button, from the server's public `statEgg`
-- (StatEggState.public). Pure. The figures shown are the figures the server rolls with: the stat
-- is an equal share of the pet's stats below 99 (OddsText.equalShare), the size is the integer
-- table of StatEggCatalog.sizeOdds (Feast 100% on a promised egg). Restricted players (the
-- policy says no paid random items, or it has not answered) see the fixed next snack instead.
local Shared=game:GetService("ReplicatedStorage").Shared
local K=require(Shared.StatEggCatalog)
local Stats=require(Shared.StatCatalog)
local OddsText=require(Shared.OddsText)
local UICopy=require(Shared.UICopy)
local Odds={}

function Odds.statName(id)return UICopy.get("stats.name."..tostring(id))end
function Odds.sizeName(id)return UICopy.get("stats.snacks.size."..tostring(id))end
function Odds.quote(state,petId)
	local egg=type(state)=="table"and state.statEgg
	return if type(egg)=="table"and type(egg.quotes)=="table"then egg.quotes[petId]else nil
end

-- {rows = {{id, name, value, label?, info?}}, per, restricted, note, empty}
function Odds.rows(state,petId)
	local egg=type(state)=="table"and state.statEgg or nil
	local per=UICopy.get("hatch.egg.stat.per")
	if type(egg)~="table"or egg.enabled==false then return{rows={},per=per,empty=UICopy.get("hatch.stat.notReady")}end
	local quote=Odds.quote(state,petId)
	if not quote then return{rows={},per=per,empty=UICopy.get("hatch.stat.noPet")}end
	local eligible=quote.eligible or {}
	if #eligible==0 then return{rows={},per=per,empty=UICopy.get("hatch.stat.allMaxed")}end
	if egg.mode~="random"then
		local rows={}
		local nextSnack=quote.next
		if nextSnack then
			table.insert(rows,{id="next",name=UICopy.get("hatch.stat.next",{stat=Odds.statName(nextSnack.stat),size=Odds.sizeName(nextSnack.size)}),value=""})
		end
		table.insert(rows,{id="cycle",name=UICopy.get("hatch.stat.cycle"),value="",info=true})
		return{rows=rows,per=per,restricted=true,note=UICopy.get("hatch.stat.promise.fixed")}
	end
	local each,rounded=OddsText.equalShare(#eligible)
	local names={};for _,id in ipairs(eligible)do table.insert(names,Odds.statName(id))end
	local rows={{id="stat",name=UICopy.get("hatch.stat.each",{each=each}),value=each,
		label=UICopy.get("hatch.stat.eachLabel",{count=#eligible,each=each,names=table.concat(names,", ")})}}
	for _,row in ipairs(K.sizeOdds(egg.misses))do
		table.insert(rows,{id=row.id,name=UICopy.get("hatch.stat.size."..row.id),value=row.percent.."%"})
	end
	local left=K.pityLeft(egg.misses)
	local short=if left<=1 then UICopy.get("hatch.stat.pityOne")else UICopy.get("hatch.stat.pity",{count=left})
	table.insert(rows,{id="pity",name=short,label=UICopy.get("hatch.stat.pityRule"),value="",info=true})
	if rounded then table.insert(rows,{id="rounded",name=UICopy.get("hatch.odds.rounded"),value="",info=true})end
	return{rows=rows,per=per,note=UICopy.get("hatch.stat.promise.random"),rounded=rounded==true}
end

-- The primary button: {text, enabled, free, need}.
function Odds.action(state,petId)
	local egg=type(state)=="table"and state.statEgg or nil
	if type(egg)~="table"or egg.enabled==false then return{text=UICopy.get("hatch.stat.notReady"),enabled=false}end
	local quote=Odds.quote(state,petId)
	if not quote then return{text=UICopy.get("hatch.stat.noPet"),enabled=false}end
	if #(quote.eligible or {})==0 then return{text=UICopy.get("hatch.stat.allMaxed"),enabled=false}end
	if #(egg.pouch or {})>=(egg.pouchSize or K.PouchSize)then return{text=UICopy.get("hatch.stat.pouchFull"),enabled=false}end
	if(egg.free or 0)>0 then return{text=UICopy.get("hatch.stat.free",{count=egg.free}),enabled=true,free=true}end
	if(egg.boughtToday or 0)>=(egg.dailyBuys or K.DailyBuys)then return{text=UICopy.get("hatch.stat.soldOut"),enabled=false}end
	local price=egg.price or K.Price
	local text=UICopy.get("hatch.stat.hatch",{count=price})
	if(state.nectar or 0)<price then return{text=text,enabled=false,need=require(script.Parent.ShopPriceState).need(price,state.nectar)}end
	return{text=text,enabled=true,free=false}
end

-- The line under the egg's description: today's stock and free eggs.
function Odds.stockLine(state)
	local egg=type(state)=="table"and state.statEgg or nil
	if type(egg)~="table"then return ""end
	local left=math.max(0,(egg.dailyBuys or K.DailyBuys)-(egg.boughtToday or 0))
	local line=UICopy.get("hatch.stat.today",{count=left,total=egg.dailyBuys or K.DailyBuys})
	if(egg.free or 0)>0 then line=UICopy.get("hatch.stat.freeLine",{count=egg.free}).." · "..line end
	return line
end

-- Stat colour for UI (fixed, never tinted).
function Odds.color(statId)local s=Stats.ById[statId];return if s then s.color else Color3.new(1,1,1)end
return Odds
