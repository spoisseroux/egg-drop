-- Ball faces (ROUND-ITEMS-AND-BALL-THEMES-SCOPE B2-B4, batch 2026-11-13 R1).
-- Pure presentation: the expression state machine, the shiver schedule and the
-- crude pixel patterns drawn on the 64-wide LCD. Nothing here reads or writes
-- game state; the renderer feeds it positions and the two danger attributes.
--
-- Expressions, highest priority first:
--   frozen  items carousel open        eyes up, small "o"
--   last    under 1 s of grace          wide eyes, big "O", sweat drop (shivers)
--   danger  over the fill line          wide eyes, frown (shivers)
--   merged  0.32 s after a merge        happy squint, open smile
--   near    a same-size ball touching   wide eyes, small "o"
--   sleepy  untouched and calm for 8 s  closed eyes, mouth nearly gone
--   blink   every 3-6 s for 120 ms      eyes become a line
--   idle    the size's own face
-- Shiver: only the face moves, one LCD pixel, never the body. Balls over the line
-- shiver continuously, calm balls once every 2-5 s; at most 6 per tick; ticks are
-- 10 a second; none under Reduced Motion (blinks and expressions stay).
local Faces={}
Faces.__index=Faces
Faces.Tick=.1
Faces.MaxShivering=6
Faces.MergedFor=.32
Faces.SleepAfter=8
Faces.BlinkFor=.12
Faces.Expressions=table.freeze({"idle","blink","near","merged","danger","last","sleepy","frozen"})
-- Continuous shiver for worried balls: +1, -1, rest, rest (phase per ball).
Faces.DangerCycle=table.freeze({1,-1,0,0})

-- Deterministic 0..1 from an id and a salt (no shared RNG, stable per ball).
local function hash(id,salt)
	local n=math.floor(tonumber(id)or 0)*2654435761+(salt or 0)*40503
	n=(n%4294967296)
	n=bit32.bxor(n,bit32.rshift(n,15))
	n=(n*2246822519)%4294967296
	n=bit32.bxor(n,bit32.rshift(n,13))
	return(n%100000)/100000
end
Faces.hash=hash

-- ── Pixel patterns ─────────────────────────────────────────────────────────
-- g: eye gap from the centre line, ew x eh: eye size, ey: eye top row,
-- ck: mouth corner column, my: mouth row. dx counts from the centre line:
-- left pixels are negative (-1 is the first one left of centre).
local FACE={
	{g=1,ew=1,eh=1,ey=-1,ck=1,my=1},{g=1,ew=1,eh=2,ey=-2,ck=1,my=1},{g=2,ew=2,eh=2,ey=-3,ck=2,my=1},
	{g=2,ew=2,eh=3,ey=-4,ck=3,my=1},{g=3,ew=3,eh=3,ey=-5,ck=4,my=1},
}
local IDLE={{"open","smile"},{"open","smile"},{"open","grin"},{"lidded","smirk"},{"open","joy"}}
local STYLE={happy={"happy","smile"},sleepy={"closed","smile"},dots={"open","none"},cat={"open","cat"}}

