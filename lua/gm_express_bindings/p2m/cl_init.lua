local enabled = CreateConVar( "express_enable_p2m", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable Prop2Mesh Bindings" )

local function makeEnv( overrides )
    return setmetatable( overrides or {}, {
        __index = _G
    } )
end

local function wrapUploadStartReceiver()
    local eid
    local objectCount

    local nextObj
    local objects = {}

    local env = makeEnv( {
        upstreams = prop2mesh.upstreams,
        filecache_keys = prop2mesh.filecache_keys,

        -- This function only uses the WriteString function of prop2mesh
        -- We just need to keep track of the data and give it a fake netstream object
        prop2mesh = {
            WriteStream = function( data )
                nextObj.data = data
                return {
                    numChunks = 1,
                    clients = {
                        {
                            progress = 0,
                            finished = false,
                        }
                    }
                }
            end
        },
        net = {
            ReadString = net.ReadString,
            WriteUInt = net.WriteUInt,

            ReadUInt = function( bits )
                local result = net.ReadUInt( bits )

                if bits == 16 and not eid then
                    eid = result
                elseif bits == 8 and not objectCount then
                    objectCount = result
                end

                return result
            end,

            Start = function( message )
                nextObj = {}
                net.Start( message )
            end,

            WriteString = function( str )
                nextObj.crc = str
                net.WriteString( str )
            end,

            SendToServer = function()
                table.insert( objects, nextObj )
                net.SendToServer()

                -- The loop has completed, we can send the full dataset
                if #objects == objectCount then
                    print( "Uploading " .. objectCount .. " p2m objects to the server" )
                    express.Send( "prop2mesh_upload", {
                        eid = eid,
                        objects = objects
                    }, function()
                        -- Update the fake netstream objects to be finished
                        for _, obj in ipairs( objects ) do
                            prop2mesh.upstreams[obj.crc].clients[1].finished = true
                        end
                    end )
                end
            end
        }
    } )

    setfenv( net.Receivers["prop2mesh_upload_start"], env )

    express.Receive( "prop2mesh_controller_update", function( data )
        local ent = data.ent
        if not prop2mesh.isValid( ent ) then return end

        local syncTime = data.syncTime
        local updates = data.updates

        prop2mesh.handleControllerUpdates( ent, syncTime, updates )
    end )

    express.Receive( "prop2mesh_controller_sync", function( data )
        local ent = data.ent
        if not prop2mesh.isValid( ent ) then return end

        local syncTime = data.syncTime
        local controllers = data.controllers

        prop2mesh.discardControllers( ent, ent.prop2mesh_controllers )

        ent.prop2mesh_synctime = syncTime
        ent.prop2mesh_controllers = controllers
        ent.prop2mesh_refresh = true
        ent.prop2mesh_triggertool = true
        ent.prop2mesh_triggereditor = prop2mesh.editor and true

    end )
end

local function unwrapUploadStartReceiver()
    setfenv( net.Receivers["prop2mesh_upload_start"], _G )
end

local function enable()
    if not prop2mesh then return end
    if not enabled:GetBool() then return end

    wrapUploadStartReceiver()
end

local function disable()
    if not prop2mesh then return end
    if enabled:GetBool() then return end

    unwrapUploadStartReceiver()
end

cvars.AddChangeCallback( "express_enable_p2m", function( _, new )
    if new == 0 then return disable() end
    if new ~= 0 then return enable() end
end, "setup_teardown" )

hook.Add( "InitPostEntity", "Express_P2MBindings", function()
    if enabled:GetBool() then enable() end
end )
