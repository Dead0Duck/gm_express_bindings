local enabled = CreateConVar( "express_enable_glib", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable GLib Bindings" )

local function enable()
    if not enabled:GetBool() then return end
end

local function disable()
    if enabled:GetBool() then return end
end

cvars.AddChangeCallback( "express_enable_glib", function( _, old, new )
    if new == 0 and old ~= 0 then
        return disable()
    end

    if new ~= 0 then
        return enable()
    end
end, "setup_teardown" )

hook.Add( "InitPostEntity", "Express_GLibBindings", function()
    if enabled:GetBool() then enable() end
end )
