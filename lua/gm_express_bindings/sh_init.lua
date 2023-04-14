AddCSLuaFile()

ExpressBindings = {}
ExpressBindings.Modules = {}
ExpressBindings.waiting = {}

if SERVER then
    util.AddNetworkString( "express_bindings_change" )
end

function ExpressBindings.waitForExpress( name, cb )
    if loaded then
        ErrorNoHalt( "ExpressBindings.waitForExpress called after Express was loaded!" )
        return cb()
    end

    ExpressBindings.waiting[name] = cb
end

-- Creates a toggleable module. Handles changes and enable/disable callbacks
function ExpressBindings.RegisterModule( name, module )
    local cvarName = "express_bindings_enable_" .. name
    local cvar = CreateConVar( cvarName, module.default and 1 or 0, FCVAR_ARCHIVE + FCVAR_REPLICATED, "Express Bindings: Enable/Disable " .. name )
    module.setting = cvar

    if SERVER then
        -- Server broadcasts changes to clients using net instead of cvar callbacks
        -- due to a bug where cvar callbacks are not called on clients for replicated cvars
        cvars.AddChangeCallback( cvarName, function( _, _, new )
            new = tobool( new )

            net.Start( "express_bindings_change" )
                net.WriteString( name )
                net.WriteBool( new )
            net.Broadcast()

            if new then
                module.enable()
            else
                module.disable()
            end
        end, "module_toggle" )
    end

    -- First load setting
    ExpressBindings.waitForExpress( name, function()
        if cvar:GetBool() then module.enable() end
    end )

    ExpressBindings.Modules[name] = module
end

hook.Add( "ExpressLoaded", "ExpressBindings_Loader", function()
    hook.Add( "Think", "ExpressBindings_Loader", function()
        hook.Remove( "Think", "ExpressBindings_Loader" )
        loaded = true

        for name, cb in pairs( ExpressBindings.waiting ) do
            local success, err = pcall( cb )
            if not success then
                ErrorNoHalt( "ExpressBindings Loader (" .. name .. ") : " .. err )
            end
        end
    end )
end )

if CLIENT then
    net.Receive( "express_bindings_change", function()
        local moduleName = net.ReadString()
        local enabled = net.ReadBool()

        local module = ExpressBindings.Modules[moduleName]
        if enabled then
            module.enable()
        else
            module.disable()
        end
    end )
end

if SERVER then
    require( "playerload" )
end

include( "sh_loader.lua" )
