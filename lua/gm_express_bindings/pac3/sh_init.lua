AddCSLuaFile()

local Module = { default = true }

if SERVER then
    AddCSLuaFile( "cl_init.lua" )
    include( "sv_init.lua" )( Module )
else
    include( "cl_init.lua" )( Module )
end

function Module:IsValid()
    return pac ~= nil
end

ExpressBindings.RegisterModule( "pac3", Module )
