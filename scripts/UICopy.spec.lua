-- Studio Client. UI personality T3: the menu copy table (Shared.UICopy).
-- Every key resolves, placeholders fill, every key the P1 call sites use exists, and
-- each changed line fits the width of the line it replaced on the 812 x 354 layout
-- (and on desktop where the line is desktop only), measured with
-- TextService:GetTextBoundsAsync in the face its Kit role draws with.
-- Usage: require(PlayerScripts.Client.ZZSpecs.UICopy)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local UICopy=require(game:GetService("ReplicatedStorage").Shared.UICopy)
 local Kit=require(client.DeckKit)
 local TextService=game:GetService("TextService")
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local sample={count=3,heat="Medium",low=6,high=8,pet="Bear",reward=5,item="Squeaky Bone",owned=3,total=12}
 local function width(text,role,size)
  local params=Instance.new("GetTextBoundsParams")
  params.Text=text;params.Font=Kit.faceFor(role,size);params.Size=size;params.Width=10000
  return TextService:GetTextBoundsAsync(params).X
 end
 local gui=Instance.new("ScreenGui");gui.Name="_UICopySpec";gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=parent
 local ok,problem=pcall(function()
  test("every key resolves to a non-empty string with no unfilled placeholder",function()
   local keys=UICopy.keys();assert(#keys>=30,"table has the moved strings ("..#keys..")")
   for _,key in ipairs(keys)do
    assert(UICopy.has(key),key)
    local text=UICopy.get(key,sample)
    assert(type(text)=="string"and text~=""and text~=key,key.." resolves")
    assert(not string.find(text,"{",1,true),key.." leaves a placeholder: "..text)
   end
   assert(not UICopy.has("results.leave")and not UICopy.has("no.such.key"),"sections and typos are not strings")
   assert(UICopy.get("no.such.key")=="no.such.key","a missing key shows itself")
  end)
  test("placeholders fill from vars; a missing var stays visible; no concatenation needed",function()
   assert(UICopy.get("results.nudge.up",{heat="Medium",low=6,high=8})=="Brave? Medium pays 6 to 8")
   assert(UICopy.get("results.nudge.again",{heat="Hard",low=9,high=12})=="A win on Hard pays 9 to 12")
   assert(UICopy.get("quests.allDone",{pet="Bear"})=="All done. Bear is impressed.")
   assert(UICopy.get("results.nudge.up",{heat="Easy"})=="Brave? Easy pays {low} to {high}")
   local one,many,none=UICopy.starsShort(1),UICopy.starsShort(12),UICopy.starsShort(nil)
   assert(one[1]=="1 Star short. One more round?"and one[2]=="1 Star short")
   assert(many[1]=="12 Stars short. One more round?"and many[2]=="12 Stars short")
   assert(#none==1 and none[1]==UICopy.get("shop.reason.needStars")and UICopy.starsShort(0)[1]==none[1])
  end)
  test("every key the P1 call sites read exists",function()
   for _,key in ipairs({"hatch.footer.desktop","hatch.footer.phone","hatch.promise","hatch.egg.toy.line","hatch.egg.material.line",
    "hatch.egg.hue.line","hatch.egg.feature.line","hatch.egg.material.per","style.promise.faceplates","style.promise.backgrounds",
    "style.promise.balls","style.balls.pitch","results.leave.wide","results.leave.mid","results.leave.narrow","results.saved.done",
    "results.saved.pending","results.nudge.up","results.nudge.again","shop.short.one","shop.short.many","shop.short.plain",
    "shop.short.plainOne","shop.reason.needStars","shop.reason.busy","shop.reason.throttled","shop.reason.priceChanged",
    "shop.reason.unowned","shop.reason.notOwned","shop.reason.retrying","shop.failed.bought","shop.failed.applied","shop.failed.saved",
    "items.note.empty","items.note.full","menu.subtitle.locked","menu.subtitle.empty","menu.subtitle.paused",
    "wardrobe.emptySlot","companions.wearing.none"})do
    assert(UICopy.has(key),"missing "..key)
   end
   local View=require(client.EggHatchView);assert(View.EggCopy.material.line==UICopy.get("hatch.egg.material.line"))
   local Carousel=require(client.ItemCarousel);assert(Carousel.FullNote==UICopy.get("items.note.full")and Carousel.EmptyNote==UICopy.get("items.note.empty"))
   local Balls=require(client.BallShop);assert(Balls.Reasons.NeedStars==UICopy.get("shop.reason.needStars"))
   local Shop=require(client.FaceplateShop);assert(Shop.Hints[3].promise==UICopy.get("style.promise.balls"))
  end)
  test("every key the play-forever F2 call sites read exists (book, stamp card, restricted eggs)",function()
   for _,key in ipairs({"book.title","book.eyebrow","book.entry.line","book.entry.claimOne","book.entry.claimMany","book.records.name",
    "book.records.line","book.records.empty","book.promise","book.claim","book.claimShort","book.claimed","book.pending","book.retrying",
    "book.timeout","book.failed","book.owned","book.found","book.missing","book.empty","book.bookworm.line","book.bookworm.short",
    "book.bookworm.done","book.bookworm.count","book.toast.claimed","book.toast.bookworm","book.hint.pages","book.hint.move",
    "book.hint.claim","book.hint.back","stamp.title","stamp.promise","stamp.next","stamp.tomorrow","stamp.full","stamp.button",
    "stamp.done","stamp.landed","hatch.next.label","hatch.next.line","hatch.next.done"})do
    assert(UICopy.has(key),"missing "..key)
   end
   local View=require(client.BookView)
   for _,key in ipairs(View.StatsOrder)do assert(UICopy.has("book.stats."..key),"missing Records label "..key)end
   assert(UICopy.has("book.stats.stamps"))
   assert(UICopy.get("stamp.promise")=="No streaks. Miss a day, lose nothing.","the stamp card promise reads as the scope wrote it")
  end)
  -- {key, role, size, width (px of the line it replaces), where, vars}
  local rows={
   {"hatch.footer.phone","Small",12,226-10-8,"phone list note (812 x 354)"},
   {"hatch.footer.desktop","Small",14,334-10-8,"desktop list note"},
   {"hatch.promise","Small",14,400,"desktop hint bar promise"},
   {"hatch.egg.material.line","Small",12,226-10-100,"phone egg row line (812 x 354)"},
   {"hatch.egg.material.line","Small",14,334-10-100,"desktop egg row line"},
   {"style.balls.pitch","Small",14,288,"Balls pane status (desktop only)"},
   {"style.promise.balls","Small",14,300,"Deck style hint bar promise (desktop only)"},
   {"results.saved.done","Small",14,248-36,"results wallet line (desktop; hidden on phones)"},
   {"results.nudge.up","BodyMedium",16,248-36,"results nudge (desktop)",{heat="Medium",low=6,high=8}},
   {"results.nudge.up","BodyMedium",16,248-36,"results nudge (desktop)",{heat="Hard",low=9,high=12}},
   {"results.leave.mid","Button",15,160-26-10,"phone Leave button (160, glyph shown)"},
   {"results.leave.wide","Button",22,392-26-10,"desktop Leave button (392)"},
   {"shop.short.plain","Body",14,232-24,"phone shop status (812 x 354), worst price",{count=120}},
   {"items.note.full","Strong",16,260,"board note (auto-sized pill on the board)"},
   -- Play-forever F2 (new lines; the widths are the cells they sit in).
   {"book.claim","Button",15,113-16,"desktop book milestone button (113)",{reward=15}},
   {"book.claim","Button",14,128-16,"phone book milestone button (128; under 15 px the label is Builder Sans Bold)",{reward=15}},
   {"book.records.line","Small",12,192-24,"phone Records tile line (812 x 354)"},
   {"book.entry.line","Small",12,812-20-232-72-170,"phone Companions hub row line (812 x 354)"},
  }
  test("changed lines fit the width of the line they replace (GetTextBoundsAsync, role face)",function()
   for _,row in ipairs(rows)do
    local text=UICopy.get(row[1],row[6])
    local w=width(text,row[2],row[3])
    assert(w<=row[4],string.format("%s '%s' is %.1f px, line is %d (%s)",row[1],text,w,row[4],row[5]))
   end
  end)
  test("Kit.measure follows the role face and agrees with GetTextBoundsAsync",function()
   for _,case in ipairs({{"Back to the garden","Button",22},{"Leave","Button",15},{"Tucked into your wallet","Small",14},{"Hatch","Button",14}})do
    local m=Kit.measure(case[1],case[2],case[3]).X;local w=width(case[1],case[2],case[3])
    assert(math.abs(m-w)<=1,case[1].." measure "..m.." vs "..w)
   end
   assert(Kit.faceFor("Button",14)~=Kit.DisplayFace and Kit.faceFor("Button",15)==Kit.DisplayFace,"Fredoka only at 15 px and up")
   assert(Kit.faceFor("Body",16)==Kit.Type.Body[3],"body text keeps Builder Sans")
  end)
  test("Pocket menu subtitle: the locked line keeps the subtitle where the old line kept it (812 x 354)",function()
   local Screen=require(client.DeckScreen);local Pocket=require(client.PocketMenu)
   local size=Vector2.new(812,354)
   local root=Instance.new("Frame");root.Size=UDim2.fromOffset(size.X,size.Y);root.BackgroundTransparency=1;root.Parent=gui
   local s=Screen.new({parent=root,overlayParent=root,viewRoot=root})
   local menu=Pocket.new(s:addOverlay("Pocket",36,{lcd=true}),{})
   s:layout(size,(11+.8)/(19+.8),{kx=116,kh=58});s:setVisible(true)
   menu:open({empty=true,locked=true,canRestart=false,canQuit=false,canHatch=false,canCustomize=false});task.wait(.3)
   local sub=menu.subtitle;local row=sub.Size.X.Offset
   local tw=Kit.measure(menu.title.Text,"Title",menu.title.TextSize).X
   local oldFits=tw+16+math.max(width("Round not started","Body",sub.TextSize),width("Win a round to unlock","Body",sub.TextSize))<=row
   assert(sub.Text==UICopy.get("menu.subtitle.locked"))
   assert(not oldFits or sub.Visible,"the voiced locked line hides a subtitle the old line showed")
   root:Destroy()
  end)
 end)
 gui:Destroy()
 assert(ok,problem)
 return{passed=#cases,cases=cases}
end
