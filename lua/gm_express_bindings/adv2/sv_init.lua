local ogSendToClient
local enabled = CreateConVar( "express_enable_adv2", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable AdvDupe2 Bindings" )

local function enable()
    if not AdvDupe2 then return end
    if not enabled:GetBool() then return end

    ogSendToClient = ogSendToClient or AdvDupe2.SendToClient
    function AdvDupe2.SendToClient( ply, autoSave, data )
        if not IsValid( ply ) then return end
        ply.AdvDupe2.Downloading = true
        AdvDupe2.InitProgressBar( ply, "Saving:" )

        local sendData  = {
            autoSave = autoSave,
            data = data
        }

        express.Send( "advdupe2_receivefile", sendData, ply, function( cbPly )
            cbPly.AdvDupe2.Downloading = false
        end )
    end

    express.Receive( "advdupe2_receivefile", function( ply, data )
        if not IsValid( ply ) then return end
        ply.AdvDupe2.Uploading = true
        AdvDupe2.InitProgressBar( ply, "Opening: " )

        local name = data.name
        local fileData = data.data
        print( "Received AdvDupe2 File: ", name, fileData )

        if not ply.AdvDupe2 then ply.AdvDupe2 = {} end

        local _1, _2, _3 = string.find( name, "([%w_]+)" )
        if _3 then
            ply.AdvDupe2.Name = string.sub( _3, 1, 32 )
        else
            ply.AdvDupe2.Name = "Advanced Duplication"
        end

        AdvDupe2.LoadDupe( ply, AdvDupe2.Decode( fileData ) )
        ply.AdvDupe2.Uploading = false
    end )
end

local function disable()
    if enabled:GetBool() then return end
    AdvDupe2.SendToClient = ogSendToClient
end

cvars.AddChangeCallback( "express_enable_adv2", function( _, old, new )
    if new == 0 and old ~= 0 then
        return disable()
    end

    if new ~= 0 then
        return enable()
    end
end, "setup_teardown" )

hook.Add( "InitPostEntity", "Express_Adv2Bindings", function()
    if enabled:GetBool() then enable() end
end )
