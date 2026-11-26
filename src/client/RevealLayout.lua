-- The pet reveal card's geometry (RevealStage), pure, so the specs can run it offline. Two rules:
--
--  * today's layout (Onboard "safecard" off): Stage.geometry(W, H, clear) exactly as it was, measured from the raw screen
--    corner (moved here from RevealStage.lua unchanged);
--  * the safe card (Onboard "safecard" on, artifacts/qa-2026-11-26-beta35/ONBOARDING-V2.md step 4, Spencer: "the scaling
--    is weird, it doesnt fit under the roblox ui"): the ScreenGui stays full-bleed for the backdrop only (checker, flash,
--    confetti, fade cover). Inside the safe rect (the CoreUISafeInsets probe: under the Roblox top bar, clear of a notch)
--    one content box with the authored shape is centred: 1920 x 1080 on a computer, 812 x 354 on a phone, and a stacked
--    390 x 700 box when the safe rect is portrait or near-square (W < H * 1.2). s = min(safeW / boxW, safeH / boxH): the
--    box scales by its short side and is never cropped. Every content position is the box origin + authored * s (the
--    layout is drawn in box space, then moved), so off 16:9 nothing drifts apart. The name plate's band may bleed to the
--    screen's right edge; its text, the buttons and everything else stay in the box. The card's top is at least
--    safeTop + 8.
local Layout={}
-- Beta 14 Q3: on a phone the button row keeps RowClear px clear of the stage card (shot 2: Back sat 8 px inside it at
-- 844 x 390). Back (the short label) gives way first, down to PlayMin; then the card narrows (never under 1.3 pet boxes).
Layout.RowClear=12
Layout.PlayMin=110
Layout.Boxes=table.freeze({desktop={w=1920,h=1080},phone={w=812,h=354},stack={w=390,h=700}})
Layout.CardGap=8 -- px: the card's top stays this far under the safe rect's top
Layout.StackRatio=1.2

-- DeckKit.compactRule, copied so this stays pure (a phone-sized landscape screen).
function Layout.compactRule(W,H)return W>=H*1.2 and(H<500 or W<1000)end
function Layout.phoneRule(W,H)return Layout.compactRule(W,H)or W<760 end

-- Pure: which box a safe rect of this size gets.
function Layout.mode(safeW,safeH)
	if safeW<safeH*Layout.StackRatio then return "stack"end
	return if Layout.phoneRule(safeW,safeH)then "phone"else "desktop"
end
-- Pure: the content box inside the safe rect {x, y, w, h} (root pixels). Returns {mode, s, x, y, w, h}.
function Layout.box(safe)
	local mode=Layout.mode(safe.w,safe.h)
	local B=Layout.Boxes[mode]
	local s=math.min(safe.w/B.w,safe.h/B.h)
	local w,h=math.floor(B.w*s),math.floor(B.h*s)
	return{mode=mode,s=s,w=w,h=h,x=math.floor(safe.x+(safe.w-w)/2),y=math.floor(safe.y+(safe.h-h)/2)}
end

-- The authored layouts in box space (W, H = the box). `top` is the phone's top margin (60 on the raw screen, today).
local function phone(L,W,H,clear,top)
	local s=math.min(W/812,H/354);L.s=s
	L.petX=math.floor(W*268/812);L.feet=H-math.floor(48*s);L.petH=188*s;L.petBox=230*s
	L.coneTop,L.coneBottom=34*s,240*s
	L.poolRX,L.poolRY,L.ring=120*s,24*s,math.max(2,4*s)
	L.headX,L.headY=math.max(24,math.floor(22*s)),math.max(top+4,math.floor(64*s))
	L.tagSize,L.lineSize=12,math.max(18,27*s);L.dropTag=W<700
	L.plateX=W-math.floor(368*s);L.plateY=math.max(top+40,math.floor(104*s));L.plateH=math.max(44,math.floor(60*s))
	L.nameSize=math.max(26,46*s);L.plateTag=12
	L.descX=W-math.floor(342*s);L.descY=L.plateY+L.plateH+math.floor(34*s);L.descSize=math.max(12,14*s);L.descW=math.floor(300*s);L.descLines=1
	L.btnH=48;L.btnY=H-L.btnH-math.floor(14*s);L.meetW=math.max(120,math.floor(176*s));L.playW=math.max(110,math.floor(150*s))
	L.margin=24;L.gap=10;L.btnText=16
	L.hintX,L.hintY,L.hintSize=L.petX,H-math.floor(16*s),12
	local wellRight=L.petX+math.floor(math.min(L.petBox*1.7,L.petX*2-32))/2
	local rowLeft=W-L.margin-L.meetW-L.gap-L.playW
	local need=math.ceil(wellRight+Layout.RowClear-rowLeft)
	if clear and need>0 then
		local give=math.min(need,math.max(0,L.playW-Layout.PlayMin))
		L.playW-=give;rowLeft+=give;need-=give
		if need>0 then L.wellW=math.max(math.floor(L.petBox*1.3),math.floor((rowLeft-Layout.RowClear-L.petX)*2))end
	end
