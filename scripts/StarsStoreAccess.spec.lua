-- Studio Client. Stars store access (STARS-STORE-ACCESS-PLAN-2026-11-21.md): the header
-- wallet is a tap key (opt-in), the "need more Stars" card (StarsShort on ConfirmDialog's new
-- alt choice), and the Kit "tappable but dim" state the short buy buttons use.
-- Usage: require(PlayerScripts.Client.ZZSpecs.StarsStoreAccess)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Kit=require(client.DeckKit)
 local Confirm=require(client.ConfirmDialog)
 local Short=require(client.StarsShort)
 local UICopy=require(game:GetService("ReplicatedStorage").Shared.UICopy)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function settle()task.wait();task.wait()end
 local host=Instance.new("ScreenGui");host.Name="StarsStoreAccessSpec";host.ResetOnSpawn=false;host.Parent=parent
 local frame=Instance.new("Frame");frame.Size=UDim2.fromOffset(600,200);frame.Parent=host

 test("count and words: the shortfall, one Star, no item",function()
  assert(Short.count(40,12)==28 and Short.count(40,40)==0 and Short.count(40,99)==0 and Short.count(nil,nil)==0)
  local w=Short.copy({price=40,wallet=12,item="Sun Hat"})
  assert(w.count==28 and w.title==UICopy.get("starsShort.title",{count=28}),w.title)
  assert(w.line:find("Sun Hat",1,true)and w.line:find("40",1,true),w.line)
  assert(Short.copy({price=13,wallet=12}).title==UICopy.get("starsShort.titleOne"))
  assert(Short.copy({price=13,wallet=12}).line==UICopy.get("starsShort.lineNoItem"))
  assert(w.buy=="Get Stars"and w.earn=="Play a round")
 end)

 test("no route or enough Stars: nothing shows",function()
  Short.setRoute(nil)
  assert(Short.ask({price=40,wallet=0})==false and not Confirm.isOpen())
  Short.setRoute(function()end)
  assert(Short.ask({price=40,wallet=40})==false and not Confirm.isOpen())
  Short.setRoute(nil)
 end)

 test("Get Stars routes store, Play a round routes earn, close routes nothing",function()
  local calls={}
  Short.setRoute(function(choice,request)table.insert(calls,choice.."|"..tostring(request.from))end)
  assert(Short.ask({price=40,wallet=12,item="Sun Hat",from="wardrobe"}))
  local panel=Confirm.panel()
  assert(panel and panel.Title.Text==UICopy.get("starsShort.title",{count=28}))
  assert(panel:FindFirstChild("Alt")and panel:FindFirstChild("Confirm")and panel:FindFirstChild("Close"),"two choices and a close key")
  assert(panel.Alt:GetAttribute("AccessibleLabel")=="Play a round"and panel.Confirm:GetAttribute("AccessibleLabel")=="Get Stars")
  assert(panel.Alt.AbsoluteSize.X==panel.Confirm.AbsoluteSize.X,"equal footing")
  assert(Confirm.accept());settle();assert(calls[1]=="store|wardrobe",calls[1])
  assert(Short.ask({price=40,wallet=12,from="style"}))
  assert(Confirm.chooseAlt());settle();assert(calls[2]=="earn|style",tostring(calls[2]))
  assert(Short.ask({price=40,wallet=12,from="names"}))
  assert(Confirm.close("back"));settle();assert(#calls==2,"closing routes nowhere")
  assert(not Confirm.chooseAlt(),"alt with nothing open does nothing")
  Short.setRoute(nil)
 end)

 test("the card closes with the screen that raised it, and routes nowhere",function()
  local calls=0
  Short.setRoute(function()calls+=1 end)
  local owner={}
  assert(Short.ask({price=40,wallet=12,from="wardrobe"},owner)and owner.confirmHandle~=nil)
  Confirm.cancelFor(owner);settle()
  assert(not Confirm.isOpen()and owner.confirmHandle==nil and calls==0)
  assert(Short.ask({price=40,wallet=12,from="wardrobe"},owner));Confirm.accept();settle()
  assert(calls==1 and owner.confirmHandle==nil,"a choice clears the owner's handle")
  Short.setRoute(nil)
 end)

 test("a plain confirm keeps Cancel and has no close key",function()
  local alt=0
  Confirm.ask({title="Buy?",line="",alt=nil})
  local panel=Confirm.panel()
  assert(panel:FindFirstChild("Cancel")and not panel:FindFirstChild("Alt")and not panel:FindFirstChild("Close"))
  assert(Confirm.chooseAlt()==false and Confirm.isOpen(),"no alt: X does nothing")
  Confirm.close("cancel");settle()
  assert(alt==0 and not Confirm.isOpen())
 end)

 test("a header wallet takes taps; other wallets do not",function()
  local plain=Kit.wallet(frame,32)
  assert(plain.tap==nil and plain.root:FindFirstChild("Tap")==nil)
  local w=Kit.wallet(frame,44,{tap=true})
  assert(w.tap and w.tap.Selectable==false and w.tap:GetAttribute("AccessibleLabel")=="Get Stars")
  assert(w.tap.ZIndex>w.star.ZIndex,"above the Star")
  local seen=0
  Kit.onWalletTap=function(api)seen+=1;assert(api==w);return false end
  -- Activated cannot be fired from a script: call the hook the way the key does.
  local ok=Kit.onWalletTap(w)
  assert(seen==1 and ok==false)
  Kit.onWalletTap=nil
  w.set(15);assert(w.amount.Text=="15","the number is untouched")
 end)

 test("tappable keeps the dim paint but takes presses",function()
  local b,s=Kit.button(frame,"Buy",{text="★ Buy 40"})
  Kit.setEnabled(b,false)
  assert(b.Interactable==false and s.enabled==false)
  Kit.setTappable(b,true)
  assert(b.Interactable==true and b.Active==true and s.enabled==false,"still painted disabled")
  Kit.setEnabled(b,false)
  assert(b.Interactable==true,"a repaint keeps the press")
  Kit.setTappable(b,false)
  assert(b.Interactable==false)
  Kit.setEnabled(b,true);assert(b.Interactable==true and s.enabled==true)
 end)

 test("shops keep the short state text and price",function()
  local Wardrobe=require(client.WardrobeShop)
  local ok,status=pcall(Wardrobe.status,"pip","sunhat",{row={owned={},equipped={}},wallet=12})
  assert(ok and status.kind=="short"and status.price and status.enabled==false,tostring(status and status.kind))
  assert(status.text==require(client.ShopPriceState).need(status.price,12))
 end)

 host:Destroy()
 return{passed=#cases,cases=cases}
end
