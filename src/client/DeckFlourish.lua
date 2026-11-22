-- Start flourish (deck juice, V3-LEVELS-BUILD-PLAN-2026-11-22 S3): a one second lid animation on the
-- deck screen when a round begins. Cosmetic and never in the way: nothing here is Active, no input,
-- sim, score or clock reads or waits on it, and the first drop cuts it at once. FieldEffects owns it
-- and makes it only for a chosen flourish, so classic costs nothing. Cut under Reduced Motion and at
-- AliveBudget level 2. Once per round serial; a round start makes no Instances, tables or tweens.
local Budget=require(script.Parent.AliveBudget)
local Flourish={};Flourish.__index=Flourish
Flourish.Duration=1
Flourish.Wait=2 -- seconds a round start waits for the deck boot; then it is skipped
Flourish.LidHeight=.15 -- of the screen
Flourish.Ink=Color3.fromHex("#142D20")
Flourish.Cream=Color3.fromHex("#FFF4D6")
-- drop: the lids fall shut in this long. open, opened: they slide apart between these times.
Flourish.Styles=table.freeze({
 ready=table.freeze({drop=.12,open=.66,opened=.9,lid=Color3.fromHex("#FFD35C"),edge=Color3.fromHex("#C98A1B")}),
 lightning=table.freeze({drop=.1,open=.42,opened=.56,lid=Color3.fromHex("#4F7BFF"),edge=Color3.fromHex("#2546B8")}),
})
Flourish.LampAt=table.freeze({.18,.36,.54})
Flourish.LampOn=table.freeze({Color3.fromHex("#FFF1A8"),Color3.fromHex("#FFF1A8"),Color3.fromHex("#5FE39A")})
Flourish.LampOff=Color3.fromHex("#5A6B62")
Flourish.Bolt=Color3.fromHex("#FFF3A0")
-- The bolt, top to bottom: x (of the screen), y and length (of the lid), degrees.
Flourish.BoltParts=table.freeze({table.freeze({.515,.2,.5,24}),table.freeze({.485,.52,.46,-38}),table.freeze({.505,.82,.5,20})})
Flourish.BoltAt=.16
Flourish.Sparks=6

-- Pure. `reduced`: Reduced Motion or Motion: Low. `level`: AliveBudget's step-down.
function Flourish.allowed(reduced,level)return reduced~=true and(level or 0)<Budget.MaxLevel end
-- Pure: the lid at `age` seconds: how far it has fallen shut (0..1), how far it is open (0..1).
function Flourish.lid(style,age)
 local s=Flourish.Styles[style]
 if not s then return 0,1 end
 local d=math.clamp(age/s.drop,0,1);d=1-(1-d)*(1-d)
 local o=math.clamp((age-s.open)/(s.opened-s.open),0,1)
 o=if style=="lightning"then 1-(1-o)*(1-o)else o*o*(3-2*o)
 return d,o
end
-- Pure: lamps lit at `age` (0..3).
function Flourish.lampsLit(age)
 local lit=0
 for _,at in ipairs(Flourish.LampAt)do if age>=at then lit+=1 end end
 return lit
end
local function put(object,key,value)if object[key]~=value then object[key]=value end end
local function box(parent,name,z,round)
 local f=Instance.new("Frame");f.Name=name;f.BorderSizePixel=0;f.Active,f.Selectable=false,false;f.ZIndex=z;f.Parent=parent
 if round then local c=Instance.new("UICorner");c.CornerRadius=round;c.Parent=f end
 return f
end
local function edge(parent,thickness)
 local s=Instance.new("UIStroke");s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;s.Thickness=thickness;s.Color=Flourish.Ink;s.Parent=parent
 return s
end

-- parent: the clipped effects layer. options.ready() (optional): the screen is bare (no deck boot);
-- options.lidHeight: for a small preview.
function Flourish.new(parent,options)
 local self=setmetatable({ready=options and options.ready,style=nil,playing=false,pending=false,serial=nil,visible=false,
  lidHeight=options and options.lidHeight or Flourish.LidHeight,stats={played=0,cut=0}},Flourish)
 local root=box(parent,"StartFlourish",7);root.BackgroundTransparency=1;root.Size=UDim2.fromScale(1,1);root.Visible=false
 self.root=root
 self.lids={}
 for i=1,2 do
  local lid=box(root,if i==1 then "LidLeft"else "LidRight",7,UDim.new(0,10));lid.Size=UDim2.new(.5,0,self.lidHeight,0);edge(lid,2)
  local lip=box(lid,"Lip",8,UDim.new(0,6));lip.AnchorPoint=Vector2.new(0,1);lip.Position=UDim2.new(0,3,1,-3);lip.Size=UDim2.new(1,-6,.22,0)
  local glint=box(lid,"Glint",8,UDim.new(.5,0));glint.BackgroundColor3=Flourish.Cream;glint.BackgroundTransparency=.35
  glint.Position=UDim2.new(0,8,0,5);glint.Size=UDim2.new(1,-16,0,3)
  self.lids[i]={frame=lid,lip=lip}
 end
 -- Ready, steady: three round lamps across the seam.
 self.lamps={}
 for i=1,3 do
  local lamp=box(root,"Lamp"..i,9,UDim.new(.5,0));lamp.AnchorPoint=Vector2.new(.5,.5);lamp.SizeConstraint=Enum.SizeConstraint.RelativeYY
  lamp.BackgroundColor3=Flourish.LampOff;lamp.Visible=false;edge(lamp,2)
  self.lamps[i]=lamp
 end
 -- Lightning lid: a chunky bolt and its sparks.
 self.bolt={}
 for i,part in ipairs(Flourish.BoltParts)do
  local bar=box(root,"Bolt"..i,9,UDim.new(0,3));bar.AnchorPoint=Vector2.new(.5,.5);bar.BackgroundColor3=Flourish.Bolt;bar.Rotation=part[4]
  bar.Position=UDim2.fromScale(part[1],part[2]*self.lidHeight);bar.Size=UDim2.new(0,8,part[3]*self.lidHeight,0);bar.Visible=false;edge(bar,1.5)
  self.bolt[i]=bar
 end
 self.sparks={}
 for i=1,Flourish.Sparks do
  local spark=box(root,"Spark"..i,9,UDim.new(0,2));spark.AnchorPoint=Vector2.new(.5,.5);spark.BackgroundColor3=Flourish.Bolt;spark.Rotation=45;spark.Visible=false
  self.sparks[i]={frame=spark,stroke=edge(spark,1)}
 end
 return self
