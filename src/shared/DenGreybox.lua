-- The Play Den greybox (PLAY-DEN-BUILD-PLAN.md, step A): the sign under the lintel, four lanterns (the whole light budget),
-- the notice board on the apron, and each bay's object by its kind: the Garden Dash gate (two posts, bunting, a chalk
-- slate, paw stones), the Pocket Deck table (a stump, the Deck propped on it with its screen lit, stools) and a roped
-- niche (a crate under a dust sheet). Pure rows for GreyboxRows.build, from a DenLayout layout. Names "W7D_" so the
-- camera clamp (CameraClamp.isWorld) stops on them. Matte wood and stone; the bunting, the Deck's screen and the lamps
-- are the only bright things. In the pocket only the posts and the stump collide (architect); in the room the crates and
-- stools do too. Pets are kept off all of it by DenLayout.footprints.
local Layout=require(script.Parent.DenLayout)
local Greybox={}
Greybox.Prefix="W7D_"
Greybox.Look=table.freeze({wood="#7A5A3A",dark="#5C4330",stone="#8E8A80",cloth="#B8AE98",rope="#B79A66",slate="#3A3F3A",
	lamp="#D98A3A",screen="#9BE3C9",red="#D9725E",yellow="#E8C468",earth="#815C3F",pawStone="#A39684"})
-- Fable cliff-den review (FABLE-REVIEW-CLIFF-DEN.md), the room only: a timber frame over the old marble mouth (lintel,
-- jambs, a dirt threshold over the white sill), the mouth lanterns hung from the beam's ends (no posts), the sign on the
-- beam, a mat mid-room, the apron slab joining the mouth and the cliff path's foot. Lamps #D98A3A with caps and bases.
Greybox.Frame=table.freeze({beamY=10.5,beam=Vector3.new(17.5,1.3,1.2),out=2.5,jamb=1.5,cord=.8,tilt=8})
-- top 4.95 (Fable asked 4.65, lawn + .05): the drawn lawn by the mouth stands up to about 4.9 over its 4.2 to 4.6 collision,
-- so at 4.65 the slab showed only as a frame round the grass (Studio R3).
Greybox.Apron=table.freeze({x1=-25,x2=3,z1=-100,z2=-90,top=4.95,thick=.6})
Greybox.Mat=table.freeze({at=Vector2.new(-8,-108),d=8,inner=6.4})
local L=Greybox.Look
Greybox.MaxParts=120 -- round 6: the Garden Dash gate's banner, bulbs, pennant and start mat (was 80)
-- Round 6 (Spencer, beta 25: "the race entrance in the cave thing needs to be clearer / the model / it kinda belnds in";
-- Fable DEN-ROUND6-LOOK.md section 4): the room's only saturated object. Painted timber: teal posts with cream bands, a
-- banner of cream and charcoal checks, seven warm bulbs and one light, a coral swallow-tail pennant, a "Garden Dash"
-- board, a checker start mat and a line of paw stones toward the room. Fable's size is 9 x 9 clear; it shrinks to the
-- bay's width and roof (CliffDenData den.bays) so it always fits under the dome, and grows with the room.
Greybox.Gate=table.freeze({clear=9,clearH=9,post=1,beam=.6,band=1.4,q=.7,bulbs=7,pennant=2,head=.4,sign=Vector2.new(6,1.6),
	mat=Vector2.new(9,4),cell=1.5,paws=6,teal="#2F7F8C",cream="#EFE3C8",charcoal="#2E2A28",coral="#E2603F",bulb="#FFD27A",
	light=table.freeze({color="#FFE2A8",range=12,brightness=1.2})})

-- The gate's clear width and height in this bay, and the pennant pole's height (0 when it does not fit): Greybox.Gate,
-- shrunk to the bay's width (between the post centres' room) and to its roof less a 0.4 margin.
function Greybox.gateSize(bay,layout)
	local G=Greybox.Gate
	local width=math.min(G.clear,bay.width or 7)   -- the bay's slot is the opening; the posts stand just outside it
	local head=(bay.roof or (layout.floorY+9.25))-layout.floorY-G.head
	local clearH=math.min(G.clearH,head-G.beam-G.band)
	local pennant=math.max(0,math.min(G.pennant,head-G.beam-G.band-clearH))
	return width,clearH,pennant
end

