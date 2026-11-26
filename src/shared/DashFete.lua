-- The Garden Dash start and finish as one fete set (beta 17 QA; artifacts/qa-2026-11-25-beta17/WORLD-ALIVE-LOOK.md
-- section 3): timber posts on the garden's marble-and-gold feet, rope, and cloth flags in four muted colours. Shared and
-- pure: the pieces DashMount builds while the Alive `scene` switch is on (off: the placeholder arches, exactly as
-- before). No instances. Every piece is in its gate's own frame: X across the lanes, Y up, +Z the way the race runs
-- (DashCourse.at's yaw), so the start line is Z = 0.
--   piece  {name, shape ("Block" | "Cylinder" | "Ball"), size, at (CFrame in the frame), material, colour,
--           transparency?, shadow?, words? (the faces that carry the Dash title)}
--   rope   {name, a, b (Vector3 in the frame), sag, width}: a Beam between two attachments on the frame's anchor
-- Nothing in the start gate hangs below Clear across the lanes (the race camera is 9 up). The flags are static tonight;
-- swaying them with Wind.swayAt is the follow-up.
local Grid=require(script.Parent.DashGrid)
local Fete={}
local hex=Color3.fromHex

Fete.Timber=hex("#A9764A")
Fete.EndGrain=hex("#7A5636")
Fete.Marble=hex("#F4EFF5") -- the bridge's marble [check] against W7_Bridge__marble in Studio
Fete.Gold=hex("#E0A93A")
Fete.Cloth=table.freeze({hex("#EFE6D2"),hex("#D9A0A8"),hex("#9DB8A0"),hex("#6FAFA6")}) -- cream, dusty rose, sage, soft teal
Fete.Rope=hex("#B79A66") -- DashLine's rope
Fete.Chalk=hex("#EDE8DA")
Fete.Pebbles=table.freeze({hex("#8C8A84"),hex("#B8B2A6")})
Fete.Earth=hex("#8B6A4A") -- the dirt path's colour [check] against the path in Studio
Fete.RopeWidth=.11
Fete.Clear=9.6 -- nothing across the lanes under this (the race camera is 9 up)
Fete.MaxParts=60

local function piece(list,name,shape,size,at,material,colour,extra)
	local p={name=name,shape=shape,size=size,at=at,material=material,colour=colour}
	for key,value in pairs(extra or {})do p[key]=value end
	table.insert(list,table.freeze(p))
	return p
end
local function rope(list,name,a,b,sag,width)
	table.insert(list,table.freeze({name=name,a=a,b=b,sag=sag or 0,width=width or Fete.RopeWidth}))
end
-- A seeded turn in [lo, hi] degrees for flag k, its sign alternating (no Random: the same on every server).
local function rest(k,lo,hi)
	local h=((k*2654435761)%4294967296)/4294967296
	return math.rad(lo+(hi-lo)*h)*(if k%2==0 then 1 else -1)
end
-- A rope's height `x` across, for ends at `y` and `half` out with `sag` (a parabola: the Beam's Bezier is within a
-- hundredth of it for these spans).
function Fete.ropeY(x,y,half,sag)
	local u=math.clamp(x/half,-1,1)
	return y-sag*(1-u*u)
