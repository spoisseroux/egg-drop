-- Parts and board attributes replicate independently. Accept one complete serial,
-- never an old ball set merely because Mode/ResetId arrived first.
local Http=game:GetService("HttpService")
local Gate={}
function Gate.matches(serial,previous,content,sources)
 if type(serial)~="number"or serial==previous or type(content)~="table"or content.serial~=serial or type(content.ids)~="table"then return false end
 local expected,count={},0
 for _,id in ipairs(content.ids)do
  if type(id)~="number"or id%1~=0 or expected[id]then return false end
  expected[id]=true;count+=1
 end
 local seen={}
 for _,source in ipairs(sources)do
  local id=source:GetAttribute("EggId")
  if id~=nil then
   if source:GetAttribute("BoardSerial")~=serial or not expected[id]or seen[id]or type(source:GetAttribute("Tier"))~="number"then return false end
   seen[id]=true;count-=1
  end
 end
 return count==0
end
function Gate.ready(board,previous)
 local raw=board:GetAttribute("BoardContent")
 if type(raw)~="string"then return false end
 local ok,content=pcall(Http.JSONDecode,Http,raw)
 return ok and Gate.matches(board:GetAttribute("ResetId"),previous,content,board:GetChildren())
end
return Gate
