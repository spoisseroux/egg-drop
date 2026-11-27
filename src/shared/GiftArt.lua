-- The gift chain's art (artifacts/qa-2026-11-27-beta37/GIFT-ART-BRIEF.md, Fable, beta 40): the pure half. The kit's
-- colours, the wrapped egg's proportions, and every timing, curve, cue and layout the client draws from: the gift chip
-- over the pet, the ribbon on the machine's dial, the wrapped gift card, the paint wipe on the pet and the nest Peek.
-- One clock in, numbers out; nothing here touches an Instance, so GiftArt.spec checks it offline. Looks and feel only:
-- no rule, odds, grant or save change. Behind Onboard "gifts" (the callers check it; off is today exactly).
-- Reduced Motion as the brief writes it: no bob, wiggle, sway, glint, rock, shafts or bob of the "?"; the untie is a
-- .15 s fade, the card a .15 s fade, the wipe a .4 s cross-fade, the Peek's light and disc a .2 s fade in and out.
local Art={}

-- ── The kit ──────────────────────────────────────────────────────────────────────────────────────────────────────
-- Gold (#FFC14D) is Stars only: nothing here but the Peek's Stars chip uses it.
Art.Hex=table.freeze({ink="#1B2A4A",glass="#FFFFFF",pink="#FF6FA8",deep="#D8327E",light="#FFD3E6",gold="#FFC14D",
	eggTop="#FFFFFF",eggBottom="#C9F1FF",white="#FFFFFF",crack="#FFF3C4",shell="#C9B4FF"})
Art.GlassTransparency=.15 -- white at 85%
-- The pots (HueCatalog's colours), and the two whose button label is white.
Art.PotHex=table.freeze({rose="#FF327A",tide="#008DFF",citrus="#FFCC00",iris="#9350FF"})
Art.WhiteLabel=table.freeze({tide=true,iris=true})
local colors={}
function Art.color(name)
	local hex=Art.Hex[name]or Art.PotHex[name]or name
	local c=colors[hex]
	if not c then c=Color3.fromHex(hex);colors[hex]=c end
	return c
end
-- Per channel (the offline mocks give the real answer; Color3:Lerp is not mocked everywhere).
function Art.mix(a,b,t)
	t=math.clamp(t,0,1)
	return Color3.new(a.R+(b.R-a.R)*t,a.G+(b.G-a.G)*t,a.B+(b.B-a.B)*t)
end

-- ── Curves ───────────────────────────────────────────────────────────────────────────────────────────────────────
local function clamp01(x)return math.clamp(x,0,1)end
local function ramp(t,from,seconds)return clamp01((t-from)/math.max(seconds,1e-6))end
local function easeOut(x)x=clamp01(x);return 1-(1-x)^3 end
local function quadInOut(x)x=clamp01(x);return if x<.5 then 2*x*x else 1-(-2*x+2)^2/2 end
local function backOut(x)x=clamp01(x);local c1=1.70158;local c3=c1+1;return 1+c3*(x-1)^3+c1*(x-1)^2 end
local function bump(t,from,to)return if t>from and t<to then math.sin((t-from)/(to-from)*math.pi)else 0 end
Art.ease=table.freeze({out=easeOut,quadInOut=quadInOut,backOut=backOut,ramp=ramp,bump=bump})
-- A pop from 0: up to `over` at 60% of `seconds`, back to 1 by the end.
function Art.pop(age,seconds,over,from)
	from=from or 0
	if age==nil or age>=seconds then return 1 end
	if age<=0 then return from end
	local u=age/seconds
	if u<.6 then return from+(over-from)*easeOut(u/.6)end
	return over+(1-over)*quadInOut((u-.6)/.4)
end
-- The cues of `list` that fall due between two clock readings: from < at <= to (the first frame takes at = 0).
function Art.due(list,from,to)
	local out={}
	for _,cue in ipairs(list)do
		if cue.at<=to and(cue.at>from or(from<0 and cue.at<=0))then table.insert(out,cue)end
	end
	return out
end
local function cues(list)
	for _,c in ipairs(list)do table.freeze(c)end
	return table.freeze(list)
end

-- ── The wrapped egg (one drawing; 36, 44 and 28 px) ──────────────────────────────────────────────────────────────
-- Shares of the egg's own box (height 1): the egg .78 wide, a band down it 22% wide, one across 18% high meeting 42%
-- from the top; there the bow, two loops 30% of the width at +-28 degrees and a 4 px knot; the Aero glint, a 2 px bar
-- upper left and a dot below right of it.
Art.Egg=table.freeze({w=.78,h=1,bandW=.22,bandH=.18,meet=.42,loop=.30,loopTall=.17,loopAngle=28,knot=4,stroke=2,
	glint=table.freeze({x=.27,y=.17,w=2,h=.17,rot=-24}),dot=table.freeze({x=.4,y=.34,size=.06})})
Art.EggSizes=table.freeze({chip=36,pill=44,tag=28})
-- Pure: the wrapped egg's pieces for an egg `height` px tall: {name = {x, y (centre px from the box's top left), w, h,
-- rot}} plus the box's width and height. The loops sit either side of the knot.
function Art.eggLayout(height)
	local E=Art.Egg
	local w,h=height*E.w,height
	local meet=h*E.meet
	local loopW,loopH=w*E.loop,h*E.loopTall
	local knot=math.max(3,math.floor(E.knot*height/36+.5))
	return{w=w,h=h,
		egg={x=w/2,y=h/2,w=w,h=h,rot=0},
		bandDown={x=w/2,y=h/2,w=w*E.bandW,h=h*.96,rot=0},
		bandAcross={x=w/2,y=meet,w=w*.98,h=h*E.bandH,rot=0},
		loopL={x=w/2-loopW*.48,y=meet-loopH*.18,w=loopW,h=loopH,rot=-E.loopAngle},
		loopR={x=w/2+loopW*.48,y=meet-loopH*.18,w=loopW,h=loopH,rot=E.loopAngle},
		knot={x=w/2,y=meet,w=knot,h=knot,rot=0},
		glint={x=w*E.glint.x,y=h*E.glint.y,w=E.glint.w,h=h*E.glint.h,rot=E.glint.rot},
		dot={x=w*E.dot.x,y=h*E.dot.y,w=math.max(2,h*E.dot.size),h=math.max(2,h*E.dot.size),rot=0}}
