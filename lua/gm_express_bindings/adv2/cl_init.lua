return function( Module )
    -- TODO: Both functions need env on / off - they should be done the same way

    -- https://github.com/wiremod/advdupe2/blob/master/lua/advdupe2/cl_file.lua#L1
    -- The current net reciever is a local function, so we use setfenv to hijack its environment
    -- replacing the net library with our own, which reads data differently
    local function envOn( data )
        local env = setmetatable( {
            -- We need to change the behavior of the net library to read data
            -- differently, so we store those special cases here
            net = {
                ReadUInt = function( v )
                    assert( v == 8, "Expected receiver to read 8 bits - is Express Bindings out of date?" )
                    return data.autoSave
                end,

                ReadStream = function( _, cb )
                    cb( data.data )
                end
            },
        }, {
            -- However, anything else the function needs should be fine, so we do a _G passthrough
            -- "if accessing the net table, use ours, otherwise use _G"
            __index = function( t, k )
                local stubbed = rawget( t, k )
                if stubbed ~= nil then return stubbed end

                return _G[k]
            end
        } )

        setfenv( Module.originalReceiver, env )
    end

    local function envOff()
        setfenv( Module.originalReceiver, getfenv( 0 ) )
    end

    function Module.Enable()
        Module.originalReceiver = Module.originalReceiver or net.Receivers["advdupe2_receivefile"]

        express.Receive( "advdupe2_receivefile", function( data )
            -- When we receive dupe data, we wrap the normal receiver in our special environment,
            -- run it, and then restore the environment
            envOn( data )

            local success, err = pcall( Module.originalReceiver )
            if not success then
                ErrorNoHalt( "Error processing received AdvDupe2 file: " .. err )
            end

            envOff()
        end )

        Module.originalUploadFile = Module.originalUploadFile or AdvDupe2.UploadFile
        AdvDupe2.UploadFile = function( ... )
            local name
            local stub = function() end

            -- We need to change the behavior of the net library to write data
            -- differently, so we store those special cases here
            local customNet = {
                -- Start and SendToServer will be called, so they need to exist
                Start = stub,
                SendToServer = stub,

                WriteString = function( str )
                    -- Currently, the only WriteString call is for the name of the file,
                    -- so we store it here
                    name = str
                end,

                WriteStream = function( fileData, cb )
                    assert( name ~= nil, "Expected WriteString to be called before WriteStream - Is Express Bindings out of date?" )

                    -- Hijacking call to WriteStream to send the file data to the server using Express instead
                    express.Send( "advdupe2_receivefile", {
                        name = name,
                        data = fileData
                    }, cb )

                    -- TODO: We should really return a proper NetStream mock here.
                    -- Doesn't appear to be matter in base adv2, but other addons might expect it
                    return { "ExpressBindings Mock NetStream object for dupe: " .. name }
                end
            }

            -- We override the environment of the function to use our custom net stub
            local env = setmetatable(
                { net = customNet },
                {
                    __index = function( t, k )
                        -- "if accessing the net table, use ours, otherwise use _G"
                        local stubbed = rawget( t, k )
                        if stubbed ~= nil then return stubbed end

                        return _G[k]
                    end
                }
            )

            setfenv( Module.originalUploadFile, env )

            local ok, err = pcall( Module.originalUploadFile, ... )
            if not ok then
                print( "Error uploading file: ", err )
            end

            -- Restore the environment
            setfenv( Module.originalUploadFile, getfenv( 0 ) )
        end
    end

    function Module.Disable()
        envOff()
        setfenv( Module.originalUploadFile, getfenv( 0 ) )

        AdvDupe2.UploadFile = Module.originalUploadFile
        express.ClearReceiver( "advdupe2_receivefile" )
    end
end
