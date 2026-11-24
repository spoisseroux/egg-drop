-- The Hush greybox parts (HUSH-GREYBOX-BUILD-PLAN.md section 2), as pure rows HushHost builds into EggDropLounge.Hush.
-- Untextured matte blockout: no meshes, no textures. Every name starts "W7H_" so the camera clamp (CameraClamp.isWorld)
-- stops on the solids. Row: {name, size, cframe, color (hex), collide, visible, shadow, light = {color, range,
-- brightness} for a fixture}. The Hush rows come from Hush.at (one origin); the Underway rows sit in the existing pocket
-- behind the old blocker line, measured from the 4-stud ground grid (probe P1 measures it for real).
local Hush=require(script.Parent.Hush)
local at=Hush.at
local rows={}
local function solid(name,size,cframe,color,options)
	options=options or {}
	table.insert(rows,table.freeze({name="W7H_"..name,size=size,cframe=cframe,color=color,collide=options.collide~=false,
		visible=options.visible~=false,shadow=options.shadow==true}))
end
-- A box between two Hush-local corners (u, v, h).
local function span(name,u1,v1,h1,u2,v2,h2,color,options)
	local a,b=at(u1,v1,h1),at(u2,v2,h2)
	local size=Vector3.new(math.abs(b.X-a.X),math.abs(b.Y-a.Y),math.abs(b.Z-a.Z))
	solid(name,size,CFrame.new((a+b)/2),color,options)
