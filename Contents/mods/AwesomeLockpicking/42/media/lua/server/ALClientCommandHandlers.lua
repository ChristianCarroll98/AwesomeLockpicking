---@type ALSharedUtils
local u = require 'ALSharedUtils'

---@type ALNetworkRouter
local net = require 'ALNetworkRouter'

---@const
local settings = SandboxVars and SandboxVars.AwesomeLockpicking

---@const
local fileName = "ALClientCommandHandlers"

---------- local const multiplier settings - subject to chance ----------

---@const
local BASE_CHANCE = 15.0

---@const
local LEVEL_MULTIPLIER = 7.0

---@const
local MIN_CHANCE = 5.0

---@const
local TOOL_MULT = {
    SCREWDRIVER = 1.0,
    PROFESSIONAL = 1.5,
    FORGED = 1.3
}

---@const
local DOOR_MULT = {
    WOODEN = 1.0,
    GLASS = 0.8,
    METAL = 0.65,
    VEHICLE = 0.55,
    HIGH_SEC = 0.5,
    PLAYER = 0.475
}

---@const
local XP_GAIN = 10.0


---------- local helpers ----------

--- Returns whether this lockpick attempt succeeds based on player (lockpicking level), tool, and target type
---@param playerObj IsoPlayer
---@param tool InventoryItem
---@param target IsoDoor|IsoThumpable|VehiclePart|nil
---@return boolean
local function isLockpickSuccess(playerObj, tool, target)
    local contextStr = fileName .. ".isLockpickSuccess"
    if not playerObj then u.ALlog("playerObj nil", u.ALLogLevel.ERROR, contextStr) return false end
    if not tool then u.ALlog("tool nil", u.ALLogLevel.ERROR, contextStr) return false end
    if not target then u.ALlog("target nil", u.ALLogLevel.ERROR, contextStr) return false end

    local baseChance = BASE_CHANCE + (playerObj:getPerkLevel(Perks.Lockpicking) * LEVEL_MULTIPLIER)
    local toolBonus = TOOL_MULT.SCREWDRIVER -- default for screwdriver
    local toolType = u.getLockpickToolTypeFromObj(tool)
    local lockpickToolTypes = u.LockpickToolTypes

    if toolType == lockpickToolTypes.Professional then toolBonus = TOOL_MULT.PROFESSIONAL
    elseif toolType == lockpickToolTypes.Forged then toolBonus = TOOL_MULT.FORGED
    elseif toolType == lockpickToolTypes.Invalid then u.ALlog("lockpick tool type invalid", u.ALLogLevel.ERROR,
        contextStr) return false end

    local targetType = u.getTargetTypeFromObj(target)
    local targetTypes = u.LockpickableObjectTypes
    local doorMultiplier = DOOR_MULT.WOODEN -- default basic doors
    if targetType == targetTypes.VehicleDoor then
        doorMultiplier = DOOR_MULT.VEHICLE

    elseif targetType == targetTypes.PlayerDoor then
        doorMultiplier = DOOR_MULT.PLAYER

    elseif targetType == targetTypes.WorldDoor then
        local sprite = target:getSprite()
        local props = sprite and sprite:getProperties()

        if props then
            if props:get("HighSecurity") == "true" then
                doorMultiplier = DOOR_MULT.HIGH_SEC

            elseif props:get("MetalDoor") == "true" then
                doorMultiplier = DOOR_MULT.METAL

            elseif props:get("GlassDoor") == "true" then
                doorMultiplier = DOOR_MULT.GLASS
            end
        end
    elseif targetType == targetTypes.Invalid then
        u.ALlog("targetType invalid", u.ALLogLevel.ERROR, contextStr)
        return false
    end

    local sandboxMod = settings and settings.SuccessChanceMultiplier or 1.0 -- default 1

    local finalChance = baseChance * doorMultiplier * toolBonus * sandboxMod

    finalChance = math.max(MIN_CHANCE, finalChance)

    u.ALlog("base*door*tool*sandbox = successChance: " .. tostring(baseChance) .. "*" .. tostring(doorMultiplier) .. "*"
        .. tostring(toolBonus) .. "*" .. tostring(sandboxMod) .. " = " .. tostring(finalChance), u.ALLogLevel.TRACE,
        contextStr)

    return ZombRand(100) < finalChance
end


