local enabled = CreateConVar( "express_enable_p2m", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable Prop2Mesh Bindings" )

local originalWriteStream
local originalDownloadReceiver
local originalUploadReceiver

local originalEntSendControllers
local originalEntBroadcastUpdate

local function enable()
    if not prop2mesh then return end
    if not enabled:GetBool() then return end

    originalWriteStream = originalWriteStream or prop2mesh.WriteStream
    originalDownloadReceiver = originalDownloadReceiver or net.Receivers["prop2mesh_download"]
    originalUploadReceiver = originalUploadReceiver or net.Receivers["prop2mesh_upload"]

    local p2mMeta = scripted_ents.GetStored( "prop2mesh" ).t

    originalEntSendControllers = originalEntSendControllers or p2mMeta.SendControllers
    p2mMeta.SendControllers = function( self, target )
        local data = {
            ent = self,
            syncTime = self.prop2mesh_synctime,
            controllers = self.prop2mesh_controllers
        }

        if target then
            express.Send( "prop2mesh_controller_sync", data, target )
        else
            express.Broadcast( "prop2mesh_controller_sync", data )
        end
    end

    originalEntBroadcastUpdate = originalEntBroadcastUpdate or p2mMeta.BroadcastUpdate
    p2mMeta.BroadcastUpdate = function( self )
        self.prop2mesh_synctime = SysTime() .. ""

        express.Broadcast( "prop2mesh_controller_sync", {
            ent = self,
            syncTime = self.prop2mesh_synctime,
            updates = self.prop2mesh_updates
        } )

        self.prop2mesh_updates = nil
    end

    for _, ent in ipairs( ents.FindByClass( "prop2mesh" ) ) do
        ent.SendControllers = p2mMeta.SendControllers
        ent.BroadcastUpdate = p2mMeta.BroadcastUpdate
    end

    express.Receive( "prop2mesh_upload", function( ply, data )
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
end

cvars.AddChangeCallback( "express_enable_p2m", function( _, _, new )
    if new == 0 then return disable() end
    if new ~= 0 then return enable() end
end, "setup_teardown" )

hook.Add( "InitPostEntity", "Express_P2MBindings", function()
    if enabled:GetBool() then enable() end
end )
