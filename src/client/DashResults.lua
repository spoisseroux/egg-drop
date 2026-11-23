-- Garden Dash results (V3-DASH-BUILD-PLAN-2026-11-22, slice S7). "You finished 5th!" with the time, the best and, once
-- the save has it, the Stars. No losing screen. The words are pure; DashCard draws them. Place and time come from
-- the server's result; Stars and best only from the owner's snapshot, so nothing is shown before it is saved.
local UICopy=require(game:GetService("ReplicatedStorage").Shared.UICopy)
local Results={}
function Results.seconds(us)return string.format("%.1f",us/1000000)end
-- packet: the server's result. mine: the owner's snapshot `dash` block (nil = prizes or saves not there yet).
-- before: that block's last receipt id when the race was locked. Title, then the lines (always three).
function Results.words(packet,mine,before)
	local title
	if packet.trial then
		title=if packet.us then UICopy.get("dash.result.trial",{time=Results.seconds(packet.us)})else UICopy.get("dash.result.noTime")
	else
		title=UICopy.get("dash.result.place",{place=UICopy.get("dash.ordinal.p"..math.clamp(packet.place,1,8))})
	end
	local lines={"","",""}
	if packet.trial then
		if type(packet.medal)=="string"then lines[1]=UICopy.get("dash.medal."..packet.medal)
		else lines[1]=UICopy.get("dash.result.tryAgain")end
	else
		lines[1]=if packet.us then UICopy.get("dash.result.time",{time=Results.seconds(packet.us)})else UICopy.get("dash.result.home")
	end
	local best=mine and mine.best
	if type(best)=="number"then lines[2]=UICopy.get("dash.result.best",{best=Results.seconds(best)})end
	local last=mine and mine.last
	if not packet.trial and type(last)=="table"and last.op~=before and type(last.stars)=="number"and last.stars>0 and type(mine.paid)=="number"then
		lines[3]=UICopy.get("dash.result.stars",{reward=last.stars,done=mine.paid,total=mine.limit or 5})
	end
	return title,lines
end

-- Beta 12 U6 (DASH-DECK-UI-LOOK): what the results sheet shows, pure. Colours are hex strings.
Results.MedalColor=table.freeze({"#FFC14D","#DCE5FF","#FF9D4D"}) -- 1st, 2nd, 3rd; the rest cream
Results.Cream="#FFF4DC"
Results.CupColor=table.freeze({gold="#FFC14D",silver="#DCE5FF",bronze="#FF9D4D"})
Results.FieldChips=4
function Results.placeColor(place)return Results.MedalColor[place]or Results.Cream end
-- packet, mine, before: as words(). ctx: {prizes (Stars races on), bestBefore (the saved best when the race locked),
-- names = {[seat] = text}}. Answers {headline, trial, time?, best?, newBest, medal, earned?, field?, celebrate}:
--   medal   {ordinal, color} for a race; {cup, color} or {stopwatch=true, color} for a Time Trial
--   earned  nil (prizes off) or {state = "paid" | "saving" | "usedUp" | "none" | "cup" | "noCup", stars, done, total, text}
--   field   nil (a Time Trial, a race of one) or up to four {place, name, time?, mine, color}: the top three, and you
--           fourth when you are lower
function Results.model(packet,mine,before,ctx)
	ctx=ctx or {}
	local title=Results.words(packet,mine,before)
	local m={headline=title,trial=packet.trial==true,newBest=false}
	if type(packet.us)=="number"then m.time=Results.seconds(packet.us)end
	local best=mine and mine.best
	if type(best)=="number"then
		m.best=Results.seconds(best)
		m.newBest=type(packet.us)=="number"and best==packet.us and(type(ctx.bestBefore)~="number"or packet.us<ctx.bestBefore)
	end
	local place=math.clamp(math.floor(tonumber(packet.place)or 8),1,8)
	if m.trial then
		local cup=if type(packet.medal)=="string"and Results.CupColor[packet.medal]then packet.medal else nil
		m.medal=if cup then {cup=cup,color=Results.CupColor[cup]}else {stopwatch=true,color=Results.Cream}
		m.earned=if cup then {state="cup",text=UICopy.get("dash.medal."..cup)}else {state="noCup",text=UICopy.get("dash.result.tryAgain")}
		m.celebrate=cup~=nil
	else
		m.medal={ordinal=UICopy.get("dash.ordinal.p"..place),color=Results.placeColor(place)}
		m.celebrate=place<=3
		if ctx.prizes then
			local last=mine and mine.last
			local paid=if mine and type(mine.paid)=="number"then mine.paid else 0
			local total=if mine and type(mine.limit)=="number"then mine.limit else 5
			local fresh=type(last)=="table"and last.op~=before
			if fresh and type(last.stars)=="number"and last.stars>0 then
				m.earned={state="paid",stars=last.stars,done=paid,total=total,text=UICopy.get("dash.result.starsShort",{reward=last.stars})}
			elseif paid>=total then
				m.earned={state="usedUp",done=total,total=total,text=UICopy.get("dash.result.tomorrow")}
			elseif fresh then
				m.earned={state="none",done=paid,total=total,text=UICopy.get("dash.result.today",{done=paid,total=total})}
			else
				m.earned={state="saving",done=paid,total=total,text=UICopy.get("dash.result.saving")}
			end
		end
		local seats=if type(packet.seats)=="table"then packet.seats else {}
		if #seats>1 then
			local order=table.clone(seats)
			table.sort(order,function(a,b)return(tonumber(a.place)or 99)<(tonumber(b.place)or 99)end)
			-- The top three, then you if you are lower, else the fourth.
			local field,mineIn={},false
			for index=1,math.min(Results.FieldChips-1,#order)do
				field[index]=order[index]
				if order[index].seat==packet.seat then mineIn=true end
			end
			for index=Results.FieldChips,#order do
				local entry=order[index]
				if mineIn or entry.seat==packet.seat then table.insert(field,entry);break end
			end
			m.field={}
			for _,entry in ipairs(field)do
				local p=math.clamp(math.floor(tonumber(entry.place)or 8),1,8)
				table.insert(m.field,{place=p,name=(ctx.names and ctx.names[entry.seat])or"",time=if type(entry.us)=="number"then Results.seconds(entry.us)else nil,
					mine=entry.seat==packet.seat,color=Results.placeColor(p)})
			end
		end
	end
	return m
end
-- Pure: what a newer model would change on an open sheet (the saved receipt and the best), as one string.
function Results.key(m)
	local e=m.earned or {}
	return table.concat({tostring(e.state),tostring(e.stars),tostring(e.done),tostring(e.total),tostring(m.best),tostring(m.newBest)},"|")
end
return Results
