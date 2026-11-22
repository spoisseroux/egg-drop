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
return Results
