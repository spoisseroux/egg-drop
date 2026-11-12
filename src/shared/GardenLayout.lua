-- Garden anchors for the active world (HollowWorldLayout.WorldVersion).
-- Legacy: the original hub anchors with a second dry rest lawn.
-- v7: the toy lawn beside the hub plaza and the three nap daises.
local World=require(script.Parent.HollowWorldLayout)
local Layout
if World.WorldVersion=="v7"then
	local toy=World.Stations.ToyLawn
	local function lawn(x,z)return Vector3.new(x,World.groundY(x,z)+.025,z)end
	local front=toy.Position+Vector3.new(0,0,4.5)
	Layout={
		FloorY=World.FloorTop+.025,
		Toy=lawn(front.X,front.Z),
		Lawn=lawn(front.X,front.Z+4),
		ToyWest=lawn(front.X-2.4,front.Z),
		ToyEast=lawn(front.X+2.4,front.Z),
		Rest=lawn(front.X-3,front.Z+5),
		Nook=World.Rest.CreekNook,
		RestAnchors=table.freeze({
			table.freeze({id="creek_nook",position=World.Rest.CreekNook}),
			table.freeze({id="spring_meadow_west",position=World.Rest.SpringRestWest,exclusive=true}),
			table.freeze({id="spring_meadow_east",position=World.Rest.SpringRestEast,exclusive=true}),
		}),
	}
else
	local nook=Vector3.new(26,4.175,-15.5)
	Layout={
		FloorY=4.025,
		Toy=Vector3.new(-2,4.025,17.5),
		Lawn=Vector3.new(-2,4.025,12.5),
		ToyWest=Vector3.new(-4.4,4.025,17.5),
		ToyEast=Vector3.new(.4,4.025,17.5),
		Rest=Vector3.new(-5,4.025,11.5),
		Nook=nook,
		RestAnchors=table.freeze({
			table.freeze({id="creek_nook",position=nook}),
			table.freeze({id="spring_meadow_west",position=World.Spring.RestWest,exclusive=true}),
			table.freeze({id="spring_meadow_east",position=World.Spring.RestEast,exclusive=true}),
		}),
	}
end
Layout.DecisionInterval=.5
Layout.WalkSpeed=4
Layout.CatchupSpeed=9
Layout.LeashSpeed=18
Layout.StrollSpeed=3
Layout.ObserverDistance=72
Layout.ObserverCap=6
-- Ground under (x, z) plus the pet sole offset, and whether an anchor stands
-- on the bare ground rather than a bench, stair, knoll or terrace.
function Layout.groundAt(x,z)return World.groundY(x,z)+.025 end
function Layout.onGround(anchor)return anchor.Y<=Layout.groundAt(anchor.X,anchor.Z)+.6 end
return table.freeze(Layout)
