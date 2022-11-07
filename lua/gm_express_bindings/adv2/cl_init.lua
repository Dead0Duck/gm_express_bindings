local originalReceiver
local enabled = CreateConVar( "express_enable_adv2", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable AdvDupe2 Bindings" )

local function envOn( data )
    setfenv( originalReceiver, {
        net = {
            ReadUInt = function()
                return data.autoSave
            end,

            ReadStream = function( _, cb )
                cb( data.data )
            end
        }
    } )
end

local function envOff()
    setfenv( originalReceiver, getfenv( 0 ) )
end

local function enable()
    if not AdvDupe2 then return end
    if not enabled:GetBool() then return end

    originalReceiver = originalReceiver or net.Receivers["AdvDupe2_ReceiveFile"]
    net.Receivers["AdvDupe2_ReceiveFile"] = nil

    express.Listen( "advdupe2_receivefile", function( data )
        envOn( data )
        originalReceiver()
        envOff()
    end )
end

local function disable()
    if enabled:GetBool() then return end

    envOff()
    net.Receive( "AdvDupe2_ReceiveFile", originalReceiver )
    express.RemoveListener( "advdupe2_receivefile" )
end

cvars.AddChangeCallback( "express_enable_adv2", "setup_teardown", function( _, old, new )
    if new == 0 and old ~= 0 then
        return disable()
    end

    if new ~= 0 then
        return enable()
    end
end )

hook.Add( "InitPostEntity", "Express_Adv2Bindings", function()
    if enabled:GetBool() then enable() end
end )