--- Rolls for whether tool durability should be degraded based on player maintenance level and tool condition lower
--- chance. If toolType is screwdriver, rolls for whether to delete a paperclip. SERVER ONLY
---@param tool InventoryItem
---@param success boolean
local function tryReduceToolDurability(playerObj, tool, success)
    local contextStr = fileName .. ".tryReduceToolDurability"
    if not playerObj then u.ALlog("playerObj nil", u.ALLogLevel.ERROR, contextStr) return false end
    if not tool then u.ALlog("tool nil", u.ALLogLevel.ERROR, contextStr) return false end

    local inv = playerObj:getInventory()
    if not inv then u.ALlog("could not get player inventory", u.ALLogLevel.ERROR, contextStr) return false end

    if tool.getCondition and tool:getCondition() > 0 then

        local baseChancePool = tool:getConditionLowerChance()
        local maintenanceMod = playerObj:getMaintenanceMod()

        local finalChancePool = baseChancePool + maintenanceMod

        -- halve chance for condition lower if success
        if success then
            finalChancePool = finalChancePool * 2
        end

        if ZombRand(finalChancePool) == 0 then
            tool:setCondition(tool:getCondition() - 1)
        end
    end

    if u.getLockpickToolTypeFromObj(tool) == u.LockpickToolTypes.Screwdriver then
        local paperclip = inv:getFirstTypeRecurse("Base.Paperclip")
        if not paperclip then u.ALlog("tool is screwdriver but could not find paperclip", u.u.ALLogLevel.WARN,
            contextStr) return end
        -- paperclip removal 10% chance on success, 25% chance on failure
        local removePaperclipChance = success and 10 or 25
        if ZombRand(100) < removePaperclipChance then
            inv:Remove(paperclip)
        end
    end
end


--- Returns seat index from given VehiclePart, -1 if no seat assigned
---@param vehiclePart VehiclePart
---@return integer
local function getSeatIndexFromPart(vehiclePart)
    local contextStr = fileName .. "getSeatIndexFromPart"
    if not vehiclePart then u.ALlog("vehiclePart nil", u.ALLogLevel.ERROR, contextStr) return -1 end

    local vehicle = vehiclePart:getVehicle()
    if not vehicle then return -1 end

    for i = 0, vehicle:getMaxPassengers() - 1 do
        -- Only check the doors mapped to this seat index
        if vehicle:getPassengerDoor(i) == vehiclePart or vehicle:getPassengerDoor2(i) == vehiclePart then
            return i
        end
    end

    return -1 -- Not a door assigned to a seat
end


--- Tries to unlock the given vehicle and part ids. If area is seat, enter. If area is Trunk, open trunk.
---@param playerObj IsoPlayer
---@param vehicle BaseVehicle
---@param vehiclePartId string
local function handleVehiclePart(playerObj, vehicle, vehiclePartId)
    local contextStr = fileName .. ".handleVehiclePart"
    if not playerObj then u.ALlog("playerObj nil", u.ALLogLevel.ERROR, contextStr) return false end
    if not vehicle then u.ALlog("vehicle nil", u.ALLogLevel.ERROR, contextStr) return false end
    if not vehiclePartId or vehiclePartId == "" then
        u.ALlog("vehiclePartId nil or empty", u.ALLogLevel.ERROR, contextStr) return false end

    local vehiclePart = vehicle:getPartById(vehiclePartId)
    if not vehiclePart then u.ALlog("could not get vehicle part from part ID: " .. tostring(vehiclePartId),
        u.ALLogLevel.ERROR, contextStr) return false end

    local vehicleDoor = vehiclePart.getDoor and vehiclePart:getDoor()
    if not vehicleDoor then u.ALlog("vehicle part " .. tostring(vehiclePartId) .. " has no door",
        u.ALLogLevel.ERROR, contextStr) return false end

    vehicleDoor:setLocked(false)
    -- vehicle:transmitPartDoor(target) -- required?? ALTODO

    local area = vehiclePart:getArea()

    if area == "TruckBed" then -- unlocking a trunk
        local truckBed = vehicle:getPartById("TruckBed")
        if truckBed and truckBed:getItemContainer() then
            net.sendToClient( -- tell client to open trunk
                playerObj,
                net.serverCommands.openVehicleDoor,
                { -- Expected params: integer playerId, integer vehicleId, integer vehiclePartId
                    playerId = playerObj:getOnlineID(),
                    vehicleId = vehicle:getId(),
                    vehiclePartId = vehiclePartId
                }
            )
        end
    elseif settings and settings.AutoEnterOnLockpickingVehicleDoor then -- unlocking a door
        local seatIndex = getSeatIndexFromPart(vehiclePart)
        if seatIndex > -1 then
            net.sendToClient( -- tell client to enter the vehicle at that seat index
                playerObj,
                net.serverCommands.enterVehicle,
                { -- Expected params: integer playerId, integer vehicleId, integer seatIndex
                    playerId = playerObj:getOnlineID(),
                    vehicleId = vehicle:getId(),
                    seatIndex = seatIndex
                }
            )
        else
            u.ALlog("seatIndex invalid (-1) when sending enter vehicle command", u.ALLogLevel.WARN, contextStr)
        end
    end
end


