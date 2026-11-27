-- Onboarding v2 (Fable, artifacts/qa-2026-11-26-beta35/ONBOARDING-V2.md; Spencer's notes 20 to 25: "the new onboarding
-- doesnt help? idek know what to do?"): the numbers and pure rules of the five steps, spec-checked offline
-- (scripts/OnboardV2.spec.lua). The views read these; nothing here touches the game.
--   1 the Welcome deck: one instruction, a 3D spinning egg, three shell pips           (switch egg3d, WelcomeEgg3D)
--   2 the stork brings the egg into the garden                                          (switch stork, FirstHatchStory)
--   3 three taps crack it there                                                         (switch stork, FirstHatchStory)
--   4 the Bear's card, inside the safe area                                             (switch safecard, RevealLayout)
--   5 what now: one worded bubble at a time and the end card                            (switch guide, BearNeeds)
-- Every instruction is 16 characters or fewer and never a key name. The server stays the truth: the Bear is granted and
-- saved by the Welcome round before any of this plays; steps 2 to 4 are presentation and the receipt's own ack.
local V2={}
local function hex(h)return Color3.fromHex(h)end

-- ── Switches ─────────────────────────────────────────────────────────────────────────────────────────────────────────
-- Onboard.on(name); "stork" also needs opener and crack (Onboard.storyOn). Specs inject V2.read.
V2.read=nil
function V2.on(name)
	if V2.read then return V2.read(name)==true end
	local ok,on=pcall(function()
		local Onboard=require(game:GetService("ReplicatedStorage").Shared.Onboard)
		if name=="stork"then return Onboard.storyOn()end
		return Onboard.on(name)
	end)
	return ok and on==true
end

-- ── Step 1: the Welcome deck ─────────────────────────────────────────────────────────────────────────────────────────
V2.Deck=table.freeze({
	textMin=18,textMax=34,ink=hex("#FFFFFF"),
	pip=22,pipGap=10,pipEmpty=hex("#2B4C7E"),pipRing=hex("#9FC4FF"),pipFilled=hex("#FFD86B"),
	-- Beta (36), Spencer: "we dont need that giant shiny circle" and no cracking on the deck (the egg cracks in the
	-- world, step 3); Fable (AERO-JUICE-BRIEF 4): no disc at all and no Neon core showing. The egg itself is lit a
	-- little brighter each combo (the viewport's light), with a short flare on the hop; the finale brightens it more.
	-- Fable B37 1b: the grey flash: a cream base colour under the texture, the texture preloaded (at most 0.6 s) with
	-- the egg hidden, then a 150 ms fade in.
	base=hex("#FBF6D2"),preloadCap=.6,fadeIn=.15,
	pad=8,light=hex("#FFF3D6"),lightIdle=0,lightStep=.12,lightFlare=.12,lightFinal=.6,
	yawRate=25,bobDeg=3,bobHz=.5,                          -- idle: degrees a second, tilt bob
	hop=.10,wobbleDeg=14,wobbleTime=.4,turnTime=.6,        -- each combo: a hop (card heights), a damped wobble, one turn
	pipPop=.2,pipScale=1.3,                                -- a pip fills with a 1.0 -> 1.3 -> 1.0 pop
	finale=.5,lift=.2,                                     -- combo 3: the glow rises, the egg lifts 20% and fades
	reducedYaw=-28,                                        -- Reduced Motion: a still three-quarter pose
	tuckAfter=.4,                                          -- step 2: the deck tucks this long after combo 3
})
-- The card's one line for this moment (UICopy keys). eggVoice (deck2, the onboarding fun pass): after combos 1 and 2
-- the egg's own words ("It moved!", "It's cracking!") instead of a count ("2 more!", "1 more!"; the gold numeral stays).
function V2.deckLine(drops,combos,eggVoice)
	combos=math.clamp(math.floor(tonumber(combos)or 0),0,3)
	if combos>=3 then return "onb2.deck.hatching"end
	if combos==2 then return if eggVoice then "onb2.deck.cracking"else "onb2.deck.one"end
	if combos==1 then return if eggVoice then "onb2.deck.moved"else "onb2.deck.two"end
	if(tonumber(drops)or 0)>=1 then return "onb2.deck.match"end
	return "onb2.deck.drop"
end
-- The board pill before the first drop: computer words only (the phone has the hand, the pad its own picture line).
function V2.dropHint(input)
	if input=="Touch"or input=="Gamepad"then return nil end
	return "onb2.deck.click"
end
-- Pip i (1..3) with `combos` filled: "filled" or "empty".
function V2.pip(i,combos)return if i<=math.clamp(math.floor(tonumber(combos)or 0),0,3)then "filled"else "empty"end
-- The pop of a pip that just filled, `age` s after (1 at rest).
function V2.pipScale(age)
	local D=V2.Deck
	if type(age)~="number"or age<0 or age>=D.pipPop then return 1 end
	return 1+(D.pipScale-1)*math.sin(age/D.pipPop*math.pi)
end
-- How much brighter the egg is lit after `combos` combos (0 = as Hatch eggs lights it): a little more each one.
function V2.glow(combos)return V2.Deck.lightIdle+V2.Deck.lightStep*math.clamp(math.floor(tonumber(combos)or 0),0,3)end
-- Pure: a light colour lifted toward the warm white by `amount` (0..1).
function V2.lift(color,amount)return color:Lerp(V2.Deck.light,math.clamp(amount or 0,0,1))end
local function smooth(u)u=math.clamp(u,0,1);return u*u*(3-2*u)end
-- The egg's pose at clock t, `beat` s after the last combo (nil: none yet). Returns yaw and tilt (degrees) and hop (card
-- heights). Reduced Motion: the still three-quarter pose, no hop.
function V2.eggPose(t,beat,reduced)
	local D=V2.Deck
	if reduced then return D.reducedYaw,0,0 end
	local yaw=(t*D.yawRate)%360
	local tilt=D.bobDeg*math.sin(t*D.bobHz*math.pi*2)
	local hop=0
	if type(beat)=="number"and beat>=0 then
		if beat<D.wobbleTime then
			local u=beat/D.wobbleTime
			hop=D.hop*math.sin(u*math.pi)
			tilt+=D.wobbleDeg*(1-u)*math.sin(u*math.pi*4)
		end
		if beat<D.turnTime then yaw+=360*smooth(beat/D.turnTime)end
	end
	return yaw,tilt,hop
end
-- Combo 3's finale `age` s in: light (0..1), lift (card heights), fade (0 shown .. 1 gone).
function V2.finale(age,reduced)
	local D=V2.Deck
	local u=math.clamp((age or 0)/D.finale,0,1)
	local from=V2.glow(3)
	local glow=from+(D.lightFinal-from)*u
	return glow,if reduced then 0 else D.lift*smooth(u),u
end
-- Each combo's sound on the deck: a rising fill chime (the "charge" cue up a step each time) and a soft buzz. Never a
-- crack: beta (36), the egg only cracks in the world.
V2.ComboChime=table.freeze({cue="charge",pitches={1.12,1.26,1.5},gain=.45,haptic="settle"})

-- ── Step 1, v3: the cuter Welcome deck (switch deck2, WelcomeDeck2) ─────────────────────────────────────────────────
-- Fable, ONBOARDING-V3-BRIEF section 5 (Spencer, beta 37: "a cuter Welcome deck"). Inside the two existing cards; the
-- board and its rules are untouched. It dresses the egg3d deck, so it needs both switches; off is exactly beta (37).
-- Every number is in authored deck pixels (the deck's UIScale shrinks them on a phone) or seconds.
V2.Deck2=table.freeze({
	-- the left card: a glass sky, a 1 px white top highlight, three rising bubbles at 12%
	skyTop=hex("#2FA8F0"),skyBottom=hex("#0E5FB8"),highlight=.35,
	bubbles=3,bubbleAlpha=.12,bubbleRim=.7,bubbleSizes={9,13,16},bubbleX={.2,.56,.82},bubblePeriod={6,7.5,9.2},bubbleSway=4,
	-- the top 45%: the step's looping picture (a 40 px ball, the 64 px sun-gold numeral)
	picture=.45,ball=40,merged=1.3,dropLoop=1.6,matchLoop=2.0,numeral=64,gold=hex("#FFD86B"),
	-- the line under it: each change punches 1.25 with a menu tick
	punch=1.25,punchTime=.2,tick=table.freeze({cue="menu",pitch=1.2,gain=.3}),
	-- the egg card: a sky fill, the hatch card's grass arc on about the bottom 18%, a soft shadow under the egg. Beta 39:
	-- the shadow is a radial blob (UnderstoryArt.Blob, dark green, alpha peaking at shadowPeak) stretched to an ellipse,
	-- 25% dark at its centre fading to nothing, 60% of the egg's width, `shadowAspect` as tall, on the grass top
	eggTop=hex("#C9F1FF"),eggBottom=hex("#58B8F2"),grass=.18,shadowAlpha=.25,shadowWidth=.6,shadowAspect=.28,shadowPeak=229/255,
	-- the knock from inside: a 5 degree twitch and a quiet tap every 4 s, then 2.5 s, then 1.2 s as combos land
	knockEvery={4,2.5,1.2},knockDeg=5,knockTime=.32,knock=table.freeze({cue="egg_wobble",pitch=1.3,gain=.15}),
	-- the pips: three eggs, 26 px tall; empty white at 25% with a 2 px ring, filled gold with a white glint
	pipW=21,pipH=26,pipGap=10,pipPad=6,pipEmptyAlpha=.75,pipRing=hex("#9FC4FF"),pipFilled=hex("#FFD86B"),
	breathe=.12,breatheHz=1,                               -- the next pip to fill breathes 1.0 -> 1.12 at 1 Hz
	-- the combo moment
	arc=.35,beads=4,beadGap=.045,arcLift=50,spark=16,      -- the spark to its pip: 0.35 s, 4 beads behind it
	popGrace=.12,popCap=.5,                                -- a counted combo waits for its spark this long at most
	popScale=1.4,popTime=.25,ringTime=.35,ringScale=2.2,   -- the pip pops 1.0 -> 1.4 -> 1.0 with a ring
	flash=.3,                                              -- the egg card's border in the merged tier's light
	wordTime=.6,wordPunch=1.45,wordIn=.12,wordOut=.18,     -- the word over the well
	-- combo 3: the pips fly into the egg, one light sweep, then the egg's rise and the tuck
	flyStart=.25,flyTime=.3,flyStagger=.05,flyTo=.3,
	sweepStart=.55,sweepTime=.35,sweepAlpha=.45,
	finaleAt=.55,                                          -- the old finale (glow, lift, fade) starts this long after pip 3
	tuckAfter=1.2,                                         -- the deck tucks this long after combo 3 (Deck.tuckAfter off)
	-- the onboarding fun pass (ONBOARDING-FUN-PASS section 1, "deck to stork"): from finaleAt until the deck tucks (the
	-- story asks for the garden, or never takes the Bear), the egg stays, knocks every 0.4 s and the card's border
	-- pulses gold; its rise starts as the deck tucks. holdMax: the rise starts by then whatever (past V2.Hold + tuckAfter)
	holdKnock=.4,pulseHz=1.4,pulseLow=.15,pulseHigh=.8,pulseReduced=.35,holdMax=6,
})
V2.ComboWords=table.freeze({"onb2.deck.nice","onb2.deck.close","onb2.deck.hatching"})
-- Both switches: the cuter deck dresses the egg3d deck.
function V2.deck2On()return V2.on("deck2")and V2.on("egg3d")end
-- Step 2's tuck: Deck.tuckAfter as before, longer with deck2 (combo 3's pips, sweep and rise play first).
function V2.tuckAfter()return if V2.deck2On()then V2.Deck2.tuckAfter else V2.Deck.tuckAfter end
-- The left card's picture for this moment: "drop", "match", "two", "one" or "hatching" (V2.deckLine's moments).
function V2.picture(drops,combos)
	local key=V2.deckLine(drops,combos)
	return(string.match(key,"([%a]+)$"))
