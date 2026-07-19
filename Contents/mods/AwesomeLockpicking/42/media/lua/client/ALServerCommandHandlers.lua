require 'ALSharedUtils'
-- require 'ALNetworkRouter' -- included in ALSharedUtils

---@const
local settings = SandboxVars and SandboxVars.AwesomeLockpicking


--- Sets halo note with given text in red "bad" color for 150.0 duration. Expected params: integer playerId, string text
---@param args ALargsType
local function setHaloNoteWarningHandler(args)

    local playerId = args.playerId --[[@as integer]]
    local text = args.text --[[@as string]]

    local playerObj = getPlayerByOnlineID(playerId)
    if not playerObj then
        print("[ERROR] AwesomeLockpicking.ALServerCommandHandlers.setHaloNoteWarning handler - could not find player "
            .. "with online Id: " .. tostring(playerId))
        return
    elseif not text or text == "" then
        print("[ERROR] AwesomeLockpicking.ALServerCommandHandlers.setHaloNoteWarning handler - text nil or empty")
        return
    end

    local badColor = getCore():getBadHighlitedColor()

    local r = math.floor(badColor:getR() * 255)
    local g = math.floor(badColor:getG() * 255)
    local b = math.floor(badColor:getB() * 255)

    playerObj:setHaloNote(text, r, g, b, 150.0)
end
ALNetworkRouter.registerServerCommandHandler(ALNetworkRouter.serverCommands.setHaloNoteWarning,
    setHaloNoteWarningHandler)


--- Adds enter vehicle timed action to queue. Expected params: integer playerId, integer vehicleId, integer seatIndex
---@param args ALargsType
local function addEnterVehicleActionToQueue(args)
    if settings and not settings.AutoEnterOnLockpickingVehicleDoor then
        return
    end

    local playerObj = getPlayerByOnlineID(args.playerId --[[@as integer]])
    if not playerObj then
        print("[ERROR] AwesomeLockpicking.ALServerCommandHandlers.addEnterVehicleActionToQueue handler - could not "
            .. "find player with online Id: " .. tostring(args.playerId))
        return
    end

    ---@diagnostic disable: undefined-global
    local vehicleObj = VehicleManager.instance:getVehicleByID(args.vehicleId --[[@as integer]])
    if not vehicleObj then
        print("[ERROR] AwesomeLockpicking.ALServerCommandHandlers.addEnterVehicleActionToQueue - could not get vehicle "
            .. "from vehicleId: " .. tostring(args.vehicleId))
        return
    end

    local enterVehicleAction = ISEnterVehicle:new(playerObj, vehicleObj, args.seatIndex --[[@as integer]])
    ISTimedActionQueue.add(enterVehicleAction)
end
ALNetworkRouter.registerServerCommandHandler(ALNetworkRouter.serverCommands.enterVehicle,
    addEnterVehicleActionToQueue)


--- Adds open door timed action to queue. Expected params: integer playerId, integer vehicleId, integer vehiclePartId
---@param args ALargsType
local function addOpenVehicleDoorActionToQueue(args)
    local playerObj = getPlayerByOnlineID(args.playerId --[[@as integer]])
    if not playerObj then
        print("[ERROR] AwesomeLockpicking.ALServerCommandHandlers.addOpenVehicleDoorActionToQueue handler - could not "
            .. "find player with online playerId: " .. tostring(args.playerId))
        return
    end

    ---@diagnostic disable: undefined-global
    local vehicleObj = VehicleManager.instance:getVehicleByID(args.vehicleId --[[@as integer]])
    if not vehicleObj then
        print("[ERROR] AwesomeLockpicking.ALClientServerHandlers.addOpenVehicleDoorActionToQueue - could not get "
        .. "vehicle from vehicleId: " .. tostring(args.vehicleId))
        return
    end

    local vehiclePart = vehicle:getPartById(args.vehiclePartId --[[@as string]]) --[[@as VehiclePart]]
    if not targetObj then
        print("[ERROR] AwesomeLockpicking.ALClientServerHandlers.addOpenVehicleDoorActionToQueue - could not get "
        .. "vehicle part from vehiclePartId: " .. tostring(args.vehiclePartId))
        return
    end

    local openVehicleDoorAction = ISOpenVehicleDoor:new(playerObj, vehicleObj, vehiclePart)
    ISTimedActionQueue.add(openVehicleDoorAction)
end
ALNetworkRouter.registerServerCommandHandler(ALNetworkRouter.serverCommands.openVehicleDoor,
    addOpenVehicleDoorActionToQueue)