-- The Pocket Deck feel pass (DECK-FEEL-BRIEF, beta 40 notes 9-17). Pure parts only:
--   switch   Alive "deckfeel": the flag, beta and Studio only, never the live place; the override.
--   open     the 1.25 s timeline, the rise (4 px overshoot, scale .92 -> 1), the scanline, the panels' order and
--            stagger, the held ball's drop and squash, the full boot on the session's first open only, the timing.
--   hold     the minimum visible hold, the drag direction (3 px on, 120 ms off), the stick, the wedge, A's press scale.
--   lean     the brief's offsets, the 3 px cap, the phone scale, the spring's one overshoot under 1 px, the parallax,
--            the merge winning, Reduced Motion and Motion: Low.
--   life     the pattern drift and merge jump, the breath, blinks every 4-6 s, the aim march, the dashes, the near
--            colour, the lane, border, glow and dust shapes; what Reduced Motion keeps.
--   fresh    the stale-balls gate (always on), the resumed round's rows bottom up (40 ms, .3 s at most).
--   stepper  live only while untouched, tap wraps and keys stop, the one pop, the tints, the picker's two cases.
--   polish   the pill rect and the content shift that never passes the card's foot; the change-only motion shapes.
--   results  kinds, opening cues (no `lose`), the beat list, the clock spec, the blip pitch, the headline, stamps,
--            rows, the Star's land, the punch, the buttons by 1.9, the burst, the looks and Reduced Motion.
-- Usage (Client): require(ZZSpecs.DeckFeel)(StarterPlayerScripts.Client)
-- Offline: scripts/run_dash_server_specs.py
return function(client)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Alive=require(Shared.Alive)
	local Flags=require(Shared.FeatureFlags)
	local Feel=require(client.DeckFeel)
	local Lean=require(client.DeckPressLean)
	local Fresh=require(client.DeckFresh)
	local Handoff=require(client.DeckHandoff)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function near(a,b,e)return math.abs(a-b)<=(e or 1e-6)end

	test("switch: Alive deckfeel (beta and Studio only, never live); the override wins",function()
		assert(table.find(Alive.Features,"deckfeel")and Flags.AliveDeckFeel==true)
		assert(Alive.ceiling("deckfeel",{AliveDeckFeel=true},107705084891479,false))
		assert(Alive.ceiling("deckfeel",{AliveDeckFeel=true},96451847774961,true),"Studio")
		assert(not Alive.ceiling("deckfeel",{AliveDeckFeel=true},96451847774961,false),"never on the live place")
		assert(Alive.resolve("deckfeel",nil,nil,true)==true,"missing = on")
		Feel.setSwitch(true);assert(Feel.switch()==true)
		Feel.setSwitch(false);assert(Feel.switch()==false)
		Feel.setSwitch(nil)
	end)

	test("open: 1.25 s to playable, input live at 1.05, phases in the brief's order",function()
		local O=Feel.Open
		assert(O.shade==.20 and O.rise==.38 and O.scan==.12 and O.mark==.2 and O.lit==.15 and O.live==1.05 and O.total==1.25)
		assert(near(O.shade+O.rise+O.scan+O.mark+O.lit,O.live,1e-9),"the phases add up to the live moment")
		assert(near(O.live+O.ballFall+O.squashFor,O.total,1e-9),"the ball drop ends the open")
		assert(Feel.openPhase(0)=="shade"and Feel.openPhase(.3)=="rise"and Feel.openPhase(.6)=="scan"and Feel.openPhase(.8)=="mark")
		assert(Feel.openPhase(1.0)=="lit"and Feel.openPhase(1.1)=="ball"and Feel.openPhase(1.3)==nil)
		assert(O.cue=="deck_boot"and O.cueVolume==.4 and O.markFrame==21 and O.scanColor[1]==118 and O.scanColor[2]==246 and O.scanColor[3]==176)
		assert(Feel.Timing.Cover==.20 and Feel.Timing.Rise==.38 and Feel.Timing.Lit==.15 and Feel.Timing.Drop==O.from)
		assert(Feel.fullBoot(0)and not Feel.fullBoot(1)and not Feel.fullBoot(5),"the full boot sheet only on the session's first open")
	end)

	test("open: the first open after loading waits for the loading screen's handoff (or its absence); .30 sky, .20 pals",function()
		assert(Handoff.clear(false,nil)and Handoff.clear(true,true)and not Handoff.clear(true,nil)and not Handoff.clear(true,false))
		assert(Handoff.Screen=="EggDropLoading"and Handoff.Wait>=25,"never shorter than the loading screen's own 25 s")
		assert(Feel.Handoff.sky==.30 and Feel.Handoff.pals==.20)
		assert(Feel.ReducedOpen.shade==.2 and Feel.ReducedOpen.still==.4)
	end)

	test("open: the rise starts .42 body heights down at .92, overshoots 4 px at most and rests at 1",function()
		local y0,s0=Feel.riseAt(0,300)
		assert(y0==300 and near(s0,.92))
		local low,last=math.huge,300
		for t=0,Feel.Open.rise,.005 do local y,s=Feel.riseAt(t,300);low=math.min(low,y);assert(s>=.92-1e-9 and s<=1+1e-9)end
		assert(low>=-Feel.Open.overshoot-1e-6 and low<=-3,"a 4 px overshoot, no more ("..low..")")
		local y1,s1=Feel.riseAt(Feel.Open.rise,300);assert(y1==0 and near(s1,1))
		local _=last
		assert(Feel.scanAt(0)==0 and near(Feel.scanAt(Feel.Open.scan),1)and Feel.scanAt(.06)>.5,"Quad Out")
	end)

	test("open: panels stagger left column, well, right column, 30 ms apart; 6 px up over .14 s",function()
		local order=Feel.panelOrder({{id="next",x=500,y=10,w=100},{id="score",x=10,y=10,w=100},{id="well",x=200,y=0,w=200},
			{id="goals",x=10,y=120,w=100},{id="pays",x=500,y=300,w=100}},150,450)
		local ids={};for _,row in ipairs(order)do table.insert(ids,row.id)end
		assert(table.concat(ids," ")=="score goals well next pays",table.concat(ids," "))
		assert(order[1].delay==0 and near(order[2].delay,.03)and near(order[5].delay,.12))
		local y,a=Feel.panelAt(0);assert(y==6 and a==1)
		y,a=Feel.panelAt(.14);assert(y==0 and a==0)
	end)

	test("open: the held ball falls 10 px then squashes 1.12 x .88 once, at rest by 1.25",function()
		local dy,sx,sy=Feel.ballDrop(0);assert(dy==-10 and sx==1 and sy==1)
		dy,sx,sy=Feel.ballDrop(Feel.Open.ballFall);assert(dy==0 and near(sx,1.12)and near(sy,.88))
		dy,sx,sy=Feel.ballDrop(Feel.Open.ballFall+Feel.Open.squashFor);assert(dy==0 and sx==1 and sy==1)
		for t=0,.3,.01 do local _,x,y2=Feel.ballDrop(t);assert(x<=1.12+1e-9 and y2>=.88-1e-9)end
	end)

	test("hold: 90 ms minimum, flash .10, drag on above 3 px and off after 120 ms still, stick past .25, wedge order",function()
		assert(Feel.Hold.minHold==.09 and Feel.Hold.flash==.10 and Feel.Hold.down==.06 and Feel.Hold.pressScale==.94)
		assert(near(Feel.releaseAt(1,1.02),1.09)and Feel.releaseAt(1,1.5)==1.5)
		local s={}
		assert(Feel.dragStep(s,2,0)==nil,"3 px or less is still")
		assert(Feel.dragStep(s,-4,0)==-1 and Feel.dragStep(s,0,.1)==-1 and Feel.dragStep(s,0,.13)==nil)
		assert(Feel.dragStep(s,5,.2)==1)
		assert(Feel.stickDirection(.2)==0 and Feel.stickDirection(.3)==1 and Feel.stickDirection(-.9)==-1 and Feel.stickDirection(nil)==0)
		assert(Feel.aimWedge(-1,1,.9)=="Left","held keys first")
		assert(Feel.aimWedge(0,1,-.9)=="Right"and Feel.aimWedge(0,nil,-.9)=="Left"and Feel.aimWedge(0,nil,0)==nil)
		assert(Feel.Hold.haptic.ms==18)
	end)

	test("hold: A presses to .94 in 60 ms and springs back (4.5 Hz, .32) through an overshoot to 1",function()
		assert(Feel.pressScale(0,nil)==1 and near(Feel.pressScale(.06,nil),.94)and near(Feel.pressScale(1,nil),.94))
		assert(near(Feel.pressScale(nil,0),.94))
		local top=0;for t=0,1.5,.005 do top=math.max(top,Feel.pressScale(nil,t))end
		assert(top>1 and top<1.05,"one bouncy overshoot ("..top..")")
		assert(near(Feel.pressScale(nil,3),1,1e-3))
	end)

	test("lean: the brief's offsets, a 3 px cap, x.6 on phones, the pressed half",function()
		local x,y=Lean.target("A",false);assert(x==2 and y==3 or near(math.sqrt(x*x+y*y),3,1e-9),"A is capped to 3 px")
		assert(near(math.sqrt(x*x+y*y),3,1e-9))
		x,y=Lean.target("Left",false);assert(x==-2 and y==2)
		x,y=Lean.target("Right",false);assert(x==1 and y==2)
		x,y=Lean.target("Up",false);assert(x==0 and y==1)
		x,y=Lean.target("B",true);assert(near(x,1.2)and near(y,1.2))
		x,y=Lean.target("nope",false);assert(x==0 and y==0)
		assert(Lean.Side.A=="right"and Lean.Side.B=="right"and Lean.Side.Left=="left"and Lean.Side.Down=="left")
		assert(Lean.Shade==.08 and Lean.Down==.07 and Lean.Frequency==5 and Lean.Damping==.45)
		for _,id in ipairs({"A","B","Left","Right","Up","Down"})do local a,b=Lean.target(id,false);assert(math.sqrt(a*a+b*b)<=3+1e-9)end
	end)

	test("lean: down in 70 ms, back on the spring with one overshoot under 1 px; never stacks",function()
		local l=Lean.new()
		l:press("Left",0,false)
		local x,y,shade=l:step(.07);assert(near(x,-2)and near(y,2)and near(shade,1))
		l:press("A",.08,false);l:press("A",.09,false)
		x,y=l:step(.3);assert(math.sqrt(x*x+y*y)<=3+1e-9,"pressing again never adds")
		l:release("A",.3)
		local over=0
		for t=.3,1.6,.002 do local px,py=l:step(t);if py<0 then over=math.max(over,-py)end;if px<0 then over=math.max(over,-px)end end
		assert(over>0 and over<1,"one small overshoot ("..over..")")
		x,y,shade=l:step(2);assert(x==0 and y==0 and shade==0)
		assert(not l:release("B",3),"a release of another control is ignored")
		l:kick(0,3,4);x,y=l:step(4);assert(near(y,3))
	end)

	test("lean: one writer; a merge wins, a drop adds under the cap; parallax 1 px the other way; RM none, Low shade",function()
		local V=Vector2.new
		local x,y=Lean.compose(V(5,-4),V(2,3),V(0,2));assert(x==5 and y==-4,"a merge jolt wins")
		x,y=Lean.compose(nil,V(2,2),V(0,2));assert(near(math.sqrt(x*x+y*y),3,1e-9),"capped")
		x,y=Lean.compose(nil,nil,V(0,2));assert(x==0 and y==2,"a drop alone is today's kick")
		local px,py=Lean.parallax(2,3);assert(px==-1 and py==-1)
		px,py=Lean.parallax(.4,0);assert(px==0 and py==0)
		local a=Lean.allows(true,false);assert(not a.offset and not a.shade)
		a=Lean.allows(false,true);assert(not a.offset and a.shade)
		a=Lean.allows(false,false);assert(a.offset and a.shade)
	end)

	test("life: drift a cell per 16 s on the 15 Hz step, merge jumps, breath, blinks 4-6 s, marches",function()
		assert(Feel.patternOffset(0,23,46)==0 and Feel.patternOffset(16,23,46)==23 and Feel.patternOffset(32,23,46)==0)
		assert(Feel.patternOffset(1/30,23,46)==0,"quantised to the 15 Hz step")
		assert(Feel.patternOffset(0,24,48,1)==3,"a merge jumps 1/8 cell")
		assert(near(Feel.breath(.6),1,1e-9)and near(Feel.breath(0),0))
		local blinks,last,gaps,inBlink=0,nil,{},false
		for t=0,60,1/30 do
			local b=Feel.blinkAt(t)
			if b and not inBlink then blinks+=1;if last then table.insert(gaps,t-last)end;last=t end
			inBlink=b
		end
		assert(blinks>=10 and blinks<=15,"blinks "..blinks)
		for _,g in ipairs(gaps)do assert(g>=4-.05 and g<=6+.1,"gap "..g)end
		assert(near(Feel.aimPhase(.3),.5)and near(Feel.aimPhase(.6),0))
		assert(near(Feel.dashOffset(.5,10,false),-4)and near(Feel.dashOffset(.5,10,true),-8))
		for t=0,3,.07 do local o=Feel.dashOffset(t,10,false);assert(o<=0 and o>-10)end
	end)

	test("life: the near colour eases to coral (no flashing); lane, border, glow, dust; RM keeps border and lane",function()
		assert(Feel.nearAmount(0)==0 and Feel.nearAmount(1)==1 and Feel.nearAmount(.2)==0)
		local r,g,b=Feel.lineColor(0);assert(r==1 and g==1 and b==1)
		r,g,b=Feel.lineColor(1);assert(near(r,1)and near(g,120/255)and near(b,96/255))
		assert(Feel.Life.near.maxHz<=2)
		assert(near(Feel.laneAt(0),.04)and Feel.laneAt(.25)==0)
		assert(Feel.borderAt(0)==1 and Feel.borderAt(.2)==0)
		assert(Feel.glowAt(0,2)==0 and near(Feel.glowAt(0,3),.3)and Feel.glowAt(1.2,5)==0)
		local x,y,a=Feel.dustAt(1,0);assert(x==0 and y==0 and a==1)
		x,y,a=Feel.dustAt(3,.09);assert(x>0 and y<0 and a>0)
		assert(select(3,Feel.dustAt(2,.18))==0)
		assert(Feel.lifeAllows("border",true)and Feel.lifeAllows("lane",true))
		for _,f in ipairs({"drift","breath","blink","march","dashes","dust","glow"})do assert(not Feel.lifeAllows(f,true)and Feel.lifeAllows(f,false))end
		assert(Feel.Life.maxTweens==4 and Feel.Life.step==1/15)
	end)

	test("fresh (always on): an old serial's frame never shows; a resumed round comes in by row, bottom up",function()
		assert(Fresh.labelVisible(4,4)and not Fresh.labelVisible(3,4)and not Fresh.labelVisible(nil,4))
		local s=Fresh.new();assert(not Fresh.keep(s,1))
		Fresh.drew(s,1);assert(Fresh.keep(s,1)and not Fresh.keep(s,2),"the next round hides the last frame")
		Fresh.forget(s);assert(not Fresh.keep(s,1),"closed under the shade: drawn fresh on reopen")
		assert(Fresh.rowDelay(0,1)==0 and near(Fresh.rowDelay(2.5,1),.08)and Fresh.rowDelay(40,1)==.3)
		assert(Fresh.rowShown(0,1,0)and not Fresh.rowShown(3.2,1,.1)and Fresh.rowShown(3.2,1,.12))
		assert(Fresh.arrival(0)=="fresh"and Fresh.arrival(3)=="resume")
	end)

	test("stepper: live while untouched; tap wraps, keys stop; one pop; tints; the picker's two cases",function()
		assert(Feel.stepperLive(0,false,false,false)and not Feel.stepperLive(1,false,false)and not Feel.stepperLive(0,true,false)
			and not Feel.stepperLive(0,false,true)and not Feel.stepperLive(0,false,false,true))
		local order={"easy","medium","hard"}
		assert(Feel.stepLevel(order,"easy",1,true)=="medium"and Feel.stepLevel(order,"hard",1,true)=="easy")
		assert(Feel.stepLevel(order,"hard",1,false)=="hard"and Feel.stepLevel(order,"easy",-1,false)=="easy"and Feel.stepLevel(order,"medium",-1,false)=="easy")
		assert(Feel.stepperPop(-.1)==1 and near(Feel.stepperPop(.14),1.08)and Feel.stepperPop(.28)==1)
		local r,g,b=Feel.levelTint("Easy");assert(r==95 and g==227 and b==154)
		r=Feel.levelTint("hard");assert(r==255)
		assert(Feel.levelTint("nope")==nil)
		assert(Feel.pickerWanted(true,false)and Feel.pickerWanted(false,true)and not Feel.pickerWanted(false,false))
	end)

	test("polish: radius 18 (12 compact), pill 14/12 inset, 24 tall, 10 pad; the shift never passes the foot",function()
		assert(Feel.cardRadius(false)==18 and Feel.cardRadius(true)==12)
		local p=Feel.pillRect(40,false);assert(p.x==14 and p.y==12 and p.h==24 and p.w==60 and p.labelX==24 and p.radius==8 and p.lip==2)
		p=Feel.pillRect(40,false,60);assert(p.y==18,"a one-row card keeps its vertical centre")
		p=Feel.pillRect(40,false,nil,60);assert(p.y==12 and p.h==24,"room for the full pill")
		p=Feel.pillRect(40,false,nil,32);assert(p.y==12 and p.h==18,"shrinks to keep 2 px clear of the content")
		p=Feel.pillRect(40,true,nil,21);assert(p.h==16 and p.y==4,"a tight phone card: 16 tall, moved up to 4 px in")
		assert(Feel.contentShift(36,30,80,120,false)==18,"12 under the pill")
		assert(Feel.contentShift(36,30,110,120,false)==4,"never past the foot")
		assert(Feel.contentShift(36,60,80,120,false)==0)
		assert(Feel.punchAt(0)==1 and near(Feel.punchAt(.08),1.14)and Feel.punchAt(.16)==1)
		assert(near(Feel.tickAt(0),2)and Feel.tickAt(.25)==0)
		assert(Feel.dotPop(0,1)==1 and near(Feel.dotPop(.08,1),1.3)and Feel.dotPop(.08,3)==1)
		assert(near(Feel.bobAt(.6,1),1)and near(Feel.bobAt(.6,2),-1),"half a beat apart")
		assert(Feel.Polish.highlight==.86 and Feel.Polish.stroke==.82 and Feel.Polish.wellRadius==12)
	end)

	test("results: kinds; opening cues (a win slams, so close whooshes, a loss hushes; never `lose`)",function()
		assert(Feel.resultKind("clear",2)=="win"and Feel.resultKind("overflow",1)=="close"and Feel.resultKind("missed",0)=="loss")
		local function cues(kind)local out={};for _,c in ipairs(Feel.openingCues(kind))do out[c[1]]=c[3]end;return out end
		local w=cues("win");assert(w.win==.5 and w.tag_slam==.5)
		local c=cues("close");assert(c.streak_whoosh==.35 and not c.win)
		local l=cues("loss");assert(l.reveal_hush and l.meter_fill and not l.lose)
		for _,kind in ipairs({"win","close","loss"})do for _,cue in ipairs(Feel.openingCues(kind))do assert(cue[1]~="lose")end end
	end)

	test("results: beats .15 goals (+.06 pitch), .30 rows .12 apart, 1.7 new best; the clock's spec",function()
		local beats=Feel.resultBeats(2,3,true)
		assert(#beats==6)
		assert(beats[1].cue=="goal_tick"and near(beats[1].at,.15)and near(beats[2].at,.24)and near(beats[2].pitch,1.06))
		assert(beats[3].cue=="row_flip"and near(beats[3].at,.30)and near(beats[5].at,.54)and beats[3].volume==.3)
		assert(beats[6].cue=="new_best"and near(beats[6].at,1.7))
		assert(#Feel.resultBeats(0,0,false)==0)
		local spec=Feel.recapSpec()
		assert(spec.dropAt==.6 and spec.countStart==.6 and near(spec.countSpan,.9)and spec.finaleAt==1.5 and spec.banks==false)
		assert(Feel.blipPitch(1,10)==1 and near(Feel.blipPitch(10,10),1.5)and Feel.blipPitch(1,1)==1)
		assert(Feel.starPulse(5,0)==1.04 and Feel.starPulse(4,0)==1 and Feel.starPulse(10,.1)==1)
	end)

	test("results: headline 1.6 -> 1 and -4 -> 0 in .22; stamps 1.4 with a wobble; rows; Star squash; punch; buttons by 1.9",function()
		local s,r=Feel.headlineAt(0);assert(near(s,1.6)and near(r,-4))
		s,r=Feel.headlineAt(.22);assert(near(s,1)and near(r,0))
		local st,rot,shown=Feel.stampAt(-.01);assert(not shown and st==1.4)
		st,rot,shown=Feel.stampAt(.14);assert(shown and near(st,1)and near(rot,0,1e-9))
		local wob=0;for t=0,.14,.005 do wob=math.max(wob,math.abs(select(2,Feel.stampAt(t))))end;assert(wob<=3)
		assert(select(2,Feel.rowAt(-.1))==false and near(Feel.rowAt(.14),1))
		local sx,sy=Feel.starLand(0);assert(near(sx,1.14)and near(sy,.86))
		sx,sy=Feel.starLand(.2);assert(sx==1 and sy==1)
		assert(near(Feel.totalPunch(.1),1.25)and Feel.totalPunch(.2)==1)
		assert(Feel.buttonsAt(0)==8 and Feel.buttonsAt(1.9)==8 and Feel.buttonsAt(1.9+.16)==0,"Replay never later than 1.9")
		assert(Feel.Results.buttonsAt<=1.9)
	end)

	test("results: the burst (12, 6 so close), confetti for a win only, no slam or burst under Reduced Motion",function()
		local x,y,a=Feel.burstAt(1,12,0,40);assert(x==0 and y==0 and a==1)
		x,y,a=Feel.burstAt(1,12,Feel.Results.burstLife-.01,40);assert(x>35 and a<.05)
		assert(select(3,Feel.burstAt(1,12,1,40))==0)
		local w=Feel.resultLook("win",false);assert(w.confetti and w.burst==12 and w.rays==1 and w.bounce)
		local c=Feel.resultLook("close",false);assert(not c.confetti and c.burst==6 and c.rays==.5 and not c.bounce)
		local l=Feel.resultLook("loss",false);assert(not l.confetti and l.burst==0 and l.rays==0)
		local rm=Feel.resultLook("win",true);assert(not rm.slam and rm.burst==0 and not rm.confetti and not rm.bounce)
	end)
	-- Beta 41 code review: the jolt's rebase and the touch holds.
	test("beta 41 review: a rebase puts a node the jolt last wrote back at its base; a moved node takes its new place",function()
		-- a small UDim2 (offsets only) for the offline run; Studio has its own
		local saved=UDim2
		local meta={}
		local function make(x,y)return setmetatable({x=x,y=y},meta)end
		meta.__add=function(a,b)return make(a.x+b.x,a.y+b.y)end
		meta.__eq=function(a,b)return a.x==b.x and a.y==b.y end
		local fake={fromOffset=make,new=function(_,x,_,y)return make(x or 0,y or 0)end}
		local ok,problem=pcall(function()
			UDim2=fake
			local Jolt=require(client.DeckMergeJolt)
			local kept={Position=make(10,20),Parent=true}
			local moved={Position=make(30,40),Parent=true}
			local j=Jolt.new({kept,moved})
			j:setOwner(true,1,false)
			assert(j:emit(1,1,4,1,false,0));j:update(.03)
			local w=j.written
			assert(w and(w.X~=0 or w.Y~=0)and kept.Position==make(10+w.X,20+w.Y),"mid-jolt: offset")
			moved.Position=make(50,60) -- a layout moved this one
			j:rebase()
			assert(kept.Position==make(10,20)and j.nodes[1].base==make(10,20),"back at its rest, never left offset")
			assert(j.nodes[2].base==make(50,60)and moved.Position==make(50,60),"the moved one rebases where it is")
			assert(j.active==nil and j.written==nil)
		end)
		UDim2=saved
		assert(ok,problem)
	end)
	test("beta 41 review: a touch hold lets go when its touch ends anywhere, and every hold goes when the deck closes",function()
		local t=Feel.touches()
		local one,two={},{}
		t:down(one,"A");t:down(two,"Left")
		assert(t:holding("A")and t:holding("Left"))
		assert(t:up(one)=="A"and t:up(one)==nil,"ended off the key: A goes once")
		assert(not t:holding("A")and t:holding("Left"))
		t:down(one,"B")
		local all=t:clear()
		assert(#all==2 and all[1]=="B"and all[2]=="Left"and not t:holding("Left")and t:up(two)==nil,"closing: every one, then none")
		-- the view: every hold still down goes up (A, its lean)
		local View=require(client.DeckFeelScreen)
		local log={}
		local screen={buttons={},pressButton=function(_,id,down)table.insert(log,id..(if down then "+"else "-"))end,
			pressDpad=function(_,id,down)table.insert(log,id..(if down then "+"else "-"))end}
		local v=setmetatable({screen=screen,holds={},lean=Lean.new(),springs={},runners={}},View)
		v:hold("A",true,0);v:hold("Left",true,0)
		assert(v:isDown("A")and v:isDown("Left")and v.lean.id=="Left")
		local let=v:releaseAll(1)
		assert(#let==2 and let[1]=="A"and let[2]=="Left","both let go")
		assert(not v:isDown("A")and not v:isDown("Left")and v.lean.id==nil,"no key down, no lean")
		assert(table.find(log,"A-")and table.find(log,"Left-"))
		assert(#v:releaseAll(2)==0,"nothing held: nothing")
	end)
	test("beta 42 note 10 (C10): a moved NEXT ball bobs about its new rest; rebase hands back the old rest",function()
		local View=require(client.DeckFeelScreen)
		local v=setmetatable({screen={},holds={},springs={},runners={}},View)
		assert(v:rebase(1,"calm")==nil,"no HUD built yet: nothing")
		v.nextBase={"build","second"};v.bob={1,0}
		assert(v:rebase(1,"calm")=="build","the HUD-build rest comes back")
		assert(v.nextBase[1]=="calm"and v.nextBase[2]=="second","only that ball moves")
		assert(v.bob[1]==nil and v.bob[2]==0,"its bob is rewritten on the next frame")
		assert(v:rebase(1,"build")=="calm"and v.nextBase[1]=="build","restoreCalm puts it back")
	end)
	return{passed=#cases,cases=cases}
end
