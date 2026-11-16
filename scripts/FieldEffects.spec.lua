-- Actual LocalScript + enabled ScreenGui. No sound/remotes/gameplay changes.
return function(client,parent)
 assert(parent:IsA("ScreenGui")and parent.Enabled,"enabled ScreenGui required")
 local Effects=require(client.FieldEffects);local root=Instance.new("Frame");root.Size=UDim2.fromOffset(354,594);root.BackgroundTransparency=1;root.Parent=parent
 local fx=Effects.new(root);local cases={};local color=Color3.fromRGB(82,173,242);local point=Vector2.new(100,120)
 local function test(name,run)run();table.insert(cases,name)end
 local function emit(kind,tier,chain,serial,time)return fx:emit(kind,point,18,color,tier,chain,serial or 10,time or 0)end
 game:GetService("RunService").Heartbeat:Wait();game:GetService("RunService").Heartbeat:Wait()
 local ok,err=pcall(function()
  test("fixed four-slot six-fragment passive clipped pool",function()
   assert(#fx.slots==4 and fx.root.ClipsDescendants)
   for _,s in ipairs(fx.slots)do assert(#s.fragments==6 and not s.ring.Active and not s.ring.Selectable);for _,n in ipairs(s.fragments)do assert(not n.Active and not n.Selectable)end end
  end)
  test("hidden and old-run events never enter pool",function()
   assert(not emit("merge",5,4));fx:setOwner(true,10,false);assert(not emit("merge",5,4,9));assert(fx.stats.accepted==0)
  end)
  test("published run token remains valid across multiple accepted drops",function()
   assert(not fx:observeDrop(10,0));for n=1,6 do assert(fx:observeDrop(10,n));assert(emit("merge",2,1,10,n))end
   assert(not fx:observeDrop(11,0));fx:setOwner(true,11,false);assert(not emit("merge",5,5,10));assert(fx:observeDrop(11,1))
   fx:setOwner(true,10,false)
  end)
  test("counter jumps resets and duplicates do not synthesize drops",function()
   assert(not fx:observeDrop(12,0));assert(not fx:observeDrop(12,8));assert(not fx:observeDrop(12,8));assert(not fx:observeDrop(12,0));assert(fx:observeDrop(12,1))
  end)
  test("largest merge evicts lesser feedback without allocating",function()
   fx:clear();local count=#fx.root:GetDescendants();for i=1,4 do assert(emit("impact",1,1,10,20))end
   assert(emit("merge",5,4,10,20));assert(fx.stats.evicted>0 and #fx.root:GetDescendants()==count)
   for i=1,4 do emit("merge",5,4,10,20)end;assert(not emit("drop",1,1,10,20))
  end)
  test("active lifetime is bounded and releases every fragment",function()
   fx:update(20.4);assert(fx.stats.active==0);for _,s in ipairs(fx.slots)do assert(not s.ring.Visible);for _,f in ipairs(s.fragments)do assert(not f.Visible)end end
  end)
  test("reduced mode keeps a still local fade without fragments",function()
   fx:setOwner(true,10,true);assert(emit("merge",3,2,10,30));local first=fx.slots[1];local position=first.ring.Position;fx:update(30.08)
   assert(first.ring.Visible and first.ring.Position==position);for _,f in ipairs(first.fragments)do assert(not f.Visible)end
  end)
  test("one measured reusable chain and max-clear label stays inside every tray",function()
   for _,size in ipairs({Vector2.new(354,594),Vector2.new(172,289),Vector2.new(71,120)})do
    root.Size=UDim2.fromOffset(size.X,size.Y);game:GetService("RunService").Heartbeat:Wait();game:GetService("RunService").Heartbeat:Wait()
    fx:clear();fx:setOwner(true,10,true)
    assert(fx:emit("merge",Vector2.new(size.X/2,size.Y/2),10,color,5,3,10,32,nil,true))
    game:GetService("RunService").Heartbeat:Wait()
    assert(fx.caption.Visible and fx.caption.Text:find("100")and fx.caption.Text:find("pts")and fx.caption.TextFits,"max-clear feedback must fit: "..tostring(fx.caption.AbsoluteSize).."/"..tostring(fx.caption.TextBounds))
    assert(fx.caption.Position.Y.Offset>=0 and fx.caption.Position.Y.Offset+fx.caption.Size.Y.Offset<=size.Y)
    assert(not fx.caption.Active and not fx.caption.Selectable and not fx.caption.TextScaled)
   end
  end)
  test("cover clears immediately and hidden updates write nothing",function()
   assert(fx:setOwner(false,10,true)==true);assert(not fx:setOwner(false,10,true));local writes=fx.stats.writes;for n=1,60 do fx:update(30+n/60)end;assert(fx.stats.writes==writes and fx.stats.active==0)
  end)
  test("reset and reduction transitions retain pool but revoke old work",function()
   local count=#fx.root:GetDescendants();assert(not fx:setOwner(true,20,false));emit("merge",3,2,20,40);assert(fx:setOwner(true,21,false)==true);assert(not fx:setOwner(true,21,false));assert(fx.stats.active==0)
   emit("merge",2,1,21,40);assert(not fx:setOwner(true,21,true));assert(fx.stats.active==0 and #fx.root:GetDescendants()==count)
  end)
  test("steady events and resizing never create new descendants",function()
   local count=#fx.root:GetDescendants();fx:setOwner(true,21,false)
   for n=1,120 do if n%12==0 then emit("merge",1+n%5,1,21,50+n/60)end;fx:update(50+n/60)end
   root.Size=UDim2.fromOffset(172,289);fx:clear();assert(#fx.root:GetDescendants()==count)
  end)
  test("merge score pops show the server delta, rise, fade within 0.7 s and cap at four",function()
   local Config=require(game.ReplicatedStorage.Shared.BoardConfig);local Pico8=require(game.ReplicatedStorage.Shared.Pico8)
   assert(Config.mergeScore(2,1,false)==20 and Config.mergeScore(3,2,false)==40 and Config.mergeScore(5,12,true)==240)
   root.Size=UDim2.fromOffset(354,594);fx:clear();fx:setOwner(true,40,false);local count=#fx.root:GetDescendants()
   assert(fx:emit("merge",point,18,color,3,2,40,60,nil,false,Config.mergeScore(3,2,false)))
   local pop;for _,p in ipairs(fx.pops)do if p.active then pop=p.label end end
   assert(pop and pop.Visible and pop.Text=="+40" and pop.TextColor3==color,"no +N pop")
   local y=pop.Position.Y.Offset;fx:update(60.35);assert(pop.Position.Y.Offset<y-5,"pop did not rise");fx:update(60.71);assert(not pop.Visible,"pop outlived 0.7 s")
   for n=1,7 do fx:emit("merge",point,18,color,2,1,40,61+n*.01,nil,false,20)end
   local shown=0;for _,p in ipairs(fx.pops)do if p.label.Visible then shown+=1 end end
   assert(shown<=4 and #fx.pops==4 and #fx.root:GetDescendants()==count,"pop pool grew")
   for chain,c in pairs({[2]=Pico8[9],[3]=Pico8[10],[5]=Pico8[8]})do
    fx:clear();assert(fx:emit("merge",point,18,color,3,chain,40,70+chain,nil,false,10));assert(fx.caption.Text=="×"..chain and fx.caption.TextColor3==c,"chain caption "..chain)
   end
   fx:setOwner(true,40,true);fx:clear();assert(fx:emit("merge",point,18,color,4,1,40,80,nil,false,40))
   for _,p in ipairs(fx.pops)do if p.active then local at=p.label.Position;fx:update(80.3);assert(p.label.Position==at and p.label.Text=="+40","reduced pop moved")end end
  end)
  test("G1 juice: ring, fragments and chain counter grow with tier and chain; the counter and +N land with a punch",function()
   assert(Effects.mergeDuration(1)<Effects.mergeDuration(5)and Effects.mergeDuration(5)<=.32 and Effects.mergeDuration(9)==Effects.mergeDuration(5))
   assert(Effects.ringReach(2)<Effects.ringReach(5)and Effects.fragmentReach(2)<Effects.fragmentReach(5))
   assert(Effects.chainTextSize(2)==20 and Effects.chainTextSize(3)==22 and Effects.chainTextSize(7)==30 and Effects.chainTextSize(40)==30)
   root.Size=UDim2.fromOffset(172,289);game:GetService("RunService").Heartbeat:Wait();game:GetService("RunService").Heartbeat:Wait()
   fx:setOwner(true,50,false);fx:clear()
   assert(fx:emit("merge",Vector2.new(86,140),10,color,3,4,50,90,nil,false,60))
   local pop;for _,p in ipairs(fx.pops)do if p.active then pop=p end end
   assert(fx.caption.Text=="×4"and fx.caption.TextSize==Effects.punchSize(24,0)and Effects.punchSize(24,0)==35 and Effects.punchSize(24,1)==24 and pop.label.TextSize==Effects.punchSize(15,0),"punch start")
   assert(fx.caption.Size.Y.Offset>=fx.caption.TextSize and fx.caption.Position.Y.Offset>=0,"the box fits the punch peak")
   fx:update(90+Effects.PunchTime);assert(fx.caption.TextSize==24 and pop.label.TextSize==15 and fx.caption.TextTransparency==0,"lands at rest size, still opaque")
   local slot;for _,sl in ipairs(fx.slots)do if sl.active then slot=sl end end
   assert(slot and slot.stroke.Thickness==3 and slot.fragments[2].BackgroundColor3~=slot.fragments[1].BackgroundColor3,"tier ring and sparkle fragments")
   fx:update(90+Effects.CaptionHold+.01);assert(not fx.caption.Visible,"counter gone after the hold")
   fx:setOwner(true,50,true);fx:clear();assert(fx:emit("merge",Vector2.new(86,140),10,color,3,4,50,95,nil,false,60))
   assert(fx.caption.TextSize==24,"Reduced Motion: no punch")
  end)
  test("teardown is idempotent and rejects late events",function()
   fx:destroy();fx:destroy();local writes=fx.stats.writes;assert(not emit("merge",5,5,21,60));fx:update(60);assert(fx.stats.writes==writes and fx.root.Parent==nil)
  end)
 end)
 fx:destroy();root:Destroy();assert(ok,err);return cases
end
