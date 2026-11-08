-- Native LocalScript + enabled ScreenGui. Pure layout, component geometry and callback fixtures;
-- root separately captures actual renderer corners/bank contrast and both-origin X/B routes.
return function(client,parent)
 local Layout=require(client.DeckLayout);local Art=require(client.DeckArt);local Dispenser=require(client.DropDispenser);local Menu=require(client.DeckMenu)
 local Config=require(game.ReplicatedStorage.Shared.BoardConfig);local Text=game:GetService("TextService")
 local cases={};local ratio=(Config.Width+.8)/(Config.Height+.8)
 local function test(name,run)run();table.insert(cases,name)end
 local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
 local function copy(r)return{x=r.x,y=r.y,w=r.w,h=r.h}end
 local function same(a,b)return a.x==b.x and a.y==b.y and a.w==b.w and a.h==b.h end
 local root=Instance.new("Frame");root.BackgroundTransparency=1;root.Parent=parent
 local views={};local ok,problem=pcall(function()
  for _,size in ipairs({Vector2.new(1649,971),Vector2.new(733,307),Vector2.new(568,160),Vector2.new(480,160),Vector2.new(350,279),Vector2.new(385,703)})do
   test(tostring(size).." passive stacks lower only within measured free rails",function()
    local line=math.ceil(Text:GetTextSize("Next",12,Art.Font.Body,Vector2.new(1000,100)).Y)+4
    local l=Layout.resolve(size,ratio,{lineHeight=line,queueHeight=line+40,utilityWidth=80,countWidth=68})
    local fixed={};for _,name in ipairs({"shell","tray","bezel","menu","lounge","dpad","drop","speaker"})do fixed[name]=copy(l[name])end
    local wallet,quest,queue,meter=copy(l.wallet),copy(l.quest),copy(l.queue),copy(l.meter)
    local speakerVisible=l.speakerVisible
    Layout.fitInstruments(l,Dispenser.preferredHeight({budget=24},meter.w,meter.h))
    for name,r in pairs(fixed)do assert(same(l[name],r),"passive reflow moved "..name)end
    assert(l.speakerVisible==speakerVisible)
    assert(l.wallet.y-wallet.y==l.quest.y-quest.y and l.wallet.h==wallet.h and l.quest.h==quest.h)
    assert(l.queue.y-queue.y==l.meter.y-meter.y and l.queue.h==queue.h and l.meter.h<=meter.h)
    if not l.lateral or l.short or l.dense then assert(l.instrumentShiftLeft==0 and l.instrumentShiftRight==0)
    else
     assert(l.instrumentShiftLeft>=0 and l.instrumentShiftLeft<=math.ceil(l.shell.h*.06))
     assert(l.instrumentShiftRight>=0 and l.instrumentShiftRight<=math.ceil(l.shell.h*.06))
     assert(l.quest.y+l.quest.h<=math.min(l.menu.y,l.lounge.y)-7.9)
     assert(l.meter.y+l.meter.h<=(if l.speakerVisible then l.speaker.y else l.drop.y)-7.9)
     if size.X==1649 then assert(l.instrumentShiftLeft>0 and l.instrumentShiftRight>0,"roomy instruments stayed at upper edge")end
    end
   end)
  end
  test("speaker seat and visibility survive the midheight threshold unchanged",function()
   local shown,hidden=false,false
   for _,height in ipairs({330,350,370,390,430,460})do
    local l=Layout.resolve(Vector2.new(733,height),ratio,{queueHeight=60,lineHeight=30})
    local seat,visible=copy(l.speaker),l.speakerVisible
    if visible then shown=true else hidden=true end
    Layout.fitInstruments(l,Dispenser.preferredHeight({budget=24},l.meter.w,l.meter.h))
    assert(same(l.speaker,seat)and l.speakerVisible==visible,"instrument reflow changed fixed speaker at"..height)
    if visible then assert(l.meter.y+l.meter.h<=seat.y-7.9)end
   end
   assert(shown and hidden,"fixture missed speaker visibility transition")
  end)
  test("full welcome coach keeps its exact size and a tight left rail clamps shift to zero",function()
   local l=Layout.resolve(Vector2.new(1649,971),ratio);l.quest.w,l.quest.h=179,104
   local size=Vector2.new(l.quest.w,l.quest.h);Layout.fitInstruments(l,50);assert(Vector2.new(l.quest.w,l.quest.h)==size)
   l=Layout.resolve(Vector2.new(733,307),ratio);l.quest.h=l.menu.y-l.quest.y-8;local before=l.quest.y
   Layout.fitInstruments(l,40);assert(l.quest.y==before and l.instrumentShiftLeft==0)
  end)
  test("short dispenser retains exact24counter and optional centered train without extra well",function()
   root.Size=UDim2.fromOffset(220,72);settle();local d=Dispenser.new(root,function()return true end)
   local height=d:preferredHeight(220,72);assert(height<=72 and height>=20)
   root.Size=UDim2.fromOffset(220,height);settle();d:update(1,0,24,true)
   assert(d.label.TextFits and d.label.Text:find("24/24",1,true));local count=#d.host:GetDescendants()
   for n=1,24 do d:update(1,n,24,true);assert(d.remaining==24-n and d.label.TextFits)end
   assert(d.label.Text:find("0/24",1,true)and #d.host:GetDescendants()==count)
   if d.channel.Visible then local a,b=d.balls[1],d.balls[8];assert(math.abs(a.Position.X.Offset-(d.channel.AbsoluteSize.X-b.Position.X.Offset-b.Size.X.Offset))<=1)end
   d.host:Destroy()
  end)
  test("Menu has one X close route and no Resume action at either origin",function()
   root.Size=UDim2.fromOffset(733,307);settle()
   for _,origin in ipairs({"Board","Room"})do
    local mode,closed=origin,0;local menu
    menu=Menu.new(root,{close=function()closed+=1;menu:close()end});table.insert(views,menu)
    menu:open();assert(not menu.resumeButton and not menu.card:FindFirstChild("Deck",true));assert(menu:activate("close"))
    assert(not menu.shade.Visible and mode==origin and closed==1)
    menu:open();menu:close();assert(mode==origin and not menu.shade.Visible and closed==1,"Back changed origin mode")
   end
  end)
  test("rounded outside-arc strips cover all four fractional corners and remain passive",function()
   local host=Art.frame(root,"Tray",Art.LCD,UDim2.fromOffset(3.25,4.5),UDim2.fromOffset(417.3,700.25),2);host.ClipsDescendants=true
   for _,layer in ipairs({{"JellyLCDSpans",3},{"JellyLCD",3},{"Sprites",3},{"TargetRegions",6},{"OverflowLine",5},{"TierMarks",9}})do Art.frame(host,layer[1],Art.Leaf,UDim2.fromScale(0,0),UDim2.fromScale(1,1),layer[2])end
   local mask=Art.lcdCorners(host,Art.Ink);local instances=mask:GetChildren();local count=#instances;assert(count==48)
   local function covered(point)
    for _,strip in ipairs(instances)do if strip.Visible then local p,s=strip.AbsolutePosition-host.AbsolutePosition,strip.AbsoluteSize;if point.X>=p.X-.01 and point.X<=p.X+s.X+.01 and point.Y>=p.Y-.01 and point.Y<=p.Y+s.Y+.01 then return true end end end
    return false
   end
   for _,size in ipairs({Vector2.new(417.3,700.25),Vector2.new(173.7,291.4),Vector2.new(71.5,120.3)})do
    host.Size=UDim2.fromOffset(size.X,size.Y);settle();local s=host.AbsoluteSize
    for _,point in ipairs({Vector2.new(.1,.1),Vector2.new(s.X-.1,.1),Vector2.new(.1,s.Y-.1),Vector2.new(s.X-.1,s.Y-.1)})do assert(covered(point),"fractional corner leak:"..tostring(point))end
    assert(not covered(s*.5)and not covered(Vector2.new(s.X*.5,.1)),"mask covered screen interior")
    assert(not mask.Active and not mask.Selectable and mask.BackgroundTransparency==1 and mask.ZIndex>9)
    for _,strip in ipairs(instances)do assert(strip.Parent==mask and not strip.Active and not strip.Selectable and not strip.ClipsDescendants)end
    assert(#mask:GetChildren()==count)
   end
   host:Destroy()
  end)
 end)
 for _,v in ipairs(views)do v.shade:Destroy()end;root:Destroy();assert(ok,problem);return{passed=#cases,cases=cases}
end
