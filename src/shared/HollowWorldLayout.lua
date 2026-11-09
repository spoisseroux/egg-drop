-- Authored geometry coordinates; the original hub and spawn remain in place.
local function points(values)return table.freeze(values)end
return table.freeze({
	Width=160,Depth=176,FloorCenterZ=24,FloorTop=4,BoardwalkWidth=8,
    Spring=table.freeze({
        LawnCenter=Vector2.new(-10,88),LawnSize=Vector2.new(14,12),
        Rest=Vector3.new(-10,4.025,87),
        RestWest=Vector3.new(-12.5,4.025,87),RestEast=Vector3.new(-7.5,4.025,87),
        BasinCenter=Vector3.new(-14,4.20,99),BasinSize=Vector3.new(7,.12,3.6),
    }),
    WalkableSpans=table.freeze({
        PrimaryBridge=table.freeze({center=Vector3.new(17.6,4.25,-9.4),size=Vector3.new(10.0,.21,4.5)}),
        RestNook=table.freeze({center=Vector3.new(26,4.025,-15.2),size=Vector3.new(8.3,.25,5.0)}),
    }),
	Landmarks=table.freeze({Boardwalk=Vector2.new(64,-14),Orchard=Vector2.new(-59,-34),Spring=Vector2.new(-10,88)}),
	Routes=table.freeze({
		Boardwalk=points({Vector2.new(43,-28),Vector2.new(48,-26),Vector2.new(55,-20),Vector2.new(64,-14)}),
		EastReturn=points({Vector2.new(64,-14),Vector2.new(65,-4),Vector2.new(53,3),Vector2.new(42,-6),Vector2.new(47,-16),Vector2.new(48,-26)}),
		Orchard=points({Vector2.new(-35,-22),Vector2.new(-44,-22),Vector2.new(-51,-29),Vector2.new(-59,-34)}),
		OrchardReturn=points({Vector2.new(-59,-34),Vector2.new(-61,-22),Vector2.new(-49,-15),Vector2.new(-35,-22)}),
        SpringApproach=points({Vector2.new(0,39),Vector2.new(0,48)}),
        SpringLoop=points({Vector2.new(0,48),Vector2.new(-12,60),Vector2.new(-17,77),Vector2.new(-9,91),Vector2.new(5,83),Vector2.new(6,63),Vector2.new(0,48)}),
	}),
	Lamps=points({Vector2.new(44,-30),Vector2.new(-18,89),Vector2.new(65,-18),Vector2.new(67,-10),
		Vector2.new(-3,69),Vector2.new(-7,51),Vector2.new(-63,-36)}),
	LitLamps=table.freeze({[2]=true,[3]=true,[7]=true}),
})
