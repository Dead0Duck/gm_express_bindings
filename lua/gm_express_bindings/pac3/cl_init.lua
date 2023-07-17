local table_Merge = table.Merge
local table_insert = table.insert

return function( Module )
    function Module.Enable()
        local pace_IsPartSendable = pace.IsPartSendable
        local pace_CreateWearFilter = pace.CreateWearFilter

        Module.ogWearOnServer = Module.ogWearOnServer or pace.WearOnServer
        Module.ogSendPartToServer = Module.ogSendPartToServer or pace.SendPartToServer

        pace.WearOnServer = function( filter )
            local allowed, reason = pac.CallHook( "CanWearParts", pac.LocalPlayer )
            if allowed == false then
                pac.Message( reason or "the server doesn't want you to wear parts for some reason" )
                return false
            end

            local parts = {}

            pace.SendPartToServer = function( part, extra )
                if not pace_IsPartSendable( part ) then
                    return false
                end

                local data = { part = part:ToTable() }
                if extra then
                    table_Merge( data, extra )
                end

                data.owner = part:GetPlayerOwner()
                data.wear_filter = pace_CreateWearFilter()

                table_insert( parts, data )
            end

            -- This will put all of the parts into the parts table
            Module.ogWearOnServer( filter )
            pace.SendPartToServer = Module.ogSendPartToServer

            if #parts == 0 then return end

            express.Send( "pac_submit", parts )
        end

        express.ReceivePreDl( "pac_submit_multi", function()
            if not pac.IsEnabled() then return false end
        end )

        express.Receive( "pac_submit_multi", function( parts )
            local partCount = #parts

            for i = 1, partCount do
                local data = parts[i]
                local owner = data.owner
                local ownerType = type( owner )

                if ownerType ~= "Player" or not owner:IsValid() then
                    pac.Message( "received message from server but owner is not valid!? typeof " .. ownerType .. " || ", owner )
                    return
                end

                if pac.IsPacOnUseOnly() and owner ~= pac.LocalPlayer then
                    pace.HandleOnUseReceivedData( data )
                else
                    pace.HandleReceiveData( data, true )
                end
            end
        end )
    end

    function Module.Disable()
        hook.Remove( "pac_SendData", "ExpressBindings_HijackSend" )
        express.ClearReceiver( "pac_submit" )
    end
end
