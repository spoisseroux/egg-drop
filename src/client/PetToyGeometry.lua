-- Original +Z-facing personal props, normalized to one pet body-height.
local Prop=require(script.Parent.PetPropGeometry)
local Toys={}
local indigo=Color3.fromHex("#333C78");local brass=Color3.fromHex("#C69A45");local citrine=Color3.fromHex("#F6D759")
function Toys.create(parent,id,scale)
 if id~="sparkler"and id~="ball"and id~="bone"then return nil end
 local h=Prop.new(parent,"PersonalToy_"..id,scale);h.id=id
 if id=="sparkler"then
  h:add("IndigoGrip",Vector3.new(.052,.17,.052),CFrame.new(0,-.065,0)*CFrame.Angles(0,0,-.10),indigo,"sphere")
  h:add("OffsetBrassWire",Vector3.new(.016,.12,.016),CFrame.new(.018,.074,0)*CFrame.Angles(0,0,-.24),brass,"sphere")
  for i=-1,1 do h:add("SeedProng"..i,Vector3.new(.025,.082,.025),CFrame.new(.025+i*.026,.145+math.abs(i)*-.015,0)*CFrame.Angles(0,0,-i*.55),citrine,"sphere")end
  h.sparks={}
  for i=1,3 do
   local p=h:add("Spark_"..i,Vector3.new(.014,.043,.012),CFrame.new(.025+(i-2)*.052,.213+(i%2)*.025,.008)*CFrame.Angles(0,0,(i-2)*.5),Color3.fromHex("#FFE9A6"),"sphere")
   table.insert(h.sparks,p)
  end
 elseif id=="ball"then
  h:add("CoralBall",Vector3.new(.24,.24,.24),CFrame.identity,Color3.fromHex("#EF786B"),"sphere")
  h:add("OffsetCreamEquator",Vector3.new(.244,.055,.244),CFrame.new(0,.018,0)*CFrame.Angles(0,0,.18),Color3.fromHex("#FFF0C9"),"sphere")
  h:add("TealDimple",Vector3.new(.048,.043,.012),CFrame.new(.045,.039,.116),Color3.fromHex("#327E83"),"sphere")
 else
  h:add("OchreWaist",Vector3.new(.21,.061,.064),CFrame.identity,Color3.fromHex("#C9954A"),"sphere")
  for _,side in ipairs({-1,1})do for _,lobe in ipairs({-1,1})do
   h:add("SeafoamLobe"..side..lobe,Vector3.new(.075,.065,.067),CFrame.new(side*.12,lobe*.026,0)*CFrame.Angles(0,0,side*lobe*.2),Color3.fromHex("#9CE0CC"),"sphere")
  end end
  h:add("OffcenterWrap",Vector3.new(.045,.074,.075),CFrame.new(.027,0,0)*CFrame.Angles(0,0,.16),Color3.fromHex("#E9D29A"),"sphere")
  h:add("WrapNotch",Vector3.new(.013,.018,.008),CFrame.new(.025,.018,.038),Color3.fromHex("#936B3B"),"sphere")
 end
 return h
end
return Toys