end
-- The numeral over "2 more!" / "1 more!" (a UICopy key), or nil.
function V2.numeral(picture)
	if picture=="two"then return "onb2.deck.numTwo"end
	if picture=="one"then return "onb2.deck.numOne"end
	return nil
end
-- The punch word for combo n (1..3).
function V2.comboWord(n)return V2.ComboWords[math.clamp(math.floor(tonumber(n)or 1),1,3)]end
-- Pure: a 1 -> peak -> 1 punch `age` s into a `time` s punch (1 outside it).
function V2.punch(age,peak,time)
	if type(age)~="number"or age<0 or age>=time then return 1 end
	return 1+(peak-1)*math.sin(age/time*math.pi)
end
-- Pure: the "Drop a ball!" loop at t: the ball's fall (0 at the top .. 1 on the floor), its squash (width, height
-- scale) and see-through. 1.6 s: it falls (0.45 s, ease-in), squashes and settles (to 0.75 s), rests, fades by 1.6.
-- Reduced Motion: resting on the floor, still.
function V2.dropBall(t,reduced)
	local D=V2.Deck2
	if reduced then return 1,1,1,0 end
	t=(t or 0)%D.dropLoop
	local fall,sx,sy,alpha=1,1,1,0
	if t<.45 then
		local u=t/.45;fall=u*u
		sx,sy=1-.08*u,1+.1*u                                 -- it stretches as it speeds up
		alpha=if t<.08 then 1-t/.08 else 0
	elseif t<.75 then
		local u=(t-.45)/.3
		local s=math.sin(u*math.pi)*(1-u)
		sx,sy=1+.28*s,1-.24*s                                -- the squash on landing, springing back
	elseif t>1.3 then alpha=(t-1.3)/.3 end
	return fall,sx,sy,math.clamp(alpha,0,1)
