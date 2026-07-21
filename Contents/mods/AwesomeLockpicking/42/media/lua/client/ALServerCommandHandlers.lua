---@type ALSharedUtils
local u = require 'ALSharedUtils'

---@type ALNetworkRouter
local net = require 'ALNetworkRouter'


---@const
local settings = SandboxVars and SandboxVars.AwesomeLockpicking
---@const
local fileName = "ALServerCommandHandlers"


--- Sets halo note with given text in red "bad" color for 150.0 duration. Expected params: integer playerId, string 
--- textTranslationKey (takes text key in case I add other warnings later like "too dark...") ALTODO: optionally take
--- color as argument?
---@param args ALargsType
local function setHaloNoteWarningHandler(args)
    local contextStr = fileName .. "setHaloNoteWarningHandler"
    local playerId = args.playerId --[[@as integer]]
    if not playerId then u.ALlog("args.playerId nil", u.ALLogLevel.ERROR, contextStr) return end
    local textTranslationKey = args.textTranslationKey --[[@as string]]
    if not textTranslationKey then u.ALlog("args.textTranslationKey nil", u.ALLogLevel.ERROR, contextStr) return end
    if textTranslationKey == "" then u.ALlog("args.textTranslationKey empty", u.ALLogLevel.ERROR, contextStr) return end

    ---@type IsoPlayer
    local playerObj = nil
    if net:isSinglePlayerContext() then
        playerObj = getSpecificPlayer(playerId)
    else
        playerObj = getPlayerByOnlineID(playerId)
    end
    if not playerObj then u.ALlog("could not get playerObj from playerId: " .. tostring(playerId), u.ALLogLevel.ERROR,
        contextStr) return end

    local text = getText(textTranslationKey)
    if not text then u.ALlog("Could not get translated text from textTranslationKey: " .. tostring(textTranslationKey),
        u.ALLogLevel.ERROR, contextStr) return end
    if text == "" then u.ALlog("text from textTranslationKey: " .. tostring(textTranslationKey) .. " is empty",
        u.ALLogLevel.ERROR, contextStr) return end

    local badColor = getCore():getBadHighlitedColor()

    local r = math.floor(badColor:getR() * 255)
    local g = math.floor(badColor:getG() * 255)
    local b = math.floor(badColor:getB() * 255)

    playerObj:setHaloNote(text, r, g, b, 150.0)
end
net.registerServerCommandHandler(net.serverCommands.setHaloNoteWarning, setHaloNoteWarningHandler)


--- Adds enter vehicle timed action to queue. Expected params: integer playerId, integer vehicleId, integer seatIndex
---@param args ALargsType
local function addEnterVehicleActionToQueue(args)
    local contextStr = fileName .. "addEnterVehicleActionToQueue"
    if settings and not settings.AutoEnterOnLockpickingVehicleDoor then return end

    local playerId = args.playerId --[[@as integer]]
    if not playerId then u.ALlog("args.playerId nil", u.ALLogLevel.ERROR, contextStr) return end

    ---@type IsoPlayer
    local playerObj = nil
    if net:isSinglePlayerContext() then
        playerObj = getSpecificPlayer(playerId)
    else
        playerObj = getPlayerByOnlineID(playerId)
    end
    if not playerObj then u.ALlog("could not get playerObj from playerId: " .. tostring(playerId), u.ALLogLevel.ERROR,
        contextStr) return end

    local vehicleId = args.vehicleId --[[@as integer]]
    if not vehicleId then u.ALlog("args.vehicleId nil", u.ALLogLevel.ERROR, contextStr) return end

    local vehicleObj = getVehicleById(vehicleId)
    if not vehicleObj then u.ALlog("could not get vehicleObj from vehicleId: " .. tostring(vehicleId),
        u.ALLogLevel.ERROR, contextStr) return end

    local seatIndex = args.seatIndex --[[@as integer]]
    if not seatIndex then u.ALlog("args.seatIndex nil", u.ALLogLevel.ERROR, contextStr) return end

    local enterVehicleAction = ISEnterVehicle:new(playerObj, vehicleObj, seatIndex)
    ISTimedActionQueue.add(enterVehicleAction)
end
net.registerServerCommandHandler(net.serverCommands.enterVehicle, addEnterVehicleActionToQueue)


--- Adds open door timed action to queue. Expected params: integer playerId, integer vehicleId, integer vehiclePartId
---@param args ALargsType
local function addOpenVehicleDoorActionToQueue(args)
    local contextStr = fileName .. "addOpenVehicleDoorActionToQueue"
    if settings and not settings.AutoEnterOnLockpickingVehicleDoor then return end

    local playerId = args.playerId --[[@as integer]]
    if not playerId then u.ALlog("args.playerId nil", u.ALLogLevel.ERROR, contextStr) return end

    ---@type IsoPlayer
    local playerObj = nil
    if net:isSinglePlayerContext() then
        playerObj = getSpecificPlayer(playerId)
    else
        playerObj = getPlayerByOnlineID(playerId)
    end
    if not playerObj then u.ALlog("could not get playerObj from playerId: " .. tostring(playerId), u.ALLogLevel.ERROR,
        contextStr) return end

    local vehicleId = args.vehicleId --[[@as integer]]
    if not vehicleId then u.ALlog("args.vehicleId nil", u.ALLogLevel.ERROR, contextStr) return end

    local vehicleObj = getVehicleById(vehicleId)
    if not vehicleObj then u.ALlog("could not get vehicleObj from vehicleId: " .. tostring(vehicleId),
        u.ALLogLevel.ERROR, contextStr) return end

    local vehiclePartId = args.vehiclePartId --[[@as string]]
    if not vehiclePartId then u.ALlog("args.vehiclePartId nil", u.ALLogLevel.ERROR, contextStr) return end
    if vehiclePartId == "" then u.ALlog("args.vehiclePartId empty", u.ALLogLevel.ERROR, contextStr) return end

    local vehiclePart = vehicleObj:getPartById(vehiclePartId)
    if not vehiclePart then u.ALlog("could not get vehiclePart from vehiclePartId: " .. tostring(vehiclePartId),
        u.ALLogLevel.ERROR, contextStr) return end

    local openVehicleDoorAction = ISOpenVehicleDoor:new(playerObj, vehicleObj, vehiclePart)
    ISTimedActionQueue.add(openVehicleDoorAction)
end
net.registerServerCommandHandler(net.serverCommands.openVehicleDoor, addOpenVehicleDoorActionToQueue)