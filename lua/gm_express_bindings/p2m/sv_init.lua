local enabled = CreateConVar( "express_enable_p2m", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable Prop2Mesh Bindings" )

local originalSendDownload

local function enable()
    if not prop2mesh then return end
    if not enabled:GetBool() then return end

    originalSendDownload = originalSendDownload or prop2mesh.sendDownload

    local pendingSendDownloads = {}

    prop2mesh.sendDownload = function( ply, ent, crc )
        pendingSendDownloads[ply] = pendingSendDownloads[ply] or {}
        table.insert( pendingSendDownloads[ply], { ent, crc } )
        timer.Start( "express_p2m_send_download" )
    end

    timer.Create( "express_p2m_send_download", 0.25, 0, function()
        for ply, downloads in pairs( pendingSendDownloads ) do
            local downloadObjects = {}

            for _, download in ipairs( downloads ) do
                local ent, crc = unpack( download )
                table.insert( downloadObjects, { crc = crc, partData = ent.prop2mesh_partlists[crc] } )
            end

            express.Send( "prop2mesh_download", downloadObjects, ply )
        end

        pendingSendDownloads = {}
        timer.Stop( "express_p2m_send_download" )
    end )
    timer.Stop( "express_p2m_send_download" )

end

local function disable()
    if not prop2mesh then return end
    if enabled:GetBool() then return end

    prop2mesh.sendDownload = originalSendDownload
end

cvars.AddChangeCallback( "express_enable_p2m", function( _, _, new )
    if new == 0 then return disable() end
    if new ~= 0 then return enable() end
end, "setup_teardown" )

hook.Add( "InitPostEntity", "Express_P2MBindings", function()
    if enabled:GetBool() then enable() end
end )