end
-- Pure: the "Match two!" loop at t: the two balls' offsets from the middle (in ball widths, + right), the bigger
-- ball's scale (0 hidden) and the picture's see-through. 2 s: they roll in and bump (0.55 s), the bigger one pops in
-- 0 -> 1.15 -> 1 (to 0.85 s), rests, fades by 2.0. Reduced Motion: the two balls touching, still.
function V2.matchBalls(t,reduced)
	local D=V2.Deck2
	if reduced then return -.5,.5,0,0 end
	t=(t or 0)%D.matchLoop
	if t<.55 then
		local u=smooth(t/.55)
		local gap=1.1-.6*u
		return -gap,gap,0,if t<.1 then 1-t/.1 else 0
	end
	local u=math.clamp((t-.55)/.3,0,1)
	local grow=if u<.6 then 1.15*smooth(u/.6)else 1.15-.15*smooth((u-.6)/.4)
	return -.5,.5,grow,if t>1.7 then math.clamp((t-1.7)/.3,0,1)else 0
end
-- Pure: one rising bubble on the left card (i 1..3) at t: its height (0 the foot .. 1 the top, of the card), sideways
-- sway (px) and see-through (the 12% body fades in at the foot and out at the top). Reduced Motion: still, part way up.
function V2.cardBubble(i,t,reduced)
	local D=V2.Deck2
	local period=D.bubblePeriod[i]or 7
	local u=if reduced then .25+.22*(i-1)else((t or 0)/period+(i-1)*.37)%1
	local sway=if reduced then 0 else D.bubbleSway*math.sin(((t or 0)/period+i)*math.pi*2*1.5)
	local fade=math.min(1,u/.12,(1-u)/.2)
	return u,sway,1-D.bubbleAlpha*math.clamp(fade,0,1)
end
-- The knock: seconds between knocks with `combos` combos landed (nil: no more knocking). holding: combo 3 is in and the
-- deck waits for the stork (the fun pass): every holdKnock s.
function V2.knockEvery(combos,holding)
	if holding then return V2.Deck2.holdKnock end
	return V2.Deck2.knockEvery[math.clamp(math.floor(tonumber(combos)or 0),0,3)+1]
end
-- Pure: is a knock due at `now` (the last at `last`)? Never under Reduced Motion, nor once combo 3 has landed unless
-- the deck is holding.
function V2.knockDue(now,last,combos,reduced,holding)
	local every=V2.knockEvery(combos,holding)
	if reduced or not every or type(now)~="number"then return false end
	return now-(last or now)>=every
