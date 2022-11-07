local rawget = rawget
local rawset = rawset

local originalReceiver
local enabled = CreateConVar( "express_enable_fpp", "1", { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Enable FPP Bindings" )

local function enable()
    if not enabled:GetBool() then return end

    originalReceiver = originalReceiver or net.Receivers["FPP_TouchabilityData"]
    net.Receivers["FPP_TouchabilityData"] = nil

    local entOwners = FPP.entOwners
    local entTouchabiiity = FPP.entTouchability
    local entTouchReasons = FPP.entTouchReasons

    express.Listen( "fpp_touchability_data", function( data )
        local dataCount = #data
        for i = 1, dataCount, 4 do
            local ent = rawget( data, i )
            local owner = rawget( data, i + 1 )
            local touchability = rawget( data, i + 2 )
            local reason = rawget( data, i + 3 )

            rawset( entOwners, ent, owner )
            rawset( entTouchabiiity, ent, touchability )
            rawset( entTouchReasons, ent, reason )
        end
    end )
end

local function disable()
    if enabled:GetBool() then return end

    net.Receive( "FPP_TouchabilityData", originalReceiver )
    express.RemoveListener( "fpp_touchability_data" )
end

cvars.AddChangeCallback( "express_enable_fpp", "setup_teardown", function( _, old, new )
    if new == 0 and old ~= 0 then
        return disable()
    end

    if new ~= 0 then
        return enable()
    end
end )

hook.Add( "InitPostEntity", "Express_FPPBindings", begin )
