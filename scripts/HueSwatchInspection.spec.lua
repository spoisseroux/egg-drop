return function(client,parent)
 local View=require(client.HueEggView);local Intent=require(client.HueIntent);local Shared=game.ReplicatedStorage.Shared
 local H=require(Shared.HueCatalog);local Http=game:GetService("HttpService");local Run=game:GetService("RunService")
 local root=Instance.new("Frame");root.Size=UDim2.fromOffset(350,703);root.Parent=parent
 local sent,cases={},{};local view
 local intent=Intent.new({id=function()return "swatch-confirm"end,send=function(a,v,r)table.insert(sent,{action=a,value=v,revision=r})end,changed=function()if view then view:refresh()end end})
 view=View.new(root,intent,{appearance=function()return{charmVisible=false}end})
 local row={main={rose=2,tide=1,citrus=0,iris=0},secondary={rose=0,tide=0,citrus=1,iris=2}}
 local state={status="Ready",revision=1,nectar=24,inventoryMask=127,hues={},petHues={pip=row},hueInventory={rose=3,tide=0,citrus=2,iris=1,reset=1}}
 local function settle()for _=1,3 do Run.Heartbeat:Wait()end end
 local function test(name,run)run();table.insert(cases,name)end
 local ok,problem=pcall(function()
  view:open(state,"palette","pip");settle()
  test("inspection changes no saved vectors stock portrait or spend intent",function()
   local before=Http:JSONEncode(state);local visual=view.visual;local pieces=visual.pieces
   local colors={};for _,e in ipairs(pieces)do colors[e.part]=e.part.Color end
   assert(view:inspectHue("rose",4)and #sent==0 and Http:JSONEncode(state)==before and view.visual==visual and view.visual.pieces==pieces)
   assert(not view.inspection.Text:find("#",1,true)and view.inspection.Text:find("Unapplied",1,true))
   assert(view.bars.rose.ticks[4]:GetAttribute("Inspected")and view.bars.rose.ticks[2]:GetAttribute("SavedStage"))
   for part,color in pairs(colors)do assert(part.Color==color,"inspection recolored saved portrait")end
  end)
  test("zero-stock stages inspect but cannot consume, channels use their independent saved vectors",function()
   assert(view:inspectHue("tide",5)and view.inspection.Text:find("0 in inventory",1,true)and not view:chooseItem("tide")and #sent==0)
   view:chooseChannel("secondary");assert(view.inspected==nil and view:inspectHue("iris",4))
   assert(view.inspection.Text:find("Iris fruit stage 4",1,true)and view.bars.iris.value.Text=="2/5")
  end)
  test("all swatches retain 44px targets and readable stage text on phone, short landscape and desktop",function()
   for _,size in ipairs({Vector2.new(350,703),Vector2.new(568,160),Vector2.new(733,307),Vector2.new(1649,971)})do
    root.Size=UDim2.fromOffset(size.X,size.Y);settle();view:layout();settle()
    assert(view.title.TextFits and view.inspection.TextFits)
    for _,bar in pairs(view.bars)do for _,tick in ipairs(bar.ticks)do
     assert(tick.AbsoluteSize.X>=44 and tick.AbsoluteSize.Y>=44 and tick.TextFits)
     assert(not tick:FindFirstChildWhichIsA("UIGradient"),"decoration tinted exact quoted chip")
     local function luminance(color)local function linear(v)return if v<=.04045 then v/12.92 else((v+.055)/1.055)^2.4 end;return .2126*linear(color.R)+.7152*linear(color.G)+.0722*linear(color.B)end
     local ink,fill=luminance(tick.TextColor3),luminance(tick.BackgroundColor3)
     assert((math.max(ink,fill)+.05)/(math.min(ink,fill)+.05)>=4.5,"stage text contrast below4.5:1")
    end end
    if size==Vector2.new(733,307)then
     local portrait=view.portrait.AbsolutePosition
     view.body.CanvasPosition=Vector2.zero;assert(view:inspectHue("rose",4));settle()
     assert(not view.inspection.Text:find("#",1,true)and view.inspection:GetAttribute("AccessibleLabel"):find("Unapplied",1,true))
     view:ensure(view.bars.rose.ticks[5]);settle();assert(view.portrait.AbsolutePosition==portrait,"swatch scroll moved fixed portrait")
    end
   end
  end)
  test("inspecting stage4 at saved2 still confirms only next3 and emits one unchanged dose quote",function()
   view:chooseChannel("main");assert(view:inspectHue("rose",4));assert(view:chooseItem("rose"))
   assert(#sent==0 and view.quote.Text:find("2/5 → 3/5",1,true))
   assert(view:activate()and not view:activate()and #sent==1)
   assert(sent[1].value.counts.rose==2 and sent[1].value.counts.tide==1 and sent[1].value.channel=="main")
  end)
 end)
 view:destroy();root:Destroy();assert(ok,problem);return{passed=#cases,cases=cases}
end
