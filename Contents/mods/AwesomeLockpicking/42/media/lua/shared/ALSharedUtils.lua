require 'Vehicles/ISUI/ISVehicleMenu'
require 'ALNetworkRouter'

ALSharedUtils = ALSharedUtils or {}


---------- enums and global const vars ----------

---@const
local settings = SandboxVars and SandboxVars.AwesomeLockpicking

---@const
---@enum toolTypes
ALSharedUtils.lockpickToolTypes = {
    screwdriver = "screwdriver",
    professional = "professional",
    forged = "forged",
    invalid = "invalid"
}

---@const
---@enum targetTypes
ALSharedUtils.ALPickableObjectType = {
    WorldDoor = "WorldDoor",
    PlayerDoor = "PlayerDoor",
    VehicleDoor = "VehicleDoor",
    Invalid = "Invalid"
}


---------- local helper functions ----------

--- Returns seat index from given VehiclePart, -1 if no seat assigned
---@return integer
local function getSeatIndexFromPart(part)
    if not part then return -1 end
    local vehicle = part:getVehicle()
    if not vehicle then return -1 end

    for i = 0, vehicle:getMaxPassengers() - 1 do
        -- Only check the doors mapped to this seat index
        if vehicle:getPassengerDoor(i) == part or vehicle:getPassengerDoor2(i) == part then
            return i
        end
    end

    return -1 -- Not a door assigned to a seat
end

---Returns tool type enum from object for easy checking
---@param tool InventoryItem
---@return toolTypes
local function getLockpickToolTypeFromObj(tool)
    local toolType = tool:getFullType()

    if toolType == "AwesomeLockpicking.ProfessionalLockpickingTools" then
        return ALSharedUtils.lockpickToolTypes.professional

    elseif toolType == "AwesomeLockpicking.ForgedLockpickingTools" then
        return ALSharedUtils.lockpickToolTypes.forged

    elseif tool:hasTag(ItemTag.get(ResourceLocation.new("base", "screwdriver"))) then
        return ALSharedUtils.lockpickToolTypes.screwdriver
    end

    return ALSharedUtils.lockpickToolTypes.invalid
end

---Returns tool type enum from object for easy checking
---@param target IsoDoor | IsoThumpable | VehiclePart
---@return targetTypes
local function getTargetTypeFromObj(target)
    if instanceof(target, "IsoDoor") then
        return ALSharedUtils.ALPickableObjectType.WorldDoor

    elseif instanceof(target, "IsoThumpable") and target.isDoor and target:isDoor() then
        return ALSharedUtils.ALPickableObjectType.PlayerDoor

    elseif instanceof(target, "VehiclePart") then
        return ALSharedUtils.ALPickableObjectType.VehicleDoor
    end

    return ALSharedUtils.ALPickableObjectType.Invalid
end

--- Returns whether this lockpick attempt succeeds based on player (lockpicking level), tool, and target type
---@param playerObj IsoPlayer
---@param tool InventoryItem
---@param target IsoDoor | IsoThumpable | VehiclePart
---@return boolean
local function isLockpickSuccess(playerObj, tool, target)
    local baseChance = 15 + (playerObj:getPerkLevel(Perks.Lockpicking) * 7) -- subject to change

    local toolBonus = 1.0 -- default for screwdriver
    local toolType = getLockpickToolTypeFromObj(tool)
    if toolType == ALSharedUtils.lockpickToolTypes.professional then toolBonus = 1.5
    elseif toolType == ALSharedUtils.lockpickToolTypes.forged then toolBonus = 1.3
    -- elseif toolType == ALSharedUtils.lockpickToolTypes.screwdriver then toolBonus = 1.0 -- implied, can skip
    elseif toolType == ALSharedUtils.lockpickToolTypes.invalid then
        print("[ERROR] AwesomeLockpicking.ALSharedUtils.isLockpickSuccess - lockpick tool type invalid")
        return false
    end

    local targetType = getTargetTypeFromObj(target)
    local targetTypes = ALSharedUtils.ALPickableObjectType
    local doorMultiplier = 1.0
    if targetType == targetTypes.VehicleDoor then
        doorMultiplier = 0.55

    elseif targetType == targetTypes.PlayerDoor then
        doorMultiplier = 0.475

    elseif targetType == targetTypes.WorldDoor then
        local sprite = target:getSprite()
        local props = sprite and sprite:getProperties()

        if props then
            if props:get("HighSecurity") == "true" then
                doorMultiplier = 0.5

            elseif props:get("MetalDoor") == "true" then
                doorMultiplier = 0.65

            elseif props:get("GlassDoor") == "true" then
                doorMultiplier = 0.8
            end
        end
    elseif targetType == targetTypes.Invalid then
        print("[ERROR] AwesomeLockpicking.ALSharedUtils.isLockpickSuccess - target type invalid")
        return false
    end

    local sandboxMod = settings and settings.SuccessChanceMultiplier or 1.0

    local finalChance = baseChance * doorMultiplier * toolBonus * sandboxMod

    -- min of 5% chance
    finalChance = math.max(5, finalChance)

    return ZombRand(100) < finalChance
