-- Garden Dash sheets (DASH-DECK-UI-LOOK U3 and U6): every box of the mode picker and the results card for a W x H
-- safe area, in pt. Pure, no requires: DashGateSheet and DashResultsSheet draw from it, DashSheetLayout.spec checks it.
--   phone        H <= 430 (and not small): the sheets as drawn, 620 wide
--   small phone  W < 640 or H < 340: what gives way is listed per sheet
--   tablet and desktop (H > 430): the phone layout under one UIScale, 1.25 lowered until the card fits W - 48 by H - 120
-- Boxes are {x, y, w, h} inside the card (the card's own box is in screen pt, before the scale).
local Layout={}
Layout.Width=620
Layout.Pad=14
Layout.Big=1.25
local function box(x,y,w,h)return{x=math.floor(x),y=math.floor(y),w=math.floor(w),h=math.floor(h)}end

function Layout.small(W,H)return W<640 or H<340 end
-- The card's place on screen and its scale: centred at (W/2, H/2 + 14) on a phone.
local function place(W,H,w,h)
	local scale=1
	if H>430 then scale=math.max(.5,math.min(Layout.Big,(W-48)/w,(H-120)/h))end
	local cx,cy=W/2,H/2+(if H>430 then 0 else 14)
	-- Never off the bottom: a short screen centres it.
	if cy+h*scale/2>H-4 then cy=H/2 end
	return box(cx-w*scale/2,cy-h*scale/2,w,h),scale
end

-- U3: the stage (pet on its pedestal) at the left; title, line, stats, the three race tiles and the foot at the right.
function Layout.gate(W,H)
	local small=Layout.small(W,H)
	local p=Layout.Pad
	local w=if small then math.min(Layout.Width,W-24)else Layout.Width
	local h=if small then 236 else 276
	local stage=if small then box(p,p,150,208)else box(p,p,196,248)
	local x=stage.x+stage.w+p
	local cw=w-x-p
	local out={small=small,w=w,h=h,stage=stage,right={x=x,w=cw}}
	out.title=box(x,p,cw-40,30)
	out.close=box(w-p-32,12,32,32)
	out.line=if small then nil else box(x,46,cw,18)
	out.stats=box(x,if small then 50 else 72,cw,if small then 64 else 72)
	out.statPitch=if small then 18 else 20
	out.statTop=if small then 6 else 8
	local tileY,tileH=if small then 122 else 152,if small then 60 else 76
	local gap=8
	local tw=math.floor((cw-gap*2)/3)
	out.tiles={}
	for i=1,3 do out.tiles[i]=box(x+(i-1)*(tw+gap),tileY,tw,tileH)end
	out.tileSub=not(small and W<600)
	out.foot=box(x,if small then 190 else 238,cw,22)
	-- On the stage (its own coordinates): the pedestal's middle 62 pt over the bottom edge, the name's 32, the band
	-- line under the name (small: 52 and 24, no band line).
	local sw,sh=stage.w,stage.h
	local pw,ph=if small then 102 else 132,if small then 20 else 26
	out.pedestal=box((sw-pw)/2,sh-(if small then 52 else 62)-ph/2,pw,ph)
	out.name=box(4,sh-(if small then 24 else 32)-10,sw-8,20)
	out.band=if small then nil else box(4,sh-20,sw-8,14)
	out.card,out.scale=place(W,H,w,h)
	return out
end

-- U6: the stage with the podium and the medal; headline, time, earned and field rows; the strip; Race again and Done.
-- opts: {earned = the Earned row shows, field = the Field row shows, strip = the See you tomorrow strip shows}.
function Layout.results(W,H,opts)
	opts=opts or {}
	local small=Layout.small(W,H)
	local p=Layout.Pad
	local w=if W<640 then W-24 else Layout.Width
	local field=opts.field==true and not(small or H<390)
	local stageW=if W<640 then 150 else 196
	local x=p+stageW+p
	local cw=w-x-p
	local out={small=small,w=w,right={x=x,w=cw}}
	out.headline=box(x,12,cw,36)
	local y=54
	out.time=box(x,y,cw,40);y+=46
	if opts.earned then out.earned=box(x,y,cw,40);y+=46 end
	if field then out.field=box(x,y,cw,40);y+=46 end
	local bottom=math.max(p+132,y-6)
	out.stage=box(p,p,stageW,bottom-p)
	y=bottom+8
	if opts.strip then out.strip=box(p,y,w-p*2,48);y+=48+8 end
	local inner=w-p*2
	local again=math.floor(inner*.655+.5)
	out.again=box(p,y,again,48)
	out.done=box(p+again+8,y,inner-again-8,48)
	out.h=y+48+p
	-- The podium step and the medal on the stage. FABLE-REVIEW-R1 7: a tall stage (an Earned or Field row, about 172)
	-- has a 132 x 22 step 14 above the bottom, an 84 pt pet and a 24 pt hop; a short one (132, prizes off) a 110 x 18
	-- step 10 above it, a 62 pt pet and a 16 pt hop. The pet stands centred 10 right of the middle, clear of the medal.
	local tall=out.stage.h>=150
	local pw,ph,lift=if tall then 132 else 110,if tall then 22 else 18,if tall then 14 else 10
	pw=math.min(pw,stageW-16)
	out.podium=box((stageW-pw)/2,out.stage.h-lift-ph,pw,ph)
	out.pet={height=if tall then 84 else 62,hop=if tall then 24 else 16,shift=10,clear=8}
	out.medal=box(8,8,40,40)
	out.card,out.scale=place(W,H,w,out.h)
	return out
end
return Layout
