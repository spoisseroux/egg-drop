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
	lamp="#FFD9A0",screen="#9BE3C9",red="#D9725E",yellow="#E8C468"})
local L=Greybox.Look
Greybox.MaxParts=60

function Greybox.rows(layout)
	local rows={}
	local function add(name,size,cframe,color,options)
		options=options or {}
		local row={name=Greybox.Prefix..name,size=size,cframe=cframe,color=color,material=options.material,collide=options.collide==true,
			visible=true,shadow=false,tilted=true,light=options.light}
		table.insert(rows,table.freeze(row))
		return row
	end
	local light=table.freeze({color=Layout.Light.color,range=Layout.Light.range,brightness=Layout.Light.brightness})
	local solidExtras=layout.variant=="room"
	-- The sign under the lintel, hung on two cords.
	add("Sign",Vector3.new(8,2.2,.25),layout.sign,L.wood,{material="WoodPlanks"})
	for side=-1,1,2 do add("SignCord",Vector3.new(.08,.9,.08),layout.sign*CFrame.new(side*3.6,1.55,0),L.rope,{material="Fabric"})end
	-- The lanterns: posts at the mouth, wall lamps inside.
	for i,l in ipairs(layout.lanterns)do
		if l.post then
			add("LanternPost"..i,Vector3.new(.35,6.6,.35),CFrame.new(l.at+Vector3.new(0,3.3,0)),L.dark,{material="Wood",collide=true})
			add("Lantern"..i,Vector3.new(.8,1.1,.8),CFrame.new(l.at+Vector3.new(0,6.9,0)),L.lamp,{material="Neon",light=light})
		else
			add("LanternBracket"..i,Vector3.new(.2,.2,.8),CFrame.new(l.at+Vector3.new(0,.7,-.4)),L.dark,{material="Wood"})
			add("Lantern"..i,Vector3.new(.8,1.1,.8),CFrame.new(l.at),L.lamp,{material="Neon",light=light})
		end
	end
	-- The notice board on its post, facing the lawn.
	add("BoardPost",Vector3.new(.4,5,.4),layout.board*CFrame.new(0,2.5,.2),L.dark,{material="Wood",collide=true})
	add("Board",Vector3.new(4,2.6,.2),layout.board*CFrame.new(0,3.6,-.05),L.wood,{material="WoodPlanks"})
	for _,bay in ipairs(layout.bays)do
		local f,n=bay.frame,bay.id
		if bay.kind=="dash"then
			for side=-1,1,2 do add(n.."GatePost",Vector3.new(.5,5,.5),f*CFrame.new(side*2,2.5,0),L.wood,{material="Wood",collide=true})end
			add(n.."GateBar",Vector3.new(4.5,.4,.3),f*CFrame.new(0,4.9,0),L.wood,{material="Wood"})
			for k=1,5 do
				add(n.."Bunting",Vector3.new(.6,.6,.08),f*CFrame.new(-1.6+(k-1)*.8,4.45,0)*CFrame.Angles(0,0,math.pi/4),if k%2==1 then L.red else L.yellow,{material="Fabric"})
			end
			add(n.."Slate",Vector3.new(1.4,1.1,.12),f*CFrame.new(1.6,1.1,-.45)*CFrame.Angles(math.rad(-12),0,0),L.slate,{material="Slate"})
			-- The paw stones where you wait, round the spot in front of the gate.
			local count=if layout.variant=="room"then 8 else 6
			local r=if layout.variant=="room"then 5 else 2
			for k=1,count do
				local a=(k-1)/count*math.pi*2
				add(n.."Paw",Vector3.new(.9,.06,.9),f*CFrame.new(math.cos(a)*r,.03,-2.8+math.sin(a)*r),L.stone,{material="Slate"})
			end
		elseif bay.kind=="deck"then
			add(n.."Stump",Vector3.new(3,2.4,3),f*CFrame.new(0,1.2,0),L.dark,{material="Wood",collide=true})
			local slab=f*CFrame.new(0,2.62,.2)*CFrame.Angles(math.rad(-18),0,0)
			add(n.."Deck",Vector3.new(2.4,.22,1.6),slab,L.cloth,{material="SmoothPlastic"})
			add(n.."DeckScreen",Vector3.new(1.8,.05,1.1),slab*CFrame.new(0,.13,0),L.screen,{material="Neon"})
			local stools=if layout.variant=="room"then{{-2.6,-1},{2.6,-1},{-1.2,-2.6},{1.2,-2.6}}else{{-1.2,-2.4},{1.2,-2.4}}
			for k,s in ipairs(stools)do
				add(n.."Stool"..k,Vector3.new(.9,.9,.9),f*CFrame.new(s[1],.45,s[2]),L.wood,{material="Wood",collide=solidExtras})
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