end
local function invisible(name,u1,v1,h1,u2,v2,h2)span(name,u1,v1,h1,u2,v2,h2,"#FFFFFF",{visible=false})end
-- A wall 1 thick standing on the line (u1, v1) to (u2, v2), from h1 to h2 (the tunnel's flared mouth).
local function slant(name,u1,v1,u2,v2,h1,h2,color)
	local a,b=at(u1,v1,(h1+h2)/2),at(u2,v2,(h1+h2)/2)
	local frame=CFrame.lookAt((a+b)/2,b)
	table.insert(rows,table.freeze({name="W7H_"..name,size=Vector3.new(1,h2-h1,(b-a).Magnitude),cframe=frame,color=color,
		collide=true,visible=true,shadow=false,angled=true}))
end
local function light(name,position,color,range,brightness)
	table.insert(rows,table.freeze({name="W7H_"..name,size=Vector3.new(.2,.2,.2),cframe=CFrame.new(position),color="#FFFFFF",
		collide=false,visible=false,shadow=false,light=table.freeze({color=color,range=range,brightness=brightness})}))
end
local FLOOR,WALL,SILL,CLUMP,DARK="#6E7A6A","#5A5E62","#7A746A","#59665A","#101412"
local WALLED={shadow=true}

-- The Hush ------------------------------------------------------------------------------------------------------
span("Floor",-79,-4,-4,79,138,0,FLOOR)
span("WallWest",-79,-4,0,-75,128,40,WALL,WALLED)
span("WallEast",75,-4,0,79,128,40,WALL,WALLED)
local S=Hush.SillH
span("WallSouthWest",-79,-4,0,-7,0,40,WALL,WALLED)
span("WallSouthEast",7,-4,0,79,0,40,WALL,WALLED)
span("WallSouthLintel",-7,-4,S+8,7,0,40,WALL,WALLED)
span("WallSouthUnder",-7,-4,0,7,0,S,WALL)
span("WallNorthWest",-79,124,0,-5,128,40,WALL,WALLED)
span("WallNorthEast",15,124,0,79,128,40,WALL,WALLED)
span("ShelfWest",-9,128,0,-5,138,40,WALL,WALLED)
span("ShelfEast",15,128,0,19,138,40,WALL,WALLED)
span("ShelfRail",-5,137.4,0,15,137.8,1.2,SILL)
invisible("ShelfStop",-5,137.8,0,15,138.8,14)
-- The tunnel: straight in G0 (the bend is G3), floor at the Sill top (h SillH), 8 high, a dead end at v -24. Fable R5:
-- its last 8 studs flare out to the Sill's width at the wall face (v 0), so the walls leave the view from the Sill.
span("TunnelFloor",-3,-24,S-1,3,-8,S,SILL)
span("TunnelFloorMouth",-8,-8,S-1,8,0,S,SILL)
span("TunnelWallWest",-4,-24,S,-3,-8,S+8,WALL)
span("TunnelWallEast",3,-24,S,4,-8,S+8,WALL)
slant("TunnelFlareWest",-3.5,-8,-7.5,0,S,S+8,WALL)
slant("TunnelFlareEast",3.5,-8,7.5,0,S,S+8,WALL)
span("TunnelRoof",-4,-24,S+8,4,-8,S+9,WALL)
span("TunnelRoofMouth",-9,-8,S+8,9,-4,S+9,WALL)
span("TunnelEnd",-4,-25,S-1,4,-24,S+9,DARK)
-- The Sill: you come out 6 studs up with the whole hollow below. A low lip and invisible walls on its north and west
-- edges; the ramp leaves from its east edge.
span("Sill",-8,0,0,8,10,S,SILL)
span("SillLip",-8,9.4,S,8,10,S+.8,SILL)
invisible("SillStopNorth",-8,10,S,8,10.6,S+10)
invisible("SillStopWest",-8.6,0,S,-8,10.6,S+10)
-- The ramp: a tilted slab whose top runs from the Sill's east edge (u 8, h SillH) down to the floor (u RampFootU), 7 wide.
do
	local top,foot=at(8,5,S),at(Hush.RampFootU,5,0)
	local run=foot-top
	local length=run.Magnitude
	local frame=CFrame.lookAt((top+foot)/2,(top+foot)/2+Vector3.new(0,0,-1))*CFrame.Angles(0,0,-math.atan2(top.Y-foot.Y,foot.X-top.X))
	-- frame's X runs east and down along the slope; its top face is half a stud above the centre.
	solid("Ramp",Vector3.new(length+1,1,7),frame*CFrame.new(0,-.5,0),SILL)
end
-- Five clumps (Hush.Clumps: rooms that hide each other) and the pool's outline to judge scale.
for _,c in ipairs(Hush.Clumps)do span(c.name,c.u1,c.v1,0,c.u2,c.v2,Hush.ClumpHeight,CLUMP,WALLED)end
span("PoolOutline",-22,65,0,22,91,.1,DARK,{collide=false})
light("TunnelLight",at(0,-12,S+6),"#DFF5E6",14,.8)

-- The Underway (the pocket, floor y 4, back wall about z -114) -------------------------------------------------
-- The north throat: an alcove 6 wide x 8 high, 3 deep, with a dark back; its trigger is Hush.Doors.north.
solid("ThroatNorthJambWest",Vector3.new(1,8,3),CFrame.new(-10.5,8,-113.5),WALL)
solid("ThroatNorthJambEast",Vector3.new(1,8,3),CFrame.new(-3.5,8,-113.5),WALL)
solid("ThroatNorthLintel",Vector3.new(8,1,3),CFrame.new(-7,12.5,-113.5),WALL)
solid("ThroatNorthBack",Vector3.new(8,9.5,1),CFrame.new(-7,8.25,-115.5),DARK)
-- The sealed throats, west and east: dry-stacked stones to head height and a dark gap above. Scenery only.
solid("ThroatWestStones",Vector3.new(1.5,5,6),CFrame.new(-12.25,6.5,-107.5),SILL)
solid("ThroatWestGap",Vector3.new(.4,3,6),CFrame.new(-12.6,10.5,-107.5),DARK,{collide=false})
solid("ThroatEastStones",Vector3.new(1.5,5,6),CFrame.new(-1.75,6.5,-107.5),SILL)
solid("ThroatEastGap",Vector3.new(.4,3,6),CFrame.new(-1.4,10.5,-107.5),DARK,{collide=false})
light("ThroatNorthLight",Vector3.new(-7,9,-112),"#DFF5E6",10,.9)
light("ThroatWestLight",Vector3.new(-11,10,-107.5),"#FFC07A",7,.6)
light("ThroatEastLight",Vector3.new(-3,10,-107.5),"#5C8CFF",7,.6)

return table.freeze(rows)
