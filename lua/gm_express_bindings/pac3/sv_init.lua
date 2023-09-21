return function( Module )
    local singlePlayer = game.SinglePlayer()

    function Module.Enable()
        local pacSubmitSpam = GetConVar( "pac_submit_spam" )
        local pacSubmitLimit = GetConVar( "pac_submit_limit" )

        local partsToPlayers = {}
        local next = next
        local table_insert = table.insert

        local function sendParts()
            -- Common parts and players lists for all existing parts
            local commonParts = {}
            local commonPlys = {}

            while next( partsToPlayers ) ~= nil do
                -- Select the first part to compare with
                local firstPart = next( partsToPlayers )
                table_insert( commonParts, firstPart )
                commonPlys = partsToPlayers[firstPart]
                partsToPlayers[firstPart] = nil

                -- Check all other parts for common players
                for part, players in pairs( partsToPlayers ) do
                    local newCommonPlayers = {}
                    for _, player in pairs( commonPlys ) do
                        for _, p in pairs( players ) do
                            if p == player then
                                table_insert( newCommonPlayers, p )
                            end
                        end
                    end

                    -- If the part has common players, add to the common list and remove from partsToPlayers
                    if #newCommonPlayers > 0 then
                        commonPlys = newCommonPlayers
                        table_insert( commonParts, part )
                        partsToPlayers[part] = nil
                    end
                end

                -- Send parts to the common players
                express.Send( "pac_submit_multi", commonParts, commonPlys )

                -- Clear the common lists for the next iteration
                commonParts = {}
                commonPlys = {}
            end
        end

        hook.Add( "pac_SendData", "ExpressBindings_HijackSend", function( plys, part )
            if not partsToPlayers[part] then
                partsToPlayers[part] = {}
            end

            if not istable( plys ) then plys = { plys } end

            for _, ply in pairs( plys ) do
                table.insert( partsToPlayers[part], ply )
            end

            timer.Create( "pac_submit_multi", 0.25, 1, sendParts )
            return false
        end )


        express.ReceivePreDl( "pac_submit", function( _, ply, _, size )
            if size < 64 then return false end

            if pacSubmitSpam:GetBool() and not singlePlayer then
                local allowed = pac.RatelimitPlayer( ply, "pac_submit", pacSubmitLimit:GetInt(), 5, { "Player ", ply, " is spamming pac_submit express messages!" } )
                if not allowed then return false end
            end

            if pac.CallHook( "CanWearParts", ply ) == false then
                return false
            end
        end )

        express.Receive( "pac_submit", function( ply, data )
            if not ply:IsValid() then
                pac.Message( "received message from ", ply, " but player is no longer valid!" )
            end

            local dataCount = #data

            for i = 1, dataCount do
                pace.HandleReceivedData( ply, data[i] )
            end
        end )
    end

    function Module.Disable()
        hook.Remove( "pac_SendData", "ExpressBindings_HijackSend" )
        express.ClearReceiver( "pac_submit" )
        timer.Remove( "pac_submit_multi" )
    end
end
