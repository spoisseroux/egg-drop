-- Owner-local snapshot presentation. Server mutations still require fenced remotes.
local Snapshot={}
local current;local listeners={}
function Snapshot.read()return current end
function Snapshot.receive(value)
 if type(value)~="table"then return false end
 if current and type(current.revision)=="number"and type(value.revision)=="number"and value.revision<current.revision then return false end
 current=value;for _,notify in pairs(listeners)do notify(value)end;return true
end
function Snapshot.subscribe(notify)
 local key={};listeners[key]=notify;if current then notify(current)end
 return function()listeners[key]=nil end
end
return Snapshot