end
function Flourish:cancel()
 if self.playing then self.stats.cut+=1 end
 self.playing,self.pending=false,false
 put(self.root,"Visible",false)
end
-- nil or an unknown id plays nothing.
function Flourish:setStyle(id)
 local style=if type(id)=="string"then Flourish.Styles[id]else nil
 id=if style then id else nil
 if self.style==id then return end
 self:cancel();self.style=id
 if not style then return end
 for _,lid in ipairs(self.lids)do lid.frame.BackgroundColor3=style.lid;lid.lip.BackgroundColor3=style.edge end
 for _,lamp in ipairs(self.lamps)do lamp.Visible=id=="ready"end
 for _,bar in ipairs(self.bolt)do bar.Visible=false end
 for _,spark in ipairs(self.sparks)do spark.frame.Visible=false end
end
-- The board's owner state, every frame. `fresh`: this round has had no drop yet.
function Flourish:owner(visible,serial,reduced,fresh)
 if not visible then
  if self.playing or self.pending then self:cancel()end
  return
 end
 if serial==self.serial then
  if reduced and(self.playing or self.pending)then self:cancel()end
  return
 end
 self.serial=serial;self:cancel()
 if fresh and self.style and Flourish.allowed(reduced,Budget.level())then self.pending,self.pendingAt=true,nil end
end
function Flourish:play(now)
 if self.destroyed or not self.style then return false end
 self.pending,self.playing,self.start=false,true,now
 self.stats.played+=1
 self:draw(0);put(self.root,"Visible",true)
 return true
end
function Flourish:update(now)
 if self.destroyed or not(self.playing or self.pending)then return end
 if self.pending then
  self.pendingAt=self.pendingAt or now
  if now-self.pendingAt>Flourish.Wait then self:cancel();return end
  if self.ready and self.ready()~=true then return end
  self:play(now);return
 end
 local age=now-self.start
 if age>=Flourish.Duration then self.playing=false;put(self.root,"Visible",false);return end
 self:draw(age)
end
function Flourish:draw(age)
 local style=self.style
 local dropped,open=Flourish.lid(style,age)
 local y=-(1-dropped)*self.lidHeight
 for i,lid in ipairs(self.lids)do
  put(lid.frame,"Position",UDim2.fromScale(if i==1 then -.53*open else .5+.53*open,y))
 end
 if style=="ready"then
  local lit=Flourish.lampsLit(age)
  for i,lamp in ipairs(self.lamps)do
   put(lamp,"BackgroundColor3",if i<=lit then Flourish.LampOn[i]else Flourish.LampOff)
   -- A lamp swells as it lights; they all shrink away with the lid.
   local since=if i<=lit then age-Flourish.LampAt[i]else 1
   local size=self.lidHeight*.46*(1+.35*math.max(0,1-since/.14))*(1-open)
   put(lamp,"Size",UDim2.fromScale(size,size))
   put(lamp,"Position",UDim2.fromScale(.5+(i-2)*.17,y+self.lidHeight*.46))
   put(lamp,"Visible",open<.98)
  end
  return
 end
 for i,bar in ipairs(self.bolt)do put(bar,"Visible",age>=Flourish.BoltAt+(i-1)*.05 and open<.6)end
 local s=Flourish.Styles.lightning
 local t=math.clamp((age-s.open)/(Flourish.Duration-s.open),0,1)
 for i,spark in ipairs(self.sparks)do
  local on=age>=s.open and t<1
  put(spark.frame,"Visible",on)
  if on then
   local angle=i*math.pi/3+.3;local out=1-(1-t)*(1-t)
   put(spark.frame,"Position",UDim2.fromScale(.5+math.cos(angle)*.3*out,self.lidHeight*.6+(math.sin(angle)*.1+.12*t)*out))
   local size=10*(1-.6*t);put(spark.frame,"Size",UDim2.fromOffset(size,size))
   put(spark.frame,"BackgroundTransparency",t*t);put(spark.stroke,"Transparency",t)
  end
 end
end
function Flourish:destroy()if self.destroyed then return end;self:cancel();self.destroyed=true;self.root:Destroy()end
return Flourish