end

-- ── 1. The chip over the pet ─────────────────────────────────────────────────────────────────────────────────────
Art.Chip=table.freeze({size=36,hit=52,egg=26,bob=3,bobPeriod=2.4,every=6,wiggle=10,wiggleSeconds=.3,pop=.25,popOver=1.15,
	shine=.25,near=10,nearScale=1.15,nearEase=2,far=60,farAlpha=.6,farEase=10})
-- Pure: the chip at `t` s of its own clock, `parked` s since it parked (nil: long ago), `distance` studs from the player.
-- -> {y (px, negative up), bow (degrees), scale, alpha (0..1 opacity), cycle (the 6 s beat it is in: a new one glints)}
function Art.chip(t,parked,distance,reduced)
	local C=Art.Chip
	local y,bow=0,0
	local cycle=math.floor((t or 0)/C.every)
	if not reduced then
		y=-C.bob*math.sin((t or 0)*2*math.pi/C.bobPeriod)
		local u=(t or 0)-cycle*C.every
		if u<C.wiggleSeconds then bow=C.wiggle*math.sin(u/C.wiggleSeconds*2*math.pi)end
	end
	local scale=Art.pop(parked,C.pop,C.popOver)
	local near=0
	if type(distance)=="number"then near=1-clamp01((distance-C.near)/C.nearEase)end
	scale*=1+(C.nearScale-1)*near
	local alpha=1
	if type(distance)=="number"then alpha=1-(1-C.farAlpha)*clamp01((distance-(C.far-C.farEase))/C.farEase)end
	return{y=y,bow=bow,scale=scale,alpha=alpha,cycle=if reduced then -1 else cycle}
end

