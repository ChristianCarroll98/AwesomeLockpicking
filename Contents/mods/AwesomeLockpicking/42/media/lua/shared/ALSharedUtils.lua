require 'Vehicles/ISUI/ISVehicleMenu'

ALSharedUtils = ALSharedUtils or {}

local function applyLockpickAttempt(playerObj, tool, target, targetType)
    local targetTypes = ALSharedUtils.ALPickableObjectType
    if not playerObj or not target or not tool or not targetType or targetType == targetTypes.None then
        print("[ERROR] AwesomeLockpicking - nil param or None targetType in applyLockpickAttempt")
        return
    end

    local inv = playerObj:getInventory()
    if not inv then
        print("[ERROR] AwesomeLockpicking - player:getInventory() returned nil in applyLockpickAttempt")
        return
    end

    local toolTypes = {
        screwdriver = "screwdriver",
        professional = "professional",
        forged = "forged"
    }

    local toolBonus = 1 -- default for screwdriver
    local toolType = tool:getFullType()
    if toolType == "AwesomeLockpicking.ProfessionalLockpickingTools" then
        toolType = toolTypes.professional
        toolBonus = 1.55
    elseif toolType == "AwesomeLockpicking.ForgedLockpickingTools" then
        toolType = toolTypes.forged
        toolBonus = 1.35
    else
        toolType = toolTypes.screwdriver -- any screwdriver if not lockpicking tools
    end

    local baseChance = 20 + (playerObj:getPerkLevel(Perks.Lockpicking) * 7)

    local doorMultiplier = 1.0
    if targetType == targetTypes.VehicleDoor then
        doorMultiplier = 0.6
    else
        local sprite = target:getSprite()
        local props = sprite and sprite:getProperties()
        if props then
            if props:get("HighSecurity") == "true" then
                doorMultiplier = 0.45
            elseif props:get("MetalDoor") == "true" then
                doorMultiplier = 0.75
            elseif props:get("GlassDoor") == "true" then
                doorMultiplier = 0.90
            end
        end
    end

    local sandboxMod = 1.0
    if SandboxVars and SandboxVars.AwesomeLockpicking then
        sandboxMod = SandboxVars.AwesomeLockpicking.SuccessChanceModifier or 1.0
    end

    local finalChance = baseChance * doorMultiplier * toolBonus * sandboxMod
    finalChance = math.max(5, finalChance)

    local success = ZombRand(100) < finalChance

    if tool.getCondition and tool:getCondition() > 0 then
        local baseChancePool = tool:getConditionLowerChance()
        local maintenanceMod = playerObj:getMaintenanceMod()
        local finalChancePool = baseChancePool + maintenanceMod

        if success then
            finalChancePool = finalChancePool * 2
        end

        if ZombRand(finalChancePool) == 0 then
            tool:setCondition(tool:getCondition() - 1)
            inv:setDrawDirty(true)
        end
    end

    if toolType == toolTypes.screwdriver then
        local paperclip = inv:getFirstTypeRecurse("Base.Paperclip")
        if paperclip then
            local removePaperclipChance = success and 10 or 25
            if ZombRand(100) < removePaperclipChance then
                inv:Remove(paperclip)
            end
        end
    end

    local commands = ALSharedUtils.CommandList
    local xpGain = 10

    if success then -- unlock and open doors.
        if targetType == targetTypes.VehicleDoor then -- borrowed from ISUnlockVehicleDoor:complete()
            local vehicle = target:getVehicle()
            if vehicle then
                if not target then
                    print('[ERROR] AwesomeLockpicking - no such vehicle part '..tostring(target))
                    return
                end
                local vehicleDoor = target:getDoor()
                if not vehicleDoor then
                    print('[ERROR] AwesomeLockpicking - part ' .. target .. ' has no door')
                    return
                end
                vehicleDoor:setLocked(false)
                vehicle:transmitPartDoor(target) -- required??

                local areaId = target:getArea() -- Grabs layout ID (e.g., "FrontLeft")
                print("[DEBUG] getArea: " .. tostring(areaId))
                local seatIndex = vehicle:getScript():getPassengerIndex(areaId) -- Returns 0, 1, 2... or -1
                print("[DEBUG] seatIndex: " .. tostring(seatIndex))
                if(seatIndex == -1) then
                    print("[DEBUG] seatIndex was -1!")
                else -- enter vehicle
                    if isServer() then
                        sendServerCommand(playerObj, commands.ALModule, commands.enterVehicle,
                        {vehicle = vehicle, seatIndex = seatIndex})
                    else
                        local enterVehicleAction = ISEnterVehicle:new(playerObj, vehicle, seatIndex) -- sandbox option..
                        ISTimedActionQueue.add(enterVehicleAction)
                    end
                end
            else
                print('no such vehicle id='..tostring(vehicle))
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

    elseif isServer() then -- fail from server, send halo note text to client
        sendServerCommand(playerObj, commands.ALModule, commands.setHaloNoteClient,
            {text = "IGUI_ingame_LockpickingTaskFailed"})
    else
        playerObj:setHaloNote(getText("IGUI_ingame_LockpickingTaskFailed"))
    end

    local settings = SandboxVars and SandboxVars.AwesomeLockpicking
    if not settings then
        print("[ERROR] AwesomeLockpicking - could not retrieve sandbox settings in applyLockpickAttempt")
        return
    end

    playerObj:getXp():AddXP(Perks.Lockpicking, settings.XPMultiplier * xpGain, false, true, false)
end


---------- Enums ----------
local CommandList = {
    ALModule = "ALModule",
    applyLockpickAttemptServer = "applyLockpickAttemptServer",
    setHaloNoteClient = "setHaloNoteClient",
    enterVehicle = "enterVehicle"
}

local ALPickableObjectType = {
    WorldDoor = "WorldDoor",
    PlayerDoor = "PlayerDoor",
    VehicleDoor = "VehicleDoor",
    None = "None"
}

---------- Exports ----------
ALSharedUtils.applyLockpickAttempt = applyLockpickAttempt
ALSharedUtils.CommandList = CommandList
ALSharedUtils.ALPickableObjectType = ALPickableObjectType