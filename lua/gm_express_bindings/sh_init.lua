AddCSLuaFile()

-- TODO: Make a proper loader
if SERVER then
    include( "fpp/sv_init.lua" )
    AddCSLuaFile( "fpp/cl_init.lua" )

    include( "adv2/sv_init.lua" )
    AddCSLuaFile( "adv2/cl_init.lua" )
else
    include( "fpp/cl_init.lua" )
    include( "adv2/cl_init.lua" )
end