-- ── 1. The ribbon on the machine ─────────────────────────────────────────────────────────────────────────────────
-- Studs: a matte pink sash across the dial at 30 degrees, a bow at its upper right (two .5 loops, a .18 knot, two .45
-- tails swaying +-6 degrees on a 3 s sine), a tag under the bow. The sash runs `margin` past the dial on each side.
Art.Ribbon=table.freeze({sash=table.freeze({w=.22,thick=.05,angle=30,margin=.08,lift=.03}),
	bow=table.freeze({along=.3,loop=.5,loopTall=.28,loopThick=.1,loopAngle=28,knot=.18,tail=.45,tailW=.1,tailThick=.04,
		tailSpread=18,sway=6,swayPeriod=3}),
	tag=table.freeze({w=92,h=30,font=16,egg=28,maxDistance=60,below=.62}),
	glint=table.freeze({every=5,seconds=.45,size=.18}),attract=20,
	untie=table.freeze({bow=.2,slide=.4,fall=1.5}),reducedFade=.15,offFade=.3})
-- Pure: the ribbon's pieces on a dial `diameter` studs across, in the dial face's own frame (x right, y up, z out of
-- the face): {sash = {at, angle, length}, bow = Vector3, loops = {{at, angle}}, tails = {{at, angle}}, tag = Vector3}.
function Art.ribbonLayout(diameter)
	local R=Art.Ribbon
	local length=math.max(.6,diameter)+2*R.sash.margin
	local a=math.rad(R.sash.angle)
	local dir=Vector3.new(math.cos(a),math.sin(a),0)
	local z=R.sash.thick/2
	local bow=dir*(length*R.bow.along)+Vector3.new(0,0,R.sash.thick+R.bow.loopThick/2)
	local side=R.bow.loop*.42
	local loops={{at=bow+Vector3.new(-side,R.bow.loopTall*.1,0),angle=-R.bow.loopAngle},{at=bow+Vector3.new(side,R.bow.loopTall*.1,0),angle=R.bow.loopAngle}}
	local tails={}
	for i,sign in ipairs({-1,1})do
		local spread=math.rad(R.bow.tailSpread)*sign
		local hang=Vector3.new(math.sin(spread),-math.cos(spread),0)*(R.bow.tail/2)
		tails[i]={at=bow+hang+Vector3.new(0,0,-R.bow.loopThick/4),angle=R.bow.tailSpread*sign}
	end
	return{sash={at=Vector3.new(0,0,z),angle=R.sash.angle,length=length},bow=bow,loops=loops,tails=tails,
		tag=bow+Vector3.new(0,-R.tag.below,0)}
end
-- Pure: the ribbon at `t` s (its own clock), `untie` s since the first crank tick (nil: tied).
-- -> {sway (degrees, the tails), glint (0..1 along the sash, or nil), open (0..1 the bow untied), fall (studs down),
--    alpha (0..1 opacity), done (gone: take it away)}
function Art.ribbon(t,untie,reduced)
	local R=Art.Ribbon
	local s={sway=0,glint=nil,open=0,fall=0,alpha=1,done=false}
	if not reduced then
		s.sway=R.bow.sway*math.sin((t or 0)*2*math.pi/R.bow.swayPeriod)
		local u=((t or 0)%R.glint.every)/R.glint.seconds
		if u<1 then s.glint=u end
	end
	if untie then
		s.glint=nil
		if reduced then
			s.alpha=1-clamp01(untie/R.reducedFade);s.done=untie>=R.reducedFade
			return s
		end
		s.open=clamp01(untie/R.untie.bow)
		local v=clamp01((untie-R.untie.bow)/R.untie.slide)
		s.fall=R.untie.fall*v*v
		s.alpha=1-v
		s.done=untie>=R.untie.bow+R.untie.slide-1e-9
	end
	return s
end
-- The untie's sound and buzz (on the first crank tick).
Art.RibbonCue=table.freeze({sound="blanket_rustle",speed=1.3,volume=.35,buzz="machine_light"})

