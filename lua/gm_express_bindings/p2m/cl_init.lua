local GREEN = Color( 50, 200, 50 )
local GREY = Color( 200, 200, 200 )
local ORANGE = Color( 225, 100, 50 )
local BLUE = Color( 93, 145, 240 )

return function( Module )
    function Module.Enable()
        local downloadStart

        express.Receive( "prop2mesh_download", function( objects )
            if downloadStart then
                local diff = math.Round( SysTime() - downloadStart, 2 )
                MsgC(
                    GREEN, "Completed download of ",
                    GREY, #objects,
                    GREEN, " P2M objects in ",
                    GREY, diff,
                    GREEN, " seconds ",
                    GREY, "(",
                    BLUE, "Accelerated by Express",
                    GREY, ")",
                    "\n"
                )
            end
            prop2mesh.downloads = prop2mesh.downloads + #objects

            for _, obj in ipairs( objects ) do
                local crc = obj.crc
                local partData = obj.partData
                if partData then
                    prop2mesh.handleDownload( crc, partData )
                end
            end
        end )

        express.ReceivePreDl( "prop2mesh_download", function( _, _, size )
            downloadStart = SysTime()
            size = string.NiceSize( size )
            MsgC( GREEN, "Starting Accelerated P2M download ", GREY, "(", ORANGE, size, GREY, ")", "\n" )
        end )
    end

    function Module.Disable()
        express.ClearReceiver( "prop2mesh_download" )
    end
end
