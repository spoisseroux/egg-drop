-- The gift chain's art (artifacts/qa-2026-11-27-beta37/GIFT-ART-BRIEF.md): GiftArt's pure rules. The kit (no Stars
-- gold outside the Peek's Stars chip), the wrapped egg's proportions, the chip's bob, wiggle, pop and distance, the
-- ribbon's layout, sway and untie, the card's entrance and buttons, the paint wipe's schedule, sweep and duplicate,
-- the nest Peek's schedule and silhouettes, and Reduced Motion as the brief writes it.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.GiftArt)(ServerScriptService.Server)
-- Offline: python scripts/run_dash_server_specs.py
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local A=require(Shared.GiftArt)
	local Hue=require(Shared.HueCatalog)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function near(a,b,e)return math.abs(a-b)<=(e or 1e-6)end
	local function hexOf(c)return string.format("#%02X%02X%02X",math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5))end
	local function luminance(c)
		local function lin(x)return if x<=.03928 then x/12.92 else((x+.055)/1.055)^2.4 end
		return .2126*lin(c.R)+.7152*lin(c.G)+.0722*lin(c.B)
	end
	local function contrast(a,b)
		local la,lb=luminance(a),luminance(b)
		return(math.max(la,lb)+.05)/(math.min(la,lb)+.05)
	end

	test("the kit, hex for hex; the pots are HueCatalog's; gold is never a gift colour",function()
		assert(A.Hex.ink=="#1B2A4A"and A.Hex.pink=="#FF6FA8"and A.Hex.deep=="#D8327E"and A.Hex.light=="#FFD3E6")
		assert(A.GlassTransparency==.15,"glass is white at 85%")
		for id,hex in pairs(A.PotHex)do
			assert(Hue.ById[id]and hexOf(Hue.ById[id].color)==hex,id.." is the catalogue's colour")
		end
		for _,h in ipairs(Hue.Order)do assert(A.PotHex[h.id],h.id.." has a pot colour")end
		for _,kind in ipairs({"paint","toy"})do
			for _,pot in ipairs({"rose","tide","citrus","iris",nil})do
				local fill=A.button(kind,pot)
				assert(fill~=A.Hex.gold and A.accent(kind,pot)~=A.Hex.gold,"no Stars gold on the card")
			end
		end
	end)

	test("the wrapped egg: .78 x 1, the bands meet 42% down, the bow on the meet, the glint upper left; 36, 44 and 28 px",function()
		assert(A.EggSizes.chip==36 and A.EggSizes.pill==44 and A.EggSizes.tag==28)
		for _,height in ipairs({36,44,28,26})do
			local L=A.eggLayout(height)
			assert(near(L.w,height*.78)and near(L.h,height))
			assert(near(L.bandDown.w,L.w*.22)and near(L.bandAcross.h,height*.18))
			assert(near(L.bandAcross.y,height*.42)and near(L.knot.y,L.bandAcross.y),"the knot where the bands meet")
			assert(L.loopL.x<L.knot.x and L.loopR.x>L.knot.x and L.loopL.rot==-28 and L.loopR.rot==28,"two loops either side, +-28")
			assert(near(L.loopL.w,L.w*.30),"the loops are 30% of the width")
			assert(L.glint.x<L.w/2 and L.glint.y<L.knot.y and L.glint.w==2,"a 2 px bar upper left")
			assert(L.dot.x>L.glint.x and L.dot.y>L.glint.y,"the dot below right of the bar")
			for _,key in ipairs({"bandDown","bandAcross","loopL","loopR","knot","glint","dot"})do
				local p=L[key]
				assert(p.x-p.w/2>=-L.w*.05 and p.x+p.w/2<=L.w*1.05 and p.y-p.h/2>=-1 and p.y+p.h/2<=L.h+1,key.." inside the egg's box")
			end
		end
	end)

	test("the chip: a 3 px bob on 2.4 s, the bow wiggles +-10 once every 6 s for .3 s, a new cycle glints",function()
		local high,low=0,0
		for i=0,240 do
			local s=A.chip(i/100,nil,30,false)
			high=math.max(high,s.y);low=math.min(low,s.y)
		end
		assert(near(high,3,.01)and near(low,-3,.01),"3 px each way")
		assert(near(A.chip(0,nil,30,false).y,A.chip(2.4,nil,30,false).y,1e-6),"a 2.4 s period")
		local peak=0
		for i=0,30 do peak=math.max(peak,math.abs(A.chip(6+i/100,nil,30,false).bow))end
		assert(near(peak,10,.1),"+-10 degrees")
		assert(A.chip(6.4,nil,30,false).bow==0 and A.chip(11.9,nil,30,false).bow==0,"still between wiggles")
		assert(A.chip(5.9,nil,30,false).cycle==0 and A.chip(6.0,nil,30,false).cycle==1,"each 6 s is a new glint")
		local r=A.chip(1.3,nil,30,true)
		assert(r.y==0 and r.bow==0 and r.cycle==-1,"Reduced Motion: no bob, wiggle or glint")
	end)

	test("the chip parks: 0, 1.15, 1.0 in .25 s; 1.15 within 10 studs; 60% alpha beyond 60",function()
		assert(A.chip(0,0,30,false).scale==0)
		assert(near(A.chip(0,.15,30,false).scale,1.15,1e-6),"1.15 at 60%")
		assert(A.chip(0,.25,30,false).scale==1 and A.chip(0,nil,30,false).scale==1)
		assert(near(A.chip(0,nil,8,false).scale,1.15),"close: 1.15")
		assert(A.chip(0,nil,20,false).scale==1 and A.chip(0,nil,20,false).alpha==1)
		assert(near(A.chip(0,nil,70,false).alpha,.6),"far: 60%")
		assert(near(A.chip(0,nil,nil,false).alpha,1),"no player: as near")
	end)

	test("the ribbon: across the dial at 30 degrees, the bow at its upper right, the tag under the bow, tails either side",function()
		local L=A.ribbonLayout(1.7)
		assert(L.sash.angle==30 and near(L.sash.length,1.7+2*A.Ribbon.sash.margin),"the sash crosses the dial")
		assert(L.bow.X>0 and L.bow.Y>0 and L.bow.Z>L.sash.at.Z,"the bow sits on the sash's upper right, in front of it")
		assert(L.tag.Y<L.bow.Y and near(L.tag.X,L.bow.X),"the tag hangs under the bow")
		assert(L.loops[1].at.X<L.bow.X and L.loops[2].at.X>L.bow.X,"two loops")
		assert(L.tails[1].at.Y<L.bow.Y and L.tails[2].at.Y<L.bow.Y and L.tails[1].at.X<L.tails[2].at.X,"two tails below the knot")
		assert(A.Ribbon.sash.w==.22 and A.Ribbon.sash.thick==.05 and A.Ribbon.bow.loop==.5 and A.Ribbon.bow.knot==.18 and A.Ribbon.bow.tail==.45)
		assert(A.Ribbon.tag.w==92 and A.Ribbon.tag.h==30 and A.Ribbon.tag.maxDistance==60)
	end)

	test("the ribbon sways +-6 on 3 s, glints every 5 s; the untie: .2 s bow, .4 s slide 1.5 studs and fade; RM a .15 fade",function()
		local peak=0
		for i=0,300 do peak=math.max(peak,math.abs(A.ribbon(i/100,nil,false).sway))end
		assert(near(peak,6,.01))
		assert(A.ribbon(0.1,nil,false).glint~=nil and A.ribbon(1,nil,false).glint==nil and A.ribbon(5.1,nil,false).glint~=nil,"every 5 s")
		local s=A.ribbon(3,.1,false)
		assert(near(s.open,.5)and s.fall==0 and s.alpha==1 and s.glint==nil,"the bow unties first")
		s=A.ribbon(3,.6,false)
		assert(near(s.fall,1.5)and near(s.alpha,0)and s.done,"then it falls 1.5 studs and fades")
		assert(not A.ribbon(3,.5,false).done)
		local r=A.ribbon(3,nil,true)
		assert(r.sway==0 and r.glint==nil,"RM: no sway or glint")
		r=A.ribbon(3,.075,true)
		assert(near(r.alpha,.5)and r.fall==0 and r.open==0,"RM: the untie is a fade")
		assert(A.ribbon(3,.15,true).done)
		assert(A.RibbonCue.sound=="blanket_rustle"and A.RibbonCue.speed==1.3 and A.RibbonCue.buzz=="machine_light")
	end)

	test("the card's entrance (.9 s): the pop .85, 1.05, 1.0 in .3; sash at .15; the pot lands at .35 and squashes 10%",function()
		assert(near(A.card(0,false).scale,.85)and near(A.card(.18,false).scale,1.05)and A.card(.3,false).scale==1)
		assert(A.card(.15,false).sash==0 and A.card(.35,false).sash==1,"the sash draws in .2 s from .15")
		assert(A.card(.1,false).bow==0 and near(A.card(.35,false).bow,1),"the bow ties with it")
		assert(A.card(.1,false).potAlpha==0,"no pot before .2")
		assert(near(A.card(.2,false).potY,-30)and near(A.card(.35,false).potY,0),"falls 30 px to land at .35")
		local squash=1
		for i=35,50 do squash=math.min(squash,A.card(i/100,false).potSquash)end
		assert(near(squash,.9,.005),"squashes 10%")
		assert(A.card(.59,false).tag==-14 and near(A.card(.9,false).tag,-4),"the tag swings -14 to -4 from .6")
		assert(A.card(.89,false).buttons==false and A.card(.9,false).buttons==true,"buttons at .9")
		local at={}
		for _,cue in ipairs(A.CardCues)do at[cue.sound]=cue.at end
		assert(at.screen_rise==0 and at.blanket_rustle==.15 and at.egg_tok_1==.35 and at.rarity_common==.5)
		local burst=A.due(A.CardCues,.45,.55)
		assert(#burst==1 and burst[1].buzz=="pop"and burst[1].confetti and burst[1].sweep)
		assert(#A.due(A.CardCues,-1,0)==1,"the first frame plays the rise")
		local r=A.card(.075,true)
		assert(near(r.alpha,.5)and r.scale==1 and r.tag==-4 and not r.buttons,"RM: a .15 s fade")
		assert(A.card(.15,true).buttons)
	end)

	test("the card's buttons: the pot's colour (ink on rose and citrus, white on tide and iris), a toy pink",function()
		local function check(pot,label)
			local fill,ink=A.button("paint",pot)
			assert(fill==A.PotHex[pot]and ink==label,pot)
			-- 20 px ExtraBold is large text: AA large (3:1)
			assert(contrast(Color3.fromHex(fill),Color3.fromHex(ink))>=3,pot.." label reads")
		end
		check("rose",A.Hex.ink);check("citrus",A.Hex.ink);check("tide",A.Hex.white);check("iris",A.Hex.white)
		local fill,ink=A.button("toy","ball")
		assert(fill==A.Hex.pink and ink==A.Hex.ink)
		assert(A.accent("paint","tide")==A.PotHex.tide and A.accent("toy")==A.Hex.pink)
		for i=1,12 do assert(typeof(A.confetti(i,A.PotHex.rose))=="Color3")end
		assert(A.Card.confetti==12 and A.Card.bubbles==6 and A.Card.w==340 and A.Card.h==300)
		local p,s=A.arc(0,Vector2.new(0,0),Vector2.new(100,0))
		assert(near(p.X,0)and near(s,1))
		p,s=A.arc(1,Vector2.new(0,0),Vector2.new(100,0))
		assert(near(p.X,100)and near(p.Y,0)and near(s,A.Card.arcScale))
		p=A.arc(.5,Vector2.new(0,0),Vector2.new(100,0))
		assert(p.Y<0,"the arc lifts")
	end)

	test("the paint wipe's schedule: pour, land at .25, sweep .4 to 1.0 (Quad in-out), ring at 1.0, shake, paws, spin",function()
		local s=A.wipe(.1,false,false)
		assert(s.pot.shown and s.headPitch<0 and s.eye>1,"the pot over the pet; it looks up, eyes wide")
		local squash=0
		for i=25,40 do squash=math.max(squash,A.wipe(i/100,false,false).squash)end
		assert(squash>.95,"the squash at the landing")
		assert(A.wipe(.4,false,false).sweep==0 and near(A.wipe(.7,false,false).sweep,.5)and A.wipe(1.0,false,false).sweep==1)
		assert(A.wipe(.55,false,false).sweep<.25,"in-out: slow at first")
		assert(A.wipe(.99,false,false).ring==nil and A.wipe(1.1,false,false).ring~=nil and A.wipe(1.41,false,false).ring==nil,"the ring fades in .4")
		assert(near(A.wipe(1.25,false,false).ring.size,3),"3 studs")
		local roll=0
		for i=105,145 do roll=math.max(roll,math.abs(A.wipe(i/100,false,false).roll))end
		assert(roll>math.rad(9)and roll<=math.rad(14),"the shake, damped from 14 degrees")
		assert(A.wipe(1.1,false,false).beads~=nil and A.wipe(1.6,false,false).beads==nil)
		assert(math.abs(A.wipe(1.5,false,false).headYaw)>0,"it looks at each paw")
		local hop=0
		for i=162,180 do hop=math.max(hop,A.wipe(i/100,false,false).hop)end
		assert(hop>.5,"the jump-spin")
		assert(not A.wipe(1.79,false,false).done and A.wipe(1.8,false,false).done)
		local at={}
		for _,cue in ipairs(A.WipeCues)do at[cue.sound]=cue end
		assert(at.snack_sniff.at==0 and at.merge_jelly.at==.25 and at.merge_jelly.buzz=="crack1")
		assert(at.shimmer_loop.speed==.9 and at.shimmer_loop.toSpeed==1.3 and at.shimmer_loop.buzz=="creak")
		assert(at.merge_bubble.speed==1.12 and at.shell_scatter.buzz=="settle"and at.snack_happy_squeak.buzz=="pop")
	end)

	test("the wipe: a duplicate pot runs at 60% length; Reduced Motion a .4 s cross-fade with the ring",function()
		assert(near(A.wipeLength(false,false),1.8)and near(A.wipeLength(true,false),1.08)and A.wipeLength(false,true)==.4)
		assert(near(A.wipe(.42,true,false).sweep,A.wipe(.7,false,false).sweep),"the same sweep at 60%")
		assert(A.wipe(1.08,true,false).done and not A.wipe(1.0,true,false).done)
		local r=A.wipe(.2,false,true)
		assert(near(r.sweep,.5)and r.ring~=nil and r.roll==0 and r.hop==0 and r.spin==0 and not r.pot.shown,"RM: no motion")
		assert(A.wipe(.4,false,true).done)
		assert(#A.WipeReducedCues==1 and A.WipeReducedCues[1].buzz=="settle")
	end)

	test("the sweep, crown to feet: final above the edge band, the bright edge, the old below; the edge halfway to white",function()
		assert(A.sweepState(0,.2,0)=="old"and A.sweepState(.8,1,0)=="old")
		assert(A.sweepState(0,.2,1)=="new"and A.sweepState(.8,1,1)=="new")
		assert(A.sweepState(0,.2,.5)=="new"and A.sweepState(.8,1,.5)=="old")
		local seen={}
		for i=0,100 do seen[A.sweepState(.4,.6,i/100)]=true end
		assert(seen.old and seen.edge and seen.new,"a piece goes old, edge, new")
		local last="old"
		local order={old=0,edge=1,new=2}
		for i=0,100 do
			local s=A.sweepState(.3,.5,i/100)
			assert(order[s]>=order[last],"it never goes back");last=s
		end
		local e=A.edgeColor(Color3.fromHex("#008DFF"))
		assert(near(e.R,.5,.01)and near(e.B,1,.01),"halfway to white")
		local count=0
		for i=1,6 do if A.drip(i,6,.4,1.5)then count+=1 end end
		assert(count>0 and A.drip(1,6,0,1.5)==nil and A.drip(1,6,1,1.5)==nil,"drips only during the sweep")
		local _,share=A.drip(2,6,.3,1.5)
		assert(share>.3*(1+A.Wipe.sweep.band),"ahead of the front")
	end)

	test("the Peek (2.4 s): three smaller rocks, the crack at .6, the disc at .8, closing at 1.9; the Bear gasps",function()
		local peaks={0,0,0}
		for i=0,59 do
			local t=i/100
			local k=math.floor(t/.2)+1
			peaks[k]=math.max(peaks[k],math.abs(A.peek(t,false).rock))
		end
		assert(peaks[1]>peaks[2]and peaks[2]>peaks[3]and peaks[1]<=6,"each rock smaller")
		assert(A.peek(.59,false).crack==0 and A.peek(.8,false).crack==1,"the crack opens at .6")
		assert(A.peek(.79,false).disc==0 and A.peek(1.2,false).disc==1 and A.peek(1.2,false).discScale==1,"the disc at .8")
		assert(A.peek(1.5,false).q~=0,"the ? bobs")
		assert(A.peek(2.2,false).crack==0 and A.peek(2.2,false).disc==0,"closed by 2.2")
		assert(A.peek(.4,false).lean>.9,"the Bear leans in")
		assert(A.peek(1.3,false).back>.39 and A.peek(1.3,false).paws==1,"hops back .4, paws up")
		assert(A.peek(2.4,false).done and not A.peek(2.3,false).done)
		assert(A.Peek.prompt==3,"the prompt is off for 3 s")
		local at={}
		for _,cue in ipairs(A.PeekCues)do at[cue.sound]=cue end
		assert(at.egg_wobble.at==0 and at.egg_tok_1.at<at.egg_tok_2.at and at.egg_tok_2.at<.6)
		assert(at.egg_crack_glint.at==.6 and at.egg_crack_glint.buzz=="crack1"and at.reveal_shimmer.volume==.3)
		assert(at.reveal_hush.at==.8 and at.bear_boop.speed==1.2 and at.bear_boop.gasp)
		assert(at.blanket_rustle.at==1.9 and at.blanket_rustle.pill and at.pet_coo_1.speed==.85)
		assert(#A.crackPoints()==A.Peek.crack.points+1 and near(A.crackPoints()[1].X,-.45)and near(A.crackPoints()[7].X,.45),".9 across")
		assert(A.shaft(1)==-20 and A.shaft(4)==20,"four shafts fan 40 degrees")
	end)

	test("the Peek under Reduced Motion: light and disc fade in .2, hold 1.6, fade .2; no rock, shafts, bob or gasp",function()
		local r=A.peek(.1,true)
		assert(near(r.light,.5)and near(r.disc,.5)and r.rock==0 and r.shafts==0 and r.q==0 and r.back==0 and r.hop==0)
		assert(A.peek(1,true).disc==1 and near(A.peek(1.9,true).disc,.5)and A.peek(2.0,true).done)
		assert(near(A.peekLength(true),2.0)and A.peekLength(false)==2.4)
		assert(A.PeekReducedCues==A.PeekCues,"the sounds and buzzes stay")
	end)

	test("the silhouettes: the gift's real kind (hat, neck, toy, charm, stars), ink shapes inside the disc; unknown is Stars",function()
		local seen={}
		for _,kind in ipairs(A.SilhouetteKinds)do
			local shapes=A.silhouette(kind)
			assert(#shapes>=2,kind)
			local inks=0
			for _,s in ipairs(shapes)do
				assert(s.shape=="round"or s.shape=="rect"or s.shape=="ring",kind)
				assert(s.tone=="ink"or s.tone=="paper",kind)
				if s.tone=="ink"then inks+=1 end
				local a=math.rad(s.rot)
				local rx=(math.abs(math.cos(a))*s.w+math.abs(math.sin(a))*s.h)/2
				local ry=(math.abs(math.sin(a))*s.w+math.abs(math.cos(a))*s.h)/2
				assert(s.x-rx>=.08 and s.x+rx<=.92 and s.y-ry>=.08 and s.y+ry<=.92,kind.." inside the disc")
			end
			assert(inks>=1,kind.." has ink")
			local key=""
			for _,s in ipairs(shapes)do key..=s.shape..s.x..s.y..s.w end
			assert(not seen[key],kind.." is its own shape");seen[key]=true
		end
		assert(A.silhouette("pet")==A.silhouette("stars")and A.silhouette(nil)==A.Silhouettes.stars,"never a pet")
		assert(A.Peek.disc.size==72 and A.Peek.disc.q==34 and A.Peek.disc.bob==2)
	end)

	return {passed=#cases,cases=cases}
end