-- ── 2. The gift card ─────────────────────────────────────────────────────────────────────────────────────────────
Art.Card=table.freeze({w=340,h=300,corner=24,sash=26,sashEdge=1,bow=44,bowOver=12,
	tag=table.freeze({w=190,h=34,rest=-4,from=-14,font=20,string=2}),shot=64,ring=3,item=96,
	name=22,odds=14,oddsAlpha=.65,primary=table.freeze({w=170,h=52}),later=table.freeze({w=110,h=52}),glint=6,confetti=12,
	entrance=.9,popFrom=.85,popOver=1.05,pop=.3,sashAt=.15,sashSeconds=.2,potFrom=.2,potAt=.35,potDrop=30,squash=.1,
	squashSeconds=.15,burstAt=.5,tagAt=.6,tagSeconds=.3,buttonsAt=.9,reduced=.15,fold=.2,arc=.35,arcLift=.35,arcScale=.35,
	bubbles=6,rays=5})
Art.CardCues=cues({
	{at=0,sound="screen_rise",volume=.4},
	{at=.15,sound="blanket_rustle",speed=1.2,volume=.4},
	{at=.35,sound="egg_tok_1",volume=.5},
	{at=.5,sound="rarity_common",volume=.6,buzz="pop",confetti=true,sweep=true},
})
-- Pure: the card at `t` s from its open. -> {scale, alpha (0..1 opacity), sash (0..1 drawn), bow (scale), potAlpha,
-- potY (px, negative up), potSquash (height factor), tag (degrees), buttons (shown)}
function Art.card(t,reduced)
	local C=Art.Card
	if reduced then
		local a=clamp01(t/C.reduced)
		return{scale=1,alpha=a,sash=1,bow=1,potAlpha=1,potY=0,potSquash=1,tag=C.tag.rest,buttons=t>=C.reduced}
	end
	local s={alpha=1}
	local u=t/C.pop
	if u>=1 then s.scale=1
	elseif u<.6 then s.scale=C.popFrom+(C.popOver-C.popFrom)*easeOut(u/.6)
	else s.scale=C.popOver+(1-C.popOver)*quadInOut((u-.6)/.4)end
	s.sash=easeOut(ramp(t,C.sashAt,C.sashSeconds))
	s.bow=if t<C.sashAt then 0 else backOut(ramp(t,C.sashAt,C.sashSeconds))
	-- the pot falls 30 px to land at .35, then squashes 10%
	local fall=ramp(t,C.potFrom,C.potAt-C.potFrom)
	s.potAlpha=if t<C.potFrom then 0 else clamp01(fall*3)
	s.potY=-C.potDrop*(1-fall*fall)
	s.potSquash=1-C.squash*bump(t,C.potAt,C.potAt+C.squashSeconds)
	-- the tag swings from -14 to -4, past it and back
	local v=ramp(t,C.tagAt,C.tagSeconds)
	s.tag=if t<C.tagAt then C.tag.from else C.tag.rest+(C.tag.from-C.tag.rest)*(1-v)^1.5*math.cos(v*2*math.pi)
	s.buttons=t>=C.buttonsAt
	return s
end
-- Pure: the primary button's fill and label for the item: the pot's colour (ink on rose and citrus, white on tide and
-- iris); a toy (or an unknown pot) is gift pink with ink.
function Art.button(kind,pot)
	if kind=="paint"and Art.PotHex[pot or ""]then
		return Art.PotHex[pot],if Art.WhiteLabel[pot]then Art.Hex.white else Art.Hex.ink
	end
	return Art.Hex.pink,Art.Hex.ink
end
-- Pure: the accent of the card's bubble rims and confetti: the pot's colour, or pink for a toy.
function Art.accent(kind,pot)
	if kind=="paint"and Art.PotHex[pot or ""]then return Art.PotHex[pot]end
	return Art.Hex.pink
end
-- Pure: confetti dot `i`'s colour: the accent, white, light pink, and the accent halfway to white.
function Art.confetti(i,accentHex)
	local pick=(i-1)%4
	local accent=Color3.fromHex(accentHex)
	if pick==0 then return accent end
	if pick==1 then return Color3.new(1,1,1)end
	if pick==2 then return Art.color("light")end
	return Art.mix(accent,Color3.new(1,1,1),.5)