end

--- Rolls for whether tool durability should be degraded based on player maintenance level and tool condition lower
--- chance. If toolType is screwdriver, rolls for whether to delete a paperclip.
---@param tool InventoryItem
---@param success boolean
local function tryReduceToolDurability(playerObj, tool, success)
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

    if getLockpickToolTypeFromObj(tool) == ALSharedUtils.lockpickToolTypes.screwdriver then
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

---@param playerObj IsoPlayer
---@param tool InventoryItem
---@param target IsoDoor | IsoThumpable | VehiclePart
---@param targetType targetTypes
local function applyLockpickAttempt(playerObj, tool, target, targetType)
    -- #region nil checks
    if not playerObj then
        print("[ERROR] AwesomeLockpicking.ALSharedUtils.applyLockpickAttempt - playerObj nil")
        return
    elseif not tool then
        print("[ERROR] AwesomeLockpicking.ALSharedUtils.applyLockpickAttempt - tool nil")
        return
    elseif not target then
        print("[ERROR] AwesomeLockpicking.ALSharedUtils.applyLockpickAttempt - target nil")
        return
    elseif not targetType then
        print("[ERROR] AwesomeLockpicking.ALSharedUtils.applyLockpickAttempt - targetType nil")
        return
    end
    -- #endregion

    local success = isLockpickSuccess(playerObj, tool, target)
    tryReduceToolDurability(playerObj, tool, success)

    local commands = ALSharedUtils.CommandList --ALTODO continue here tomorrow
    local xpGain = 10

    local targetTypes = ALSharedUtils.ALPickableObjectType
    if success then -- unlock and open doors.
        if targetType == targetTypes.VehicleDoor then -- borrowed from ISUnlockVehicleDoor:complete()
            local vehicle = target:getVehicle()
            if vehicle then
                if not target then
                    print("[ERROR] AwesomeLockpicking.applyLockpickAttempt - no such vehicle part " .. tostring(target))
                    return
                end
                local vehicleDoor = target:getDoor()
                if not vehicleDoor then
                    print("[ERROR] AwesomeLockpicking.applyLockpickAttempt - part " .. target .. " has no door")
                    return
                end

                vehicleDoor:setLocked(false)
                vehicle:transmitPartDoor(target) -- required??

                if target:getArea() ~= "TruckBed" then -- unlocking a door
                    if settings.AutoEnterOnLockpickingVehicleDoor then
                        local seatIndex = getSeatIndexFromPart(target)

                        if seatIndex > -1 then -- enter vehicle

                            if isServer() then
                                sendServerCommand(playerObj, commands.ALModule, commands.enterVehicleClient,
                                    {vehicle = vehicle, seatIndex = seatIndex})

                            else
                                local enterVehicleAction = ISEnterVehicle:new(playerObj, vehicle, seatIndex) -- sandbox option..
                                ISTimedActionQueue.add(enterVehicleAction)
                            end
                        end
                    end
                else
                    local truckBed = vehicle:getPartById("TruckBed")
                    if truckBed and truckBed:getItemContainer() then
                        if isServer() then
                            sendServerCommand(playerObj, commands.ALModule, commands.openVehicleDoorClient,
                                {vehicle = vehicle, vehiclePart = target})
                        else
                            local openTrunkAction = ISOpenVehicleDoor:new(playerObj, vehicle, target)
                            ISTimedActionQueue.add(openTrunkAction)
                        end
                    end
                end
            else
                print('[ERROR] AwesomeLockpicking.applyLockpickAttempt - no such vehicle id='..tostring(vehicle))
                return
            end
        else
            if targetType == targetTypes.PlayerDoor then
                if target.setIsLocked then target:setIsLocked(false) end -- PlayerDoor

            elseif targetType == targetTypes.WorldDoor then
                if target.setLockedByKey then target:setLockedByKey(false) end -- WorldDoor
            end
            if target.ToggleDoor then target:ToggleDoor(playerObj) end -- both PlayerDoor and WorldDoor
        end

        xpGain = 20

    else
        ALNetworkRouter.sendToClient(
            playerObj,
            ALNetworkRouter.serverCommands.setHaloNoteWarning,
            {
                playerId = playerObj:getOnlineID(),
                text = getText("IGUI_ingame_LockpickingTaskFailed")
            }
        )
    end

    playerObj:getXp():AddXP(Perks.Lockpicking, settings.XPMultiplier * xpGain, false, true, false)
end


---------- register server commands ----------









--- Sets halo note with given text in red "bad" color for 150.0 duration
---@param args ALargsType
local function setHaloNoteWarningHandler(args)

    local playerId = args.playerId --[[@as integer]]
    local text = args.getText --[[@as string]]

    local playerObj = getPlayerByOnlineID(playerId)
    if not playerObj then
        print("[ERROR] AwesomeLockpicking.ALSharedUtils.setHaloNoteWarning handler - could not find player with "
            .. "Id: " .. tostring(playerId))
        return
    elseif not args.text or args.text == "" then
        print("[ERROR] AwesomeLockpicking.ALSharedUtils.setHaloNoteWarning handler - text nil or empty")
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
