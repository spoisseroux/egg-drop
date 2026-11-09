-- Existing hub anchors remain fixed while a second dry rest lawn is added.
local World=require(script.Parent.HollowWorldLayout)
local nook=Vector3.new(26,4.175,-15.5)
local Layout = {
    FloorY = 4.025,
    Toy = Vector3.new(-2, 4.025, 17.5),
    Lawn = Vector3.new(-2, 4.025, 12.5),
    ToyWest = Vector3.new(-4.4, 4.025, 17.5),
    ToyEast = Vector3.new(.4, 4.025, 17.5),
    Rest = Vector3.new(-5, 4.025, 11.5),
    Nook = nook,
    RestAnchors = table.freeze({
        table.freeze({id="creek_nook",position=nook}),
        table.freeze({id="spring_meadow_west",position=World.Spring.RestWest,exclusive=true}),
        table.freeze({id="spring_meadow_east",position=World.Spring.RestEast,exclusive=true}),
    }),
    DecisionInterval = .5,
    WalkSpeed = 4,
    CatchupSpeed = 9,
    LeashSpeed = 18,
    StrollSpeed = 3,
    ObserverDistance = 72,
    ObserverCap = 6,
}
return table.freeze(Layout)