function Greybox.gate(add,bay,layout)
	local G,f,n=Greybox.Gate,bay.frame,bay.id
	local width,clearH,pennant=Greybox.gateSize(bay,layout)
	local half=width/2+G.post/2
	local top=clearH+G.band+G.beam                  -- the beam's top over the floor
	for side=-1,1,2 do
		local s=if side<0 then "L"else "R"
		add(n.."GatePost"..s,Vector3.new(G.post,top,G.post),f*CFrame.new(side*half,top/2,0),G.teal,{material="Wood",collide=true})
		for k,y in ipairs({1.1,clearH-.6})do
			add(n.."GateBand"..s..k,Vector3.new(G.post+.1,.35,G.post+.1),f*CFrame.new(side*half,y,0),G.cream,{material="Wood"})
		end
	end
	add(n.."GateBeam",Vector3.new(width+2*G.post,G.beam,G.post),f*CFrame.new(0,top-G.beam/2,0),G.teal,{material="Wood"})
	-- the checker band: a cream board with charcoal squares on alternate cells, two rows of q, on both faces
	local bandY=clearH+G.band/2
	add(n.."GateBanner",Vector3.new(width,G.band,.3),f*CFrame.new(0,bandY,0),G.cream,{material="Wood"})
	local cols=math.floor(width/G.q)
	local x0=-cols*G.q/2+G.q/2
	for r=0,1 do
		for c=0,cols-1 do
			if (r+c)%2==0 then
				add(n.."GateCheck"..r.."_"..c,Vector3.new(G.q,G.q,.36),f*CFrame.new(x0+c*G.q,clearH+G.band/4+r*G.q,0),G.charcoal,{material="Wood"})
			end
		end
	end
	-- seven bulbs under the band; the middle one carries the gate's one light
	for k=1,G.bulbs do
		local x=-width/2+.4+(width-.8)*(k-1)/(G.bulbs-1)
		add(n.."GateBulb"..k,Vector3.new(.35,.35,.35),f*CFrame.new(x,clearH-.25,0),G.bulb,
			{material="Neon",shape="ball",light=if k==math.ceil(G.bulbs/2)then G.light else nil})
	end
	-- the pennant: a pole off the right post and a coral swallow tail (two wedges); dropped when the roof is too low
	if pennant>=.8 then
		add(n.."GatePole",Vector3.new(.2,pennant,.2),f*CFrame.new(half,top+pennant/2,0),G.cream,{material="Wood"})
		for k,dy in ipairs({.18,-.18})do
			add(n.."GatePennant"..k,Vector3.new(1.6,.32,.06),f*CFrame.new(half+.9,top+pennant-.35+dy,0)*CFrame.Angles(0,0,math.rad(-dy*60)),G.coral,{material="Fabric"})
		end
	end
	-- the board on the banner's front (its words: DenClient, UICopy dash.title)
	-- Studio R6: at 6 on a 7-wide banner the board hid the checks; it leaves at least 1.4 of checks each side
	add(n.."GateSign",Vector3.new(math.min(G.sign.X,width-2.8),G.sign.Y,.15),f*CFrame.new(0,bandY,-.25),G.cream,{material="Wood"})
	-- the start mat in front of the gate in checks of `cell`, and the paw stones in a line on toward the room
	local mw=math.min(G.mat.X,width+1)
	local matZ=-G.mat.Y/2-.6
	add(n.."GateMat",Vector3.new(mw,.06,G.mat.Y),f*CFrame.new(0,.03,matZ),G.cream,{material="Fabric"})
	local mc,mr=math.floor(mw/G.cell),math.floor(G.mat.Y/G.cell)
	for r=0,mr-1 do
		for c=0,mc-1 do
			if (r+c)%2==0 then
				add(n.."GateMatCheck"..r.."_"..c,Vector3.new(G.cell,.07,G.cell),f*CFrame.new(-mc*G.cell/2+G.cell/2+c*G.cell,.035,matZ-mr*G.cell/2+G.cell/2+r*G.cell),G.charcoal,{material="Fabric"})
			end
		end
	end
	for k=1,G.paws do
		add(n.."Paw"..k,Vector3.new(.9,.06,.9),f*CFrame.new(((k%2)*2-1)*.5,.03,matZ-G.mat.Y/2-1.2-(k-1)*1.3),L.pawStone,{material="Slate"})
	end
end