end
-- A cloth flag hung by its top edge at (x, top, z), turned `turn` about the rope.
local function flag(list,name,k,x,top,z,size,turn)
	local at=CFrame.new(x,top,z)*CFrame.Angles(turn,0,0)*CFrame.new(0,-size.Y/2,0)
	piece(list,name,"Block",size,at,"Fabric",Fete.Cloth[(k-1)%#Fete.Cloth+1])
end
-- A marble foot, a gold cap and a timber post standing on them at x; returns the post's top.
local function post(list,name,x,foot,cap,width,height,shadow)
	piece(list,name.."Foot","Block",foot,CFrame.new(x,foot.Y/2,0),"Marble",Fete.Marble)
	piece(list,name.."Cap","Block",cap,CFrame.new(x,foot.Y+cap.Y/2,0),"SmoothPlastic",Fete.Gold)
	local base=foot.Y+cap.Y
	piece(list,name.."Post","Block",Vector3.new(width,height,width),CFrame.new(x,base+height/2,0),"Wood",Fete.Timber,{shadow=shadow})
	return base+height
end

-- The start gate. postOut: the posts' distance from the centre line (studs; DashGrid.PostOut). lanes: the racers'
-- sideways offsets at the line (studs), one pebble under each.
Fete.Start=table.freeze({foot=Vector3.new(1.6,1,1.6),cap=Vector3.new(1.8,.25,1.8),post=.6,postHeight=10.6,sag=.6,
	flag=Vector3.new(.8,1,.05),flagStep=1.35,flags=9,header=Vector3.new(5,1.3,.22),headerY=10.4,headerZ=-.15,drop=1.8,
	dropWidth=.12,guyAt=9,guyOut=5,guyBack=3,stake=Vector3.new(.16,1,.16),stakeSink=.1,guyFlag=Vector3.new(.5,.6,.04),
	guyFlags=table.freeze({.3,.5,.7}),line=Vector3.new(0,.04,.3),lineTransparency=.15,pebble=.7,pebbleHigh=.08,pebbleBack=.8})
function Fete.start(postOut,lanes)
	local S=Fete.Start
	postOut=postOut or Grid.PostOut/100
	local parts,ropes={},{}
	local top=0
	for side=-1,1,2 do
		local name=if side<0 then "StartLeft"else "StartRight"
		top=post(parts,name,side*postOut,S.foot,S.cap,S.post,S.postHeight,true)
	end
	-- The rope between the post tops (its ends just under them), sagging .6.
	local ends=top-.05
	rope(ropes,"StartRope",Vector3.new(-postOut,ends,0),Vector3.new(postOut,ends,0),S.sag)
	-- The header hangs from the rope's middle on two drops, a little in front of the flags.
	local headerTop=S.headerY+S.header.Y/2
	piece(parts,"StartHeader","Block",S.header,CFrame.new(0,S.headerY,S.headerZ),"Wood",Fete.Timber,{words={"Front","Back"}})
	for side=-1,1,2 do
		local x=side*S.drop
		rope(ropes,"StartDrop",Vector3.new(x,Fete.ropeY(x,ends,postOut,S.sag),0),Vector3.new(x,headerTop,S.headerZ),0,S.dropWidth)
	end
	-- Flags 1.35 apart along the rope; the ones the header hides (inside its width) are not built.
	local hidden=S.header.X/2-S.flag.X/2+.05
	for k=1,S.flags do
		local x=(k-(S.flags+1)/2)*S.flagStep
		if math.abs(x)>hidden then
			flag(parts,"StartFlag",k,x,Fete.ropeY(x,ends,postOut,S.sag)-.02,0,S.flag,rest(k,3,8))
		end
	end
	-- Guy lines: from each post at 9 up to a stake 5 out and 3 back, three small flags on each.
	for side=-1,1,2 do
		local from=Vector3.new(side*postOut,S.guyAt,0)
		local foot=Vector3.new(side*(postOut+S.guyOut),0,-S.guyBack)
		piece(parts,"GuyStake","Block",S.stake,CFrame.new(foot+Vector3.new(0,S.stake.Y/2-S.stakeSink,0)),"Wood",Fete.EndGrain)
		local to=foot+Vector3.new(0,S.stake.Y-S.stakeSink,0)
		rope(ropes,"GuyLine",from,to,.15)
		local d=to-from
		local yaw=math.atan2(-d.Z,d.X)
		for i,t in ipairs(S.guyFlags)do
			local at=from:Lerp(to,t)
			piece(parts,"GuyFlag","Block",S.guyFlag,CFrame.new(at)*CFrame.Angles(0,yaw,0)*CFrame.new(0,-S.guyFlag.Y/2-.03,0),"Fabric",
				Fete.Cloth[(i+side)%#Fete.Cloth+1])
		end
	end
	-- The chalk line in place of the eight slabs, and a flat pebble under each racer's slot.
	piece(parts,"StartLine","Block",Vector3.new(postOut*2+S.post+.1,S.line.Y,S.line.Z),CFrame.new(0,S.line.Y/2,0),"SmoothPlastic",
		Fete.Chalk,{transparency=S.lineTransparency})
	for lane,o in ipairs(lanes or {})do
		piece(parts,"LaneStone_"..lane,"Cylinder",Vector3.new(S.pebbleHigh,S.pebble,S.pebble),
			CFrame.new(-o,S.pebbleHigh/2,-S.pebbleBack)*CFrame.Angles(0,0,math.pi/2),"Slate",Fete.Pebbles[(lane-1)%2+1])
	end
	return parts,ropes
end

-- The finish: the same family at 6.8 wide, a rosette at the rope's middle facing the runners (no words).
Fete.Finish=table.freeze({postOut=3.4,foot=Vector3.new(1.2,.8,1.2),cap=Vector3.new(1.4,.2,1.4),post=.5,postHeight=6.2,sag=.4,
	flag=Vector3.new(.7,.9,.05),flagStep=1.2,flags=5,rosette=1.6,rosetteThick=.12,boss=.7,tail=Vector3.new(.35,1.1,.04),
	rosetteZ=-.15,line=Vector3.new(6.8,.04,.3)})
function Fete.finish()
	local F=Fete.Finish
	local parts,ropes={},{}
	local top=0
	for side=-1,1,2 do
		top=post(parts,if side<0 then "FinishLeft"else "FinishRight",side*F.postOut,F.foot,F.cap,F.post,F.postHeight,true)
	end
	local ends=top-.05
	rope(ropes,"FinishRope",Vector3.new(-F.postOut,ends,0),Vector3.new(F.postOut,ends,0),F.sag)
	-- The rosette hangs from the rope's middle; the middle flag would sit behind it, so it is not built.
	local low=ends-F.sag
	local centre=low-F.rosette/2
	local face=CFrame.Angles(0,math.pi/2,0) -- a cylinder's axis (X) along Z: the disc faces the runners
	piece(parts,"Rosette","Cylinder",Vector3.new(F.rosetteThick,F.rosette,F.rosette),CFrame.new(0,centre,F.rosetteZ)*face,"Fabric",Fete.Cloth[1])
	piece(parts,"RosetteBoss","Cylinder",Vector3.new(F.rosetteThick/2,F.boss,F.boss),
		CFrame.new(0,centre,F.rosetteZ-F.rosetteThick*.75)*face,"SmoothPlastic",Fete.Gold)
	for side=-1,1,2 do
		local at=CFrame.new(side*.2,centre-F.rosette*.35,F.rosetteZ+.02)*CFrame.Angles(0,0,math.rad(10*side))*CFrame.new(0,-F.tail.Y/2,0)
		piece(parts,"RosetteTail","Block",F.tail,at,"Fabric",if side<0 then Fete.Cloth[2]else Fete.Cloth[4])
	end
	for k=1,F.flags do
		local x=(k-(F.flags+1)/2)*F.flagStep
		if math.abs(x)>F.rosette/2 then
			flag(parts,"FinishFlag",k,x,Fete.ropeY(x,ends,F.postOut,F.sag)-.02,0,F.flag,rest(k+20,3,8))
		end
	end
	piece(parts,"FinishLine","Block",F.line,CFrame.new(0,F.line.Y/2,0),"SmoothPlastic",Fete.Chalk,{transparency=Fete.Start.lineTransparency})
	return parts,ropes
end

-- The waiting pad: trodden earth with the rope ring round it as today (DashLine), and a timber sign on the far edge.
-- Spencer 2026-11-26 (beta 34): "the garden dash sign has the post going up thru the text". The board now hangs
-- between two posts at its ends (each a hair past the board's top), so nothing crosses the words on either face.
Fete.Pad=table.freeze({high=.06,post=Vector3.new(.3,3,.3),board=Vector3.new(2.4,1.3,.2),out=.4,boardY=2.6,postOver=.15})
function Fete.pad(r)
	local P=Fete.Pad
	local parts={}
	piece(parts,"WaitPad","Cylinder",Vector3.new(P.high,r*2,r*2),CFrame.new(0,P.high/2,0)*CFrame.Angles(0,0,math.pi/2),"Ground",Fete.Earth)
	local top=P.boardY+P.board.Y/2+P.postOver
	local side=P.board.X/2+P.post.X/2
	for index,x in ipairs({-side,side})do
		piece(parts,if index==1 then"SignPost"else"SignPost2","Block",Vector3.new(P.post.X,top,P.post.Z),CFrame.new(x,top/2,-r-P.out),"Wood",Fete.Timber)
	end
	piece(parts,"Sign","Block",P.board,CFrame.new(0,P.boardY,-r-P.out),"Wood",Fete.Timber,{words={"Front","Back"}})
	return parts,{}
end

-- The lowest point of a piece (its eight corners) in the frame.
function Fete.bottom(p)
	local h=p.size/2
	local low=math.huge
	for _,sx in ipairs({-1,1})do for _,sy in ipairs({-1,1})do for _,sz in ipairs({-1,1})do
		low=math.min(low,(p.at*Vector3.new(h.X*sx,h.Y*sy,h.Z*sz)).Y)
	end end end
	return low
end

return table.freeze(Fete)