end
-- Pure: the knock's twitch (degrees) `age` s after it: a 5 degree jolt, damped, two swings over 0.32 s.
function V2.knockTwitch(age)
	local D=V2.Deck2
	if type(age)~="number"or age<0 or age>=D.knockTime then return 0 end
	local u=age/D.knockTime
	return D.knockDeg*(1-u)*(1-u)*math.sin(u*math.pi*4)
end
-- Pure (the fun pass): the egg card's gold border `age` s into the hold: its see-through, pulsing pulseLow..pulseHigh
-- at pulseHz (it starts bright). Reduced Motion: a steady pulseReduced.
function V2.holdPulse(age,reduced)
	local D=V2.Deck2
	if type(age)~="number"or age<0 then return 1 end
	if reduced then return D.pulseReduced end
	local u=.5-.5*math.cos(age*D.pulseHz*math.pi*2)
	return D.pulseLow+(D.pulseHigh-D.pulseLow)*u
end
-- Pure (the fun pass): does the egg's rise start now? holdFrom: when the hold began (nil: no hold); tucked: the deck is
-- tucking (the story asked for the garden, or it will not take the Bear). By holdMax s whatever.
function V2.riseDue(holdFrom,now,tucked)
	if type(holdFrom)~="number"or type(now)~="number"or now<holdFrom then return false end
	return tucked==true or now-holdFrom>=V2.Deck2.holdMax
end
-- Pure: the next pip's breath at t (1 at rest; 1.0 -> 1.12 at 1 Hz). Still under Reduced Motion.
function V2.breathe(t,reduced)
	if reduced then return 1 end
	local D=V2.Deck2
	return 1+D.breathe*(.5-.5*math.cos((t or 0)*D.breatheHz*math.pi*2))
end
-- Pure: when combo n's pip pops. counted: when the server's count reached n (nil: not yet, no pop); landAt: when its
-- spark lands (nil: no spark yet). It waits for its spark, at most popCap s; with no spark it pops popGrace s after the
-- count (a spark sent in that time is waited for). Reduced Motion (no arc): at once.
function V2.pipPopAt(counted,landAt,reduced)
	if type(counted)~="number"then return nil end
	if reduced then return counted end
	local D=V2.Deck2
	if type(landAt)=="number"then return math.clamp(landAt,counted,counted+D.popCap)end
	return counted+D.popGrace
end
-- Pure: a popped pip `age` s after its pop: its scale (1 -> 1.4 -> 1) and its ring's scale and see-through (1 gone).
-- Reduced Motion: no pop, no ring.
function V2.pipPop(age,reduced)
	local D=V2.Deck2
	if reduced or type(age)~="number"or age<0 then return 1,1,1 end
	local scale=V2.punch(age,D.popScale,D.popTime)
	if age>=D.ringTime then return scale,1,1 end
	local u=age/D.ringTime
	return scale,1+(D.ringScale-1)*(1-(1-u)*(1-u)),u
end
-- Pure: the egg card's border flash `age` s in: its see-through (1 gone).
function V2.flashAlpha(age)
	if type(age)~="number"or age<0 or age>=V2.Deck2.flash then return 1 end
	return age/V2.Deck2.flash
end
-- Pure: the word over the well `age` s in: shown, its scale (1.45 -> 1 in 0.12 s; 1 under Reduced Motion) and
-- see-through (it fades over the last 0.18 s).
function V2.wordLook(age,reduced)
	local D=V2.Deck2
	if type(age)~="number"or age<0 or age>=D.wordTime then return false,1,1 end
	local scale=if reduced or age>=D.wordIn then 1 else D.wordPunch-(D.wordPunch-1)*smooth(age/D.wordIn)
	local fade=math.clamp((age-(D.wordTime-D.wordOut))/D.wordOut,0,1)
	return true,scale,fade
end
-- Pure: the spark's point at u (0..1) on a curve rising `lift` px over the line from a to b (screen px, y down).
function V2.arc(a,b,u,lift)
	u=math.clamp(u,0,1)
	local c=(a+b)/2-Vector2.new(0,lift or V2.Deck2.arcLift)
	local v=1-u
	return a*(v*v)+c*(2*v*u)+b*(u*u)
end
-- Pure: how far along its arc a spark is `age` s after it left (ease-in: it speeds into the pip); 1 = landed.
function V2.arcProgress(age)
	if type(age)~="number"or age<=0 then return 0 end
	local u=math.clamp(age/V2.Deck2.arc,0,1)
	return u*u
end
-- Pure: combo 3's flight of pip i (1..3) `age` s after pip 3 popped: progress (0 home .. 1 in the egg), scale and
-- see-through. Reduced Motion: no flight; the pips fade where they are over the same time.
function V2.pipFly(i,age,reduced)
	local D=V2.Deck2
	local start=D.flyStart+(i-1)*D.flyStagger
	local u=math.clamp(((age or 0)-start)/D.flyTime,0,1)
	if reduced then return 0,1,u end
	local e=u*u
	return e,1-(1-D.flyTo)*e,if u>.7 then(u-.7)/.3 else 0
end
-- Pure: combo 3's light sweep `age` s after pip 3 popped: the band's offset (-1 .. 1) or nil (not sweeping).
function V2.sweep(age,reduced)
	local D=V2.Deck2
	if reduced or type(age)~="number"then return nil end
	local u=(age-D.sweepStart)/D.sweepTime
	if u<0 or u>1 then return nil end
	return -1+2*smooth(u)
