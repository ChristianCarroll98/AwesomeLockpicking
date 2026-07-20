require 'ALSharedUtils'
-- require 'ALNetworkRouter' -- included in ALSharedUtils

---@const
local settings = SandboxVars and SandboxVars.AwesomeLockpicking


--- Sets halo note with given text in red "bad" color for 150.0 duration. Expected params: integer playerId, string 
--- textTranslationKey (takes text key in case I add other warnings later like "too dark...") ALTODO: optionally take
--- color as argument?
---@param args ALargsType
local function setHaloNoteWarningHandler(args)
    local playerId = args.playerId --[[@as integer]]
    if not playerId then
        print("[ERROR] AwesomeLockpicking.ALClientCommandHandlers.setHaloNoteWarningHandler - args.playerId nil")
        return
    end

    local textTranslationKey = args.textTranslationKey --[[@as string]]
    if not textTranslationKey or textTranslationKey == "" then
        print("[ERROR] AwesomeLockpicking.ALClientCommandHandlers.setHaloNoteWarningHandler - args.text nil or empty")
        return
    end

    ---@type IsoPlayer
    local playerObj = nil
    if ALNetworkRouter:isSinglePlayerContext() then
        playerObj = getSpecificPlayer(playerId)
    else
        playerObj = getPlayerByOnlineID(playerId)
    end
    if not playerObj then
        print("[ERROR] AwesomeLockpicking.ALServerCommandHandlers.setHaloNoteWarning handler - could not find player "
            .. "with online Id: " .. tostring(playerId))
        return
    end

    local text = getText(textTranslationKey)
    if not text or text == textTranslationKey then
        print("[ERROR] AwesomeLockpicking.ALServerCommandHandlers.setHaloNoteWarning handler - Could not get text "
            .. "from translation key: " .. tostring(textTranslationKey))
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

    local playerId = args.playerId --[[@as integer]]
    if not playerId then
        print("[ERROR] AwesomeLockpicking.ALClientCommandHandlers.setHaloNoteWarningHandler - args.playerId nil")
        return
    end

    ---@type IsoPlayer
    local playerObj = nil
    if ALNetworkRouter:isSinglePlayerContext() then
        playerObj = getSpecificPlayer(playerId)
    else
        playerObj = getPlayerByOnlineID(playerId)
    end

    local vehicleId = args.vehicleId --[[@as integer]]
    if not vehicleId then
        print("[ERROR] AwesomeLockpicking.ALServerCommandHandlers.addEnterVehicleActionToQueue - args.vehicleId nil")
        return
    end

    local vehicleObj = getVehicleById(vehicleId)
    if not vehicleObj then
        print("[ERROR] AwesomeLockpicking.ALServerCommandHandlers.addEnterVehicleActionToQueue - could not get vehicle "
        .. "from vehicleId: " .. tostring(vehicleId))
        return
    end

    local seatIndex = args.seatIndex --[[@as integer]]
    if not seatIndex then
        print("[ERROR] AwesomeLockpicking.ALServerCommandHandlers.addEnterVehicleActionToQueue - args.seatIndex nil")
        return
    end

    local enterVehicleAction = ISEnterVehicle:new(playerObj, vehicleObj, seatIndex)
    ISTimedActionQueue.add(enterVehicleAction)
end
ALNetworkRouter.registerServerCommandHandler(ALNetworkRouter.serverCommands.enterVehicle,
    addEnterVehicleActionToQueue)


--- Adds open door timed action to queue. Expected params: integer playerId, integer vehicleId, integer vehiclePartId
---@param args ALargsType
local function addOpenVehicleDoorActionToQueue(args)
    print("[DEBUG] AwesomeLockpicking.ALClientCommandHandlers.addOpenVehicleDoorActionToQueue")
    local playerId = args.playerId --[[@as integer]]
    if not playerId then
        print("[ERROR] AwesomeLockpicking.ALClientCommandHandlers.addOpenVehicleDoorActionToQueue - args.playerId nil")
        return
    end

    ---@type IsoPlayer
    local playerObj = nil
    if ALNetworkRouter:isSinglePlayerContext() then
        playerObj = getSpecificPlayer(playerId)
    else
        playerObj = getPlayerByOnlineID(playerId)
    end

    local vehicleId = args.vehicleId --[[@as integer]]
    if not vehicleId then
        print("[ERROR] AwesomeLockpicking.ALServerCommandHandlers.addOpenVehicleDoorActionToQueue - args.vehicleId nil")
        return
    end

    local vehicleObj = getVehicleById(vehicleId)
    if not vehicleObj then
        print("[ERROR] AwesomeLockpicking.ALServerCommandHandlers.addOpenVehicleDoorActionToQueue - could not get "
            .. "vehicle from vehicleId: " .. tostring(vehicleId))
        return
    end

    local vehiclePartId = args.vehiclePartId --[[@as string]]
    if not vehiclePartId then
        print("[ERROR] AwesomeLockpicking.ALServerCommandHandlers.addOpenVehicleDoorActionToQueue - vehiclePartId nil")
        return
    end

    local vehiclePart = vehicleObj:getPartById(vehiclePartId)
    if not vehiclePart then
        print("[ERROR] AwesomeLockpicking.ALClientServerHandlers.addOpenVehicleDoorActionToQueue - could not get "
            .. "vehicle part from vehiclePartId: " .. tostring(args.vehiclePartId))
        return
    end

    local openVehicleDoorAction = ISOpenVehicleDoor:new(playerObj, vehicleObj, vehiclePart)
    ISTimedActionQueue.add(openVehicleDoorAction)
end
ALNetworkRouter.registerServerCommandHandler(ALNetworkRouter.serverCommands.openVehicleDoor,
    addOpenVehicleDoorActionToQueue)