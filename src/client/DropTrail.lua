-- Drop trail (deck juice, V3-LEVELS-BUILD-PLAN-2026-11-22 S3): bubbles or a comet tail behind the ball
-- that was just dropped. Cosmetic: it only reads where the ball is drawn; the sim, score, RNG, board
-- hash and input never read or wait on it. FieldEffects owns it and makes it only for a chosen trail,
-- so classic costs nothing. Twelve pooled pieces, the oldest reused first; a drop makes no Instances,
-- tables or tweens. Cut under Reduced Motion and at AliveBudget level 2.
local Budget=require(script.Parent.AliveBudget)
local Trail={};Trail.__index=Trail
Trail.Pieces=12
Trail.LaunchBand=4 -- studs under the launch point: a ball first drawn in here was just dropped
Trail.HandoffReach=2.5 -- studs: the predicted ball's server copy takes the trail over
Trail.MaxFollow=1.1 -- seconds behind one ball
Trail.Settle=.1 -- seconds without falling: it has landed
Trail.Ink=Color3.fromHex("#142D20")
-- life: seconds a piece lives. step: how far the ball falls between pieces, in ball radii.
Trail.Styles=table.freeze({
 bubble=table.freeze({life=.55,step=.8,fill=table.freeze({Color3.fromHex("#E4FBFF"),Color3.fromHex("#A9E8FF"),Color3.fromHex("#FFFFFF")})}),
 comet=table.freeze({life=.36,step=.42,fill=table.freeze({Color3.fromHex("#FFF3B0"),Color3.fromHex("#FFC23D"),Color3.fromHex("#FF8FB4")})}),
})
-- Pure. `reduced`: Reduced Motion or Motion: Low. `level`: AliveBudget's step-down.
function Trail.allowed(reduced,level)return reduced~=true and(level or 0)<Budget.MaxLevel end
-- Pure: was a ball first drawn at height `y` (studs) just dropped?
function Trail.isLaunch(y,launchY)return y>=launchY-Trail.LaunchBand end
-- Pure: piece `k` (1..12) at `t` (0..1) of its life: x and y offset and diameter in ball radii,
-- then transparency. Numbers only: nothing is allocated.
function Trail.pose(style,k,t)
 if style=="comet"then
  -- A tail that tapers and burns out where it was left.
  return 0,0,(.95-.12*(k%3))*(1-t)^.8+.08,.05+.95*t*t
 end
 -- Bubbles wobble up and swell, then pop.
 local pop=math.clamp((t-.82)/.18,0,1)
 return math.sin(t*6+k*1.9)*.28+((k%3)-1)*.3,-.9*t,(.34+.1*(k%3))*(.6+.4*math.min(1,t*4))*(1+.35*pop),.12+.88*pop
end
local function put(object,key,value)if object[key]~=value then object[key]=value end end

-- parent: the clipped effects layer. options: views ({[source]={tier}} as drawn), launchY (studs),
-- project(Vector2 studs) -> point px, px per stud.
function Trail.new(parent,options)
 local self=setmetatable({pieces={},views=options.views,project=options.project,launchY=options.launchY,
  visible=false,reduced=false,active=0,head=0,source=nil,style=nil,stats={followed=0,emitted=0}},Trail)
 for i=1,Trail.Pieces do
  local frame=Instance.new("Frame");frame.Name="Trail"..i;frame.BorderSizePixel=0;frame.Active,frame.Selectable=false,false
  frame.AnchorPoint=Vector2.new(.5,.5);frame.ZIndex=5;frame.Visible=false;frame.Parent=parent
  local round=Instance.new("UICorner");round.CornerRadius=UDim.new(.5,0);round.Parent=frame
  local stroke=Instance.new("UIStroke");stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;stroke.Thickness=1.5;stroke.Color=Trail.Ink;stroke.Parent=frame
  self.pieces[i]={frame=frame,stroke=stroke,active=false,x=0,y=0,r=0,at=0}
 end
 return self
end
function Trail:clear()
 self.source=nil
 if self.active==0 then return end
 for _,piece in ipairs(self.pieces)do piece.active=false;put(piece.frame,"Visible",false)end
 self.active=0
