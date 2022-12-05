local enabled = CreateConVar( "express_enable_p2m", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable Prop2Mesh Bindings" )

local originalDownloadReceiver
local originalUploadReceiver

local originalEntSendControllers
local originalEntBroadcastUpdate

local SysTime = SysTime
local table_Count = table.Count

local function enable()
    if not prop2mesh then return end
    if not enabled:GetBool() then return end

    originalSendDownload = originalSendDownload or prop2mesh.sendDownload
    originalUploadReceiver = originalUploadReceiver or net.Receivers["prop2mesh_upload"]
    originalDownloadReceiver = originalDownloadReceiver or net.Receivers["prop2mesh_download"]


    -- prop2mesh_download

    local pendingSendDownloads = {}

    prop2mesh.sendDownload = function( ply, ent, crc )
        pendingSendDownloads[ply] = pendingSendDownloads[ply] or {}
        table.insert( pendingSendDownloads[ply], { ent, crc } )
        timer.Start( "express_p2m_send_download" )
    end

    timer.Create( "express_p2m_send_download", 0.15, 0, function()
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

    -- local p2mMeta = scripted_ents.GetStored( "sent_prop2mesh" ).t


    -- -- EntSendControllers

    -- originalEntSendControllers = originalEntSendControllers or p2mMeta.SendControllers

    -- local pendingBroadcastSyncs = {}
    -- local pendingTargetSyncs = {}
    -- local function processSyncs()
    --     print( "Running express_p2m_send_sync" )
    --     local syncs = {}

    --     print( "Broadcasting " .. table_Count( pendingBroadcastSyncs ) .. " p2m syncs" )
    --     for ent in pairs( pendingBroadcastSyncs ) do
    --         if IsValid( ent ) then
    --             local data = {
    --                 ent = ent,
    --                 syncTime = ent.prop2mesh_synctime,
    --                 controllers = ent.prop2mesh_controllers
    --             }

    --             table.insert( syncs, data )
    --         end
    --     end
    --     pendingBroadcastSyncs = {}

    --     if #syncs > 0 then
    --         express.Broadcast( "prop2mesh_controller_sync", syncs )
    --     end

    --     print( "Sending " .. #pendingTargetSyncs .. " p2m syncs" )
    --     for _, sync in ipairs( pendingTargetSyncs ) do
    --         local ent = sync.ent
    --         local target = sync.target

    --         if IsValid( ent ) then
    --             local data = {
    --                 ent = ent,
    --                 syncTime = ent.prop2mesh_synctime,
    --                 controllers = ent.prop2mesh_controllers
    --             }

    --             express.Send( "prop2mesh_controller_sync", data, target )
    --         end
    --     end
    --     pendingTargetSyncs = {}

    --     timer.Stop( "express_p2m_send_sync" )
    -- end

    -- p2mMeta.SendControllers = function( ent, target )
    --     local targetCount = #pendingTargetSyncs
    --     local broadcastCount = table_Count( pendingBroadcastSyncs )

    --     -- FIXME: This won't work if we were using express before and suddenly want to not use it
    --     local queueIsLarge = ( targetCount > 12 ) or ( broadcastCount > 10 )

    --     -- If there are too few players to justify using Express
    --     -- (Unless the queue is large)
    --     local shouldUseNet = ( not queueIsLarge ) and #player.GetAll() <= 12
    --     if shouldUseNet then
    --         return originalEntSendControllers( ent, target )
    --     end

    --     if target then
    --         table.insert( { ent = ent, target = target }, pendingTargetSyncs )
    --     else
    --         pendingBroadcastSyncs[ent] = true
    --     end

    --     -- If the queues are getting too big, process them now
    --     if queueIsLarge then return processSyncs() end

    --     timer.Start( "express_p2m_send_sync" )
    -- end
    -- timer.Create( "express_p2m_send_sync", 0.15, 0, processSyncs )
    -- timer.Stop( "express_p2m_send_sync" )


    -- -- Ent Broadcast Update

    -- originalEntBroadcastUpdate = originalEntBroadcastUpdate or p2mMeta.BroadcastUpdate

    -- local pendingUpdates = {}

    -- local function processPendingUpdates()
    --     local updates = {}
    --     print( "Broadcasting " .. table_Count( pendingUpdates ) .. " p2m updates" )
    --     for ent in pairs( pendingUpdates ) do
    --         if IsValid( ent ) then
    --             local data = {
    --                 ent = ent,
    --                 syncTime = ent.prop2mesh_synctime,
    --                 updates = ent.prop2mesh_updates
    --             }

    --             table.insert( updates, data )
    --             ent.prop2mesh_updates = nil
    --         end

    --         pendingUpdates[ent] = nil
    --     end

    --     if #updates > 0 then
    --         express.Broadcast( "prop2mesh_controller_update", updates )
    --     end

    --     timer.Stop( "express_p2m_broadcast_updates" )
    -- end

    -- p2mMeta.BroadcastUpdate = function( ent )
    --     -- FIXME: This won't work if we were using express before and suddenly want to not use it
    --     local queueIsLarge = table_Count( pendingUpdates ) >= 20

    --     -- If there are too few players to justify using Express
    --     local shouldUseNet = #player.GetAll() <= 12
    --     if shouldUseNet then
    --         return originalEntBroadcastUpdate( ent )
    --     end

    --     -- You already told us you have an update
    --     if pendingUpdates[ent] then return end

    --     pendingUpdates[ent] = true
    --     ent.prop2mesh_synctime = SysTime() .. ""

    --     -- If there are too many queued updates, process them now

    --     if shouldShortcut then
    --         return processPendingUpdates()
    --     end

    --     -- Otherwise restart the window for bulking
    --     timer.Start( "express_p2m_broadcast_updates" )
    -- end
    -- timer.Create( "express_p2m_broadcast_updates", 0.15, 0, processPendingUpdates )
    -- timer.Stop( "express_p2m_broadcast_updates" )

    -- for _, ent in ipairs( ents.FindByClass( "sent_prop2mesh" ) ) do
    --     ent.SendControllers = p2mMeta.SendControllers
    --     ent.BroadcastUpdate = p2mMeta.BroadcastUpdate
    -- end


    -- -- Upload

    -- express.Receive( "prop2mesh_upload", function( ply, data )
    --     print( SysTime(), "Received prop2mesh_upload from", ply )
    --     local ent = Entity( data.eid )
    --     if not prop2mesh.canUpload( ply, ent ) then return end

    --     for _, obj in ipairs( data.objects ) do
    --         local crc = obj.crc
    --         prop2mesh.handleUpdate( obj.data, ent, ply, crc )
    --     end
    -- end )
end

local function disable()
    if not prop2mesh then return end
    if enabled:GetBool() then return end

    -- for _, ent in ipairs( ents.FindByClass( "sent_prop2mesh" ) ) do
    --     ent.SendControllers = originalEntSendControllers
    --     ent.BroadcastUpdate = originalEntBroadcastUpdate
    -- end

    prop2mesh.sendDownload = originalSendDownload
end

cvars.AddChangeCallback( "express_enable_p2m", function( _, _, new )
    if new == 0 then return disable() end
    if new ~= 0 then return enable() end
end, "setup_teardown" )

hook.Add( "InitPostEntity", "Express_P2MBindings", function()
    if enabled:GetBool() then enable() end
end )