function Greybox.rows(layout)
	local rows={}
	local function add(name,size,cframe,color,options)
		options=options or {}
		local row={name=Greybox.Prefix..name,size=size,cframe=cframe,color=color,material=options.material,collide=options.collide==true,
			visible=true,shadow=false,tilted=true,light=options.light,shape=options.shape}
		table.insert(rows,table.freeze(row))
		return row
	end
	local light=table.freeze({color=Layout.Light.color,range=Layout.Light.range,brightness=Layout.Light.brightness})
	local solidExtras=layout.variant=="room"
	local room=layout.variant=="room"
	-- A lantern: the lamp with a dark cap and base, so it reads as a lantern and not a cube.
	local function lantern(i,at)
		add("Lantern"..i,Vector3.new(.8,1.1,.8),CFrame.new(at),L.lamp,{material="Neon",light=light})
		for k,dy in ipairs({.62,-.62})do add("Lantern"..i..(if k==1 then "Cap"else "Base"),Vector3.new(.95,.15,.95),CFrame.new(at+Vector3.new(0,dy,0)),L.dark,{material="Wood"})end
	end
	if room then
		-- The timber frame over the old marble mouth: the beam on the trim, a lawnward stud off the marble's face.
		local m,F=layout.mouth,Greybox.Frame
		local z=m.z+F.out
		local beamCF=CFrame.new((m.x1+m.x2)/2,F.beamY,z)
		add("FrameLintel",F.beam,beamCF,L.dark,{material="Wood"})
		local bottom=F.beamY-F.beam.Y/2
		for k,x in ipairs({m.x1-.5,m.x2+.5})do
			add("FrameJamb"..k,Vector3.new(F.jamb,bottom-layout.floorY,F.jamb),CFrame.new(x,(bottom+layout.floorY)/2,z),L.dark,{material="Wood"})
		end
		add("FrameThreshold",Vector3.new(m.x2-m.x1+1,.5,1.8),CFrame.new((m.x1+m.x2)/2,4.5-.25,m.z+.9),L.earth,{material="Ground"})
		-- The sign on the beam's lawn face, tilted forward; the opening stays clear.
		local signCF=CFrame.new((m.x1+m.x2)/2,F.beamY,z+F.beam.Z/2+.14)*CFrame.Angles(math.rad(-F.tilt),0,0)
		add("Sign",Vector3.new(8,2.2,.25),signCF,L.wood,{material="WoodPlanks"})
		-- The mouth lanterns hang from the beam's ends; the wall lamps stay on their brackets.
		local hung=0
		for i,l in ipairs(layout.lanterns)do
			if l.post then
				hung+=1
				local x=if hung==1 then m.x1+.5 else m.x2-.5
				add("LanternCord"..i,Vector3.new(.08,F.cord,.08),CFrame.new(x,bottom-F.cord/2,z),L.rope,{material="Fabric"})
				lantern(i,Vector3.new(x,bottom-F.cord-.55,z))
			else
				add("LanternBracket"..i,Vector3.new(.2,.2,.8),CFrame.new(l.at+Vector3.new(0,.7,-.4)),L.dark,{material="Wood"})
				lantern(i,l.at)
			end
		end
		-- The mat mid-room: a cloth disc with a red inner disc.
		local mat=Greybox.Mat
		local up=CFrame.Angles(0,0,math.pi/2)
		add("Mat",Vector3.new(.08,mat.d,mat.d),CFrame.new(mat.at.X,layout.floorY+.04,mat.at.Y)*up,L.cloth,{material="Fabric",shape="cylinder"})
		add("MatInner",Vector3.new(.08,mat.inner,mat.inner),CFrame.new(mat.at.X,layout.floorY+.05,mat.at.Y)*up,L.red,{material="Fabric",shape="cylinder"})
		-- The apron: one worn dirt patch from the mouth to the cliff path's foot, plugging the cut's edge (the mouth's own
		-- floor stays the room's: the slab skips it).
		local A=Greybox.Apron
		local y=A.top-A.thick/2
		local function slab(name,x1,z1,x2,z2)
			add(name,Vector3.new(x2-x1,A.thick,z2-z1),CFrame.new((x1+x2)/2,y,(z1+z2)/2),L.earth,{material="Ground",collide=true})
		end
		local front=m.z+7.3 -- the mouth's floor box ends about here (CliffDenData.collision, floor 2)
		slab("ApronFront",A.x1,front,A.x2,A.z2)
		slab("ApronWest",A.x1,A.z1,m.x1-1,front)
		slab("ApronEast",m.x2+1,A.z1,A.x2,front)
	else
		-- Step A's pocket (the specs' fixture): the sign under the lintel, posts at the mouth.
		add("Sign",Vector3.new(8,2.2,.25),layout.sign,L.wood,{material="WoodPlanks"})
		for side=-1,1,2 do add("SignCord",Vector3.new(.08,.9,.08),layout.sign*CFrame.new(side*3.6,1.55,0),L.rope,{material="Fabric"})end
		for i,l in ipairs(layout.lanterns)do
			if l.post then
				add("LanternPost"..i,Vector3.new(.35,6.6,.35),CFrame.new(l.at+Vector3.new(0,3.3,0)),L.dark,{material="Wood",collide=true})
				lantern(i,l.at+Vector3.new(0,6.9,0))
			else
				add("LanternBracket"..i,Vector3.new(.2,.2,.8),CFrame.new(l.at+Vector3.new(0,.7,-.4)),L.dark,{material="Wood"})
				lantern(i,l.at)
			end
		end
	end
	-- The notice board on its post, facing the lawn.
	add("BoardPost",Vector3.new(.4,5,.4),layout.board*CFrame.new(0,2.5,.2),L.dark,{material="Wood",collide=true})
	add("Board",Vector3.new(4,2.6,.2),layout.board*CFrame.new(0,3.6,-.05),L.wood,{material="WoodPlanks"})
	-- Fable fix 11: three cloth rows on its face, so it reads as a list.
	if room then
		for k=1,3 do add("BoardRow"..k,Vector3.new(3.4,.5,.05),layout.board*CFrame.new(0,3.6+(2-k)*.75,-.18),L.cloth,{material="Fabric"})end
	end
	for _,bay in ipairs(layout.bays)do
		local f,n=bay.frame,bay.id
		if bay.kind=="dash"then
			Greybox.gate(add,bay,layout)
		elseif bay.kind=="deck"then
			if room then
				-- Fable fix 10: a round stump, the Deck propped up at its back facing the mouth.
				add(n.."Stump",Vector3.new(2.2,5,5),f*CFrame.new(0,1.1,0)*CFrame.Angles(0,0,math.pi/2),L.dark,{material="Wood",collide=true,shape="cylinder"})
				local slab=f*CFrame.new(0,3.25,1.2)*CFrame.Angles(math.rad(-55),0,0)
				add(n.."Deck",Vector3.new(3.5,.25,2.4),slab,L.cloth,{material="SmoothPlastic"})
				add(n.."DeckScreen",Vector3.new(2.8,.05,1.7),slab*CFrame.new(0,.15,0),L.screen,{material="Neon"})
			else
				add(n.."Stump",Vector3.new(3,2.4,3),f*CFrame.new(0,1.2,0),L.dark,{material="Wood",collide=true})
				local slab=f*CFrame.new(0,2.62,.2)*CFrame.Angles(math.rad(-18),0,0)
				add(n.."Deck",Vector3.new(2.4,.22,1.6),slab,L.cloth,{material="SmoothPlastic"})
				add(n.."DeckScreen",Vector3.new(1.8,.05,1.1),slab*CFrame.new(0,.13,0),L.screen,{material="Neon"})
			end
			local stools=if layout.variant=="room"then{{-2.6,-1},{2.6,-1},{-1.2,-2.6},{1.2,-2.6}}else{{-1.2,-2.4},{1.2,-2.4}}
			for k,s in ipairs(stools)do
				if room then
					add(n.."Stool"..k,Vector3.new(.9,1.1,1.1),f*CFrame.new(s[1],.45,s[2])*CFrame.Angles(0,0,math.pi/2),L.wood,{material="Wood",collide=solidExtras,shape="cylinder"})
				else
					add(n.."Stool"..k,Vector3.new(.9,.9,.9),f*CFrame.new(s[1],.45,s[2]),L.wood,{material="Wood",collide=solidExtras})
				end
			end
		elseif bay.kind=="niche"then
			add(n.."Crate",Vector3.new(1.6,1.6,1.6),f*CFrame.new(0,.8,0),L.wood,{material="WoodPlanks",collide=solidExtras})
			add(n.."Sheet",Vector3.new(1.8,.12,1.8),f*CFrame.new(0,1.66,0),L.cloth,{material="Fabric"})
			add(n.."Drape",Vector3.new(1.8,1.1,.1),f*CFrame.new(0,1.15,-.9),L.cloth,{material="Fabric"})
			for side=-1,1,2 do add(n.."RopePost",Vector3.new(.2,1.2,.2),f*CFrame.new(side*1.4,.6,-1.4),L.dark,{material="Wood"})end
			add(n.."Rope",Vector3.new(2.8,.08,.08),f*CFrame.new(0,1.0,-1.4),L.rope,{material="Fabric"})
		end
	end
	return rows
end
return table.freeze(Greybox)
