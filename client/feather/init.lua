-- bcc-documents' boundary to the Feather Framework (client side).
-- Server calls go through feather-core RPC; messages through feather-notify.

DocsRPC = {}

-- Calls a server procedure and returns its reply, or nil on transport failure.
function DocsRPC.CallAsync(name, params)
    local result, transportError = exports['feather-core']:CallRPCAsync(name, params or {})
    if result == nil and type(transportError) == 'table' then
        print(('[bcc-documents] rpc %s failed: %s'):format(name,
            tostring(transportError.code or transportError.message)))
    end
    return result
end

-- Fire and forget: the reply is not needed.
function DocsRPC.Send(name, params)
    CreateThread(function()
        DocsRPC.CallAsync(name, params)
    end)
end

-- Server-to-client procedures (open or show a document).
function DocsRPC.Register(name, handler)
    exports['feather-core']:RegisterRPC(name, function(params, respond)
        handler(type(params) == 'table' and params or {})
        if respond then
            respond(true)
        end
    end)
end

function Notify(message, duration)
    local called, result = pcall(function()
        return exports['feather-notify']:ShowNotification({
            style = Config.feather.notifyStyle or 'right',
            message = tostring(message),
            duration = tonumber(duration) or 4000
        })
    end)
    if not called or type(result) ~= 'table' or result.ok ~= true then
        print(('[bcc-documents] notification failed: %s'):format(
            called and type(result) == 'table' and tostring(result.code) or 'provider_unavailable'))
    end
end
