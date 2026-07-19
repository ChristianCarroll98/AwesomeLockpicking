---------- define tables, const enums and vars, and types ----------

ALNetworkRouter = ALNetworkRouter or {}
ALNetworkRouter.serverCommandHandlers = ALNetworkRouter.serverCommandHandlers or {}
ALNetworkRouter.clientCommandHandlers = ALNetworkRouter.clientCommandHandlers or {}

--- Command sent from client to server
---@const
---@enum clientCommands
ALNetworkRouter.clientCommands = {
    applyLockpickAttempt = "applyLockpickAttempt"
}
--- Command sent from server to client
---@const
---@enum serverCommands
ALNetworkRouter.serverCommands = {
    setHaloNoteWarning = "setHaloNoteWarning",
    enterVehicle = "enterVehicle",
    openVehicleDoor = "openVehicleDoor"
}

---@const
ALNetworkRouter.MODULE_NAME = "ALModule"

--- Table of allowed values for client-server communication including nested tables.
---@class ALargsType
---@field [string] string | number | integer | boolean | nil | ALargsType


--- Returns true if current context is singleplayer, otherwise false
---@return boolean
function ALNetworkRouter.isSinglePlayerContext()
    return not isClient() and not isServer()
end


--- Returns true if current context is pure client connected to multiplayer host, otherwise false
---@return boolean
function ALNetworkRouter.isPureClientContext()
    return isClient() and not isServer()
end


--- Returns true if current context live multiplayer server host, otherwise false
---@return boolean
function ALNetworkRouter.isPureServerContext()
    return not isClient() and isServer()
end


--- server -> client - process server commands on the client. Do not call directly.
---@param serverCommand serverCommands
---@param args ALargsType
function ALNetworkRouter.handleServerCommand(serverCommand, args)
    args = args or {}
    local serverCommandHandler = ALNetworkRouter.serverCommandHandlers[serverCommand]
    if serverCommandHandler then
        serverCommandHandler(args)
    else
        print("[WARN] AwesomeLockpicking.ALNetworkRouter.handleServerCommand - Received unregistered server command: "
            .. tostring(serverCommand))
    end
end


--- client -> server - process clent commands on the server. Do not call directly.
---@param clientCommand clientCommands
---@param args ALargsType
function ALNetworkRouter.handleClientCommand(clientCommand, args)
    args = args or {}
    local clientCommandHandler = ALNetworkRouter.clientCommandHandlers[clientCommand]
    if clientCommandHandler then
        clientCommandHandler(args)
    else
        print("[WARN] AwesomeLockpicking.ALNetworkRouter.handleClientCommand - Received unregistered client command: "
            .. tostring(clientCommand))
    end
end


--- Assign a function to the indicated server command to be executed on the client
---@param serverCommand serverCommands
---@param func fun(...): any
function ALNetworkRouter.registerServerCommandHandler(serverCommand, func)
    if ALNetworkRouter.serverCommandHandlers[serverCommand] then
        print("[WARN] AwesomeLockpicking.ALNetworkRouter.registerServerCommandHandler - re-registering "
            .. "server command: " .. tostring(serverCommand))
    end
    ALNetworkRouter.serverCommandHandlers[serverCommand] = func
end


--- Assign a function to the indicated client command to be executed on the server
---@param clientCommand clientCommands
---@param func fun(...): any
function ALNetworkRouter.registerClientCommandHandler(clientCommand, func)
    if ALNetworkRouter.clientCommandHandlers[clientCommand] then
        print("[WARN] AwesomeLockpicking.ALNetworkRouter.registerClientCommandHandler - re-registering "
            .. "client command: " .. tostring(clientCommand))
    end
    ALNetworkRouter.clientCommandHandlers[clientCommand] = func
end


---Unified client command sender, call this from anywhere to properly route a function that should execute from server
---@param clientCommand clientCommands
---@param args ALargsType
function ALNetworkRouter.sendToServer(clientCommand, args)
    if ALNetworkRouter.isPureClientContext() then
        sendClientCommand(ALNetworkRouter.MODULE_NAME, clientCommand, args)

    elseif ALNetworkRouter.isSinglePlayerContext() or ALNetworkRouter.isPureServerContext() then
        ALNetworkRouter.handleClientCommand(clientCommand, args)

    else
        print("[ERROR] AwesomeLockpicking.ALNetworkRouter.sendToServer - Unknown environment context, "
            .. "sendToServer aborted")
    end
end


---Unified server command sender, call this from anywhere to properly route a function that should execute from client
---@param playerObj IsoPlayer
---@param serverCommand serverCommands
---@param args ALargsType
function ALNetworkRouter.sendToClient(playerObj, serverCommand, args)
    if ALNetworkRouter.isPureServerContext() then
        if not playerObj then
            print("[ERROR] AwesomeLockpicking.ALNetworkRouter.sendToClient - playerObj param nil in pure server "
                .. "context, sendToClient aborted")
            return
        end
        sendServerCommand(playerObj, ALNetworkRouter.MODULE_NAME, serverCommand, args)

    elseif ALNetworkRouter.isSinglePlayerContext() or ALNetworkRouter.isPureClientContext() then
        ALNetworkRouter.handleServerCommand(serverCommand, args)

    else
        print("[ERROR] AwesomeLockpicking.ALNetworkRouter.sendToClient - Unknown environment context, "
            .. "sendToClient aborted")
    end
end
