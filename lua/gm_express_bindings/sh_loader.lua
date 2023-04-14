AddCSLuaFile()
local modulesRoot = "gm_express_bindings"

local _, modules = file.Find( modulesRoot .. "/*", "LUA" )
print( "Loading " .. #modules .. " Express Bindings modules..." )

for _, module in ipairs( modules ) do
    local path = modulesRoot .. "/" .. module .. "/sh_init.lua"
    print( "Loading Express Bindings module: " .. module )
    include( path )
end