end
local function desktop(L,W,H)
	local s=math.min(W/1920,H/1080);L.s=s
	L.petX=math.floor(W*800/1920);L.feet=H-math.floor(238*s);L.petH=590*s;L.petBox=700*s
	L.coneTop,L.coneBottom=92*s,700*s
	L.poolRX,L.poolRY,L.ring=350*s,70*s,math.max(2,4*s)
	L.headX,L.headY=math.floor(88*s),math.floor(76*s);L.tagSize,L.lineSize=math.max(12,26*s),math.max(24,80*s)
	L.plateX=W-math.floor(910*s);L.plateY=L.feet-math.floor(202*s);L.plateH=math.max(56,math.floor(168*s))
	L.nameSize=math.max(28,128*s);L.plateTag=math.max(12,22*s)
	L.descX=W-math.floor(812*s);L.descY=L.feet+math.floor(36*s);L.descSize=math.max(14,26*s);L.descW=math.floor(700*s);L.descLines=2
	L.btnH=math.max(44,math.floor(72*s));L.btnY=H-math.floor(112*s);L.meetW=math.max(160,math.floor(300*s));L.playW=math.max(130,math.floor(240*s))
	L.margin=math.floor(88*s);L.gap=math.max(10,math.floor(16*s));L.btnText=math.max(16,math.floor(22*s))
	L.hintX,L.hintY,L.hintSize=L.petX,H-math.floor(118*s),math.max(12,16*s)
	L.nextX,L.nextY,L.nextSize=math.floor(88*s),H-math.floor(76*s),math.max(12,16*s)
end
-- Portrait and near-square (safe card only): headline, card, plate, line, button, top to bottom.
local function stack(L,W,H)
	local s=math.min(W/390,H/700);L.s=s;L.stack=true
	L.petX=math.floor(W/2);L.feet=math.floor(430*s);L.petH=210*s;L.petBox=250*s
	L.coneTop,L.coneBottom=30*s,230*s
	L.poolRX,L.poolRY,L.ring=110*s,22*s,math.max(2,4*s)
	L.headX,L.headY=math.floor(20*s),math.floor(16*s)
	L.tagSize,L.lineSize=math.max(12,14*s),math.max(20,34*s);L.dropTag=false
	L.plateX=math.floor(40*s);L.plateY=math.floor(478*s);L.plateH=math.max(44,math.floor(56*s))
	L.nameSize=math.max(26,44*s);L.plateTag=12
	L.descX=math.floor(24*s);L.descY=L.plateY+L.plateH+math.floor(18*s);L.descSize=math.max(12,14*s);L.descW=math.floor(342*s);L.descLines=2
	L.btnH=48;L.btnY=H-L.btnH-math.floor(16*s);L.meetW=math.max(140,math.floor(200*s));L.playW=math.max(110,math.floor(150*s))
	L.margin=math.floor(24*s);L.gap=10;L.btnText=16
	L.hintX,L.hintY,L.hintSize=L.petX,L.feet+math.floor(26*s),12
end

-- Pure. W, H: the root (screen) size. clear: the phone row rule (RevealStage.rowClearOn). safe: nil for today's
-- layout, or the safe rect {x, y, w, h} in root pixels for the safe card.
function Layout.geometry(W,H,clear,safe)
	if type(safe)~="table"then
		local L={W=W,H=H,phone=Layout.phoneRule(W,H)}
		if L.phone then phone(L,W,H,clear,60)else desktop(L,W,H)end
		return L
	end
	local box=Layout.box(safe)
	local L={W=box.w,H=box.h,phone=box.mode~="desktop",mode=box.mode}
	if box.mode=="phone"then phone(L,box.w,box.h,clear,8)
	elseif box.mode=="stack"then stack(L,box.w,box.h)
	else desktop(L,box.w,box.h)end
	-- Box space to root space: every content x and y moves by the box origin; the backdrop's W and H are the screen's.
	local ox,oy=box.x,box.y
	for _,key in ipairs({"petX","headX","plateX","descX","hintX","nextX"})do if L[key]then L[key]+=ox end end
	for _,key in ipairs({"feet","headY","plateY","descY","btnY","hintY","nextY"})do if L[key]then L[key]+=oy end end
	L.W,L.H=W,H
	L.box=box;L.boxX,L.boxY,L.boxRight,L.boxBottom=ox,oy,ox+box.w,oy+box.h
	L.safe={x=safe.x,y=safe.y,w=safe.w,h=safe.h}
	return L
