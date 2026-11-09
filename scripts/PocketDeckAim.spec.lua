-- Inspect the real PocketDeck after actual pointer / keyboard / D-pad input.
-- Read-only: no requests, input injection, profile or board mutation.
return function(gui,board)
 local Config=require(game.ReplicatedStorage.Shared.BoardConfig)
 local tray=gui.Backdrop.Tray
 local overlay=gui.Backdrop.TrayOverlay
 local pivot=overlay.Guide;local nozzle=overlay.NextEgg
 local cases={}
 local function test(name,run)run();table.insert(cases,name)end
 local function project(point)
  local scale=tray.AbsoluteSize.X/(Config.Width+.8)
  return Vector2.new(tray.AbsoluteSize.X/2+point.X*scale,tray.AbsoluteSize.Y/2-(point.Y-Config.Height/2)*scale)
 end
 local origin=project(Config.launchPosition())
 local aim=.5-math.rad(pivot.Rotation)/(2*math.rad(Config.LaunchAngleDegrees))
 test("actual nozzle and rotation center share the fixed launch projection",function()
  assert(pivot.Size==UDim2.fromOffset(0,0)and pivot.AnchorPoint==Vector2.new(.5,.5),"guide rotates about an offset center")
  local point=Vector2.new(pivot.Position.X.Offset,pivot.Position.Y.Offset)
  assert((point-origin).Magnitude<1 and(nozzle.AbsolutePosition+nozzle.AbsoluteSize/2-overlay.AbsolutePosition-origin).Magnitude<1)
  assert(pivot.Tangent.AnchorPoint==Vector2.new(.5,0)and pivot.Tangent.Position==UDim2.fromOffset(0,0))
  assert(aim>=-.0001 and aim<=1.0001,"visual angle outside legal normalized range")
 end)
 test("real fallback guide dots use the same gravity and launch direction at current angle",function()
  for index=1,Config.PreviewCount do
   local dot=overlay["FlightDot"..index];local expected=project(Config.flightPoint(aim,index*Config.PreviewStep))
   -- Native offset components truncate independently, so a diagonal can
   -- differ by almost sqrt(2) pixels while each component is correct.
   local delta=Vector2.new(dot.Position.X.Offset,dot.Position.Y.Offset)-expected
   assert(math.abs(delta.X)<1.001 and math.abs(delta.Y)<1.001,"flight sample disagrees with shared physics")
  end
 end)
 test("real objective markers are 2px thresholds with no left right or center fill",function()
  local host=assert(gui:FindFirstChild("TargetRegions",true))
  for _,name in ipairs({"LeftThreshold","RightThreshold"})do
   local line=host[name];assert(line.Size.X.Scale==0 and line.Size.X.Offset==2 and not line.Active and not line.Selectable)
   assert(line.ZIndex<nozzle.ZIndex,"threshold covers pieces")
  end
  local center=host.CenterGoalRegion;assert(center.BackgroundTransparency==1)
  assert(center.Min.Size.X.Offset==2 and center.Max.Size.X.Offset==2)
 end)
 return{passed=#cases,cases=cases,normalizedAim=aim,pivot={x=origin.X,y=origin.Y},tier=board:GetAttribute("NextTier"),persistentWrites=false}
end
