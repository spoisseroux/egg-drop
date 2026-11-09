-- Rooted original feature clusters; scale is head width, front is +Z.
local Prop=require(script.Parent.PetPropGeometry)
local Features={}
local ivory=Color3.fromHex("#F4EDCD")
function Features.create(parent,id,stage,scale,secondary,side)
 if(id~="horns"and id~="claws"and id~="wings")or type(stage)~="number"or stage%1~=0 or stage<1 or stage>5 then return nil end
 local h=Prop.new(parent,"PetFeature_"..id.."_"..stage,scale);h.id,h.stage=id,stage
 secondary=if typeof(secondary)=="Color3"then secondary else Color3.fromHex("#89C8BD")
 local extension=stage/5;local sides=if side==-1 or side==1 then {side}else{-1,1}
 for _,sign in ipairs(sides)do
  local root=if side then Vector3.zero else Vector3.new(sign*(if id=="horns"then .26 elseif id=="claws"then .20 else .10),0,0)
  if id=="horns"then
   h:add("HornCollar"..sign,Vector3.new(.091,.034,.082),CFrame.new(root+Vector3.new(0,.012,0)),secondary,"sphere")
   local previous=root+Vector3.new(0,.025,0)
   for n=1,3 do
    local u=n/3;local point=root+Vector3.new(sign*.06*extension*u*u,.025+.22*extension*u,-.055*extension*u*u)
    local delta=point-previous;local radius=.067*(1-u*.72)
    local center=(previous+point)*.5
    h:add("RoundedHorn"..sign.."_"..n,Vector3.new(radius,delta.Magnitude+.018,radius),CFrame.lookAt(center,point)*CFrame.Angles(math.pi/2,0,0),ivory,"sphere")
    previous=point
   end
  elseif id=="claws"then
   for nail=-1,1,2 do
    local base=root+Vector3.new(nail*.028,.018,0)
    h:add("ClawBase"..sign..nail,Vector3.new(.043,.029,.049),CFrame.new(base),secondary,"sphere")
    h:add("RoundedClaw"..sign..nail,Vector3.new(.037,.033,.035+.11*extension),CFrame.new(base+Vector3.new(0,.006,.025+.055*extension))*CFrame.Angles(-.12,0,0),ivory,"sphere")
   end
  else
   h:add("PlushWingRoot"..sign,Vector3.new(.07,.092,.042),CFrame.new(root+Vector3.new(sign*.018,.035,0)),secondary,"sphere")
   for leaf=1,3 do
    local length=.055+.24*extension*(1-(leaf-1)*.13)
    local center=root+Vector3.new(sign*length*.44,.025+leaf*.025*extension,-.014*leaf)
    h:add("FoldedFan"..sign..leaf,Vector3.new(length,.055+.044*extension,.034),CFrame.new(center)*CFrame.Angles(0,sign*.16,sign*(.18+leaf*.22)),if leaf==1 then ivory else secondary,"sphere")
   end
  end
 end
 return h
end
return Features
