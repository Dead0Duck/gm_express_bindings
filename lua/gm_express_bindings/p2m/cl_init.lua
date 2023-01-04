local enabled = CreateConVar( "express_enable_p2m", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable Prop2Mesh Bindings" )
local originalUploadStartReceiver

local function mockNetStream()
    return {
        numchunks = 1,
        clients = {
            {
                progress = 0,
                finished = false,
            }
        }
    }
end

local function wrapUploadStartReceiver()
    originalUploadStartReceiver = originalUploadStartReceiver or net.Receivers["prop2mesh_upload_start"]

    local upstreams
    local filecache_keys

    do
        local name, func = debug.getupvalue( originalUploadStartReceiver, 2 )
        assert( name == "filecache_keys", "Express: Failed to get upvalue 'filecache_keys' from 'prop2mesh_upload_start'" )
        filecache_keys = func
    end

    do
        local name, func = debug.getupvalue( originalUploadStartReceiver, 3 )
        assert( name == "upstreams", "Express: Failed to get upvalue 'upstreams' from 'prop2mesh_upload_start'" )
        upstreams = func
    end

    local newReceiver = function()
        local objects = {}
        local eid = net.ReadUInt( 16 )

        for _ = 1, net.ReadUInt( 8 ) do
            local crc = net.ReadString()
            local key = filecache_keys[crc]
            local data = key and key.data

            if data then
                net.Start( "prop2mesh_upload" )
                net.WriteUInt( eid, 16 )
                net.WriteString( crc )
                upstreams[crc] = mockNetStream()
                net.SendToServer()

                table.insert( objects, { crc = crc, data = data } )
            end
        end

        local objectCount = #objects
        if objectCount == 0 then
            ErrorNoHaltWithStack( "Express: No valid objects found in p2m upload request" )
            return
        end

        print( "Uploading " .. objectCount .. " p2m objects to the server" )
        express.Send(
            "prop2mesh_upload",
            { eid = eid, objects = objects },
            function()
                -- Update the fake netstream objects to be finished
                for _, obj in ipairs( objects ) do
                    prop2mesh.upstreams[obj.crc].clients[1].finished = true
                end
            end
        )
    end

    net.Receive( "prop2mesh_upload_start", newReceiver )
end

local function enable()
    if not prop2mesh then return end
    if not enabled:GetBool() then return end

    wrapUploadStartReceiver()

    express.Receive( "prop2mesh_download", function( objects )
        prop2mesh.downloads = prop2mesh.downloads + #objects

        for _, obj in ipairs( objects ) do
            local crc = obj.crc
            local partData = obj.partData
            prop2mesh.handleDownload( crc, partData )
        end
    end )
end

local function disable()
    if not prop2mesh then return end
    if enabled:GetBool() then return end

    net.Receive( "prop2mesh_upload_start", originalUploadStartReceiver )
end

cvars.AddChangeCallback( "express_enable_p2m", function( _, new )
    if new == 0 then return disable() end
    if new ~= 0 then return enable() end
end, "setup_teardown" )

hook.Add( "InitPostEntity", "Express_P2MBindings", function()
    if enabled:GetBool() then enable() end
end )