--- Takes data, and gets whether lockpick attempt should succeed, and applies tool damage and other effects. Expected 
--- params: integer playerId, integer toolId, targetTypes targetType, if VehicleDoor: integer vehicleId and string 
--- vehiclePartId, or if WorldDoor or PlayerDoor: table<string, number>: {x, y, z} squarePos
---@param args ALargsType
local function applyLockpickAttempt(args)
    ---@const
    local contextStr = fileName .. ".applyLockpickAttempt"

    local playerId = args.playerId --[[@as integer]]
    if not playerId then u.ALlog("args.playerId nil", u.ALLogLevel.ERROR, contextStr) return end
    local toolId = args.toolId --[[@as integer]]
    if not toolId then u.ALlog("args.toolId nil", u.ALLogLevel.ERROR, contextStr) return end
    local targetType = args.targetType --[[@as targetTypes]]
    if not targetType then u.ALlog("args.targetType nil", u.ALLogLevel.ERROR, contextStr) return end

    ---@type IsoPlayer
    local playerObj = nil
    if net:isSinglePlayerContext() then
        playerObj = getSpecificPlayer(playerId)
    else
        playerObj = getPlayerByOnlineID(playerId)
    end
    if not playerObj then u.ALlog("could not get playerObj from playerId: " .. tostring(playerId), u.ALLogLevel.ERROR,
        contextStr) return end

    local tool = playerObj:getInventory():getItemWithID(toolId)
    if not tool then u.ALlog("could not get tool from toolId: " .. tostring(tool), u.ALLogLevel.ERROR,
        contextStr) return end

    local targetTypes = u.LockpickableObjectTypes
    ---@type IsoDoor|IsoThumpable|VehiclePart
    local targetObj = nil
    ---@type BaseVehicle
    local vehicleObj = nil -- only used if target type is VehicleDoor

    -- get target object based on type
    if targetType == targetTypes.VehicleDoor then
        local vehicleId = args.vehicleId --[[@as integer]]
        if not vehicleId then u.ALlog("args.vehicleId nil", u.ALLogLevel.ERROR, contextStr) return end

        vehicleObj = getVehicleById(vehicleId)
        if not vehicleObj then u.ALlog("could not get vehicleObj from vehicleId: " .. tostring(vehicleId),
            u.ALLogLevel.ERROR, contextStr) return end

        local vehiclePartId = args.vehiclePartId --[[@as string]]
        if not vehiclePartId then u.ALlog("args.vehiclePartId nil", u.ALLogLevel.ERROR, contextStr) return end
        if vehiclePartId == "" then u.ALlog("args.vehiclePartId empty", u.ALLogLevel.ERROR, contextStr) return end

        targetObj = vehicleObj:getPartById(vehiclePartId)
        if not targetObj then u.ALlog("could not get part from vehiclePartId: " .. tostring(vehiclePartId),
            u.ALLogLevel.ERROR, contextStr) return end

    elseif targetType == targetTypes.PlayerDoor or targetType == targetTypes.WorldDoor then

        local pos = args.squarePos --[[@as table<string, number>]]
        if not pos then u.ALlog("args.squarePos nil", u.ALLogLevel.ERROR, contextStr) return end
        if not pos.x or not pos.y or not pos.z then u.ALlog("pos.x/y/z nil", u.ALLogLevel.ERROR, contextStr) return end

        local square = getCell():getGridSquare(pos.x, pos.y, pos.z)
        if not square then u.ALlog("could not find grid square for door target", u.ALLogLevel.ERROR,
            contextStr) return end

        local objects = square:getObjects()
        for i = 0, objects:size() - 1 do
            local obj = objects:get(i)

            if (targetType == targetTypes.WorldDoor and instanceof(obj, "IsoDoor")) then
                targetObj = obj --[[@as IsoDoor]]

            elseif (targetType == targetTypes.PlayerDoor and instanceof(obj, "IsoThumpable") and
                obj--[[@as IsoThumpable]].isDoor and obj--[[@as IsoThumpable]]:isDoor()) then

                targetObj = obj --[[@as IsoThumpable]]
            end
        end

        if not targetObj then u.ALlog("could not find door at square: " .. u.parseToString(pos),
            u.ALLogLevel.ERROR, contextStr) return end
    end

    local success = isLockpickSuccess(playerObj, tool, targetObj)
    tryReduceToolDurability(playerObj, tool, success)

    if success then -- unlock and open doors.
        if targetType == targetTypes.VehicleDoor then
            handleVehiclePart(playerObj, vehicleObj, args.vehiclePartId --[[@as string]])
        else
            if targetType == targetTypes.PlayerDoor and targetObj.setIsLocked then
                targetObj:setIsLocked(false)
                targetObj:syncIsoThumpable()
            elseif targetType == targetTypes.WorldDoor then
                if targetObj.setLockedByKey then targetObj:setLockedByKey(false) end
            end
            if targetObj.ToggleDoor then targetObj :ToggleDoor(playerObj) end -- both PlayerDoor and WorldDoor
        end
    else
        net.sendToClient( -- tell client to display failed halo text. ALTODO: bugged in MP, Indie Stone's fault??
            playerObj,
            net.serverCommands.setHaloNoteWarning,
            {
                playerId = playerId,
                textTranslationKey = "IGUI_ingame_LockpickingTaskFailed"
            }
        )
    end

    --double XP gain on success
    local successXPMultiplier = success and 1.0 or 2.0

    playerObj:getXp():AddXP(Perks.Lockpicking, settings.XPMultiplier * XP_GAIN * successXPMultiplier, false, true,
        net.isPureServerContext())
end
net.registerClientCommandHandler(net.clientCommands.applyLockpickAttempt, applyLockpickAttempt)