end
-- Pure: confetti dot `i` of `n`, `age` s after the burst: its offset from the pot (px) and opacity; nil once gone.
function Art.confettiAt(i,n,age,reduced)
	if age<0 or age>=1.1 or reduced then return nil end
	local a=(i-1)/n*2*math.pi+.35*math.sin(i*1.7)
	local speed=150+60*((i*.618)%1)
	local x=math.cos(a)*speed*age
	local y=math.sin(a)*speed*age-120*age+160*age*age
	return Vector2.new(x,y),1-clamp01((age-.6)/.5)
end
-- Pure: the pot's arc to the pet after "Paint {pet}!": at share `u` of Card.arc, from `from` to `to` (screen px); a
-- curve lifted `arcLift` of the distance, the pot shrinking to `arcScale`. -> position, scale
function Art.arc(u,from,to)
	local C=Art.Card
	u=quadInOut(u)
	local mid=(from+to)/2-Vector2.new(0,(to-from).Magnitude*C.arcLift)
	local a=from:Lerp(mid,u)
	local b=mid:Lerp(to,u)
	return a:Lerp(b,u),1+(C.arcScale-1)*u
end

-- ── 3. The paint wipe (1.8 s in the garden) ──────────────────────────────────────────────────────────────────────
Art.Wipe=table.freeze({seconds=1.8,closer=.04,closerSeconds=.3,
	pot=table.freeze({size=1.2,over=2.2,arrive=.15,tip=110,tipAt=.25,leave=.45,leaveSeconds=.3}),
	land=.25,ribbon=.5,squash=.12,squashSeconds=.15,
	look=table.freeze({pitch=-.35,eye=1.25,until_=.4}),
	sweep=table.freeze({from=.4,to=1.0,band=.25,drips=6,ahead=.2}),
	ring=table.freeze({at=1.0,size=3,grow=.25,fade=.4}),
	shake=table.freeze({from=1.05,to=1.45,angle=14,swings=4}),
	beads=table.freeze({at=1.05,count=10,seconds=.45}),
	paws=table.freeze({from=1.45,to=1.62,pitch=.3,yaw=.35}),
	spin=table.freeze({from=1.62,to=1.8,hop=.55}),
	sparkles=10,label=2,duplicate=.6,reduced=.4,edge=.5})
Art.WipeCues=cues({
	{at=0,sound="snack_sniff",volume=.5},
	{at=.25,sound="merge_jelly",speed=.8,volume=.5,buzz="crack1"},
	{at=.4,sound="shimmer_loop",speed=.9,toSpeed=1.3,volume=.35,buzz="creak",rising=.6},
	{at=1.0,sound="merge_bubble",speed=1.12,volume=.5,ring=true},
	{at=1.05,sound="shell_scatter",volume=.45,buzz="settle",beads=true},
	{at=1.45,sound="snack_happy_squeak",volume=.55,buzz="pop",sparkles=true},
})
-- Reduced Motion: the cross-fade, the ring, one sound and the settle buzz.
Art.WipeReducedCues=cues({{at=0,sound="merge_bubble",speed=1.12,volume=.5,buzz="settle",ring=true}})
-- Pure: how long the wipe runs (a duplicate pot: 60%; Reduced Motion: the .4 s cross-fade).
function Art.wipeLength(duplicate,reduced)
	if reduced then return Art.Wipe.reduced end
	return Art.Wipe.seconds*(if duplicate then Art.Wipe.duplicate else 1)
