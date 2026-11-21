-- Studio Client. Round 3 (Spencer 2026-11-20): the confirm dialog for big spends and actions
-- that can't be undone. Pure layout; ask shows one card; yes / cancel / handle.cancel run their
-- callbacks once, after the close; a second ask replaces the first; it fits phone and desktop.
-- Usage: require(PlayerScripts.Client.ZZSpecs.ConfirmDialog)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Confirm=require(client.ConfirmDialog)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function settle()task.wait();task.wait()end
 test("layout fits a phone and a desktop with two equal keys",function()
  local phone=Confirm.layout(844,390,40);local desk=Confirm.layout(1280,720,40)
  assert(phone.compact and not desk.compact)
  assert(phone.w<=844-32 and phone.h<=390 and desk.w==440)
  assert(phone.buttonW*2+12==phone.w-phone.pad*2 or phone.buttonW*2+12==phone.w-phone.pad*2-1)
 end)
 test("yes runs onConfirm once, after the close",function()
  local yes,no,closed=0,0,nil
  local h=Confirm.ask({title="Adopt the Bunny?",line="Line",confirm="Adopt ★ 400",onConfirm=function()yes+=1;assert(not Confirm.isOpen())end,
   onCancel=function()no+=1 end,onClosed=function(c)closed=c end})
  assert(h and Confirm.isOpen()and Confirm.panel()~=nil and Confirm.panel().Title.Text=="Adopt the Bunny?")
  assert(Confirm.accept());settle()
  assert(yes==1 and no==0 and closed==true and not Confirm.isOpen()and Confirm.panel()==nil)
  assert(not Confirm.accept(),"a second yes does nothing")
 end)
 test("cancel, the owner's handle and a replacing ask all cancel",function()
  local no={}
  local h=Confirm.ask({title="A",line="",onCancel=function(r)table.insert(no,r)end})
  assert(Confirm.close("back"));settle();assert(no[1]=="back")
  h=Confirm.ask({title="B",line="",onCancel=function(r)table.insert(no,r)end})
  assert(h.isOpen()and h.cancel());settle();assert(no[2]=="owner"and not Confirm.isOpen())
  assert(not h.cancel(),"a stale handle does nothing")
  local first=Confirm.ask({title="C",line="",onCancel=function(r)table.insert(no,r)end})
  local second=Confirm.ask({title="D",line=""})
  settle();assert(no[3]=="replaced"and not first.isOpen()and second.isOpen()and Confirm.panel().Title.Text=="D")
  assert(not first.cancel()and second.cancel())
 end)
 return{passed=#cases,cases=cases}
end
