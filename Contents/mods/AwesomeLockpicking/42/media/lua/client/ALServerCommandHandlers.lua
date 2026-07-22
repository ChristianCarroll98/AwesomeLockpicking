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


--- Adds open door timed action to queue. Expected params: integer playerId, targetTypes targetType, 
--- table<string, number>: {x, y, z} squarePos,
---@param args ALargsType
local function addOpenDoorActionToQueue(args)
    local contextStr = fileName .. ".addOpenDoorActionToQueue"
    u.ALlog("called", u.ALLogLevel.DEBUG, contextStr)

    local targetType = args.targetType --[[@as targetTypes]]
    if not targetType then u.ALlog("args.targetType nil", u.ALLogLevel.ERROR, contextStr) return end

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

    local pos = args.squarePos --[[@as table<string, number>]]
    if not pos then u.ALlog("args.squarePos nil", u.ALLogLevel.ERROR, contextStr) return end
    if not pos.x or not pos.y or not pos.z then u.ALlog("pos.x/y/z nil", u.ALLogLevel.ERROR, contextStr) return end

    local square = getCell():getGridSquare(pos.x, pos.y, pos.z)
    if not square then u.ALlog("could not find grid square for door target", u.ALLogLevel.ERROR,
        contextStr) return end

    ---@type IsoDoor|IsoThumpable
    local doorObj = nil
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)

        if (targetType == u.LockpickableObjectTypes.WorldDoor and instanceof(obj, "IsoDoor")) then
            doorObj = obj --[[@as IsoDoor]]
            u.ALlog("found IsoDoor at " .. u.parseToString(pos), u.ALLogLevel.DEBUG, contextStr)

        elseif (targetType == u.LockpickableObjectTypes.PlayerDoor and instanceof(obj, "IsoThumpable") and
            obj--[[@as IsoThumpable]].isDoor and obj--[[@as IsoThumpable]]:isDoor()) then

            doorObj = obj --[[@as IsoThumpable]]
            u.ALlog("found IsoThumpable door at " .. u.parseToString(pos), u.ALLogLevel.DEBUG, contextStr)
        end
    end

    if not doorObj then u.ALlog("could not find door at square: " .. u.parseToString(pos),
        u.ALLogLevel.ERROR, contextStr) return end

    u.ALlog("adding openDoorAction to queue", u.ALLogLevel.DEBUG, contextStr)
    local openDoorAction = ISOpenCloseDoor:new(playerObj, doorObj)
    ISTimedActionQueue.add(openDoorAction)
end
net.registerServerCommandHandler(net.serverCommands.openDoor, addOpenDoorActionToQueue)