end
-- Pure: the egg card's soft shadow (beta 39: it was a hard grey pill). cx: the egg's centre across, eggW: its width,
-- crestY: the grass top (card px); rise: how far the egg is lifted (px: a hop, the finale's rise), fade: the egg's own
-- fade (0..1). Returns the ellipse's centre x, y, width, height and the blob's ImageTransparency: it lies on the grass
-- top, and shrinks and fades as the egg lifts (gone at one egg width up).
function V2.eggShadow(cx,eggW,crestY,rise,fade)
	local D=V2.Deck2
	eggW=math.max(0,tonumber(eggW)or 0)
	local up=if eggW>0 then math.clamp((tonumber(rise)or 0)/eggW,0,1)else 0
	local w=math.max(4,math.floor(eggW*D.shadowWidth*(1-.4*up)+.5))
	local h=math.max(3,math.floor(w*D.shadowAspect+.5))
	local alpha=D.shadowAlpha*(1-up)*(1-math.clamp(tonumber(fade)or 0,0,1))
	return math.floor((tonumber(cx)or 0)+.5),math.floor((tonumber(crestY)or 0)+h*.25+.5),w,h,math.clamp(1-alpha/D.shadowPeak,0,1)
end
-- Pure: the grass arc's crest (a share of the egg card's height) for the egg's foot at `foot` (share): the arc meets
-- the egg's foot, about the bottom 18% of the card, never under 12% or over 26%.
function V2.grassCrest(foot)
	local D=V2.Deck2
	return math.clamp(tonumber(foot)or(1-D.grass),.74,.88)
end
-- Pure: an egg pip's outline as Path2D control points ({x, y, left dx, left dy, right dx, right dy} in px) for a pip
-- `w` x `h`: round at the foot, a little narrower at the top (its widest at 58% down).
function V2.eggOutline(w,h)
	local k=.5523
	local mid=h*.58
	local up,down=mid,h-mid
	local r=w/2
	return{
		{r,0,-k*r,0,k*r,0},
		{w,mid,0,-k*up,0,k*down},
		{r,h,k*r,0,-k*r,0},
		{0,mid,0,k*down,0,-k*up},
	}
end

-- ── Step 1 to 2: one hatch, never two (review B36) ──────────────────────────────────────────────────────────────────
-- The deck's own hatch modal waits up to Hold s for the Bear's receipt (the stork plays it). A receipt that comes later
-- finds the modal already let back: the stork then declines it for the session (the old path plays it), so the Bear
-- never hatches twice. gate: a table the story keeps ({since, declined}).
V2.Hold=4
-- Pure: does the deck modal wait (true) at `now`? bear: the deck is hatching the first Bear; running: the story runs.
function V2.deckHold(gate,bear,running,now)
	if not bear then gate.since=nil;return false end
	if running then return true end
	if gate.declined then return false end
	gate.since=gate.since or now
	if now-gate.since<V2.Hold then return true end
	gate.declined=true -- the modal shows from here: no stork for this session
	return false
end
-- Pure: may the story still take the Bear's receipt?
function V2.mayClaim(gate)return gate.declined~=true end
-- The card's safety: with no stage (it failed to show) Meet happens at once; a card left up this long meets too.
V2.CardTimeout=90
-- Beta (37) note 1 ("the bear ... teleports somewhere behind us behind a fence"): on Meet the garden Bear is asked to
-- stand where the egg opened, facing the player, a beat (s) before it follows (the server's GardenState:stand owns
-- the spot; reach s more for the ask to arrive). The story's own Bear stands there until the garden Bear is drawn
-- within `near` studs of it (or `wait` s pass), then the two swap.
-- The fun pass: the beat is 0.8 s (was 1.5).
V2.Stand=table.freeze({beat=.8,reach=.6,wait=2,near=1.2})
-- Pure: is the garden Bear drawn at the egg's spot (flat distance)?
function V2.standArrived(at,land)
	if typeof(at)~="Vector3"or typeof(land)~="Vector3"then return false end
	return Vector2.new(at.X-land.X,at.Z-land.Z).Magnitude<=V2.Stand.near and math.abs(at.Y-land.Y)<=2
end

