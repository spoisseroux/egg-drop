-- One small activity beside the existing hub; no world expansion.
local Layout = {
    FloorY = 4.025,
    Toy = Vector3.new(-2, 4.025, -9),
    Lawn = Vector3.new(-2, 4.025, -4),
    ToyWest = Vector3.new(-4.4, 4.025, -7.7),
    ToyEast = Vector3.new(.4, 4.025, -7.7),
    Rest = Vector3.new(-5, 4.025, -3),
    DecisionInterval = .5,
    ObserverDistance = 72,
    ObserverCap = 6,
}
return table.freeze(Layout)