end
-- Pure: a time on the wipe's own clock mapped onto the full 1.8 s schedule (a duplicate runs it at 60% length).
function Art.wipeClock(t,duplicate)return t/(if duplicate then Art.Wipe.duplicate else 1)end
-- Pure: the wipe at `t` s (its own clock). Everything the garden draws:
--   pot = {shown, over (studs above the pet's top), tip (degrees), alpha}, stream (0..1 the paint ribbon's length),
--   squash (0..1), headPitch, headYaw (radians), eye (factor), sweep (0..1 crown to feet), ring = {size, alpha} or nil,
--   roll (radians, the shake), beads (0..1 or nil), hop (studs), spin (radians), closer (0..1 the camera's 4%), done
function Art.wipe(t,duplicate,reduced)
	local W=Art.Wipe
	local s={pot={shown=false,over=W.pot.over,tip=0,alpha=1},stream=0,squash=0,headPitch=0,headYaw=0,eye=1,sweep=0,ring=nil,
		roll=0,beads=nil,hop=0,spin=0,closer=0,done=false}
	if reduced then
		local u=clamp01(t/W.reduced)
		s.sweep=u
		s.ring={size=W.ring.size*easeOut(u/.6),alpha=1-u}
		s.done=t>=W.reduced-1e-9
		return s
	end
	local u=Art.wipeClock(t,duplicate)
	s.closer=easeOut(ramp(u,0,W.closerSeconds))*(1-ramp(u,W.seconds-.2,.2))
	-- the pot: in from above, tips 110 degrees by the landing, pours, then lifts away and fades
	if u<W.pot.leave+W.pot.leaveSeconds then
		s.pot.shown=true
		local arrive=easeOut(ramp(u,0,W.pot.arrive))
		local leave=ramp(u,W.pot.leave,W.pot.leaveSeconds)
		s.pot.over=W.pot.over+.8*(1-arrive)+.6*leave
		s.pot.tip=W.pot.tip*easeOut(ramp(u,.05,W.pot.tipAt-.05))*(1-.4*leave)
		s.pot.alpha=arrive*(1-leave)
	end
	s.stream=clamp01(ramp(u,.15,W.land-.15))*(1-ramp(u,W.pot.leave,.1))
	s.squash=bump(u,W.land,W.land+W.squashSeconds)
	-- looks up, eyes wide, until the sweep starts
	if u<W.look.until_ then
		local k=easeOut(ramp(u,0,.12))*(1-ramp(u,W.look.until_-.1,.1))
		s.headPitch=W.look.pitch*k;s.eye=1+(W.look.eye-1)*k
	end
	s.sweep=quadInOut(ramp(u,W.sweep.from,W.sweep.to-W.sweep.from))
	if u>=W.ring.at and u<W.ring.at+W.ring.fade then
		local v=(u-W.ring.at)/W.ring.fade
		s.ring={size=W.ring.size*easeOut(v/(W.ring.grow/W.ring.fade)),alpha=1-v}
	end
	if u>=W.shake.from and u<W.shake.to then
		local v=(u-W.shake.from)/(W.shake.to-W.shake.from)
		s.roll=math.rad(W.shake.angle)*math.sin(v*math.pi*W.shake.swings)*(1-v)
	end
	if u>=W.beads.at and u<W.beads.at+W.beads.seconds then s.beads=(u-W.beads.at)/W.beads.seconds end
	if u>=W.paws.from and u<W.paws.to then
		local v=(u-W.paws.from)/(W.paws.to-W.paws.from)
		s.headPitch=W.paws.pitch*math.sin(v*math.pi)
		s.headYaw=W.paws.yaw*math.sin(v*2*math.pi)
	end
	if u>=W.spin.from and u<W.spin.to then
		local v=(u-W.spin.from)/(W.spin.to-W.spin.from)
		s.hop=W.spin.hop*math.sin(v*math.pi)
		s.spin=2*math.pi*quadInOut(v)
	end
	s.done=u>=W.seconds-1e-9
	return s
end
-- Pure: which colour a body piece shows mid-sweep. top and bottom are the piece's height as shares of the pet (0 the
-- crown, 1 the feet), sweep 0..1. The leading edge is a band (Wipe.sweep.band of the pet's height) of the pot's colour
-- halfway to white; above it the final colour, below it the old. -> "new" | "edge" | "old"
function Art.sweepState(top,bottom,sweep)
	local band=Art.Wipe.sweep.band
	local front=sweep*(1+band)
	local centre=(top+bottom)/2
	if sweep>=1 or centre<front-band then return "new"end
	if centre>front then return "old"end
	return "edge"
end
-- Pure: the bright edge's colour for a pot colour.
function Art.edgeColor(pot)return Art.mix(pot,Color3.new(1,1,1),Art.Wipe.edge)end
-- Pure: drip `i` of `n` at sweep `sweep`: its angle round the pet (radians) and its height share (ahead of the front);
-- nil before the sweep or once past the feet.
function Art.drip(i,n,sweep,height)
	if sweep<=0 or sweep>=1 then return nil end
	local band=Art.Wipe.sweep.band
	local ahead=Art.Wipe.sweep.ahead/math.max(height or 1,.1)
	local share=sweep*(1+band)+ahead*(.6+.4*((i*.618)%1))
	if share>1 then return nil end
	return(i-1)/n*2*math.pi+.4*math.sin(i*2.3),share
end
-- Pure: bead / sparkle `i` of `n`, `age` 0..1 of its flight: the offset from the pet's middle (studs) and its opacity.
function Art.bead(i,n,age,spread)
	local a=(i-1)/n*2*math.pi+.5*math.sin(i*1.9)
	local out=(spread or 1.4)*(.7+.3*((i*.618)%1))*age
	local up=1.1*age-1.6*age*age
	return Vector3.new(math.cos(a)*out,up,math.sin(a)*out),1-clamp01((age-.5)/.5)
end

-- ── 4. The nest Peek (2.4 s, on the tuck) ────────────────────────────────────────────────────────────────────────
-- Honest: the nest egg holds the gift (hat, neck, toy, charm or Stars), never a pet; the shadow is its real kind and
-- the Stars chip the true number; the name waits for the hatch. Light only: the shell is never broken or marked.
Art.Peek=table.freeze({seconds=2.4,prompt=3,
	rock=table.freeze({angle=6,count=3,seconds=.6}),
	crack=table.freeze({at=.6,open=.15,width=.9,height=.5,line=.06,edge=.13,closeAt=1.9,close=.3,points=6}),
	light=table.freeze({range=8,brightness=1.8}),
	shafts=table.freeze({count=4,fan=40,length=1.6,width=.1,alpha=.55,grow=.2}),
	disc=table.freeze({at=.8,grow=.2,size=72,q=34,bob=2,bobPeriod=1.1,out=.9}),
	bear=table.freeze({lean=.12,back=.4,hop=.22,gasp=.35,paws=1.1}),
	pill=1.9,
	reduced=table.freeze({fade=.2,hold=1.6})})
Art.PeekCues=cues({
	{at=0,sound="egg_wobble",volume=.45,buzz="settle"},
	{at=.2,sound="egg_tok_1",volume=.4},
	{at=.4,sound="egg_tok_2",volume=.4},
	{at=.6,sound="egg_crack_glint",volume=.5,buzz="crack1"},
	{at=.6,sound="reveal_shimmer",volume=.3},
	{at=.8,sound="reveal_hush",volume=.45},
	{at=.8,sound="bear_boop",speed=1.2,volume=.45,gasp=true},
	{at=1.9,sound="blanket_rustle",volume=.35,zzz=true,pill=true},
	{at=1.9,sound="pet_coo_1",speed=.85,volume=.35},
})
-- Reduced Motion: every sound and buzz stays.
Art.PeekReducedCues=Art.PeekCues
function Art.peekLength(reduced)
	local R=Art.Peek.reduced
	return if reduced then R.fade*2+R.hold else Art.Peek.seconds
end
-- Pure: the Peek at `t` s. -> {rock (degrees), crack (0..1 open), light (0..1), shafts (0..1), disc (0..1 opacity),
-- discScale, q (px, the "?" bob), lean (0..1 the Bear leaning in), back (studs, the Bear's hop back), hop (studs),
-- paws (0..1 up), done}
function Art.peek(t,reduced)
	local P=Art.Peek
	local s={rock=0,crack=0,light=0,shafts=0,disc=0,discScale=1,q=0,lean=0,back=0,hop=0,paws=0,done=false}
	if reduced then
		local R=P.reduced
		local a=clamp01(t/R.fade)*(1-clamp01((t-R.fade-R.hold)/R.fade))
		s.crack,s.light,s.disc=a,a,a
		s.done=t>=R.fade*2+R.hold-1e-9
		return s
	end
	-- three rocks, each smaller
	if t<P.rock.seconds then
		local u=t/P.rock.seconds
		s.rock=P.rock.angle*math.sin(u*P.rock.count*2*math.pi)*(1-.65*u)
	end
	local open=easeOut(ramp(t,P.crack.at,P.crack.open))
	local close=ramp(t,P.crack.closeAt,P.crack.close)
	s.crack=open*(1-close)
	s.light=s.crack
	s.shafts=easeOut(ramp(t,P.crack.at,P.shafts.grow))*(1-close)
	s.discScale=backOut(ramp(t,P.disc.at,P.disc.grow))*(1-close)
	s.disc=clamp01(ramp(t,P.disc.at,P.disc.grow*.6))*(1-close)
	if t>=P.disc.at then s.q=-P.disc.bob*math.sin((t-P.disc.at)*2*math.pi/P.disc.bobPeriod)end
	-- the Bear leans in, then gasps: hops back, paws up, until the crack closes
	s.lean=if t<P.disc.at then easeOut(ramp(t,0,.3))else 0
	local gasp=ramp(t,P.disc.at,P.bear.gasp)
	s.back=P.bear.back*easeOut(gasp)*(1-ramp(t,P.crack.closeAt,P.crack.close+.2))
	s.hop=P.bear.hop*bump(t,P.disc.at,P.disc.at+P.bear.gasp)
	s.paws=easeOut(ramp(t,P.disc.at,.15))*(1-ramp(t,P.crack.closeAt,P.crack.close))
	s.done=t>=P.seconds-1e-9
	return s
end
-- Pure: the zigzag crack's points across the egg's front, in shares of its width (x -.5..+.5) and of its height (y).
function Art.crackPoints()
	local C=Art.Peek.crack
	local out={}
	for i=0,C.points do
		local x=-.5+i/C.points
		table.insert(out,Vector2.new(x*C.width,C.height+(if i%2==0 then .05 else -.05)))
	end
	return out
end
-- Pure: shaft `i`'s fan angle (degrees, 0 = straight out of the crack).
function Art.shaft(i)
	local S=Art.Peek.shafts
	return -S.fan/2+S.fan*(i-1)/math.max(1,S.count-1)
end
-- The silhouettes: five ink shapes built from frames, in shares of the 72 px disc (x, y the centre). `shape` round
-- (fully rounded), rect (a small corner) or ring (an ink outline); tone ink, or paper (the disc's own glass, to cut).
local function sh(shape,x,y,w,h,rot,tone)return table.freeze({shape=shape,x=x,y=y,w=w,h=h,rot=rot or 0,tone=tone or "ink"})end
local function star()
	local out={sh("round",.5,.53,.26,.26)}
	for k=0,4 do
		local a=math.rad(-90+k*72)
		table.insert(out,sh("rect",.5+math.cos(a)*.15,.53+math.sin(a)*.15,.13,.27,k*72))
	end
	return table.freeze(out)
end
Art.Silhouettes=table.freeze({
	hat=table.freeze({sh("round",.5,.5,.42,.4),sh("rect",.5,.6,.42,.14),sh("round",.5,.66,.66,.1)}),
	neck=table.freeze({sh("rect",.35,.52,.25,.25,45),sh("rect",.65,.52,.25,.25,45),sh("round",.5,.52,.15,.19)}),
	toy=table.freeze({sh("round",.5,.52,.5,.5),sh("rect",.41,.52,.04,.42,-14,"paper"),sh("rect",.59,.52,.04,.42,14,"paper")}),
	charm=table.freeze({sh("ring",.5,.3,.18,.18),sh("rect",.5,.6,.3,.3,45)}),
	stars=star(),
})
Art.SilhouetteKinds=table.freeze({"hat","neck","toy","charm","stars"})
-- Pure: the silhouette for a nest gift's kind (an unknown kind shows the Stars it would be paid as).
function Art.silhouette(kind)return Art.Silhouettes[kind or ""]or Art.Silhouettes.stars end

return table.freeze(Art)
