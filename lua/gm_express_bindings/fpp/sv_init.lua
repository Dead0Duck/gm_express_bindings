local rawget = rawget
local table_insert = table.insert

local originalPlySendTouchData
local enabled = CreateConVar( "express_enable_fpp", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable FPP Bindings" )

local function enable()
    if not FPP then return end
    if not enabled:GetBool() then return end
    originalPlySendTouchData = originalPlySendTouchData or FPP.plySendTouchData

    local function writeEntData( ply, ent, tbl )
        local cppiOwner = ent:CPPIGetOwner()
        local owner = IsValid( cppiOwner ) and cppiOwner:EntIndex() or -1

        local restrictConstraint = ent.FPPRestrictConstraint
        local touchability = rawget( restrictConstraint and restrictConstraint or ent.FPPCanTouch, ply )

        local constraintReasons = ent.FPPConstraintReasons
        local reasons = rawget( constraintReasons and constraintReasons or ent.FPPCanTouchWhy, ply )

        table_insert( tbl, ent:EntIndex() )
        table_insert( tbl, owner )
        table_insert( tbl, touchability )
        table_insert( tbl, reasons )
    end

    FPP.plySendTouchData = function( ply, ents )
        -- Technically this breaks out before <300 ents, but that's correct too
        if not ply.Express_CanReceiveFPP then return end

        if #ents < 300 then
            return originalPlySendTouchData( ply, ents )
        end

        local tbl = {}
        for i = 1, #ents do
            writeEntData( ply, rawget( ents, i ), tbl )
        end

        express.Send( "fpp_touchability_data", tbl, ply )
    end
end

local function disable()
    if enabled:GetBool() then return end
    FPP.plySendTouchData = originalPlySendTouchData
end

cvars.AddChangeCallback( "express_enable_fpp", function( _, old, new )
    if new == 0 and old ~= 0 then
        return disable()
    end

    if new ~= 0 then
        return enable()
    end
end, "setup_teardown" )

hook.Add( "PlayerFullLoad", "Express_FPPBindings", function( ply )
    ply.Express_CanReceiveFPP = true
end )

hook.Add( "InitPostEntity", "Express_FPPBindings", function()
    if enabled:GetBool() then enable() end
end )
