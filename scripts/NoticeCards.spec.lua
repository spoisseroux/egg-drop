-- QA v735 H5: tappable top-bar pills and the notice cards they open (NoticeCards.lua,
-- NotificationRail, HowItWorks.openNotice), and the first-session garden tour
-- (HowItWorks "garden" set, CoachCards options.tour).
-- Run (Client): require(Client.ZZSpecs.NoticeCards)(Client, PlayerGui)
return function(client,parent)
 local Shared=game:GetService("ReplicatedStorage").Shared
 local UICopy=require(Shared.UICopy);local Coach=require(Shared.CoachMarks)
 local Notices=require(client.NoticeCards);local How=require(client.HowItWorks)
 local Rail=require(client.NotificationRail);local Kit=require(client.DeckKit);local Cards=require(client.CoachCards)
 local TextService=game:GetService("TextService");local RunService=game:GetService("RunService")
 parent=parent or game.Players.LocalPlayer:WaitForChild("PlayerGui")
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local savedGo,savedCan=How.go,How.canGo
 How.close("fixture")
 local function railWidth(text)return TextService:GetTextSize(text,14,Enum.Font.BuilderSansMedium,Vector2.new(10000,40)).X end
 -- v2 tickets: a Stars line's "+N" is its own label after the text (Rail.measure).
 local function lineWidth(text,amount)local _,_,_,_,content=Rail.measure({text=text,amount=amount});return content end
 local ok,problem=pcall(function()
  test("every notice has a title, the two cards and filled copy; its button names a real place",function()
   assert(#Notices.Order>=12)
   for _,id in ipairs(Notices.Order)do
    assert(Notices.has(id),id)
    for _,key in ipairs({"title","what","next"})do assert(UICopy.has("notice."..id.."."..key),"missing notice."..id.."."..key)end
    local vars={pet="Bear",quest="Merge 10 eggs",reward=3}
    local title=Notices.title(id,vars);assert(title~=""and not title:find("{",1,true),id.." title")
    local cards=Notices.cards(id,vars);assert(#cards==2 and cards[1].key=="what"and cards[2].key=="next",id)
    assert(cards[1].title==UICopy.get("notice.label.what")and cards[2].title==UICopy.get("notice.label.next"))
    for _,card in ipairs(cards)do
     assert(card.line~=""and not card.line:find("{",1,true)and not card.line:find("notice.",1,true),id.." "..card.key.." line: "..card.line)
     assert(type(card.icon)=="string",id.." picture")
    end
    -- Without values the lines still read (defaults), never a raw placeholder.
    for _,card in ipairs(Notices.cards(id))do assert(not card.line:find("{",1,true),id.." default "..card.line)end
    local go=Notices.go(id)
    if go then assert(table.find(Notices.Targets,go.target)and go.text==UICopy.get("notice.go."..go.target)and go.text~="",id.." go")end
   end
   assert(not Notices.has("nope")and Notices.detail("nope")==nil and #Notices.cards("nope")==0 and Notices.go("locked")==nil)
   local detail=Notices.detail("questReady",{quest="Q",reward=2});assert(detail.id=="questReady"and detail.vars.reward==2)
   assert(Notices.cards("questReady",{quest="Tidy win",reward=4})[1].line:find("Tidy win",1,true),"the quest is named")
   -- The lines the first session must teach.
   assert(Notices.go("quest").target=="quests"and Notices.go("customize").target=="companions"and Notices.go("machines").target=="menu")
  end)
  test("the rail: a line with an action or a detail is tappable, gets a chevron and still fits",function()
   assert(Rail.tappable({activate=function()end})and Rail.tappable({detail={id="quest"}})and not Rail.tappable({text="x"})and not Rail.tappable(nil))
   local plain,tap=Rail.geometry(320,58,100),Rail.geometry(320,58,100,true)
   assert(tap.width==plain.width+Rail.MoreWidth and tap.fits,"room for the chevron")
   -- Spec 1 widths: 96..260 (220 on a free bar under 600 px); hidden under a 32 px bar.
   assert(Rail.geometry(1280,58,0).width==Rail.MinWidth and Rail.geometry(1280,58,900).width==Rail.MaxWidth and Rail.geometry(320,58,900).width==Rail.NarrowMaxWidth)
   assert(Rail.geometry(1280,58,10).height==44 and Rail.geometry(1280,40,10).height==34 and Rail.geometry(1280,32,10).height==32 and not Rail.geometry(1280,30,10).fits,"44 / 34 / 32 / hidden by bar height (round 3)")
   local lines={{UICopy.get("notice.pill.firstSpend")},{UICopy.get("qa.coach.welcome")},{UICopy.get("coach.firstStars.toast"),6},
    {UICopy.get("coach.fillLine.short")},{UICopy.get("coach.item.short")},{"Quest claimed",12}}
   for _,id in ipairs({"hatch","style","companions","quests","book","park"})do table.insert(lines,{Cards.railLine(id,"once",{pet="Bear"},true).text})end
   for _,id in ipairs({"machines","hub","quest","questDone"})do table.insert(lines,{Cards.railLine(id,"beat",{pet="Bear"},false).text})end
   -- Every tappable coach line shows on a phone bar and reads whole on a desktop one.
   for _,line in ipairs(lines)do
    local width=lineWidth(line[1],line[2])
    assert(Rail.geometry(320,58,width,true).fits and Rail.geometry(1280,58,width,true).full,"a tappable line does not fit the rail: "..line[1])
   end
   assert(railWidth("x")>0)
  end)
  test("coach lines: a first visit is a tip that opens the machine's cards; the rest open their notice",function()
   local tip=Cards.railLine("hatch","once",{pet="Bear"},true)
   assert(tip.text==UICopy.get("notice.pill.tip",{title=UICopy.get("coach.hatch.title")})and tip.icon=="?"and tip.help=="hatch"and tip.notice==nil)
   for _,id in ipairs(Coach.GardenBeats)do
    local line=Cards.railLine(id,"beat",{pet="Bear",input="Touch"},How.has(id))
    assert(line.notice==id and line.icon=="?"and line.help==nil,"beat "..id.." opens its notice")
   end
   assert(Cards.railLine("questDone","once",{},false).notice=="questDone")
   local hi=Cards.railLine("petArrived","arrival",{pet="Zivvi"},false);assert(hi.text==UICopy.get("qa.coach.sayHi",{pet="Zivvi"})and hi.notice==nil and hi.help==nil)
   for _,id in ipairs({"hatch","style","companions","quests","book","park"})do assert(How.has(id),"first-visit tip has cards: "..id)end
  end)
  test("a tap: the line's own action wins; else its notice opens with both cards and Got it",function()
   local ran=0
   assert(Rail.activate({activate=function()ran+=1 end,detail=Notices.detail("quest")})and ran==1 and not How.isOpen(),"own action only")
   assert(not Rail.activate({text="plain"})and not Rail.activate({detail={id="nope"}})and not How.isOpen())
   How.go,How.canGo=nil,nil
   assert(Rail.activate({detail=Notices.detail("questReady",{quest="Merge 10 eggs",reward=3})}))
   assert(How.isOpen()and How.noticeId()=="questReady"and How.openId()=="notice:questReady")
   RunService.RenderStepped:Wait()
   local panel=How.panel();local body=panel:FindFirstChild("Cards")
   local what,nextCard=body:FindFirstChild("Card_what"),body:FindFirstChild("Card_next")
   assert(what and nextCard,"both cards")
   assert(what.CardTitle.Text==UICopy.get("notice.label.what")and what.CardLine.Text:find("Merge 10 eggs",1,true)and what.CardLine.Text:find("3",1,true))
   assert(nextCard.CardTitle.Text==UICopy.get("notice.label.next")and nextCard.CardLine.Text==UICopy.get("notice.questReady.next"))
   assert(panel.Title.Text==UICopy.get("notice.questReady.title"))
   assert(panel:FindFirstChild("GotIt")and not panel:FindFirstChild("Go")and not panel:FindFirstChild("ShowTips"),"no route set: Got it only")
   for _,label in ipairs(panel:GetDescendants())do
    if label:IsA("TextLabel")and label.Visible and label.Text~=""then assert(label.TextSize>=12,"text floor "..label:GetFullName())end
   end
   assert(How.accept()and not How.isOpen(),"A / Enter closes a notice without a button")
  end)
  test("the button: shown only when the client can go there; it closes the card, then goes",function()
   local went,asked={},{}
   How.go=function(target)table.insert(went,target)end
   How.canGo=function(target)table.insert(asked,target);return false end
   assert(How.openNotice("quest",{vars={pet="Bear"}}));assert(not How.panel():FindFirstChild("Go")and asked[1]=="quests","cannot go: no button")
   How.close("fixture")
   How.canGo=function()return true end
   assert(How.openNotice("quest"));local button=assert(How.panel():FindFirstChild("Go"),"Go button")
   assert(button:GetAttribute("GoTarget")=="quests"and How.panel():FindFirstChild("GotIt"),"Open Quests beside Got it")
   local footer=How.panel():FindFirstChild("GotIt")
   assert(footer.AbsolutePosition.X+footer.AbsoluteSize.X<=button.AbsolutePosition.X+1,"the two buttons do not overlap")
   assert(How.accept()and not How.isOpen()and #went==0,"closes first")
   task.wait();task.wait();assert(#went==1 and went[1]=="quests","then goes to Quests")
   -- A line's own `run` replaces the route (the first egg opens Hatch eggs on the Toy Egg).
   local ran
   How.canGo=function()return false end
   assert(Rail.activate({detail=Notices.detail("firstSpend",{pet="Bear"},function(target)ran=target end)}))
   assert(How.panel():FindFirstChild("Go"),"its own action needs no route")
   How.accept();task.wait();task.wait();assert(ran=="hatch"and #went==1)
   -- Back / outside never goes anywhere.
   How.canGo=function()return true end
   assert(How.openNotice("customize"));How.close("back");task.wait();task.wait();assert(#went==1)
   -- A machine's own set is unchanged by all this.
   assert(How.open("quests")and How.noticeId()==nil and How.panel():FindFirstChild("GotIt")and not How.panel():FindFirstChild("Go"));How.close("fixture")
  end)
  test("layout: every notice and the garden tour fit a landscape phone",function()
   for _,size in ipairs({Vector2.new(812,354),Vector2.new(844,390),Vector2.new(1280,720)})do
    for _,id in ipairs(Notices.Order)do
     local g=How.layout(size.X,size.Y,Notices.cards(id,{pet="Bear",quest="Merge 10 eggs",reward=3}))
     assert(g.columns==2 and g.panelW<=size.X and g.panelH<=size.Y and g.cardH<=g.viewportH,id.." at "..tostring(size))
    end
    for _,input in ipairs({"Touch","Keyboard","Gamepad"})do
     local g=How.layout(size.X,size.Y,How.cards("garden",input))
     assert(g.columns==4 and g.panelW<=size.X and g.panelH<=size.Y and g.cardH<=g.viewportH,"garden tour ("..input..") at "..tostring(size))
    end
   end
  end)
  test("the garden tour: four cards that teach machines and the Menu, saying hi, Quests and dailies, and customize",function()
   local cards=How.cards("garden");assert(#cards==4 and not table.find(How.Order,"garden"),"a tour, not a machine's ? set")
   local text=""
   for _,card in ipairs(cards)do assert(card.title~=""and card.line~=""and not card.title:find("r3.",1,true));text..=card.title.." "..card.line.." "end
   for _,word in ipairs({"machine","Quests","stamp","Menu","Companions","eggs"})do assert(text:find(word,1,true),"the tour never says "..word)end
   -- QA v775: "say hi to your pet" lives here (it was an always-on hint in the garden), second,
   -- and names the tap, the key or the button.
   assert(cards[2].key=="e"and cards[2].title==UICopy.get("r3.help.garden.e.title")and cards[2].title:find("Say hi",1,true))
   local touch,key,pad=How.cards("garden","Touch")[2].line,How.cards("garden","Keyboard")[2].line,How.cards("garden","Gamepad")[2].line
   assert(touch:find("Tap your pet",1,true)and key:find("press E",1,true)and pad:find("press X",1,true)and touch~=key and key~=pad)
   assert(table.find({touch,key,pad},cards[2].line),"the live line follows the input in use")
   assert(How.open("garden")and How.openId()=="garden"and How.panel():FindFirstChild("Card_e",true)and not How.panel():FindFirstChild("Card_d",true));How.close("fixture")
  end)
  test("coach: with a tour the garden step opens it once, by the beat rules, and closing it saves the step",function()
   local gui=Instance.new("ScreenGui");gui.Name="_NoticeTourSpec";gui.Parent=parent
   local sent,opened,done={},0,nil
   local cards=Cards.new({gui=parent,send=function(id)table.insert(sent,id)end,tour=function(finish)opened+=1;done=finish;return true end})
   local good,why=pcall(function()
    local function step(t,extra)
     local ctx={mode="Room",canRoam=true,presented=false,owned=1,input="Touch",open={},used={},pet="Bear"}
     for k,v in pairs(extra or {})do ctx[k]=v end
     cards:step(t,ctx)
    end
    cards:sync({coachMask=0,totalWins=0,quests={daily={}}})
    step(0);step(1,{idleFor=.2});assert(opened==0,"waits for the garden to settle and the player to stand still")
    step(5,{idleFor=5,windowActive=false});assert(opened==0,"waits for a focused window")
    step(6,{idleFor=5});assert(opened==0,"the settle time starts over once the window is back")
    step(9,{idleFor=5});assert(opened==1 and cards.tourOpen and cards.garden==nil,"the tour opens; no beat line beside it")
    step(10,{idleFor=5});step(20,{idleFor=5});assert(opened==1 and cards.garden==nil and not table.find(sent,"gardenIntro"),"held while the cards are up")
    done();assert(not cards.tourOpen and cards.gardenDone and table.find(sent,"gardenIntro"),"closing the tour ends and saves the step")
    step(30,{idleFor=5});step(40,{idleFor=5});assert(opened==1 and cards.garden==nil,"never twice")
    assert(cards:replayGarden());step(50,{idleFor=5});step(54,{idleFor=5});assert(opened==2,"Show tips again replays the tour")
    done()
   end)
   cards:destroy();gui:Destroy();assert(good,why)
   -- The cards could not open: the three beat lines run instead.
   local gui2=Instance.new("ScreenGui");gui2.Name="_NoticeTourSpec2";gui2.Parent=parent
   local tried=0
   local fallback=Cards.new({gui=parent,send=function()end,tour=function()tried+=1;return false end})
   local good2,why2=pcall(function()
    fallback:sync({coachMask=0,totalWins=0,quests={daily={}}})
    local ctx={mode="Room",canRoam=true,presented=false,owned=1,input="Touch",open={},used={},pet="Bear",idleFor=5}
    fallback:step(0,ctx);fallback:step(6,ctx)
    assert(tried==1 and fallback.garden and fallback.garden.id=="machines"and fallback.garden.line.notice=="machines","falls back to the beat lines")
    fallback:step(7,ctx);assert(tried==1,"asked once")
   end)
   fallback:destroy();gui2:Destroy();assert(good2,why2)
  end)
  test("toasts carry their notice to the rail",function()
   local got
   local toaster=Kit.toaster(Instance.new("Frame"),{enqueue=function(_,_,data)got=data;return {}end})
   toaster.show("Quest done: Merge 10 eggs",3,nil,Notices.detail("questReady",{quest="Merge 10 eggs",reward=3}))
   assert(got.text=="Quest done: Merge 10 eggs"and got.amount==3 and got.detail.id=="questReady"and Rail.tappable(got))
   toaster.show("Saved");assert(got.detail==nil and not Rail.tappable(got),"a plain toast stays plain")
  end)
 end)
 How.close("fixture");How.go,How.canGo=savedGo,savedCan
 assert(ok,problem);return cases
end
