local enabled = CreateConVar( "express_enable_p2m", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable Prop2Mesh Bindings" )

local originalDownloadReceiver
local originalUploadReceiver

local originalEntSendControllers
local originalEntBroadcastUpdate

local function enable()
    if not prop2mesh then return end
    if not enabled:GetBool() then return end

    originalDownloadReceiver = originalDownloadReceiver or net.Receivers["prop2mesh_download"]
    originalUploadReceiver = originalUploadReceiver or net.Receivers["prop2mesh_upload"]
    originalSendDownload = originalSendDownload or prop2mesh.sendDownload


    -- prop2mesh_download

    local pendingSendDownloads = {}

    prop2mesh.sendDownload = function( ply, ent, crc )
        pendingSendDownloads[ply] = pendingSendDownloads[ply] or {}
        table.insert( pendingSendDownloads[ply], { ent, crc } )
        timer.Start( "express_p2m_send_download" )
    end

    timer.Create( "express_p2m_send_download", 1, 0, function()
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

    local p2mMeta = scripted_ents.GetStored( "sent_prop2mesh" ).t


    -- EntSendControllers

    originalEntSendControllers = originalEntSendControllers or p2mMeta.SendControllers

    local pendingBroadcastSyncs = {}
    local pendingTargetSyncs = {}
    p2mMeta.SendControllers = function( ent, target )
        if target then
            table.insert( { ent = ent, target = target }, pendingTargetSyncs )
        else
            pendingBroadcastSyncs[ent] = true
        end

        timer.Start( "express_p2m_send_sync" )
    end

    timer.Create( "express_p2m_send_sync", 1, 0, function()
        print( "Running express_p2m_send_sync" )
        local syncs = {}

        print( "Broadcasting " .. table.Count( pendingBroadcastSyncs ) .. " p2m syncs" )
        for ent in pairs( pendingBroadcastSyncs ) do
            if IsValid( ent ) then
                local data = {
                    ent = ent,
                    syncTime = ent.prop2mesh_synctime,
                    controllers = ent.prop2mesh_controllers
                }

                table.insert( syncs, data )
            end
        end
        pendingBroadcastSyncs = {}

        if #syncs > 0 then
            express.Broadcast( "prop2mesh_controller_sync", syncs )
        end

        print( "Sending " .. #pendingTargetSyncs .. " p2m syncs" )
        for _, sync in ipairs( pendingTargetSyncs ) do
            local ent = sync.ent
            local target = sync.target

            if IsValid( ent ) then
                local data = {
                    ent = ent,
                    syncTime = ent.prop2mesh_synctime,
                    controllers = ent.prop2mesh_controllers
                }

                express.Send( "prop2mesh_controller_sync", data, target )
            end
        end
        pendingTargetSyncs = {}

        timer.Stop( "express_p2m_send_sync" )
    end )


    -- Ent Broadcast Update

    originalEntBroadcastUpdate = originalEntBroadcastUpdate or p2mMeta.BroadcastUpdate

    local pendingUpdates = {}
    p2mMeta.BroadcastUpdate = function( ent )
        ent.prop2mesh_synctime = SysTime() .. ""
        pendingUpdates[ent] = true
        timer.Start( "express_p2m_broadcast_updates" )
    end

    timer.Create( "express_p2m_broadcast_updates", 1, 0, function()
        local updates = {}
        print( "Broadcasting " .. table.Count( pendingUpdates ) .. " p2m updates" )
        for ent in pairs( pendingUpdates ) do
            if IsValid( ent ) then
                local data = {
                    ent = ent,
                    syncTime = ent.prop2mesh_synctime,
                    updates = ent.prop2mesh_updates
                }

                table.insert( updates, data )
                ent.prop2mesh_updates = nil
            end

            pendingUpdates[ent] = nil
        end

        if #updates == 0 then return end
        express.Broadcast( "prop2mesh_controller_update", updates )

        timer.Stop( "express_p2m_broadcast_updates" )
    end )

    for _, ent in ipairs( ents.FindByClass( "prop2mesh" ) ) do
        ent.SendControllers = p2mMeta.SendControllers
        ent.BroadcastUpdate = p2mMeta.BroadcastUpdate
    end


    -- Upload

    express.Receive( "prop2mesh_upload", function( ply, data )
        print( SysTime(), "Received prop2mesh_upload from", ply )
        local ent = Entity( data.eid )
        if not prop2mesh.canUpload( ply, ent ) then return end

        for _, obj in ipairs( data.objects ) do
            local crc = obj.crc
            prop2mesh.handleUpdate( obj.data, ent, ply, crc )
        end
    end )
end

local function disable()
    if not prop2mesh then return end
    if enabled:GetBool() then return end

    for _, ent in ipairs( ents.FindByClass( "prop2mesh" ) ) do
        ent.SendControllers = originalEntSendControllers
        ent.BroadcastUpdate = originalEntBroadcastUpdate
    end

    prop2mesh.sendDownload = originalSendDownload
end

cvars.AddChangeCallback( "express_enable_p2m", function( _, _, new )
    if new == 0 then return disable() end
    if new ~= 0 then return enable() end
end, "setup_teardown" )

hook.Add( "InitPostEntity", "Express_P2MBindings", function()
    if enabled:GetBool() then enable() end
end )
