require 'ALSharedUtils'
-- require 'ALNetworkRouter' -- included in ALSharedUtils

---@const
local settings = SandboxVars and SandboxVars.AwesomeLockpicking
---@const
local log = ALSharedUtils.log
---@const
local logLevel = ALSharedUtils.ALLogLevel
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
    if not playerObj then
        log("playerObj nil", logLevel.ERROR, contextStr)
        return false
    end
    if not tool then
        log("tool nil", logLevel.ERROR, contextStr)
        return false
    end
    if not target then
        log("target nil", logLevel.ERROR, contextStr)
        return false
    end

    local baseChance = BASE_CHANCE + (playerObj:getPerkLevel(Perks.Lockpicking) * LEVEL_MULTIPLIER)

    local toolBonus = TOOL_MULT.SCREWDRIVER -- default for screwdriver
    local toolType = ALSharedUtils.getLockpickToolTypeFromObj(tool)
    local lockpickToolTypes = ALSharedUtils.LockpickToolTypes

    if toolType == lockpickToolTypes.Professional then toolBonus = TOOL_MULT.PROFESSIONAL
    elseif toolType == lockpickToolTypes.Forged then toolBonus = TOOL_MULT.FORGED
    elseif toolType == lockpickToolTypes.Invalid then
        log("lockpick tool type invalid", logLevel.ERROR, contextStr)
        return false
    end

    local targetType = ALSharedUtils.getTargetTypeFromObj(target)
    local targetTypes = ALSharedUtils.LockpickableObjectTypes
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
        log("targetType invalid", logLevel.ERROR, contextStr)
        return false
    end

    local sandboxMod = settings and settings.SuccessChanceMultiplier or 1.0 -- default 1

    local finalChance = baseChance * doorMultiplier * toolBonus * sandboxMod

    finalChance = math.max(MIN_CHANCE, finalChance)

    log("base*door*tool*sandbox = successChance: " .. tostring(baseChance) .. "*" .. tostring(doorMultiplier) .. "*"
        .. tostring(toolBonus) .. "*" .. tostring(sandboxMod) .. " = " .. tostring(finalChance), logLevel.DEBUG,
        contextStr)

    return ZombRand(100) < finalChance
end
--ALTODONEXT - make the rest of the print statements my custom log, and also continue testing multiplayer

