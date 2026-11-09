-- One shared activity on the grass beyond the benches; no world expansion.
local Layout = {
    FloorY = 4.025,
    Toy = Vector3.new(-2, 4.025, 17.5),
    Lawn = Vector3.new(-2, 4.025, 12.5),
    ToyWest = Vector3.new(-4.4, 4.025, 17.5),
    ToyEast = Vector3.new(.4, 4.025, 17.5),
    Rest = Vector3.new(-5, 4.025, 11.5),
    Nook = Vector3.new(26,4.175,-15.5),
    DecisionInterval = .5,
    WalkSpeed = 4,
    CatchupSpeed = 9,
    LeashSpeed = 18,
    StrollSpeed = 3,
    ObserverDistance = 72,
    ObserverCap = 6,
}
return table.freeze(Layout)
