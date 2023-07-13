AddCSLuaFile()

local Module = { default = true }

if SERVER then
    AddCSLuaFile( "cl_init.lua" )
    include( "sv_init.lua" )( Module )
else
    include( "cl_init.lua" )( Module )
end

function Module:IsValid()
    return AdvDupe2 ~= nil
end

ExpressBindings.RegisterModule( "adv2", Module )
