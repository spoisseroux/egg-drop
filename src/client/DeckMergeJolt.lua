-- Astra's single held recoil. Decorative nodes only; simulation/input are never transformed.
local Recipe=require(script.Parent.CareFeedbackData).jolt
local Jolt={};Jolt.__index=Jolt
local peak=0;for _,key in ipairs(Recipe.keys)do peak=math.max(peak,Vector2.new(key[2],key[3]).Magnitude)end
function Jolt.new(nodes)
 local self=setmetatable({nodes={},seen={},ring={},cursor=0,offset=Vector2.zero},Jolt)
 for _,node in ipairs(nodes)do table.insert(self.nodes,{node=node,base=node.Position})end
 return self
end
function Jolt:reset()
 self.active=nil;self.offset=Vector2.zero
 for _,entry in ipairs(self.nodes)do if entry.node.Parent then entry.node.Position=entry.base end end
end
function Jolt:rebase()
 self.active=nil;self.offset=Vector2.zero
 for _,entry in ipairs(self.nodes)do entry.base=entry.node.Position end
end
function Jolt:setOwner(visible,serial,reduced)
 if self.visible~=visible or self.serial~=serial or self.reduced~=reduced then self:reset()end
 if self.serial~=serial then table.clear(self.seen);table.clear(self.ring);self.cursor=0 end
 self.visible,self.serial,self.reduced=visible,serial,reduced
end
function Jolt:emit(serial,id,tier,chain,cleared,now)
 if self.destroyed or not self.visible or self.serial~=serial or self.reduced or(type(id)~="number"and type(id)~="string")or self.seen[id]then return false end
 self.cursor=self.cursor%64+1;local old=self.ring[self.cursor];if old~=nil then self.seen[old]=nil end
 self.ring[self.cursor],self.seen[id]=id,true
 local entry=if cleared then Recipe.clear elseif tier>=5 then Recipe.tierV elseif tier==4 then Recipe.tierIV elseif tier==3 then Recipe.tierIII else Recipe.tierII
 local amplitude=math.min(Recipe.peakPixels,entry[1]*(if chain>1 then Recipe.chainScale else 1))
 if self.active and now-self.active.at<self.active.duration and amplitude<self.active.amplitude then return false end
 self.active={at=now,duration=entry[2],amplitude=amplitude};return true
end
function Jolt:update(now)
 local active=self.active
 if not active then return end
 local t=math.clamp((now-active.at)/active.duration,0,1)
 if t>=1 then self:reset();return end
 local x,y=0,0
 for i=2,#Recipe.keys do local a,b=Recipe.keys[i-1],Recipe.keys[i]
  if t<=b[1]then local u=(t-a[1])/(b[1]-a[1]);u=u*u*(3-2*u);x=a[2]+(b[2]-a[2])*u;y=a[3]+(b[3]-a[3])*u;break end
 end
 local offset=Vector2.new(x,y)*(active.amplitude/peak);self.offset=offset
 for _,entry in ipairs(self.nodes)do if entry.node.Parent then entry.node.Position=entry.base+UDim2.fromOffset(offset.X,offset.Y)end end
end
function Jolt:destroy()if self.destroyed then return end;self:reset();self.destroyed=true;table.clear(self.nodes)end
return Jolt
