-- Pocket Deck results in place, the v3 look (beta 12 QA U7, DASH-DECK-UI-LOOK; behind DeckLook.on()). Pure geometry for
-- DeckResultsInPlace: the panes and the See you tomorrow strip under them, the compact action stack, and the gamepad
-- moves between its buttons. Button ids are DeckResultsInPlace's: 1 Replay, 3 Difficulty, 5 Hatch, 2 Leave.
local Layout={}
Layout.StripH=48
Layout.StripGap=6
Layout.Pad=6
Layout.Gap=4
Layout.Replay=44
Layout.Difficulty=36
Layout.Half=40
Layout.Full=36 -- a row of the fallback stack (a label too long for half a button)
Layout.TextSize=13
Layout.SmallText=11

-- The three panes ({x, y, w, h} each) and, with the strip on, the panes 54 pt shorter and the strip across the whole
-- LCD under them: from the left pane's left edge to the right pane's right edge.
function Layout.panes(left,middle,right,strip)
	local function copy(r)return{x=r.x,y=r.y,w=r.w,h=r.h}end
	local out={left=copy(left),middle=copy(middle),right=copy(right)}
	if strip then
		local give=Layout.StripH+Layout.StripGap
		local bottom=0
		for _,name in ipairs({"left","middle","right"})do
			local r=out[name]
			r.h-=give
			bottom=math.max(bottom,r.y+r.h)
		end
		out.strip={x=left.x,y=bottom+Layout.StripGap,w=right.x+right.w-left.x,h=Layout.StripH}
	end
	return out
end
-- The text size that fits both half buttons ("Hatch", "Leave") at `half` px wide, or nil (none does: two full rows).
-- measure(text, size) -> px.
function Layout.halfText(half,labels,measure)
	for _,size in ipairs({Layout.TextSize,Layout.SmallText})do
		local fits=true
		for _,text in ipairs(labels)do if measure(text,size)+12>half then fits=false end end
		if fits then return size end
	end
	return nil
end
-- The action rows inside a right pane `rw` wide: {total, rows = {[id] = {x, y, w, h}}, textSize}, y from the stack's
-- top. 128 in all when Hatch and Leave share a row; 164 when they cannot.
function Layout.actions(rw,labels,measure)
	local w=rw-Layout.Pad*2
	local half=math.floor((w-Layout.Gap)/2)
	local size=Layout.halfText(half,labels,measure)
	local rows={}
	local y=0
	rows[1]={x=0,y=y,w=w,h=Layout.Replay};y+=Layout.Replay+Layout.Gap
	rows[3]={x=0,y=y,w=w,h=Layout.Difficulty};y+=Layout.Difficulty+Layout.Gap
	if size then
		rows[5]={x=0,y=y,w=half,h=Layout.Half}
		rows[2]={x=w-half,y=y,w=half,h=Layout.Half}
		y+=Layout.Half
	else
		rows[5]={x=0,y=y,w=w,h=Layout.Full};y+=Layout.Full+Layout.Gap
		rows[2]={x=0,y=y,w=w,h=Layout.Full};y+=Layout.Full
	end
	return{total=y,rows=rows,textSize=size or Layout.TextSize,paired=size~=nil}
end
-- The gamepad on the compact stack: down from Difficulty goes to Hatch; right from Hatch to Leave and left back; up
-- from either goes to Difficulty. Answers the id to focus, or nil (no move: the caller's own rule).
function Layout.move(focus,dx,dy,paired)
	if dy<0 and(focus==5 or focus==2)then return 3 end
	if dy>0 and focus==3 then return 5 end
	if paired then
		if dx>0 and focus==5 then return 2 end
		if dx<0 and focus==2 then return 5 end
		if dx~=0 and(focus==5 or focus==2)then return focus end
	end
	if dy>0 and focus==5 then return if paired then focus else 2 end
	if dy>0 and focus==2 then return focus end
	return nil
end
return Layout
