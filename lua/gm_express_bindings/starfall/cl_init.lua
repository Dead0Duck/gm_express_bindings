return function( Module )
    function Module.Enable()

        -- SF.SendStarfall
        do
            Module.ogSendStarfall = Module.ogSendStarfall or SF.SendStarfall

            function SF.SendStarfall( _, sfdata, callback )
                express.Send( "starfall_upload", sfdata, callback )
            end
        end

        -- SF.PushStarfall
        do
            Module.ogPushStarfall = Module.ogPushStarfall or SF.PushStarfall

            function SF.PushStarfall( sf, sfdata )
                local data = {
                    sf = sf,
                    sfdata = sfdata
                }

                express.Send( "starfall_upload_push", data )
            end
        end
    end

    function Module.Disable()
        SF.SendStarfall = Module.ogSendStarfall or SF.SendStarfall
        SF.PushStarfall = Module.ogPushStarfall or SF.PushStarfall
    end
end
