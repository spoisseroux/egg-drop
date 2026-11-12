-- Single prototype bay at the Journal station. Art remains independently authored.
-- v7: the Care Cradle (stations.json); the pet sole sits on the cradle cushion
-- top (Blender z 2.21) and the player approaches from the cradle's open front.
local World=require(script.Parent.HollowWorldLayout)
if World.WorldVersion=="v7"then
 local station=World.Stations.Journal
 local front=station.LookVector*-1 -- the station's local +Z
 local dock=Vector3.new(station.X,6.21,station.Z)
 local approach=dock+front*3.2
 return table.freeze({BayId="journal_care",Prompt=Vector3.new(station.X,5.6,station.Z)+front*.8,Dock=dock,
  Approach=Vector3.new(approach.X,World.groundY(approach.X,approach.Z)+.025,approach.Z),Reach=7,LeaveReach=10,LeaseSeconds=3,PlacedReach=5,
  Footprint=Vector3.new(1.9,2.9,1.9)})
end
return table.freeze({BayId="journal_care",Prompt=Vector3.new(11,6.51,-6.3),Dock=Vector3.new(11.75,5.18,-4.20),
 Approach=Vector3.new(11.75,4.025,-1.60),Reach=7,LeaveReach=10,LeaseSeconds=3,PlacedReach=5,
 Footprint=Vector3.new(1.9,2.9,1.9)})