--- Rolls for whether tool durability should be degraded based on player maintenance level and tool condition lower
--- chance. If toolType is screwdriver, rolls for whether to delete a paperclip. SERVER ONLY
---@param tool InventoryItem
---@param success boolean
local function tryReduceToolDurability(playerObj, tool, success)
    if not playerObj then
        print("[ERROR] AwesomeLockpicking.ALClientCommandHandlers.tryReduceToolDurability - playerObj nil")
        return false
    end
    if not tool then
        print("[ERROR] AwesomeLockpicking.ALClientCommandHandlers.tryReduceToolDurability - tool nil")
        return false
    end

    local inv = playerObj:getInventory()
    if not inv then
        print("[ERROR] AwesomeLockpicking.ALSharedUtils.tryReduceToolDurability - could not get player inventory")
        return
    end

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

    if ALSharedUtils.getLockpickToolTypeFromObj(tool) == ALSharedUtils.LockpickToolTypes.Screwdriver then
        local paperclip = inv:getFirstTypeRecurse("Base.Paperclip")
        if not paperclip then
            print("[ERROR] AwesomeLockpicking.ALSharedUtils.tryReduceToolDurability - tool is screwdriver but could "
                .. "not find paperclip")
            return
        end
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
    if not vehiclePart then
        print("[ERROR] AwesomeLockpicking.ALClientCommandHandlers.getSeatIndexFromPart - vehiclePart nil")
        return -1
    end
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
    if not playerObj then
        print("[ERROR] AwesomeLockpicking.ALClientCommandHandlers.handleVehiclePart - playerObj nil")
        return
    end
    if not vehicle then
        print("[ERROR] AwesomeLockpicking.ALClientCommandHandlers.handleVehiclePart - vehicle nil")
        return
    end
    if not vehiclePartId or vehiclePartId == "" then
        print("[ERROR] AwesomeLockpicking.ALClientCommandHandlers.handleVehiclePart - vehiclePartId nil or empty")
        return
    end

    local vehiclePart = vehicle:getPartById(vehiclePartId)
    if not vehiclePart then
        print("[ERROR] AwesomeLockpicking.ALClientCommandHandlers.handleVehiclePart - could not get vehicle part from "
            .. "part ID: " .. tostring(vehiclePartId))
        return
    end

    local vehicleDoor = vehiclePart.getDoor and vehiclePart:getDoor()
    if not vehicleDoor then
        print("[ERROR] AwesomeLockpicking.ALClientCommandHandlers.handleVehiclePart - part " .. tostring(vehiclePartId)
            .. " has no door")
        return
    end

    vehicleDoor:setLocked(false)
    -- vehicle:transmitPartDoor(target) -- required?? ALTODO

    local area = vehiclePart:getArea()

    if area == "TruckBed" then -- unlocking a trunk
        local truckBed = vehicle:getPartById("TruckBed")
        if truckBed and truckBed:getItemContainer() then
            ALNetworkRouter.sendToClient( -- tell client to open trunk
                playerObj,
                ALNetworkRouter.serverCommands.openVehicleDoor,
                { -- Expected params: integer playerId, integer vehicleId, integer vehiclePartId
                    playerId = playerObj:getOnlineID(),
                    vehicleId = vehicle:getId(),
                    vehiclePartId = vehiclePartId
                }
            )
        end
    elseif settings and settings.AutoEnterOnLockpickingVehicleDoor then -- unlocking a door
        -- ALTODO - might move getSeatIndexFromPart into this file
        local seatIndex = getSeatIndexFromPart(vehiclePart)
        if seatIndex > -1 then
            ALNetworkRouter.sendToClient( -- tell client to enter the vehicle at that seat index
                playerObj,
                ALNetworkRouter.serverCommands.enterVehicle,
                { -- Expected params: integer playerId, integer vehicleId, integer seatIndex
                    playerId = playerObj:getOnlineID(),
                    vehicleId = vehicle:getId(),
                    seatIndex = seatIndex
                }
            )
        end
    end
end


