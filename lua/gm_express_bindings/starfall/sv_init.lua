return function( Module )

    local function getUploadData()
        local name, val = debug.getupvalue( SF.RequestCode, 1 )
        assert( name == "uploaddata", "SF.RequestCode has changed. Is Express Bindings out of date?" )

        return val
    end

    function Module.Enable()
        local uploads = getUploadData()

        do
            express.ReceivePreDl( "starfall_upload", function( _, ply )
                local upload = uploads[ply]
                if not upload or upload.reading then
                    ErrorNoHalt( "SF: Player " .. ply:GetName() .. " tried to upload code without being requested." )
                    return false
                end

                upload.reading = true
            end )

            express.Receive( "starfall_upload", function( ply, data )
                local upload = uploads[ply]
                uploads[ply] = nil

                if #data.mainfile > 0 then
                    data.owner = ply
                    upload.callback( data )
                end
            end )
        end

        do
            express.Receive( "starfall_upload_push", function( ply, data )
                local sf = data.sf
                local sfdata = data.sfdata

                if not sf:IsValid() then return end
                if sf:GetClass() ~= "starfall_processor" then return end
                if not sf.sfdata then return end

                if sf.sfdata.mainfile ~= sfdata.mainfile then return end
                if sf.sfdata.owner ~= ply then return end

                sfdata.owner = ply
                sf:SetupFiles( sfdata )
            end )
        end
    end

    function Module.Disable()
        express.ClearReceiver( "starfall_upload" )
        express.ClearReceiver( "starfall_upload_push" )
    end
end