-- ── Step 2: the stork ────────────────────────────────────────────────────────────────────────────────────────────────
V2.Stork=table.freeze({
	-- the onboarding fun pass (ONBOARDING-FUN-PASS section 1): 4.6 s, was 6.0 (glide 3.0, hover 3.8, release 4.3);
	-- the bundle's lowering and let-go keep their length, the glide loses 1 s and the leave 0.4 s (V2.Leave)
	glide=2.0,hover=2.8,release=3.3,total=4.6,             -- seconds: glide in, lower the bundle, let go, fly off
	out=40,up=18,land=6,hoverUp=4.2,                       -- studs: the start (out, up, to the player's right), the drop
	flapDeg=35,flapFast=3,flapSlow=1.5,                    -- wings
	open=1.2,rockDeg=6,clacks=2,                           -- the blanket's radius, the egg's settle rock
	skipAt=.5,skipH=44,fov=55,reducedFade=.3,               -- Skip from 0.5 s (was 1)
	body=hex("#F6F3EA"),tips=hex("#2E3440"),beak=hex("#F28C28"),cap=hex("#5B8DEF"),band=hex("#FFD86B"),
	blanket=hex("#8FD3FF"),dots=hex("#FFFFFF"),
})
-- The phase at t: "glide", "hover", "release", "leave" or "gone".
function V2.storkPhase(t)
	local S=V2.Stork
	if t<S.glide then return "glide"end
	if t<S.hover then return "hover"end
	if t<S.release then return "release"end
	if t<S.total then return "leave"end
	return "gone"
end
-- The wing angle (degrees) at t: 3 Hz slowing to 1.5 Hz over the glide, 1.5 Hz after (the phase is the integral, so
-- the beat never jumps).
function V2.flap(t)
	local S=V2.Stork
	local phase
	if t<=S.glide then
		local slope=(S.flapSlow-S.flapFast)/S.glide
		phase=S.flapFast*t+.5*slope*t*t
	else
		phase=S.flapFast*S.glide+.5*(S.flapSlow-S.flapFast)*S.glide+S.flapSlow*(t-S.glide)
	end
	return S.flapDeg*math.sin(phase*math.pi*2)
end
-- Pure: the point on a curve at u (0..1) from a to b, bowed out by `bow` (a Vector3 offset at the middle).
function V2.curve(a,b,bow,u)
	u=math.clamp(u,0,1)
	local c=(a+b)/2+bow
	local v=1-u
	return a*(v*v)+c*(2*v*u)+b*(u*u)
end
-- Pure: how far the bundle hangs under the beak (0 tucked .. 1 on the ground) at t.
function V2.lower(t)
	local S=V2.Stork
	if t<S.glide then return 0 end
	return smooth((t-S.glide)/(S.hover-S.glide))
end
-- Pure: the egg's settle rock (degrees) `age` s after it is let go.
function V2.rock(age)
	local S=V2.Stork
	if type(age)~="number"or age<0 then return 0 end
	local span=S.release-S.hover
	if age>=span then return 0 end
	local u=age/span
	return S.rockDeg*(1-u)*math.sin(u*math.pi*3)
end
-- The two beak clacks and the nod in the leave phase (seconds after the release): {clacks}, nodAt, flyAt.
-- The fun pass: the leave is 1.3 s (was 1.7): the clacks, the nod and the fly-off come a little sooner.
V2.Leave=table.freeze({clacks={.12,.34},nod=.55,fly=.75})

-- Beta (36), Spencer: "the stork flies thru the arch mesh". The flight is chosen against the world before it starts:
-- candidate approaches (a heading round the landing and a height) are sampled along the same curve the stork flies,
-- its body (2.2 studs over its feet) swept as a sphere of Route.radius (the wings); the first clear one is flown, and
-- the stork leaves back along it. None clear: it comes straight down from high over the landing.
--   headings: degrees from the player's right (0) toward beyond the landing (90); negative ones come from behind.
V2.Route=table.freeze({radius=3,body=2.2,samples=24,coarse=6,budget=160,castsPerSweep=4,framesCasts=24,out=40,bowUp=5,bowBack=6,
	headings={11,169,45,135,90,-20,-160},heights={18,28,38},drop=40,
	-- the landing: 6 studs ahead first, then round the player, with open sky over it (the bundle comes down there)
	landing={{0,6},{30,6},{-30,6},{60,6},{-60,6},{0,8},{90,6},{-90,6},{0,10},{45,9},{-45,9},{135,6},{-135,6},{180,6}},
	sky=9,skyRadius=1.3,
	-- the stork's beak tip from its feet (StorkModel.BeakTip): the bundle hangs here, so it hovers with its body back
	beak=Vector3.new(0,3.4,-2.95),hoverUp=4.4})
-- Fable B37 section 3: the open blanket 78% of its old diameter, half as thick, with no grey tufts (the dots are a pale
-- blue), and on the arrival dais it lands 0.6 studs further in, so nothing hangs past the chamfer.
V2.Blanket=table.freeze({radius=1.2*.78,thick=.1*.5,dots=hex("#DCEBFA"),inward=.6,daisReach=8})
-- Pure: the landing moved Blanket.inward studs toward the dais centre when it is on (near) the dais.
function V2.onDais(land,dais)
	if typeof(dais)~="Vector3"then return land end
	local d=Vector3.new(dais.X-land.X,0,dais.Z-land.Z)
	local m=d.Magnitude
	if m>V2.Blanket.daisReach or m<1e-3 then return land end
	return land+d/m*math.min(V2.Blanket.inward,m)
end
-- Pure: the stork's feet (root) while it hovers over `land` facing the player (its beak tip over the landing).
function V2.hover(land,toPlayer)
	local R=V2.Route
	return land+Vector3.new(0,R.hoverUp-R.beak.Y,0)+toPlayer*R.beak.Z
end
-- Pure: a heading's direction (degrees) from the player's right toward beyond the landing.
function V2.heading(right,away,degrees)
	local a=math.rad(degrees)
	return right*math.cos(a)+away*math.sin(a)
end
-- Pure: the body's path for a start, a hover root and a bow: Route.samples + 1 points.
function V2.routePath(start,hover,bow,samples)
	local out={}
	local lift=Vector3.new(0,V2.Route.body,0)
	local n=samples or V2.Route.samples
	for i=0,n do out[i+1]=V2.curve(start,hover,bow,i/n)+lift end
	return out
end
-- Pure: the flight. land: the landing point; toPlayer: flat unit vector from it to the player; hover: the stork's root
-- when it hovers over the landing; clear(a, b, radius): true when a sphere swept from a to b hits nothing. Returns
-- {start, bow, heading, height} (heading nil = straight down) and how many candidates were tried.
function V2.storkRoute(land,toPlayer,hover,clear)
	local R=V2.Route
	local up=Vector3.new(0,1,0)
	local away=-toPlayer
	local right=away:Cross(up)
	right=right/math.max(1e-6,right.Magnitude)
	local bow=up*R.bowUp-toPlayer*R.bowBack
	-- Code review: a cast budget. Each candidate is swept coarse first (Route.coarse legs), then fine only if that is
	-- clear; the first clear one is flown; past Route.budget sweeps it stops and comes straight down.
	local tried,calls=0,0
	local function sweep(path)
		for i=1,#path-1 do
			if calls>=R.budget then return false end
			calls+=1
			if not clear(path[i],path[i+1],R.radius)then return false end
		end
		return true
	end
	for _,height in ipairs(R.heights)do
		for _,degrees in ipairs(R.headings)do
			if calls>=R.budget then break end
			tried+=1
			local start=land+V2.heading(right,away,degrees)*R.out+up*height
			if sweep(V2.routePath(start,hover,bow,R.coarse))and sweep(V2.routePath(start,hover,bow))then
				return{start=start,bow=bow,heading=degrees,height=height},tried,calls
			end
		end
	end
	return{start=hover+up*R.drop,bow=Vector3.new(0,0,0),heading=nil,height=R.drop},tried,calls
end
-- Pure: the landing. ground(x, z) -> the ground point under it or nil; clear as storkRoute. look: the player's flat
-- look; at: the player's feet. The first spot with ground and open sky (Route.sky studs) over it, else the first guess.
function V2.landing(at,look,ground,clear)
	local R=V2.Route
	local up=Vector3.new(0,1,0)
	local first
	for _,spot in ipairs(R.landing)do
		local dir=CFrame.Angles(0,math.rad(spot[1]),0):VectorToWorldSpace(look)
		local guess=at+dir*spot[2]
		local point=ground(guess.X,guess.Z,at.Y)
		if point then
			first=first or point
			-- open sky over it, and room for the hovering stork (its body and wings) over it
			local toPlayer=Vector3.new(at.X-point.X,0,at.Z-point.Z)
			toPlayer=if toPlayer.Magnitude>1e-3 then toPlayer/toPlayer.Magnitude else -look
			local body=V2.hover(point,toPlayer)+up*R.body
			if clear(point+up*.6,point+up*R.sky,R.skyRadius)and clear(body,body+up*6,R.radius)then return point end
		end
	end
	-- no ground under any spot: nil, so the story can take the spawn pad
	return first
end

-- ── Step 3: crack it ─────────────────────────────────────────────────────────────────────────────────────────────────
-- Fable's cathartic crack (AERO-JUICE-BRIEF section 4), on Spencer's 3D cracks: the cracks grow on the shell itself
-- (EggCrackPaths: where; EggCrack3D: how it looks), never on the screen. Per tap: a 40 ms anticipation dip, the
-- sound and buzz, the crack stage growing over 90 ms, the rock (or the flex), crumbs, the camera 3% closer.
V2.Crack=table.freeze({
	dist=5,up=1.6,fov=40,tween=.6,vignette=hex("#0B1220"),vignetteAlpha=.35,pill=hex("#FFD86B"),
	stops={.05,.5,.95},                                   -- the ritual's clock: a stop per tap, a beat between
	handAfter=3,auto=7,                                    -- no countdown shown; the hand at 3 s, the tap itself at 7 s
	zone=.6,                                               -- any tap in the middle 60% of the screen counts
	anticipate=.04,grow=.09,closer=.03,leakAlpha=.25,
	flex={time=.25,to=1.08,hzFrom=5,hzTo=9},
	pop={silence=.08,duck=.5,keepBottom=.6,up=3,fade=.5,flash=.12,flashAlpha=.35,kick=.15,fovPeak=44,fovRest=42,settle=.4,hold=.6,
		pieces={12,16},voiced=5,cueDelay=.12,lateFlakes={2,4},sting="rarity_common",scatter="shell_scatter"},
	-- the pop's beat: the creak and flex, then the silence, then the burst (s after tap 3's sound)
	creak=.25,
})
-- What each tap does. layers: HatchAsmr layers (existing ids); takes: the new synthesised takes (Story.Takes, empty
-- slots until uploaded); under: a layer under it at a gain; rock (deg) and its cycles, or flex; crumbs and their kind.
V2.Taps=table.freeze({
	{dip=.03,widen=.02,layers={"crack1"},takes={"tap_knuckle"},haptic="crack1",rock=10,cycles=2,crumbs=4,stage=1,closer=true},
	{dip=.04,widen=.02,layers={"crack2"},takes={"tap_knuckle"},under={layer="creak",gain=.4},haptic="crack2",rock=14,cycles=3,
		crumbs=6,stage=2,leak=true,closer=true,duck={time=.6,gain=.7}},
	{dip=.05,widen=.02,hold=true,layers={"creakLong"},takes={"asmr_crack3"},haptic="creak_long",flex=true,crumbs=3,skitter=true,
		stage=3,pop=true},
})
V2.ReducedFlakes=3
-- Pure: the anticipation dip before a tap's sound: squash Y (1 = rest) and widen XZ at t (s since the tap), for tap i.
function V2.dip(i,t)
	local tap=V2.Taps[i];if not tap or type(t)~="number"or t<0 then return 1,1 end
	local A=V2.Crack.anticipate
	if t<A then local u=smooth(t/A);return 1-tap.dip*u,1+tap.widen*u end
	if tap.hold then return 1-tap.dip,1+tap.widen end -- tap 3 holds its dip into the flex
	local u=smooth((t-A)/.08)
	return 1-tap.dip*(1-u),1+tap.widen*(1-u)