--- Takes data, and gets whether lockpick attempt should succeed, and applies tool damage and other effects. Expected 
--- params: integer playerId, integer toolId, targetTypes targetType, if VehicleDoor: integer vehicleId and string 
--- vehiclePartId, or if WorldDoor or PlayerDoor: table<string, number>: {x, y, z} squarePos
---@param args ALargsType
local function applyLockpickAttempt(args)
    ---@const
    local functionName = "applyLockpickAttempt"

    local playerId = args.playerId --[[@as integer]]
    if not playerId then
        print("[ERROR] AwesomeLockpicking.ALClientCommandHandlers.applyLockpickAttempt - args.playerId nil")
        return
    end
    local toolId = args.toolId --[[@as integer]]
    if not toolId then
        print("[ERROR] AwesomeLockpicking.ALClientCommandHandlers.applyLockpickAttempt - args.toolId nil")
        return
    end
    local targetType = args.targetType --[[@as targetTypes]]
    if not targetType then
        print("[ERROR] AwesomeLockpicking.ALClientCommandHandlers.applyLockpickAttempt - args.targetType nil")
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
        print("[ERROR] AwesomeLockpicking.ALClientCommandHandlers.applyLockpickAttempt - Could not retrieve player "
        .. "from player online ID: " .. tostring(playerId))
        return
    end

    local tool = playerObj:getInventory():getItemWithID(toolId)
    if not tool then
        print("[ERROR] AwesomeLockpicking.ALClientCommandHandlers.applyLockpickAttempt - could not get tool from "
            .. "toolId: " .. tostring(toolId))
        return
    end

    local targetTypes = ALSharedUtils.LockpickableObjectTypes
    ---@type IsoDoor|IsoThumpable|VehiclePart
    local targetObj = nil
    ---@type BaseVehicle
    local vehicleObj = nil -- only used if target type is VehicleDoor

    -- get target object based on type
    if targetType == targetTypes.VehicleDoor then
        local vehicleId = args.vehicleId --[[@as integer]]
        if not vehicleId then
            print("[ERROR] AwesomeLockpicking.ALClientCommandHandlers.applyLockpickAttempt - args.vehicleId nil")
            return
        end

        vehicleObj = getVehicleById(vehicleId)
        if not vehicleObj then
            print("[ERROR] AwesomeLockpicking.ALClientCommandHandlers.applyLockpickAttempt - could not get vehicle "
            .. "from vehicleId: " .. tostring(vehicleId))
            return
        end

        local vehiclePartId = args.vehiclePartId --[[@as string]]
        if not vehiclePartId then
            print("[ERROR] AwesomeLockpicking.ALClientCommandHandlers.applyLockpickAttempt - args.vehiclePartId nil")
            return
        end

        if not vehiclePartId or vehiclePartId == "" then
            print("[ERROR] AwesomeLockpicking.ALClientCommandHandlers.applyLockpickAttempt - args.vehiclePartId "
                .. "nil or empty")
            return
        end

        targetObj = vehicleObj:getPartById(vehiclePartId)
        if not targetObj then
            print("[ERROR] AwesomeLockpicking.ALClientCommandHandlers.applyLockpickAttempt - could not get vehicle "
            .. "part from Id")
            return
        end
    elseif targetType == targetTypes.PlayerDoor
        or targetType == targetTypes.WorldDoor then

        local pos = args.squarePos --[[@as table<string, number>]]
        if not pos then
            print("[ERROR] AwesomeLockpicking.ALClientCommandHandlers.applyLockpickAttempt - pos table nil")
            return
        elseif not pos.x or not pos.y or not pos.z then
            print("[ERROR] AwesomeLockpicking.ALClientCommandHandlers.applyLockpickAttempt - pos.x/y/z nil")
            return
        end

        local square = getCell():getGridSquare(pos.x, pos.y, pos.z)
        if not square then
            print("[ERROR] AwesomeLockpicking.ALClientCommandHandlers.applyLockpickAttempt - could not find grid "
                .. "square for door target")
            return
        end

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
    end

    local success = isLockpickSuccess(playerObj, tool, targetObj)
    tryReduceToolDurability(playerObj, tool, success)

    if success then -- unlock and open doors.
        if targetType == targetTypes.VehicleDoor then
            handleVehiclePart(playerObj, vehicleObj, args.vehiclePartId --[[@as string]])
        else
            if targetType == targetTypes.PlayerDoor then
                if targetObj.setIsLocked then targetObj:setIsLocked(false) end

            elseif targetType == targetTypes.WorldDoor then
                if targetObj.setLockedByKey then targetObj:setLockedByKey(false) end
            end
            if targetObj.ToggleDoor then targetObj :ToggleDoor(playerObj) end -- both PlayerDoor and WorldDoor
        end
    else
        ALNetworkRouter.sendToClient( -- tell client to display failed halo text
            playerObj,
            ALNetworkRouter.serverCommands.setHaloNoteWarning,
            {
                playerId = playerId,
                textTranslationKey = "IGUI_ingame_LockpickingTaskFailed"
            }
        )
    end

    --double XP gain on success
    local successXPMultiplier = success and 1.0 or 2.0

    playerObj:getXp():AddXP(Perks.Lockpicking, settings.XPMultiplier * XP_GAIN * successXPMultiplier, false, true,
        ALNetworkRouter.isPureServerContext())
end
ALNetworkRouter.registerClientCommandHandler(ALNetworkRouter.clientCommands.applyLockpickAttempt,
    applyLockpickAttempt)