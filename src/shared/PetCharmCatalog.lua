-- Free cosmetic forms. The "dot" id renders the snowflake mesh (its label is Snowflake).
-- Stored future IDs survive even when this renderer cannot draw them.
local Catalog={Version=2,SelectionsEnabled=true,Default="dot",Order=table.freeze({"dot","ring","pebble"}),
 ById=table.freeze({dot=table.freeze({name="Snowflake"}),ring=table.freeze({name="Ring"}),pebble=table.freeze({name="Pebble"})})}
function Catalog.known(id)return type(id)=="string"and Catalog.ById[id]~=nil end
function Catalog.validStored(id)return type(id)=="string"and #id>=1 and #id<=64 and id:match("^[a-z][a-z0-9_%-]*$")~=nil end
function Catalog.renderShape(id)return if Catalog.known(id)then id else Catalog.Default end
return table.freeze(Catalog)