end
-- Pure: the rock (deg) t s after a tap's sound: damped, `cycles` swings over 0.4 s.
function V2.tapRock(i,t)
	local tap=V2.Taps[i];if not tap or not tap.rock or type(t)~="number"or t<0 or t>=.4 then return 0 end
	local u=t/.4
	return tap.rock*(1-u)*(1-u)*math.sin(u*math.pi*2*tap.cycles)
end
-- Pure: tap 3's shell flex: the scale t s after its sound (1.00 to 1.08 while the wobble climbs 5 Hz to 9 Hz).
function V2.flex(t)
	local F=V2.Crack.flex
	if type(t)~="number"or t<0 then return 1 end
	local u=math.clamp(t/F.time,0,1)
	local cycles=(F.hzFrom*u+.5*(F.hzTo-F.hzFrom)*u*u)*F.time -- the integral of a 5 -> 9 Hz sweep
	return 1+(F.to-1)*u+.012*u*math.sin(cycles*math.pi*2)
end
-- Pure: the pop's camera, t s after the burst: kick back (studs) and the FOV (40 -> 44 -> 42 over 0.4 s).
function V2.popCamera(t)
	local P=V2.Crack.pop
	if type(t)~="number"or t<0 then return 0,V2.Crack.fov end
	local u=math.clamp((t-.06)/(P.settle-.06),0,1)
	local up=math.clamp(t/.06,0,1)
	local fov=if t<.06 then V2.Crack.fov+(P.fovPeak-V2.Crack.fov)*smooth(up)else P.fovPeak+(P.fovRest-P.fovPeak)*smooth(u)
	return P.kick*smooth(up)*(1-.6*smooth(u)),fov