end

-- The well behind the pet (the card): from the top of the stage to just under its feet. Today's numbers, measured
-- from the box (the screen when there is no box), and never above safeTop + CardGap.
function Layout.wellRect(L)
	local ox,oy=L.boxX or 0,L.boxY or 0
	local bottomEdge=L.boxBottom or L.H
	local minTop=if L.safe then math.max(oy+16,L.safe.y+Layout.CardGap)else 16
	local top=math.max(minTop,math.floor(L.feet-L.petH*1.55))
	local bottom=math.min(bottomEdge-8,math.floor(L.feet+math.max(30,L.petH*.2)))
	local w=L.wellW or math.floor(math.min(L.petBox*1.7,(L.petX-ox)*2-32))
	return math.floor(L.petX-w/2),top,w,bottom-top
end
-- The right edge text and buttons line up to (the box's on the safe card, the screen's today).
function Layout.right(L)return L.boxRight or L.W end

-- Pure: the headline's size for its words, shrunk to fit the box's width when it would not (safe card only).
-- measure(text, size) -> width in px (RevealStage passes the real measure; specs an estimate).
function Layout.headlineSize(L,line,measure)
	local size=math.floor(L.lineSize)
	if not L.box or type(measure)~="function"then return size end
	local room=Layout.right(L)-L.headX-math.floor(16*L.s)
	local w=measure(line,size)+8
	if w>room and w>0 then size=math.max(14,math.floor(size*room/w))end
	return size
end

-- Pure: the content rects in root pixels, for the spec ("all inside the safe rect"). measure(text, size) -> px wide;
-- buttons: how many (1 or 2). Words: the headline's long line, the name and the description.
function Layout.rects(L,words,measure,buttons)
	words=words or {}
	measure=measure or function(text,size)return #text*size*.62 end
	local out={}
	local x,y,w,h=Layout.wellRect(L)
	out.card={x=x,y=y,w=w,h=h}
	local lineSize=Layout.headlineSize(L,words.headline or "LITTLE WONDER!",measure)
	local tagH=if L.dropTag then 0 else math.floor(L.tagSize*1.45)
	out.headline={x=L.headX,y=L.headY,w=measure(words.headline or "LITTLE WONDER!",lineSize)+8,h=tagH+math.floor(lineSize*1.1)+math.max(3,math.floor(lineSize*.08))+4}
	-- The name's text box (the plate band itself may bleed to the screen edge).
	local available=Layout.right(L)-L.plateX-L.plateH*.5-(if L.phone then 24 else 60)
	out.name={x=L.plateX+math.floor(L.plateH*.36),y=L.plateY-math.floor(L.plateTag*1.6),w=math.max(1,available),h=L.plateH+math.floor(L.plateTag*1.6)}
	local descW=math.min(L.descW,measure(words.description or "",L.descSize)*.86+8)+L.descSize*1.6
	out.line={x=L.descX,y=L.descY,w=descW,h=math.floor(L.descSize*(if L.descLines>1 then 2.7 else 1.9))}
	local right=Layout.right(L)-L.margin
	local left=right-L.meetW-(if(buttons or 1)>1 then L.gap+L.playW else 0)
	out.buttons={x=left,y=L.btnY,w=right-left,h=L.btnH}
	local hintW=measure("Drag to spin",L.hintSize)*.85+L.hintSize*2.6
	local hintH=math.floor(L.hintSize*2)
	out.hint={x=L.hintX-hintW/2,y=L.hintY-hintH/2,w=hintW,h=hintH}
	return out
end
-- Pure: is rect r inside rect s (both {x, y, w, h})? One pixel of rounding is allowed.
function Layout.inside(r,s)
	return r.x>=s.x-1 and r.y>=s.y-1 and r.x+r.w<=s.x+s.w+1 and r.y+r.h<=s.y+s.h+1
end
return table.freeze(Layout)
