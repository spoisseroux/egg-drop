-- Read-only actual built lounge geometry. Run from real Client or Server after the lounge loads.
-- Standard client,parent args are ignored; optional third argument accepts an isolated built lounge.
return function(_client,_parent,providedLounge)
 local lounge=providedLounge or workspace:FindFirstChild("EggDropLounge");assert(lounge,"built lounge required")
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function near(a,b,label)assert(math.abs(a-b)<.0001,(label or"dimension").." actual="..a.." expected="..b)end
 local function vector(a,b,label)assert((a-b).Magnitude<.0001,(label or"vector").." actual="..tostring(a).." expected="..tostring(b))end
 local function all(name)local found={};for _,node in ipairs(lounge:GetChildren())do if node.Name==name then table.insert(found,node)end end;return found end
 local function part(name)local value=lounge:FindFirstChild(name);assert(value and value:IsA("BasePart"),name);return value end
 local function prompt(node,kind,caption,reach,offset)
  local p=node:FindFirstChildOfClass("ProximityPrompt");assert(p and p:GetAttribute("PocketClubStation")==kind)
  assert(p.ActionText==caption and p.ObjectText=="" and p.Style==Enum.ProximityPromptStyle.Default)
  assert(p.KeyboardKeyCode==Enum.KeyCode.E and p.GamepadKeyCode==Enum.KeyCode.ButtonX and p.ClickablePrompt and p.HoldDuration==0)
  assert(not p.RequiresLineOfSight and p.Exclusivity==Enum.ProximityPromptExclusivity.OnePerButton)
  near(p.MaxActivationDistance,reach,"prompt reach");assert(p.UIOffset==offset)
 end
 test("playable floor and boundaries retain original route/collision dimensions",function()
  local f=part("Floor");vector(f.Size,Vector3.new(112,1,96));vector(f.Position,Vector3.new(0,3.5,0));assert(f.CanCollide and f.CanQuery and not f.CanTouch)
  assert(f:GetAttribute("PlayableWidth")==112 and f:GetAttribute("PlayableDepth")==96)
  local boundaries=all("GardenBoundary");assert(#boundaries==4);for _,b in ipairs(boundaries)do assert(b.CanCollide and b.CanQuery and b.Transparency==1);near(b.Position.Y,12)end
 end)
 test("both service surfaces rise1.10 to6.63 while centers and solid dimensions stay fixed",function()
  for _,data in ipairs({{"CustomizeTop",-11},{"JournalTop",11}})do local p=part(data[1]);vector(p.Position,Vector3.new(data[2],6.51,-6.3));vector(p.Size,Vector3.new(5.15,.24,2.25));near(p.Position.Y+p.Size.Y*.5,6.63,"upper surface");assert(p.CanCollide and p.CanQuery and not p.CanTouch)end
 end)
 test("four table supports extend upward from their originalY4 floor anchors",function()
  local legs=all("TableLeg");assert(#legs==4)
  for _,p in ipairs(legs)do vector(p.Size,Vector3.new(.34,2.42,1.62));near(p.Position.Y,5.21);near(p.Position.Y-p.Size.Y*.5,4);near(p.Position.Y+p.Size.Y*.5,6.42);near(p.Position.Z,-6.3);assert(p.CanCollide and p.CanQuery)
   local owner=if p.Position.X<0 then -11 else 11;near(math.abs(p.Position.X-owner),2.05)
  end
 end)
 test("station signs keep their mounted labels and lift with their tabletops",function()
  for _,data in ipairs({{"CustomizeSign",-11,"Deck workbench"},{"JournalSign",11,"Field journal"}})do
   local p=part(data[1]);vector(p.Position,Vector3.new(data[2],7.3,-7.2));vector(p.Size,Vector3.new(4.65,.68,.18));assert(not p.CanCollide and not p.CanQuery)
   local gui=p:FindFirstChildOfClass("SurfaceGui");assert(gui and gui.Face==Enum.NormalId.Back and gui:FindFirstChildOfClass("TextLabel").Text==data[3])
  end
 end)
 test("book cover and every detail share one lift without doubled local offsets",function()
  local cover=part("FieldGuideCover");vector(cover.Position,Vector3.new(11,6.93,-6.15));near(cover.CFrame.UpVector.Y,math.cos(math.rad(18)))
  local stands=all("FieldGuideStand");assert(#stands==2);for _,s in ipairs(stands)do near(s.Position.Y,6.77);near(math.abs(s.Position.X-11),.78)end
  local spine=part("FieldGuideSpine");vector(cover.CFrame:PointToObjectSpace(spine.Position),Vector3.new(0,.12,0))
  local pages=all("FieldGuidePage");assert(#pages==2);for _,p in ipairs(pages)do local localPoint=cover.CFrame:PointToObjectSpace(p.Position);near(math.abs(localPoint.X),.55);near(localPoint.Y,.12);near(localPoint.Z,0)end
  local seals,ink=all("FieldGuideFamilySeal"),all("FieldGuideInk");assert(#seals==4 and #ink==4)
  for _,p in ipairs(seals)do local localPoint=cover.CFrame:PointToObjectSpace(p.Position);near(math.abs(localPoint.X),.55);near(localPoint.Y,.17);assert(math.abs(localPoint.Z+.34)<.0001 or math.abs(localPoint.Z-.18)<.0001)end
  for _,p in ipairs(ink)do near(cover.CFrame:PointToObjectSpace(p.Position).Y,.17)end
  vector(cover.CFrame:PointToObjectSpace(part("FieldGuideRibbon").Position),Vector3.new(.32,.10,.78))
 end)
 test("workbench awning lifts coherently with planted supports and no new collision",function()
  local posts=all("AwningPost");assert(#posts==2);for _,p in ipairs(posts)do near(p.Position.Y,6.35);near(p.Size.Y,4.7);near(p.Position.Y-p.Size.Y*.5,4);near(p.Position.Y+p.Size.Y*.5,8.7);assert(not p.CanCollide and not p.CanQuery)end
  local canopy=part("CanvasAwning");vector(canopy.Position,Vector3.new(-11,8.65,-6.9));vector(canopy.Size,Vector3.new(5.65,.12,2.35));near(canopy.CFrame.UpVector.Y,math.cos(math.rad(-9)));assert(not canopy.CanCollide and not canopy.CanQuery)
 end)
 test("display deck and its physical controls remain seated on the lifted workbench",function()
  local deck=part("DisplayDeck");vector(deck.Position,Vector3.new(-11.2,6.87,-6));vector(deck.Size,Vector3.new(1.02,.47,.15));near(deck.Position.Y-deck.Size.Y*.5-(part("CustomizeTop").Position.Y+.12),.005)
  for _,name in ipairs({"DisplayLCD","DisplayRocker","DisplayA"})do local p=part(name);near(p.Position.Y,6.87);assert(not p.CanCollide and not p.CanQuery)end
  near(part("DisplayLCD").Position.X-deck.Position.X,0);near(part("DisplayRocker").Position.X-deck.Position.X,-.33);near(part("DisplayA").Position.X-deck.Position.X,.33)
 end)
 test("three short native prompts keep originalE/X/touch routes and reach",function()
  prompt(part("CustomizeTop"),"Customize","Style deck",7,Vector2.new(112,-12));prompt(part("JournalTop"),"Journal","Open journal",7,Vector2.new(72,-12));prompt(part("EggsSign"),"Eggs","Browse eggs",5,Vector2.new(72,-16))
 end)
 test("nest bridges and stepping route remain at original physical seats",function()
  local nest=part("HatchTop");vector(nest.Position,Vector3.new(0,4.115,-5));vector(nest.Size,Vector3.new(5.8,.23,4.6));assert(nest.CanCollide and nest.CanQuery)
  vector(part("EggsSign").Position,Vector3.new(0,5.5,-3.5));local stones=all("SteppingStone");assert(#stones==18)
  for _,p in ipairs(stones)do near(p.Position.Y,4.026);near(p.Size.Y,.13);assert(not p.CanCollide and not p.CanQuery)end
  local bridge=all("BridgePlank");assert(#bridge==11);for _,p in ipairs(bridge)do near(p.Position.Y,4.25);assert(p.CanCollide and p.CanQuery)end
 end)
 return{passed=#cases,cases=cases}
end