end
-- TODO(upload): the asset id of assets/eggs/textures/egg-companion-color-noseam.png (scripts/build_egg_textures.py
-- noseam): the first Bear's egg without its zig-zag until it opens. PLACEHOLDER 0 = not uploaded yet: the old map
-- (Models.Types.companion.colorMap, with the zig-zag) is used.
V2.NoSeamId=130682441511149 -- egg-companion-color-noseam.png (uploaded 2026-11-26)
-- The closed egg's map, or nil for the old one.
function V2.closedMap()return if type(V2.NoSeamId)=="number"and V2.NoSeamId>0 then "rbxassetid://"..V2.NoSeamId else nil end
-- Pure: does a press at `at` (px) count, on a screen of `size` (px)? The middle 60% each way.
function V2.inZone(at,size)
	if typeof(at)~="Vector2"or typeof(size)~="Vector2"then return false end
	local m=(1-V2.Crack.zone)/2
	return at.X>=size.X*m and at.X<=size.X*(1-m)and at.Y>=size.Y*m and at.Y<=size.Y*(1-m)
end
-- The longest an untouched egg takes to open (s): three waits, the beats and the creak.
function V2.longest()
	local C=V2.Crack
	return C.auto*#C.stops+C.stops[#C.stops]+C.creak
end
-- The pill's wording by the last input (UICopy keys for CrackFx:configure).
V2.CrackCopy=table.freeze({Touch="onb2.crack.tap",Gamepad="onb2.crack.pad",other="onb2.crack.click"})

-- ── Step 5: what now ─────────────────────────────────────────────────────────────────────────────────────────────────
V2.Guide=table.freeze({
	order={"needHi","needNest","needDeck"},
	-- Beta (37) note 3 ("it said youre all set before i even did anything. it just timed out?"): a prompt is never
	-- skipped. Shown this long (s, counted while it shows) and not done, it nudges instead: the bubble hops and the pet
	-- chirps softly, again every `nudge` s at most, until it is done.
	ignore=20,
	nudge=15,
	far=12,                                               -- a dotted trail leads to anything further than this (studs)
	fill=hex("#FFFFFF"),ink=hex("#1B2A4A"),arrow=hex("#FFD86B"),arrowPx=6,arrowHz=1,
	endCard=2.5,
})
V2.GuideCopy=table.freeze({needHi="onb2.guide.pet",needNest="onb2.guide.nest",needDeck="onb2.guide.deck"})
V2.GuideIcon=table.freeze({needHi="hand",needNest="moon",needDeck="deck"})
-- The bubble's button picture: the pad's X only (G and L2 still work, never printed; a phone taps, a computer clicks).
function V2.guideKey(input)return if input=="Gamepad"then "X"else nil end
-- Is a guide prompt that has shown since `shownAt` ignored at `now`?
function V2.ignored(shownAt,now)return type(shownAt)=="number"and type(now)=="number"and now-shownAt>=V2.Guide.ignore end
-- Pure (beta 37 note 3): is an attention nudge due? shownFor: seconds the prompt has shown, not done; lastAt: the last
-- nudge (nil: none yet); now: the clock. Never a skip.
function V2.nudgeDue(shownFor,lastAt,now)
	if type(shownFor)~="number"or type(now)~="number"or shownFor<V2.Guide.ignore then return false end
	return type(lastAt)~="number"or now-lastAt>=V2.Guide.nudge
end
-- The bubble's arrow lift (px) at t; still under Reduced Motion.
function V2.arrowLift(t,reduced)
	if reduced then return 0 end
	return V2.Guide.arrowPx*(.5-.5*math.cos((t or 0)*V2.Guide.arrowHz*math.pi*2))
end
return V2