end
-- nil or an unknown id draws nothing.
function Trail:setStyle(id)
 local style=if type(id)=="string"then Trail.Styles[id]else nil
 id=if style then id else nil
 if self.style==id then return end
 self:clear();self.style=id
 if style then
  for k,piece in ipairs(self.pieces)do put(piece.frame,"BackgroundColor3",style.fill[(k-1)%#style.fill+1])end
 end
end
function Trail:setOwner(visible,reduced)
 if self.visible~=visible or self.reduced~=reduced then self:clear()end
 self.visible,self.reduced=visible,reduced
end
local function follow(self,source,now)
 local at=source.Position
 self.source,self.sx,self.sy=source,at.X,at.Y
 local point=self.project(Vector2.new(at.X,at.Y))
 self.y,self.lastX,self.lastY=point.Y,point.X,point.Y
 self.fellAt=now
end
-- A ball's view was just made. Only one that starts at the launch point gets the trail.
function Trail:added(source,now)
 if self.destroyed or not self.style or not self.visible then return false end
 if not Trail.isLaunch(source.Position.Y,self.launchY)or not Trail.allowed(self.reduced,Budget.level())then return false end
 local view=self.views[source];self.tier=view and view.tier
 follow(self,source,now);self.startedAt=now
 self.stats.followed+=1
 return true
end
-- The drawn ball changed hands (a predicted ball became the server's): the nearest of its tier.
function Trail:handoff(now)
 local best,distance=nil,Trail.HandoffReach
 for source,view in pairs(self.views)do
  if view.tier==self.tier then
   local at=source.Position;local dx,dy=at.X-self.sx,at.Y-self.sy
   local d=math.sqrt(dx*dx+dy*dy)
   if d<distance then best,distance=source,d end
  end
 end
 if best then follow(self,best,now)else self.source=nil end
 return best
end
-- Once per presented frame. `now` is the host's clock.
function Trail:step(now)
 if self.destroyed or not self.visible or(self.source==nil and self.active==0)then return end
 local style=Trail.Styles[self.style]
 if not style then self:clear();return end
 local source=self.source
 if source and self.views[source]==nil then source=self:handoff(now)end
 if source and now-self.startedAt>Trail.MaxFollow then self.source=nil;source=nil end
 if source then
  local at=source.Position;self.sx,self.sy=at.X,at.Y
  local point,scale=self.project(Vector2.new(at.X,at.Y))
  local r=math.max(3,source.Size.X/2*scale)
  local fell=point.Y-self.y
  self.y=point.Y
  if fell>0 then self.fellAt=now end
  if fell<-1 or now-self.fellAt>Trail.Settle then
   self.source=nil -- bounced or landed
  else
   local dx,dy=point.X-self.lastX,point.Y-self.lastY
   local moved=math.sqrt(dx*dx+dy*dy)
   if moved>=style.step*r then
    self.head=self.head%Trail.Pieces+1
    local piece=self.pieces[self.head]
    if not piece.active then piece.active=true;self.active+=1 end
    -- On the ball's trailing edge, so its face stays clear.
    piece.x,piece.y,piece.r,piece.at=point.X-dx/moved*r*.95,point.Y-dy/moved*r*.95,r,now
    self.lastX,self.lastY=point.X,point.Y
    self.stats.emitted+=1
   end
  end
 end
 for k,piece in ipairs(self.pieces)do if piece.active then
  local t=(now-piece.at)/style.life
  local frame=piece.frame
  if t>=1 then piece.active=false;self.active-=1;put(frame,"Visible",false)
  else
   local ox,oy,size,fade=Trail.pose(self.style,k,math.max(0,t))
   local d=math.max(3,size*piece.r)
   put(frame,"Position",UDim2.fromOffset(piece.x+ox*piece.r,piece.y+oy*piece.r))
   put(frame,"Size",UDim2.fromOffset(d,d))
   put(frame,"BackgroundTransparency",fade);put(piece.stroke,"Transparency",math.min(1,.25+.75*fade))
   put(frame,"Visible",true)
  end
 end end
end
function Trail:destroy()
 if self.destroyed then return end
 self:clear();self.destroyed=true
 for _,piece in ipairs(self.pieces)do piece.frame:Destroy()end
end
return Trail
