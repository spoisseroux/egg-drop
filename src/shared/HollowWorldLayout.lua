-- Authored geometry coordinates; the original hub and spawn remain in place.
local function points(values)return table.freeze(values)end
return table.freeze({
	Width=160,Depth=128,FloorTop=4,BoardwalkWidth=8,
	Landmarks=table.freeze({Boardwalk=Vector2.new(64,-14),Orchard=Vector2.new(-59,-34)}),
	Routes=table.freeze({
		Boardwalk=points({Vector2.new(43,-28),Vector2.new(48,-26),Vector2.new(55,-20),Vector2.new(64,-14)}),
		EastReturn=points({Vector2.new(64,-14),Vector2.new(65,-4),Vector2.new(53,3),Vector2.new(42,-6),Vector2.new(47,-16),Vector2.new(48,-26)}),
		Orchard=points({Vector2.new(-35,-22),Vector2.new(-44,-22),Vector2.new(-51,-29),Vector2.new(-59,-34)}),
		OrchardReturn=points({Vector2.new(-59,-34),Vector2.new(-61,-22),Vector2.new(-49,-15),Vector2.new(-35,-22)}),
	}),
	Lamps=points({Vector2.new(44,-30),Vector2.new(53,-24),Vector2.new(65,-18),Vector2.new(67,-10),
		Vector2.new(54,6),Vector2.new(-46,-25),Vector2.new(-63,-36)}),
	LitLamps=table.freeze({[2]=true,[3]=true,[7]=true}),
})