local function build(tier,expr,style)
	local f=FACE[tier]
	local g,ew,eh,ey,ck,my=f.g,f.ew,f.eh,f.ey,f.ck,f.my
	local eyes,mouth=IDLE[tier][1],IDLE[tier][2]
	if STYLE[style]then eyes,mouth=STYLE[style][1],STYLE[style][2]end
	if expr~="idle"then
		if expr=="blink"then eyes="closed"
		elseif expr=="near"then eyes,mouth="wide","o"
		elseif expr=="merged"then eyes="happy";mouth=if tier>=3 then "joy"else "smile"
		elseif expr=="danger"then eyes,mouth="wide","frown"
		elseif expr=="last"then eyes,mouth="wide","O"
		elseif expr=="sleepy"then eyes="closed";mouth=if tier<=2 then "none"else "dash"
		elseif expr=="frozen"then eyes,mouth="up","o"end
		if style=="dots"and expr~="near"and expr~="last"and expr~="danger"and expr~="merged"then mouth="none"end
		if style=="cat"and(mouth=="smile"or mouth=="none"or mouth=="dash")then mouth="cat"end
	end
	local px={}
	local function put(x,y,tone)table.insert(px,{x,y,tone})end
	local function both(k,dy,tone)put(-1-k,dy,tone or "ink");put(k,dy,tone or "ink")end
	for side=1,2 do
		local xs={}
		for k=g,g+ew-1 do table.insert(xs,if side==1 then -1-k else k)end
		table.sort(xs)
		local outer=if xs[1]<0 then xs[1]-1 else xs[#xs]+1
		if eyes=="open"or eyes=="wide"or eyes=="up"then
			local top=ey-(if eyes=="wide"or eyes=="up"then 1 else 0)
			local bottom=ey+eh-(if eyes=="up"then 1 else 0)
			for _,x in ipairs(xs)do for y=top,bottom-1 do put(x,y,"ink")end end
			if ew>=2 then put(xs[1],top,"glint")end
		elseif eyes=="closed"then
			for _,x in ipairs(xs)do put(x,ey+eh-1,"ink")end
			-- A blink is a line: one pixel wider than the open eye (the smallest size too).
			if ew==1 then put(outer,ey+eh-1,"ink")end
		elseif eyes=="happy"then
			if ew==1 then put(xs[1],ey,"ink");put(outer,ey+1,"ink")
			else
				local wide=table.clone(xs);table.insert(wide,outer);table.sort(wide)
				for i,x in ipairs(wide)do put(x,ey+(if i>1 and i<#wide then 0 else 1),"ink")end
			end
		elseif eyes=="lidded"then
			local wide=table.clone(xs);table.insert(wide,outer);table.sort(wide)
			for _,x in ipairs(wide)do put(x,ey+1,"ink")end
			for _,x in ipairs(xs)do put(x,ey+2,"ink")end
		end
	end
	local eyeCount=#px
	if mouth=="smile"then
		if tier==1 then both(0,my)else both(ck,my);for k=0,ck-1 do both(k,my+1)end end
	elseif mouth=="grin"or mouth=="joy"then
		for k=0,ck do both(k,my)end
		for k=0,ck-1 do both(k,my+1,if tier<4 then "ink"else "blush")end
		if tier>=4 then for k=0,ck-2 do both(k,my+2)end;both(ck-1,my+1)end
	elseif mouth=="smirk"then
		for k=0,ck-1 do both(k,my+1)end;put(ck,my,"ink")
	elseif mouth=="frown"then
		if tier==1 then both(0,my+1)else for k=0,ck-1 do both(k,my+1)end;both(ck,my+2)end
	elseif mouth=="o"then both(0,my);both(0,my+1)
	elseif mouth=="O"then
		local w=if tier<=2 then 1 else 2
		local h=if tier<=2 then 2 else 3
		for k=0,w-1 do for y=my,my+h-1 do both(k,y)end end
	elseif mouth=="dash"then both(0,my+1)
	elseif mouth=="cat"then
		both(0,my,"blush")
		if tier>=2 then both(1,my+1)end
		if tier>=3 then both(0,my+2);both(2,my+1)end
	end
	if expr=="last"and tier>=2 then put(g+ew+1,ey-1,"glint");put(g+ew+1,ey,"light")end -- a sweat drop
	if tier==5 and(style=="smiley"or style=="happy"or style=="cat")and(expr=="idle"or expr=="blink"or expr=="merged"or expr=="near")then
		both(6,0,"blush");both(7,0,"blush")
	end
	return px,eyeCount
end

local cache={}
-- -> frozen list of {dx, dy, tone}; tone is ink | glint | light | blush. `simple`
-- (span budget fallback) keeps only the eyes on the two smallest sizes.
function Faces.pixels(style,tier,expr,simple)
	if style=="none"then return nil end
	tier=math.clamp(math.floor(tier or 1),1,5);expr=expr or "idle"
	local lean=simple==true and tier<=2
	local key=style..tier..expr..(if simple==true then "s"else "")
	local hit=cache[key]
	if hit then return hit end
	local px,eyes=build(tier,expr,style)
	if lean then local trimmed={};for i=1,eyes do trimmed[i]=px[i]end;px=trimmed end
	-- Simple faces are ink only on every size: no eye glints, sweat drops or blush.
	if simple==true then local inked={};for _,p in ipairs(px)do if p[3]=="ink"then table.insert(inked,p)end end;px=inked end
	for _,p in ipairs(px)do table.freeze(p)end
	cache[key]=table.freeze(px)
	return cache[key]
end

-- ── State machine ──────────────────────────────────────────────────────────
function Faces.new()
	return setmetatable({balls={},out={},tickIndex=nil,merges={},shivering=0},Faces)
end
function Faces:merged(id,now)
	if id~=nil then self.merges[id]=now end
end
-- The mood every face shares this tick.
-- mood = { dangerY, pressure, graceLeft, itemsOpen, reduced }
function Faces.boardState(mood)
	local grace=mood.graceLeft or 0
	if mood.itemsOpen then return "frozen"end
	if grace>0 and grace<1 then return "last"end
	if grace>0 or(mood.pressure or 0)>0 then return "danger"end
	return "calm"
end

-- list: array of {id, tier, x, y, radius} in world units (reused by the caller).
-- Runs at most once a tick; the result is read with :get(id).
function Faces:update(now,list,mood)
	local tick=math.floor(now/Faces.Tick)
	if self.tickIndex==tick then return false end
	self.tickIndex=tick
	local state=Faces.boardState(mood)
	local dangerY=mood.dangerY or 8.6
	local reduced=mood.reduced==true
	local seen={}
	local worried={}
	for _,b in ipairs(list)do
		seen[b.id]=true
		local s=self.balls[b.id]
		if not s then
			s={x=b.x,y=b.y,moved=now,blinkAt=now+3+hash(b.id,1)*3,shiverAt=now+2+hash(b.id,2)*3}
			self.balls[b.id]=s
		end
		if math.abs(b.x-s.x)+math.abs(b.y-s.y)>.05 then s.moved=now;s.x,s.y=b.x,b.y end
		local top=b.y+b.radius
		local expr="idle"
		if state=="frozen"then expr="frozen"
		elseif state=="last"and top>dangerY-1.5 then expr="last"
		elseif(state=="danger"or state=="last")and top>dangerY then expr="danger"
		elseif self.merges[b.id]and now-self.merges[b.id]<Faces.MergedFor then expr="merged"
		else
			for _,o in ipairs(list)do
				if o~=b and o.tier==b.tier then
					local dx,dy=o.x-b.x,o.y-b.y
					local reach=b.radius+o.radius+b.radius
					if dx*dx+dy*dy<reach*reach then expr="near";break end
				end
			end
			if expr=="idle"then
				if state=="calm"and now-s.moved>=Faces.SleepAfter then expr="sleepy"
				elseif now>=s.blinkAt then
					if now<s.blinkAt+Faces.BlinkFor+Faces.Tick then expr="blink"
					else s.blinkAt=now+3+hash(b.id,tick)*3 end
				end
			end
		end
		s.expr=expr
		if expr=="danger"or expr=="last"then table.insert(worried,b)end
	end
	for id in pairs(self.balls)do if not seen[id]then self.balls[id]=nil;self.out[id]=nil end end
	for id,at in pairs(self.merges)do if now-at>1 then self.merges[id]=nil end end
	-- Shiver: worried balls first (highest first), then calm ones on their schedule.
	local count=0
	for id,s in pairs(self.balls)do s.dx=0 end
	if not reduced then
		table.sort(worried,function(a,b)return a.y>b.y end)
		for _,b in ipairs(worried)do
			if count>=Faces.MaxShivering then break end
			local s=self.balls[b.id]
			local phase=(tick+math.floor(hash(b.id,3)*4))%#Faces.DangerCycle+1
			local dx=Faces.DangerCycle[phase]
			if dx~=0 then s.dx=dx;count+=1 end -- the cap counts faces that move this tick
		end
		for _,b in ipairs(list)do
			local s=self.balls[b.id]
			if s.expr~="danger"and s.expr~="last"and now>=s.shiverAt then
				local into=now-s.shiverAt
				if into<Faces.Tick*2 and count<Faces.MaxShivering then
					s.dx=if into<Faces.Tick then 1 else -1;count+=1
				elseif into>=Faces.Tick*2 then
					s.shiverAt=now+2+hash(b.id,tick)*3
				end
			end
		end
	end
	self.shivering=count
	for id,s in pairs(self.balls)do
		local o=self.out[id]
		if not o then o={};self.out[id]=o end
		o.expr,o.dx=s.expr,s.dx or 0
	end
	return true
end
function Faces:get(id)
	local o=self.out[id]
	if o then return o.expr,o.dx end
	return "idle",0
end
function Faces:clear()table.clear(self.balls);table.clear(self.out);table.clear(self.merges);self.tickIndex=nil end

-- Next / Then / the held ball: the same faces with no neighbours. `slot` staggers
-- blinks and shivers (0 = held, 1 = Next, 2 = Then).
function Faces.preview(slot,now,mood)
	local state=Faces.boardState(mood)
	local expr="idle"
	if state=="frozen"then expr="frozen"
	elseif state=="last"then expr="last"
	elseif state=="danger"then expr="danger"
	else
		local period=3.4+slot*.9
		local phase=(now+slot*1.3)%period
		if phase<Faces.BlinkFor then expr="blink"end
	end
	local dx=0
	if mood.reduced~=true then
		local tick=math.floor(now/Faces.Tick)
		if expr=="danger"or expr=="last"then
			dx=Faces.DangerCycle[(tick+slot)%#Faces.DangerCycle+1]
		else
			local period=math.floor((2.6+slot*.7)/Faces.Tick)
			local at=(tick+slot*7)%period
			dx=if at==0 then 1 elseif at==1 then -1 else 0
		end
	end
	return expr,dx
end

return Faces
