-- Same gesture methods as native CAS; deterministic hold clock, no server sends.
return function(client)
 local Focus=require(client.PetFocusUI);local cases={}
 local function test(name,run)run();table.insert(cases,name)end
 local function fixture()
  local now,owns=0,true;local count={greet=0,start=0,stop=0}
  local f=setmetatable({active=true,glove={},helper={Visible=false},callbacks={greet=function()count.greet+=1;return true end,
   canReact=function()return owns end,petContact=function(active)if active then count.start+=1 else count.stop+=1 end;return false end},
   clock=function()return now end,canOwnInput=function()return owns end},Focus)
  return f,count,function(dt)now+=dt;f:checkContactDeadline()end,function(value)owns=value end
 end
 local E={UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.E}
 local X={UserInputType=Enum.UserInputType.Gamepad1,KeyCode=Enum.KeyCode.ButtonX}
 test("short E tap greets once without opening a reward contact",function()
  local f,c,advance=fixture();f:handleGreet(Enum.UserInputState.Begin,E);advance(.2);f:handleGreet(Enum.UserInputState.End,E)
  assert(c.greet==1 and c.start==0 and c.stop==0 and not f.heldGreet)
 end)
 test("same held E crosses threshold once and remains deliberate until release",function()
  local f,c,advance=fixture();f:handleGreet(Enum.UserInputState.Begin,E);advance(.36);assert(c.start==1 and f:contactValid())
  for _=1,60 do advance(.1);f:handleGreet(Enum.UserInputState.Begin,E)end
  assert(c.greet==1 and c.start==1);f:handleGreet(Enum.UserInputState.End,E);assert(c.stop==1 and not f:contactValid())
 end)
 test("controller X uses identical held admission and matching release",function()
  local f,c,advance=fixture();f:handleGreet(Enum.UserInputState.Begin,X);advance(.36);f:handleGreet(Enum.UserInputState.End,E);assert(f:contactValid())
  f:handleGreet(Enum.UserInputState.End,X);assert(c.greet==1 and c.start==1 and c.stop==1)
 end)
 test("carried opener E and X drain without greeting or later idle admission",function()
  for _,input in ipairs({E,X})do local f,c,advance=fixture();f.openingGreetE=input==E;f.openingGreetDevice=if input==X then X.UserInputType else nil
   f:handleGreet(Enum.UserInputState.Begin,input);advance(2);f:handleGreet(Enum.UserInputState.End,input)
   assert(c.greet==0 and c.start==0);f:handleGreet(Enum.UserInputState.Begin,input);assert(c.greet==1)
  end
 end)
 test("cancel blur and owner loss end once without a release tap",function()
  for _,route in ipairs({"cancel","blur","owner"})do local f,c,advance,owns=fixture();f:handleGreet(Enum.UserInputState.Begin,X);advance(.36)
   if route=="cancel"then f:handleGreet(Enum.UserInputState.Cancel,X)elseif route=="blur"then f:loseWindowFocus()else owns(false);f:handleGreet(Enum.UserInputState.Begin,X)end
   f:handleGreet(Enum.UserInputState.End,X);assert(c.start==1 and c.stop==1 and c.greet==1 and not f:contactValid())
  end
 end)
 test("background rejects fresh keys and pointer while muted foreground stays eligible",function()
  local f,c,advance=fixture();f:loseWindowFocus()
  assert(f:handleGreet(Enum.UserInputState.Begin,E)==Enum.ContextActionResult.Pass);advance(1)
  assert(not f:beginPointer({UserInputType=Enum.UserInputType.MouseButton1})and c.greet==0 and c.start==0 and not f:contactValid())
  f:gainWindowFocus();advance(1);assert(c.start==0 and not f.heldGreet)
  f:handleGreet(Enum.UserInputState.Begin,E);advance(.36);assert(c.start==1 and f:contactValid())
 end)
 test("blurred held gesture drains its release and refocus cannot auto restart",function()
  local f,c,advance=fixture();f:handleGreet(Enum.UserInputState.Begin,X);advance(.36);f:loseWindowFocus();assert(c.stop==1)
  f:gainWindowFocus();advance(1);f:handleGreet(Enum.UserInputState.Begin,X);advance(1);assert(c.start==1)
  f:handleGreet(Enum.UserInputState.End,X);f:handleGreet(Enum.UserInputState.Begin,X);advance(.36);assert(c.start==2)
 end)
 test("no key press or mere focused time can open contact",function()
  local f,c,advance=fixture();for _=1,120 do advance(.1)end;assert(c.start==0 and c.greet==0 and not f:contactValid())
 end)
 return cases
end
