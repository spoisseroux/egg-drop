-- One soft garden ball; decorative and entirely driven by the shared sample.
local Toy={};Toy.__index=Toy
function Toy.new(parent,origin)
 local part=Instance.new("Part");part.Name="GardenBall";part.Shape=Enum.PartType.Ball;part.Size=Vector3.one*.62
 part.Color=Color3.fromHex("#F5B77C");part.Material=Enum.Material.SmoothPlastic;part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false
 part.Position=origin+Vector3.new(0,.31,0);part.Parent=parent
 return setmetatable({part=part,origin=origin,visible=true},Toy)
end
function Toy:setVisible(visible)
 visible=visible==true;if self.visible==visible then return end
 self.visible=visible;self.part.Transparency=if visible then 0 else 1
end
function Toy:update(sample,dt,reduced)
 if not sample or not self.visible then return end
 local position=if reduced then sample.basePosition or self.origin else sample.position or self.origin
 local tilt=if reduced then 0 else sample.tilt or 0
 local cf=CFrame.new(position+Vector3.new(0,.31,0))*CFrame.Angles(tilt,if reduced then 0 else sample.rotation or 0,0)
 if self.lastFrame~=cf then self.part.CFrame=cf;self.lastFrame=cf end
end
function Toy:destroy()self.part:Destroy()end
return Toy
