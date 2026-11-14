-- Studio Client. Pocket Deck Slim geometry, touch targets, token contrast and the
-- DeckKit component states (UI-SPEC-2026-11-12 sections 1-4 and 7).
-- Usage: require(PlayerScripts.Client.ZZSpecs.DeckScreen)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Screen=require(client.DeckScreen);local Kit=require(client.DeckKit);local Art=require(client.DeckArt)
 local Themes=require(game.ReplicatedStorage.Shared.DeckThemes)
 local aspect=(11+.8)/(19+.8)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function near(a,b,e)return math.abs(a-b)<=(e or .51)end
 local function lum(c)
  local function ch(v)return if v<=.03928 then v/12.92 else((v+.055)/1.055)^2.4 end
  return .2126*ch(c.R)+.7152*ch(c.G)+.0722*ch(c.B)
 end
 local function contrast(a,b)local x,y=lum(a),lum(b);return(math.max(x,y)+.05)/(math.min(x,y)+.05)end
 local gui=Instance.new("ScreenGui");gui.Name="_DeckScreenSpec";gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=parent
 local old=Art.getTheme()
 local ok,problem=pcall(function()
  test("1920x1080 reference: s = 1, deck at (160,150), LCD at (536,246), board 584 high in the centre",function()
   local g=Screen.resolve(Vector2.new(1920,1080),aspect)
   assert(g.s==1 and g.mode=="Regular")
   assert(near(g.deck.x,160)and near(g.deck.y,150)and near(g.lcd.x,536)and near(g.lcd.y,246),"deck/LCD origin")
   assert(g.boardLocal.h==584 and g.boardLocal.y==12 and near(g.boardLocal.x+g.boardLocal.w/2,424,1),"board centred in the LCD")
   assert(g.column>=200,"side panels keep their width")
  end)
  test("1649x971 is still s = 1; small desktop roots scale down but stay Regular above 0.75",function()
   assert(Screen.resolve(Vector2.new(1649,971),aspect).s==1)
   local g=Screen.resolve(Vector2.new(1300,700),aspect);assert(g.s<1 and g.s>=.75 and not g.compact)
  end)
  test("phone landscape 733x307 is the Compact phone layout; 1024x768 keeps the small scaled LCD",function()
   local g=Screen.resolve(Vector2.new(733,307),aspect)
   assert(g.mode=="Compact"and g.phone and g.s==1 and g.board.h==307-80 and g.contentScale==1,"phone layout in real px (glass under the Roblox controls: H - 80)")
   -- QA v2 R6.1: the phone handheld body around that LCD (the board size is unchanged).
   assert(g.body and g.body.x==4 and g.body.w==733-8 and g.body.y<g.glass.y and g.body.y+g.body.h>307,"phone handheld body")
   local small=Screen.resolve(Vector2.new(1024,768),aspect)
   assert(small.mode=="Small"and small.compact and near(small.s,(768-8)/608,.001)and small.authored==Screen.Compact,"the 1024x768 band is unchanged")
  end)
  test("every hardware target is at least 44 px on the phone and the back arrow is 44",function()
   local root=Instance.new("Frame");root.Size=UDim2.fromOffset(733,307);root.BackgroundTransparency=1;root.Parent=gui
   local s=Screen.new({parent=root,overlayParent=root,viewRoot=root});s:layout(Vector2.new(733,307),aspect);s:setVisible(true)
   task.wait()
   for dir,q in pairs(s.quadrants)do if q.Visible then assert(q.AbsoluteSize.X>=44 and q.AbsoluteSize.Y>=44,q.Name)else assert(dir=="Up"or dir=="Down")end end
   -- QA v2 R6.1: the phone draws A and B; B is the B sprite under the item button, whose
   -- hit (8 px wider than the disc) is its target. MENU is on the left shoulder.
   for id,b in pairs(s.buttons)do
    assert(b.holder.Visible,id.." drawn")
    if id=="B"then assert(not b.hit.Visible,"phone B uses the item button's hit")
    else assert(b.hit.AbsoluteSize.X>=44 and b.hit.AbsoluteSize.Y>=44,id)end
   end
   assert(s.itemButton.hit.AbsoluteSize.X>=44 and s.itemButton.hit.AbsoluteSize.Y>=44,"B / Items target")
   -- QA v2 R2.4: in a round Left / Right are the tall halves of the d-pad box.
   assert(s.quadrants.Left.AbsoluteSize.Y>=s.dpad.AbsoluteSize.Y+48 and not s.quadrants.Up.Visible,"round d-pad halves take the Up / Down area")
   assert(s.menu.Visible and s.menuHit.AbsoluteSize.Y>=44 and s.back.root.AbsoluteSize.X==44)
   -- Compact HUD type never goes under 12.
   for _,node in ipairs(s.hudRoot:GetDescendants())do if node:IsA("TextLabel")and node.Text~=""then assert(node.TextSize>=12,node:GetFullName())end end
   root:Destroy()
  end)
  test("HUD fills from replicated data without inventing numbers",function()
   local root=Instance.new("Frame");root.Size=UDim2.fromOffset(1920,1080);root.BackgroundTransparency=1;root.Parent=gui
   local s=Screen.new({parent=root,overlayParent=root,viewRoot=root});s:layout(Vector2.new(1920,1080),aspect)
   s:setHud({score=2340,best=2210,chain=7,goals={{text="Match I + I in CENTER",done=true,progress=1,target=1},{text="Make III on RIGHT",done=false,progress=0,target=1}},
    daily={{title="Win 2 rounds",progress=1,target=2}},next={2,1,3},eggsLeft=14,budget=24,input="Gamepad"})
   local h=s.hud
   assert(h.score.Text=="2340"and h.best.Text=="BEST 2210"and h.chain.Text=="×7")
   assert(h.goalsCount.Text=="1/2"and h.goals[3].row.Visible==false and h.eggs.Text=="14"and h.budget.Text=="/24")
   assert(h.diffName.Text=="Medium"and h.daily[1].count.Text=="1/2"and not h.daily[2].name.Visible)
   s:setHud({score=0,goals={},message="1/3 AIM & DROP",statusLabel=nil,next={1,1,1},eggsLeft=24,budget=24})
   assert(h.status.Visible and h.goalsCount.Text=="")
   s:setHud({score=0,goals={{text="A",progress=0,target=1}},statusLabel="Settling…",next={1,1,1},eggsLeft=3,budget=24})
   assert(h.goalsEyebrow.Text=="SETTLING…")
   root:Destroy()
  end)
  test("text roles keep 4.5:1 on every starter plate's glass; ink keeps 4.5:1 on the accent",function()
   for _,id in ipairs(Themes.Order)do
    local t=Themes.ById[id]
    for _,surface in ipairs({t.ui.panel,t.ui.raised,t.ui.inset})do
     for _,role in ipairs({"text","soft","dim"})do assert(contrast(Kit.Color[role],surface)>=4.5,id.." "..role)end
     assert(contrast(Kit.Color.stars,surface)>=4.5,id.." stars")
    end
    assert(contrast(t.ui.ink,t.ui.accent)>=4.5,id.." ink on accent")
   end
  end)
  test("button states: selected 2 px accent, disabled leaves the selection tree, press drops onto the lip",function()
   Art.applyTheme(Themes.ById.ice)
   local holder=Instance.new("Frame");holder.Size=UDim2.fromOffset(400,200);holder.Parent=gui
   local b,state=Kit.button(holder,"Probe",{text="Leave",glyph="B"})
   assert(b.AbsoluteSize.Y==48 and state.stroke.Thickness==1 and near(state.stroke.Transparency,.86,.01))
   Kit.setSelected(b,true);assert(state.stroke.Thickness==2 and state.stroke.Color==Art.uiTheme().ui.accent)
   Kit.setEnabled(b,false);assert(not b.Active and not b.Interactable and state.label.TextTransparency>0)
   -- UI personality T2 (deliberate change): a secondary button now has a 4 px lip and
   -- the face (Fill + Content) drops onto it in 60 ms, instead of the content settling 2 px.
   Kit.setEnabled(b,true);state.pressed=true;Kit.paintButton(b);task.wait(.12)
   assert(state.lip==4 and state.ledge==4 and state.edge.Visible and state.content.Position.Y.Offset==4 and state.fill.Position.Y.Offset==4,"secondary press drops the face onto its 4 px lip")
   state.pressed=false;Kit.paintButton(b)
   local p,ps=Kit.button(holder,"Primary",{variant="primary",text="Replay",glyph="A"})
   assert(ps.fill.BackgroundColor3==Art.uiTheme().ui.accent and ps.label.TextColor3==Kit.Color.ink and ps.edge.Visible,"primary accent fill, ink label, lower edge")
   Art.applyTheme(Themes.ById.brick);assert(ps.fill.BackgroundColor3==Art.uiTheme().ui.accent,"a plate change leaves menu buttons on the house palette")
   holder:Destroy()
  end)
  test("focus ring sits 4 px outside its target and hides with it",function()
   local holder=Instance.new("Frame");holder.Size=UDim2.fromOffset(400,200);holder.Position=UDim2.fromOffset(10,10);holder.Parent=gui
   local b=Kit.button(holder,"Target",{text="Replay"});b.Position=UDim2.fromOffset(40,30)
   local ring=Kit.focusRing(holder);task.wait();ring.attach(b,12);task.wait()
   assert(near(ring.root.AbsolutePosition.X,b.AbsolutePosition.X-4,1)and near(ring.root.AbsoluteSize.X,b.AbsoluteSize.X+8,1)and ring.root.Visible)
   ring.hide();assert(not ring.root.Visible);holder:Destroy()
  end)
 end)
 gui:Destroy();if old then Art.applyTheme(old)end
 assert(ok,problem)
 return{passed=#cases,cases=cases}
end
