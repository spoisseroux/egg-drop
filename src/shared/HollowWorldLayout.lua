-- Authored geometry coordinates. The hub (stations, hatch tree, spawn, toy
-- lawn, creek nook, spring meadow) stays where it was; the approved greybox
-- landscape (2026-11-11, src/server/LoungeGreyboxArt.lua) surrounds it.
-- Every crossing bridge spans X over water that runs along Z.
local function points(values)return table.freeze(values)end
return table.freeze({
	-- Floor covers greybox-local X -121..120, Z -100..100.
	Width=241,Depth=200,FloorCenterX=-10.5,FloorCenterZ=25,FloorTop=4,
	-- greybox-local + offset = world; the greybox landmark tree sits on the hatch tree.
	GreyboxOffset=Vector3.new(-10,4,25),
    Spring=table.freeze({
        LawnCenter=Vector2.new(-10,88),LawnSize=Vector2.new(14,12),
        Rest=Vector3.new(-10,4.025,87),
        RestWest=Vector3.new(-12.5,4.025,87),RestEast=Vector3.new(-7.5,4.025,87),
        BasinCenter=Vector3.new(-14,4.20,99),BasinSize=Vector3.new(7,.12,3.6),
    }),
    WalkableSpans=table.freeze({
        PrimaryBridge=table.freeze({center=Vector3.new(17.6,4.25,-9.4),size=Vector3.new(10.0,.21,4.5),crossing=true}),
        WestBridge=table.freeze({center=Vector3.new(-83,4.25,35),size=Vector3.new(16.0,.21,6.0),crossing=true}),
        RestNook=table.freeze({center=Vector3.new(26,4.025,-15.2),size=Vector3.new(8.3,.25,5.0)}),
    }),
	Landmarks=table.freeze({Spring=Vector2.new(-10,88),WestBridge=Vector2.new(-83,35),Cave=Vector2.new(10,-72)}),
	Routes=table.freeze({
        SpringApproach=points({Vector2.new(0,39),Vector2.new(0,48)}),
        SpringLoop=points({Vector2.new(0,48),Vector2.new(-12,60),Vector2.new(-17,77),Vector2.new(-9,91),Vector2.new(5,83),Vector2.new(6,63),Vector2.new(0,48)}),
	}),
	Lamps=points({Vector2.new(-72,31),Vector2.new(-18,89),Vector2.new(65,-18),Vector2.new(44,40),
		Vector2.new(-3,69),Vector2.new(-7,51),Vector2.new(4,-68)}),
	LitLamps=table.freeze({[1]=true,[2]=true,[7]=true}),
})
