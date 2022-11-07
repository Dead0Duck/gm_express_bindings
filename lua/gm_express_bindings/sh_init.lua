AddCSLuaFile()

-- TODO: Make a proper loader
if SERVER then
    include( "fpp/sv_init.lua" )
    AddCSLuaFile( "fpp/cl_init.lua" )
else
    incluide( "fpp/cl_init.lua" )
end
